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
-- Nouvelle version (14-10-2011) base sur waver et reader

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
use work.telescope_conf.all;

--===============================================================================================
entity CsiChannel is
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
    Histo1   : std_logic_vector(SC_TOP downto 0); -- mémoire histogrammer total
    Histo2   : std_logic_vector(SC_TOP downto 0); -- mémoire histogrammer fast
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
    streamOut   : out  std_logic_vector(ADC_TOP downto 0);  -- flux temps réel vers DAC rapide
    --------------------------------
    alignBus    : in  alignBusRec;
    alignDataBit: out std_logic;
    inspect     : out std_logic;
    ---
    slowCtBus   : in  slowCtBusRec;
    slowCtBusRd : out std_logic_vector(SC_TOP downto 0);
    ---
    timer       : in  std_logic;       -- signal périodique @ 1 µs destiné aux shapers
    --------------------------------------------------
    trigFastH   : out std_logic;       -- sortie comparateur rapide seuil haut
    trigFastL   : out std_logic;       -- sortie comparateur rapide seuil bas
    trigSlow    : out std_logic        -- sortie comparateur lent
  );
    
end CsiChannel;

--===============================================================================================
architecture Behavioral of CsiChannel is

--=== paramtrage ===============================================================================
constant HEADER_CSI_TOT  : integer := 1; -- adresse du tag de l'nergie totale dans le buffer (itemAddr)
constant LEN_CSI_TOT     : integer := 2; -- adresse de la longueur du champ nergie totale dans le buffer - en mots de 16 bits(itemAddr)
constant ITEM_RISE_TOT   : integer := 3; -- adresse du temps de mont�e du filtre trapezo�dal pour une normalisation ult�rieure
constant ITEM_TOT_H      : integer := 4; -- adresse de la partie H de l'nergie totale dans le buffer (itemAddr)
constant ITEM_TOT_L      : integer := 5; -- adresse de la partie L de l'nergie totale dans le buffer (itemAddr)
constant HEADER_CSI_FAST : integer := 6; -- adresse du tag de l'nergie dans le buffer (itemAddr)
constant LEN_CSI_FAST    : integer := 7; -- adresse de la longueur du champ nergie dans le buffer - en mots de 16 bits(itemAddr)
constant ITEM_RISE_FAST  : integer := 8; -- adresse du temps de mont�e du filtre trapezo�dal pour une normalisation ult�rieure
constant ITEM_FAST_H     : integer := 9; -- adresse de la partie H de l'nergie rapide dans le buffer (itemAddr)
constant ITEM_FAST_L     : integer := 10; -- adresse de la partie L de l'nergie rapide dans le buffer (itemAddr)
constant HEADER_CSI_BASE : integer := 11; -- adresse du tag de l'nergie dans le buffer (itemAddr)
constant LEN_CSI_BASE    : integer := 12; -- adresse de la longueur du champ nergie dans le buffer - en mots de 16 bits(itemAddr)
constant ITEM_BASE_H     : integer := 13; -- adresse de la partie haute de la ligne de base dans le buffer (itemAddr)
constant ITEM_BASE_L     : integer := 14; -- adresse de la partie basse de la ligne de base dans le buffer (itemAddr)
constant RecordBits  : integer := bits(SEG_CSI_ITEMS+1);

-- signaux ======================================================================================

-- les liaisons en sortie de DDR
signal adcIn                       : std_logic_vector(ADC_TOP downto 0);
signal adcClk                      : std_logic;
signal busy                        : std_logic;

signal fluxToMeb                   : std_logic_vector(ADC_TOP downto 0);
signal mainStream                  : std_logic_vector(ADC_TOP downto 0);
signal filterStream                : std_logic_vector(ADC_TOP downto 0);

signal nrjShaperTot, nrjShaperFast : std_logic_vector(ADC_TOP downto 0);
signal triggerShaper               : std_logic_vector(ADC_TOP downto 0);
signal eRdyTot, eRdyFast           : std_logic; -- fin de peaking
signal eReset                      : std_logic; -- raz track & hold
signal riseTimeTot, riseTimeFast   : std_logic_vector(9 downto 0);
signal energyTot, energyFast       : std_logic_vector(ENER_WIDTH-1 downto 0); -- nergies peakes
signal itemData                    : std_logic_vector(15 downto 0);
signal baselineMean                : std_logic_vector(BL_TOP downto 0);

signal slowCtBusRdMeb              : std_logic_vector(SC_TOP downto 0);
signal slowCtBusRdTot              : std_logic_vector(SC_TOP downto 0);
signal slowCtBusRdFast             : std_logic_vector(SC_TOP downto 0);
signal slowCtBusRdTrig             : std_logic_vector(SC_TOP downto 0);
signal slowCtBusRdHisto1           : std_logic_vector(SC_TOP downto 0);
signal slowCtBusRdHisto2           : std_logic_vector(SC_TOP downto 0);
signal itemAddr                    : std_logic_vector(RecordBits-1 downto 0);

signal terminate                   : std_logic;
signal itemWr                      : std_logic;

signal nrjTotDone, nrjFastDone     : std_logic;

-- type slowType is (IDLE, WAITING, TOT_H, TOT_L, FAST_H, FAST_L, BASE_H, BASE_L, ACQUIT);
type slowType is (IDLE, WAITING, TOT_HEADER, TOT_LENGTH, TOT_T_RISE, TOT_H, TOT_L, FAST_HEADER, FAST_LENGTH, FAST_T_RISE, FAST_H, FAST_L, BASE_HEADER, BASE_LENGTH, BASE_H, BASE_L, ACQUIT);

signal slowState : slowType := IDLE;

-- registre de contrle gnral

constant STATUS_BITS : integer := 1; -- pour viter les warnings
-- status: bit 0: slection vers MEB: 0= ADC, 1= sortie shaper
signal status        : std_logic_vector(STATUS_BITS-1 downto 0);
signal inspectSource : std_logic_vector (RT_STREAM_SCE_BITS-1 downto 0);
signal filterSource  : std_logic_vector (1 downto 0);

signal ddrOut_i      : std_logic_vector (15 downto 0);
alias adcIn_i_0      : std_logic is ddrOut_i(0);
alias adcIn_i_1      : std_logic is ddrOut_i(1);
alias adcIn_i_2      : std_logic is ddrOut_i(2);
alias adcIn_i_3      : std_logic is ddrOut_i(3);
alias adcIn_i_4      : std_logic is ddrOut_i(4);
alias adcIn_i_5      : std_logic is ddrOut_i(5);
alias adcIn_i_6      : std_logic is ddrOut_i(6);
alias adcIn_i_7      : std_logic is ddrOut_i(7);
alias adcIn_i_8      : std_logic is ddrOut_i(8);
alias adcIn_i_9      : std_logic is ddrOut_i(9);
alias adcIn_i_10     : std_logic is ddrOut_i(10);
alias adcIn_i_11     : std_logic is ddrOut_i(11);
alias adcIn_i_12     : std_logic is ddrOut_i(12);
alias adcIn_i_13     : std_logic is ddrOut_i(13);

signal streamEnerFast_i  : std_logic_vector(ENER_WIDTH-1 downto 0);
alias nrjShaperFast_i_0  : std_logic is streamEnerFast_i(10);       -- ENER_WIDTH-ADC_DATA_W
alias nrjShaperFast_i_1  : std_logic is streamEnerFast_i(11);
alias nrjShaperFast_i_2  : std_logic is streamEnerFast_i(12);
alias nrjShaperFast_i_3  : std_logic is streamEnerFast_i(13);
alias nrjShaperFast_i_4  : std_logic is streamEnerFast_i(14);
alias nrjShaperFast_i_5  : std_logic is streamEnerFast_i(15);
alias nrjShaperFast_i_6  : std_logic is streamEnerFast_i(16);
alias nrjShaperFast_i_7  : std_logic is streamEnerFast_i(17);
alias nrjShaperFast_i_8  : std_logic is streamEnerFast_i(18);
alias nrjShaperFast_i_9  : std_logic is streamEnerFast_i(19);
alias nrjShaperFast_i_10 : std_logic is streamEnerFast_i(20);
alias nrjShaperFast_i_11 : std_logic is streamEnerFast_i(21);
alias nrjShaperFast_i_12 : std_logic is streamEnerFast_i(22);
alias nrjShaperFast_i_13 : std_logic is streamEnerFast_i(23);

signal streamEnerTot_i  : std_logic_vector(ENER_WIDTH-1 downto 0);
alias nrjShaperTot_i_0  : std_logic is streamEnerTot_i(10);       -- ENER_WIDTH-ADC_DATA_W
alias nrjShaperTot_i_1  : std_logic is streamEnerTot_i(11);
alias nrjShaperTot_i_2  : std_logic is streamEnerTot_i(12);
alias nrjShaperTot_i_3  : std_logic is streamEnerTot_i(13);
alias nrjShaperTot_i_4  : std_logic is streamEnerTot_i(14);
alias nrjShaperTot_i_5  : std_logic is streamEnerTot_i(15);
alias nrjShaperTot_i_6  : std_logic is streamEnerTot_i(16);
alias nrjShaperTot_i_7  : std_logic is streamEnerTot_i(17);
alias nrjShaperTot_i_8  : std_logic is streamEnerTot_i(18);
alias nrjShaperTot_i_9  : std_logic is streamEnerTot_i(19);
alias nrjShaperTot_i_10 : std_logic is streamEnerTot_i(20);
alias nrjShaperTot_i_11 : std_logic is streamEnerTot_i(21);
alias nrjShaperTot_i_12 : std_logic is streamEnerTot_i(22);
alias nrjShaperTot_i_13 : std_logic is streamEnerTot_i(23);

signal streamTrigger_i   : std_logic_vector(TRIG_SHAPER_OUT_WIDTH-1 downto 0);
alias triggerShaper_i_0  : std_logic is streamTrigger_i(6);       -- TRIG_SHAPER_OUT_WIDTH-ADC_DATA_W
alias triggerShaper_i_1  : std_logic is streamTrigger_i(7);
alias triggerShaper_i_2  : std_logic is streamTrigger_i(8);
alias triggerShaper_i_3  : std_logic is streamTrigger_i(9);
alias triggerShaper_i_4  : std_logic is streamTrigger_i(10);
alias triggerShaper_i_5  : std_logic is streamTrigger_i(11);
alias triggerShaper_i_6  : std_logic is streamTrigger_i(12);
alias triggerShaper_i_7  : std_logic is streamTrigger_i(13);
alias triggerShaper_i_8  : std_logic is streamTrigger_i(14);
alias triggerShaper_i_9  : std_logic is streamTrigger_i(15);
alias triggerShaper_i_10 : std_logic is streamTrigger_i(16);
alias triggerShaper_i_11 : std_logic is streamTrigger_i(17);
alias triggerShaper_i_12 : std_logic is streamTrigger_i(18);
alias triggerShaper_i_13 : std_logic is streamTrigger_i(19);
--===== chipscope ===============================================================================
signal all_zero_64 : std_logic_vector (64 downto 0) := (others => '0');
signal etat : std_logic_vector (2 downto 0);
signal CONTROL0 : std_logic_vector (35 downto 0);

component tel_ila_36
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK   : IN STD_LOGIC;
    TRIG0 : IN STD_LOGIC_VECTOR(35 DOWNTO 0));
end component;

component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
end component;

--===============================================================================================
begin

--===== chipscope ===============================================================================
make_chipscope: if chip_csi and (RegAd = Q3_SC) generate
mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0);
    
mes_sondes : tel_ila_36
  port map (
    CONTROL => CONTROL0,
    CLK      => adcClk,
    ---
    TRIG0 (2  downto  0) => etat,     --  3 bits
    TRIG0 (3)            => eRdyTot,
    TRIG0 (4)            => eRdyFast,
    TRIG0 (6 downto 5)   => itemAddr,
    trig0 (7)            => val,
    TRIG0 (35 downto 8)  => all_zero_64(35 downto 8)
 );
end generate;

etat <= conv_std_logic_vector(slowType'pos(slowState), 3);

slowCtBusRd <= slowCtBusRdMeb or
               slowCtBusRdTot or slowCtBusRdFast or
               slowCtBusRdTrig or
               slowCtBusRdHisto1 or slowCtBusRdHisto2;

--fluxToMeb <= adcIn when status(0) = '0' -- uniquement les bits de poids fort
--                   else energyShaper; -- ++ signe
                   --else energyShaper(ENER_WIDTH-1 downto ENER_WIDTH - 16);

fluxToMeb    <= adcIn;
filterStream <= triggerShaper when filterSource = "01" else
                nrjShaperTot  when filterSource = "10" else
                nrjShaperFast when filterSource = "11" else
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
  else nrjShaperTot  when inspectSource = "010"
  else triggerShaper when inspectSource = "011"
  else adcIn         when inspectSource = "100"
  else nrjShaperFast when inspectSource = "101"
  else (others => '0');

acqBusyOut <= acqBusyIn or busy;

-- instantiation des composants
adcIn <= (adcIn_i_13, adcIn_i_12, adcIn_i_11, adcIn_i_10, adcIn_i_9, 
          adcIn_i_8, adcIn_i_7,adcIn_i_6, adcIn_i_5, adcIn_i_4, adcIn_i_3, adcIn_i_2, adcIn_i_1, adcIn_i_0);  

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
--    ddrOut(15 downto ADC_TOP+1) => open,
--    ddrOut(ADC_TOP downto 0)    => adcIn,
    ddrOut       => ddrOut_i, 
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
    SegItems => SEG_CSI_ITEMS
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
nrjShaperTot <= (nrjShaperTot_i_13, nrjShaperTot_i_12, nrjShaperTot_i_11, nrjShaperTot_i_10, nrjShaperTot_i_9,
                 nrjShaperTot_i_8, nrjShaperTot_i_7, nrjShaperTot_i_6, nrjShaperTot_i_5, nrjShaperTot_i_4,
					  nrjShaperTot_i_3, nrjShaperTot_i_2, nrjShaperTot_i_1, nrjShaperTot_i_0);
					  
-- nergie totale
blockNrj: entity work.Energy
  generic map (
    Regad => RegAd or ENERGY_SC, -- ENERGY_SC vaut x"0010"
    DEFAULT_RISE    => DEFAULT_RISE_CSI_TOT,
    DEFAULT_PLATEAU => DEFAULT_PLATEAU_CSI_TOT,
    DEFAULT_PEAKING => DEFAULT_PEAKING_CSI_TOT,
	 DEFAULT_SHAPER_FLAT_WIDTH => DEFAULT_SHAPER_FLAT_WIDTH_CSI
  )
  port map (
    clk         => clk,
    reset       => reset,
    ---
    eRdyPort    => eRdyTot,
    eReset      => eReset,
	 riseTimeOut => riseTimeTot,
    energy      => energyTot,
    streamIn    => mainStream,
--    streamOut(ENER_WIDTH-1 downto ENER_WIDTH-ADC_DATA_W) => nrjShaperTot,
--    streamOut(ENER_WIDTH-ADC_DATA_W-1 downto 0) => open,
    streamOut   => streamEnerTot_i, 
    trigSlow    => trigSlow, -- seul le bloc nergie totale dlivre ce signal
    ---
    timer       => timer,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdTot
    );
    
---------------------------------------------------------
nrjShaperFast <= (nrjShaperFast_i_13, nrjShaperFast_i_12, nrjShaperFast_i_11, nrjShaperFast_i_10, nrjShaperFast_i_9,
                 nrjShaperFast_i_8, nrjShaperFast_i_7, nrjShaperFast_i_6, nrjShaperFast_i_5, nrjShaperFast_i_4,
					  nrjShaperFast_i_3, nrjShaperFast_i_2, nrjShaperFast_i_1, nrjShaperFast_i_0);
					  
-- nergie composante rapide
blockFastNrj: entity work.Energy
  generic map (
    Regad => RegAd or CSI_FAST or ENERGY_SC, -- CSI_FAST vaut x"0040"
    DEFAULT_RISE => DEFAULT_RISE_CSI_FAST,
    DEFAULT_PLATEAU => DEFAULT_PLATEAU_CSI_FAST,
    DEFAULT_PEAKING => DEFAULT_PEAKING_CSI_FAST,
	 DEFAULT_SHAPER_FLAT_WIDTH => DEFAULT_SHAPER_FLAT_WIDTH_CSI
  )
  port map (
    clk         => clk,
    reset       => reset,
    ---
    eRdyPort    => eRdyFast,
    eReset      => eReset,
	 riseTimeOut => riseTimeFast,
    energy      => energyFast,
    streamIn    => mainStream,
--    streamOut(ENER_WIDTH-1 downto ENER_WIDTH-ADC_DATA_W) => nrjShaperFast,
--    streamOut(ENER_WIDTH-ADC_DATA_W-1 downto 0) => open,
    streamOut   => streamEnerFast_i,
    trigSlow    => open, -- seul le bloc nergie totale dlivre ce signal
    ---
    timer       => timer,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdFast
    );
    
---------------------------------------------------------
triggerShaper <= (triggerShaper_i_13, triggerShaper_i_12, triggerShaper_i_11, triggerShaper_i_10, triggerShaper_i_9,
                 triggerShaper_i_8, triggerShaper_i_7, triggerShaper_i_6, triggerShaper_i_5, triggerShaper_i_4,
					  triggerShaper_i_3, triggerShaper_i_2, triggerShaper_i_1, triggerShaper_i_0);
					  
blockTrig: entity work.ETrigger
  generic map (Regad => RegAd or E_TRIGGER_SC)
  port map (
    clk        => clk,
    reset      => reset,
    ---
    streamIn   => mainStream,
--    streamOut(TRIG_SHAPER_OUT_WIDTH-1 downto TRIG_SHAPER_OUT_WIDTH-ADC_DATA_W) => triggerShaper,
--    streamOut(TRIG_SHAPER_OUT_WIDTH-ADC_DATA_W-1 downto 0) => open,
    streamOut  => streamTrigger_i,
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
blockHisto1: if Histo1 /= x"0000" generate
totHisto: entity work.Histogrammer
  generic map (
    --RegAd       => RegAd or ENERGY_SC,
    RegAd       => RegAd,
    HistoAd     => Histo1
  )
  port map (
    clk         => clk,
    reset       => reset,
    ---
    dataIn      => energyTot,
    fire        => eRdyTot,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdHisto1
  );
end generate;

blockHisto2: if Histo2 /= x"0000" generate
fastHisto: entity work.Histogrammer
  generic map (
    RegAd       => RegAd or CSI_FAST,
    HistoAd     => Histo2
  )
  port map (
    clk         => clk,
    reset       => reset,
    ---
    dataIn      => energyFast,
    fire        => eRdyFast,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdHisto2
  );
end generate;

--===============================================================================================
-- L'nergie peake doit avoir une largeur suprieure 16 et infrieure 32 bits

--                    |-- ENER_WIDTH-15           |
--                    |                           |
--|15|14|13|12|11|10|09|08|07|06|05|04|03|02|01|00|15|14|13|12|11|10|9|8|7|6|5|4|3|2|1|0|
--|  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  |  | | | | | | | | | | |
--|31|30|29|28|27|26|25|24|23|22|21|20|19|18|17|16|15|14|13|12|11|10|9|8|7|6|5|4|3|2|1|0|
--                          |                     |
--                          |-- ENER_WIDTH -1     |

--===============================================================================================
--    Machine d'tat
--===============================================================================================

slowSeq: process (reset, clear, clk)
begin
  if reset = '1' then
    slowState <= IDLE;
  elsif rising_edge(clk) then
    if clear = '1' then
      slowState <= IDLE;
    else
      case slowState is
      ----------------------------------
      when IDLE => -- 0
        if val = '1' then
          nrjTotDone  <= '0';
          nrjFastDone <= '0';
          slowState   <= WAITING;
        end if;
      ----------------------------------
      when WAITING => -- 1
        if eRdyTot = '1' and nrjTotDone = '0' then
          nrjTotDone <= '1';
          slowState   <= TOT_HEADER;
        end if;
        if eRdyFast = '1' and nrjFastDone = '0' then
          nrjFastDone <= '1';
          slowState   <= FAST_HEADER;
        end if;
        if nrjTotDone = '1' and nrjFastDone = '1' then	  
          slowState   <= BASE_HEADER;
        end if;
      ----------------------------------
      when TOT_HEADER => -- 2
        slowState   <= TOT_LENGTH;
      ----------------------------------		  
       when TOT_LENGTH => -- 3
        slowState   <= TOT_T_RISE;
      ----------------------------------	
      when TOT_T_RISE => -- 4
        slowState   <= TOT_H;
      ----------------------------------		  
      when TOT_H => -- 5
        slowState   <= TOT_L;
      ----------------------------------
      when TOT_L => -- 6
        slowState   <= WAITING;
      ----------------------------------
      when FAST_HEADER => -- 7
        slowState   <= FAST_LENGTH;
      ----------------------------------		  
       when FAST_LENGTH => -- 8
        slowState   <= FAST_T_RISE;
      ----------------------------------	
      when FAST_T_RISE => -- 9
        slowState   <= FAST_H;
      ----------------------------------				
      when FAST_H => -- 10
        slowState   <= FAST_L;
      ----------------------------------
      when FAST_L => -- 11
        slowState   <= WAITING;
      ----------------------------------
      when BASE_HEADER => -- 12
        slowState   <= BASE_LENGTH;
      ----------------------------------		  
      when BASE_LENGTH => -- 13
        slowState   <= BASE_H;
      ----------------------------------	    				
      when BASE_H => -- 14
        slowState   <= BASE_L;
      ----------------------------------	         				
      when BASE_L => -- 15
        slowState   <= ACQUIT;
      ----------------------------------		  
      when ACQUIT => -- attendre que val redescende -- 16
        if val = '0' then
          slowState <= IDLE;
        end if;
      ----------------------------------
      end case;
    end if;
    ----------------------------------
  end if;
end process;

-------------------------------------------------------------------------------------------------
slowComb: process (slowState, val, eRdyTot, nrjTotDone, eRdyFast, nrjFastDone, riseTimeTot, energyTot, riseTimeFast, energyFast, baselineMean)
begin
  eReset    <= '0';
  terminate <= '0';
  itemWr    <= '0';
  case slowState is
  ----------------------------------
  when IDLE =>
       if val = '1' then
          eReset    <= '1'; -- un seul clock
        end if;
  ----------------------------------
  when WAITING => null;
  ----------------------------------
  when TOT_HEADER => 
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(HEADER_CSI_TOT, RecordBits);
       itemData(15 downto 12) <= '0'& '1'&'1'&'1'; -- c'est le protocole : MSBs = '0111' if data tag
       itemData(11 downto 0) <= SS_ENER_TAG; 
  ----------------------------------		 
  when TOT_LENGTH => 
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(LEN_CSI_TOT, RecordBits);
       itemData(15) <= '0'; -- c'est le protocole : MSBs = '0' if data
       itemData(14 downto 0) <= conv_std_logic_vector(SS_ENER_LEN, 15); 	
  ----------------------------------
  when TOT_T_RISE => -- �criture de la longueur du champ (en mots 16 bits)
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(ITEM_RISE_TOT, RecordBits);
       itemData(15) <= '0'; -- c'est le protocole : MSBs = '0' if data
       itemData(14 downto 0) <= '0'&'0'&'0'&'0'&'0'& riseTimeTot; 
  ----------------------------------	  
  when TOT_H =>
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(ITEM_TOT_H, RecordBits);
       itemData(15) <= '0'; -- c'est le protocole
       for i in 14 downto ENER_WIDTH-15 loop     -- remplissage avec ext. de signe
          itemData(i) <= energyTot(ENER_WIDTH-1); -- signe
       end loop;
       itemData(ENER_WIDTH-16 downto 0) <= energyTot(ENER_WIDTH-1 downto 15); -- partie basse
  ----------------------------------
  when TOT_L =>
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(ITEM_TOT_L, RecordBits);
       itemData <= '0' & energyTot(14 downto 0); -- 15 bits significatifs prcds de '0'
  ----------------------------------
  when FAST_HEADER => 
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(HEADER_CSI_FAST, RecordBits);
       itemData(15 downto 12) <= '0'& '1'&'1'&'1'; -- c'est le protocole : MSBs = '0111' if data tag
       itemData(11 downto 0) <= FS_ENER_TAG; 
  ----------------------------------		 
  when FAST_LENGTH => 
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(LEN_CSI_FAST, RecordBits);
       itemData(15) <= '0'; -- c'est le protocole : MSBs = '0' if data
       itemData(14 downto 0) <= conv_std_logic_vector(FS_ENER_LEN, 15); 	
  ----------------------------------
  when FAST_T_RISE => -- �criture de la longueur du champ (en mots 16 bits)
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(ITEM_RISE_FAST, RecordBits);
       itemData(15) <= '0'; -- c'est le protocole : MSBs = '0' if data
       itemData(14 downto 0) <= '0'&'0'&'0'&'0'&'0'& riseTimeFast; 
  ----------------------------------	   
  when FAST_H =>
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(ITEM_FAST_H, RecordBits);
       itemData(15) <= '0'; -- c'est le protocole
       for i in 14 downto ENER_WIDTH-15 loop      -- remplissage avec ext. de signe
          itemData(i) <= energyFast(ENER_WIDTH-1); -- signe
       end loop;
       itemData(ENER_WIDTH-16 downto 0) <= energyFast(ENER_WIDTH-1 downto 15); -- partie basse
  ----------------------------------
  when FAST_L =>
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(ITEM_FAST_L, RecordBits);
       itemData <= '0' & energyFast(14 downto 0); -- 15 bits significatifs prcds de '0'
  ----------------------------------
  when BASE_HEADER => 
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(HEADER_CSI_BASE, RecordBits);
       itemData(15 downto 12) <= '0'& '1'&'1'&'1'; -- c'est le protocole : MSBs = '0111' if data tag
       itemData(11 downto 0) <= BASE_TAG; 
  ----------------------------------		 
  when BASE_LENGTH => 
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(LEN_CSI_BASE, RecordBits);
       itemData(15) <= '0'; -- c'est le protocole : MSBs = '0' if data
       itemData(14 downto 0) <= conv_std_logic_vector(BASE_LEN, 15); 	 
  ----------------------------------
  when BASE_H =>
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(ITEM_BASE_H, RecordBits);
	    itemData(15) <= '0'; -- c'est le protocole : MSB = '0' if data		 
	    for i in 14 downto BL_TOP-15 loop   -- remplissage avec ext. de signe
	       itemData(i) <= baselineMean(BL_TOP);  -- signe
	    end loop;
       itemData(BL_TOP-16 downto 0) <= baselineMean(BL_TOP-1 downto 15); 
  ----------------------------------
  when BASE_L =>
       itemWr <= '1';
       itemAddr <= conv_std_logic_vector(ITEM_BASE_L, RecordBits);
       itemData <= '0' & baselineMean(14 downto 0); -- 15 bits significatifs preced�s de "0" (MSB = '0' if data)		 
  ----------------------------------
  when ACQUIT =>
       terminate <= '1';
  ----------------------------------
  end case;
end process slowComb;

--===============================================================================================  
--    Gestion des registres
--===============================================================================================

regLoad: process (clk, reset, slowCtBus)

-- une petite variable (decod) pour le chip-select du module
variable decod : std_logic;

-- isolation du champ d'en bas
variable lowerField : std_logic_vector(LEV_SLOW_FLD-1 downto 0); -- pour faciliter le dcodage

-- L'adresse _AD est reconnue par tous les modules slow et fast
-- Chaque voie SlowChannel ou FastChannel possde un bus de sortie destin  l'inspection
-- analogique en temps rel au moyen d'un dac rapide. Les 6 bus sont runis par une fonction 
-- 'ou' au top level. Il est donc indispensable qu'une voie dont la sortie inspection n'est pas
-- en cours d'utilisation ait son bus d'inspection positionn  0. Chaque voie reconnat toutes 
-- les transactions d'inspection et positionne son bus en consquence (zro si c'est une autre
-- voie qui est slectionne)
-- Le registre status servait jadis slectionner le flux d'entre de la mmoire MEB
-- (adc normal ou sortie de shaper). Cette fonction n'existe plus bien que le registre status
-- soit toujours l.

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


