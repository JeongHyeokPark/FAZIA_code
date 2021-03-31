-------------------------------------------------------------------------------------------------
-- Company:   IPN Orsay
-- Engineer:  Pierre EDELBRUCK
-- 
-- Create Date:  13:01:26 07/28/2010 
-- Design Name:  telescope
-- Module Name:  AdcMon - Behavioral 
-- Project Name: fazia
-- Target Devices: virtex-5
-- Tool versions: ise 11.1 linux
-- Description: Ce module est instancié au top niveau du télescope, il comprend
-- les modules SpiAdc et  Aligner. Il émet les ordres d'alignement via l'alignBus et reçoit
-- les données des 6 modules de gestion d'ADC via les 6 fils alignDataBit
--
-- Dependencies:  tel_defs.vhd, align_defs.fhd
--
-- Revision 0.01 - File Created
-- Printed 27-01-2012
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;

--library fazia;
--use fazia.slow_ct_defs.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AdcMon is
  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    lock200MHz   : in  std_logic;
    -- les 6 ports SPI
    sClkPort     : out std_logic_vector(ADCS_TOTAL-1 downto 0);
    rstPort_n    : out std_logic_vector(ADCS_TOTAL-1 downto 0); -- utile seulement sur KAD5514
    csPort       : out std_logic_vector(ADCS_TOTAL-1 downto 0);
    sdoPort      : in  std_logic_vector(ADCS_TOTAL-1 downto 0);
    sdioPort     : out std_logic_vector(ADCS_TOTAL-1 downto 0);
    -- les données d'alignement
    alignBus     : out AlignBusRec;                              -- vers les demux
    alignDataBit : in  std_logic_vector (ADCS_TOTAL-1 downto 0); -- retour des demux
    inspect      : out std_logic;
    -- le slow control
    slowCtBus    : in  slowCtBusRec;
    slowCtBusRd  : out std_logic_vector (15 downto 0)
  );
end AdcMon;

architecture Behavioral of AdcMon is

-- composants ===================================================================================
component SpiAdc
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    slowCtBus   : in  slowCtBusRec;
    slowCtBusRd : out std_logic_vector (15 downto 0);
    adcNr       : out std_logic_vector (2 downto 0);  -- N° d'ADC
    cs          : out std_logic;
    sClk        : out std_logic;
    sdi         : out std_logic; -- on va toujours travailler en mode 4 fils
    sdo         : in  std_logic  -- attention, i et o vu du périphérique
  );
end component SpiAdc;
-------------------------------------------------------------------------------------------------
-- signaux 
signal cs       : std_logic;
signal sClk     : std_logic;
signal sdi      : std_logic;
signal sdo      : std_logic;
signal adcNr    : std_logic_vector(2 downto 0);
signal sdoP     : std_logic_vector(7 downto 0);
signal decod    : std_logic_vector(ADCS_TOTAL-1 downto 0);
signal slowCtBusRd0, slowCtBusRd1 : std_logic_vector (15 downto 0);

--signal rstPort_internal_n : std_logic_vector(ADCS_TOTAL-1 downto 0);
signal adcToBeReseted : std_logic_vector(2 downto 0);
signal startPulse : std_logic;
signal rstCnt   : std_logic_vector(3 downto 0);

-- pour la constante qui suit, voir l'affectation de sdoP
constant aux: std_logic_vector (7-ADCS_TOTAL downto 0) := (others => '0');

begin

--===============================================================================================

slowCtBusRd <= slowCtBusRd0 or slowCtBusRd1;
sdoP    <= aux & sdoPort;
inspect <= or_reduce(alignDataBit);

-- instanciation des composants -----------------------------------------------------------------
spi_inst: SpiAdc
  port map (
    clk         => clk,
    reset       => reset,
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRd0,
    adcNr       => adcNr,
    cs          => cs,
    sClk        => sClk,
    sdi         => sdi,
    sdo         => sdo
  );
-------------------------------------------------------------------------------------------------
aligneur: entity work.Aligner_new
  generic map (MemAdr => ALIGNER_MEM)
  port map (
    clk          => clk,
    reset        => reset,
    lock200MHz   => lock200MHz,
    ---
    --reLoad       => '0',
    alignBus     => alignBus,
    alignDataBit => alignDataBit,
    ---
    SlowCtBus    => SlowCtBus,
    slowCtBusRd  => slowCtBusRd1
  );

-------------------------------------------------------------------------------------------------  
-- dispatching statique des signaux spi

dispatch: for i in 0 to ADCS_TOTAL-1 generate
begin
  decod(i)    <= '1'  when adcNr = i else '0';
  csPort(i)   <= not cs   when decod(i) = '1' else '1'; -- logique négative
  sClkPort(i) <= sClk when decod(i) = '1' else '0';
  sdioPort(i) <= sdi  when decod(i) = '1' else '0';
end generate dispatch;

sdo <= sdoP(conv_integer(adcNr)); -- la taille de sdoP doit être une puissance entière de 2
                                  -- et adcNr doit être "statique"
-------------------------------------------------------------------------------------------------
-- génération du reset hardware des adcs
-- le numéro d'ADC est donné par la partie basse de l'adresse

rstProc: process (reset, clk)
begin
  if reset = '1' then
    rstPort_n <= "000000"; -- c'est un drain ouvert
  elsif rising_edge(clk) then
    if startPulse = '1' then
      rstCnt <= "1010"; -- 100 ns;
    end if;
    
    if rstCnt /= 0 then
      rstCnt <= rstCnt-1;
    end if;
    
    if rstCnt = 0 then
      rstPort_n <= "ZZZZZZ";
    else
      rstPort_n(conv_integer(adcToBeReseted)) <= '0'; -- sélection de l'ADC depuis le slow control
    end if;
  end if;
end process;

----------------------------------
registerProc: process (clk)
begin
  if rising_edge(clk) then
    startPulse <= '0';
    if slowCtBus.addr(SC_TOP downto 3) = ADC_CONTROL(SC_TOP downto 3) and slowCtBus.wr = '1' then
      adcToBeReseted <= slowCtBus.addr(2 downto 0);
      startPulse <= '1';
    end if;
  end if;
end process;
    

end Behavioral;

