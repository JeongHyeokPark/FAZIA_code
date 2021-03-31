-------------------------------------------------------------------------------------------------
-- Company:  IPNO
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:    09:07:56 11/23/2011 
-- Design Name: telescope
--===============================================================================================
-- Module Name:                       ===== telescope =====
--===============================================================================================
-- File:   telescope.vhd
-- Project Name:  Fazia
-- Target Devices: Virtex-5
-- Tool versions: 12.4
-- Description:
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
--------------------------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;
library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;
use work.telescope_conf.all;

-------------------------------------------------------------------------------------------------
entity telescope is
  port (
    ----------------------------------- signaux gnraux
    sysClk_n    : in    std_logic;
    sysClk_p    : in    std_logic;
    --clkBack     : out   std_logic;
    resetIn     : in    std_logic;
    syncZer     : in    std_logic;
    clk25MHz_n  : in    std_logic;
    clk25MHz_p  : in    std_logic;
    -- DACs d'offset pramplis ---------------------------------
    dacScl      : out   std_logic;
    dacSda      : out   std_logic;
    adjust1     : out   std_logic;
    adjust2     : out   std_logic;
    adjust3     : out   std_logic;
    ----------------------------------- LTC 2260 - = Energy 4 GeV Si-1   QH1
    adcQH1Sclk  : out   std_logic;
    adcQH1Cs_n  : out   std_logic;
    adcQH1Sdo   : in    std_logic;
    adcQH1Sdio  : out   std_logic;
    ----
    adcQH1_n    : in    std_logic_vector (7 downto 0);
    adcQH1_p    : in    std_logic_vector (7 downto 0);
    ckAdcQH1_n  : in    std_logic;
    ckAdcQH1_p  : in    std_logic;
    ----------------------------------- KAD 5514 - = Current Si-1         I1
    adcI1Sclk   : out   std_logic;
    adcI1Rst_n  : out   std_logic;
    adcI1Cs_n   : out   std_logic;
    adcI1Sdo    : in    std_logic;
    adcI1Sdio   : out   std_logic;
    ----
    adcI1_n     : in    std_logic_vector (7 downto 0);
    adcI1_p     : in    std_logic_vector (7 downto 0);
    ckAdcI1_n   : in    std_logic;
    ckAdcI1_p   : in    std_logic;
    ----------------------------------- KAD 5514 - = Energy 250 MeV Si-1 QL1
    adcQL1Sclk  : out   std_logic;
    adcQL1Rst_n : out   std_logic;
    adcQL1Cs_n  : out   std_logic;
    adcQL1Sdo   : in    std_logic;
    adcQL1Sdio  : out   std_logic;
    ----
    adcQL1_n    : in    std_logic_vector (7 downto 0);
    adcQL1_p    : in    std_logic_vector (7 downto 0);
    ckAdcQL1_n  : in    std_logic;
    ckAdcQL1_p  : in    std_logic;
    ----------------------------------- LTC 2260 - = Energy 4 GeV Si-2    Q2
    adcQ2Sclk   : out   std_logic;
    adcQ2Cs_n   : out   std_logic;
    adcQ2Sdo    : in    std_logic;
    adcQ2Sdio   : out   std_logic;
    ----
    adcQ2_n     : in    std_logic_vector (7 downto 0);
    adcQ2_p     : in    std_logic_vector (7 downto 0);
    ckAdcQ2_n   : in    std_logic;
    ckAdcQ2_p   : in    std_logic;
    ----------------------------------- KAD 5514 - = Current Si-2         I2
    adcI2Sclk   : out   std_logic;
    adcI2Rst_n  : out   std_logic;
    adcI2Cs_n   : out   std_logic;
    adcI2Sdo    : in    std_logic;
    adcI2Sdio   : out   std_logic;
    ----
    adcI2_n     : in    std_logic_vector (7 downto 0);
    adcI2_p     : in    std_logic_vector (7 downto 0);
    ckAdcI2_n   : in    std_logic;
    ckAdcI2_p   : in    std_logic;
    ----------------------------------- LTC 2260 - = Energy 4 GeV CsI     Q3
    adcQ3Sclk   : out   std_logic;
    adcQ3Cs_n   : out   std_logic;
    adcQ3Sdo    : in    std_logic;
    adcQ3Sdio   : out   std_logic;
    ----
    adcQ3_n     : in    std_logic_vector (7 downto 0);
    adcQ3_p     : in    std_logic_vector (7 downto 0);
    ckAdcQ3_n   : in    std_logic;
    ckAdcQ3_p   : in    std_logic;
    ----------------------------------- Interface PIC (point de vue du pic)
    ucSpiSdi    : out   std_logic; -- in/out du point de vue du pic
    ucSpiSdo    : in    std_logic;
    ucSpiSck    : in    std_logic;
    ucSpiSs_n   : in    std_logic;
    ----------------------------------- Interface USB
    dataUsb     : inout std_logic_vector (7 downto 0);
    rxf_n       : in    std_logic;
    txe_n       : in    std_logic;
    rdUsb_n     : inout std_logic; -- sortie tristate (on peut aussi lire)
    wrUsb       : out   std_logic; -- sortie tristate
    -----------------------------------
    -- io  usage gnral (voir schma page 16)
    galClk      : out   std_logic;
    galIO       : out   std_logic_vector(13 downto 0); -- DAC rapide
    aux_0       : out   std_logic;
    aux_1       : out   std_logic;
    aux_2       : out   std_logic;
    ledRouge    : out   std_logic;
    ledVerte    : out   std_logic;
    ledJaune    : out   std_logic;
    ledBleue    : out   std_logic;
    -----------------------------------
    -- io srie rapides
    sdi_p       : in     std_logic;
    sdi_n       : in     std_logic;
    sdi_H_p     : in     std_logic;
    sdi_H_n     : in     std_logic;
    sdi_L_p     : in     std_logic;
    sdi_L_n     : in     std_logic;
    ---
    alignIn     : in     std_logic;
    lWaitIn     : in     std_logic;
    blkBusyIn   : in     std_logic;
    alignOut    : out    std_logic;
    lWaitOut    : out    std_logic; -- devra tre open drain
    blkBusyOut  : out    std_logic;
    ---
    sdo_p       : out    std_logic;
    sdo_n       : out    std_logic;
    sdo_H_p     : out    std_logic;
    sdo_H_n     : out    std_logic;
    sdo_L_p     : out    std_logic;
    sdo_L_n     : out    std_logic;
    ---
    free_p      : inout  std_logic;
    free_n      : inout  std_logic;
    ---
    idFpga      : in     std_logic;
    
    --- trigger
    lt          : out    std_logic; -- local trigger (trigger request to block card)
    glt      : inout  std_logic; -- global trigger (trigger validation from block card)

    
    --- i/o de communication entre A et B
    
    aVersB_0   : inout  std_logic; -- propagation de LD1 de A vers B
    aVersB_1   : inout  std_logic; -- tokenRequest de B vers A (obsolete)
    aVersB_2   : inout  std_logic; -- tokenGrant de A vers B (obsolete)
    aVersB_3   : inout  std_logic; -- en mode stand alone, il s'agit du glt local du A vers le B
                                                      -- 0 sert  acheminer ltB vers tel A
    riserv_n   : inout  std_logic_vector(7 downto 0); -- 1 = syncW, 2 = syncR, 3 = readB, 4 = bDone
    riserv_p   : inout  std_logic_vector(7 downto 0); -- 5 = acqBusyARaw, 6 = acqBusyBRaw, 7 = clkGene
                                  ------ A -------- B ------------
    ioFpga_4   : inout std_logic; -- riserv0   |  reserv6 = pulser depuis le FdP
    ioFpga_5   : out   std_logic; -- riserv1   |  reserv7
    ioFpga_6   : out   std_logic; -- riserv2   |  reserv8
    ioFpga_7   : out   std_logic; -- riserv3   |  reserv9
    ioFpga_8   : out   std_logic; -- riserv4   |  reserv10
    ioFpga_9   : inout std_logic; -- riserv5   |  reserv11
    ioFpga_10  : in    std_logic; -- riserv12  |  reserv12  att. ! le mme pour A et B

    ioFpga_11  : inout  std_logic; -- A_VERS_B_4 sur tel A et tel B
    ioFpga_12  : inout  std_logic; -- A_VERS_B_5 sur tel A et syncVP2_5 sur tel B
    ioFpga_13  : inout  std_logic; -- A_VERS_B_6 sur tel A et A_VERS_B_5 sur tel B
    ioFpga_14  : inout  std_logic; -- A_VERS_B_7 sur tel A et syncVP3_7 sur tel B
    ioFpga_15  : inout  std_logic; -- A_VERS_PIC sur tel A et syncVM2_7 sur tel B

    ioFpga_17  : inout  std_logic; -- uWire1 sur tel_a, sync_hv sur tel_b 
    ioFpga_18  : inout  std_logic; -- uWire2 sur tel_a, clkGene sur tel_b
    ioFpga_19  : inout  std_logic; -- clk_uwire sur tel_a, A_VERS_B_6 sur tel_b
    ioFpga_20  : inout  std_logic; -- data_uwire sur tel_a, A_VERS_B_7 sur tel_b
    ioFpga_21  : inout  std_logic; -- sur tel_a: ld1 lock detected LMK2000 100 MHz et sur tel_b: b_vers_pic_1
    ioFpga_22  : inout  std_logic  -- sur tel_a: ld2 lock detected LMK2000 250 MHz et sur tel_b: b_vers_pic_2
  );
end telescope;

-------------------------------------------------------------------------------------------------
architecture telescope_arch of telescope is

component dcm_200
  port (
    CLKIN_IN   : in    std_logic; 
    RST_IN     : in    std_logic; 
    CLK0_OUT   : out   std_logic; 
    CLK2X_OUT  : out   std_logic;
    LOCKED_OUT : out   std_logic
  );
end component dcm_200;

--===============================================================================================
component TalkToLmk
  generic (
    RegAd : std_logic_vector(SC_AD_WIDTH-1 downto 0) -- adresse absolue
  );
	port (
    clk       : in   std_logic; -- horloge  25 MHz
    sysClk    : in   std_logic; -- horloge systme  100 MHz
    resetIn   : in   std_logic;
    ---
    uWire1    : out  std_logic;
    uWire2    : out  std_logic;
    ckUWire   : out  std_logic;
    dataUWire : out  std_logic;
    ---
    slowCtBus : in   SlowCtBusRec
  );
end component TalkToLmk;

--===============================================================================================
--component Mutex
--  port (
--    clk           : in  std_logic;
--    reset         : in  std_logic;
--    ---
--    tokenRequestA : in  std_logic;
--    tokenGrantA   : out std_logic;
--    ---
--    tokenRequestB : in  std_logic;
--    tokenGrantB   : out std_logic
--  );
--end component Mutex;

--===============================================================================================
component GlobalTrigger
  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    ---
    ltA          : in  std_logic;
    ltB          : in  std_logic;
    localWaitOut : in std_logic;
    glt          : out std_logic
  );
end component GlobalTrigger;

--===============================================================================================
-- les i/o communs de tel_a et tel_b
alias a_vers_b_4  is ioFpga_11;

--===============================================================================================
-- les i/o de tel_a
alias pulserGlob is ioFpga_4;  -- le signal pulser en provenance du fond de panier
alias a_vers_b_5 is ioFpga_12;
alias a_vers_b_6 is ioFpga_13;
alias a_vers_b_7 is ioFpga_14;
alias a_vers_pic is ioFpga_15;
alias uWire1     is ioFpga_17;
alias uWire2     is ioFpga_18;
alias clkUWire   is ioFpga_19;
alias dataUWire  is ioFpga_20;
alias ld1        is ioFpga_21;
alias ld2        is ioFpga_22;

--===============================================================================================
-- les i/o de tel_b
alias sync_vp2_5   is ioFpga_12;
alias b_vers_a_5   is ioFpga_13;
alias sync_vp3_7   is ioFpga_14;
alias sync_vm2_7   is ioFpga_15;
alias sync_hv      is ioFpga_17;
alias clkGene      is ioFpga_18;
alias b_vers_a_6   is ioFpga_19;
alias b_vers_a_7   is ioFpga_20;
alias b_vers_pic_1 is ioFpga_21;
alias b_vers_pic_2 is ioFpga_22;

--===============================================================================================
attribute keep : string;
signal clk       : std_logic;
attribute keep of clk : signal is "true";


signal reset     : std_logic;
--signal resetOred : std_logic; -- ce signal est un ou entre resetIn et ioFpga_10 qui set de reset de secours sur la carte 3
signal clear     : std_logic; -- reset soft, provient de GeneralIo
signal resetSoft : std_logic; -- reset soft, provient du pic via le GeneralIo
signal refClk    : std_logic;
-- signaux de synchro 25/100/250 MHz ---------------------------------------
signal sync      : std_logic; -- durée 10 ns période 40 ns pour les ddr et al
signal clk25MHz  : std_logic;
signal clk25Falling : std_logic; -- 25 MHz échantillonné sur le front descendant de clk
signal clk25Resync, clk25Old : std_logic; -- clk25Falling reclocké par le front montant de clk
signal timer_250ms : std_logic_vector (7 downto 0);
-- segments ----------------------------------------------------------------
signal segNrRd, segNrWr : std_logic_vector(SEG_BITS-1 downto 0);
type array_of_data is array (NB_CHAN downto 0) of std_logic_vector(DATA_WITH_TAG-1 downto 0);
signal data      : array_of_data;
signal readInOut : std_logic_vector(NB_CHAN downto 0); -- un bit de + que de voies
signal done      : std_logic_vector(NB_CHAN downto 0);
signal acqBusy   : std_logic_vector(NB_CHAN downto 0);
signal throttle  : std_logic;
signal saveWaveFlag : boolean;

-- les signaux de trigger
signal ltLocal, ltOld, ltRise : std_logic;
signal ltLed     : std_logic;
signal gltA,gltLocal  : std_logic;
signal valExt : std_logic; -- bit de configuration: glt arrive depuis le connecteur si vrai

signal val, veto : std_logic;
signal valLed    : std_logic;
signal trigFastH : std_logic_vector(NB_SLOW-1 downto 0);
signal trigFastL : std_logic_vector(NB_SLOW-1 downto 0);
signal trigSlow  : std_logic_vector(NB_SLOW-1 downto 0);
signal trigBitmask: std_logic_vector(14 downto 0);
--signal trigReq   : std_logic;
--signal trigExt   : std_logic;
--signal rdRdy     : std_logic;
signal timeStamp : std_logic_vector(TS_BITS-1 downto 0);

--------------------------------------------------------------------
-- handshake des communications srie
--signal tokenRequestLocal : std_logic; -- demande de communication depuis readEngine
--signal tokenGrantLocal   : std_logic; -- autorisation de communication
--signal tokenRequestRemote: std_logic; -- demande de communication depuis tel B
--signal tokenGrantRemote  : std_logic; -- autorisation de communication vers tel B
-- liaisons readEngine <--> fastlink
signal rdToFast   : std_logic_vector(15 downto 0);
signal fastToRd   : std_logic_vector( 7 downto 0);
signal voieInt    : std_logic; -- slection source parallle vers sortie DAQ srie
-- handshake block card <--> readEngine
signal lWait, blkBusy : std_logic; -- routs slectivement selon que l'on est A ou B
signal localWaitOutLocal  : std_logic; 
--signal dataVM_rdy : std_logic; -- synchro des octets de la voie montante
signal spyBus     : std_logic_vector(15 downto 0);
signal alignInLocal : std_logic;
--------------------------------------------------------------------
signal telId     : std_logic_vector( 3 downto 0);
----------------------------------------- bus d'alignement des donnes ADC -------------------
signal alignBus     : alignBusRec;
signal alignDataBit : std_logic_vector (ADCS_TOTAL-1 downto 0);
signal inspectBits  : std_logic_vector (6 downto 0); -- 6  + adcMon
--signal inspect      : std_logic; -- le regroupement des signaux d'inspection
---------------------------------------------------------------------
type bus_data   is array (0 to CHAN_TOP) of std_logic_vector(15 downto 0);
signal slowCtRd         : bus_data;   -- donnes de lecture slow control pour les voies
signal slowCtBus        : slowCtBusRec;
signal slowCtBusRd      : std_logic_vector(15 downto 0); -- le regroupement de ttes les lectures
--signal slowCtBusRdDetec : std_logic_vector(15 downto 0);
signal slowCtBusRdAdc   : std_logic_vector(15 downto 0); -- le block adcMonitor
signal slowCtBusRdGal   : std_logic_vector(15 downto 0); -- le block general_io
signal slowCtBusRdTrig  : std_logic_vector(15 downto 0); -- le block trigger
signal slowCtBusRdSysMon : std_logic_vector(15 downto 0); -- le block SysMon
signal slowCtBusRdId : std_logic_vector(15 downto 0); -- le block Id
signal slowCtBusRdEng   : std_logic_vector(15 downto 0); -- le block read Engine
signal slowCtBusRdVirtu : std_logic_vector(15 downto 0); -- le block blocCard virtuelle
signal slowCtBusRdPs    : std_logic_vector(15 downto 0); -- le block blocCard virtuelle
signal slowCtBusRdZone  : std_logic_vector(15 downto 0); -- le block zone de communication
signal slowCtBusRdGene  : std_logic_vector(15 downto 0); -- le block Gene pour le pulser des preamplis
signal slowCtBusRdOffset : std_logic_vector(15 downto 0);-- le block ctrlOffset pour le réglage des offsets des préamplis
---------------------------------------------------------------------
signal microsec  : std_logic; -- provient de GeneralIo
signal millisec  : std_logic; -- idem
--signal timer     : std_logic_vector(3 downto 0);
---------------------------------------------------------------------
type fastDacType is array (0 to FAST_SIGNALS-1) of std_logic_vector (ADC_TOP downto 0);
signal fastDacVector : fastDacType;
-- bus interne qui reçoit les éléments du précédent
signal fastDac : std_logic_vector (ADC_TOP downto 0);
signal lockDetected : std_logic; -- provient de LD1 dans A et aVersB_0 dans B
signal lock200MHz : std_logic;
---------------------------------------------------------------------
--signal dummy : std_logic;
signal prescaler   : std_logic_vector (14 downto 0); -- assez pour 1.31 msec @ 25 MHz (1 ms = 25000)
signal slowClocker : std_logic_vector (9 downto 0);  -- assez pour 1.024 sec @ 1 kHz
---------------------------------------------------------------------
-- les signaux de synchronisation acquisition et readout entre A et B
signal syncWr : std_logic; -- synchro du compteur d'criture fifo (riserv<1>)
signal syncRd : std_logic; -- synchro du compteur de lecture fifo (riserv<2>)
signal readB  : std_logic; -- A demande  lire B (riserv<3>)
signal bDone  : std_logic; -- B est prt  envoyer des donnes (riserv<4>)
-- signal riserv : std_logic_vector (7 downto 7); -- destin  recevoir les buffers des i/o correspondants
signal ltB    : std_logic; -- port par riserv(0)
signal acqBusyOtherRaw : std_logic;
signal acqBusyAll  : std_logic;
signal alignFromSc : std_logic;
signal blkBusyFromSc : std_logic;

-- signaux de contrle pour Franck
signal readerStateMach_Qh1 : std_logic_vector (3 downto 0);
signal readerStateMach_Ql1 : std_logic_vector (3 downto 0);
signal readerStateMach_I1 : std_logic_vector (3 downto 0);
signal readerStateMach_Q2 : std_logic_vector (3 downto 0);
signal readerStateMach_I2 : std_logic_vector (3 downto 0);
signal readerStateMach_Q3 : std_logic_vector (3 downto 0);
signal readerErrBit       : std_logic_vector (5 downto 0);

-- comZONE
signal lBox : std_logic;

signal clkGene_int : std_logic;
signal pulserOn : std_logic;

--===== chipscope =============================================================================
-- recopi/modifi depuis histogrammer.vhd

signal all_zero_128 : std_logic_vector (127 downto 0) := (others => '0');
signal CONTROL0 : std_logic_vector (35 downto 0);
signal etatTrigger : std_logic_vector( 2 downto 0);
signal sourceBrute : std_logic;
signal alignOutLocal : std_logic;

component tel_ila
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK     : IN STD_LOGIC;
    TRIG0   : IN STD_LOGIC_VECTOR(  127 DOWNTO 0)
  );
end component;

component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
end component;

begin

--===== chipscope ===============================================================================
makeCS: if chip_teles generate

mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0
  );

mes_sondes : tel_ila
  port map (
    CONTROL => CONTROL0,
    CLK     => clk,
    ---
    trig0 (0) => voieInt,
    trig0 (1) => gltLocal,
    trig0 (2) => lWaitIn, --throttle or gltA
    trig0 (3) => lWait,
    trig0 (4) => alignOutLocal,
    trig0 (12 downto 5) => fastToRd,
    trig0 (28 downto 13) => spyBus,
	 trig0 (29) => glt,
    trig0 (30) => readInOut(0),
    trig0 (31) => readInOut(1),
    trig0 (32) => readInOut(2),
    trig0 (33) => readInOut(3),
    trig0 (34) => readInOut(4),
    trig0 (35) => readInOut(5),
    trig0 (36) => readInOut(6),
	  trig0 (52 downto 37) => rdToFast,
    trig0 (53) => bDone,
    trig0 (54) => localWaitOutLocal, --done(0)
    trig0 (55) => ltB, --done(1)
    trig0 (56) => ltLocal, --done(2)
    trig0 (57) => done(3), --done(3)
    trig0 (58) => done(4),
    trig0 (62 downto 59) => ReaderStateMach_Qh1,
    trig0 (66 downto 63) => ReaderStateMach_Ql1,
    trig0 (70 downto 67) => ReaderStateMach_I1,
    trig0 (74 downto 71) => ReaderStateMach_Q2,
    trig0 (78 downto 75) => ReaderStateMach_I2,
    trig0 (82 downto 79) => ReaderStateMach_Q3,
    trig0 (88 downto 83) => readerErrBit,
    trig0 (89) => localWaitOutLocal,
    trig0 (90) => slowCtBus.rd,
    trig0 (91) => slowCtBus.wr,
    trig0 (107 downto 92) => slowCtBusRd, --slowCtBus.data
    trig0 (123 downto 108)=> slowCtBus.addr,
    trig0 (124) => lBox,
	 trig0 (125) => b_vers_a_7,
	 trig0 (127 downto 126) => all_zero_128 (127 downto 126)
 );
end generate;

--===============================================================================================

--blkBusyOut <= '0';
--lWaitOut   <= '0';
--lt         <= ltLocal; -- ancienne version (dure maintenant 40 ns  la monte de ltLocal)



ltProc: process(clk, reset)
begin
  if reset = '1' then
    ltRise <= '0';
  elsif rising_edge(clk) then
    ltOld <= ltLocal;
    if ltLocal = '1' and ltOld = '0' then -- dtection de la monte de lt
      ltRise <= '1';
    end if;
    
    if clk25Resync = '0' and clk25Old = '0' then -- juste avant la monte de clk25Resync
      if ltRise = '0' then
        lt <= '0';
      else
        lt <= '1';          -- lt durera 40 ns
        ltRise <= '0';
      end if;
    end if;
  end if;
end process;

alignOut  <= alignOutLocal;
--resetOred  <= resetIn or ioFpga_10;

-------------------------------------------------------------------------------------------------
-- Gestion/gnration du signal de reset
-- prescaler: 40 ns * 25000 = 1 ms
-- Le process surveille  la fois resetIn et lock detect. reset est maintenu actif tant que
-- l'un des deux signaux l'est (resetIn = 1 OU lockDetected = 0) et pendant 200 ms aprs la
-- dernire retombe de ce 'OU'.

makeReset: process (resetIn, clk25MHz)
--makeReset: process (resetOred, clk25MHz)
begin
  if rising_edge(clk25MHz) then
    if resetIn = '1' or lockDetected = '0' or resetSoft = '1' then
--    if resetOred = '1' or lockDetected = '0' then
      prescaler   <= (others => '0');
      slowClocker <= (others => '0');
      reset <= '1';
    end if;
    
    if prescaler = conv_std_logic_vector(24999, 15) then -- modulo 1 ms
      prescaler   <= (others => '0');
      slowClocker <= slowClocker + 1;
    else
      prescaler <= prescaler + 1;
    end if;
    
    if slowClocker = 200 then -- 200 msec
      reset <= '0';
    end if;
  end if;
end process;

-------------------------------------------------------------------------------------------------
--  clkBack  <= clk;
  slowCtBusRd <=
    slowCtRd(ADC_QH1) or
    slowCtRd(ADC_I1)  or
    slowCtRd(ADC_QL1) or
    slowCtRd(ADC_Q2)  or
    slowCtRd(ADC_I2)  or
    slowCtRd(ADC_Q3)  or
    slowCtBusRdAdc    or
    slowCtBusRdTrig   or
    slowctBusRdGal    or
    slowctBusRdEng    or
    slowCtBusRdSysMon or
    slowCtBusRdVirtu  or
    slowCtBusRdZone   or
    slowCtBusRdPs     or
	 slowCtBusRdGene   or
	 slowCtBusRdId     or
	 slowCtBusRdOffset;
                 
  fastDac <=
    fastDacVector(ADC_QH1) or
    fastDacVector(ADC_Q2)  or
    fastDacVector(ADC_Q3)  or
    fastDacVector(ADC_QL1) or
    fastDacVector(ADC_I1)  or
    fastDacVector(ADC_I2)  or
    fastDacVector(RAMP); -- gnrateur isocle issu de general_io
    
  -- affectation de la sortie physique
  -- transformation cm2 --> offset binary (on passe de n <-8192 .. +8191> = n+8192 <0 .. 16384>
  galIO(ADC_TOP-1 downto 0) <=     fastDac(ADC_TOP-1 downto 0);
  galIO(ADC_TOP)            <= not fastDac(ADC_TOP);
  galClk <= clk;
  
--  adcI1Rst_n  <= '1';
--  adcQL1Rst_n <= '1';
--  adcI2Rst_n  <= '1';
  
  aux_0 <= or_reduce(inspectBits);
  aux_1 <= ltLocal;
  aux_2 <= val;
  
--  aux_0 <= clk25Resync;
--  aux_1 <= clk25Falling;
--  aux_2 <= sync;
  
-------------------------------------------------------------------------------------------------
-- la DCM pour les dlais
delDcm: dcm_200
  port map (
    CLKIN_IN        => clk,
    RST_IN          => reset,
    ----CLKIN_IBUFG_OUT => open,
    CLK0_OUT        => open,
    CLK2X_OUT       => refClk,
    LOCKED_OUT      => lock200MHz
  );
-------------------------------------------------------------------------------------------------
-- le buffer de l'horloge systme
  clk_buf: IBUFGDS                                                                
    port map (I => sysClk_p, IB => sysClk_n, O => clk);
    
-------------------------------------------------------------------------------------------------
-- le buffer de l'horloge  25 MHz
  clk_25_buf: IBUFGDS                                                                
    port map (I => clk25MHz_p, IB => clk25MHz_n, O => clk25MHz);
    
-------------------------------------------------------------------------------------------------
-- supprim au profit de celui instanci dans le fastLink
-- le module de contrle pour les dlais
--  idel_ctrl: idelayCtrl
--    port map (refClk => refClk, rst => '0', rdy => open);

-------------------------------------------------------------------------------------------------
inspectBits(6) <= '0';

adc_monitor: entity work.AdcMon
  port map (
    clk          => clk,
    reset        => reset,
    lock200MHz   => lock200MHz,
    ---
    sClkPort(ADC_QH1) => AdcQH1Sclk,
    sClkPort(ADC_I1)  => AdcI1Sclk,
    sClkPort(ADC_QL1) => AdcQL1Sclk,
    sClkPort(ADC_Q2)  => AdcQ2Sclk,
    sClkPort(ADC_I2)  => AdcI2Sclk,
    sClkPort(ADC_Q3)  => AdcQ3Sclk,
    ---
    csPort(ADC_QH1)   => AdcQH1Cs_n,
    csPort(ADC_I1)    => AdcI1Cs_n,
    csPort(ADC_QL1)   => AdcQL1Cs_n,
    csPort(ADC_Q2)    => AdcQ2Cs_n,
    csPort(ADC_I2)    => AdcI2Cs_n,
    csPort(ADC_Q3)    => AdcQ3Cs_n,
    ---
    sdoPort(ADC_QH1)  => AdcQH1Sdo,
    sdoPort(ADC_I1)   => AdcI1Sdo,
    sdoPort(ADC_QL1)  => AdcQL1Sdo,
    sdoPort(ADC_Q2)   => AdcQ2Sdo,
    sdoPort(ADC_I2)   => AdcI2Sdo,
    sdoPort(ADC_Q3)   => AdcQ3Sdo,
    ---
    sdioPort(ADC_QH1) => AdcQH1Sdio,
    sdioPort(ADC_I1)  => AdcI1Sdio,
    sdioPort(ADC_QL1) => AdcQL1Sdio,
    sdioPort(ADC_Q2)  => AdcQ2Sdio,
    sdioPort(ADC_I2)  => AdcI2Sdio,
    sdioPort(ADC_Q3)  => AdcQ3Sdio,
    ---
    rstPort_n(ADC_QH1) => open,
    rstPort_n(ADC_I1)  => adcI1Rst_n,
    rstPort_n(ADC_QL1) => adcQL1Rst_n,
    rstPort_n(ADC_Q2)  => open,
    rstPort_n(ADC_I2)  => adcI2Rst_n,
    rstPort_n(ADC_Q3)  => open,
    ---
    alignBus     => alignBus,
    alignDataBit => alignDataBit,
    --inspect      => inspectBits(6),
    inspect      => open,
    ---
    slowCtBus    => slowCtBus,
    slowCtBusRd  => slowCtBusRdAdc
  );
-------------------------------------------------------------------------------------------------
picoBlock: entity work.comZone
port map (
  clk         => clk,
  reset       => reset,
  letterBox   => lBox,
  slowCtBus   => slowCtBus,
  slowCtBusRd => slowCtBusRdZone);

-------------------------------------------------------------------------------------------------
genIoBloc: entity work.GeneralIo
  generic map (regAd => GENERAL_IO)
  port map (
    clk         => clk,
    reset       => reset,
    clear       => clear, -- reset soft, provient de GeneralIo
    resetSoft   => resetSoft,
    alignFromSc => alignFromSc,
    blkBusyFromSc => blkBusyFromSc,
    ---
    idFpga      => idFpga,
    ---
    rougeIn     => valLed,
    verteIn     => ltLed,
    jauneIn     => '0',
    bleueIn     => '0',
    ---
    telIdPort  => telId,
    valExt      => valExt,
    ---
    ledRouge    => ledRouge,
    ledVerte    => ledVerte,
    ledJaune    => ledJaune,
    ledBleue    => ledBleue,
    ---
    microsec    => microsec,
    millisec    => millisec,
    ---
    fastDacOut  => fastDacVector(RAMP),
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdGal);

-------------------------------------------------------------------------------------------------
sysMonBlock: entity work.SysMonitor
  generic map (regAd => SYS_MON)
  port map (
    clk         => clk,
    reset       => reset,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdSysMon
);

--------------------------------------------------------
idModule: entity work.identity
  generic map (regAd => REG_ID)
  port map(
    clk     => clk,
	 reset   => reset,
	 --------
	 slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdId
);
-------------------------------------------------------------------------------------------------
 qh1: entity work.SlowChannel
   generic map (
     AdcNr    => ADC_QH1,      -- (0)
     reverse  => true,      -- inversion des bits de donne d'ADC
     --reverse  => false,   -- inversion des bits de donne d'ADC
     detId   => SI_1,      -- numro de dtecteur (0 à 2)
     WaveId   => WAVE_QH1,  -- numro de signal dans le telescope (1  3)
     ---
     RegAd    => QH1_SC,
     CircAd   => CIR_BUF_QH1, 
     MebAd    => MEB_QH1,
     SegAd    => SEG_QH1,
     HistoAd  => HISTO_QH1,
     ---
     CirSize  => CIR_Q_SIZE,    -- 1024
     MebSize  => MEB_Q_SIZE,
     SegSize  => NB_SEG         -- 16
   )
   port map (
     clk          => clk,
     sync         => sync,
     reset        => reset,
     clear        => clear,
     telId       => telId,
     ---
     adcIn_n      => adcQH1_n,
     adcIn_p      => adcQH1_p,
     ckAdc_n      => ckAdcQH1_n,
     ckAdc_p      => ckAdcQH1_p,
     ---
     segNrRd      => segNrRd,
     segNrWr      => segNrWr,
     acqBusyIn    => acqBusy(1),
     acqBusyOut   => acqBusy(0),
     ---
     dataIn       => data(1),
     dataOut      => data(0),
     ---
	  saveWave     => saveWaveFlag,
     throttle     => throttle,
     readIn       => readInOut(0),
     readOut      => readInOut(1),
     doneIn       => done(1),
     doneOut      => done(0),
     ---
     readerStateMach => readerStateMach_Qh1,
     readerErrBit    => readerErrBit(0),
     --abort        => '0',
     val          => val,
     ---
     streamOut    => fastDacVector(ADC_QH1),
     ---
     alignBus     => alignBus,
     alignDataBit => alignDataBit(ADC_QH1),
     inspect      => inspectBits(ADC_QH1),
     ---
     slowCtBus    => slowCtBus,
     slowCtBusRd  => slowCtRd(ADC_QH1),
     ---
     timer        => microsec,
     --timer        => millisec,
     ---
     trigFastH    => trigFastH(0),
     trigFastL    => trigFastL(0),
     trigSlow     => trigSlow(0)
  );
-------------------------------------------------------------------------------------------------
 i1: entity work.FastChannel
   generic map (
     AdcNr    => ADC_I1,       -- (0)
     reverse  => false,
     detId   => SI_1,
     WaveId   => WAVE_I1,
     ---
     RegAd    => I1_SC,
     MebAd    => MEB_I1,
     SegAd    => SEG_I1,
     ---
     CirSize  => CIR_I_SIZE,   -- 1024
     MebSize  => MEB_I_SIZE,
     SegSize  => NB_SEG        -- 16
   )
   port map (
     clk          => clk,
     clk25MHz     => clk25MHz,
     sync         => sync,
     reset        => reset,
     clear        => clear,
     telId        => telId,
     ---
     adcIn_n      => adcI1_n,
     adcIn_p      => adcI1_p,
     ckAdc_n      => ckAdcI1_n,
     ckAdc_p      => ckAdcI1_p,
     ---
     segNrRd      => segNrRd,
     segNrWr      => segNrWr,
     acqBusyIn    => acqBusy(2),
     acqBusyOut   => acqBusy(1),
     ---
     dataIn       => data(2),
     dataOut      => data(1),
     ---
	  saveWave     => saveWaveFlag,
--	  saveWave     => true,
     throttle     => throttle,
     readIn       => readInOut(1),
     readOut      => readInOut(2),
     doneIn       => done(2),
     doneOut      => done(1),
     ---
     readerStateMach => readerStateMach_I1,
     readerErrBit    => readerErrBit(1),
     --abort        => '0',
     val          => val,
     ---
     streamOut    => fastDacVector(ADC_I1),
     ---
     alignBus     => alignBus,
     alignDataBit => alignDataBit(ADC_I1),
     inspect      => inspectBits(ADC_I1),
     ---
     slowCtBus    => slowCtBus,
     slowCtBusRd  => slowCtRd(ADC_I1)
  );
-------------------------------------------------------------------------------------------------
 ql1: entity work.FastChannel
   generic map (
     AdcNr    => ADC_QL1,       -- (0)
     reverse  => true,
     detId   => SI_1,
     WaveId   => WAVE_QL1,
     ---
     RegAd    => QL1_SC,
     MebAd    => MEB_QL1,
     SegAd    => SEG_QL1,
     ---
     CirSize  => CIR_I_SIZE,   -- 1024
     MebSize  => MEB_I_SIZE,
     SegSize  => NB_SEG        -- 16
   )
   port map (
     clk          => clk,
     clk25MHz     => clk25MHz,
     sync         => sync,
     reset        => reset,
     clear        => clear,
     telId       => telId,
     ---
     adcIn_n      => adcQL1_n,
     adcIn_p      => adcQL1_p,
     ckAdc_n      => ckAdcQL1_n,
     ckAdc_p      => ckAdcQL1_p,
     ---
     segNrRd      => segNrRd,
     segNrWr      => segNrWr,
     acqBusyIn    => acqBusy(3),
     acqBusyOut   => acqBusy(2),
     ---
     dataIn       => data(3),
     dataOut      => data(2),
     ---
	  saveWave     => saveWaveFlag,
--	  saveWave     => true,  
     throttle     => throttle,
     readIn       => readInOut(2),
     readOut      => readInOut(3),
     doneIn       => done(3),
     doneOut      => done(2),
     ---
     readerStateMach => readerStateMach_Ql1,
     readerErrBit    => readerErrBit(2),
     --abort        => '0',
     val          => val,
     ---
     streamOut    => fastDacVector(ADC_QL1),
     ---
     alignBus     => alignBus,
     alignDataBit => alignDataBit(ADC_QL1),
     inspect      => inspectBits(ADC_QL1),
     ---
     slowCtBus    => slowCtBus,
     slowCtBusRd  => slowCtRd(ADC_QL1)
  );
-------------------------------------------------------------------------------------------------
 q2: entity work.SlowChannel
   generic map (
     AdcNr    => ADC_Q2,
     reverse  => false,
     detId   => SI_2,
     WaveId   => WAVE_Q2,
     ---
     RegAd    => Q2_SC,
     CircAd   => CIR_BUF_Q2, 
     MebAd    => MEB_Q2,
     SegAd    => SEG_Q2,
     HistoAd  => HISTO_Q2,
     ---
     CirSize  => CIR_Q_SIZE,    -- 1024
     MebSize  => MEB_Q_SIZE,
     SegSize  => NB_SEG         -- 16
   )
   port map (
     clk          => clk,
     sync         => sync,
     reset        => reset,
     clear        => clear,
     telId       => telId,
     ---
     adcIn_n      => adcQ2_n,
     adcIn_p      => adcQ2_p,
     ckAdc_n      => ckAdcQ2_n,
     ckAdc_p      => ckAdcQ2_p,
     ---
     segNrRd      => segNrRd,
     segNrWr      => segNrWr,
     acqBusyIn    => acqBusy(4),
     acqBusyOut   => acqBusy(3),
     ---
     dataIn       => data(4),
     dataOut      => data(3),
     ---
	  saveWave     => saveWaveFlag,	  
     throttle     => throttle,
     readIn       => readInOut(3),
     readOut      => readInOut(4),
     doneIn       => done(4),
     doneOut      => done(3),
     ---
     readerStateMach => readerStateMach_Q2,
     readerErrBit    => readerErrBit(3),
     --abort        => '0',
     val          => val,
     ---
     streamOut    => fastDacVector(ADC_Q2),
     ---
     alignBus     => alignBus,
     alignDataBit => alignDataBit(ADC_Q2),
     inspect      => inspectBits(ADC_Q2),
     ---
     slowCtBus    => slowCtBus,
     slowCtBusRd  => slowCtRd(ADC_Q2),
     ---
     timer        => microsec,
     --timer        => millisec,
     ---
     trigFastH    => trigFastH(1),
     trigFastL    => trigFastL(1),
     trigSlow     => trigSlow(1)
  );
-------------------------------------------------------------------------------------------------
 i2: entity work.FastChannel
   generic map (
     AdcNr    => ADC_I2,       -- (0)
     reverse  => false,
     detId   => SI_2,
     WaveId   => WAVE_I2,
     ---
     RegAd    => I2_SC,
     MebAd    => MEB_I2,
     SegAd    => SEG_I2,
     ---
     CirSize  => CIR_I_SIZE,   -- 1024
     MebSize  => MEB_I_SIZE,
     SegSize  => NB_SEG        -- 16
   )
   port map (
     clk          => clk,
     clk25MHz     => clk25MHz,
     sync         => sync,
     reset        => reset,
     clear        => clear,
     telId       => telId,
     ---
     adcIn_n      => adcI2_n,
     adcIn_p      => adcI2_p,
     ckAdc_n      => ckAdcI2_n,
     ckAdc_p      => ckAdcI2_p,
     ---
     segNrRd      => segNrRd,
     segNrWr      => segNrWr,
     acqBusyIn    => acqBusy(5),
     acqBusyOut   => acqBusy(4),
     ---
     dataIn       => data(5),
     dataOut      => data(4),
     ---
	  saveWave     => saveWaveFlag,
--	  saveWave     => true,  
     throttle     => throttle,
     readIn       => readInOut(4),
     readOut      => readInOut(5),
     doneIn       => done(5),
     doneOut      => done(4),
     ---
     readerStateMach => readerStateMach_I2,
     readerErrBit    => readerErrBit(4),
     --abort        => '0',
     val          => val,
     ---
     streamOut    => fastDacVector(ADC_I2),
     ---
     alignBus     => alignBus,
     alignDataBit => alignDataBit(ADC_I2),
     inspect      => inspectBits(ADC_I2),
     ---
     slowCtBus    => slowCtBus,
     slowCtBusRd  => slowCtRd(ADC_I2)
  );
-------------------------------------------------------------------------------------------------
 q3: entity work.CsiChannel
   generic map (
     AdcNr    => ADC_Q3,
     reverse  => true,
     detId   => CS_I,
     WaveId   => WAVE_Q3,
     ---
     RegAd    => Q3_SC,
     CircAd   => CIR_BUF_Q3, 
     MebAd    => MEB_Q3,
     SegAd    => SEG_Q3,
     Histo1   => HISTO_TOT,
     Histo2   => HISTO_FAST,
     ---
     CirSize  => CIR_Q_SIZE,    -- 1024
     MebSize  => MEB_Q_SIZE,
     SegSize  => NB_SEG         -- 16
   )
   port map (
     clk          => clk,
     sync         => sync,
     reset        => reset,
     clear        => clear,
     telId       => telId,
     ---
     adcIn_n      => adcQ3_n,
     adcIn_p      => adcQ3_p,
     ckAdc_n      => ckAdcQ3_n,
     ckAdc_p      => ckAdcQ3_p,
     ---
     segNrRd      => segNrRd,
     segNrWr      => segNrWr,
     acqBusyIn    => acqBusy(6),
     acqBusyOut   => acqBusy(5),
     ---
     dataIn       => data(6),
     dataOut      => data(5),
     ---
	  saveWave     => saveWaveFlag,	  
     throttle     => throttle,
     readIn       => readInOut(5),
     readOut      => readInOut(6),
     doneIn       => done(6),
     doneOut      => done(5),
     ---
     readerStateMach => readerStateMach_Q3,
     readerErrBit    => readerErrBit(5),
     --abort        => '0',
     val          => val,
     ---
     streamOut    => fastDacVector(ADC_Q3),
     ---
     alignBus     => alignBus,
     alignDataBit => alignDataBit(ADC_Q3),
     inspect      => inspectBits(ADC_Q3),
     ---
     slowCtBus    => slowCtBus,
     slowCtBusRd  => slowCtRd(ADC_Q3),
     ---
     timer        => microsec,
     --timer        => millisec,
     ---
     trigFastH    => trigFastH(2),
     trigFastL    => trigFastL(2),
     trigSlow     => trigSlow(2)
  );
-------------------------------------------------------------------------------------------------
finisseur: entity work.Terminator
	port map (
		clk        => clk,
		reset      => reset,
    clear      => clear,
		---
		dataOut    => data(NB_CHAN),
    acqBusyOut => acqBusy(NB_CHAN),
		throttle   => throttle,
		readIn     => readInOut(NB_CHAN),
		doneOut    => done(NB_CHAN)
	);
	
-------------------------------------------------------------------------------------------------
rEngine: entity work.readEngine
  generic map (
    withChipScope => chip_read_engine,
    build_a       => build_a
  )
  port map (
    clk       => clk,
    reset     => reset,
    clear     => clear,
    syncZer   => syncZer,
    --sync      => sync,
    ---
    alignIn   => alignInLocal, -- pour le test
    alignOut  => alignOutLocal,
    ---
    throttle  => throttle, -- sortie vers toutes les voies
    done      => done(0),
    readOut   => readInOut(0),
    dataIn    => data(0),
    ---
    hostIn    => fastToRd,
    hostOutPort => rdToFast,
    spyBus    => spyBus,
    voieInt   => voieInt,
    ---
    lWait      => lWait,
    blkBusyPort=> blkBusy,
    --tokenReq   => tokenRequestLocal,
    --tokenGrant => tokenGrantLocal,
    --
    telId     => telId,
    ---
    lt        => ltLocal,
    val       => val,
    --glt       => gltLocal,
    vetoIn    => veto,
    segNrWr   => segNrWr,
    segNrRd   => segNrRd,
    ---
	 trigBitmask => trigBitmask,
    saveWaveFlag => saveWaveFlag,	 
	 ---
    syncWr    => syncWr,
    syncRd    => syncRd,
    bDone      => bDone,
    readB     => readB,
    ---
    slowCtBus    => slowCtBus,
    slowCtBusRd  => slowCtBusRdEng
  );
	
-------------------------------------------------------------------------------------------------
fLink: entity work.FASTLINK
generic map (
  last          => not build_a,
  withChipScope => chip_flink
)

port map (
  clk100MHz_sys  => clk,
  clk25MHz_sys   => clk25MHz,
  reset      => reset,
  ---
  sdi_p      => sdi_p,   -- voie montante
  sdi_n      => sdi_n,
  sdi_H_p    => sdi_H_p, -- voie descendante (2 lanes)
  sdi_H_n    => sdi_H_n,
  sdi_L_p    => sdi_L_p,
  sdi_L_n    => sdi_L_n,
  ---
  alignIn    => alignInLocal,
  voieInt    => voieInt,  -- aiguilleur interne ou externe
  --voieInt_VM  => '0',
  hostIn     => rdToFast, -- bus de données local
  --hostInVM   => x"0000",
  hostOut    => fastToRd, -- bus de sortie de la voie montante
  spyvd16bus => spyBus,   -- bus de sortie de fastlink, pour debug seulement
  alignOut   => alignOutLocal, -- indicateur d'alignement
  ---
  sdo_p      => sdo_p,
  sdo_n      => sdo_n,
  sdo_H_p    => sdo_H_p,
  sdo_H_n    => sdo_H_n,
  sdo_L_p    => sdo_L_p,
  sdo_L_n    => sdo_L_n
);

-------------------------------------------------------------------------------------------------
trigger: entity work.trigger
  generic map (RegAd => REG_TRIG)
  port map (
    clk         => clk,
    reset       => reset,
    clear       => clear,
    microsec    => microsec,
    millisec    => millisec,
    ---
    trigSlow    => trigSlow,
    trigFastH   => trigFastH,
    trigFastL   => trigFastL,
    trigExt     => '0',
	 pulserOn    => pulserOn,
	 trigBitmask => trigBitmask,
    ---
    lt          => ltLocal,
    ltLed       => ltLed,
    glt         => gltLocal,
    val         => val,
    veto        => veto,
    valLed      => valLed,
    ---
--    acqBusy     => acqBusy(0),
    acqBusy     => acqBusyAll,
    segNrWr     => segNrWr,
    ---
    etatTrigger => etatTrigger,
    sourceBrute => sourceBrute,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdTrig
  );

--------------------------------------------------------------------------------------------------
offsetAnalog: entity work.OffsetCtrl
  generic map (
    RegAd   => OFFSET
  )
  port map ( 
    clk      => clk,
    reset    => reset,
    ---
    adjust_n(0) => adjust1,
    adjust_n(1) => adjust2,
    adjust_n(2) => adjust3,
    ---
    scl      => dacScl,
    sda      => dacSda,
    ---
    slowCtBus => slowCtBus,
	 slowCtBusRd => slowCtBusRdOffset
   );

-------------------------------------------------------------------------------------------------
-- gnration des signaux de synchro
gene_25_f: process (clk)
begin
  if falling_edge(clk) then
    clk25Falling <= clk25MHz;
  end if;
end process;
------------------------------------
gene_25: process (clk)
begin
  if rising_edge(clk) then
    clk25Resync <= clk25Falling;
    clk25Old    <= clk25Resync;
  end if;
end process;
------------------------------------
-- signal  25 MHz de dure 10 ns
gegne_sync: process (reset, clk)
begin
  if reset = '1' then
    sync <= '0';
  elsif rising_edge(clk) then
    if clk25Falling = '0' and clk25Resync = '1' then
      sync <= '1';
    else
      sync <= '0';
    end if;
  end if;
end process;

aVersB_3 <= '0';

--===============================================================================================
---- les i/o diffrentielles non utilises (qui doivent tre connectes)
--dummy_buf: for i in 7 to 7 generate -- <0> porte ltB
--  ltb_buf : IBUFDS
--    port map (
--      I  => riserv_p(i),
--      IB => riserv_n(i),
--      O  => riserv(i)
--    );
--end generate;

-- la gnration synchronise des signaux d'occupation des acquisitions
-- acqBusyOtherRaw provient de l'autre tlescope et n'est pas synchrone

syncBsyProc: process (clk)
begin
  if rising_edge(clk) then
    acqBusyAll <= acqBusyOtherRaw or acqBusy(0);
  end if;
end process;

lWaitOut <= localWaitOutLocal;

--===============================================================================================
-- Section spcifique au telescope A                                                  ==== A ====
--===============================================================================================
make_tel_a: if build_a generate

-- gnration d'un signal d'alignement fastlink, seulement pour le debug
-- ultrieurement, ce signal proviendra du fond de panier

--make_align: process (reset, clk)
--begin
--  if reset = '1' then
--    alignInLocal <= '0';
--    timer_250ms <= (others => '0');
--  elsif rising_edge(clk) then
--    oldMillisec <= millisec;
--    if  millisec = '1' and oldMillisec = '0' then                                  -- ==== A ====
--      if timer_250ms < 250 then
--        alignInLocal <= '1';
--        timer_250ms <= timer_250ms + 1;
--      else
--        alignInLocal <= '0';
--      end if;
--    end if;
--  end if;
--end process;

----------------------------------------                                              ==== A ====
aVersB_0     <= ld1;
lockDetected <= ld1;

aVersB_1 <= '0';
aVersB_2 <= '0';
--aVersB_3 <= '0';

alignInLocal <= alignIn or alignFromSC;

free_p    <= '0';
free_n    <= '1';

--ioFpga_11 <= '0';
--ioFpga_12 <= '0';
--ioFpga_13 <= '0';
--ioFpga_14 <= '0';
--ioFpga_15 <= '0';
a_vers_b_4 <= '0';
a_vers_b_5 <= '0';
a_vers_b_6 <= '0';
--a_vers_b_7 <= '0';
a_vers_pic <= lBox;

-------------------------------------------------------------------------------------------------
--r_lmk: entity work.TalkToLmk  
r_lmk: TalkToLmk
  generic map (
    RegAd => AD_LMK)
  port map (
    clk       => clk25MHz,
    sysClk    => clk,
    resetIn   => resetIn, -- cas particulier: TalkToLmk utilise le reset hardware brut
    uWire1    => uWire1,  --    (qui ne tient pas compte des signaux lock detect)
    uWire2    => uWire2,
    ckUWire   => clkUWire,
    dataUWire => dataUWire,
    ---
    slowCtBus => slowCtBus
	);

------------------------------------------------------------                          ==== A ====
  scBloc_a: entity work.ScItf
    port map (
      clk         => clk,
      reset       => reset,
      -- spi to pic ---------------------------------------
      ucSpiSdi    => ucSpiSdi,
      ucSpiSdo    => ucSpiSdo,
      ucSpiSck    => ucSpiSck,
      ucSpiSs_n   => ucSpiSs_n,
      -- Interface to USB ---------------------------------
      addrUsb     => "00",      -- tel_a est master
      dataUsb     => dataUsb,
      rdUsb_n     => rdUsb_n,
      wrUsb       => wrUsb,
      rxf_n       => rxf_n,
      txe_n       => txe_n,
      -- bus ----------------------------------------------
      slowCtBus   => slowCtBus,
      slowCtBusRd => slowCtBusRd
    );
------------------------------------------------------------                          ==== A ====

-- handshake entre blockCard et readEngine(s)
-- blkBusy    <= blkBusyIn or blkBusyFromSc; -- du connecteur (blockCard) vers readEngine
-- blkBusyOut <= blkBusy;   -- vers telescope B
-- J'ai synchronis BlkBusy pour viter des problmes de mtastabilits

syncBlkBusyProcA : process (clk)
begin
  if rising_edge(clk) then
    blkBusy    <= blkBusyIn or blkBusyFromSc; -- du connecteur (blockCard) vers readEngine
	 blkBusyOut <= blkBusy;   -- vers telescope B
  end if;
end process;


localWaitOutLocal <= '0' when lWait = '1' or lWaitIn = '1' --                                  ==== A ====
                else 'Z'; --'Z'

-- la machine temporaire de global trigger
-- valExt permet de choisir si le global trigger arrive -0- par le connecteur (glt)
-- ou s'il est gnr par la machine locale -1- (configuration de test stand_alone)

--makeGlt: process (clk) -- resynchro de glt
--begin
--  if rising_edge (clk) then
--    if valExt = '1' then
--      gltLocal <= glt;
--    else
--      gltLocal <= 'Z'; -- faux !
--    end if;
--  end if;
--end process;

--gltLocal <= glt when valExt = '1' else gltA;
--glt <= 'Z' when valExt = '1' else gltA; --modification faite par Franck le 21 octobre 2013
glt <= 'Z';

-- resynchro de glt -------------------                                               ==== A ====
syncGltProcA: process (clk)
begin
  if rising_edge(clk) then
    if valExt = '1' then
      gltLocal <= glt;
    else
      gltLocal <= gltA;
    end if;
  end if;
end process;
----------------------------------------

-- rception du lt de B
ltb_buf : IBUFDS
  port map (
    I  => riserv_p(0),
    IB => riserv_n(0),
    O  => ltB
  );

globalTrig: GlobalTrigger
  port map (
    clk          => clk,
    reset        => reset,
    ---
    ltA          => ltLocal,
    ltB          => ltB,
    localWaitOut => localWaitOutLocal,
    glt          => gltA
  );
  
  a_vers_b_7 <= gltA;
  
-----------------------------------------------------------------------------         ==== A ====
-- la blockCard virtuelle
virtu: entity work.Virblock
  port map (
    clk       => clk,
    reset     => reset,
    clk25MHz  => clk25MHz,
    ---
    ioFpga_4  => ioFpga_4,
    ioFpga_5  => ioFpga_5,
    ioFpga_6  => ioFpga_6,
    ioFpga_7  => ioFpga_7,
    ioFpga_8  => ioFpga_8,
    ioFpga_9  => ioFpga_9,
--    ioFpga_10 => ioFpga_10, -- maintenant mobilis pour le reset de secours
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdVirtu
  );
  
-----------------------------------------------------------------------------         ==== A ====
-- interfaage des signaux de readout entre A et B
syncW_buf : OBUFDS
  port map (
    I  => syncWr,
    O  => riserv_p(1),
    OB => riserv_n(1)
  );
  
syncR_buf : OBUFDS
  port map (
    I  => syncRd,
    O  => riserv_p(2),
    OB => riserv_n(2)
  );
  
readB_buf : OBUFDS
  port map (
    I  => readB,
    O  => riserv_p(3),
    OB => riserv_n(3)
  );

bDone_buf : IBUFDS
  port map (
    I  => riserv_p(4),
    IB => riserv_n(4),
    O  => bDone
  );

absyA_buf : OBUFDS
  port map (
    I  => acqBusy(0),  -- le dernier de la chane
    O  => riserv_p(5),
    OB => riserv_n(5)
  );

absyB_buf : IBUFDS
  port map (
    I  => riserv_p(6),
    IB => riserv_n(6),
    O  => acqBusyOtherRaw
  );
 
pulserOn_buf : IOBUF
  port map (
     O  => pulserOn,
     IO => riserv_p(7),
     I  => '0',
     T  => '1'
  );
 
end generate;
  
--=============================================================================================
-- Section spcifique au telescope B                                                ==== B ====
--=============================================================================================

make_tel_b: if not build_a generate

alignInLocal <= alignIn;
pulserGlob   <= 'Z';

generateur: entity work.Gene
  port map (
    clk       => clk,
    reset     => reset,
    ---
    --millisec  => millisec, -- entre 1 kHz - 50 %
    trigExt   => pulserGlob,
    microsec  => microsec, -- entre 1 MHz - 50 %
    clkGene   => clkGene_int,  -- sortie programme
    ---
    slowCtBus => slowCtBus,
	 slowCtBusRd => slowCtBusRdGene
	);

aVersB_0    <= 'Z';
lockDetected <= aVersB_0;

--ioFpga_4  <= '0';
--ioFpga_5  <= '0';
--ioFpga_6  <= '0';
--ioFpga_7  <= '0';
--ioFpga_8  <= '0';
--ioFpga_9  <= '0';
--ioFpga_10 <= '0';

b_vers_pic_1 <= lBox;
b_vers_pic_2 <= '0';

--ioFpga_19   <= '0';
--ioFpga_20   <= '0';

--dummy <= ioFpga_21 or ioFpga_22;

------------------------------------------------------------                        ==== B ====
  scBloc_b: entity work.ScItf
    port map (
      clk         => clk,
      reset       => reset,
      -- spi to pic ---------------------------------------
      ucSpiSdi    => ucSpiSdi,
      ucSpiSdo    => ucSpiSdo,
      ucSpiSck    => ucSpiSck,
      ucSpiSs_n   => ucSpiSs_n,
      -- Interface to USB ---------------------------------
      addrUsb     => "01",      -- tel_b est slave
      dataUsb     => dataUsb,
      rdUsb_n     => rdUsb_n,
      wrUsb       => wrUsb,
      rxf_n       => rxf_n,
      txe_n       => txe_n,
      -- bus ----------------------------------------------
      slowCtBus   => slowCtBus,
      slowCtBusRd => slowCtBusRd
    );
------------------------------------------------------------
--gltLocal <= glt;

-- resynchro de glt -------------------                                             ==== B ====
syncGltProcB: process (clk)
begin
  if rising_edge(clk) then
    if valExt = '1' then
      gltLocal <= glt;
	 else
	   gltLocal <= b_vers_a_7;
	 end if;
  end if;
end process;

--------------------------------------------------------------                      ==== B ====
-- la machine temporaire de global trigger
-- sortir le signal lt sur une ligne auxiliaire

lt_buf : OBUFDS
  port map (
    I  => ltLocal,
    O  => riserv_p(0),
    OB => riserv_n(0)
  );

-- handshake entre blockCard et readEngine(s)
localWaitOutLocal   <= lWait; -- depuis readEngine
--blkBusy    <= blkBusyIn;
--blkBusyOut <= '0';

syncBlkBusyProcB : process(clk)
begin
  blkBusy    <= blkBusyIn;
  blkBusyOut <= '0';
end process;

iofpga_5    <= '0';
iofpga_6    <= '0';
iofpga_7    <= '0';
iofpga_8    <= '0';
iofpga_9    <= '0';

--------------------------------------
alims: entity work.psSyncGen
  generic map (
    RegAd => PS_GEN
  )
  port map (
    clk       => clk,
    reset     => reset,
    ---
--                                                                                   ==== B ====
    sync_vp2_5  => sync_vp2_5,
    sync_vp3_7  => sync_vp3_7,
    sync_vm2_7  => sync_vm2_7,
    sync_hv     => sync_hv,
    ---
    slowCtBus   => slowCtBus,
    slowCtBusRd => slowCtBusRdPs
   );
	
-----------------------------------------------------------------------------         ==== B ====
-- interfaage des signaux de readout entre A et B
syncW_buf : IBUFDS
  port map (
    I  => riserv_p(1),
    IB => riserv_n(1),
    O  => syncWr
  );

syncR_buf : IBUFDS
  port map (
    I  => riserv_p(2),
    IB => riserv_n(2),
    O  => syncRd
  );

readB_buf : IBUFDS
  port map (
    I  => riserv_p(3),
    IB => riserv_n(3),
    O  => readB
  );

bDone_buf : OBUFDS
  port map (
    I  => bDone,
    O  => riserv_p(4),
    OB => riserv_n(4)
  );
bbsyB_buf : OBUFDS
  port map (
    I  => acqBusy(0),  -- le dernier de la chane
    O  => riserv_p(6),
    OB => riserv_n(6)
  );

bbsyA_buf : IBUFDS
  port map (
    I  => riserv_p(5),
    IB => riserv_n(5),
    O  => acqBusyOtherRaw
  );

clkGene_buf : IOBUF
  port map (
     O  => pulserOn,
     IO => riserv_p(7),
     I  => clkGene_int,
     T  => '0'
  );
  
clkGene1_buf : IOBUF
  port map (
     O  => open,
     IO => ioFpga_18,
     I  => clkGene_int,
     T  => '0'
  );
end generate;

-----------------------------------------------------------------------------------------------

end telescope_arch;

