----------------------------------------------------------------------------------
-- Company:  IPN Orsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:  18/11/2010
-- Updated:      03/05/2011
-- Design Name:  telescope
-- Module Name:  shaper - Behavioral 
-- Project Name: FAZIA
-- Target Devices: Virtex-5
-- Tool versions: ISE 11.1
-- Description: 
-- Mis à jour le 3/5/2011. Pour une raison non élucidée, ai dû ajouter un bit aux
-- bus internes (vs bus d'entrée) pour tenir toute la dynamique. Supprimé aussi les
-- librairies signed et unsigned au profit de arith avec des casts explicites.

-- Additional Comments: 
--
----------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.ALL;
use ieee.numeric_std.ALL;
use ieee.std_logic_signed.ALL;
--use ieee.std_logic_arith.ALL;
use work.tel_defs.all;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity shaper is
  generic (
    INPUT_WIDTH  : integer;
    OUTPUT_WIDTH : integer;
    SHAPER_FLAT_WIDTH : integer);
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    --
    input     : in  std_logic_vector (INPUT_WIDTH-1  downto 0);
    output    : out std_logic_vector (OUTPUT_WIDTH-1 downto 0);
    --
    rise      : in  std_logic_vector (9 downto 0); -- montée
    flat      : in  std_logic_vector (SHAPER_FLAT_WIDTH-1 downto 0); -- montée + plateau
    --
    timer     : in  std_logic);

end shaper;

architecture Behavioral of shaper is

-----------------------------------------------------------------------------------
signal inputExtended : std_logic_vector(INPUT_WIDTH downto 0);
signal risingOut : std_logic_vector(INPUT_WIDTH downto 0);
signal firstDif  : std_logic_vector(INPUT_WIDTH downto 0);
signal secondDif : std_logic_vector(INPUT_WIDTH+1 downto 0);
signal fallingOut: std_logic_vector(INPUT_WIDTH downto 0);
signal somme     : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
signal shaperOut : std_logic_vector(OUTPUT_WIDTH-1 downto 0);
signal lateTimer : std_logic; -- pour la fonction leakage
signal postTimer : std_logic_vector(3 downto 0); -- pour diviser timer par 10

-----------------------------------------------------------------------------------
begin
-- instantiate delays
rising: entity work.retard_1
generic map (DATA_WIDTH => INPUT_WIDTH+1)
port map (
  clk   => clk,
  reset => reset,
  din   => inputExtended,
  dout  => risingOut,
  duree => rise);

-----------------------------------------------------------------------------------
falling: entity work.retard_2
generic map (DATA_WIDTH => INPUT_WIDTH+1,
             DELAY_WIDTH => SHAPER_FLAT_WIDTH)
port map (
   clk   => clk,
   reset => reset,
   din   => firstDif,
   dout  => fallingOut,
   duree => flat);
   
------------------------------------------------------------------------------------
inputExtended(INPUT_WIDTH) <= input(INPUT_WIDTH-1);
inputExtended(INPUT_WIDTH-1 downto 0) <= input;
------------------------------------------------------------------------------------
shaper_1: process (reset, clk)
begin
   if (reset = '1') then
      firstDif <= (others => '0');
   elsif rising_edge (clk) then
		firstDif <= signed(inputExtended) - signed(risingOut);
   end if;
end process shaper_1;

-----------------------------------------------------------------------------------
shaper_2: process (reset, clk)
begin
	if (reset = '1') then
      secondDif <= (others => '0');
	elsif rising_edge (clk) then
      secondDif <= std_logic_vector(resize(signed(firstDif),INPUT_WIDTH+2) - resize(signed(fallingOut),INPUT_WIDTH+2));
	end if;
end process shaper_2;

-----------------------------------------------------------------------------------
-- somme combinatoire
somme <= signed(secondDif) + signed(shaperOut);

shaper_3: process (reset, clk, timer, lateTimer) -- the integrator 
  variable microsec : std_logic;
  variable leakageTime : std_logic;
  
begin
  if timer = '1' and lateTimer = '0' then
    microsec := '1';
  else
    microsec := '0';
  end if;

	if (reset = '1') then
		shaperOut <= (others => '0');
    postTimer <= (others => '0');
	elsif rising_edge (clk) then
    lateTimer <= timer;
    leakageTime := '0';
    
    if microsec = '1' then
      if postTimer = 9 then
        postTimer <= (others => '0');
        leakageTime := '1';
      else
        postTimer <= postTimer + 1;
      end if;
    end if;
    ---------------------------------------
    if secondDif(INPUT_WIDTH) = '0' and shaperOut(OUTPUT_WIDTH-1) = '0' and somme(OUTPUT_WIDTH-1) = '1' then
      shaperOut(OUTPUT_WIDTH-1) <= '0';
      shaperOut(OUTPUT_WIDTH-2 downto 0) <= (others => '1'); -- plafonnement à +MAX
    elsif secondDif(INPUT_WIDTH) = '1' and shaperOut(OUTPUT_WIDTH-1) = '1' and somme(OUTPUT_WIDTH-1) = '0' then
      shaperOut(OUTPUT_WIDTH-1) <= '1';
      shaperOut(OUTPUT_WIDTH-2 downto 0) <= (others => '0'); -- plafonnement à -min
		elsif leakageTime = '1' then
      if shaperOut(OUTPUT_WIDTH-1) = '0' then -- and/substract some leakage
        shaperOut <= somme - 1; -- output positive
      else
        shaperOut <= somme + 1; -- output negative
      end if;
    else
      shaperOut   <= somme; -- no leakage
    end if;
	end if;
end process shaper_3;

-----------------------------------------------------------------------------------

output <= shaperOut;

end Behavioral;

