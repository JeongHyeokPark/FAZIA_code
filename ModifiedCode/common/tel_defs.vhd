--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions

-- printed: 22-12-2011


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use work.slow_ct_defs.all;

--===============================================================================================
package tel_defs is

function bits (taille : integer) return integer;
function or_reduce (A : std_logic_vector) return std_logic;

constant ALL_ZERO : std_logic_vector(15 downto 0) := x"0000";
constant ALL_ONE  : std_logic_vector(15 downto 0) := x"FFFF";

-- version number: 0xTMmv
--  T = telescope: 0 = A,  1 = B -- copie physique du fil id_FPGA dans le bit 12
--  M = majeur
--  m = mineur
--  v = variante (par exemple patch sur une carte donne)

-- nb. c'est la valeur, pas l'adresse ;)
--constant VERSION_VHDL : std_logic_vector (15 downto 0) := X"0200"; 
constant NB_SLOW : integer := 3;
constant NB_FAST : integer := 3;
constant NB_CHAN : integer := NB_SLOW + NB_FAST; -- pour les chainages
constant CHAN_TOP: integer := NB_CHAN-1;

--===== les registres de contrle d'offset des pramplis ========================================

constant OFFSET : std_logic_vector (SC_TOP downto 0) := X"0004"; -- 4, 5, 6
constant OFFSET_FIELD  :  integer := 2;
constant PERIOD_I2C :       integer := 252;  -- 252*10 ns = 2.52 s soit 397 kHz
constant DAC6571_SETTLING : integer := 2000; -- 2000*10 ns = 20 s
constant DS4305_STROBE :    integer := 15;   -- 150 ns

--===============================================================================================
-- Numros de bit de chaque voie pour les donnes vectorises (getData, dataOut etc.)

constant ADC_DUMMY: integer := 6;
constant GENE_ISOCELE : integer := 6;

-- pour l'usage de ces constantes, voir dans e_trigger.vhd, le bloc repr
    --<==================== prototype dcodeur ====================>

constant GENERAL_IO   : std_logic_vector (SC_TOP downto 0) := X"0000";
constant GIO_FIELD  : integer := 2;
constant AD_VERS    : std_logic_vector (GIO_FIELD-1 downto 0) := "00"; -- numro de version
constant AD_LED_MPX : std_logic_vector (GIO_FIELD-1 downto 0) := "01"; -- port de leds
-- numro de tlescope au sein du bloc (registre crit au reset par le pic) = geo & bit A|B
constant AD_DETGID  : std_logic_vector (GIO_FIELD-1 downto 0) := "10";
constant AD_CONFIG  : std_logic_vector (GIO_FIELD-1 downto 0) := "11"; -- divers bits de configuration
--    constant CONFIG_BITS : integer := 4; -- le registre de configuration a maintenant 16 bits
constant CLEAR_BIT      : integer := 0; -- reset 'soft'
constant RESET_FROM_PIC : integer := 2; -- provoque un reset gnral comme le bouton poussoir
constant ALIGNEMENT     : integer := 3; -- provoque un alignement forc
constant GLT_SEL        : integer := 4; -- slection global trigger externe (1) ou interne (0)
constant BLK_BUSY_FORCE : integer := 5;
constant BLUE_FLAG      : integer := 6;
constant YELLOW_FLAG    : integer := 7;
constant GREEN_FLAG     : integer := 8;
constant RED_FLAG       : integer := 9;

constant INSPECT_AD : std_logic_vector (SC_TOP downto 0) := X"0010";
constant INSPECT_FIELD : integer := 4; -- pour le N d'ADC dans INSPECT_AD
constant RT_STREAM_SCE_BITS : integer := 3;

-- pulser (telescope B) -------------------------------------------------------------------------
constant PULSER_PERIOD : std_logic_vector (SC_TOP downto 0) := X"0100"; -- dure en ms
constant PULSER_HIGH   : std_logic_vector (SC_TOP downto 0) := X"0101"; -- idem
constant DEFAULT_PERIOD: integer := 50000; -- 50 ms => 20 Hz
constant DEFAULT_HIGH  : integer := 25000; -- 25 ms

-- system monitor -------------------------------------------------------------------------------
constant SYS_MON : std_logic_vector (SC_TOP downto 0) := X"0200";
constant SYS_MON_FIELD : integer := 2; -- la largeur du champ SYS_MON (assez pour 4 registres)
constant CORE_TEMP : std_logic_vector(SYS_MON_FIELD-1 downto 0) := "00";
constant VCC_INT   : std_logic_vector(SYS_MON_FIELD-1 downto 0) := "01";
constant VCC_AUX   : std_logic_vector(SYS_MON_FIELD-1 downto 0) := "10";
    
-- USB to PIC communication area ----------------------------------------------------------------
constant COM_ZONE      : std_logic_vector(SC_TOP downto 0) := X"0220";

----- registres spi des ADC (en criture) -------------------------------------------------------
type adr_adcs is array (0 to 5) of std_logic_vector (15 downto 0);
constant SPI_ADC_WR : adr_adcs := (x"0800", x"0900", x"0A00", x"0B00", x"0C00", x"0D00");

-- registre rsultat de lecture spi des ADC
constant SPI_READ      : std_logic_vector (SC_TOP downto 0) := x"0E00";
--constant DELAY_SET     : std_logic_vector (SC_TOP downto 0) := x"0E01";
--constant CALI_AUTO     : std_logic_vector (SC_TOP downto 0) := x"0E02";
constant DELAY_INSPECT : std_logic_vector (SC_TOP downto 0) := x"0E03";
constant ADC_CONTROL   : std_logic_vector (SC_TOP downto 0) := x"0F00"; -- utilis par adc_mon

constant SLOW_LOCAL     : std_logic_vector(SC_TOP downto 0) := x"0000";
constant LEV_SLOW_FLD : integer := 4; -- la largeur du champ SLOW_LOCAL
constant SLOW_STATUS  : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"0";
-- la sce  envoyer vers le MEB 00 = adc -- 01 = filtre trigger -- 10 = filtre nergie
constant FILTER_SCE     : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"1";
      
constant FAST_LOCAL      : std_logic_vector(SC_TOP downto 0) := x"0000";
constant FAST_FLD : integer := 4; -- la largeur du champ FAST_LOCAL
constant DECIMATOR_PHASE : std_logic_vector(FAST_FLD-1 downto 0) := x"0";
      
constant ENERGY_SC       : std_logic_vector(SC_TOP downto 0) := x"0010";
constant CSI_FAST        : std_logic_vector(SC_TOP downto 0) := x"0040"; -- cas particulier deuxime nergie du CsI
-- dans bloc nergie
constant LEV_EN_FLD    : integer := 4; -- la largeur du champ ENERGY
-- deux mots conscutifs (adresse paire !)
constant ENERGY_REG_H  : std_logic_vector(LEV_EN_FLD-1 downto 0) := x"0";
constant ENERGY_REG_L  : std_logic_vector(LEV_EN_FLD-1 downto 0) := x"1";
constant LEVEL_SLOW    : std_logic_vector(LEV_EN_FLD-1 downto 0) := x"2";
constant ENER_RISE_REG : std_logic_vector(LEV_EN_FLD-1 downto 0) := x"3"; -- dure d'intgration du shaper (en chantillons, 10-bit)
constant ENER_PLAT_REG : std_logic_vector(LEV_EN_FLD-1 downto 0) := x"4"; -- dure plat + intgration du shaper (en chantillons, 10-bit)
constant PEAKING_REG   : std_logic_vector(LEV_EN_FLD-1 downto 0) := x"5"; -- instant de peaking (en chantillons, 10-bit)
constant ENER_STATUS   : std_logic_vector(LEV_EN_FLD-1 downto 0) := x"6"; -- un peu de tout dans le bloc nergie
constant ENER_STATUS_BITS : integer := 1;
constant ENER_RDY    : integer := 0; -- indicateur nergie porte, raz par la lecture de ENERGY_REG_H
constant HISTO_CTRL     : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"7";
constant HISTO_BIN      : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"8";
constant HISTO_OFFSET_H : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"9";
constant HISTO_OFFSET_L : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"A";

constant E_TRIGGER_SC    : std_logic_vector(SC_TOP downto 0) := x"0020";
constant LEV_FAST_FLD  : integer := 4; -- la largeur du champ E_TRIGGER
constant LEVEL_L_FAST  : std_logic_vector(LEV_FAST_FLD-1 downto 0) := x"0";
constant LEVEL_H_FAST  : std_logic_vector(LEV_FAST_FLD-1 downto 0) := x"1";
constant TRIG_RISE_REG : std_logic_vector(LEV_FAST_FLD-1 downto 0) := x"2";
constant TRIG_PLAT_REG : std_logic_vector(LEV_FAST_FLD-1 downto 0) := x"3";
constant TRIG_CTRL_REG : std_logic_vector(LEV_FAST_FLD-1 downto 0) := x"4";
constant BL_PRETRIG_REG: std_logic_vector(LEV_FAST_FLD-1 downto 0) := x"5";
constant BL_MDEPTH_REG : std_logic_vector(LEV_FAST_FLD-1 downto 0) := x"6";
constant TRIG_CTRL_BITS : integer := 1; -- nbre de bits du mot de contrle
constant BIT_INV : integer := 0;        -- bit zro = commande de polarit
      
constant WAVER_SC      : std_logic_vector(SC_TOP downto 0) := x"0030";
constant WAVER_FIELD : integer := 4; -- la largeur du champ WAVER (assez pour 16 registres)
-- le registre de pretrig
constant WAVER_PRETRG  : std_logic_vector(WAVER_FIELD-1 downto 0) := x"0"; -- x"30"
-- le registre de longueur  transfrer entre circ et meb
constant WAVER_DEPTH   : std_logic_vector(WAVER_FIELD-1 downto 0) := x"1"; -- x"31"
-- le registre de contrle gnral
constant WAVER_CTRL    : std_logic_vector(WAVER_FIELD-1 downto 0) := x"2"; -- x"32"
-- l'adresse de dbut de signal dans le MEB
constant WAVER_CAPTURE : std_logic_vector(WAVER_FIELD-1 downto 0) := x"3"; -- x"33"
-- machine d'tat slow
constant WAVER_STAT_S  : std_logic_vector(WAVER_FIELD-1 downto 0) := x"4"; -- x"34"
-- machine d'tat fast
constant WAVER_STAT_F  : std_logic_vector(WAVER_FIELD-1 downto 0) := x"5"; -- x"35"
-- contenu ADC, chantillonn  50 MHz
constant ADC_SAMPLE    : std_logic_vector(WAVER_FIELD-1 downto 0) := x"6"; -- x"36"
-- periodical waveform memorization enable
constant WAVE_MEM_ENABLE: std_logic_vector(WAVER_FIELD-1 downto 0) := x"7"; -- x"37";

--=======registre servant  l'identification ========
constant REG_ID : std_logic_vector (SC_TOP downto 0) := x"0007";
      
--===== la Trigger-Box ==========================================================================

constant VAL_EXT : std_logic := '1'; -- la validation provient par dfaut du connecteur

constant REG_TRIG    : std_logic_vector (SC_TOP downto 0) := x"1600";
constant TRIG_FIELD  : integer := 4;
-- le registre de status
constant TRIG_CTRL   : std_logic_vector(TRIG_FIELD-1 downto 0) := x"0"; -- 0x1600
constant STATUS_BITS : integer := 2; -- nbre de bits du registre de status
constant FORCE_BIT : integer := 0;
constant ARM_BIT   : integer := 1;
-- le registre de source de trigger : 4 nibbles [ ext | CsI | Si2 | Si1 ]
-- 1 + 3x4 bits x, slow, fast_high, fast_low
constant TRIG_SOURCE : std_logic_vector(TRIG_FIELD-1 downto 0) := x"1"; -- 0x1601
constant FAST_LOW  : natural := 0;
constant FAST_HIGH : natural := 1;
constant TRIG_SLOW : natural := 2;
constant SCE_EXT   : natural := 3;
-- le registre mode de dclenchement
constant TRIG_MODE : std_logic_vector(TRIG_FIELD-1 downto 0) := x"2"; -- 0x1602
constant MODE_BITS : integer := 2; -- nbre de bits du registre de mode
constant TRIG_OFF  : std_logic_vector(MODE_BITS-1 downto 0) := "00";
constant SINGLE    : std_logic_vector(MODE_BITS-1 downto 0) := "01";
constant NORMAL    : std_logic_vector(MODE_BITS-1 downto 0) := "10";
constant AUTO      : std_logic_vector(MODE_BITS-1 downto 0) := "11";
-- le registre contenant la priode de relaxation du mode auto
constant RELAX       : std_logic_vector(TRIG_FIELD-1 downto 0) := x"3"; -- 0x1603
-- la priode de relaxation par defaut du mode auto
constant AUTO_BITS : integer := 10; -- le nombre de bits du compteur de relaxation (max 1023 ms)
constant DEFAULT_RELAX : integer := 50; -- en units de l'horloge 'millisec' (50 millisecondes)
-- le timeout requte / validation (en s)
constant TRIG_TIME_OUT : std_logic_vector(TRIG_FIELD-1 downto 0) := x"4"; -- 0x1604
constant TRIG_TOUT_BITS: integer := 8; -- max 256 s
constant DEFAULT_TRIG_TOUT : integer := 50; -- timeout par dfaut = 50 s
-- l'tat de la machine de trigger
constant TRIG_STATE : std_logic_vector(TRIG_FIELD-1 downto 0) := x"5"; -- 0x1605

--===== les ADCs et le systme d'alignement des horloges ========================================
-- (longueur 1024 --> adresse en '400')
constant ALIGNER_MEM: std_logic_vector (SC_TOP downto 0) := x"1800";

--===== les buffers circulaires d'adc ===========================================================
constant CIR_Q_SIZE  : integer := 1024;
constant CIR_I_SIZE  : integer := 1024;

--constant DEFAULT_PRETRIG : integer := 512;
--constant DEFAULT_DEPTH   : integer := 1024;
constant DEFAULT_PRETRIG : integer := 200;  --initial value : 5
constant DEFAULT_DEPTH   : integer := 1000;  -- enregistrements courts pour le test / initial value : 10
constant DEFAULT_WAVE_ENABLE : std_logic_vector(0 downto 0):= "1";

--===== les buffers multi-vnements =============================================================
constant MEB_Q_SIZE : integer := 4096; -- les buffers linaires multi-evt  100 MHz
constant MEB_I_SIZE : integer := 8192; -- les buffers linaires multi-evt  250 MHz

--===== les mmoires segments ===================================================================
-- pour la dtermination de la taille (en mots) de la mmoire segments, deux lments comptent:
-- * le nombre de segments (NB_SEG). c'est un paramtre global. point n'est besoin
--   de le passer en argument aux modules
-- * le nombre de mots de chaque entre segment celui-ci est gal au nombre d'items
--   (SEG_SLOW/FAST_ITEMS) + 1 pour le pointeur vers la mmoire fifo
--   la taille et le nombre de bits d'adresse sont calculs automatiquement en fonction des
--   deux paramtres ci-dessus quand c'est ncessaire

-- l'espace SC des mmoires segment (7 bits, physiquement. c'est plus petit)
constant SEG_SC_BITS  : integer := 7; -- on peut adresser chaque item sparment

-- nbre total de segments par buffer. Ce paramtre est global
-- et le nombre de bits ncessaires pour adresser les segments (pas les items)
constant NB_SEG    : integer := 16;
constant SEG_BITS  : integer := bits(NB_SEG);
constant SEG_ALARM : integer := 2; -- seuil de gnration de lWait (en nbre de segments):11 par dfaut

--=== Machine de lecture ========================================================================
-- les numros d'item pour le rangement dans le MEB
constant RD_FIFO_RECORD_ITEMS : integer := 5; 
constant ITEM_SEG    : std_logic_vector (2 downto 0) := "000"; -- N de segment
constant ITEM_EVT    : std_logic_vector (2 downto 0) := "001"; -- N d'vnement
constant ITEM_TS_REQ : std_logic_vector (2 downto 0) := "010"; -- Timestamp Request
constant ITEM_TS_VAL : std_logic_vector (2 downto 0) := "011"; -- Timestamp Validation
constant ITEM_BITMASK : std_logic_vector (2 downto 0):= "100"; -- trigger bitmask

-- les registres de la machine de lecture
constant RD_ENG_REG  : std_logic_vector (SC_TOP downto 0) := X"1700";
constant RD_ENG_FLD : integer := 4; -- la largeur du champ RD_ENG
constant TS_REQ  : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"0";
constant TS_VAL  : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"1";
constant RD_ENG_CTRL : std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"2";
constant WAVER_SAVE: std_logic_vector(LEV_SLOW_FLD-1 downto 0) := x"3"; 

--===============================================================================================

-- nombre de bits des donnes changes entre blocs, y compris tag
constant DATA_WITH_TAG : integer := 16;
constant NO_DATA   : std_logic_vector (DATA_WITH_TAG-1 downto 0) := x"3030"; -- donnee factice
                                                                             -- pour le debug
--===== les segments de donnes dans les MEB ====================================================
--constant SEG_LENGTH  : integer :=  256; -- la longueur par dfaut du segment de charge  4 GeV
--constant NSEG        : integer :=   16; -- le nbre max de segments du MEB

--===============================================================================================
-- les ADCs
constant ADC_DATA_W  : integer :=   14; -- la largeur de l'ADC
constant ADC_TOP     : integer := ADC_DATA_W - 1;
-- les ADCs rapides
constant ADC_FAST_DATA_W : integer := 14;
constant ADC_FAST_TOP    : integer := ADC_FAST_DATA_W - 1;

constant ADC_TOTAL_W : integer :=   16; -- la largeur tendue pour traiter les donnes ADC 2
constant ENER_WIDTH  : integer := ADC_DATA_W + 10; -- paramtre pour + de 16 bits au total (2 mots)
--constant CLK_DELAY_VAL : integer := 12; -- environ 1 ns
constant CLK_DELAY_VAL : integer := 12; -- 78 ps pour ne pas faire zro

-- le trigger ===================================================================================
constant TRIG_SHAPER_OUT_WIDTH : integer := 20; -- les bits en sortie de shaper (jusqu' 320 ns sans saturer le filtre)
constant DEFAULT_TRIG_RISE     : integer := 50; -- mont par dfaut (500 ns)
constant DEFAULT_TRIG_PLATEAU  : integer := 100; -- plateau + descente par dfaut (plateau = 500 ns)
                                                --                  (plateau max 128 -> 1,28 Âµs)
constant DEFAULT_LEVEL_L       : integer := 100; -- valeur initiale du registre niveau bas
constant DEFAULT_LEVEL_H       : integer := 500; -- valeur initiale du registre niveau haut
constant DEFAULT_LEVEL_SLOW    : integer := 500; -- valeur initiale dclenchement lent

-- le bloc nergie =============================================================================
constant ENER_SHAPER_OUT_WIDTH    : integer :=  24; -- les bits en sortie de shaper (14 + 10)
constant TRIG_SHAPER_FLAT_WIDTH   : integer := 10; -- pour le shaper du bloc ETrigger

constant DEFAULT_SHAPER_FLAT_WIDTH_SI : integer := 10;
constant DEFAULT_RISE_SI          : integer := 200; -- 2 s
constant DEFAULT_PLATEAU_SI       : integer := 400; -- monte + plateau (plateau = 2 s) (plateau max 128 -> 1,28 s)
constant DEFAULT_PEAKING_SI       : integer := 300; -- 3 s
--constant DEFAULT_PEAKING_SI       : integer := 30; -- court pour le test

constant DEFAULT_SHAPER_FLAT_WIDTH_CSI : integer := 11;
constant DEFAULT_RISE_CSI_TOT     : integer := 500; -- 5 s
constant DEFAULT_PLATEAU_CSI_TOT  : integer := 1000; -- plateau = 5 s
--constant DEFAULT_PEAKING_CSI_TOT  : integer := 800; -- peaking = 8 s
constant DEFAULT_PEAKING_CSI_TOT  : integer := 40; -- court pour le test

constant DEFAULT_RISE_CSI_FAST    : integer := 100; -- 1 s
constant DEFAULT_PLATEAU_CSI_FAST : integer := 200; -- plateau = 1 s
--constant DEFAULT_PEAKING_CSI_FAST : integer := 250;
constant DEFAULT_PEAKING_CSI_FAST : integer := 20; -- court pour le test

-- baseline calculation block  ==================================================================
constant BL_DEFAULT_PRETRIG       : integer := 5;
constant BL_DEFAULT_MDEPTH        : integer := 8;
constant BL_PRECISION_BITS        : integer := 4; -- number of bits kept for baseline value precision
constant BL_TOP                   : integer := ADC_TOP+BL_PRECISION_BITS;

-- la machine de lecture (ReadEngine) ===========================================================
constant READ_BUFFER : std_logic_vector(15 downto 0) := x"F000";
constant READ_BUF_SIZE : integer := 4096;

constant TS_BITS     : integer :=   15; -- nombre de bits du time_stamp
constant EVT_NR_BITS : integer :=   12; -- longueur de l'event number fourni au moment de la validation
constant DEFAULT_SAVE_WAVE : integer :=   4; -- periodic base (should be >= 4 to save waves in all 2^4(=16)telescopes)

-- les tags des données à l'émission
constant EMPTY_TAG  : std_logic_vector(3 downto 0) := x"8";
constant DETID_TAG  : std_logic_vector(4 downto 0) := "10010"; -- 90
constant TELID_TAG  : std_logic_vector(4 downto 0) := "10011"; -- 98
constant LENGTH_TAG : std_logic_vector(3 downto 0) := x"A";
constant CRCFE_TAG  : std_logic_vector(3 downto 0) := x"B";
constant BLKID_TAG  : std_logic_vector(4 downto 0) := "11000"; -- C
constant REGID_TAG  : std_logic_vector(4 downto 0) := "11001"; -- C
constant CRCBL_TAG  : std_logic_vector(3 downto 0) := x"D";
constant EC_TAG     : std_logic_vector(3 downto 0) := x"E"; -- event counter
constant EOE_TAG    : std_logic_vector(3 downto 0) := x"F";

constant SS_ENER_TAG : std_logic_vector(11 downto 0) := x"001";  -- slow shaped energy tag
constant FS_ENER_TAG : std_logic_vector(11 downto 0) := x"002";  -- fast shaped energy tag
constant BASE_TAG    : std_logic_vector(11 downto 0) := x"003";  -- baseline tag
constant PRETRIG_TAG : std_logic_vector(11 downto 0) := x"004";  -- pretrigger tag (for all the waveforms)
constant WAVE_TAG    : std_logic_vector(11 downto 0) := x"005";  -- waveform tag  (for all the waveforms)

-- longueurs (en mots) associées à chaque tag
constant SS_ENER_LEN : integer := 3;  -- slow shaped energy field length (in samples) (includes the filter risetime)
constant FS_ENER_LEN : integer := 3;  -- fast shaped energy field  length (in samples) (includes the filter risetime)
constant BASE_LEN    : integer := 2;  -- baseline length field  (in samples)
constant PRETRIG_LEN : integer := 1;  -- wavefrom pretrigger field length (in samples)
-- la longeur du champ WAVE est dynamique et délivrée en en-tête des échantillons par le MEB.

-- les tags des données à la réception
constant EC_TAG_R   : std_logic_vector(3 downto 0) := x"1"; -- event counter
constant TP_TAG     : std_logic_vector(3 downto 0) := x"2"; -- trigger pattern

--===============================================================================================
-- un po di tutto
constant NULL_16 : std_logic_vector(15 downto 0) := (others => '0');
constant ONES_16 : std_logic_vector(15 downto 0) := (others => '1');

--===== nouvelle configuration lent / rapide ===== 28-11-2011 ===================================
-- pour toutes les voies lentes------------------------------------------------------------------

-- nbre total de mots de 16 bits par entre charge de seg  
-- constant SEG_SLOW_ITEMS    : integer :=  4; -- energie (2 mots) baseline (2 mots)
constant SEG_SLOW_ITEMS    : integer :=  9; -- (tag (1 mot) + length (1 mot) + tRise du filtre + energie (2 mots))
                                            -- + (tag (1 mot) + length (1 mot) + baseline (2 mots))
-- nbre total de mots de 16 bits par entre de seg CsI
-- constant SEG_CSI_ITEMS     : integer :=  6; -- energie tot et fast (2 x 2 mots) baseline (2 mots)
constant SEG_CSI_ITEMS     : integer :=  14; -- (tag (1 mot) + length (1 mot) + tRise du filtre + energie tot(2 mots)) - idem pour energie fast 
                                             -- + (tag (1 mot) + length (1 mot) + baseline (2 mots))              
-- pour toutes les voies rapides-----------------------------------------------------------------
-- nbre d'items par entre de segment courant
constant SEG_FAST_ITEMS     : integer :=  0;

-- regroupement de tous les paramtres d'une voie

-------------------------------------------------------------------------------------------------
constant SI_1        : integer := 0;

-- voie --- QH1 ---
constant ADC_QH1     : integer := 0; -- N d'ADC pour la calibration des dlais
constant WAVE_QH1    : integer := 0;
constant QH1_SC      : std_logic_vector (SC_TOP downto 0) := x"1000"; -- adresse des registres
constant CIR_BUF_QH1 : std_logic_vector (SC_TOP downto 0) := x"B000"; -- longueur 1024
constant MEB_QH1     : std_logic_vector (SC_TOP downto 0) := x"8000"; -- longueur 4096
constant SEG_QH1     : std_logic_vector (SC_TOP downto 0) := x"C800"; -- longueur 128
constant HISTO_QH1   : std_logic_vector (SC_TOP downto 0) := x"D000"; -- longueur 1024
-- voie --- I1 ---
constant ADC_I1      : integer := 1;
constant WAVE_I1     : integer := 1;
constant I1_SC       : std_logic_vector (SC_TOP downto 0) := x"1100";
constant CIR_BUF_I1  : std_logic_vector (SC_TOP downto 0) := x"B400"; -- longueur 1024
constant MEB_I1      : std_logic_vector (SC_TOP downto 0) := x"2000"; -- longueur 8192
constant SEG_I1      : std_logic_vector (SC_TOP downto 0) := x"C880"; -- longueur 128
-- voie --- QL1 ---
constant ADC_QL1     : integer := 2;
constant WAVE_QL1    : integer := 2;
constant QL1_SC      : std_logic_vector (SC_TOP downto 0) := x"1200";
constant CIR_BUF_QL1 : std_logic_vector (SC_TOP downto 0) := x"B800"; -- longueur 1024
constant MEB_QL1     : std_logic_vector (SC_TOP downto 0) := x"4000"; -- longueur 8192
constant SEG_QL1     : std_logic_vector (SC_TOP downto 0) := x"C900"; -- longueur 128
---------------------------------------------------------------------------------------
constant SI_2        : integer := 1;

-- voie --- Q2 ---
constant ADC_Q2      : integer := 3;
constant WAVE_Q2     : integer := 0;
constant Q2_SC       : std_logic_vector (SC_TOP downto 0) := x"1300";
constant CIR_BUF_Q2  : std_logic_vector (SC_TOP downto 0) := x"BC00"; -- longueur 1024
constant MEB_Q2      : std_logic_vector (SC_TOP downto 0) := x"9000"; -- longueur 4096
constant SEG_Q2      : std_logic_vector (SC_TOP downto 0) := x"C980"; -- longueur 128
constant HISTO_Q2    : std_logic_vector (SC_TOP downto 0) := x"D800"; -- longueur 1024
-- voie --- I2 ---
constant ADC_I2      : integer := 4;
constant WAVE_I2     : integer := 1;
constant I2_SC       : std_logic_vector (SC_TOP downto 0) := x"1400";
constant CIR_BUF_I2  : std_logic_vector (SC_TOP downto 0) := x"C000"; -- longueur 1024
constant MEB_I2      : std_logic_vector (SC_TOP downto 0) := x"6000"; -- longueur 8192
constant SEG_I2      : std_logic_vector (SC_TOP downto 0) := x"CA00"; -- longueur 128
---------------------------------------------------------------------------------------
constant CS_I        : integer := 2;

-- voie --- Q3 ---
constant ADC_Q3      : integer := 5;
constant WAVE_Q3     : integer := 0;
constant Q3_SC       : std_logic_vector (SC_TOP downto 0) := x"1500";
constant CIR_BUF_Q3  : std_logic_vector (SC_TOP downto 0) := x"C400"; -- longueur 1024
constant MEB_Q3      : std_logic_vector (SC_TOP downto 0) := x"A000"; -- longueur 4096
constant SEG_Q3      : std_logic_vector (SC_TOP downto 0) := x"CA80"; -- longueur 128
constant HISTO_TOT   : std_logic_vector (SC_TOP downto 0) := x"E000"; -- longueur 1024
constant HISTO_FAST  : std_logic_vector (SC_TOP downto 0) := x"E800"; -- longueur 1024
---------------------------------------------------------------------------------------

--- rampe issue de generalIO
constant RAMP        : integer := 6;
constant FAST_SIGNALS: integer := 7;


-- vers les LMK2000 (telescope A) ---------------------------------------------------------------
constant AD_LMK       : std_logic_vector (15 downto 0) := X"0100";
constant LMK_FIELD    : integer := 2; -- deux bits pour les 2x2 mots des deux LMK
constant LMK_1H       : std_logic_vector(LMK_FIELD-1 downto 0) := "00";
constant LMK_1L       : std_logic_vector(LMK_FIELD-1 downto 0) := "01";
constant LMK_2H       : std_logic_vector(LMK_FIELD-1 downto 0) := "10";
constant LMK_2L       : std_logic_vector(LMK_FIELD-1 downto 0) := "11";

--- gnrateur d'horloges d'alimentation (telescope B) ------------------------------------------
constant PS_GEN         : std_logic_vector (15 downto 0) := X"0110";
constant PS_FIELD       : integer := 4; -- 4 bits pour les 7 registres (so far ...)
constant PS_PERIOD      : std_logic_vector(PS_FIELD-1 downto 0) := x"0";
constant PS_PHASE_VP2_5 : std_logic_vector(PS_FIELD-1 downto 0) := x"1";
constant PS_PHASE_VP3_7 : std_logic_vector(PS_FIELD-1 downto 0) := x"2";
constant PS_PHASE_VM2_7 : std_logic_vector(PS_FIELD-1 downto 0) := x"3";
constant PS_PHASE_HV    : std_logic_vector(PS_FIELD-1 downto 0) := x"4";
constant PS_PERIODHV    : std_logic_vector(PS_FIELD-1 downto 0) := x"5";

end tel_defs;

--===============================================================================================
package body tel_defs is
-------------------------------------------------------------------------------------------------
-- Calcul du nombre de bits d'un mot en fonction de sa taille
-- les tailles singulires 0 et 1 donnent un nombre de bits de 1

function bits (taille : integer) return integer is
variable top     : integer := 1;
variable largeur : integer := 1;
begin
if taille < 2 then return 1; end if;
l: while (taille > top) loop
     top := 2*top;
     largeur := largeur + 1;
   end loop;
   return largeur-1;
end function bits;

-------------------------------------------------------------------------------------------------
-- Calcul du OU logique entre tous les bits d'un bus
function or_reduce (A : std_logic_vector) return std_logic is
variable temp : std_logic := '0';
begin
  l: for i in A'range loop
      temp := temp or A(i);
  end loop l;
  return temp;
end function or_reduce;

end tel_defs;
