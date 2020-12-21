--===============================================================================================
-- Company:  IPN Orsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:    14/10/2011
--
-- Project Name:   fazia
-- Design Name:    telescope
-- Module Name:    FastChannel - Behavioral 
-- Target Devices: virtex-5
-- Tool versions:  ISE 12.4
-- Company: IPN Orsay
-- Engineer: Pierre EDELBRUCK
-- 
-- Description:
-- Nouvelle version (14-10-2011) basée sur waver et reader
-- 
--===============================================================================================
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;

--===============================================================================================
entity FastChannel is
  generic (
    AdcNr     : integer; -- numéro de l'ADC utilisé par adc_monitor
    reverse   : boolean;
    detId    : integer;
    WaveId    : integer;
    ---
    RegAd     : std_logic_vector(SC_TOP downto 0); -- adresse de base des registres de ce module
    MebAd     : std_logic_vector(SC_TOP downto 0); -- adresse mémoire meb
    SegAd     : std_logic_vector(SC_TOP downto 0); -- adresse mémoire segments
    ---
    CirSize   : integer;   -- taille en mots de cirbuf
    MebSize   : integer;   -- taille en mots de MEB
    SegSize   : integer    -- taille en mots de la mémoire segments
  );
  port (
    clk        : in   std_logic;
    clk25MHz   : in   std_logic;
    sync       : in   std_logic;
    reset      : in   std_logic;
    clear      : in  std_logic;
    telId     : in   std_logic_vector (3 downto 0);
    -- KAD 5514 --------------------------------------------
    adcIn_n    : in   std_logic_vector (7 downto 0);
    adcIn_p    : in   std_logic_vector (7 downto 0);
    ckAdc_n    : in   std_logic;
    ckAdc_p    : in   std_logic;
    --------------------------------------------------------
    segNrRd    : in   std_logic_vector (SEG_BITS-1 downto 0);
    segNrWr    : in   std_logic_vector (SEG_BITS-1 downto 0);
    acqBusyIn  : in   std_logic;
    acqBusyOut : out  std_logic;
    ---
    dataIn     : in   std_logic_vector (DATA_WITH_TAG-1 downto 0); -- bit 8 = strobe
    dataOut    : out  std_logic_vector (DATA_WITH_TAG-1 downto 0);
	 saveWave   : in   boolean;	 
    throttle   : in   std_logic;
    readIn     : in   std_logic;
    readOut    : out  std_logic;
    doneIn     : in   std_logic;
    doneOut    : out  std_logic;
    ---
    readerStateMach : out std_logic_vector (3 downto 0);
    readerErrBit    : out std_logic;
    ---
    --abort      : in   std_logic;
    val        : in   std_logic;
    --------------------------------
    streamOut  : out  std_logic_vector(ADC_TOP downto 0);  -- flux temps réel vers DAC rapide
    --------------------------------         -- à faire produire ultérieurement par 'decimator'
    alignBus     : in  alignBusRec;
    alignDataBit : out std_logic;
    inspect      : out std_logic;
    --------------------------------
    slowCtBus   : in   slowCtBusRec;
    slowCtBusRd : out  std_logic_vector (15 downto 0)
  );
end FastChannel;

--===============================================================================================

architecture Behavioral of FastChannel is

-- signaux =====================================================================================

-- les liaissons DDR
signal adcIn    :  std_logic_vector(ADC_TOP downto 0); -- signal en sortie de DDR
signal decimated:  std_logic_vector(ADC_TOP downto 0); -- signal rééchantillonné @ 50 MHz avec adcClk
signal mainStream: std_logic_vector(ADC_TOP downto 0); -- le même rééchantillonné  avec sysClk
signal adcClk   :  std_logic;
--signal getLocal, doneLocal : std_logic;
--signal dataLocal : std_logic_vector(15 downto 0);

signal clk25MHzLate : std_logic;
signal phaseCnter   : std_logic_vector(2 downto 0); -- compteur de phase @ 4ns modulo 20 ns
signal phaser       : std_logic_vector(2 downto 0); -- registre de programmation de la phase

-- La machine d'état d'acquisition =============================================================

type AcqState is (
  IDLE, WRITING, ACQUIT
);

signal acqCs, acqFs : AcqState := IDLE;
signal busy : std_logic;

signal inspectSource : std_logic_vector (RT_STREAM_SCE_BITS-1 downto 0);

--signal terminate : std_logic; -- pas besoin car pas d'item pour l'instant

-------------------------------------------------------------------------------------------------
begin
streamOut <=
       mainStream    when inspectSource = "001"
  else (others => '0');

----------------------- DDR KAD 5514 --------------------
ddr_16_1: entity work.DDR_ADC
  generic map (
    ADC_NR => AdcNr,
    D0 => 0, D1 => 0, D2 => 0, D3 => 0,
    D4 => 0, D5 => 0, D6 => 0, D7 => 0,
    reverse => reverse,
    speed => 250)
  port map (
    sysClk       => clk,
    sync         => sync,
    ---
    inputClk_n   => ckAdc_n,
    inputClk_p   => ckAdc_p,
    input_n      => adcIn_n,
    input_p      => adcIn_p,
    ---
    ddrOut(15 downto ADC_TOP+1) => open,
    ddrOut(ADC_TOP downto 0) => adcIn,
    outputClk    => adcClk,
    ---
    alignBus     => alignBus,
    alignDataBit => alignDataBit,
    inspect      => inspect
  );
      
----------------------------------------------------------
waverFast: entity work.Waver
  generic map (
    Regad    => RegAd,
    detId   => detId,
    WaveId   => WaveId,
    ---
    --CircAd   => CircAd,
    MebAd    => MebAd,
    SegAd    => SegAd,
    ---
    CirSize  => CirSize,
    MebSize  => MebSize,
    SegItems => SEG_FAST_ITEMS
  )
  port map (
    clk          => clk,
    reset        => reset,
    clear        => clear,
    telId       => telId,
    ---
    adcClk       => adcClk,
    adcIn        => adcIn,
    filterIn     => ALL_ZERO(ADC_TOP downto 0),
    filterSource => "00", -- pas de filtre pour fast channel
    ---
    val         => val,
    segNrWr     => segNrWr,
    busyPort    => busy,
    itemNr      => (others => '0'), --itemAddr,
    itemData    => (others => '0'), --itemData,
    itemWr      => '0', --itemWr,
    terminate   => '1',
    ---
--    throttle    => getLocal,
    throttle    => throttle,
    doneIn      => doneIn,
    doneOut     => doneOut,
    segNrRd     => segNrRd,
	 saveWaveIn  => saveWave,	 
    dataRemote  => dataIn,
    dataOut     => dataOut,
    ---
    readerStateMach => readerStateMach,
    readerErrBit    => readerErrBit,
    ---
    readIn      => readIn,
    readOut     => readOut,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRd
  );

--======================== la machine d'acquisition =============================================

acqSeq: process (reset, clk)
begin
  if reset = '1' then
    acqCs <= IDLE;
  elsif rising_edge(clk) then
    if clear = '1' then
      acqCs <= IDLE;
    else
      acqCs <= acqFs;
    end if;
  end if;
end process;

-------------------------------------------------------------------------------------------------
acqComb: process (acqCs, val, busy, acqBusyIn)
begin
  acqFs   <= acqCs;
  case acqCs is
  -----------------------------------------------------
  when IDLE =>
    acqBusyOut <= '0';
    if val = '1' then
      acqBusyOut <= '1';
      acqFs  <= WRITING;
    end if;
  -----------------------------------------------------
  when WRITING =>
    acqBusyOut <= '1';
    if busy = '0' then -- attente fin du process rapide
      acqFs <=  ACQUIT;
    end if;
  -----------------------------------------------------
  when ACQUIT =>
    acqBusyOut <= acqBusyIn;
    if val = '0' then
      acqFs  <= IDLE;
    end if;
  end case;
end process;

-- le décimateur qui génère le flux de données streamOut ----------------------------------------

--decimator: process (adcClk) -- cadencé à 250 MHz
--begin
--  if rising_edge(adcClk) then
--    clk25MHzLate <= clk25MHz;
--    if (clk25MHz = '1' and clk25MHzLate = '0') or
--       (clk25MHz = '0' and clk25MHzLate = '1') then
--      phaseCnter <= (others => '0'); -- modulo 20 ns
--    else
--      phaseCnter <= phaseCnter + 1;
--    end if;
--  
--    if phaseCnter = phaser then
--      decimated <= adcIn; -- échantillonnage modulo 20 ns sur horloge adc
--    end if;
--  end if;
--end process;
-------------------------------
--fluxGen: process (clk)
--begin
--  if rising_edge(clk) then
--    mainStream <= decimated;
--  end if;
--end process;

--===============================================================================================  
--    Gestion des registres
--===============================================================================================

regLoad: process (clk, reset, slowCtBus)
variable decod : std_logic;
variable lowerField : std_logic_vector(FAST_FLD-1 downto 0); -- pour faciliter le décodage

begin
  if slowCtBus.addr(SC_TOP downto FAST_FLD) = RegAd(SC_TOP downto FAST_FLD)
  then decod := '1';
  else decod := '0';
  end if;
  lowerField := slowCtBus.addr(FAST_FLD-1 downto 0);
  
  if reset = '1' then
    phaser <= (others => '0');
  elsif rising_edge(clk) then
    if slowCtBus.wr = '1' and decod = '1' and lowerField = DECIMATOR_PHASE then
      phaser <= slowCtBus.data(2 downto 0);
    elsif slowCtBus.wr = '1' and slowCtBus.addr(SC_TOP downto INSPECT_FIELD) =
                                 INSPECT_AD(SC_TOP downto INSPECT_FIELD) then
      if slowCtBus.addr(INSPECT_FIELD-1 downto 0) = AdcNr then
        inspectSource <= slowCtBus.data(RT_STREAM_SCE_BITS-1 downto 0);
      else
        inspectSource <= (others => '0');
      end if;
    end if; 
  end if;
end process;

end Behavioral;
