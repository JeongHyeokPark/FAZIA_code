-------------------------------------------------------------------------------------------------
-- Company:  IPN Orsay
-- Engineer: Pierre EDELBRUCK
-- 
-- Create Date:    22/03/2012
--
-- Project Name:   fazia
-- Design Name:    telescope
-- Module Name:    Histogrammer - Behavioral 
-- Target Devices: virtex-5
-- Tool versions:  ISE 12.4
-- Company: IPN Orsay
-- Engineer: Pierre EDELBRUCK
-- Description: 
---------------
-- Module d'histogrammage en temps réel. Largeur histogramme = 1024 bins
-- Compteurs 24 bits (capacité 1.9 jours @ 100 Hz). Données d'entrée sur 24 bits. 
-- Origine et largeur de bin programmables.
-- Revision: 
-- Additional Comments: 
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;

--===============================================================================================
entity Histogrammer is
  generic (
    RegAd   : std_logic_vector(SC_TOP downto 0);
    HistoAd : std_logic_vector(SC_TOP downto 0)
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    ---
    dataIn      : in  std_logic_vector (23 downto 0);
    fire        : in  std_logic;
    ---
    slowCtBus   : in  slowCtBusRec;
    SlowCtBusRd : out std_logic_vector (SC_TOP downto 0)
  );
end histogrammer;

--===============================================================================================
architecture Behavioral of Histogrammer is

--=== paramétrage ===============================================================================
constant DATA_WIDTH : integer := 24; -- la même taille que dataIn
constant DEPTH      : integer := 1024;
constant AD_BITS    : integer := bits(DEPTH);
constant CNTER_BITS : integer := 24;

-- signaux ======================================================================================
signal adMem     : std_logic_vector (AD_BITS-1 downto 0);
signal dina, doutb : std_logic_vector (CNTER_BITS-1 downto 0);
signal donnee   : std_logic_vector (DATA_WIDTH-1 downto 0);
signal oldFire  : std_logic;
signal offset   : std_logic_vector (DATA_WIDTH-1 downto 0); -- registre
signal binning, diviseur : std_logic_vector (4 downto 0);  -- binning est un registre
signal memWrite : std_logic;
signal decodMem, decodMemLate, adbit0 : std_logic;
signal regRdBus : std_logic_vector (SC_TOP downto 0);
signal clearMem : std_logic;

type HistoState is (IDLE, START, DIVIDE, READ_BIN, WRITE_BIN, RAZ_MEM);
signal histoCs : HistoState;

-- composants ===================================================================================
component ram_1kx24
	port (
	clka : in  std_logic;
	wea  : in  std_logic_vector (0 downto 0);
  ---
	addra: in  std_logic_vector (9 downto 0);
	dina : in  std_logic_vector(DATA_WIDTH-1 downto 0);
  ---
	clkb : in  std_logic;
	addrb: in  std_logic_vector (9 downto 0);
	doutb: out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end component;

attribute box_type : string;
attribute box_type of ram_1kx24 : component is "black_box";

--===== chipscope =============================================================================
--signal all_zero_128 : std_logic_vector (127 downto 0) := (others => '0');
--signal etat : std_logic_vector (2 downto 0);
--
--signal CONTROL0 : std_logic_vector (35 downto 0);

--component tel_ila
--  PORT (
--    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
--    CLK     : IN STD_LOGIC;
--    TRIG0   : IN STD_LOGIC_VECTOR(  127 DOWNTO 0)
--  );
--end component;
--
--component tel_icon
--  PORT (
--    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
--end component;

--===============================================================================================
begin
--===== chipscope ===============================================================================
--mon_chip_scope: if Regad = Q2_SC generate
--mon_icon : tel_icon
--  port map (
--    CONTROL0 => CONTROL0);
--
--mes_sondes : tel_ila
--  port map (
--    CONTROL => CONTROL0,
--    CLK     => clk,
--    ---
--    TRIG0 (0) => reset,
--    TRIG0 (1) => fire,
--    TRIG0 (2) => clearMem,
--    TRIG0 (5  downto 3)    => etat,
--    TRIG0 (15 downto 6)  => adMem,
--    TRIG0 (39 downto 16) => dina,
--    TRIG0 (63 downto 40) => doutb,
--    TRIG0 (87 downto 64)  => donnee,
--    Trig0 (92 downto 88)  => diviseur,
--    Trig0 (93) => decodMem,
--    TRIG0 (127 downto 94) => all_zero_128(127 downto 94)
-- );
--etat <= conv_std_logic_vector(HistoState'pos(histoCs), 3);
--end generate;
--===============================================================================================

memoire : ram_1kx24
  port map (
    clka   => clk,
    wea(0) => memWrite,
    ---
    addra  => donnee(AD_BITS-1 downto 0),
    dina   => dina,
    ---
    clkb   => clk,
    addrb  => adMem,
    doutb  => doutb
  );
  
-- 15 à 11 (il y a 2 mots de 16 bits par position mémoire
decodMem <= '1' when (slowCtBus.addr(SC_TOP downto AD_BITS+1) = HistoAd (SC_TOP downto AD_BITS+1))
                      and slowCtBus.rd = '1' else '0';
                      
adMem <= slowCtBus.addr(AD_BITS downto 1) when decodMem = '1' else donnee(AD_BITS-1 downto 0);
  
--===============================================================================================
--    Machine d'état
-- lire la donnée
-- soustraire l'offset
-- diviser (décaler) le résultat --> donne l'adresse mémoire
-- lire le compteur (s'assurer que le SC n'est pas en train de lire)
-- l'incrémenter et le réécrire
--===============================================================================================

histoSeq: process (reset, clk)
begin
  if reset = '1' then
    oldFire  <= '0';
    histoCs  <= IDLE;
    memWrite <= '0';
    dina     <= (others => '0');
    donnee   <= (others => '0');
    diviseur <= (others => '0');
  elsif rising_edge(clk) then
    oldFire   <= fire;
    case histoCs is
    ----------------------------
    when IDLE => -- 0
      memWrite <= '0';
      if fire = '1' and oldFire = '0' then
        donnee   <= dataIn;
        diviseur <= binning; -- diviseur est le compteur de décalage et binning le registre
        histoCs  <= START;   --                                                 programmé par SC
      elsif clearMem = '1' then
        dina     <= (others => '0'); -- l'entrée de la mémoire
        donnee   <= (others => '0'); -- les adresses
        memWrite <= '1';
        histoCs  <= RAZ_MEM;
      end if;
    ----------------------------
    when START => -- 1 calcul origine de l'histogramme
      donnee <= donnee - offset;
      histoCs <= DIVIDE;
    ----------------------------
    when DIVIDE => -- 2 mise à l'échelle
      if diviseur = 0 then
        histoCs <= READ_BIN;
      else
        donnee   <= '0' & donnee (DATA_WIDTH-1 downto 1); -- diviser par 2
        diviseur <= diviseur - 1;
      end if;
    ----------------------------
    when READ_BIN => -- 3 port de lecture libre ?
      if donnee >= DEPTH then
        histoCs <= IDLE; -- si data hors gamme
      elsif decodMem = '0' and decodMemLate = '0' then -- vérifier que l'accès en lecture est libre
        dina <= doutb+1;       -- sinon, attendre
        histoCs <= WRITE_BIN;
      end if;
    ----------------------------
    when WRITE_BIN => -- 4 lecture du bin actuel
      memWrite <= '1';        -- écrire. il n'y a pas de compétition avec le slow control
      histoCs  <= IDLE;       --                                                 sur ce port
    ----------------------------
    when RAZ_MEM => -- 5
      if donnee(AD_BITS) = '1' then
        histoCs  <= IDLE;
      else
        donnee <= donnee + 1;
      end if;
    ----------------------------
    end case;
  end if;
end process histoSeq;

------------------------------------
--histoComb: process (histoCs)
--
--begin
--
--end process histoComb;
      
--===============================================================================================

--slowCtBusRd <=
--  regRdBus
--  or
--  (ALL_ZERO(15 downto CNTER_BITS-16) & doutb(CNTER_BITS-1 downto 16)
--    when decodMemLate = '1' and adbit0 = '0' else
--  doutb(15 downto 0)
--    when decodMemLate = '1' and adbit0 = '1') else
--  (others => '0')
--  );
  
-------------------------------------------------------------------------------------------------
showReg: process (regRdBus, doutb, decodMemLate, adbit0)
begin
  if decodMemLate = '1' and adbit0 = '0' then
    slowCtBusRd <= ALL_ZERO(15 downto CNTER_BITS-16) & doutb(CNTER_BITS-1 downto 16);
  elsif decodMemLate = '1' and adbit0 = '1' then
    slowCtBusRd <= doutb(15 downto 0);
  else
    slowCtBusRd <= regRdBus;
  end if;
end process;

-------------------------------------------------------------------------------------------------
regLoad: process (clk, reset, slowCtBus)
variable decod : std_logic;
variable lowerField : std_logic_vector(LEV_EN_FLD-1 downto 0); -- pour faciliter le décodage

begin
  if slowCtBus.addr(SC_AD_WIDTH-1 downto LEV_EN_FLD) = RegAd(SC_AD_WIDTH-1 downto LEV_EN_FLD)
  then decod := '1';
  else decod := '0';
  end if;
  lowerField := slowCtBus.addr(LEV_EN_FLD-1 downto 0);
  
  if reset = '1' then
    offset  <= (others => '0');
    binning <= (others => '0');
  elsif rising_edge(clk) then
    regRdBus <= (others => '0'); -- regRdBus est un registre
    adbit0 <= slowCtBus.addr(0); -- se souvenir du bit 0 pour le choix partie haute/basse au
    decodMemLate <= decodMem;    --                moment de la mise sur le bus au clock suivant
    clearMem     <= '0';
    if slowCtBus.wr = '1' and decod = '1' then
      case lowerField is
      when HISTO_CTRL  => clearMem <= '1';
      when HISTO_BIN   => binning <= slowCtBus.data(4 downto 0);
      when HISTO_OFFSET_H => offset (DATA_WIDTH-1 downto 16) <= slowCtBus.data(DATA_WIDTH-17 downto 0);
      when HISTO_OFFSET_L => offset (15 downto 0) <= slowCtBus.data;
      when others => null;
      end case;
    elsif slowCtBus.rd = '1' and decod = '1' then
      case lowerField is
      when HISTO_BIN      => regRdBus(4 downto 0) <= binning;
      when HISTO_OFFSET_H => regRdBus(DATA_WIDTH-17 downto 0) <= offset (DATA_WIDTH-1 downto 16);
      when HISTO_OFFSET_L => regRdBus <= offset (15 downto 0);
      when others => null;
      end case;
    end if;
  end if;
end process regLoad;

end Behavioral;

