----------------------------------------------------------------------------------
-- Company: IPN Orsay
-- Engineer: P. Edelbruck
-- 
-- Create Date:    13:16:00 12/10/2011 
-- Design Name: 
-- Module Name:    waver - Behavioral 
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions: ISE 12.4
-- Description:    voir en fin de fichier
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;
use work.telescope_conf.all;

--===============================================================================================
entity Waver is
  generic (
    detId   : integer;
    WaveId   : integer;
    ---
    RegAd    : std_logic_vector(SC_TOP downto 0);    -- adresse registres locaux
    -- CircAd   : std_logic_vector(SC_TOP downto 0); -- buffer circulaire
    MebAd    : std_logic_vector(SC_TOP downto 0);    -- mémoire meb
    SegAd    : std_logic_vector(SC_TOP downto 0);    -- mémoire segments
    ---
    CirSize  : integer; -- taille en mots du buffer circulaire
    MebSize  : integer; -- taille en mots du MEB
    SegItems : integer  -- nombre d'items de la mémoire segments (yc pointeur)
  );
  port ( 
    clk        : in std_logic; -- horloge système (100 MHz)
    reset      : in std_logic;
    clear      : in std_logic;
    telId     : in std_logic_vector(3 downto 0);
    --- section ADCs ---------------------------
    adcClk      : in std_logic; -- horloge ADC (100 ou 250 MHz)
    adcIn       : in std_logic_vector (ADC_TOP downto 0); -- entrées ADC depuis DDR
    filterIn    : in std_logic_vector (ADC_TOP downto 0); -- entrée vers MEB
    filterSource: in std_logic_vector (1 downto 0);       -- sélecteur de filterIn vers MEB
    --- section acquisition --------------------
    val        : in  std_logic;
    segNrWr    : in  std_logic_vector (SEG_BITS-1 downto 0);  -- Numéro de segment à enregistrer
    busyPort   : out std_logic;
    ---
    itemNr     : in  std_logic_vector(bits(SegItems+1)-1 downto 0);
    itemData   : in  std_logic_vector(15 downto 0);
    itemWr     : in  std_logic;
    terminate  : in  std_logic; -- signale la fin de l'acquisition vue de l'extérieur
    --- section lecture ------------------------    C'est comme un event-number local au telescope
    throttle   : in  std_logic;
    doneIn     : in  std_logic;
    doneOut    : out std_logic;
    segNrRd    : in  std_logic_vector (SEG_BITS-1 downto 0);
	 saveWaveIn : in  boolean;
    dataRemote : in  std_logic_vector (DATA_WITH_TAG-1 downto 0); -- données de l'étage au-dessus
    dataOut    : out std_logic_vector (DATA_WITH_TAG-1 downto 0); -- bit 8 = strobe
    ---
    readerStateMach : out std_logic_vector(3 downto 0);
    readerErrBit    : out std_logic;
    ---
    readIn     : in  std_logic;
    readOut    : out std_logic;
    --- slow control ---------------------------
    slowCtBus  : in  slowCtBusRec;
    slowCtBusRd: out std_logic_vector(15 downto 0)
  );
end Waver;

--===============================================================================================
architecture Behavioral of Waver is
-- buffer circulaire
component ram_1kx14
  port (
	  clka:  in  std_logic;
    wea:   in  std_logic_vector(0 downto 0);
    addra: in  std_logic_vector(9 downto 0);
    dina:  in  std_logic_vector(13 downto 0);
    ---
    clkb:  in  std_logic;
    addrb: in  std_logic_vector(9 downto 0);
    doutb: out std_logic_vector(13 downto 0));
end component;
---------------------------------------------
-- MEB en version 4 k
component ram_4kx14
  port (
	  clka:  in  std_logic;
    wea:   in  std_logic_vector(0 downto 0);
    addra: in  std_logic_vector(11 downto 0);
    dina:  in  std_logic_vector(13 downto 0);
    ---
    clkb:  in  std_logic;
    addrb: in  std_logic_vector(11 downto 0);
    doutb: out std_logic_vector(13 downto 0));
end component;
---------------------------------------------
-- MEB en version 8 k
component ram_8kx14
  port (
	  clka:  in  std_logic;
    wea:   in  std_logic_vector(0 downto 0);
    addra: in  std_logic_vector(12 downto 0);
    dina:  in  std_logic_vector(13 downto 0);
    ---
    clkb:  in  std_logic;
    addrb: in  std_logic_vector(12 downto 0);
    doutb: out std_logic_vector(13 downto 0));
end component;
---------------------------------------------
component ram_16x16
  port (
    clk : in  std_logic;
    ---
    a   : in  std_logic_vector(3 downto 0);
    d   : in  std_logic_vector(15 downto 0);
    we  : in  std_logic;
    ---
    dpra: in  std_logic_vector(3 downto 0);
    dpo : out std_logic_vector(15 downto 0));
end component;
---------------------------------------------
component ram_32x16
  port (
    clk : in  std_logic;
    ---
    a   : in  std_logic_vector(4 downto 0);
    d   : in  std_logic_vector(15 downto 0);
    we  : in  std_logic;
    ---
    dpra: in  std_logic_vector(4 downto 0);
    dpo : out std_logic_vector(15 downto 0));
end component;
---------------------------------------------
component ram_64x16
  port (
    clk : in  std_logic;
    ---
    a   : in  std_logic_vector(5 downto 0);
    d   : in  std_logic_vector(15 downto 0);
    we  : in  std_logic;
    ---
    dpra: in  std_logic_vector(5 downto 0);
    dpo : out std_logic_vector(15 downto 0));
end component;
---------------------------------------------
component ram_128x16
  port (
    clk : in  std_logic;
    ---
    a   : in  std_logic_vector(6 downto 0);
    d   : in  std_logic_vector(15 downto 0);
    we  : in  std_logic;
    ---
    dpra: in  std_logic_vector(6 downto 0);
    dpo : out std_logic_vector(15 downto 0));
end component;
---------------------------------------------
component ram_256x16
  port (
    clk : in  std_logic;
    ---
    a   : in  std_logic_vector(7 downto 0);
    d   : in  std_logic_vector(15 downto 0);
    we  : in  std_logic;
    ---
    dpra: in  std_logic_vector(7 downto 0);
    dpo : out std_logic_vector(15 downto 0));
end component;
---------------------------------------------

-- la fonction bits est dfinie dans le package tel_defs
constant CirBits    : integer := bits(CirSize); -- nbre de bits du bus d'adresse de cirbuf
constant MebBits    : integer := bits(MebSize); -- nbre de bits du bus d'adresse de MEB
constant RecordBits : integer := bits(SegItems+1); -- les bits de la sous-adresse "record" (le +3 pour le pointeur de fifo + header + length)
constant SegBits    : integer := bits(NB_SEG) + RecordBits; -- nbre de bits du bus d'adresse segments

-- composants ==================================================================================
-- pour le buffer circulaire (la même taille à 100 et 250 MHz --> pas de config)
-- simple dual port ram. att. la lecture est synchrone dans le sens que
-- l'adresse est mémorisée en interne sur le front montant de l'horloge
-- on observe donc une latence de 1 clock même en l'absence de latch de sortie sur les données


--=== le buffer circulaire ======================================================================
-- les signaux d'entrée
signal writeCirc  : std_logic;
signal ctWrCirc   : std_logic_vector(CirBits-1 downto 0);
signal ctRdCirc   : std_logic_vector(CirBits-1 downto 0);
signal circOut    : std_logic_vector(ADC_TOP downto 0);

--=== le MEB ====================================================================================
-- côté acquisition
signal adWrFifo   : std_logic_vector(MebBits-1 downto 0); -- adresse d'écriture
signal fifoIn     : std_logic_vector(ADC_TOP downto 0);
signal adWrCap    : std_logic_vector(MebBits-1 downto 0); -- adresse de début de segment
signal capture    : std_logic; -- signal de transfert adWrFifo --> adWrCap
signal weFifo     : std_logic; -- validation écriture fifo
signal saveChannel: boolean;
-- le système d'échantillonnage d'ADC destiné au slow control
signal sample     : std_logic_vector(ADC_TOP downto 0); -- ADC prélevé  à 50 MHz
signal syncADC    : std_logic; -- l'instant d'échantillonnage vu côté ADC
signal syncSys    : std_logic; -- l'instant d'échantillonnage vu côté système
signal dataDecim  : std_logic_vector(ADC_TOP downto 0);
signal decimator  : std_logic_vector(4 downto 0); -- le compteur modulo 20 ns
--signal fifoRazWrAdr: std_logic;
signal fifoIncWrAdr: std_logic; -- décomptage compteur de mots fifo
signal ctStore    : std_logic_vector(MebBits-1 downto 0); -- décompteur d'écriture
signal ldCtStore  : std_logic; -- ordre de chargement
signal fifoWrDone : std_logic; -- indicateur fin de décomptage
-- côté readout
signal adRdFifo   : std_logic_vector(MebBits-1 downto 0); -- compteur de readout
signal adRdMeb    : std_logic_vector(MebBits-1 downto 0); -- bus d'adresse de lecture MEB
signal fifoOut    : std_logic_vector(ADC_TOP downto 0);
signal fifoData   : std_logic_vector(15 downto 0);
--signal marqueur   : std_logic_vector(1 downto 0); -- complète fifoOut à 16 bits
signal fifoRdLd   : std_logic; -- chargement parallèle compteur de lecture MEB
signal fifoRdInc  : std_logic; -- ordre de comptage adresse de lecture MEB
signal decodMeb, decodMebLate : std_logic; -- signal de décodage

signal regRead    : std_logic_vector(15 downto 0);

--=== la mémoire segments =======================================================================
signal segsIn, segsOut : std_logic_vector(15 downto 0);
signal segsAdWr   : std_logic_vector(SegBits-1 downto 0);
signal weSegs     : std_logic;
signal ctRdSeg    : std_logic_vector(SegBits-1 downto 0);
signal segAdRd    : std_logic_vector(SegBits-1 downto 0);
signal segsRdInc  : std_logic; -- commande d'incrémentation du registre de lecture segments
signal segsRdLd   : std_logic;
signal decodSeg, decodSegLate : std_logic; -- signal de décodage

--=== les registres =============================================================================
-- le registre de controle bit 0 = inhibition de l'écriture dans le buffer circulaire
constant CTRL_BITS : integer := 1;
signal control : std_logic_vector(CTRL_BITS-1 downto 0);
-- registre de pretrig
signal pretrig    : std_logic_vector(CirBits-1 downto 0);
signal storeDepth : std_logic_vector(MebBits-1 downto 0); -- la quantité à transférer en MEB
signal saveEnable : std_logic_vector(0 downto 0);

--=== La machine d'état d'acquisition rapide ====================================================
type AcqFastState is (
  IDLE, WR_DEPTH, WR_DATA, ACQUIT0, ACQUIT1
);
signal acqFastCs, acqFastFs : AcqFastState := IDLE;
signal fastBusyF : std_logic;

--=== La machine d'état d'acquisition lente =====================================================
type AcqSlowState is (
  IDLE, WAIT_BUSY, WRITING, ACQUIT
);
signal acqSlowCs, acqSlowFs : AcqSlowState := IDLE;
signal fastBusyS : std_logic; -- fastBusyF resynchronisé
signal valResync : std_logic;

signal dummy : std_logic;
signal slowAck : std_logic;

--===============================================================================================
signal slowCtBusRdLocal : std_logic_vector (15 downto 0);

--===== chipscope ===============================================================================
signal all_zero_64 : std_logic_vector (63 downto 0) := (others => '0');
signal etat : std_logic_vector (2 downto 0);
signal busy : std_logic;
signal CONTROL0 : std_logic_vector (35 downto 0);

component tel_ila_36
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK   : IN STD_LOGIC;
    TRIG0 : IN STD_LOGIC_VECTOR(35 DOWNTO 0)
	 );
end component;

component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0)
	 );
end component;

--===============================================================================================
begin

slowCtBusRd <= slowCtBusRdLocal;
busyPort    <= busy;

--===== chipscope ===============================================================================
-- make_chipscope: if chip_waver and detId = SI_1 and WaveId = WAVE_QH1 generate
make_chipscope: if chip_waver and detId = CS_I and WaveId = WAVE_Q3 generate

mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0
  );
  
-- waver_fast
--mes_sondes : tel_ila_36
--  port map (
--    CONTROL => CONTROL0,
--    CLK      => adcClk,
--    ---
--    TRIG0 (2  downto  0) => etat,     --  3 bits
--    TRIG0 (3)            => fastBusyF,
--    TRIG0 (4)            => valResync,
--    TRIG0 (5)            => weFifo,
--    TRIG0 (6)            => fifoWrDone,
--    TRIG0 (35 downto 7)  => all_zero_64(35 downto 7)
-- );
--end generate;
----
--etat <= conv_std_logic_vector(AcqFastState'pos(acqFastCs), 3);

---- waver_slow qh1
--mes_sondes : tel_ila_36
--  port map (
--    CONTROL => CONTROL0,
--    CLK     => clk,
--    ---
--    TRIG0 (6 downto 0)   => segsAdWr,
--    TRIG0 (22 downto 7)  => segsIn,
--    TRIG0 (23)           => weSegs,
--	 TRIG0 (24)				 => fastBusyS,
--	 TRIG0 (25)				 => terminate,
--	 TRIG0 (26)				 => val,
--	 TRIG0 (35 downto 27) => all_zero_64(8 downto 0)
-- );

---- waver_slow qh3
mes_sondes : tel_ila_36
  port map (
    CONTROL => CONTROL0,
    CLK     => clk,
    ---
    TRIG0 (7 downto 0)   => segsAdWr,
    TRIG0 (23 downto 8)  => segsIn,
    TRIG0 (24)           => weSegs,
	 TRIG0 (25)				 => fastBusyS,
	 TRIG0 (26)				 => terminate,
	 TRIG0 (27)				 => val,
	 TRIG0 (35 downto 28) => all_zero_64(7 downto 0)
 );
etat <= conv_std_logic_vector(AcqSlowState'pos(acqSlowCs), 3);
---- waver_slow
--mes_sondes : tel_ila_36
--  port map (
--    CONTROL => CONTROL0,
--    CLK     => clk,
--    ---
--    TRIG0 (3  downto  0) => slowCtBus.addr(WAVER_FIELD-1 downto 0),
--    TRIG0 (4)            => valResync,
--    TRIG0 (5)            => busy,
--	 TRIG0 (6)				 => capture,
--	 TRIG0 (7)				 => slowCtBus.rd,
--	 TRIG0 (19 downto 8)  => slowCtBus.addr(15 downto 4),
--	 TRIG0 (35 downto 20) => regRead
-- );
--
end generate;


--===============================================================================================

segsAdWr(SegBits-1 downto RecordBits) <= segNrWr;
dummy <= or_reduce(slowCtBus.rd & slowCtBus.data(15 downto MebBits-1));

-- pour le test uniquement !
--fifoData(15 downto 12) <= conv_std_logic_vector(ID, 4);
--fifoData(11 downto  8) <= segNrRd(3 downto 0);
--fifoData( 7 downto  0) <= fifoOut(7 downto 0);

fifoData(15 downto ADC_TOP+1) <= (others => '0');
fifoData(ADC_TOP downto 0)    <= fifoOut;

--======================== la mémoire circulaire d'ADC ==========================================
--bufCirc: entity work.ram_1kx14
bufCirc: ram_1kx14
  port map (
    clka  => adcClk,
    wea(0)=> writeCirc,   -- not control(CIR_LOCK), -- on écrit tout le temps sauf contre-ordre de slow_control
    addra => ctWrCirc, -- ctWrCirc,
    dina  => adcIn(ADC_TOP downto 0),
    ---
    clkb  => adcClk,
    addrb => ctRdCirc,
    doutb => circOut
  );

--========================= le MEB ==============================================================
make_4k_Meb: if MebSize = 4096 generate
--meb: entity work.ram_4kx14
meb: ram_4kx14
  port map (
    clka  => adcClk,
    wea(0)=> weFifo,
    addra => adWrFifo,
    dina  => fifoIn,
    ---
    clkb  => clk,
    addrb => adRdMeb,
    doutb => fifoOut
  );
end generate;
---------------------------------------
make_8k_Meb: if MebSize = 8192 generate
--meb: entity work.ram_8kx14
meb: ram_8kx14
  port map (
    clka  => adcClk,
    wea(0)=> weFifo,
    addra => adWrFifo,
    dina  => fifoIn,
    ---
    clkb  => clk,
    addrb => adRdMeb,
    doutb => fifoOut
  );
end generate;

--========================= la mémoire segments =================================================
-- Penser que la block_ram possède ipso_facto un registre d'adresse sur le port de lecture
-- contrairement à la distributed_ram.

make_16_seg: if SegBits = 4 generate
seg: ram_16x16
  port map (
    clk   => clk,
    ---
    a     => segsAdWr,
    d     => segsIn,
    we    => weSegs,
    ---
    dpra  => segAdRd,
    dpo   => segsOut
  );
end generate;
---------------------------------------
make_32_seg: if SegBits = 5 generate
seg: ram_32x16
  port map (
    clk   => clk,
    ---
    a     => segsAdWr,
    d     => segsIn,
    we    => weSegs,
    ---
    dpra  => segAdRd,
    dpo   => segsOut
  );
end generate;
---------------------------------------
make_64_seg: if SegBits = 6 generate
seg: ram_64x16
  port map (
    clk   => clk,
    ---
    a     => segsAdWr,
    d     => segsIn,
    we    => weSegs,
    ---
    dpra  => segAdRd,
    dpo   => segsOut
  );
end generate;
---------------------------------------
make_128_seg: if SegBits = 7 generate
seg: ram_128x16
  port map (
    clk   => clk,
    ---
    a     => segsAdWr,
    d     => segsIn,
    we    => weSegs,
    ---
    dpra  => segAdRd,
    dpo   => segsOut
  );
end generate;
---------------------------------------
make_256_seg: if SegBits = 8 generate
seg: ram_256x16
  port map (
    clk   => clk,
    ---
    a     => segsAdWr,
    d     => segsIn,
    we    => weSegs,
    ---
    dpra  => segAdRd,
    dpo   => segsOut
  );
end generate;
---------------------------------------
lecteur: entity work.Reader
  generic map (
    detId      => detId,
    WaveId      => WaveId,
    MebSize     => MebSize,
    Items       => SegItems
  )
  port map (
    clk         => clk,
    reset       => reset,
    telId       => telId,
    ---
    dataRemote  => dataRemote, -- entrée en provenance de l'étage précédent
    fromFifo    => fifoData,
    segsIn      => segsOut,
	 saveWave    => saveChannel,
    dataOut     => dataOut,    -- vers étage suivant (9 bits)
    fifoLd      => fifoRdLd,
    fifoInc     => fifoRdInc,
    ---
    segsLd      => segsRdLd,
    segsInc     => segsRdInc,
    ---
    throttle    => throttle,
    doneIn      => doneIn,
    doneOut     => doneOut,
    ---
    statemach  => readerStateMach,
    errbit     => readerErrBit,
    ---
    readIn      => readIn,       -- chaînage
    readOut     => readOut
  );
--===============================================================================================

writeCirc <= not control(0); -- write inhibitted by slow control

--===============================================================================================
-- les compteurs d'adresse du buffer circulaire

cirReadWrite: process (adcClk, reset)
begin
  if reset = '1' then
    ctWrCirc <= (others => '0');    -- pour l'hygiène
    ctRdCirc <= conv_std_logic_vector(CirSize-DEFAULT_PRETRIG, CirBits);
  elsif rising_edge(adcClk) then
    ctWrCirc <= ctWrCirc + 1;
    if ctWrCirc =  conv_std_logic_vector(CirSize-1, CirBits) then
      ctRdCirc <= not pretrig;
    else
      ctRdCirc <= ctRdCirc + 1;
    end if;
  end if;
end process cirReadWrite;

--=== La machine d'état d'acquisition rapide ====================================================
-- Transfère en temps réel (250 MHz, sans arrêter le buffer circulaire) les échantillons
-- vers le MEB

--=================================================================
-- Décompteur ctStore: décompte si contenu non nul
-- entrées : weFifo = chargement du compte
--           storeDepth = compte initial
-- sortie  : fifoWrDone quand compte = 0

acqFastDecCnt: process (reset, adcClk)
begin
  if reset = '1' then
    ctStore  <= (others => '0');
    fifoWrDone <= '0';
  elsif rising_edge(adcClk) then
    if ldCtStore = '1' then
      ctStore <= storeDepth; -- le nombre d'échantillons à stocker (non compris les paramètres)
    end if;

    if ctStore /= 0 then -- le compteur décompte d'autorité tant qu'il n'est pas nul
      ctStore <= ctStore - 1; -- décomptage
    end if;

--    if ctStore = 3 then
    if ctStore = 2 then  -- modifié le 24-10-2012 (il manquait un échantillon stocké)
      fifoWrDone <= '1'; -- anticiper l'arrêt
    else
      fifoWrDone <= '0';
    end if;
  end if;
end process acqFastDecCnt;

--=================================================================
-- Compteur d'adresse d'écriture

acqFastAdrCnt: process (reset, adcClk)
begin
  if reset = '1' then
    adWrFifo <= (others => '0');
    adWrCap  <= (others => '0');
  elsif rising_edge(adcClk) then  
    if fifoIncWrAdr = '1' then
      adWrFifo <= adWrFifo + 1;
    end if;
    if capture = '1' then
      adWrCap <= adWrFifo;
    end if;

-- code provisoire destiné à commencer systmatiquement le stockage en début de mémoire MEB
-- pour la phase de test uniquement
--    if fifoRazWrAdr = '1' then
--      adWrFifo <= (others => '0');
--    elsif fifoIncWrAdr = '1' then
--      adWrFifo <= adWrFifo + 1;
--    end if;
  end if;
end process acqFastAdrCnt;

--=================================================================
-- Machine d'acquisition rapide
-- le process séquentiel
acqFastSeq: process (reset, adcClk)
begin
  if reset = '1' then
    acqFastCs <= IDLE;
  elsif rising_edge(adcClk) then
    valResync <= val;
    if clear = '1' then
      acqFastCs <= IDLE;
    else
      acqFastCs <= acqFastFs;
    end if;
  end if;
end process;

--=================================================================
-- Machine d'acquisition rapide
-- le process combinatoire
acqFastComb: process (acqFastCs, valResync, fifoWrDone, circOut,
                      pretrig, storeDepth, filterSource, filterIn, slowAck)
begin
  if filterSource ="00" then
    fifoIn     <= circOut; -- par défaut, liaison circ --> meb
  else
    fifoIn     <= filterIn;
  end if;
  acqFastFs    <= acqFastCs;
  weFifo       <= '0';
  fifoIncWrAdr <= '0';
  --fifoRazWrAdr <= '0';
  capture      <= '0';
  fastBusyF    <= '0';
  ldCtStore    <= '0';
  
  case acqFastCs is
  -----------------------------------------------------
  when IDLE =>
    if valResync = '1' then -- enregistrement pretrig
      fifoIn       <= NULL_16(ADC_TOP downto CirBits) & pretrig;
      weFifo       <= '1';
      fifoIncWrAdr <= '1';
      acqFastFs    <= WR_DEPTH;
      capture      <= '1'; -- saisir l'adresse actuelle du ringbuffer
    end if;
  -----------------------------------------------------
  when WR_DEPTH => -- enregistrement profondeur
    weFifo       <= '1';
    fifoIncWrAdr <= '1';
    fifoIn       <= NULL_16(ADC_TOP downto MebBits) & storeDepth;
    ldCtStore    <= '1'; -- initialiser le décompteur d'échantillons
    acqFastFs    <= WR_DATA;   -- qui décomptera à partir de maintenant
  -----------------------------------------------------
  when WR_DATA =>  -- transfert circ -> meb (par défaut)
    weFifo <= '1';
    fifoIncWrAdr <= '1';
    fastBusyF    <= '1';
    if fifoWrDone = '1' then
      acqFastFs  <= ACQUIT0;
    end if;
  -----------------------------------------------------
  when ACQUIT0 => -- attente d'avoir été vu par la machine lente
    fastBusyF    <= '1';
    if slowAck = '1' then
      acqFastFs  <= ACQUIT1;
    end if;
  -----------------------------------------------------
  when ACQUIT1 => -- attente retombée de val
    if valResync = '0' then
      --fifoRazWrAdr <= '1'; -- pour la prochaine acquisition (test uniquement)
      acqFastFs <= IDLE;
    end if;
  -----------------------------------------------------
  end case;
end process;

--=== La machine d'état d'acquisition lente =====================================================

Seq: process (reset, clk)
begin
  if reset = '1' then
    acqSlowCs <= IDLE;
    fastBusyS <= '0';
  elsif rising_edge(clk) then
    if clear = '1' then
      acqSlowCs <= IDLE;
    else
      acqSlowCs <= acqSlowFs;
    end if;
    fastBusyS <= fastBusyF; -- resynchro
  end if;
end process;

-------------------------------------------------------------------------------------------------
acqSlowComb: process (acqSlowCs, val, fastBusyS, itemWr, terminate, itemData, itemNr, adWrCap)
begin
  acqSlowFs   <= acqSlowCs;
  busy  <= '0';
  segsIn <= itemData; -- par défaut, prête à stocker les items
  weSegs <= '0';
  segsAdWr(RecordBits-1 downto 0) <= itemNr;
  slowAck <= '0';
  case acqSlowCs is
  -----------------------------------------------------
  when IDLE =>
    if val = '1' then
      acqSlowFs <= WAIT_BUSY;
    end if;
  -----------------------------------------------------
  -- attendre que la machine rapide soit réveillée
  when WAIT_BUSY =>
    busy <= '1';
    slowAck <= '1';
    if fastBusyS = '1' then
      slowAck <= '1'; -- le réveil a été détecté
      segsIn(15 downto MebBits)  <= (others => '0');
      segsIn(MebBits-1 downto 0) <= adWrCap;
      segsAdWr(RecordBits-1 downto 0) <= conv_std_logic_vector(0, RecordBits); -- sous-adresse du pointeur
      weSegs <= '1';
      acqSlowFs  <= WRITING;
    end if;
  -----------------------------------------------------
  when WRITING =>
    slowAck <= '1'; -- le réveil a été détecté
    busy <= '1';
    if fastBusyS = '0' and terminate = '1' then -- attente fin du process rapide et des items
      acqSlowFs <=  ACQUIT;
    end if;
    if itemWr = '1' then
      weSegs <= '1';
    end if;
  -----------------------------------------------------
  when ACQUIT =>
    busy <= '0';
    if val = '0' then
      acqSlowFs  <= IDLE;
    end if;
  -----------------------------------------------------
  end case;
end process;

--=== les compteurs de lecture commandés par 'reader' =========================================

ctRdProc: process (reset, clk)
begin
  if reset = '1' then
    ctRdSeg  <= (others => '0');
    adRdFifo <= (others => '1'); -- marqueur pour le test
  elsif rising_edge(clk) then
    if segsRdLd = '1' then
      ctRdSeg(SegBits-1    downto RecordBits) <= segNrRd; -- partie haute
      ctRdSeg(RecordBits-1 downto 0) <= (others => '0');  -- on commence par le pointeur
    elsif segsRdInc = '1' then
      ctRdSeg <= ctRdSeg + 1;
    end if;
    
    if fifoRdLd = '1' then
      adRdFifo <= segsOut(MebBits-1 downto 0);
    elsif fifoRdInc = '1' then
      adRdFifo <= adRdFifo+1;
    end if;
  end if;
end process ctRdProc;

--=== le système d'échantillonnage d'ADC =======================================================
-- les voies à 100 MHz
if100: if RegAd=QH1_SC or RegAd=Q2_SC or RegAd=Q3_SC generate

syncADCProc: process (adcClk, clk)
begin
  if rising_edge(adcClk) then
    syncADC <= not syncADC;
  end if;  
  
  if falling_edge(adcClk) then
    if syncADC = '0' then
      dataDecim <= adcIn;
    end if;
  end if;
  
  if rising_edge(clk) then
    if syncADC = '1' then
      sample <= dataDecim; -- les données sont dispo depuis au moins 5 ns
    end if;
  end if;
end process;

end generate; --==========================

-- les voies à 250 MHz
if250: if RegAd=QL1_SC or RegAd=I1_SC or RegAd=I2_SC generate

syncADCProc: process (adcClk)
begin
  if rising_edge(adcClk) then
    if decimator = 0 then
      dataDecim <= adcIn; -- échantillonnage modulo 20 ns
    end if;
    
    if decimator = 1 then
      syncADC <= '1';
    end if;
    
    if decimator = 4 then -- modulo 5
      decimator <= (others => '0');
    else
      decimator <= decimator + 1;
    end if;
    
    if syncSys = '1' then
      syncADC <= '0';
    end if;
  end if;
end process;

syncSysProc: process (clk)
begin
  if rising_edge(clk) then
    if syncADC = '1' then
      sample <= dataDecim;
      syncSys <= '1';
    else
      syncSys <= '0';
    end if;
  end if;
end process;
end generate;
--============== waveform memorization ==========================================================
--saveChannel <= saveWaveIn when saveEnable(0 downto 0) = "1"
--            else false; 
saveChannel <= saveWaveIn when saveEnable(0 downto 0) = "0"
            else true; 
				
--============== les registres ==================================================================

regLoad: process (clk, reset)
variable fMebScAd : std_logic_vector(SC_TOP downto WAVER_FIELD);
                         
begin
  fMebScAd := RegAd (SC_TOP downto 8) & WAVER_SC(7 downto WAVER_FIELD);
  if reset = '1' then
    control    <= (others => '0');
    pretrig    <= conv_std_logic_vector(DEFAULT_PRETRIG, CirBits);
    storeDepth <= conv_std_logic_vector(DEFAULT_DEPTH, MebBits);
	 saveEnable <= DEFAULT_WAVE_ENABLE;
  elsif rising_edge(clk) then
    regRead <= (others => '0');
    -- lecture
    if slowCtBus.rd = '1' and
       slowCtBus.addr(SC_TOP downto WAVER_FIELD) = fMebScAd then
      case slowCtBus.addr(WAVER_FIELD-1 downto 0) is
        when WAVER_PRETRG  => regRead(CirBits-1   downto 0) <= pretrig;
        when WAVER_DEPTH   => regRead(MebBits-1   downto 0) <= storeDepth;
        when WAVER_CTRL    => regRead(CTRL_BITS-1 downto 0) <= control;
        when WAVER_CAPTURE => regRead(MebBits-1   downto 0) <= adWrCap;
        when WAVER_STAT_S  => regRead(2 downto 0) <= conv_std_logic_vector(AcqSlowState'pos(acqSlowCs), 3);
        when WAVER_STAT_F  => regRead(2 downto 0) <= conv_std_logic_vector(AcqFastState'pos(acqFastCs), 3);
        when ADC_SAMPLE    => regRead(ADC_TOP downto 0) <= sample;
                              regRead(15 downto ADC_TOP+1) <= (others => sample(ADC_TOP));
		  when WAVE_MEM_ENABLE => regRead (0 downto 0) <= saveEnable;
        when others => null;
      end case;
    -- écriture
    elsif slowCtBus.wr = '1' and
       slowCtBus.addr(SC_TOP downto WAVER_FIELD) = fMebScAd then
      case slowCtBus.addr(WAVER_FIELD-1 downto 0) is
        when WAVER_PRETRG => pretrig    <= slowCtBus.data(CirBits-1 downto 0);
        when WAVER_DEPTH  => -- une longueur inférieure à 4 est interdite
          if slowCtBus.data(MebBits-1 downto 0) >= conv_std_logic_vector(4, MebBits) then
            storeDepth <= slowCtBus.data(MebBits-1 downto 0);
          else
            storeDepth <= conv_std_logic_vector(4, MebBits);
          end if;
		  when WAVE_MEM_ENABLE => 	saveEnable <= slowCtBus.data(0 downto 0); 
        when others => null;
      end case;
--    elsif slowCtBus.wr = '1' and slowCtBus.addr(SC_TOP downto INSPECT_FIELD) = INSPECT_AD then
--      if slowCtBus.addr(INSPECT_FIELD-1 downto 0) = AdcNr then
--        inspectSource <= slowCtBus.data(1 downto 0);
--      else
--        inspectSource <= (others => '0');
--      end if;
    end if;
  end if;
end process regLoad;

--============== les mémoires ===================================================================
-- les décodeurs

decodMeb <= '1' when slowCtBus.addr(15 downto MebBits) = MebAd(15 downto MebBits) and
                      slowCtBus.rd = '1' else '0';
decodseg <= '1' when slowCtBus.addr(15 downto SegBits) = SegAd(15 downto SegBits) and
                      slowCtBus.rd = '1' else '0';
-------------------------------------------------------------------------------------------------
decodProc: process (reset, clk)
begin
  if reset = '1' then
    decodMebLate <= '0';
    decodsegLate <= '0';
  elsif rising_edge (clk) then
    decodMebLate <= decodMeb;
    decodsegLate <= decodseg;
  end if;
end process;

-- la sélection des bus d'adresse
adRdMeb <= slowCtBus.addr(MebBits-1 downto 0) when decodMeb = '1' else adRdFifo;
segAdRd <= slowCtBus.addr(SegBits-1 downto 0) when decodseg = '1' else ctRdSeg;

-- l'affectation du bus de lecture slow control
rdBusProc: process (decodMebLate, decodSegLate, fifoOut, segsOut, regRead)
begin
  if decodMebLate = '1' then
    for i in 15 downto ADC_TOP+1 loop
      slowCtBusRdLocal(i) <= fifoOut(ADC_TOP); -- extension de signe
    end loop;
    slowCtBusRdLocal(ADC_TOP downto 0) <= fifoOut;
  elsif decodSegLate = '1' then
    slowCtBusRdLocal <= segsOut;
  else
    slowCtBusRdLocal <= regRead; -- par dfaut. "0...0" si rien  lire
  end if;
end process;

end Behavioral;

--===============================================================================================
---
-- Module waver.vhd
-- Bloc diagramme: voir phase_2/step_2/fpga/tel_ab.odg
--
-- Ce module assure
-- * l'interface avec un ADC de fréquence quelconque (100 ou 250 MHz)
-- * la calibration des délais dudit ADC au moyen du bus alignBus
-- * la mémorisation continue des données d'adc au moyen d'un buffer circulaire
-- * la mise en mémoire fifo d'un enregistrement d'adc et des données associées à la montée
--                                                                                  du signal 'val'
-- * la lecture des données de l'enregistrement à la montée du signal 'readIn'
-- les enregistrements successifs sont nommés 'segment'. Un segment s'identifie par son numéro et
-- comporte 1) un pointeur vers le début d'enregistrement dans la fifo d'adc et
--          2) des données locales écrites par le possesseur du 'waver' pendant le déroulement de
--                                                                          l'acquisition du segment
-- le module comprend deux domaines d'horloge
--      1) le domaine 'fast' du côté de l'ADC
--      2) le domaine 'slow' du côté système

-- Séquence d'acquisition:
-- ======================
-- Deux domaines d'horloge: fast séquencé par l'horloge d'ADC et slow séquencé par l'horloge système
-- Dans waver, l'acquisition comprend une machine d'état du côté slow et une autre du côté fast
-- Quand val monte:
-- La mise en fifo commence immédiatement. Le compteur de lecture adRdRBuf est en permanence en
-- retard de 'pretrig' échantillons sur le compteur d'écriture adWrRBuf. 'pretrig' se programme par
-- slow-control. Le numéro de segment à écrire est imposé de l'extérieur via l'entrée segNrWr
-- segNrWr --> adWrSeg_high (la partie basse adressera les données du segment)
-- dans le même temps, l'adresse d'écriture en fifo est mémorisée en début de segment
-- adWrFifo --> segs[adWrSeg+FIFOPT]. Ceci permettra de retrouver le 1er échantillon quand il faudra
--                                                                                           relire
-- Tant que l'acquisition n'est pas terminée, le possesseur du module peut à sa guise écrire des
-- données dans le segment en utilisant les signaux itemNr, itemData et itemWr. La fin de l'acquisition
-- est notifiée de l'extrieur par la monte de 'terminate'. Nb. ce signal peut être maintenu à '1'
-- en permanence si pas d'item à écrire

-- Séquence de lecture:
-- ====================
-- Une seule machine d'état côté slow. Elle est entièrement contenue dans le module 'Reader'
-- Quand throttle monte: segNrRd --> ctRdSeg (pour lire le registre 'segs')
-- segs:data_b --> adRdFifo (préparation de la future lecture de la fifo)
-- faire sortir les données de segs en incrémentant l'adresse de lecture
--                     (il peut y avoir zéro donnée à sortir)
-- faire sortir toutes les données de la fifo
-- activer done

-- les mémoires (exemple de configuration avec NB_SEG = 8)
-- ============

--                   cirBuf    MEB      (ITEMS)    segs
-- slow channel     1k x 14    4k x 14    (2)    16 x 16
-- fast charge      1k x 14    8k x 14    (1)     8 x 16
-- fast current     1k x 14    8k x 14    (1)     8 x 16






