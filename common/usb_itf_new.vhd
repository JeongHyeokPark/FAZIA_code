-------------------------------------------------------------------------------------------------
-- Company:        IPNO
-- Engineer:       Pierre Edelbruck
-- 
-- Create Date:    11-01-2012
-- Design Name:    Pierre Edelbruck
--===============================================================================================
-- Module Name:                      ====== usb_itf ======
--===============================================================================================
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions:  ISE 12.4
-- Description: ==== Interface de lecture pour module DLP-USB245M ====
-- Réécrit en vue de simplifier les machines d'état.
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

--use work.tel_defs.all;
use work.slow_ct_defs.all;

entity usbItf_new is
  port (
    clk       : in    std_logic;
    reset     : in    std_logic;
    --------------------------------------- Interface to USB ---------------------
    -- le numéro de port USB 00=com 01 = tel_a 10 = tel_b (step 1)
    --                              00 = tel_a 01 = tel_b (step 2)
    addrUsb   : in    std_logic_vector (1 downto 0);
    dataUsb   : inout std_logic_vector (7 downto 0) := "ZZZZZZZZ"; -- le port usb
    rd_n      : inout std_logic; -- l'esclave lit ce signal mais ne l'écrit jamais
    wr        : out   std_logic; -- sortie en ou cablé avec l'autre fpga
    rxf_n     : in    std_logic;
    txe_n     : in    std_logic;
    ---------------------------------- Interface to internal parallel bus ---------
    slowCtBus   : out slowCtBusRec;
    slowCtBusRd : in  std_logic_vector (15 downto 0)
  );
end UsbItf_new;

architecture usbItfArch of UsbItf_new is
signal rxf_s, txe_s : std_logic;
signal abort      : std_logic;
signal master, driver : std_logic;
signal usbGetData : std_logic_vector (7  downto 0); -- USB --> FPGA
signal usbPutData : std_logic_vector (7  downto 0); -- FPGA --> USB
signal readData   : std_logic_vector (15 downto 0);
signal address    : std_logic_vector (15 downto 0);
--signal usbGetReg, usbPutReg : std_logic_vector (15 downto 0);
--signal addrReg    : std_logic_vector (15 downto 0);
signal usbGetRq,  usbPutRq,  usbGetRdy : std_logic;

signal timeOut : std_logic_vector(23 downto 0); -- 24 bit = 168 ms
signal timeOutRaz, timeOutLd : std_logic;

-- le compteur block transfert
constant BITS_BLOCK_CT : integer := 14; -- il faut un bit de plus
signal blockCt : std_logic_vector(BITS_BLOCK_CT-1 downto 0); -- 12 bit pour commencer

type UsbGetState is (IDLE, ADH, ADL, CODE,
                     RD_DECR, RD_BUS0, RD_BUS1, RD_DATAH, RD_DATAL, WR_DATAH, WR_DATAL,
                     CTH, CTL);
signal usbCs : UsbGetState;

begin

getteur: entity work.usbGet_new
  port map (
    clk        => clk,
    reset      => reset,
    abort      => abort,
    driver     => driver,
    master     => master,
    ---
    dataUsb    => dataUsb,
    rxf        => rxf_s,
    txe        => txe_s,
    rd_n       => rd_n,
    wr         => wr,
    ---
    usbGetRq   => usbGetRq,
    usbGetData => usbGetData,
    usbPutRq   => usbPutRq,
    usbPutData => usbPutData,
    ---
    usbGetRdy  => usbGetRdy
  );
 
-------------------------------------------------------------------------------------------------
-- synchro des signaux d'entrée de l'usb
usb_sync : process (clk)
begin
  if rising_edge (clk) then
    rxf_s <= not rxf_n;
    txe_s <= not txe_n;
  end if;
end process;

master <= '1' when addrUsb = "00" else '0';

-------------------
affectSync : process(clk,reset)
begin
	if rising_edge(clk) then
		slowCtBus.addr <= address;
	end if;
end process;

-------------------------------------------------------------------------------------------------
-- Le compteur de time out
-- Décompte tant qu'il n'est pas nul
-- S'initialise par un coup de clock sur timeOutLd
-- Se raze  par un coup de clock sur timeOutRaz
-- Le compte se nomme timeOut
-- Génère un signal abort en passant au compte=1

usb_time_out_p : process (clk, reset)
begin
  if reset = '1' then
    --timeOut <= X"000000";
    timeOut <= X"A00000";
  elsif rising_edge (clk) then
    abort <= '0';
    if timeOutRaz = '1' then
      timeOut <= X"000000"; -- kill time out
    elsif timeOutLd = '1' then
      timeOut <= X"A00000"; -- initialize time out = 100 ms
    elsif timeOut /= 0 then
      timeOut <= timeOut-1;
      if timeOut = X"000001" then
        abort <= '1';
      else
        abort <= '0';
      end if;
    end if;
  end if;
end process;

-- Le process séquentiel de la machine d'état ---------------------------------------------------
usbItfSeq: process (reset, abort, master, clk)
begin
  if reset = '1' or abort = '1' then
    blockCt <= (others => '0');
    usbCs   <= IDLE;
    slowCtBus.wr   <= '0';
    slowCtBus.rd   <= '0';
    address        <= (others => '0');
    slowCtBus.data <= (others => '0');

    if master = '1' then driver <= '1';
                    else driver <= '0'; end if;
    
  elsif rising_edge(clk) then
    if abort = '1' then
      usbCs   <= IDLE;
    else
      case usbCs is
      -----------------------------------------------
      when IDLE     =>
        slowCtBus.wr <= '0'; -- nécessaire au rebouclage
        if addrUsb = "00" then driver <= '1';
                          else driver <= '0'; end if;
        usbGetRq <= '0';
        usbPutRq <= '0';
        if rxf_s = '1' then
          timeOutLd <= '1';
          usbGetRq  <= '1'; -- signal maintenu
          usbCs     <= ADH;
        else
          timeOutRaz <= '1';
        end if;
      -----------------------------------------------
      when ADH   =>
        timeOutLd  <= '0';
        timeOutRaz <= '0';
        if usbGetRdy ='1' then
          address(15 downto 8) <= usbGetData;
          usbCs   <= ADL;
        end if;
      -----------------------------------------------
      when ADL   =>
        if usbGetRdy ='1' then
          address(7 downto 0) <= usbGetData;
          usbCs   <= CODE;
        end if;
      -----------------------------------------------
      when CODE  =>
        if usbGetRdy ='1' then
          if usbGetData (3 downto 2) = addrUsb then
            driver <= '1'; -- get prendra la commande de wr (interface usb)
          else
            driver <= '0';
          end if;
          case usbGetData (1 downto 0) is
          when "00" => usbGetRq <= '0';      -- read
                       slowCtBus.rd <= '1';  -- lire le bus
                       usbCs    <= RD_BUS0;
          when "01" => usbCs    <= WR_DATAH; -- write
          when "11" => usbCs    <= CTH;      -- block read
          when others => null;
          end case;
        end if;
      -----------------------------------------------
      when RD_DECR => -- cet état est équivalent à RD_BUS0, mais on initialise le compteur de lecture
        blockCt      <= blockCt-1; 
        slowCtBus.rd <= '0'; -- laisser le bus se stabiliser
        usbCs        <= RD_BUS1;
      -----------------------------------------------
      when RD_BUS0 => -- laisser le bus se stabiliser
        slowCtBus.rd <= '0';
        usbCs        <= RD_BUS1;
      -----------------------------------------------
      when RD_BUS1 => -- mémoriser la valeur
        readData <= slowCtBusRd;
        usbCs    <= RD_DATAH;
      -----------------------------------------------
      when RD_DATAH => -- bus --> USB
        usbPutRq     <= '1';
        if usbGetRdy ='1' then
          usbCs <= RD_DATAL;
        end if;
      -----------------------------------------------
      when RD_DATAL => -- bus --> USB
        if usbGetRdy ='1' then
          if blockCt = 0 then
            usbPutRq <= '0';
            usbCs    <= IDLE;
          else
            if driver = '1' then -- ne lire que si la transaction m'était destinée
              slowCtBus.rd <= '1'; -- lire le bus
            end if;
            blockCt <= blockCt - 1;
            address <= address + 1;
            usbCs   <= RD_BUS0;
          end if;
        end if;
      -----------------------------------------------
      when WR_DATAH => -- USB --> bus
        if usbGetRdy ='1' then
          slowCtBus.data(15 downto 8) <= usbGetData;
          usbCs <= WR_DATAL;
        end if;
      -----------------------------------------------
      when WR_DATAL => -- USB --> bus
        if usbGetRdy ='1' then
          if driver = '1' then -- n'écrire que si la transaction m'était destinée
            slowCtBus.data(7 downto 0) <= usbGetData;
            slowCtBus.wr <= '1';
          end if;
          usbCs <= IDLE;
        end if;
      -----------------------------------------------
      when CTH   => -- compteur de lecture block
        if usbGetRdy ='1' then
          blockCt(BITS_BLOCK_CT-1 downto 8) <= usbGetData(BITS_BLOCK_CT-1-8 downto 0);
          usbCs <= CTL;
        end if;
      -----------------------------------------------
      when CTL   =>
        if usbGetRdy ='1' then
          blockCt(7 downto 0) <= usbGetData;
          slowCtBus.rd <= '1'; -- lire le bus
          usbGetRq <= '0';
          usbCs    <= RD_DECR;
        end if;
      -----------------------------------------------
      end case;
    end if;
  end if;
end process;

-- Le process combinatoire de la machine d'état -------------------------------------------------
usbItdComb: process (usbCs, readData)
begin
  usbPutData   <= (others => '0');
  case usbCs is
  -----------------------------------------------------
  when IDLE     => null;
  -----------------------------------------------------
  when ADH      => null;
  -----------------------------------------------------
  when ADL      => null;
  -----------------------------------------------------
  when CODE     => null;
  -----------------------------------------------------
  when RD_DECR  => null;
  -----------------------------------------------------
  when RD_BUS0  => null;
  -----------------------------------------------------
  when RD_BUS1  => null;
  -----------------------------------------------------
  when RD_DATAH => usbPutData <= readData(15 downto 8);
  -----------------------------------------------------
  when RD_DATAL => usbPutData <= readData( 7 downto 0);
  -----------------------------------------------------
  when WR_DATAH => null;
  -----------------------------------------------------
  when WR_DATAL => null;
  -----------------------------------------------------
  when CTH      => null;
  -----------------------------------------------------
  when CTL      => null;
  -----------------------------------------------------
  end case;
end process;
end usbItfArch;


