--	Package File Template
--
--	Purpose: This package defines supplemental types, subtypes, 
--		 constants, and functions 

library IEEE;
use IEEE.STD_LOGIC_1164.all;

package align_defs is
--===============================================================================================
constant ADCS_TOTAL : integer := 6; -- le nombre total d'adcs de toutes espèces

-- bus d'alignement: de adc_mon vers les demux
-- le retour des données issues des demux n'est pas inclus
type AlignBusRec is
  record
    -- adressage du bit à programmer (a destination du retard contrôlé)
    adc_adr    : std_logic_vector (2 downto 0);
    bit_nr     : std_logic_vector (3 downto 0); -- 0..7 = data, 8 = clk, 15 = broadcast (tous les bits)
    -- adressage du bit à inspecter
    adc_inspect: std_logic_vector (2 downto 0);
	  inspect_nr : std_logic_vector (3 downto 0); -- 0..7 = data, 8 = clk
    ---
    mode       : std_logic_vector (1 downto 0);
    ce         : std_logic;  -- count enable
    inc        : std_logic;  -- '0' = decrement ,  '1' = increment
    rst        : std_logic;  -- reset delay
  end record;

-- le N° du bit de contrôle vers le module spi (data(9))
constant ClockDelayBit : integer := 9;
constant LTC : std_logic := '0';
constant KAD : std_logic := '1';
-- codes de mode (utilisés par ddr_adc)
constant SHOW_DATA_BIT : std_logic_vector (1 downto 0) := "00"; -- fournir le bit de data
constant SHOW_SYS_CLK  : std_logic_vector (1 downto 0) := "01"; -- fournir sys_clk échantillonné
                                                                --  par l'horloge ADC
-------------------------------------------------------------------------------------------------
type SpiBus is
  record
    cs_n     : std_logic; -- chip select
    sck      : std_logic; -- horloge
    sdi      : std_logic; -- vers le périphérique
    sdo      : std_logic; -- depuis le périphérique
  end record;
  
type SpiBusVector is array (natural range <>) of SpiBus;
-- largeur du bus d'adresse de la mémoire de status (32 mots de 16 bits)
constant STAT_MEM_AD_WIDTH : integer := 6; -- 64 mots de 16 bits


end align_defs;
