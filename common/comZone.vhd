-------------------------------------------------------------------------------------------------
-- Company:  IPNO
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:    7/11/2012
-- Design Name: telescope
--===============================================================================================
-- Module Name:                       ===== ComZone =====
--===============================================================================================
-- File:   comZone.vhd
-- Project Name:  Fazia
-- Target Devices: Virtex-5
-- Tool versions: 12.4
-- Description:
--
-- Revision: 
--
--------------------------------------------------------------------------------------------------

LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
--use IEEE.std_logic_arith.ALL;
--use IEEE.std_logic_unsigned.ALL;
library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.slow_ct_defs.all;
use work.telescope_conf.all;

entity comZone is
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    ----------------------------
    letterBox   : out std_logic;
    ----------------------------
    slowCtBus   : in  SlowCtBusRec;
    slowCtBusRd : out std_logic_vector (15 downto 0)
  );
end comZone;

architecture Behavioral of comZone is

component ram_32x16_single_modified
	port (
	DO : out std_logic_vector(15 downto 0);
	ADDR : in std_logic_vector(9 downto 0);
	CLK : in std_logic;
	DI : in std_logic_vector(15 downto 0);
	EN : in std_logic;
	REGCE : in std_logic;
	RST : in std_logic;
	WE : in std_logic_vector(1 downto 0));
end component;

-- Synplicity black box declaration
attribute syn_black_box : boolean;
--attribute syn_black_box of ram_32x16_single_modified: component is true;

signal we         : std_logic;
signal we2 : std_logic_vector(1 downto 0);
signal readLate   : std_logic;
signal ramDataOut : std_logic_vector(15 downto 0);

signal letterBoxLocal : std_logic;
signal slowCtBus_addr1 : std_logic_vector(9 downto 0);
signal en1 : std_logic;
signal regce1 : std_logic;
signal rst1 : std_logic;
--signal ramAddrIn : std_logic_vector(4 downto 0);
--signal ramDataIn : std_logic_vector(15 downto 0);

--===== chipscope =============================================================================
-- recopié/modifié depuis readEngine.vhd

--signal all_zero_64 : std_logic_vector (63 downto 0) := (others => '0');
--signal CONTROL0 : std_logic_vector (35 downto 0);
--
--component tel_ila
--  PORT (
--    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
--    CLK     : IN STD_LOGIC;
--    TRIG0   : IN STD_LOGIC_VECTOR(  63 DOWNTO 0)
--  );
--end component;
--
--component tel_icon
--  PORT (
--    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
--end component;
--===============================================================================================

begin
en1 <= '1';
regce1 <= '0';
rst1 <= '0';
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
--    TRIG0 (0) => reset,
--    TRIG0 (16 downto 1) => slowctBus.addr,
--    TRIG0 (32 downto 17) => slowctBus.data,
--    trig0 (33) => slowctBus.rd,
--    trig0 (34) => slowctBus.wr,
--    trig0 (50 downto 35) => ramDataOut,
--    trig0 (51) => we,
--    trig0 (52) => readLate,
--    trig0 (63 downto 53) => all_zero_64(63 downto 53)
-- );
--===============================================================================================
-- mémoire ---registered--- en entrée, ---non_registered--- en sortie
slowCtBus_addr1 <= "11111" & slowCtBus.addr(4 downto 0);
we2 <= we & we;
maZone : ram_32x16_single_modified
  port map (
    DO => ramDataOut,
	 ADDR => slowCtBus_addr1,
	 CLK => clk,
	 DI => slowCtBus.data,
	 EN => en1,
	 REGCE => regce1,
	 RST => rst1,
	 WE => we2
  );

-----------------------------------------------------------------------------------------------
regLoad: process (clk, reset, slowCtBus)

variable decod : std_logic;

begin

  letterBox <= letterBoxLocal;

  if slowCtBus.addr(SC_TOP downto 5) = COM_ZONE(SC_TOP downto 5)
  then decod := '1';
  else decod := '0';
  end if;
  
  we <= decod and slowCtBus.wr;
  if readLate = '1' then
    slowCtBusRd <= ramDataOut;
  else
    slowCtBusRd <= (others => '0');
  end if;
  
  if rising_edge(clk) then
  
    if reset = '1' then
      letterBoxLocal <= '0';
    end if;
 
    readLate <= '0';
    if decod = '1' and slowCtBus.rd = '1' then
      readLate <= '1';
    end if;
    
    ---- Ce code a été écrit par Franck pour STEP_3
    ---- Pour enlever ce code, il faudra également retirer letterBox dans l'entity
    
    if we = '1' and slowCtBus.addr(4 downto 0) = B"00000" then
      if slowCtBus.data = X"0038" then
        letterBoxLocal <= '1';
      end if;
      
      if slowCtBus.data = X"0000" then
        letterBoxLocal <= '0';
      end if;
      
    end if;
    
  end if;
end process;

end Behavioral;

