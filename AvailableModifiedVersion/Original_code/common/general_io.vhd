----------------------------------------------------------------------------------
-- Company:  IPN Orsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:    16:45:13 10/26/2010 
-- Design Name:    telescope
-- Module Name:    general_io - Behavioral 
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions:  ise-11.1
-- Description: EntrÃ©es-sorties gÃ©nÃ©rales destnÃ©es notamment au DAC de
-- visualisation des signaux. GÃ¨re Ã©galement les LEDs et le numÃ©ro de version.
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;
use work.telescope_conf.all;
use work.tel_defs.all;
use work.slow_ct_defs.all;

--library fazia;
--use fazia.slow_ct_defs.all;

----------------------------------------------------------------------------------
entity GeneralIo is
  generic (
    regAd : std_logic_vector(SC_AD_WIDTH-1 downto 0) -- adresse absolue du bloc
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    clear       : out std_logic;  -- reset soft, généré par le slow control et détecté ici
    resetSoft   : out std_logic;  -- provoque un reset général comme le bouton poussoir
    alignFromSc : out std_logic;
    blkBusyFromSc : out std_logic; -- permet de simuler une occupation permanente de la carte block
    ---
    idFpga      : in std_logic;
--    genIo       : out std_logic_vector (15 downto 0);
--    ckIo_n      : out std_logic;
--    ckIo_p      : out std_logic;
    ---
    rougeIn     : in  std_logic; -- les entrées led (aiguillée vers led si quartet = 3)
    verteIn     : in  std_logic;
    jauneIn     : in  std_logic;
    bleueIn     : in  std_logic;
    ---
    ledRouge    : out std_logic; -- les leds physique
    ledVerte    : out std_logic;
    ledJaune    : out std_logic;
    ledBleue    : out std_logic;
    ---
    telIdPort  : out std_logic_vector (3 downto 0);  -- numéro de télescope (0 à 15)
    valExt      : out std_logic; -- flag indiquant d'où provient le signal glt
    ---
    microsec    : out std_logic; -- signal à 1 MHz rapport cyclique = 50 %
    millisec    : out std_logic; -- signal à 1 kHz rapport cyclique = 50 %
    ---
    fastDacOut  : out std_logic_vector (ADC_TOP downto 0);
    ---
    slowCtBus   : in  SlowCtBusRec;
    slowCtBusRd : out std_logic_vector (15 downto 0)
  );
end GeneralIo;

--================================================================================
architecture Behavioral of GeneralIo is

constant DEMI_CLIG : integer := 100; -- demi-période clignotant en ms (période 200 ms)

-- le registre de contrôle des LEDs
-- chaque led sur un quartet. Code des quartets:
-- 0: led forcée à zéro, 1:  led forcée à 1, 2: led = clignote.
signal leds_reg : std_logic_vector (15 downto 0);
signal telId    : std_logic_vector (3 downto 0);

-- la base de temps. elle fournit µs, ms, s
signal halfUsec   : std_logic_vector(5 downto 0);
signal fiveUsec   : std_logic_vector(3 downto 0); -- compteur 5 µs
signal halfMsec   : std_logic_vector(8 downto 0);
--signal halfSec    : std_logic_vector(8 downto 0);
signal clignoteur : std_logic_vector(9 downto 0); -- jusqu'à 1024 ms
signal redOld, greenOld, yellowOld, blueOld : std_logic;
signal usec, msec, oldMs, clignotant : std_logic;
signal geneOnOff  : std_logic;
signal isoCnt     : std_logic_vector(ADC_TOP downto 0); -- compteur pour géné de signal isocèle
signal up : std_logic;
signal configReg : std_logic_vector(15 downto 0);
signal vhdlAorB : std_logic;
signal alignezMoi : std_logic; -- signal de commande du timer d'alignement des FastLink
signal timer : std_logic_vector(8 downto 0); -- assez pour 511 ms

begin
identA:if build_a generate
  vhdlAorB <= '0';
end generate;

identB:if not build_a generate
  vhdlAorB <= '1';
end generate;
----------------------------------------------------------------------------------
-- base de temps générant des signaux de période 1 µs, 1 mS, 1 s ayant
-- un rapport cyclique de pile 0.5

millisec  <= msec;
microsec  <= usec;

fastDacOut(ADC_TOP-1 downto 0) <= not isoCnt(ADC_TOP-1 downto 0) when geneOnOff = '1' else (others => '0');
fastDacOut(ADC_TOP)            <= isoCnt(ADC_TOP)                when geneOnOff = '1' else '0';

scaler: process (clk, reset, halfUsec, halfMsec, telId)
variable cyUsec, cyMsec, cySec : std_logic;

-------------------------------------------------------------------------------------------------
begin
  telIdPort <= telId;
  blkBusyFromSc <= configReg(BLK_BUSY_FORCE);
  
  if halfUsec =  49 then cyUsec := '1'; else cyUsec := '0'; end if; -- every 500 ns pile
  if halfMsec = 499 then cyMsec := '1'; else cyMsec := '0'; end if;
--  if halfSec  = 499 then cySec  := '1'; else cySec  := '0'; end if;
  
  if reset = '1' then
    usec <= '0';
    msec <= '0';
    --sec  <= '0';
    clignotant <= '0';
    halfUsec <= (others => '0');
    halfMSec <= (others => '0');
--    halfSec  <= (others => '0');
    clignoteur <= (others => '0');
  elsif rising_edge(clk) then
    -- compteur modulo 0.5 µs
    if cyUsec = '1' then
      halfUsec <= (others => '0');
      usec     <= not usec;
    else
      halfUsec <= halfUsec + 1;
    end if;
    -- compteur modulo 0.5 ms
    if cyUsec = '1' and usec = '1' then
      if cyMsec = '1' then
        halfMsec <= (others => '0');
        msec     <= not msec;
      else
        halfMsec <= halfMsec + 1;
      end if;
    end if;
    -- compteur modulo 0.5 s
--    if cyUsec = '1' and usec = '1' and cyMsec = '1' and msec = '1' then
--      if cySec = '1' then
--        halfSec <= (others => '0');
--        sec     <= not sec;
--      else
--        halfSec <= halfSec + 1;
--      end if;
--    end if;
    -- compteur modulo 2 x DEMI_CLIG -> clignotant
    if cyUsec = '1' and usec = '1' and cyMsec = '1' and msec = '1' then
      if clignoteur =  DEMI_CLIG -1 then
        clignoteur <= (others => '0');
        clignotant <= not clignotant;
      else
        clignoteur  <= clignoteur + 1;
      end if;
    end if; 
  end if;
end process scaler;

----------------------------------------------------------------------------------
isoProc: process(reset, clk) -- générateur de signaux isocèles
begin
  if reset = '1' then
    up <= '0';
    isoCnt <= (others => '0');
  elsif rising_edge(clk) then
    if up = '1' then
      isoCnt <= isoCnt + 1;
      if isoCnt = "11111111111110" then
        up <= '0';
      end if;
    else
      isoCnt <= isoCnt - 1;
      if isoCnt = "00000000000001" then
        up <= '1';
      end if;
    end if;
  end if;
end process;

-- attention, les leds sont inversées en step_2 vs step_1 (MOS supprimé)
with leds_reg( 3 downto 0) select ledBleue <=       '0'  when x"1",
				                                     clignotant  when X"2",
                                             not bleueIn     when X"3",
				                                            '1'  when others;
with leds_reg( 7 downto 4) select ledJaune <=       '0'  when x"1",
				                                     clignotant  when X"2",
                                             not jauneIn     when X"3",
				                                            '1'  when others;
with leds_reg(11 downto 8) select ledVerte <=       '0'  when x"1",
				                                     clignotant  when X"2",
                                             not verteIn     when X"3",
				                                            '1'  when others;
with leds_reg(15 downto 12) select ledRouge <=      '0'  when x"1",
				                                     clignotant  when X"2",
                                             not rougeIn     when X"3",
				                                            '1'  when others;

valExt    <= configReg(GLT_SEL);
resetSoft <= configReg(RESET_FROM_PIC); -- provoque un reset général comme le bouton poussoir

--- génération de l'impulsion d'alignement commandée par slow control -------------------------
alignProc: process (clk, reset)
begin
  if reset = '1' then
    alignFromSc <= '0';
  elsif rising_edge(clk) then
    oldMs <= msec;
    if alignezMoi = '1' then
      timer <= conv_std_logic_vector(300, 9); -- 300 ms
      alignFromSc <= '1';
    end if;
    if msec = '1' and oldMS = '0' then
      if timer /= 0 then
        timer <= timer - 1;
      else
        alignFromSc <= '0';
      end if;
    end if;
  end if;
end process;
                                            
--- gestion du bus ----------------------------------------------------------------------------
regLoad: process (clk, reset, idFpga, slowCtBus)
variable decod : std_logic;
variable initConfig : std_logic_vector(15 downto 0) := (others => '0');
begin
  initConfig(GLT_SEL) := VAL_EXT;
  -- chip-select du module
  if slowCtBus.addr(SC_AD_WIDTH-1 downto GIO_FIELD)
          = RegAd(SC_AD_WIDTH-1 downto GIO_FIELD) then
    decod := '1';
  else
    decod := '0';
  end if;
  
  if reset = '1' then
--    configReg(GLT_SEL) <= VAL_EXT; -- sélection global trigger externe/interne
    configReg <= initConfig;
    -- RVJB
    if idFpga = '0' then
      leds_reg <= X"3320"; -- val-led rouge + lt-led verte + jaune clignotante
    else
      leds_reg <= X"3302"; -- val-led rouge + lt-led verte + bleue clignotante
    end if;
    geneOnOff <= '0';
    -- Pas de RAZ de telId. La valeur programmée par le PIC survit à un reset FPGA
    --telId <= "000" & idFpga; -- par défaut mais peut être réécrit par le SC
  elsif rising_edge(clk) then
    alignezMoi <= '0';
    slowCtBusRd <= (others => '0');
    clear <= '0';
    if decod = '1' then
      if slowCtBus.wr = '1' then ---------------------------------------------------------
        case slowCtBus.addr(GIO_FIELD-1 downto 0) is
          when AD_LED_MPX => -- leds_reg <= slowCtBus.data;
            if slowCtBus.data(3 downto 0) /= "1111" then -- "1111" = no change
              leds_reg(3 downto 0) <= slowCtBus.data(3 downto 0);
            end if;
            if slowCtBus.data(7 downto 4) /= "1111" then
              leds_reg(7 downto 4) <= slowCtBus.data(7 downto 4);
            end if;
            if slowCtBus.data(11 downto 8) /= "1111" then
              leds_reg(11 downto 8) <= slowCtBus.data(11 downto 8);
            end if;
            if slowCtBus.data(15 downto 12) /= "1111" then
              leds_reg(15 downto 12) <= slowCtBus.data(15 downto 12);
            end if;
          when AD_DETGID => telId <= slowCtBus.data(3 downto 0);
          when AD_CONFIG =>
            if slowCtBus.data(CLEAR_BIT) = '1' then
              clear <= '1'; -- bit fugitif (1 coup de clk)
            elsif slowCtBus.data(ALIGNEMENT) = '1' then
              alignezMoi <= '1'; -- 1 seul clk
            else
              configReg <= slowCtBus.data;
            end if;
          when others => null;
        end case;        
      elsif slowCtBus.rd = '1' then ------------------------------------------------------
        case slowCtBus.addr(GIO_FIELD-1 downto 0) is
          when AD_VERS    => slowCtBusRd <= vhdlAorB & VERSION_VHDL(14 downto 0);
          when AD_LED_MPX => slowCtBusRd <= leds_reg;
          when AD_DETGID  => slowCtBusRd <= b"0000_0000_0000" & telId;
          when AD_CONFIG  => slowCtBusRd <= configReg;
                             configReg(RED_FLAG downto BLUE_FLAG) <= (others => '0');
          when others  => null;
        end case;
      end if;
    elsif slowCtBus.wr = '1' and
          slowCtBus.addr(SC_TOP downto INSPECT_FIELD) = INSPECT_AD(SC_TOP downto INSPECT_FIELD) then
          if slowCtBus.addr(INSPECT_FIELD-1 downto 0) = GENE_ISOCELE then -- 6
            geneOnOff <= slowCtBus.data(0);
          else
            geneOnOff <= '0';
          end if;
    end if;
    
    -- traitement des flags de LEDs. Chaque flag occupe un bit dans le registre configReg
    -- le flag est mis à '1' si l'entrée correspondante présente un front montant. Les quatre flags
    -- sont remis à zéro lorsque le registre est lu par le slow control.
    
    redOld    <= rougeIn;
    greenOld  <= verteIn;
    yellowOld <= jauneIn;
    blueOld   <= bleueIn;
    
    if rougeIn = '1' and redOld = '0'    then configReg(RED_FLAG) <= '1';    end if;
    if verteIn = '1' and greenOld = '0'  then configReg(GREEN_FLAG) <= '1';  end if;
    if jauneIn = '1' and yellowOld = '0' then configReg(YELLOW_FLAG) <= '1'; end if;
    if bleueIn = '1' and blueOld = '0'   then configReg(BLUE_FLAG) <= '1';   end if;

  end if;
end process regLoad;

--led_out: process(reset, clk)
--	begin
--	if (reset='1') then -- reset asynchrone
--		leds_reg <= X"0021";
--	elsif rising_edge (clk) then
--		if slowCtBus.addr = AD_LED_MPX and slowCtBus.wr = '1' then
--		   -- registre de configuration des leds
--			leds_reg <= slowCtBus.data;
--		elsif slowCtBus.addr = AD_VERS and slowCtBus.rd = '1' then
--		   -- lecture du numéro de version
--			slowCtBusRd <= VERSION_VHDL;
--		end if;
--	end if;
--end process led_out;
--
------------------------------------------------------------------------------------
--genProc: process (clk, reset)
--begin
--  if reset = '1' then
--    genIo <= (others => '0');
--  end if;
--end process;

----------------------------------------------------------------------------------
end Behavioral;

