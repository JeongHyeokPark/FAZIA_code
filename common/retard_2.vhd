----------------------------------------------------------------------------------
-- Company: IPN Orsay
-- 
-- Create Date:  01/12/2016 from retard1.vhd 
-- Design Name: telescope
-- Module Name:  retard2 - Behavioral 
-- Project Name: FAZIA
-- Target Devices: Virtex-5
-- Tool versions: ISE 14.7
-- Description: Ne fonctionne que si DATA_WIDTH = 15
--              Pour d'autres largeurs, rajouter des clauses generate avec de nouvelles mémoires
-- Dependencies: 
-- Revision: 
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

entity retard_2 is
  generic (
    DATA_WIDTH   : integer;
	 DELAY_WIDTH  : integer);
  port (
    clk   : in  std_logic;
    reset : in  std_logic;
    ---
    din   : in  std_logic_vector (DATA_WIDTH-1 downto 0);
    dout  : out std_logic_vector (DATA_WIDTH-1 downto 0);
    ---
    duree : in  std_logic_vector (DELAY_WIDTH-1 downto 0));
end retard_2;

architecture Behavioral of retard_2 is

component ram_1kx15
	port (
	clka  : in  std_logic;
	wea   : in  std_logic_vector( 0 downto 0);
	addra : in  std_logic_vector(9 downto 0);
	dina  : in  std_logic_vector(14 downto 0);
	clkb  : in  std_logic;
	addrb : in  std_logic_vector(9 downto 0);
	doutb : out std_logic_vector(14 downto 0));
end component;

component ram_2kx15
	port (
	clka  : in  std_logic;
	wea   : in  std_logic_vector( 0 downto 0);
	addra : in  std_logic_vector(10 downto 0);
	dina  : in  std_logic_vector(14 downto 0);
	clkb  : in  std_logic;
	addrb : in  std_logic_vector(10 downto 0);
	doutb : out std_logic_vector(14 downto 0));
end component;

signal addra    : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal addrb    : std_logic_vector(DELAY_WIDTH-1 downto 0);
signal compteur : std_logic_vector(DELAY_WIDTH-1 downto 0);

-- attribute box_type : string;
-- attribute box_type of ram_2kx15 : component is "black_box"; -- c'est un .xco

begin
  addra <= compteur;
  addrb <= unsigned(compteur) - unsigned(duree);
  
----------------------------------------------------------------------------------------------
make_mem_1k: if DATA_WIDTH = 15 and DELAY_WIDTH = 10 generate
my_delay_1 : ram_1kx15
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

make_mem_2k: if DATA_WIDTH = 15 and DELAY_WIDTH = 11 generate
my_delay_2 : ram_2kx15
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

