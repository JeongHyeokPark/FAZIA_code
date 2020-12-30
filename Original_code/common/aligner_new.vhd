-------------------------------------------------------------------------------------------------
-- Company: IPN Orsay
-- Engineer: Pierre EDELBRUCK

-- Create Date:    31-01-2012
-- Revised:        07-03-2012
-- Printed:        07-03-2012
-- Design Name:    telescope
-- Module Name:    Aligner_new - Behavioral 
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions:  ise 12.4

-- Description:
-- ===========
-- Module d'alignement des données d'ADC. C'est un composant de AdcMon.
-- Agit sur les modules DDR_ADC par l'intermédiaire du bus alignBus.
-- Dans cette version, seul l'alignement manuel par le slow control est implémenté.
-- Chaque retard peut être programmé individuellement, sa valeur est conservée en RAM et peut
-- être relue. La RAM est initialisée automatiquement au reset par recopie du contenu d'une ROM
-- qui contient les retards par défaut (voir aligner_rom.coe).
-- Pour programmer manuellement un délai, il suffit d'écrire sa valeur à l'adresse RAM
-- correspondante

-- Pour un alignement automatique (à implanter ultérieurement) les ADCs devront émettre un
-- pattern de test en continu (c'est AdcMon qui devra s'en charger)

-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;

--===============================================================================================
entity Aligner_new is
  -- adresse de base mémoire (slot de 1 kmots)
  generic (MemAdr : std_logic_vector (SC_AD_WIDTH-1 downto 0));
  port (
    clk          : in  std_logic; -- horloge système à 100 MHz
    reset        : in  std_logic;
    lock200MHz   : in  std_logic;
    ---
    --reload       : in  std_logic; -- signal provisoire
    alignBus     : out AlignBusRec;
    alignDataBit : in  std_logic_vector (ADCS_TOTAL-1 downto 0);
    ---
    slowCtBus    : in  SlowCtBusRec;
    slowCtBusRd  : out std_logic_vector (15 downto 0)
  );
end Aligner_new;

--===============================================================================================
architecture Behavioral of Aligner_new is

signal alignBusInternal : AlignBusRec;

-- le nombre de bits d'adresse de la RAM
constant DEL_AD_BITS : integer := 7;
signal memWr1, memWr2, memWr: std_logic;
signal ramAddrIn : std_logic_vector(DEL_AD_BITS-1 downto 0);
signal ramDataIn : std_logic_vector(7 downto 0);
signal ramAddrOut: std_logic_vector(DEL_AD_BITS-1 downto 0);
signal ramDataOut: std_logic_vector(7 downto 0);
signal romAddr   : std_logic_vector(DEL_AD_BITS-1 downto 0);
signal romData   : std_logic_vector(7 downto 0);
-- Nr depuis slow control, Cnter depuis RAM locale
signal bitNr, bitCnter : std_logic_vector(3 downto 0); -- 0..9
signal adcNr, adcCnter : std_logic_vector(2 downto 0); -- 0..5
signal delCnt    : std_logic_vector(5 downto 0);
signal remote    : std_logic; -- signal de sélection RAM locale (0) / slow control (1)
signal delays    : std_logic_vector(5 downto 0); -- 0..63
signal remoteStart, localStart : std_logic; -- ordre de réglage manuel d'un délai
signal counter   : std_logic_vector(5 downto 0);
signal singleBusy: std_logic; -- délai en cours de mise en place

-- registre de sélection du bit d'inspection 6-4 = N° ADC, 3-0 = N° de bit
signal inspectReg   : std_logic_vector(6 downto 0);

-- machine d'état single
type DelState is (IDLE, RAZ, INC);
signal delCs : Delstate;

-- machine d'état positionnement de tous les délais
type AllState is (NOT_STARTED, COPY_ROM, IDLE, LOOPING, WAITING);
signal allCs : AllState;
signal reLoad : std_logic; -- commande de rechargement des délais depuis la RAM

-------------------------------------------------------------------------------------------------
component aligner_rom_128x8
	port (
	a:   in  std_logic_vector(6 downto 0);
	spo: out std_logic_vector(7 downto 0));
end component;

-------------------------------------------------------------------------------------------------
-- mémoire RAM: distributed memory à sorties non registred
component aligner_ram_128x8
port (
  clk    : in std_logic;
  we     : in std_logic;
  --
  a      : in std_logic_vector(DEL_AD_BITS-1 downto 0);  -- adresse port a
  d      : in std_logic_vector(7 downto 0);              -- données d'entrée
  --
  dpra   : in std_logic_vector(DEL_AD_BITS-1 downto 0);  -- adresse port b
  dpo    : out std_logic_vector(7 downto 0)              -- données de sortie
);
end component;

-- pour éviter le warning 2210 au translate
attribute box_type : string;
attribute box_type of aligner_rom_128x8 : component is "black_box";
attribute box_type of aligner_ram_128x8 : component is "black_box";

--===== chipscope =============================================================================
--signal all_zero_128 : std_logic_vector (127 downto 0) := (others => '0');
--signal etat : std_logic_vector (2 downto 0);
--
--signal CONTROL0 : std_logic_vector (35 downto 0);
--
--component tel_ila
--  PORT (
--    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
--    CLK     : IN STD_LOGIC;
--    DATA    : in std_logic_vector(127 downto 0);
--    TRIG0   : IN STD_LOGIC_VECTOR(  7 DOWNTO 0));
--end component;
--
--component tel_icon
--  PORT (
--    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
--end component;

--===============================================================================================
begin
--===== chipscope ===============================================================================
--mon_icon : tel_icon
--  port map (
--    CONTROL0 => CONTROL0);
--
--mes_sondes : tel_ila
--  port map (
--    CONTROL => CONTROL0,
--    CLK     => clk,
--    ---
--    DATA(  0) => reset,
--    DATA(  1) => lock200MHz,
--    DATA(  4 downto  2) => etat,
--    DATA( 11 downto  5) => romAddr,
--    DATA( 19 downto 12) => romData,
--    DATA( 22 downto 20) => adcCnter,
--    DATA( 26 downto 23) => bitCnter,
--    DATA(127 downto 27) => all_zero_128(127 downto 27),
--    ---
--    TRIG0 (0)   => reset,
--    TRIG0 (1)   => lock200MHz,
--    TRIG0 (7 downto 2) => all_zero_128(7 downto 2)
-- );
--etat <= conv_std_logic_vector(AllState'pos(allCs), 3);
--===============================================================================================

-- multiplexage local/remote
alignBusInternal.adc_adr <= adcNr  when remote = '1' else adcCnter;
alignBusInternal.bit_nr  <= bitNr  when remote = '1' else bitCnter;
delCnt           <= delays when remote = '1' else ramDataOut(5 downto 0);
ramAddrOut       <= slowCtBus.addr(DEL_AD_BITS-1 downto 0) when remote = '1'
                      else adcCnter & bitCnter;
                      
-- sélection du bit d'inspection
alignBusInternal.adc_inspect <= inspectReg(6 downto 4);
alignBusInternal.inspect_nr  <= inspectReg(3 downto 0);
alignBusInternal.mode        <= "00";

alignBus <= alignBusInternal;
reLoad  <= '0'; -- ne sert pas pour l'instant
memWr <= memWr1 or memWr2;

---------------------------------
memoireRom: aligner_rom_128x8
  port map (
    a   => romAddr, -- commun avec la ram
    spo => romData
  );

---------------------------------
memoireRam: aligner_ram_128x8
  port map (
    clk    => clk,
    we     => memWr,
    ---
    a      => ramAddrIn,
    d      => ramDataIn,
    ---
    dpra   => ramAddrOut,
    dpo    => ramDataOut
  );
  
-------------------------------------------------------------------------------------------------
-- Machine d'état mise en place de tous les délais de la mémoire: pilote la machine delSet

allSetSeq: process (reset, clk, bitCnter, adcCnter)
variable cyBit : std_logic;
variable cyADC : std_logic;
variable cys   : std_logic_vector(1 downto 0);

begin
  if bitCnter = 8 then cyBit := '1'; else cyBit := '0'; end if;
  if adcCnter = 5 then cyAdc := '1'; else cyAdc := '0'; end if;
  cys := cyAdc & cyBit;
  
  if reset = '1' then
    allCs <= NOT_STARTED;
  elsif rising_edge(clk) then
    case allCs is
    -----------------------------
    when NOT_STARTED => -- 0
      if lock200MHz = '1' then -- mise en place des délais quand PLL 200 MHz prête
        romAddr <= (others => '0');
        allCs   <= COPY_ROM;
      end if;       
    -----------------------------
    -- copy intégrale ROM --> RAM
    when COPY_ROM => -- 1
      if romAddr = 127 then
        adcCnter <= (others => '0');
        bitCnter <= (others => '0');
        allCs    <= LOOPING;
      else
        romAddr  <= romAddr + 1;
      end if;
    -----------------------------
    when IDLE => -- 2
      if reLoad = '1' then
        adcCnter <= (others => '0');
        bitCnter <= (others => '0');
        allCs    <= LOOPING;
      end if;
    -----------------------------
    when LOOPING => -- 3
      allCs <=  WAITING;
    -----------------------------
    when WAITING => -- 4
      if singleBusy = '0' then -- la mise en place du délai n'est pas terminée
        allCs <=  LOOPING;     -- tant que singleBusy est à 1
        case cys is -- cys vaut cyAdc & cyBit;
        when "00" | "10" => bitCnter <= bitCnter + 1; -- passer au bit suivant
        when "01" => bitCnter <= (others => '0');     -- dernier bit terminé
                     adcCnter <= adcCnter + 1;        -- changer d'ADC
        when "11" => allCs <= IDLE;                   -- dernier adc et dernier bit terminés
        when others => null;
        end case;
      end if;
    -----------------------------
    end case;
  end if;
end process allSetSeq;

-------------------------------------------------------------------------------------------------
allSetComb: process (allCs)
begin
    localStart <= '0';
    memWr2     <= '0';
    remote     <= '0';
    case allCs is
    -----------------------------
    when COPY_ROM => memWr2 <= '1'; -- aiguillage des adresses et données rom vers ram
    -----------------------------
    when NOT_STARTED => remote <= '0'; -- valide notamment l'adressage de la mémoire par les compteurs
    -----------------------------
    when IDLE => remote <= '1'; -- par défaut, c'est le slow control qui commande
    -----------------------------
    when LOOPING => localStart <= '1';
                    remote <= '0';
    -----------------------------
    when WAITING => remote <= '0';
    -----------------------------
    end case;
end process allSetComb;

-------------------------------------------------------------------------------------------------
-- Machine d'état mise en place d'un délai individuel (clk ou 1 bit de donnée)

singleSetSeq: process (reset, clk)
begin
  if reset = '1' then
    delCs   <= IDLE;
    counter <= (others => '0');
  elsif rising_edge(clk) then
    case delCs is
    ---------------------------
    when IDLE =>
      if remoteStart = '1' or localStart = '1' then
        counter <= delCnt; -- charger le compteur. source sélectionnée grâce au signal remote
        delCs   <= RAZ;
      end if;
    ---------------------------
    when RAZ  =>
      if counter = 0 then
        delCs <= IDLE;
      else
        delCs <= INC;
      end if;
    ---------------------------
    when INC =>
      counter <= counter - 1;
      if counter = 1 then
        delCs <= IDLE;
      end if;
    ---------------------------
    end case;
  end if;
end process singleSetSeq;

-------------------------------------------------------------------------------------------------
singleSetComb: process (delCs)
begin
  alignBusInternal.rst <= '0';
  alignBusInternal.inc <= '0';
  alignBusInternal.ce  <= '0';
  case delCs is
  ----------------------------------
  when IDLE =>  singleBusy   <= '0';
  ----------------------------------
  when RAZ  =>  alignBusInternal.ce  <= '1';
                alignBusInternal.rst <= '1';
                singleBusy   <= '1';
  ----------------------------------
  when INC  =>  alignBusInternal.ce  <= '1';  
                alignBusInternal.inc <= '1';
                singleBusy   <= '1';
  ----------------------------------
  end case;
end process singleSetComb;
  
-------------------------------------------------------------------------------------------------
regLoad: process (clk, reset, slowCtBus)

variable decod : std_logic;

begin
  if slowCtBus.addr(SC_TOP downto DEL_AD_BITS) = ALIGNER_MEM(SC_TOP downto DEL_AD_BITS)
  then decod := '1';
  else decod := '0';
  end if;
  
  if reset = '1' then
    ramAddrIn <= (others => '0');
    ramDataIn <= (others => '0');
    delays <= (others => '0');
    
    adcNr  <= (others => '0');
    bitNr  <= (others => '0');
    memWr1 <= '0';
    remoteStart   <= '0';
  elsif rising_edge(clk) then
    memWr1 <= '0';
    slowCtBusRd <= (others => '0');
    remoteStart   <= '0';
    ramAddrIn <= romAddr; -- par défaut, prêt pour une copie rom --> ram
    ramDataIn <= romData; -- idem
    if slowCtBus.wr = '1' and decod = '1' then
      memWr1    <= '1';
      ramAddrIn <= slowCtBus.addr(DEL_AD_BITS-1 downto 0);
      ramDataIn(7 downto 6) <= "00"; -- indicateur 'écriture manuelle'
      ramDataIn(5 downto 0) <= slowCtBus.data(5 downto 0);
      delays    <= slowCtBus.data(5 downto 0);
      adcNr     <= slowCtBus.addr(6 downto 4);
      bitNr     <= slowCtBus.addr(3 downto 0);
      remoteStart <= '1';
    elsif slowCtBus.wr = '1' and slowCtBus.addr = DELAY_INSPECT then
      inspectReg <= slowCtBus.data(6 downto 0);
    elsif slowCtBus.rd = '1' and decod = '1' then
      slowCtBusRd( 7 downto 0) <= ramDataOut;
    end if;
  end if;
end process;

end Behavioral;
