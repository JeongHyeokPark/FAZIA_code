----------------------------------------------------------------------------------
-- Company: IPNO
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:     11/10/2011
-- Save date:
-- Design Name:     telescope
-- Module Name:     trigger - Behavioral 
-- Project Name:    fazia
-- Target Devices:  virtex-5
-- Tool versions:   ISE 12.3
-- Description: Trigger du tÃ©lescope
-- version complÃ¨tement revue du 9-05-2012

-- Quatre modes de fonctionnement slectionns par le registre 'mode'
---------------------------------------------------------------------
-- off: trigger inactif, seule la commande SC 'force' permet de gnrer un dclenchement
-- normal: une requte (lt) est gnre  chaque fois que les conditions de trigger sont runies
-- single: deux tats
--    arm: comme en mode normal, on attend que les conditions de dclenchement soient runies
--          mais on passe dans l'tat 'inactif' aprs l'vnement
--    inactif: trigger inactif comme en mode off mais une commande SC 'single' fait passer 
--          l'tat arm
-- auto: comme en mode 'normal' mais un dclenchement on force un dclenchement si aucune
--    condition de trigger ne s'est produite pendant un certain temps (dlai d'inspection)
--    les requtes sont donc produites de faon rcurrente si pas de dclenchement naturel

-- les signaux en jeu:
----------------------
-- sourceQualified: c'est le 'ou' logique des sources naturelles (sorties des comparateurs,
--   entre externe, chacune valide par un bit d'un registre de contrle. La dure de ce signal
--   n'est pas dfinie. C'est l'instant de sa monte qui compte. Noter nanmoins que la source
--   de dclenchement se tarit si l'un quelconque des signaux reste  '1'
-- lt: requte mise par le tlescope  destination de la blockcard. Ce signal monte quand les
--   conditions sont runies et retombe 1) quand arrive la validation (glt) ou aprs un dlai
--   de timeout si celle-ci n'arrive pas. On abandonne l'vnement.
-- glt: le signal de validation manent de la blockcard. L'acquisition dmarre ds qu'il arrive
--   Sa dure n'est pas dfinie, on attend qu'il soit retomb pour que l'ensemble du trigger
--   retourne dans l'tat de repos du mode slectionn
-- val: le signal de validation envoy  toutes les voies pour dclencher l'acquisition

-- les tats de la machine de trigger
-------------------------------------
-- idle: trigger au repos, aucune action en cours
-- pending: une requte a t mise, on attend la validation
-- running: la validation est arrive, une acquisition est en cours


--
-- Revision: 
-- Additional Comments: 
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.tel_defs.all;
use work.slow_ct_defs.all;
use work.telescope_conf.all;

entity trigger is
  generic (RegAd : std_logic_vector(SC_AD_WIDTH-1 downto 0));
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    clear       : in  std_logic;
    microsec    : in  std_logic; -- signal  1 MHz rapport cyclique = 50 %
    millisec    : in  std_logic; -- signal  1 kHz rapport cyclique = 50 %
    ---
    trigSlow    : in  std_logic_vector (NB_SLOW-1 downto 0); -- autant de sces de trigger que de voies lentes
    trigFastH   : in  std_logic_vector (NB_SLOW-1 downto 0);
    trigFastL   : in  std_logic_vector (NB_SLOW-1 downto 0);
    trigExt     : in  std_logic;
	 pulserOn    : in  std_logic;
	 trigBitmask : out std_logic_vector (14 downto 0); 
    ---
    lt          : out std_logic; -- source de trigger brute, pour contrle et visualisation
    ltLed       : out std_logic; -- le voyant monostabilis
    glt         : in  std_logic; -- validation en retour de la blockcard
    val         : out std_logic;
    veto        : out std_logic;
    valLed      : out std_logic; -- le voyant monostabilis
    ---
    acqBusy     : in  std_logic;
    segNrWr     : out std_logic_vector (SEG_BITS-1 downto 0);
    --- sorties spciales pour chipscope
    etatTrigger : out std_logic_vector( 2 downto 0);
    sourceBrute : out std_logic;
    ---
    slowCtBus   : in  slowCtBusRec;
    slowCtBusRd : out std_logic_vector (15 downto 0)
  );
end trigger;

-------------------------------------------------------------------------------------------------
architecture Behavioral of trigger is

--===== configuration ===========================================================================
-- Tous les paramtres dans tel_defs sous Trigger-Box
--===============================================================================================

signal oldMicrosec : std_logic;
signal oldMillisec : std_logic;

signal sourceQualified : std_logic; -- 'or' des sources de dclenchement valides
signal oldSceQualified : std_logic;
signal bitmask         : std_logic_vector(12 downto 0);

signal segment     : std_logic_vector (SEG_BITS-1 downto 0); -- compteur de segment
signal tsCnter     : std_logic_vector(TS_BITS-1+2 downto 0); -- 2 bits de plus pour diviser par 4
signal syncZerOld  : std_logic;

signal localVal    : std_logic; -- instance interne de la sortie val
signal lateVal     : std_logic; -- pour monoflopper
signal monoVal     : std_logic_vector(7 downto 0); -- compte un maximum de 255 ms

signal ltLocal     : std_logic;
signal lateLt      : std_logic;
signal monoLt      : std_logic_vector(7 downto 0); -- compte un maximum de 255 ms

signal autoCount   : std_logic_vector(AUTO_BITS-1 downto 0); -- compteur/timer pour le mode auto

--- les registres ---
-- validation des sources
signal sceSi1    : std_logic_vector(2 downto 0); -- slow, fast_high, fast_low
signal sceSi2    : std_logic_vector(2 downto 0);
signal sceCsI    : std_logic_vector(2 downto 0);
signal sceExt    : std_logic;
-- mode: voir dfinitions associes  l'adresse TRIG_MODE
signal mode      : std_logic_vector(MODE_BITS-1 downto 0);
-- priode de relaxation mode auto (en millisecondes)
signal relaxReg, inspection: std_logic_vector (AUTO_BITS-1 downto 0); -- registre, compteur resp.
-- timeout request/validation               registre, compteur resp.
signal timeOutReg, timeOut : std_logic_vector (TRIG_TOUT_BITS-1 downto 0);
signal forceSet, armSet : std_logic;

type trigType is (IDLE, ARMED, START_REQ, PENDING, START_RUN, RUNNING, ACQUIT);
signal trigState : trigType;
signal etatTriggerLocal : std_logic_vector(2 downto 0);
signal CONTROL0 : std_logic_vector (35 downto 0);
signal all_zero_64 : std_logic_vector (63 downto 0);
signal vetoLocal   : std_logic;

component tel_ila_trig64
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK     : IN STD_LOGIC;
    TRIG0   : IN STD_LOGIC_VECTOR(  63 DOWNTO 0)
  );
end component;

component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
end component;

begin

--===== chipscope ===============================================================================

makeCS: if chip_trigger generate

mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0
  );

mes_sondes : tel_ila_trig64
  port map (
    CONTROL => CONTROL0,
    CLK     => clk,
    ---
    trig0 ( 2 downto  0) => etatTriggerLocal,
    trig0 ( 5 downto  3) => trigSlow,
    trig0 ( 8 downto  6) => trigFastH,
    trig0 (11 downto  9) => trigFastL,
    trig0 (14 downto 12) => sceSi1,
    trig0 (17 downto 15) => sceSi2,
    trig0 (20 downto 18) => sceCsI,
    trig0 (21) => sourceQualified,
    trig0 (22) => oldSceQualified,
    trig0 (23) => localVal,
    trig0 (24) => ltLocal,
    trig0 (25) => glt,
    trig0 (26) => acqBusy,
    trig0 (27) => vetoLocal,
    trig0 (63 downto 28) => all_zero_64(63 downto 28)
 );
end generate;

--===============================================================================================

-- gestion de val
val   <= localVal;
lt    <= ltLocal;
etatTriggerLocal <= conv_std_logic_vector(trigType'pos(trigState), 3);
etatTrigger <= etatTriggerLocal;
sourceBrute <= sourceQualified;

-- le 'and' entre le registre de slection et les diffrentes sources de trigger
sourceQualified <= (trigExt and sceExt) or
                  or_reduce(trigSlow(0) & trigFastH(0) & trigFastL(0) and sceSi1) or
                  or_reduce(trigSlow(1) & trigFastH(1) & trigFastL(1) and sceSi2) or
                  or_reduce(trigSlow(2) & trigFastH(2) & trigFastL(2) and sceCsI);
								
bitmask(12 downto 0) <= trigExt & 
                        '0' & (trigSlow(2) & trigFastH(2) & trigFastL(2) and sceSi1) &
 							   '0' & (trigSlow(1) & trigFastH(1) & trigFastL(1) and sceSi2) &
                        '0' & (trigSlow(0) & trigFastH(0) & trigFastL(0) and sceCsI);									  

segNrWr        <= segment;
veto           <= vetoLocal;

-------------------------------------------------------------------------------------------------
-- la machine principale de trigger

trigProc: process (reset, clk)
begin
  if reset = '1' then
    ltLocal  <= '0';
    localVal <= '0';
    segment <= (others => '0');
    trigState <= IDLE;
    inspection <= conv_std_logic_vector(DEFAULT_RELAX, AUTO_BITS);
    timeOut    <= conv_std_logic_vector(DEFAULT_TRIG_TOUT, TRIG_TOUT_BITS);
	 trigBitmask <= (others => '0');
  elsif rising_edge(clk) then
    oldSceQualified <= sourceQualified; -- pour dtection de la monte
    oldMicrosec <= microsec;
    oldMillisec <= millisec;
    if clear = '1' then
      trigState <= IDLE;
    end if;
    case trigState is
  --=======================
    when IDLE => -- 0
      localVal <= '0';
      if forceSet = '1' then -- prioritaire, indpendant du mode
        timeOut   <= timeOutReg; -- armement du timeout de validation
        trigState <= START_REQ;
      end if;
      
      case mode is
      -----------------------
      when SINGLE =>
        if armSet = '1' then
          trigState <= ARMED;
        end if;
      -----------------------
      when NORMAL =>
        trigState <= ARMED;
      -----------------------
      when AUTO =>
        inspection <= relaxReg;
        trigState  <= ARMED;
      -----------------------
      when others => null;
      -----------------------
      end case;
  --=======================
    when ARMED => -- 1 attente d'une condition de dclenchement
      if (sourceQualified = '1' and oldSceQualified = '0') or forceSet = '1' then -- le cas normal
		  trigBitmask <= pulserOn & '0' & bitmask; -- sortie du trigger bitmask (ne pas oublier que bitmask est combinatoire 
		                                 -- donc la mémorisation doit être synchro avec la détection du front montant de sourceQualified)
        trigState <= START_REQ;
      end if;
      if glt = '1' then -- global trigger avant local (peut-être venu d'une autre voie)
        segment <= segment + 1; -- nb. pas de raz de ce compteur. On compte sur le modulo
        localVal <= '1';
        trigState <= START_RUN;
      end if;
      case mode is
      -----------------------
      when TRIG_OFF => -- le SC a changé le mode
        trigState <= IDLE;
      -----------------------
      when AUTO =>
        if inspection = 0 then
          inspection <= relaxReg; -- rarmement du compteur auto
          trigState  <= START_REQ;  -- le délai d'inspection est atteint sans déclenchement naturel
        elsif millisec = '1' and oldMillisec = '0' then
          inspection <= inspection -1;
        end if;
      -----------------------
      when others => null;
      -----------------------
      end case;
  --=======================
    when START_REQ => -- 2 en attente de validation
      ltLocal <= '1';
      timeOut   <= timeOutReg; -- armement du timeout de validation
      trigState <= PENDING;
  --=======================
    when PENDING => -- 3 en attente de validation
      if glt = '1' then  -- on a reçu la validation
        ltLocal  <= '0';
        segment <= segment + 1; -- nb. pas de raz de ce compteur. On compte sur le modulo
		  trigBitmask <= (others => '0');
        localVal <= '1';
        trigState <= START_RUN;
      end if;
        
      if timeOut = 0 then
         ltLocal <= '0';
			trigBitmask <= (others => '0');
         trigState <= ARMED; -- on abandonne la requête
      elsif microsec = '1' and oldMicrosec = '0' then
         timeOut <= timeOut -1;
      end if;
  --=======================
    when START_RUN => -- 4
      if acqBusy = '1' then
        trigState <= RUNNING;
      end if;
  --=======================
    when RUNNING => -- 5 toutes les voies sont en cours d'acquisition, on attend la fin
      if acqBusy = '0' then
        localVal <= '0';
        -- génération du signal de veto. Le signal sera stable jusqu'au prochain eReset
        if trigSlow(0) = '0' and trigSlow(1) = '0' and trigSlow(2) = '0' then
          vetoLocal <= '1'; -- suppression
        else
          vetoLocal <= '0'; -- il y a de l'énergie quelque part
        end if;
        trigState <= ACQUIT;
      end if;
  --=======================
    when ACQUIT => -- 6
      --if sourceQualified = '0' then
        case mode is
        -----------------------
        when NORMAL =>
          trigState <= ARMED;
        -----------------------
        when AUTO =>
          inspection <= relaxReg;
          trigState <= ARMED;
        -----------------------
        when TRIG_OFF | SINGLE =>
          trigState <= IDLE;
        -----------------------
        when others => null;
        end case;
      --end if;
  --=======================
    when others => null;
  --=======================
    end case;
  end if;
end process trigProc;

-------------------------------------------------------------------------------------------------
-- monostable pour la led de validation. il déclenche sur la montée de val
-- c'est un compteur (monoVal) qui  décompte  chaque milliseconde quand il n'est pas nul
-- en maintenant la led allumée pendant 250 ms

mono_led_val: process(clk)
begin
  if rising_edge(clk) then
    lateVal <= localVal;
    valLed <= '0'; -- led éteinte par défaut
    if localVal = '1' and lateVal = '0' then -- montée de val (process trigComb)
      monoVal <= conv_std_logic_vector(250, 8); -- armement du compteur (250 ms) retriggerable
    elsif monoVal /= x"00" then
      valLed <= '1'; -- led allumée tant que compteur non nul
      if millisec = '1' and oldMillisec = '0' then
        monoVal <= monoVal-1;
      end if;
    end if;
  end if;
end process;

-- idem pour la led de local trigger

mono_led_lt: process(clk)
begin
  if rising_edge(clk) then
    lateLt <= LtLocal;
    ltLed <= '0'; -- led éteinte par défaut
    if ltLocal = '1' and lateLt = '0' then -- montée de val (process trigComb)
      monoLt <= conv_std_logic_vector(250, 8); -- armement du compteur (250 ms) retriggerable
    elsif monoLt /= x"00" then
      ltLed <= '1'; -- led allumée tant que compteur non nul
      if millisec = '1' and oldMillisec = '0' then
        monoLt <= monoLt-1;
      end if;
    end if;
  end if;
end process;

-------------------------------------------------------------------------------------------------
regLoad: process (clk, reset)
begin
  if reset = '1' then
    relaxReg   <= conv_std_logic_vector(DEFAULT_RELAX, AUTO_BITS);
    timeOutReg <= conv_std_logic_vector(DEFAULT_TRIG_TOUT, TRIG_TOUT_BITS);
    mode       <= TRIG_OFF;
  elsif rising_edge(clk) then
    slowCtBusRd <= (others => '0'); -- laisser le bus de lecture libre
    armSet   <= '0'; -- durée 1 seul clk
    forceSet <= '0'; -- durée 1 seul clk
    if slowCtBus.addr(SC_AD_WIDTH-1 downto TRIG_FIELD) = RegAd(SC_AD_WIDTH-1 downto TRIG_FIELD) then
      if slowCtBus.wr = '1' then
        case slowCtBus.addr(TRIG_FIELD-1 downto 0) is
          when TRIG_CTRL     => if    slowCtBus.data(ARM_BIT)   = '1' then armSet   <= '1';
                                elsif slowCtBus.data(FORCE_BIT) = '1' then forceSet <= '1';
                                end if;
          when TRIG_SOURCE   => sceSi1     <= slowCtBus.data( 2 downto 0);
                                sceSi2     <= slowCtBus.data( 6 downto 4);
                                sceCsI     <= slowCtBus.data(10 downto 8);
                                sceExt     <= slowCtBus.data(12);
          when TRIG_MODE     => mode       <= slowCtBus.data(MODE_BITS-1 downto 0);
          when RELAX         => relaxReg   <= slowCtBus.data(AUTO_BITS-1 downto 0);
          when TRIG_TIME_OUT => timeOutReg <= slowCtBus.data(TRIG_TOUT_BITS-1 downto 0);
          when others => null;
        end case;
      elsif slowCtBus.rd = '1' then
        case slowCtBus.addr(TRIG_FIELD-1 downto 0) is
          when TRIG_SOURCE   => slowCtBusRd(12 downto 0) <= sceExt & '0' & sceCsI & '0' & sceSi2 & '0' & sceSi1;
          when TRIG_MODE     => slowCtBusRd(MODE_BITS-1 downto 0) <= mode;
          when RELAX         => slowCtBusRd(AUTO_BITS-1      downto 0) <= relaxReg;
          when TRIG_TIME_OUT => slowCtBusRd(TRIG_TOUT_BITS-1 downto 0) <= timeOutReg;
          when TRIG_STATE    => slowCtBusRd(2 downto 0) <= etatTriggerLocal;
          when others => null;
        end case;
      end if;
    end if;
  end if;
end process regLoad;

-------------------------------------------------------------------------------------------------
end Behavioral;
