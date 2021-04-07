----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    11:25:36 05/27/2010 
-- Design Name: 
-- Module Name:    compteur - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
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

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity compteur is
  generic (
    WIDTH  : integer :=4;
    MODULO : integer
  );
  port (
    clk   : in  std_logic;
    reset : in  std_logic;
    raz   : in  std_logic;
    carry : out std_logic;
    incr  : in  std_logic
  );
end compteur;

----------------------------------------------------------------------------------
architecture Behavioral of compteur is

signal compte: std_logic_vector (WIDTH-1 downto 0);

----------------------------------------------------------------------------------
begin
compter: process (reset, clk)
begin
  if (reset = '1') then
    compte <= (others => '0');
  elsif rising_edge (clk) then
    if raz = '1' then -- raz prioritaire
      compte <= (others => '0');
    elsif incr = '1' then
      if compte = MODULO-1 then
        compte <= (others => '0');
      else
        compte <= compte + 1;
      end if;
    end if;
    if compte = MODULO-1 then
      carry <= '1';
    else
      carry <= '0';
    end if;
  end if;
end process;
end Behavioral;

