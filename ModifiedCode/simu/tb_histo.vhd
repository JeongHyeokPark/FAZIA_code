--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   13:00:36 03/22/2012
-- Design Name:   
-- Module Name:   /home/ebk/fazia/phase_2/step_2/fpga/simu/tb_histo.vhd
-- Project Name:  tel_b
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: Histogrammer
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
use work.tel_defs.all;
use work.slow_ct_defs.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--USE ieee.numeric_std.ALL;
 
ENTITY tb_histo IS
END tb_histo;
 
ARCHITECTURE behavior OF tb_histo IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
    COMPONENT Histogrammer
  generic (
    RegAd   : std_logic_vector(SC_TOP downto 0);
    HistoAd : std_logic_vector(SC_TOP downto 0)
  );
    PORT(
         clk : IN  std_logic;
         reset : IN  std_logic;
         dataIn : IN  std_logic_vector(23 downto 0);
         fire : IN  std_logic;
         slowCtBus : IN  slowCtBusRec;
         SlowCtBusRd : OUT  std_logic_vector(15 downto 0)
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';
   signal dataIn : std_logic_vector(23 downto 0) := (others => '0');
   signal fire : std_logic := '0';
   signal slowCtBus : slowCtBusRec;

 	--Outputs
   signal SlowCtBusRd : std_logic_vector(15 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
  uut: Histogrammer
  generic map (
    RegAd   => QH1_SC,
    HistoAd => HISTO_QH1
  )
  PORT MAP (
          clk => clk,
          reset => reset,
          dataIn => dataIn,
          fire => fire,
          slowCtBus => slowCtBus,
          SlowCtBusRd => SlowCtBusRd
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
  reset <= '1';
  slowCtBus.addr <= (others => '0');
  slowCtBus.data <= (others => '0');
  slowCtBus.rd   <= '0';
  slowCtBus.wr   <= '0';
  dataIn         <= x"000000";
  fire           <= '0';
  
  wait for 52.5 ns;
  reset <= '0';
  wait for 10 ns;
  
  slowCtBus.addr <= QH1_SC or SLOW_LOCAL or (x"000" & HISTO_BIN);
  slowCtBus.data <= x"0003";
  slowCtBus.wr   <= '1';
  wait for 10 ns;
  slowCtBus.wr   <= '0';
  wait for 10 ns;
  
  slowCtBus.addr <= QH1_SC or SLOW_LOCAL or (x"000" & HISTO_OFFSET_H);
  slowCtBus.data <= x"0000";
  slowCtBus.wr   <= '1';
  wait for 10 ns;
  slowCtBus.wr   <= '0';
  wait for 10 ns;

  slowCtBus.addr <= QH1_SC or SLOW_LOCAL or (x"000" & HISTO_OFFSET_L);
  slowCtBus.data <= x"0111";
  slowCtBus.wr   <= '1';
  wait for 10 ns;
  slowCtBus.wr   <= '0';
  wait for 10 ns;
  
  dataIn         <= x"000333";
  fire <= '1';
  wait for 10 ns;
  fire <= '0';
  
  dataIn         <= x"000123";
  wait for 100 ns;
  fire <= '1';
  wait for 10 ns;
  fire <= '0';

  
  wait for 100 ns;
  dataIn         <= x"000333";
  fire <= '1';
  wait for 10 ns;
  fire <= '0';
  
  wait for 200 ns;
  
-- lecture mémoire
  slowCtBus.addr <= HISTO_QH1 or x"0088";
  slowCtBus.rd   <= '1';
  wait for 10 ns;
  slowCtBus.rd <= '0';
  
  wait for 20 ns;
  
  slowCtBus.addr <= HISTO_QH1 or x"0089";
  slowCtBus.rd   <= '1';
  wait for 10 ns;
  slowCtBus.rd <= '0';
  
  wait for 20 ns;
  
  slowCtBus.addr <= HISTO_QH1 or x"0004";
  slowCtBus.rd   <= '1';
  wait for 10 ns;
  slowCtBus.rd <= '0';
  
  wait for 20 ns;
  
  slowCtBus.addr <= HISTO_QH1 or x"0005";
  slowCtBus.rd   <= '1';
  wait for 10 ns;
  slowCtBus.rd <= '0';
  
  wait;
end process;

END;
