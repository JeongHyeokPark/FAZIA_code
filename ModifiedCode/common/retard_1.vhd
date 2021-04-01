----------------------------------------------------------------------------------
-- Company: IPN Orsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:  14:46:12 11/18/2010 from retard.vhd (phase-1 2007)
-- Design Name: telescope
-- Module Name:  retard - Behavioral 
-- Project Name: FAZIA
-- Target Devices: Virtex-5
-- Tool versions: ISE 11.1
-- Description: Ne fonctionne que si DATA_WIDTH = 15
--              Pour d'autres largeurs, rajouter des clauses generate avec de nouvelles mémoires
-- Dependencies: 
--
-- Revision: 
-- Revision 2.0 - ramené la RAM à 15 bits pour éviter les connexions open (et les warnings)
-- Additional Comments: 
--
-------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
--use ieee.std_logic_unsigned.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity retard_1 is
  generic (
    DATA_WIDTH    : integer);
  port (
    clk   : in  std_logic;
    reset : in  std_logic;
    ---
    din   : in  std_logic_vector (DATA_WIDTH-1 downto 0);
    dout  : out std_logic_vector (DATA_WIDTH-1 downto 0);
    ---
    duree : in  std_logic_vector (9 downto 0));
end retard_1;

architecture Behavioral of retard_1 is

component ram_1kx15_modified
	port (
	clka  : in  std_logic;
	wea   : in  std_logic_vector( 0 downto 0);
	addra : in  std_logic_vector( 9 downto 0);
	dina  : in  std_logic_vector(14 downto 0);
	clkb  : in  std_logic;
	addrb : in  std_logic_vector( 9 downto 0);
	doutb : out std_logic_vector(14 downto 0));
end component;

signal addra    : std_logic_vector(9 downto 0);
signal addrb    : std_logic_vector(9 downto 0);
signal compteur : std_logic_vector(9 downto 0);

attribute box_type : string;
attribute box_type of ram_1kx15_modified : component is "black_box"; -- c'est un .xco

begin
  addra <= compteur;
  addrb <= unsigned(compteur) - unsigned(duree);
  
----------------------------------------------------------------------------------------------
make_mem: if DATA_WIDTH = 15 generate
my_delay : ram_1kx15_modified
  port map (
    clka  => clk,
    wea   => "1",
    addra => addra,
    dina  => din,
    clkb  => clk,
    addrb => addrb,
    doutb => dout
  );
end generate;

-------------------------------------------------------------------------------------------------
-- incrémenter les pointeurs
progresser : process (clk, reset)
begin
  if reset = '1' then
    compteur <= (others => '0');
  elsif rising_edge (clk) then
    compteur <= unsigned(compteur) + 1;
  end if;
end process;

-------------------------------------------------------------------------------------------------
end Behavioral;

