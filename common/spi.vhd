----------------------------------------------------------------------------------
-- Company: IPN Orsay
-- Engineer: Pierre EDELBRUCK
-- 
-- Create Date:    14:38:30 07/23/2010 
-- Design Name:    telescope
-- Module Name:    SpiAdc - Behavioral 
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions:  ise
-- Description:
-- Module d'interface spi entre slowcontrol et ADCs (sérialisateur désérialisateur)
-- Sert à la fois pour les ADC Linear et les Intersil.
--
-- Dependencies: tel_defs.vhd, align_defs.fhd
--
-- Revision: 1.0  11:00:00 28/7/2010
----0----|----1----|----2----|----3----|----4----|----5----|----6----|----7----|----8----|----9--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;
use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;

--library fazia;
--use fazia.slow_ct_defs.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;
-------------------------------------------------------------------------------------------------
entity SpiAdc is
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    ---
    slowCtBus   : in  slowCtBusRec;
    slowCtBusRd : out std_logic_vector (15 downto 0);
    ---
    adcNr       : out std_logic_vector (2 downto 0);  -- N° d'ADC
    cs          : out std_logic;
    sClk        : out std_logic;
    sdi         : out std_logic; -- on va toujours travailler en mode 4 fils
    sdo         : in  std_logic  -- attention, i et o vu du périphérique
  );
end SpiAdc;
-------------------------------------------------------------------------------------------------
architecture Behavioral of SpiAdc is

component spi_adc_rom
	port (
	a:   in  std_logic_vector( 3 downto 0);
	spo: out std_logic_vector(31 downto 0));
end component;

attribute box_type : string;
attribute box_type of spi_adc_rom : component is "black_box";

constant CK_WIDTH_WR : integer := 3; -- petite valeur pour accélérer le test bench
constant CK_WIDTH_RD : integer := 5; -- petite valeur pour accélérer le test bench

-- les signaux de commande et de status (mémorisés)
signal spiType  : std_logic; -- 0 = LTC 2260 - 1 = KAD 5514
signal rdWr_n   : std_logic; -- 0 = write - 1 = read
signal adcNrReg : std_logic_vector (2 downto 0);  -- N° d'ADC
signal done     : std_logic;
signal decod    : std_logic;

-- le compteur de bits
signal bitCnt      : std_logic_vector (4 downto 0); -- 16 bits pour LTC, 24 bits pour KAD
signal bitCntReset : std_logic;
signal bitCntInc   : std_logic;

-- le compteur de largeur de clock
signal timerCnt      : std_logic_vector (5 downto 0); -- 6 bits = 640 ns
signal timerCntReset : std_logic;
signal timerCntInc   : std_logic;

-- le registre à décalage d'entrée depuis le périphérique
signal shiftIn    : std_logic_vector (7 downto 0);
signal capture    : std_logic;

-- le registre à décalage de sortie
signal srAddr, srData : std_logic_vector (15 downto 0); -- les données pour le chargement
signal shiftReg   : std_logic_vector (23 downto 0);
signal romLd : std_logic; -- ordre de chargement depuis la ROM
signal shiftLeft  : std_logic; -- ordre de décalage à gauche

-- la rom d'initialisation
signal romAddr : std_logic_vector ( 3 downto 0);
signal romData : std_logic_vector (31 downto 0);

-- la machine d'initialisation
type InitState is (IDLE, START, LOOPING, TEST_END);
signal initCs : InitState := IDLE;

-- la machine d'état du sérialisateur
type SpiState is (IDLE, WAIT_LOW, WAIT_HIGH);
signal spiCs, spiFs : SpiState := IDLE;

--==============================================================================================
begin

memoireRom: spi_adc_rom
port map (
  a   => romAddr,
  spo => romData
);

-- câblage statique ----------------------------------------------------------------------------
adcNr <= adcNrReg;
sdi   <= shiftReg(23);

decod <= '1' when (slowCtBus.addr(15 downto  8) = SPI_ADC_WR(0)(15 downto  8) or
                   slowCtBus.addr(15 downto  8) = SPI_ADC_WR(1)(15 downto  8) or
                   slowCtBus.addr(15 downto  8) = SPI_ADC_WR(2)(15 downto  8) or
                   slowCtBus.addr(15 downto  8) = SPI_ADC_WR(3)(15 downto  8) or
                   slowCtBus.addr(15 downto  8) = SPI_ADC_WR(4)(15 downto  8) or
                   slowCtBus.addr(15 downto  8) = SPI_ADC_WR(5)(15 downto  8))
              else '0';

srAddr <= slowCtBus.addr when decod = '1' else romData(31 downto 16);
srData <= slowCtBus.data when decod = '1' else romData(15 downto 0);

-- décodage et lecture du registre spi d'entrée
-- nb. pour lire, il faut avoir au préalable passé un ordre de lecture et attendu
-- le temps de la désérialisation
slowCtBusRd <= "0000000" & done & shiftIn
                  when slowCtBus.rd = '1' and slowCtBus.addr = SPI_READ
                  else (others => '0');

-------------------------------------------------------------------------------------------------
-- initialisation automatique des ADC au reset par lecture de la ROM
initAllSeq: process (reset, clk)
begin
  if reset = '1' then
    romAddr <= (others => '0');
    initCs <= START;
  elsif rising_edge(clk) then
    case initCs is
    ---------------------
    when IDLE => null;
    ---------------------
    -- dans cet état, romLd = '1' et le sérialisateur se déclenche
    -- voir spi_comb
    when START => -- attente retombée du done
      if done = '0' then
        initCs <= LOOPING;
      end if;
    ---------------------
    when LOOPING =>
      if done = '1' then
        romAddr <= romAddr+1;
        initCs <= TEST_END;
      end if;
    ---------------------
    when TEST_END =>
      if romData(31) = '1' then -- détection de la sentinelle
        initCs <= IDLE;
      else
        initCs <= START;
      end if;
    ---------------------
    end case;
  end if;
end process initAllSeq;

----------------------------------------------
initAllComb: process (initCs)
begin
  romLd <= '0';
  case initCs is
  when IDLE     => null;
  when START    => romLd <= '1';
  when LOOPING  => null;
  when TEST_END => null;
  end case;
end process initAllComb;

-------------------------------------------------------------------------------------------------
-- gestion du registre à décalage (chargement/décalage)  ----------------------------------------
-- données sur 8 bit, N° de registre sur partie basse de l'adresse
-- slowCtBus.data(9) = KAD/LTC*  (8) = R/W*  (7 downto 0) = data

shiftRegProc: process (clk)
begin
  if rising_edge(clk) then
    if (slowCtBus.wr = '1' and decod = '1') or romLd = '1' then
      spiType  <= srData(9);
      rdWr_n   <= srData(8);
      adcNrReg <= srAddr(10 downto 8);
      if srData(9) = LTC then
        -- 16 bits utiles pour le LTC, cadrés à gauche
        shiftReg(23 downto 16) <= '0' & srAddr (6 downto 0);  -- wr + adresse intra_adc
        shiftReg(15 downto 0)  <= srData(7 downto 0) & x"00"; -- la donnée en écriture
      else-- type KAD 5514
        shiftReg(23 downto 21) <= '0' & "00"; -- bits W1-W0 = 00 (bytes transfered = 1)
        shiftReg(20 downto  8) <= "00000" & srAddr(7 downto 0);  -- adr longue pr un KAD
        shiftReg (7 downto  0) <= srData(7 downto 0);            -- la donnée en écriture
      end if;
    end if;  -- fin de décodage write
    if shiftLeft = '1' then shiftReg <= shiftReg(22 downto 0) & '0'; end if;
  end if;    -- fin rising_edge(clk)
end process shiftRegProc;

-- les registres et les compteurs ---------------------------------------------------------------
reg_et_cpt: process (reset, clk)
begin
  if reset = '1' then
    bitCnt   <= (others => '0');
    timerCnt <= (others => '0');
    shiftIn  <= (others => '0');
  elsif rising_edge(clk) then
    
    if timerCntReset  = '1' then timerCnt <= (others => '0'); -- reset prioritaire
    elsif timerCntInc = '1' then timerCnt <= timerCnt+1; end if;
    
    if bitCntReset    = '1' then bitCnt   <= (others => '0');
    elsif bitCntInc   = '1' then bitCnt <= bitCnt + 1; end if;
    
    if capture = '1' then shiftIn <= shiftIn(6 downto 0) & sdo; end if;
  end if;
end process reg_et_cpt;

-------------------------------------------------------------------------------------------------
-- la machine d'état du sérialisateur
spi_seq: process (reset, clk)
begin
  if reset = '1' then
    spiCs <= IDLE;
  elsif rising_edge(clk) then
    spiCs <= spiFs;
  end if;
end process spi_seq;
-------------------------------------------------------------------------------------------------
spi_comb: process (spiCs, timerCnt, bitCnt, slowCtBus.wr, decod, rdWr_n, spiType, romLd)
begin
  -- les valeurs par défaut
  spiFs         <= spiCs;
  shiftLeft     <= '0';
  bitCntReset   <= '0';
  bitCntInc     <= '0';
  timerCntReset <= '0';
  timerCntInc   <= '0';
  done          <= '0'; -- sauf IDLE
  sClk          <= '0';
  capture       <= '0';
  cs            <= '1'; -- sauf IDLE
  
  case spiCs is
    --------------------------------------------------------
    when IDLE =>
      done <= '1';
      cs <= '0';
      if (slowCtBus.wr = '1' and decod = '1') or romLd = '1' then
        timerCntReset <= '1';
		    bitCntReset <= '1';
        spiFs <= WAIT_LOW;
      end if;
    --------------------------------------------------------
    when WAIT_LOW =>
      timerCntInc <='1';
      if ((rdWr_n='0' and timerCnt = CK_WIDTH_WR-1) or
          (rdWr_n='1' and timerCnt = CK_WIDTH_RD-1)) then
        timerCntReset <= '1';
        if (spiType = LTC and bitCnt = 16) or
           (spiType = KAD and bitCnt = 24) then
          spiFs <= IDLE;
        else
          timerCntReset <= '1';
          if rdWr_n = '1' then capture <= '1'; end if;
          spiFs <= WAIT_HIGH;
        end if;
      end if;
    --------------------------------------------------------
    when WAIT_HIGH =>
      timerCntInc <= '1';
      sClk <='1';
      if ((rdWr_n='0' and timerCnt = CK_WIDTH_WR-1) or
          (rdWr_n='1' and timerCnt = CK_WIDTH_RD-1)) then
        bitCntInc <= '1';
        shiftLeft <= '1';
        timerCntReset <= '1';
        spiFs <= WAIT_LOW;
      end if;        
    --------------------------------------------------------
  end case;
end process spi_comb;
end Behavioral;

