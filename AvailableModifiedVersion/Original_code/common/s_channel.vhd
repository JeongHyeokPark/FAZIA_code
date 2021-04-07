------------------------------------------------------------------------------------------
-- Company:  IPN Orsay
-- Engineer: Pierre EDELBRUCK
-- 
-- Create Date:    14/10/2011
--
-- Project Name:   fazia
-- Design Name:    telescope
-- Module Name:    SlowChannel - Behavioral 
-- Target Devices: virtex-5
-- Tool versions:  ISE 12.4
-- Company: IPN Orsay
-- Engineer: Pierre EDELBRUCK
-- Description: 
-- Nouvelle version (14-10-2011) basée sur waver et reader

-- Dependencies: 
--
-- Revision: 
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;

--===============================================================================================
entity SlowChannel is
  generic (
    AdcNr    : integer;
    reverse  : boolean; -- inversion à la demande des bits de donnée d'ADC
    detId   : integer;
    WaveId   : integer;
    ---
    RegAd    : std_logic_vector(SC_TOP downto 0);
    CircAd   : std_logic_vector(SC_TOP downto 0); -- buffer circulaire
    MebAd    : std_logic_vector(SC_TOP downto 0); -- adresse mémoire meb
    SegAd    : std_logic_vector(SC_TOP downto 0); -- mémoire segments
    HistoAd  : std_logic_vector(SC_TOP downto 0); -- mémoire histogrammer
    ---
    CirSize  : integer;   -- taille en mots de cirbuf
    MebSize  : integer;   -- taille en mots de MEB
    SegSize  : integer    -- taille en mots de la mémoire segments
  );
  port (
    clk         : in  std_logic;
    sync        : in  std_logic;
    reset       : in  std_logic;
    clear       : in  std_logic;
    telId      : in  std_logic_vector (3 downto 0);
    -- LTC2260 ---------------------------------------
    adcIn_n     : in  std_logic_vector (7 downto 0);
    adcIn_p     : in  std_logic_vector (7 downto 0);
    ckAdc_n     : in  std_logic;
    ckAdc_p     : in  std_logic;
    --------------------------------------------------
    segNrRd     : in  std_logic_vector(SEG_BITS-1 downto 0);  -- N° de seg à lire
    segNrWr     : in  std_logic_vector(SEG_BITS-1 downto 0);  -- N° de seg à créer
    acqBusyIn   : in  std_logic;        -- carry du module précédent
    acqBusyOut  : out std_logic;        -- acquisition en cours
    ---
    dataIn      : in  std_logic_vector (DATA_WITH_TAG-1 downto 0);
    dataOut     : out std_logic_vector (DATA_WITH_TAG-1 downto 0);
    saveWave    : in  boolean;
    throttle    : in  std_logic;
    readIn      : in  std_logic;
    readOut     : out std_logic;
    doneIn      : in  std_logic;
    doneOut     : out std_logic;
    ---
    readerStateMach : out std_logic_vector (3 downto 0);
    readerErrBit    : out std_logic;
    ---
    --abort       : in  std_logic;        -- oublier l'acquisition en cours
    val         : in  std_logic;        -- ordre de commencer l'acquisition
    --------------------------------
    streamOut   : out  std_logic_vector(ADC_TOP downto 0);  -- flux temps rÃ©el vers DAC rapide
    --------------------------------
    alignBus    : in  alignBusRec;
    alignDataBit: out std_logic;
    inspect     : out std_logic;
    ---
    slowCtBus   : in  slowCtBusRec;
    slowCtBusRd : out std_logic_vector(SC_TOP downto 0);
    ---
    timer       : in  std_logic;       -- signal pÃ©riodique @ 1 Âµs destinÃ© aux shapers
    --------------------------------------------------
    trigFastH   : out std_logic;       -- sortie comparateur rapide seuil haut
    trigFastL   : out std_logic;       -- sortie comparateur rapide seuil bas
    trigSlow    : out std_logic        -- sortie comparateur lent
  );
    
end SlowChannel;

--===============================================================================================
architecture Behavioral of SlowChannel is

--=== paramétrage ===============================================================================
constant ITEM_HEAD_ENER : integer := 1; -- adresse du tag de l'énergie dans le buffer (itemAddr)
constant ITEM_LEN_ENER  : integer := 2; -- adresse de la longueur du champ énergie dans le buffer - en mots de 16 bits(itemAddr)
constant ITEM_RISE_TIME : integer := 3; -- adresse du temps de montée du filtre trapezoïdal pour une normalisation ultérieure
constant ITEM_ENER_H    : integer := 4; -- adresse de la partie H de l'énergie dans le buffer (itemAddr)
constant ITEM_ENER_L    : integer := 5; -- adresse de la partie L de l'énergie dans le buffer (itemAddr)
constant ITEM_HEAD_BASE : integer := 6; -- adresse du tag de l'énergie dans le buffer (itemAddr)
constant ITEM_LEN_BASE  : integer := 7; -- adresse de la longueur du champ énergie dans le buffer - en mots de 16 bits(itemAddr)
constant ITEM_BASE_H    : integer := 8; -- adresse de la partie haute de la ligne de base dans le buffer (itemAddr)
constant ITEM_BASE_L    : integer := 9; -- adresse de la partie basse de la ligne de base dans le buffer (itemAddr)
constant RecordBits     : integer := bits(SEG_SLOW_ITEMS+1); --  +1 pour pointeur fifo?

-- signaux ======================================================================================

-- les liaisons en sortie de DDR
signal adcIn      : std_logic_vector(ADC_TOP downto 0);
signal adcClk     : std_logic;
signal busy       : std_logic;

signal fluxToMeb   : std_logic_vector(ADC_TOP downto 0);
signal mainStream  : std_logic_vector(ADC_TOP downto 0);
signal filterStream: std_logic_vector(ADC_TOP downto 0);

--signal energyShaper  : std_logic_vector(ENER_WIDTH-1 downto 0);
--signal triggerShaper : std_logic_vector(TRIG_SHAPER_OUT_WIDTH-1 downto 0);
signal energyShaper  : std_logic_vector(ADC_TOP downto 0);
signal triggerShaper : std_logic_vector(ADC_TOP downto 0);
signal eRdy          : std_logic; -- fin de peaking
signal eReset        : std_logic; -- raz track & hold
signal riseTime      : std_logic_vector(9 downto 0); 
signal energyPeak    : std_logic_vector(ENER_WIDTH-1 downto 0); -- énergie peakée
signal itemData      : std_logic_vector(15 downto 0);
signal baselineMean  : std_logic_vector(ADC_TOP+BL_PRECISION_BITS downto 0);

signal slowCtBusRdMeb   : std_logic_vector(SC_TOP downto 0);
signal slowCtBusRdEner  : std_logic_vector(SC_TOP downto 0);
signal slowCtBusRdTrig  : std_logic_vector(SC_TOP downto 0);
signal slowCtBusRdHisto : std_logic_vector(SC_TOP downto 0);
signal itemAddr         : std_logic_vector(RecordBits-1 downto 0);

signal terminate     : std_logic;
signal itemWr        : std_logic;

type slowType is (IDLE, WAITING, ENERGY_HEADER, ENERGY_LENGTH, FILT_T_RISE, ENERGY_H, ENERGY_L, BASE_HEADER, BASE_LENGTH, BASE_H, BASE_L, ACQUIT);

signal slowCs, slowFs : slowType := IDLE;

-- registre de contrôle général

constant STATUS_BITS : integer := 1; -- pour éviter les warnings
-- status: bit 0: sélection vers MEB: 0= ADC, 1= sortie shaper
signal status        : std_logic_vector(STATUS_BITS-1 downto 0);
signal inspectSource : std_logic_vector (RT_STREAM_SCE_BITS-1 downto 0);
signal filterSource  : std_logic_vector (1 downto 0);

--===============================================================================================
begin

slowCtBusRd <= slowCtBusRdMeb or slowCtBusRdEner or slowCtBusRdTrig or slowCtBusRdHisto;

--fluxToMeb <= adcIn when status(0) = '0' -- uniquement les bits de poids fort
--                   else energyShaper; -- ++ signe
                   --else energyShaper(ENER_WIDTH-1 downto ENER_WIDTH - 16);

fluxToMeb    <= adcIn;
filterStream <= triggerShaper when filterSource = "01" else
                energyShaper  when filterSource = "10" else
                (others => '0');

-- resynchronisation des signaux d'ADC
syncStream: process (clk)
begin
  if rising_edge(clk) then
    mainStream <= adcIn;
  end if;
end process;
             
streamOut <=
       mainStream    when inspectSource = "001"
  else energyShaper  when inspectSource = "010"
  else triggerShaper when inspectSource = "011"
  else adcIn         when inspectSource = "100"
  else (others => '0');

acqBusyOut <= acqBusyIn or busy;

-- instantiation des composants

----------------------- DDR LTC 2260 --------------------
ddr_16_1: entity work.DDR_ADC
  generic map (
    ADC_NR => AdcNr,
    D0 => 0, D1 => 0, D2 => 0, D3 => 0,
    D4 => 0, D5 => 0, D6 => 0, D7 => 0,
    reverse => reverse,
    speed => 100)
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
    ddrOut(ADC_TOP downto 0)    => adcIn,
    outputClk    => adcClk,
    ---
    alignBus     => alignBus,
    alignDataBit => alignDataBit,
    inspect      => inspect
  );
      
----------------------------------------------------------
waverSlow: entity work.Waver
  generic map (
    Regad    => RegAd,
    detId   => detId,
    WaveId   => WaveId,
    --CircAd   => CircAd,
    MebAd    => MebAd,
    SegAd    => SegAd,
    ---
    CirSize  => CirSize,
    MebSize  => MebSize,
    SegItems => SEG_SLOW_ITEMS
  )
  port map (
    clk          => clk,
    reset        => reset,
    clear        => clear,
    telId       => telId,
    ---
    adcClk       => adcClk,
    adcIn        => fluxToMeb,
    filterIn     => filterStream,
    filterSource => filterSource,
    ---
    val         => val,
    segNrWr     => segNrWr,
    busyPort    => busy,
    itemNr      => itemAddr,
    itemData    => itemData,
    itemWr      => itemWr,
    terminate   => terminate,
    ---
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
    slowCtBusRd => slowCtBusRdMeb
  );

---------------------------------------------------------
blockNrj: entity work.Energy
  generic map (
    Regad => RegAd or ENERGY_SC, -- ENERGY_SC vaut x"0010"
    DEFAULT_RISE    => DEFAULT_RISE_SI,
    DEFAULT_PLATEAU => DEFAULT_PLATEAU_SI,
    DEFAULT_PEAKING => DEFAULT_PEAKING_SI,
    DEFAULT_SHAPER_FLAT_WIDTH => DEFAULT_SHAPER_FLAT_WIDTH_SI
  )
  port map (
    clk         => clk,
    reset       => reset,
    ---
    eRdyPort    => eRdy,
    eReset      => eReset,
    riseTimeOut => riseTime,
    energy      => energyPeak,
    streamIn    => mainStream,
    streamOut(ENER_WIDTH-1 downto ENER_WIDTH-ADC_DATA_W) => energyShaper,
    streamOut(ENER_WIDTH-ADC_DATA_W-1 downto 0) => open,
    trigSlow    => trigSlow,
    ---
    timer       => timer,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdEner
    );
    
---------------------------------------------------------
blockTrig: entity work.ETrigger
  generic map (Regad => RegAd or E_TRIGGER_SC)
  port map (
    clk        => clk,
    reset      => reset,
    ---
    streamIn   => mainStream,
    streamOut(TRIG_SHAPER_OUT_WIDTH-1 downto TRIG_SHAPER_OUT_WIDTH-ADC_DATA_W) => triggerShaper,
    streamOut(TRIG_SHAPER_OUT_WIDTH-ADC_DATA_W-1 downto 0) => open,
    avgBaseOut => baselineMean,
    trigFastH  => trigFastH,
    trigFastL  => trigFastL,
    ---
    slowCtBus  => slowCtBus,
    slowCtBusRd => slowCtBusRdtrig,
    ---
    timer      => timer
  );

---------------------------------------------------------
blockHisto: if HistoAd /= x"0000" generate -- adresse mémoire histogrammer sert de validateur
monHisto: entity work.Histogrammer
  generic map (
    --RegAd       => RegAd or ENERGY_SC,
    RegAd       => RegAd,
    HistoAd     => HistoAd
  )
  port map (
    clk         => clk,
    reset       => reset,
    ---
    dataIn      => energyPeak,
    fire        => eRdy,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdHisto
  );
end generate;

--===============================================================================================
--    Machine d'état
--===============================================================================================

slowSeq: process (reset, clk)
begin
  if reset = '1' then
    slowCs <= IDLE;
  elsif rising_edge(clk) then
    if clear = '1' then
      slowCs <= IDLE;
    else
      slowCs <= slowFs;
    end if;
  end if;
end process;

------------------------------------
slowComb: process (slowCs, val, eRdy, riseTime, energyPeak, baselineMean)
begin
  slowFs    <= slowCs;
  eReset    <= '0';
  itemAddr  <= (others => '0'); -- hygiène
  itemWr    <= '0';
  itemData  <= (others => '0'); -- hygiène
  terminate <= '0';
  case slowCs is
  ----------------------------------
  when IDLE =>
    if val = '1' then
      eReset <= '1';
      slowFs <= WAITING;
    end if;
  ----------------------------------
  when WAITING => -- On attend que l'énergie soit prête dans le bloc Energy
    if eRdy = '1' then
      slowFs <= ENERGY_HEADER;
    end if;
  ----------------------------------
  when ENERGY_HEADER => -- écriture du tag
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_HEAD_ENER, RecordBits);
    itemData(15 downto 12) <= '0'&'1'&'1'&'1'; -- c'est le protocole : MSBs = '0111' if data tag
    itemData(11 downto 0) <= SS_ENER_TAG; 
    slowFs <= ENERGY_LENGTH;
  ----------------------------------		 
  when ENERGY_LENGTH => -- écriture de la longueur du champ (en mots 16 bits)
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_LEN_ENER, RecordBits);
    itemData(15) <= '0'; -- c'est le protocole : MSBs = '0' if data
    itemData(14 downto 0) <= conv_std_logic_vector(SS_ENER_LEN, 15); 
    slowFs <= FILT_T_RISE;
  ----------------------------------	
  when FILT_T_RISE => -- écriture du temps de montée du trapèze (en mots 16 bits)
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_RISE_TIME, RecordBits);
    itemData(15) <= '0'; -- c'est le protocole : MSBs = '0' if data
    itemData(14 downto 0) <= '0'&'0'&'0'&'0'&'0'& riseTime; 
    slowFs <= ENERGY_H;
  ----------------------------------	  
-- L'énergie peakée doit avoir une largeur supérieure à 16 et inférieure à 32 bits

--                    |-- ENER_WIDTH-15           |
--                    |                           |
--|15|14|13|12|11|10|09|08|07|06|05|04|03|02|01|00|15|14|13|12|11|10|9|8|7|6|5|4|3|2|1|0|
--|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | | | | | | | | | | |
--|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10|9|8|7|6|5|4|3|2|1|0|
--                          |                     |
--                          |-- ENER_WIDTH -1     |

  when ENERGY_H => -- On attend que l'énergie soit prête dans le bloc Energy
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_ENER_H, RecordBits);
    itemData(15) <= '0'; -- c'est le protocole : MSB = '0' if data
    for i in 14 downto ENER_WIDTH-15 loop      -- remplissage avec ext. de signe
      itemData(i) <= energyPeak(ENER_WIDTH-1); -- signe
    end loop;
    itemData(ENER_WIDTH-16 downto 0) <= energyPeak(ENER_WIDTH-1 downto 15); -- partie basse
    slowFs <= ENERGY_L;
  ----------------------------------
  when ENERGY_L =>
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_ENER_L, RecordBits);
    itemData <= '0' & energyPeak(14 downto 0); -- 15 bits significatifs precedés de '0' (MSB = '0' if data)
    slowFs <= BASE_HEADER;
  ----------------------------------	 
  when BASE_HEADER => -- écriture du tag
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_HEAD_BASE, RecordBits);
    itemData(15 downto 12) <= '0'& '1'&'1'&'1'; -- c'est le protocole : MSBs = '0111' if data tag
    itemData(11 downto 0) <= BASE_TAG; 
    slowFs <= BASE_LENGTH;
  ----------------------------------		 
  when BASE_LENGTH => -- écriture de la longueur du champ (en mots 16 bits)
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_LEN_BASE, RecordBits);
    itemData(15) <= '0'; -- c'est le protocole : MSBs = '0' if data
    itemData(14 downto 0) <= conv_std_logic_vector(BASE_LEN, 15); 
    slowFs <= BASE_H;
  ----------------------------------		 
  when BASE_H =>
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_BASE_H, RecordBits);
	 itemData(15) <= '0'; -- c'est le protocole : MSB = '0' if data
	 for i in 14 downto BL_TOP-15 loop   -- remplissage avec ext. de signe
	   itemData(i) <= baselineMean(BL_TOP);  -- signe
	 end loop;
    itemData(BL_TOP-16 downto 0) <= baselineMean(BL_TOP-1 downto 15); 
    slowFs <= BASE_L;
  ----------------------------------		 
  when BASE_L =>
    itemWr <= '1';
    itemAddr <= conv_std_logic_vector(ITEM_BASE_L, RecordBits);
    itemData <= '0' & baselineMean(14 downto 0); -- 15 bits significatifs precedés de "0" (MSB = '0' if data)
    slowFs <= ACQUIT;
  ----------------------------------
  when ACQUIT => -- attendre que val redescende
    terminate <= '1';
    if val = '0' then
      slowFs <= IDLE;
    end if;
  ----------------------------------
  end case;
end process;


--===============================================================================================  
--    Gestion des registres
--===============================================================================================

regLoad: process (clk, reset, slowCtBus)

-- une petite variable (decod) pour le chip-select du module
variable decod : std_logic;

-- isolation du champ d'en bas
variable lowerField : std_logic_vector(LEV_SLOW_FLD-1 downto 0); -- pour faciliter le décodage

-- L'adresse _AD est reconnue par tous les modules slow et fast
-- Chaque voie SlowChannel ou FastChannel possède un bus de sortie destiné à l'inspection
-- analogique en temps réel au moyen d'un dac rapide. Les 6 bus sont réunis par une fonction 
-- 'ou' au top level. Il est donc indispensable qu'une voie dont la sortie inspection n'est pas
-- en cours d'utilisation ait son bus d'inspection positionné à 0. Chaque voie reconnaît toutes 
-- les transactions d'inspection et positionne son bus en conséquence (à zéro si c'est une autre
-- voie qui est sélectionnée)
-- Le registre status servait jadis à sélectionner le flux d'entrée de la mémoire MEB
-- (adc normal ou sortie de shaper). Cette fonction n'existe plus bien que le registre status
-- soit toujours là.

begin
  if slowCtBus.addr(SC_TOP downto LEV_SLOW_FLD) = RegAd(SC_TOP downto LEV_SLOW_FLD)
  then decod := '1';
  else decod := '0';
  end if;
  lowerField := slowCtBus.addr(LEV_SLOW_FLD-1 downto 0);
  
  if reset = '1' then
    status <= (others => '0');
    inspectSource <= (others => '0');
  elsif rising_edge(clk) then
    if slowCtBus.wr = '1' and decod = '1' then
       case lowerField is
         when SLOW_STATUS => status <= slowCtBus.data(STATUS_BITS-1 downto 0);
         when FILTER_SCE  => filterSource <= slowCtBus.data(1 downto 0);
         when others      => null;
       end case;
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


