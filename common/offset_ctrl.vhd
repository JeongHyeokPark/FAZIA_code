--------------------------------------
--    Company:  IPN Orsay           --
--    Engineer: Pierre Edelbruck    --
--                                  --
--    Create Date:    22/03/2011    --
--    Imprimé le:     30-03-2011    --
--    Project Name:   fazia         --
--    Design Name:    telescope     --
--    Module Name:    offset_ctrl   --
--    Target Devices: virtex-5      --
--    Tool versions:  ISE 12.3      --
--------------------------------------

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description:
-- ~~~~~~~~~~~~
-- Ce module permet le contrôle des potentiomètres numériques de réglage d'offset
-- des préamplificateurs. Le réglage d'une tension d'offset se fait par une simple
-- écriture slowcontrol sur l'un des trois ports adjust_n [0 à 2]
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
--
-- Dependencies: i2c_master
--
-- Revision 0.01 - File Created
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--use ieee.numeric_std.all;

use work.tel_defs.all;
use work.slow_ct_defs.all;

--library fazia;
--use fazia.slow_ct_defs.all;
---------------------------------------------------------------------------------------------------
entity OffsetCtrl is
  generic (
    RegAd     : std_logic_vector(SC_TOP downto 0)
  );
  port ( 
    clk :      in    std_logic;
    reset :    in    std_logic;
    ---
    adjust_n : out   std_logic_vector (2 downto 0); -- les fils de strobe des potentiomètres
    ---
    scl :      out   std_logic;
    sda :      out   std_logic;
    ---
    slowCtBus: in  SlowCtBusRec;
	 slowCtBusRd : out std_logic_vector(15 downto 0)
   );
end OffsetCtrl;

--------------------------------------------------------------------------------------------------
architecture Behavioral of OffsetCtrl is

signal tensionDac     : std_logic_vector (15 downto 0);
signal tensionDacSi1  : std_logic_vector (15 downto 0);
signal tensionDacSi2  : std_logic_vector (15 downto 0);
signal tensionDacCsi  : std_logic_vector (15 downto 0);
signal canal          : std_logic_vector (1 downto 0); -- le numéro de préampli
signal i2cWr, i2cDone : std_logic;
signal start          : std_logic;
type OffsetState is (IDLE, WAIT_DONE, SETTLE, DISPATCH);
signal offsetCs, offsetFs : OffsetState := IDLE;
signal timer, timerVal : std_logic_vector(10 downto 0);
signal loadTimer       : std_logic;
signal adjust_internal_n : std_logic_vector (3 downto 0);

signal dummy : std_logic;
--------------------------------------------------------------------------------------------------
begin

adjust_n <= adjust_internal_n (2 downto 0);
dummy <= or_reduce(slowCtBus.rd & slowCtBus.data(15 downto 10));

i2c_master: entity work.I2cMaster
  generic map (
    i2cAddr => 16#98#,
    PRESCALER  => PERIOD_I2C / 4
    --PRESCALER  => 4 -- pour la simu
  )
  port map (
    reset => reset,
    clk   => clk,
    ---
    data  => tensionDac,
    wr    => i2cWr,
    done  => i2cDone,
    ---
    scl   => scl,
    sda   => sda
  );
--------------------------------------------------------------------------------------------------
 timer_p: process (reset, clk)
 begin
   if reset = '1' then
     timer <= (others => '0');
   elsif rising_edge(clk) then
     if loadTimer = '1' then
       timer <= timerVal;
     elsif timer /= 0 then --(others => '0') then
       timer <= timer - 1;
     end if;
   end if;
 end process;
 
--------------------------------------------------------------------------------------------------
-- machine d'état
-- idle, wait, settle, clock
offsetSeq: process (reset, clk)
begin
  if reset = '1' then
    offsetCs <= IDLE;
  elsif rising_edge(clk) then
    offsetCs <= offsetFs;
  end if;
end process;

--------------------------------------------------------------------------------------------------
offsetComb: process (offsetCs, start, i2cDone, timer, canal)
--subtype mon_range is integer range 0 to 2;
--variable indice : mon_range;
  begin
    offsetFs  <= offsetCs;
    loadTimer <= '0';
    timerVal  <= (others => '0');
    adjust_internal_n <= "1111"; -- à priori au repos
    i2cWr <= '0';
    --indice := conv_integer(canal);
    case offsetCs is
    ------------------------------
    when IDLE      =>
      if start = '1' then
        i2cWr <= '1';
        offsetFs <= WAIT_DONE;
      end if;
    ------------------------------
    when WAIT_DONE => -- attente fin de transaction I2C
      if i2cDone = '1' then
        timerVal    <= conv_std_logic_vector(DAC6571_SETTLING, 11); -- 20 µs
        --timerVal    <= conv_std_logic_vector(20, 11); -- pour la simulation
        loadTimer <= '1';
        offsetFs <= SETTLE;     
      end if;
    ------------------------------
    when SETTLE    => -- attente stabilisation DAC
      if timer = 0 then
        timerVal    <= conv_std_logic_vector(DS4305_STROBE, 11); -- durée min du strobe_n 100 ns
        loadTimer <= '1';
        offsetFs <= DISPATCH;
      end if;
    ------------------------------
    when DISPATCH  => -- faire durer le strobe
    -- la taille du vecteur adjust_internal_n doit être une puissance entière de deux
      adjust_internal_n(conv_integer(canal)) <= '0'; -- activer le strobe
      if timer = 0 then
        offsetFs <= IDLE;
      end if;
    end case;
end process;

--------------------------------------------------------------------------------------------------
regLoad: process (clk, reset)
begin
  if reset = '1' then
    tensionDac <= (others => '0');
  elsif rising_edge(clk) then
    start <= '0';
	 slowCtBusRd <= (others => '0');

--    --partie programmée par Pierre	 
--    if slowCtBus.wr = '1' and
--       slowCtBus.addr(SC_TOP downto OFFSET_FIELD) =
--                      RegAd(SC_TOP downto OFFSET_FIELD) then
--      tensionDac <= "0000" & slowCtBus.data(9 downto 0) & "00"; -- voir DAC6571 page 16/17
--      canal      <= slowCtBus.addr(1 downto 0);
--      start      <= '1';
--    end if;
	 
-- partie programmée par Franck	 
	 if slowCtBus.wr = '1' and slowCtBus.addr(SC_TOP downto OFFSET_FIELD) = RegAd(SC_TOP downto OFFSET_FIELD) then
      tensionDac <= "0000" & slowCtBus.data(9 downto 0) & "00"; -- voir DAC6571 page 16/17
      canal      <= slowCtBus.addr(1 downto 0);
		
		case slowCtBus.addr(1 downto 0) is
		  when "00" => tensionDacSi1 <= "0000" & slowCtBus.data(9 downto 0) & "00";
		  when "01" => tensionDacSi2 <= "0000" & slowCtBus.data(9 downto 0) & "00";
		  when "10" => tensionDacCsi <= "0000" & slowCtBus.data(9 downto 0) & "00";
		  when others => null;
		end case;
      start      <= '1';
    end if;
	 
	 if slowCtBus.wr = '1' then
	 
	 end if;
	 
	 if slowCtBus.rd = '1' and slowCtBus.addr(SC_TOP downto OFFSET_FIELD) = RegAd(SC_TOP downto OFFSET_FIELD) then
	   case slowCtBus.addr(1 downto 0) is
		  when "00" =>	slowCtBusRd(15 downto 0) <= "00" & tensionDacSi1(15 downto 2);
		  when "01" =>	slowCtBusRd(15 downto 0) <= "00" & tensionDacSi2(15 downto 2);
		  when "10" =>	slowCtBusRd(15 downto 0) <= "00" & tensionDacCsi(15 downto 2);
		  when others => null;
		end case;
	 end if;
  end if;
end process regLoad;

--------------------------------------------------------------------------------------------------
end Behavioral;

