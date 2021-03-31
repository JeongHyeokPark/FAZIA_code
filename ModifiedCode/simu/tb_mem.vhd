--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   16:22:12 03/22/2012
-- Design Name:   
-- Module Name:   /home/ebk/fazia/phase_2/step_2/fpga/simu/tb_mem.vhd
-- Project Name:  tel_b
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: ram_1kx24
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
 
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb_mem IS
END tb_mem;
 
ARCHITECTURE behavior OF tb_mem IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT ram_1kx24
    PORT(
         clka : IN  std_logic;
         wea : IN  std_logic_vector(0 downto 0);
         addra : IN  std_logic_vector(9 downto 0);
         dina : IN  std_logic_vector(23 downto 0);
         clkb : IN  std_logic;
         addrb : IN  std_logic_vector(9 downto 0);
         doutb : OUT  std_logic_vector(23 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal wea : std_logic_vector(0 downto 0) := (others => '0');
   signal addra : std_logic_vector(9 downto 0) := (others => '0');
   signal dina : std_logic_vector(23 downto 0) := (others => '0');
   signal addrb : std_logic_vector(9 downto 0) := (others => '0');

 	--Outputs
   signal doutb : std_logic_vector(23 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: ram_1kx24 PORT MAP (
          clka => clk,
          wea => wea,
          addra => addra,
          dina => dina,
          ---
          clkb => clk,
          addrb => addrb,
          doutb => doutb
        );

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '1';
		wait for clk_period/2;
		clk <= '0';
		wait for clk_period/2;
   end process;
 
 

   -- Stimulus process
stim_proc: process
begin		
  wait for 21 ns;
  addrb <= (others => '0');
  
  addra <= "0000000001";
  dina  <= x"AAAAAA";
  wea(0) <= '1';
  wait for 10 ns;
  wea(0) <= '0';
  addra <= "0000000000";
  dina  <= x"000000";
  wait for 20 ns;
  
  addrb <= "0000000001";
  wait for 10 ns;
  addrb <= "0000000000";

  wait;
end process;

END;
