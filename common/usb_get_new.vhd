-------------------------------------------------------------------------------------------------
-- Company:        IPNO
-- Engineer:       Pierre Edelbruck
-- 
-- Create Date:    11-01-2012
-- Design Name:    Pierre Edelbruck
--===============================================================================================
-- Module Name:                      ====== usb_get ======
--===============================================================================================
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions:  ISE 12.4
-- Description: ==== Interface de lecture pour module DLP-USB245M ====
-- Réécrit en vue de simplifier la machine d'état.
-- Comportement adapté selon que le module est master ou slave
--
-- Revision:
-- Revision 1.0 - File Created
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

entity usbGet_new is
--  generic (
--    USB_ADDR : std_logic_vector (1 downto 0)
--  );
  port (
    clk        : in    std_logic;
    reset      : in    std_logic;
    abort      : in    std_logic; -- pour forcer l'arrêt de l'opération depuis l'extérieur
    driver     : in    std_logic; -- indique si les signaux wr et data doivent être activés
    master     : in    std_logic; -- indique si le signal rd doit être piloté
    -- Interface USB
    dataUsb    : inout std_logic_vector (7 downto 0) := "ZZZZZZZZ";
    rxf        : in    std_logic; -- au moins un octet dans buffer de réception si à 1
    txe        : in    std_logic; -- de l'espace dispo dans buffer de sortie si à 1
    rd_n       : out   std_logic; -- ordre de lecture usb
    wr         : out   std_logic; -- ordre d'écriture usb (ici en logique positive)
    -- Du bus interne vers l'USB
    usbPutData : in    std_logic_vector (7 downto 0);
    usbPutRq   : in    std_logic;
    -- De l'USB vers le bus interne
    usbGetData : out   std_logic_vector (7 downto 0); -- latch de sortie de ce module (USB->BUS)
    usbGetRq   : in    std_logic;
    -- Fin de transaction
		usbGetRdy  : out   std_logic
  );
end usbGet_new;
-------------------------------------------------------------------------------------------------

architecture usbGetArch of usbGet_new is

constant TIMER_BITS : integer := 5;
constant DELAI_RD : integer := 20; -- délai (coups de clock)
constant DELAI_WR : integer := 20; -- délai (coups de clock)

type UsbGetState is (IDLE, WAIT_RXF, WAIT_DATA, CHECK_TXE, WRITE_DATA, W_TXE_1, W_TXE_0, SIGNAL_END,
                     WAIT_ACQUIT
                      );
signal usbCs : UsbGetState;
signal timer : std_logic_vector (TIMER_BITS-1 downto 0); -- max 31 !
signal rd_n_internal, wr_internal : std_logic;

-- chipscope ====================================================================================

--signal all_zero : std_logic_vector (63 downto 0) := (others => '0');
--signal etat : std_logic_vector (3 downto 0);
--signal CONTROL0 : std_logic_vector (35 downto 0);
--
--component get_ila
--  PORT (
--    CONTROL  : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
--    CLK      : IN    STD_LOGIC;
--    TRIG0    : in    STD_LOGIC_VECTOR(31 DOWNTO 0)
--  );
--end component;
--
--component get_icon
--  PORT (
--    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
--end component;

--    rxf      : in    std_logic;
--    txe      : in    std_logic;
--    usbPutRq : in    std_logic;
--    usbGetRq : in    std_logic;
--    rd_n     : in    std_logic;
--    wr       : in    std_logic;
--    abort    : in    std_logic;
--    driver   : in    std_logic;
--    master   : in    std_logic;
--    etat     : in    std_logic_vector (3 downto 0);

--================================================================================================

begin
-- chipscope ====================================================================================

--mon_get_icon : get_icon
--  port map (
--    CONTROL0 => CONTROL0);
--
--mes_sondes_get : get_ila
--  port map (
--    CONTROL  => CONTROL0,
--    CLK      => clk,
--    trig0(0) => rxf,
--    trig0(1) => txe,
--    trig0(2) => usbPutRq,
--    trig0(3) => usbGetRq,
--    trig0(4) => rd_n_internal,
--    trig0(5) => wr_internal,
--    trig0(6) => abort,
--    trig0(7) => driver,
--    trig0(8) => master,
--    trig0(12 downto 9) => etat,
--    trig0(31 downto 13) => all_zero (31 downto 13)
--  );
--
--etat <= conv_std_logic_vector(UsbGetState'pos(usbCs), 4);

--================================================================================================

rd_n <= rd_n_internal;
wr   <= wr_internal;

-- Le process séquentiel de la machine d'état ---------------------------------------------------
usbGetSeq: process (reset, master, clk)
begin
  if reset = '1' then
    usbGetData <= (others => '0');
    usbCs <= IDLE;
  elsif rising_edge(clk) then
    if abort = '1' then usbCs <= IDLE;
    else
      case usbCs is
      -----------------------------------------------
      when IDLE =>
        if    usbGetRq = '1' then usbCs <= WAIT_RXF;
        elsif usbPutRq = '1' then
          usbCs <= CHECK_TXE;
        end if;
      -----------------------------------------------
      when WAIT_RXF => -- attendre l'arrivée dun octet
        if rxf = '1' then
          timer <= conv_std_logic_vector(DELAI_RD, TIMER_BITS);
          usbCs <= WAIT_DATA;
        end if;
      -----------------------------------------------
      when WAIT_DATA => -- attendre la stabilité des données
        if timer = 0 then
          usbGetData <= dataUsb; -- lire le bus usb au passage (timer = 1)
          usbCs <= WAIT_ACQUIT;
        else
          timer <= timer - 1;
        end if;
      -----------------------------------------------
      when WAIT_ACQUIT => -- attendre acquitement DLP
        if rxf = '0' then -- attendre l'acquitement du DLP
          usbCs <= SIGNAL_END;
        end if;
      -----------------------------------------------
      when CHECK_TXE =>
        if txe = '1' then
          timer <= conv_std_logic_vector(DELAI_WR, TIMER_BITS);
          usbCs <= WRITE_DATA;
        end if;
      -----------------------------------------------
      when WRITE_DATA =>
        if timer = 0 then
          usbCs <= W_TXE_0;
        else
          timer <= timer-1;
        end if;
      -----------------------------------------------   
      when W_TXE_0 => -- attente montée de txe_n
        if txe = '0' then
          usbCs <= W_TXE_1;
        end if;
      -----------------------------------------------   
      when W_TXE_1 => -- attente redescente de txe_n
        if txe = '1' then
          usbCs <= SIGNAL_END;
        end if;
      -----------------------------------------------   
      when SIGNAL_END => usbCs <= IDLE; -- activer usbGetRdy (1 clk)
      -----------------------------------------------
      end case;
    end if;
  end if;
end process;


-- Le process combinatoire de la machine d'état -------------------------------------------------
usbGetComb: process (usbCs, master, driver, usbPutData)
begin
  if driver = '1' then wr_internal   <= '0'; else wr_internal   <= 'Z'; end if;
  if master = '1' then rd_n_internal <= '1'; else rd_n_internal <= 'Z'; end if;

  usbGetRdy <= '0';
  dataUsb   <= (others => 'Z');
  case usbCs is
  when IDLE        => null;
  when WAIT_RXF    => null;
  when WAIT_DATA   => if master = '1' then rd_n_internal <= '0'; end if;
  when WAIT_ACQUIT => null;
  when CHECK_TXE   => null;
  when WRITE_DATA  => if driver = '1' then
                        wr_internal   <= '1';
                        dataUsb  <= usbPutData;
                      end if;
  when W_TXE_0    =>  if driver = '1' then
                        dataUsb <= usbPutData;
                      end if;
  when W_TXE_1    => if driver = '1' then
                       dataUsb  <= usbPutData;
                     end if;
  when SIGNAL_END => usbGetRdy <= '1';
  end case;
end process;


end usbGetArch;