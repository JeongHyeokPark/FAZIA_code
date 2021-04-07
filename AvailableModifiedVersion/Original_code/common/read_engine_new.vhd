----------------------------------------------------------------------------------
-- Company: IPN Orsay
-- Engineer: P. Edelbruck
-- 
-- Create Date:    28-11-2012
-- Design Name: 
-- Module Name:    ReadEngine - Behavioral 
-- File:           common/read_engine_new.vhd
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions:  ISE 12.4

-- Description:
-- ============
-- Pour l'inspiration, voir fazia/phase_2/systemc/read_engine.h .cc
-- Ce module se charge du vidage des donnes acquises par les voies. Celles-ci sont
-- interconnectes en srie (daisy chain). Le module est compos de deux processus
-- indpendants interconnects par une mmoire double port.
-- Listener attend un ordre d'acquisition (monte de val) et construit l'enregistrement
-- Talker met les enregistrements disponibles vers Fastlink

-- Nouvelle version en date du 28-11-2012
-- Les deux telescopes A et B ont leurs donnes encapsules dans un seul message
-- Le cas des vnements vides (suppression de zro A et/ou B) est prvu

-------------------------------------------------------------------------------------------------
library IEEE;

use IEEE.std_logic_1164.ALL;
--use IEEE.std_logic_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.numeric_std.all;


use work.tel_defs.all;
use work.slow_ct_defs.all;

entity ReadEngine is
  generic (
    withChipScope : boolean;
    build_a       : boolean  -- implicitement, si buil_a = FALSE, c'est buil_b qui est vrai ...
  );
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    clear     : in  std_logic;
    --sync      : in  std_logic; -- signal  25 MHz de dure 10 ns
    syncZer   : in  std_logic;
    ---
    alignIn   : in  std_logic;
    alignOut  : in  std_logic;
    ---
    throttle  : out std_logic; -- ce signal gle la transmission par les canaux quand il vaut '0'
    done      : in  std_logic;
    readOut   : out std_logic; -- appel des donnes (vers la dernire voie de la chane)
    dataIn    : in  std_logic_vector (DATA_WITH_TAG-1 downto 0); -- donnes depuis les voies
    ---
    hostIn     : in  std_logic_vector( 7 downto 0); -- depuis FastLink
    hostOutPort: out std_logic_vector(15 downto 0); -- vers FastLink
    spyBus     : in  std_logic_vector(15 downto 0); -- seulement pour le debug
    voieInt    : out std_logic;
    ---
    -- handshake de communication
    lWait     : out std_logic; -- handshake sortant (fifo quasi pleine)
    blkBusyPort: in  std_logic; -- handshake entrant
    ---
    telId     : in  std_logic_vector(3 downto 0); -- numro de tlescope complet (carte & FPGA)
    ---
    lt        : in  std_logic;   -- la requte issue du trigger. Ce signal sert uniquement 
    val       : in  std_logic;   --  stocker le timestamp dans le cas d'une requte locale
    --glt       : in  std_logic; -- ce signal est utilis uniquement pour la synchro des pointeurs de fifo
    vetoIn    : in  std_logic;   -- en provenance de la trigger box
    segNrWr   : in  std_logic_vector (SEG_BITS-1 downto 0);
    segNrRd   : out std_logic_vector (SEG_BITS-1 downto 0);
    ---
    trigBitmask : in std_logic_vector (14 downto 0);
    saveWaveFlag : out boolean;

    -- signaux de synchro et de communication entre A et B
    -- ces signaux ne sont pas de vrais inout, c'est selon que le parent de readEngine est A ou B
    syncWr    : inout std_logic; -- sortie si A, entre si B
    syncRd    : inout std_logic; -- idem
    bDone     : inout std_logic; -- entre si A, sortie si B : B a fini de transmettre ses donnes
    readB     : inout std_logic; -- sortie si A, entre si B : A appelle les donnes de B
    ---
    slowCtBus   : in  SlowCtBusRec;
    slowCtBusRd : out std_logic_vector(15 downto 0)
  );
end ReadEngine;

-------------------------------------------------------------------------------------------------
architecture Behavioral of ReadEngine is
component ram_32x16_modified
  port (
    clk : in  std_logic;
    ---
    a   : in  std_logic_vector( 4 downto 0);
    d   : in  std_logic_vector(15 downto 0);
    we  : in  std_logic;
    ---
    dpra: in  std_logic_vector(4 downto 0);
    dpo : out std_logic_vector(15 downto 0));
end component;
---------------------------------------------
component ram_64x16_modified
  port (
    clk : in  std_logic;
    ---
    a   : in  std_logic_vector( 5 downto 0);
    d   : in  std_logic_vector(15 downto 0);
    we  : in  std_logic;
    ---
    dpra: in  std_logic_vector( 5 downto 0);
    dpo : out std_logic_vector(15 downto 0));
end component;
---------------------------------------------
component ram_128x16_modified
  port (
    clk : in  std_logic;
    ---
    a   : in  std_logic_vector( 6 downto 0);
    d   : in  std_logic_vector(15 downto 0);
    we  : in  std_logic;
    ---
    dpra: in  std_logic_vector( 6 downto 0);
    dpo : out std_logic_vector(15 downto 0));
end component;

-------------------------------------------------------------------------------------------------
-- jeSuisA est un signal utilis pour la reconnaissance dynamique, c'est--dire que dans certains
-- cas, les deux versions A et B utilisent le mme code mais se comportent de faon diffrencie
-- selon leur identit
signal   jeSuisA      : std_logic;
constant RecordBits   : integer := bits(RD_FIFO_RECORD_ITEMS);
constant HighAddrBits : integer := bits(NB_SEG); -- il ne peut pas y avoir plus de segments en
                                                 -- attente dans read_engine que dans les voies
constant FifoBits     : integer := HighAddrBits + RecordBits; -- la fifo est suffisamment profonde
                             -- pour contenir autant d'enregistrements que de segments possibles
signal segRdLocal  : std_logic_vector (SEG_BITS-1    downto 0);
-- numro d'evt arriv par le FastLink via un mcanisme qui reste  dfinir
signal eventNumber : std_logic_vector (EVT_NR_BITS-1 downto 0);
signal triggerPattern : std_logic_vector (11 downto 0);
--
constant DELAI_0 : integer :=2; -- en coups de 20 ns
constant DELAI_1 : integer :=2;
constant DELAI_2 : integer :=2;
constant DELAI_3 : integer :=12;
constant DELAI_4 : integer :=2;
constant DELAI_5 : integer :=15;

constant TIMER_BITS : integer := 5;
signal timer       : std_logic_vector (TIMER_BITS-1 downto 0); -- pour les dlais (usage gnral)
--
signal timestamp     : std_logic_vector(TS_BITS-1 downto 0); -- le time stamp du telescope
signal tsRequest     : std_logic_vector(TS_BITS-1 downto 0); -- le time stamp mmoris au moment de la requte
signal tsVal         : std_logic_vector(TS_BITS-1 downto 0);
signal ltOld         : std_logic;
signal ltOldBis      : std_logic;
signal syncZerOld    : std_logic;
signal bitmaskForAcq : std_logic_vector(14 downto 0);
signal saveParam     : integer range 0 to 15;
signal saveWave      : unsigned(11 downto 0);

-- le registre FIFO ----------------------------------------------------------------------------

signal fifoIn, fifoOut    : std_logic_vector(15 downto 0);
signal fifoAdRd, fifoAdWr : std_logic_vector(FifoBits-1 downto 0); -- registres d'adresse (champ vnement)
signal fifoItemRd, fifoItemWr : std_logic_vector(RecordBits-1 downto 0);   -- registres d'adresse item
signal rdPt, wrPt : std_logic_vector(HighAddrBits-1 downto 0); -- registres d'adresse enregistrement
signal fifoWe     : std_logic;
signal hostOut    : std_logic_vector(15 downto 0); -- vers FastLink. registre pour accs internes

--                      0       1       2            3           4
type ListenerState is (IDLE, WR_SEG, WR_TS_RQ, WAIT_EVT_NBER, WR_TS_VAL,
                       WR_EVT_NR, WR_BITMASK, ATTENDRE);
--                         5         6           7

signal listenerCs : ListenerState := IDLE;
signal evtNberReceived, resetEvtReceived, setEvtReceived, resetTsRequest, resetBitmask : std_logic;

--- talker stuff ------------------------------------------------------------------------------
signal phase : std_logic; -- permet d'identifier les deux moitis des priodes  20 ns
                     
type TalkerStateA is
  (IDLE,         GET_SEG,      EVENT_CT1,    WAIT_BDONE,   -- 0 1 2 3
   TEL_ID,       GT_TAG,       DET_TAG,      TRG_BITMASK,  -- 4 5 6 7
   TALKING,      EVENT_CT2,    WAIT_FIFO_3A, WAIT_START_B, -- 8 9 A B
   XFER_B0,      XFER_B,       WAIT_FIFO_3B, LENG,         -- C D E F
   CRC,          EOE,          WAIT_FIFO_4,  HOLD,         -- 10 11 12 13
	WAIT_XFER_BO, DELAITOLENG                               -- 14 15                            
  );
                     
type TalkerStateB is
  (IDLE,     GET_SEG,   WAIT_A,      TEL_ID,    -- 0 1 2 3
   GT_TAG,   DET_TAG,   TRG_BITMASK, TALKING,   -- 4 5 6 7
   HOLD,     ACQUIT,   WAIT_A1                  -- 8 9 10
  );
                     
signal talkerCsA, talkerReturnA  : TalkerStateA;
signal talkerCsB, talkerReturnB  : TalkerStateB;
attribute keep : string;
attribute keep of talkerCsA : signal is "true";
attribute keep of talkerCsB : signal is "true";

-- Machine d'tat de rception N d'vnement etc.
type RcvType is (IDLE, WAIT0, GET_EC, WAITTEMPO, WAIT1, GET_TP);
signal rcvState : RcvType;

signal listener : std_logic_vector (2 downto 0);
signal talker   : std_logic_vector (4 downto 0);
signal throttleLocal : std_logic;

--signal oldGlt : std_logic;

signal syncWrLocal, syncRdLocal : std_logic;
signal bDoneLocal, readBLocal   : std_logic;
signal readOutLocal    : std_logic;
-- timeOutListener sert surtout pour le debug qd le N d'evt n'arrive pas faute de block card
signal timeOutListener : std_logic_vector (4 downto 0);
--signal timeOutTalker   : std_logic_vector (15 downto 0); -- jusqu' 655.350 s (6000*20 ns = 120 s)
--signal updateWr     : std_logic;
signal voieIntLocal : std_logic;
signal lWaitLocal   : std_logic;
signal blkBusy      : std_logic;
-- pour le gn alatoire (debug)
signal hacheur      : std_logic_vector(15 downto 0);
signal slowRand     : std_logic;
-- registre de contrle (bit0=1 ==> lwait alatoire)
signal ctrlReg      :  std_logic_vector (0 downto 0);

signal tempo        : std_logic_vector (1 downto 0);

-- signals to calculate the length of a packet
signal lengthcnter  : std_logic_vector (11 downto 0);
signal crcResult    : std_logic_vector (7 downto 0);
signal finishcounting : std_logic;
type CountingType is (IDLE, COUNTING);
signal counterSM : CountingType;
signal timerAvantLeng : std_logic_vector (3 downto 0);

constant VETO_BIT   : integer := 15; -- le bit de veto dans le mot N de segment de la fifo
alias veto is fifoOut(VETO_BIT);

--===== chipscope =============================================================================
-- recopi/modifi depuis histogrammer.vhd

signal all_zero_128 : std_logic_vector (127 downto 0) := (others => '0');
signal CONTROL0 : std_logic_vector (35 downto 0);

component tel_ila_dual_128
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK     : IN STD_LOGIC;
    trig0   : IN STD_LOGIC_VECTOR(15  DOWNTO 0);
    trig1   : IN STD_LOGIC_VECTOR(127 DOWNTO 0)
  );
end component;

component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
end component;

--===============================================================================================

begin
--===== chipscope ===============================================================================

throttle    <= throttleLocal; -- pour pouvoir lire avec chipscope
voieInt     <= voieIntLocal;

-- pour le debug, bien sr
blkBusy <= slowRand when ctrlReg(0) = '1' else blkBusyPort;
--Attention Franck a mis en commentaire la ligne au dessus
--blkBusy <= '0';


--blkBusy <= blkBusyPort;

makeCS: if withChipScope generate

listener <= std_logic_vector(to_unsigned(ListenerState'pos(listenerCs), 3));

mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0);
--------------------------------------------------
sondesA: if build_a generate
  talker   <= std_logic_vector(to_unsigned(TalkerStateA'pos(talkerCsA), 5));
end generate sondesA;
--------------------------------------------------

sondesB: if not build_a generate
talker   <= std_logic_vector(to_unsigned(TalkerStateB'pos(talkerCsB), 5));
end generate sondesB;

--------------------------------------------------
mes_sondes : tel_ila_dual_128
  port map (
    CONTROL => CONTROL0,
    CLK     => clk,
    ---
    trig0 (0)  => reset,
    trig0 (1)  => lt,
    trig0 (2)  => val,
    trig0 (3)  => veto,
    trig0 (4)  => syncWrLocal,
    trig0 (5)  => syncRdLocal,
    trig0 (6)  => bDone,
    trig0 (7)  => readBLocal,
    trig0 (8)  => blkBusy,
    trig0 (9)  => throttleLocal,
    trig0 (10) => phase,
    trig0 (11) => readOutLocal,
    trig0 (12) => done,
    trig0 (13) => voieIntLocal,
    trig0 (14) => lWaitLocal,
    trig0 (15) => vetoIn,
    --------------------------------------------
    trig1 ( 13 downto 0) => all_zero_128(13 downto 0),
    trig1 ( 16 downto 14) => fifoItemWr(2 downto 0),
    trig1 ( 21 downto 17) => timer,
    trig1 ( 24 downto 22) => listener, -- tat de la machine listener
    trig1 ( 29 downto 25) => talker,   -- tat de la machine talker
    trig1 ( 31 downto 30) => all_zero_128(31 downto 30),
    trig1 ( 47 downto 32) => spyBus,
    trig1 ( 51 downto 48) => rdPt,
    trig1 ( 55 downto 52) => wrPt,
    trig1 ( 63 downto 56) => hostIn,
    trig1 ( 79 downto 64) => hostOut,
    trig1 ( 95 downto 80) => dataIn,
    trig1 (111 downto 96) => fifoOut,
    trig1 (112)           => setEvtReceived,
    trig1 (113)           => evtNberReceived,
    trig1 (125 downto 114)=> eventNumber,
    trig1 (127 downto 126) => all_zero_128(127 downto 126)
 );

--------- B -----------------------------------------
--mes_sondes : tel_ila_dual_128
--  port map (
--    CONTROL => CONTROL0,
--    CLK     => clk,
--    ---
--    trig0 (0)  => reset,
--    trig0 (1)  => lt,
--    trig0 (2)  => val,
--    trig0 (3)  => veto,
--    trig0 (4)  => syncWr,
--    trig0 (5)  => syncRd,
--    trig0 (6)  => bDoneLocal,
--    trig0 (7)  => readB,
--    trig0 (8)  => blkBusy,
--    trig0 (9)  => throttleLocal,
--    trig0 (10) => phase,
--    trig0 (11) => readOutLocal,
--    trig0 (12) => done,
--    trig0 (13) => voieIntLocal,
--    trig0 (14) => lWaitLocal,
--    trig0 (15) => vetoIn,
--    ---------------------------------------------------
--    trig1 ( 16 downto 0) => all_zero_128(16 downto 0),
--    trig1 ( 21 downto 17) => timer,
--    trig1 ( 24 downto 22) => listener, -- tat de la machine listener
--    trig1 ( 29 downto 25) => talker,   -- tat de la machine talker
--    trig1 ( 31 downto 30) => all_zero_128(31 downto 30),
--    trig1 ( 47 downto 32) => spyBus,
--    trig1 ( 51 downto 48) => rdPt,
--    trig1 ( 55 downto 52) => wrPt,
--    trig1 ( 63 downto 56) => hostIn,
--    trig1 ( 79 downto 64) => hostOut,
--    trig1 ( 95 downto 80) => dataIn,
--    trig1 (111 downto 96) => fifoOut,
--    trig1 (127 downto 112) => all_zero_128(127 downto 112)
--);
end generate makeCS;

--===============================================================================================
hostOutPort <= hostOut;
readOut     <= readOutLocal;
--jeSuisA     <= not telId(0);
--jeSuisB     <= telId(0);

----- la mmoire FIFO ---------------------------------------------------------------------------

make_32_fifo: if FifoBits = 5 generate
seg: ram_32x16_modified
  port map (
    clk   => clk,
    ---
    a     => fifoAdWr,
    d     => fifoIn,
    we    => fifoWe,
    ---
    dpra  => fifoAdRd,
    dpo   => fifoOut
  );
end generate;
---------------------------------------
make_64_fifo: if FifoBits = 6 generate
seg: ram_64x16_modified
  port map (
    clk   => clk,
    ---
    a     => fifoAdWr,
    d     => fifoIn,
    we    => fifoWe,
    ---
    dpra  => fifoAdRd,
    dpo   => fifoOut
  );
end generate;
---------------------------------------
make_128_fifo: if FifoBits = 7 generate
seg: ram_128x16_modified
  port map (
    clk   => clk,
    ---
    a     => fifoAdWr,
    d     => fifoIn,
    we    => fifoWe,
    ---
    dpra  => fifoAdRd,
    dpo   => fifoOut
  );
end generate;

fifoAdRd <= rdPt & fifoItemRd;
fifoAdWr <= wrPt & fifoItemWr;
segNrRd  <= segRdLocal;
lWait    <= lwaitLocal;

-----------------------------------------------------------------------------
-- Gestion du timestamp

syncProc: process (clk, reset)
begin
  if reset = '1' then
    timestamp <= (others => '0');
  elsif rising_edge(clk) then
    syncZerOld <= syncZer;
    if syncZerOld = '0' and syncZer = '1' then -- front montant de syncZer
      timestamp <= std_logic_vector(to_unsigned(1, TS_BITS));
    else
      timestamp <= timestamp+1;
    end if;
  end if;
end process;

------------------------------------------------------------------------------
-- gestion de la flip-flop mmorisant le timestamp au moment de la requte

tsRequestProc: process (clk, reset,resetTsRequest)
begin
  if reset = '1' or resetTsRequest = '1' then
    tsRequest <= (others => '0');
  elsif rising_edge(clk) then
    ltOldBis <= lt;
    if ltOldBis = '0' and lt = '1' then
      tsRequest <= timestamp; -- mmorisation du timestamp au moment de la requte
    end if;
  end if;
end process;

------------------------------------------------------------------------------
-- gestion de la flip-flop mmorisant le trigger bitmask au moment de la requte

bitmaskProc: process (clk, reset,resetBitmask)
begin
  if reset = '1' or resetBitmask = '1' then
    bitmaskForAcq <= (others => '0');
  elsif rising_edge(clk) then
    ltOld <= lt;
    if ltOld = '0' and lt = '1' then
      bitmaskForAcq <= trigBitmask; -- mmorisation du trigger bitmask au moment de la requte
    end if;
  end if;
end process;

--===== Listener ================================================================================
-- Ce process attend un ordre val
-- Range dans la fifo  - N de segment. Permettra d'identifier l'evt dans les MEB des voies
--                     - N d'vnement (arriv par la liaison srie rapide)
--                     - Timestamp Request
--                     - Timestamp Validation

listenerSeq: process (reset, clk)
begin
  if reset = '1' then
    listenerCs <= IDLE;
    syncWrLocal <= '0';
    wrPt <= (others => '0');
  elsif rising_edge(clk) then
    if clear = '1' then
      listenerCs <= IDLE;
      syncWrLocal <= '0';
      wrPt <= (others => '0');
    else
      case listenerCs is
      -------------------------------------
      when IDLE => -- 0  attendre validation (dbut d'acquisition)
        if val = '1' then
          listenerCs <= WR_TS_VAL;
        end if;
      -------------------------------------	
      when WR_TS_VAL =>  -- 4  Timestamp Validation (doit tre enregistr maintenant car non mmoris)
        tsVal      <= timeStamp; -- registre pour le slowcontrol
        listenerCs <= WR_TS_RQ;
      -------------------------------------
      when WR_TS_RQ =>  -- 2 Timestamp Request
          timeOutListener <= (others => '1');
          listenerCs <= WAIT_EVT_NBER ;
      -------------------------------------
      when WAIT_EVT_NBER =>  -- 3 Attente numro d'evt depuis la block card
		  if evtNberReceived = '1' or timeOutListener = 0 then
          listenerCs <= WR_EVT_NR;
        else
          timeOutListener <= timeOutListener-1;
        end if;
      -------------------------------------
      when WR_EVT_NR =>  -- 5 N d'vnement
        listenerCs <= WR_BITMASK;
      -------------------------------------
      when WR_BITMASK => -- 6 trigger bitmask
        listenerCs <= WR_SEG;
      -------------------------------------
      when WR_SEG => -- 1  enregistrer le N du segment dont l'acquisition commence
        if jeSuisA = '1' then
          if wrPt = all_one(HighAddrBits-1 downto 0) then
            syncWrLocal <= '1';
          else
            syncWrLocal <= '0';
          end if;  
        end if;
        listenerCs <= ATTENDRE;
      -------------------------------------
      when ATTENDRE => -- 7  attendre la fin d'acquisition
        if val = '0' then
          if jeSuisA = '0' and syncWr = '1' then
              wrPt <= (others => '0');
          else
            wrPt <= wrPt + 1; -- prt pour le prochain evt et libration talker
          end if;
          listenerCs <= IDLE;
        end if;
      -------------------------------------
      end case;
    end if;
  end if;
end process listenerSeq;

-------------------------------------------------------------------------------------------------
-- Affectation des sorties (combinatoire)
-- Il s'agit essentiellement ici d'enregistrer dans la FIFO les donnes communes  l'EVT

listenerComb: process (listenerCs, timeStamp, tsRequest, eventNumber, bitmaskForAcq, vetoIn, segNrWr)
begin
  case listenerCs is
    -------------------------------------
    when IDLE => 
	   fifoWe           <= '0';
      fifoIn           <= (others => '0');
      fifoItemWr       <= (others => '0');
      resetEvtReceived <= '0';		
      resetTsRequest   <= '0';
      resetBitmask     <= '0';
    -------------------------------------
    when WR_TS_VAL =>
      resetEvtReceived <= '1';                 -- raz flipflop de rception du numro d'evt
      fifoWe           <= '1';
      fifoItemWr       <= ITEM_TS_VAL;
      fifoIn           <= '0' & timeStamp;     -- le temps actuel (val vient d'arriver)
    -------------------------------------
    when WR_TS_RQ =>
      fifoWe           <= '1';
      fifoItemWr       <= ITEM_TS_REQ;
      fifoIn           <= '0' & tsRequest;     -- le temps stock au moment de la requte
      resetEvtReceived <= '0';
    -------------------------------------
    when WAIT_EVT_NBER => 
	 	fifoWe          <= '0';		
	   resetTsRequest  <= '1';                  -- raz flipflop de mmorisation de tsRequest            
    -------------------------------------
    when WR_EVT_NR =>
      fifoWe     <= '1';
      fifoItemWr <= ITEM_EVT;
      fifoIn(EVT_NR_BITS-1 downto 0) <= eventNumber;
		resetTsRequest   <= '0';
    -------------------------------------
    when WR_BITMASK =>
      fifoWe     <= '1';
      fifoItemWr <= ITEM_BITMASK;
      fifoIn     <= '0' & bitmaskForAcq;
    -------------------------------------	 
    when WR_SEG => 
	   fifoWe           <= '0';
      fifoIn           <= (others => '0');
      fifoItemWr       <= (others => '0');		 
      resetBitmask  <= '1';              -- raz flipflop de mmorisation du trigger bitmask   
                                         -- enregistrer le N de segment dont l'acquisition commence     
                                         -- l'criture du N de segment accompagn du flag de veto a t dplac en fin
                                         -- d'acquisition (ATTENDRE + val) car ce dernier est prt  ce moment seulement	
    -------------------------------------
    when ATTENDRE =>
      resetBitmask     <= '0';
      if val = '0' then
        fifoWe     <= '1';
        fifoItemWr <= ITEM_SEG;
        fifoIn(VETO_BIT) <= vetoIn;
        fifoIn(SEG_BITS-1 downto 0) <= segNrWr;
      end if;
    -------------------------------------
  end case;
end process listenerComb;

--===============================================================================================
-- flip-flop de rception de l'event number
evtFlipFlop: process (reset, clk)
begin
  if reset = '1' then
    evtNberReceived <= '0';
  elsif rising_edge(clk) then
    if resetEvtReceived = '1' then
      evtNberReceived <= '0';
    elsif setEvtReceived = '1' then
      evtNberReceived <= '1';
    end if;
  end if;
 end process;

--===============================================================================================
-- rception des donnes depuis le fastlink, cd depuis la blockcard
-- lit le numro d'vnement et le 'pattern'

receiver: process (reset, clk)
begin
  if reset = '1' then
    eventNumber <= "010101010101"; -- 555 marqueur pour le test
    rcvState    <= IDLE;
	 tempo       <= (others => '0');
  elsif rising_edge(clk) then
    setEvtReceived <= '0';
    case rcvState is
    ------------------------------------------------------
    when IDLE =>
      case hostIn(7 downto 4) is
      when EC_TAG_R => -- lire la partie haute de
        eventNumber(11 downto 8) <= hostIn(3 downto 0);
        rcvState <= WAIT0;
      when TP_TAG =>   -- lire la partie haute du trigger pattern
        triggerPattern(11 downto 8) <= hostIn(3 downto 0);
        rcvState <= WAIT1;
      when others => null;
      end case;
    ------------------------------------------------------
    when WAIT0 => 
	   rcvState <= GET_EC; -- attendre 10 ns
    ------------------------------------------------------
    when GET_EC =>
      eventNumber(7 downto 0) <= hostIn;
		tempo <= "10";
      rcvState    <= WAITTEMPO;
    ------------------------------------------------------
	 when WAITTEMPO =>
	   if tempo = "00" then
		  rcvState <= IDLE;
		else
		  tempo <= tempo - 1;
		end if;
	 
    when WAIT1 => rcvState <= GET_TP; -- attendre 10 ns
    ------------------------------------------------------
    when GET_TP => -- lire la partie basse du trigger pattern
      triggerPattern(7 downto 0) <= hostIn;
      setEvtReceived <= '1'; -- le message complet est reu
      rcvState    <= IDLE;
    ------------------------------------------------------
    when others => null;
    ------------------------------------------------------
    end case;
    --end if;
  end if;
end process;

--=== lwait =====================================================================================
-- Gnration de lWait
-- |fifoHighAdWr-FifoHighAdRd| reprsente le nombre d'enregistrements en attente. un signal lWait
-- est gnr si ce compte est suprieur  SEG_ALARM (dfini dans tel_defs)

lWaitGen: process (clk,reset)
begin
  if reset = '1' then
    lWaitLocal <= '0';
  elsif rising_edge(clk) then -- comparaison en entiers non signs et a marche.
--    if fifoAdWr-fifoAdRd >= conv_std_logic_vector(SEG_ALARM, HighAddrBits) then
    if wrPt-rdPt >= std_logic_vector(to_unsigned(SEG_ALARM, HighAddrBits)) then
      lwaitLocal <= '1';
    else
      lWaitLocal <= '0';
    end if;
  end if;
end process;

--=============================================================================================
--    Gestion des registres
--=============================================================================================

regLoad: process (clk, reset, slowCtBus)
variable decod : std_logic;
variable lowerField : std_logic_vector(RD_ENG_FLD-1 downto 0); -- pour faciliter le dcodage

begin
  if slowCtBus.addr(SC_AD_WIDTH-1 downto RD_ENG_FLD) = RD_ENG_REG(SC_AD_WIDTH-1 downto RD_ENG_FLD)
  then decod := '1';
  else decod := '0';
  end if;
  lowerField := slowCtBus.addr(RD_ENG_FLD-1 downto 0);
  
  if reset = '1' then
    ctrlReg <= (others => '0');
    saveParam <= DEFAULT_SAVE_WAVE;	 	 
  elsif rising_edge(clk) then
    slowCtBusRd <= (others => '0'); -- slowCtBusRd est un registre clock par clk
    if slowCtBus.rd = '1' and decod = '1' then
      case lowerField is
      when TS_REQ         => slowCtBusRd <= '0' & tsRequest;
      when TS_VAL         => slowCtBusRd <= '0' & tsVal;
      when WAVER_SAVE     => slowCtBusRd <= std_logic_vector(TO_UNSIGNED(saveParam,16));				
      when others => null;
      end case;
    elsif slowCtBus.wr = '1' and decod = '1' then
      case lowerField is
      when RD_ENG_CTRL => ctrlReg(0) <= slowCtBus.data(0); -- bit de commande de lwait alatoire
      when WAVER_SAVE  => saveParam <= TO_INTEGER(unsigned(slowCtBus.data));	-- saving period = 2^saveParam
      when others => null;
      end case;
    end if;
  end if;
end process regLoad;

--===============================================================================================
-- gnrateur de squence alatoire -------------------------------------------------------------
--===============================================================================================

randomizer: process (reset, clk)
begin
  if reset = '1' then
    hacheur <= x"1234";
  elsif rising_edge(clk) then
    -- configuration de Galois, de priode 65535
    hacheur <= hacheur(0) &
               hacheur(15) &
              (hacheur(14) xor hacheur(0)) &
              (hacheur(13) xor hacheur(0)) &
               hacheur(12) &
              (hacheur(11) xor hacheur(0)) &
               hacheur(10 downto 1);
    if hacheur(0) = '1' and hacheur(1) = '1' and hacheur(2) = '1' then -- probabilit 1/8
      slowRand <= not slowRand;
    end if;
  end if;
end process randomizer;


--===============================================================================================
-- periodical waveform memorization flag generation

saveWaveform: process (reset, clk) 
begin
	if reset = '1' then
      saveWaveFlag <= false;
		saveWave <= (others => '0');		
   elsif rising_edge(clk) then
      if saveParam = 0 then
         saveWaveFlag <= true;
      elsif saveParam > 11 then
         saveWaveFlag <= false;		
      else
		   saveWave((saveParam-1) downto 0) <= unsigned(eventNumber((saveParam-1) downto 0)); -- quivaut  (eventNumber MOD (2^saveParam))
         saveWave(11 downto saveParam) <= (others => '0');
         saveWaveFlag <= (saveWave = unsigned(telId));
      end if;	
   end if;		
end process saveWaveform;

--==== fin de la zone commune entre A et B ======================================================


--===============================================================================================
-- Section spcifique au telescope A                                                  ==== A ====
--===============================================================================================

make_tel_a: if build_a generate
syncWr  <= syncWrLocal;
syncRd  <= syncRdLocal;
readB   <= readBLocal;
jeSuisA <= '1';

--============== Word Counter for the length ========================
lengcounter : process (reset,clk)
begin
  if reset = '1' then
    lengthcnter <= (others => '0');
	 crcResult   <= (others => '0');
	 counterSM   <= IDLE;
  elsif rising_edge(clk) then
	 case counterSM is
	   when IDLE =>
	     lengthcnter <= (others => '0');
		  crcResult   <= (others => '0');
		  if spyBus (15 downto 12) = EC_TAG and phase = '0' then
		    lengthcnter <= X"001";
			 crcResult   <= spyBus(15 downto 8) xor spyBus(7 downto 0);
		    counterSM <= COUNTING;
		  end if;
			 
		when COUNTING =>
		  if finishcounting = '1' then
		    counterSM <= IDLE;
		  elsif phase = '0' then
		    if spyBus /= X"8080" then
		      case spyBus(15 downto 12) is
		        when CRCFE_TAG => null;
				  when LENGTH_TAG => null;
			     when EOE_TAG => null;
			     when others => 
				    lengthcnter <= lengthcnter + 1;
				    crcResult   <= spyBus(15 downto 8) xor spyBus(7 downto 0) xor crcResult;
			   end case;
		    end if;
		  end if;
	   end case;
  end if;
end process lengcounter;


--===== Talker ========================================================================== A =====
-- Lit les voies et met les donnes vers FastLink
-- Un message comporte:
-- le N d'evt EC, le N du telescope detGid, le timestamp du global trigger GTTAG
-- le timestamp du local request DETTAG
-- la suite des donnes compose par les voies (qui arrive par dataIn)
--======================================================================================= A =====

talkerSeqAProc: process(reset, clk)
begin
  if reset = '1' then
    talkerCsA     <= IDLE;
    rdPt          <= (others => '0');
    segRdLocal    <= (others => '0');
    voieIntLocal  <= '1';
    readOutLocal  <= '0';
    readBLocal    <= '0';
    throttleLocal <= '1'; -- autoriser l'mission
  elsif rising_edge(clk) then
    if clear = '1' then
      talkerCsA     <= IDLE;
      rdPt          <= (others => '0');
      segRdLocal    <= (others => '0');
      voieIntLocal  <= '1';
      readOutLocal  <= '0';
      readBLocal    <= '0';
      throttleLocal <= '1'; -- autoriser l'mission
    else
      -------------------------------------------------------------
      -- gestion de la phase  partir du moment o l'on commence  mettre
      if talkerCsA = IDLE then
        phase <= '0';
      else
        phase <= not phase;
      end if;
      
      if phase = '0' then -- volution de la machine  50 MHz
        case talkerCsA is
        --------------------------------------
        when IDLE =>
          voieIntLocal  <= '1';
          readOutLocal  <= '0';
          readBLocal    <= '0';			 
          throttleLocal <= '1'; -- autoriser l'mission
          if rdPt /= wrPt then
            phase <= '1';
            talkerCsA <= GET_SEG;
          end if;
        ---------------------------------------------------------------------------------- A ----
        when GET_SEG =>                            -- extraire le N de segment de la FIFO
		    finishcounting <= '0';
          segRdLocal <= fifoOut(SEG_BITS-1 downto 0);   -- numro de segment  lire
          if veto = '0' then
            talkerCsA <= EVENT_CT1;
          else
            timer <= std_logic_vector(to_unsigned(DELAI_0, TIMER_BITS)); -- aller attendre que
            --readBLocal    <= '1';
            talkerCsA <= WAIT_BDONE;                          -- bDone soit stable
          end if;         
        ---------------------------------------------------------------------------------- A ----
        when WAIT_BDONE =>
          if timer = 0 then
            if bDone = '0' then -- B est \null
              timer <= std_logic_vector(to_unsigned(DELAI_1, TIMER_BITS));
              talkerCsA <= WAIT_START_B;
            else
              readBLocal   <= '1'; -- ne sert que si B tait veto
              talkerCsA <= EOE; -- B est null. bDone n'est pas tomb, B n'a rien  dire
            end if;
          else
            timer <= timer -1;
          end if;
        -----------------------------------------------
        when WAIT_START_B =>
          if timer = 0 then
            talkerCsA <= EVENT_CT2;
          else
            timer <= timer -1;
          end if;
        -----------------------------------------------
        when EVENT_CT1 =>
 --         readOutLocal <= '1';
          talkerCsA <= TEL_ID;
        ---------------------------------------------------------------------------------- A ----
        when TEL_ID   => 
        readOutLocal <= '1';		  
        talkerCsA <= GT_TAG;
        -----------------------------------------------
        when GT_TAG   => talkerCsA <= DET_TAG;
        -----------------------------------------------
        when DET_TAG  => talkerCsA <= TRG_BITMASK;
        -----------------------------------------------		  
        when TRG_BITMASK  => talkerCsA <= TALKING;
        -----------------------------------------------  	  
        when TALKING =>
		    if blkBusy = '0' then
            if done = '1' then -- A a termin
              readOutLocal <= '0';
              if bDone = '1' then -- B n'a rien  transmettre
				    timerAvantLeng <= std_logic_vector(to_unsigned(DELAI_5,4));
                talkerCsA <= DELAITOLENG;
              else
                timer <= std_logic_vector(to_unsigned(DELAI_2, TIMER_BITS));
                talkerCsA <= WAIT_FIFO_3A;
              end if;
            end if;
			 else
			   throttleLocal <= '0'; -- bloquer l'mission par les blocs
				talkerCsA <= HOLD;
			 end if;
		  --------------------------------------
		  when HOLD =>
		    if blkBusy = '0' then
            throttleLocal <= '1'; -- autoriser l'mission par les blocs
				talkerCsA <= TALKING;
			 end if;
		  --------------------------------------
		  when DELAITOLENG =>
		    if timerAvantLeng = 0 then
			   talkerCsA <= LENG;
			 else
			   timerAvantLeng <= timerAvantLeng -1;
			 end if;
        --------------------------------------
        when WAIT_FIFO_3A =>
          if timer = 0 then
            readBLocal   <= '1';
            talkerCsA <= XFER_B0;
          else
            timer <= timer -1;
          end if;
        ---------------------------------------------------------------------------------- A ----
        when EVENT_CT2 => talkerCsA <= WAIT_XFER_BO;
        --------------------------------------
		  when WAIT_XFER_BO => 
		    talkerCsA <= XFER_B0;
		    timer <= std_logic_vector(to_unsigned(10, TIMER_BITS));
		  ---------------------------------------
        when XFER_B0   =>
		    if timer = 0 then
			   readBLocal    <= '1';
            voieIntLocal <= '0';
            talkerCsA <= XFER_B;
		    else
			   timer <= timer -1;
			 end if;
        --------------------------------------
        when XFER_B  =>
          if bDone = '1' then
            timer <= std_logic_vector(to_unsigned(DELAI_3, TIMER_BITS));
            talkerCsA <= WAIT_FIFO_3B;
          end if;
        --------------------------------------
        when WAIT_FIFO_3B =>
          if timer = 0 then
			   voieIntLocal   <= '1';
            talkerCsA <= LENG;
          else
            timer <= timer -1;
          end if;
        --------------------------------------
        when LENG    =>
          readBLocal   <= '1'; -- ne sert que si B tait veto
          talkerCsA <= CRC;
        --------------------------------------
        when CRC     => talkerCsA <= EOE;
        --------------------------------------
        when EOE   =>
          --readBLocal   <= '0';
          rdPt <= rdPt + 1;
          if rdPt = all_one(HighAddrBits-1 downto 0) then
            syncRdLocal <= '1';
          else
            syncRdLocal <= '0';
          end if;
          talkerCsA <= WAIT_FIFO_4;
        --------------------------------------
        when WAIT_FIFO_4 =>
		    readBLocal   <= '0';
          voieIntLocal <= '1';
          talkerCsA <= IDLE;
			 finishcounting <= '1';
        --------------------------------------
        when others  => null;
        --------------------------------------
        end case;
      end if;
      
      ------------------------------------------------------------------------------------ A ----
      -- Evolution de la machine d'tat
--      if timeOutTalker = 1 then -- si le compteur de timeout passe par la valeur 1, raz machine
--        talkerCsA    <= IDLE;
--        prochainEtat := IDLE;
--      elsif talkerCsA = HOLD then
--        if blkBusy = '0' and phase = '0' then
--          talkerCsA <= talkerReturnA; -- quitter l'tat HOLD
--        end if;
--        -------------------------------------------------------------
--        -- gestion du compteur de timeout
--        if timeOutTalker /= 0 then
--          timeOutTalker <= timeOutTalker-1;
--        end if;
--        -------------------------------------------------------------
--      else -- si on n'est pas en HOLD
--        if blkBusy = '1' and phase = '0' then -- on va passer en HOLD
--          talkerReturnA <= prochainEtat; -- se souvenir de l'tat futur pour pouvoir y aller en quittant HOLD
--          talkerCsA <= HOLD;
--        else
--          talkerCsA <= prochainEtat; -- le cas normal
--        end if;
--      end if;

--      if talkerCsA = HOLD then
--        if blkBusy = '0' and phase = '0' then
--          talkerCsA <= talkerReturnA; -- quitter l'tat HOLD
--        end if;
--        -------------------------------------------------------------
--      else -- si on n'est pas en HOLD
--        if blkBusy = '1' and phase = '0' then -- on va passer en HOLD
--          talkerReturnA <= prochainEtat; -- se souvenir de l'tat futur pour pouvoir y aller en quittant HOLD
--          talkerCsA <= HOLD;
--        else
--          talkerCsA <= prochainEtat; -- le cas normal
--        end if;
--      end if;


    end if;
  end if;

end process talkerSeqAProc;

--====================================================================================== A ====
talkerCombAProc: process(talkerCsA)
begin
  hostOut       <= EMPTY_TAG & x"0" & EMPTY_TAG & x"0"; -- 8080
  case talkerCsA is
    --------------------------------------
    when IDLE         => 
	   fifoItemRd    <= ITEM_SEG; -- fifoItemRd vaut ITEM_SEG par dfaut
    --------------------------------------
    when GET_SEG      => null; -- fifoItemRd vaut ITEM_SEG par dfaut
    --------------------------------------
    when WAIT_BDONE   => null;
    --------------------------------------
    when WAIT_START_B => null;
    --------------------------------------
    when EVENT_CT1 =>
      fifoItemRd <= ITEM_EVT;
      hostOut    <= EC_TAG & fifoOut(11 downto 0);
    --------------------------------------
    when TEL_ID   =>
      hostOut <= TELID_TAG & "0000000" & telId; -- 98
    ------------------------------------------------------------------------------------ A ----
    when GT_TAG   =>
      fifoItemRd <= ITEM_TS_VAL;
      hostOut <= fifoOut; -- global trigger (ts of val)
    --------------------------------------
    when DET_TAG  =>
      fifoItemRd <= ITEM_TS_REQ;
      hostOut <= fifoOut; -- ts of request
    --------------------------------------
    when TRG_BITMASK =>
      fifoItemRd <= ITEM_BITMASK;
      hostOut <= fifoOut; -- trigger bitmask
    --------------------------------------		
    when TALKING  => 
      fifoItemRd <= ITEM_SEG;
      hostOut <= dataIn;
    --------------------------------------
    when  EVENT_CT2 =>
      fifoItemRd <= ITEM_EVT;
      hostOut    <= EC_TAG & fifoOut(11 downto 0);
	 --------------------------------------
	 when WAIT_XFER_BO => null;
    --------------------------------------
    when XFER_B0   => null; -- un coup sans faire retomber voieInt
    --------------------------------------
    when XFER_B    => null;
    --------------------------------------
    when WAIT_FIFO_3B => null;
    --------------------------------------
    when LENG  =>
      hostOut  <= LENGTH_TAG & lengthcnter;
    --------------------------------------
    when CRC   =>
      hostOut  <= CRCFE_TAG & crcResult & X"0";
    --------------------------------------
    when EOE   =>
      hostOut  <= EOE_TAG & x"000";
    --------------------------------------
    when WAIT_FIFO_4   =>
      hostOut  <= EMPTY_TAG & x"0" & EMPTY_TAG & x"0";
    ----------------------------------------------------
    when HOLD =>
      hostOut     <= EMPTY_TAG & x"0" & EMPTY_TAG & x"0";
    --------------------------------------
    when others   => null;
    --------------------------------------
  end case;
end process talkerCombAProc;

--====================================================================================== A ====
-- le gnrateur de parit (CRC)
--
--geneCrc: process (reset, clk)
--begin
--  if reset = '1' then
--    crcReg <= (others => '0');
--    par <= '0';
--  elsif rising_edge (clk) then
--    if talkerCsA = IDLE then
--      crcReg <= (others => '0');
--      par <= '0';
--    else
--      par <= not par; -- pour n'oprer qu'un coup sur 2 (sortie des donnes  50 MHz)
--      if par = '1' then
--        crcReg <= crcReg xor hostOut(11 downto 0);
--      end if;
--    end if;
--  end if;
--end process;

-- incrmentation du pointeur d'criture --------------------------------------------------------
--upWrProcA: process (reset, clk)
--begin
--  if reset = '1' then
--    wrPt <= (others => '0');
--  elsif rising_edge(clk) then
--    if clear = '1' then
--      wrPt <= (others => '0');
--    end if;
--    if updateWr = '1' then
--      wrPt <= wrPt + 1; -- prt pour le prochain evt et libration talker
----      if wrPt = ALL_ONE(HighAddrBits-1 downto 0) then
----        syncWrLocal <= '1';
----      else
----        syncWrLocal <= '0';
----      end if;
--    end if;
--  end if;
--end process;


end generate; ---------------------------------------------------------------------------- A ----

--===============================================================================================
-- Section spcifique au telescope B                                                  ==== B ====
--===============================================================================================

make_tel_b: if not build_a generate

jeSuisA <= '0';
bDone   <= bDoneLocal;

--===== Talker =========================================================================== B ====
-- Lit les voies et met les donnes vers FastLink
-- Un message comporte:
-- le N d'evt EC, le N du telescope detGid, le timestamp du global trigger GTTAG
-- le timestamp du local request DETTAG
-- la suite des donnes compose par les voies (qui arrive par dataIn)
--===============================================================================================

talkerSeqBProc: process(reset, clk)
begin
  if reset = '1' then
    phase      <= '0';
    talkerCsB   <= IDLE;
    rdPt       <= (others => '0');
    segRdLocal <= (others => '0');
    readOutLocal <= '0';
	 throttleLocal <= '1'; -- autoriser l'mission
  elsif rising_edge(clk) then
    if clear = '1' then
      phase      <= '0';
      talkerCsB   <= IDLE;
      rdPt       <= (others => '0');
      segRdLocal <= (others => '0');
      readOutLocal <= '0';
		throttleLocal <= '1'; -- autoriser l'mission
    else
      -------------------------------------------------------------
      -- gestion de la phase  partir du moment o l'on commence  mettre
      if talkerCsB = IDLE then
        phase <= '0';
      else
        phase <= not phase;
      end if;
      
      if phase = '0' then -- Evolution de la machine @ 50 MHz
        case talkerCsB is
        -------------------------------------------------------------------------------- B ----
        when IDLE =>
		    throttleLocal <= '1'; -- autoriser l'mission
          bDoneLocal <= '1';
          --timeOutTalker <= (others => '0');
          readOutLocal <= '0';
          if rdPt /= wrPt then
            phase <= '1';
            --timeOutTalker <= conv_std_logic_vector(30000, 16); -- armement du timeout (300 s)
            talkerCsB <= GET_SEG;
          end if;
        --------------------------------------
        when GET_SEG => -- extraire le N de segment de la FIFO
          segRdLocal <= fifoOut(SEG_BITS-1 downto 0);   -- numro de segment  lire
          if veto = '0' then
            bDoneLocal <= '0';
            talkerCsB <= WAIT_A;
          else
            talkerCsB <= WAIT_A1;
          end if;
        -------------------------------------------------------------------------------- B ------
        when WAIT_A  =>
          if readB = '1' then
 --           readOutLocal <= '1';
            talkerCsB <= TEL_ID;
          end if;
        --------------------------------------
        when TEL_ID  => 
          readOutLocal <= '1';
          talkerCsB <= GT_TAG;
        --------------------------------------
        when GT_TAG  => talkerCsB <= DET_TAG;
        --------------------------------------
        when DET_TAG => talkerCsB <= TRG_BITMASK;
        --------------------------------------		  
        when TRG_BITMASK => talkerCsB <= TALKING;
        --------------------------------------	  
        when TALKING =>
          if blkBusy = '0' then
            if done = '1' then
              readOutLocal <= '0';
              bDoneLocal <= '1';
              talkerCsB <= ACQUIT;
            end if;
          else
             throttleLocal <= '0'; -- bloquer l'mission par les blocs
             talkerCsB <= HOLD;
          end if;
        --------------------------------------
        when HOLD =>
          if blkBusy = '0' then
             throttleLocal <= '1'; -- autoriser l'mission par les blocs
             talkerCsB <= TALKING;
			 end if;
		  --------------------------------------	  
        when WAIT_A1 =>
          if readB = '1' then
            talkerCsB <= ACQUIT;
          end if;
        --------------------------------------
        when ACQUIT =>
          if readB = '0' then
            if syncRd = '1' then
              rdPt <= (others => '0'); -- rafraichissement forc par A
            else
              rdPt <= rdPt + 1;
            end if;
            talkerCsB <= IDLE;
          end if;
        --------------------------------------
        when others  => null;
        --------------------------------------
        end case;
      end if;
      
      ----------------------------------------------------------------------------------- B -----
      -- Evolution de la machine d'tat
--      if timeOutTalker = 1 then -- si le compteur de timeout passe par la valeur 1, raz machine
--        talkerCsB <= IDLE;
--      elsif talkerCsB = HOLD then
--        if blkBusy = '0' and phase = '0' then
--          talkerCsB <= talkerReturnB; -- quitter l'tat HOLD
--        end if;
--        -------------------------------------------------------------
--        -- gestion du compteur de timeout
--        if timeOutTalker /= 0 then
--          timeOutTalker <= timeOutTalker-1;
--        end if;
--        -------------------------------------------------------------
--      else -- si on n'est pas en HOLD
--        if blkBusy = '1' and phase = '0' then -- on va passer en HOLD
--          talkerReturnB <= prochainEtat; -- se souvenir de l'tat futur pour pouvoir y aller en quittant HOLD
--          talkerCsB <= HOLD;
--        else
--          talkerCsB <= prochainEtat; -- le cas normal
--        end if;
--      end if;
      
--      if talkerCsB = HOLD then
--        if blkBusy = '0' and phase = '0' then
--          talkerCsB <= talkerReturnB; -- quitter l'tat HOLD
--        end if;
--        -------------------------------------------------------------
--      else -- si on n'est pas en HOLD
--        if blkBusy = '1' and phase = '0' then -- on va passer en HOLD
--          talkerReturnB <= prochainEtat; -- se souvenir de l'tat futur pour pouvoir y aller en quittant HOLD
--          talkerCsB <= HOLD;
--        else
--          talkerCsB <= prochainEtat; -- le cas normal
--        end if;
--      end if;
      
       -------------------------------------------------------------
    end if;
  end if;

end process talkerSeqBProc;

--====================================================================================== B ====
talkerCombBProc: process(talkerCsB)
begin
  --readOutLocal  <= '0';
  --throttleLocal <= '1'; -- autoriser l'mission
--  fifoItemRd    <= ITEM_SEG;
  voieIntLocal  <= '1'; -- aiguillage des donnes en interne par dfaut
  hostOut       <= EMPTY_TAG & x"0" & EMPTY_TAG & x"0"; -- 8080
  readBLocal    <= '0';
  
  case talkerCsB is
    --------------------------------------
    when IDLE     => 
      fifoItemRd    <= ITEM_SEG;
    --------------------------------------
    when GET_SEG  => null;
    --------------------------------------
    when TEL_ID   =>
      hostOut <= TELID_TAG & "0000000" & telId; -- 98
    --------------------------------------
    when WAIT_A  =>
    ------------------------------------------------------------------------------------ B ------
    when GT_TAG   => null;
      fifoItemRd <= ITEM_TS_VAL;
      hostOut <= fifoOut; -- global trigger (ts of val)
    --------------------------------------
    when DET_TAG  =>
      fifoItemRd <= ITEM_TS_REQ;
      hostOut    <= fifoOut; -- ts of request
    --------------------------------------
    when TRG_BITMASK =>
      fifoItemRd <= ITEM_BITMASK;
      hostOut    <= fifoOut; -- trigger bitmask
    --------------------------------------		 
    when TALKING  =>
      fifoItemRd <= ITEM_SEG;
      hostOut    <= dataIn;
    --------------------------------------
    when ACQUIT =>
      hostOut    <= EMPTY_TAG & x"0" & EMPTY_TAG & x"0";
    --------------------------------------
    when HOLD =>
      hostOut    <= EMPTY_TAG & x"0" & EMPTY_TAG & x"0";
    ------------------------------------------------------------------------------------ B ------
    when others   => null;
    --------------------------------------
  end case;
end process talkerCombBProc;
end generate; -------------------------------------------------------------------------- B ----

end Behavioral;

