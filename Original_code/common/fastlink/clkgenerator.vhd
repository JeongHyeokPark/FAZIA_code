--------------------------------------------------------------------------------
-- Company:  IPN ORSAY
-- Engineer: Franck SALOMON
--
-- Create Date:    29/01/2012
  
-- Description:   Module Clock generator
-- Ce module a pour but de fournir en sortie quatre horloge avec un déphasage quasi nul
-- ainsi qu'une horloge de 25 MHz synchronisée par le 100 MHz 
--------------------------------------------------------------------------------

Library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;

--------------------------------------------------------------------------------

ENTITY clkgenerator IS
PORT(
  CLK100IN             : IN  STD_LOGIC;
  CLK25IN              : IN  STD_LOGIC;
  reset                : IN  STD_LOGIC;
  CLK50OUT             : OUT STD_LOGIC;
  CLK200OUT            : OUT STD_LOGIC;
  CLK400OUT            : OUT STD_LOGIC;
  CLK100OUT            : OUT STD_LOGIC;
  CLK25SYNC            : OUT STD_LOGIC;
  LOCKED_PLL           : OUT STD_LOGIC
  );
END clkgenerator;

ARCHITECTURE BEHAVIORAL OF clkgenerator IS

  COMPONENT the_pll
  PORT(
    CLKIN1_IN    : IN  STD_LOGIC;
    RST_IN       : IN  STD_LOGIC;
    CLKOUT0_OUT  : OUT STD_LOGIC;
    CLKOUT1_OUT  : OUT STD_LOGIC;
    CLKOUT2_OUT  : OUT STD_LOGIC;
    CLKOUT3_OUT  : OUT STD_LOGIC;
    CLKFBOUT_OUT : OUT STD_LOGIC;
    LOCKED_OUT   : OUT STD_LOGIC
  );
  END COMPONENT;

  SIGNAL clk25falling  : STD_LOGIC;

BEGIN

  inst_the_pll: the_pll
  PORT MAP(
  CLKIN1_IN    => CLK25IN,
  RST_IN       => reset,
  CLKOUT0_OUT  => CLK50OUT,
  CLKOUT1_OUT  => CLK200OUT,
  CLKOUT2_OUT  => CLK400OUT,
  CLKOUT3_OUT  => CLK100OUT,
  CLKFBOUT_OUT => open,
  LOCKED_OUT   => LOCKED_PLL
  );

  gene_25_f: PROCESS (CLK100IN)
  BEGIN
  IF falling_edge(CLK100IN) then
    clk25Falling <= CLK25IN;
  END IF;
  END PROCESS;
--------------------------------------
  gene_25: PROCESS (CLK100IN)
  begin
    IF rising_edge(CLK100IN) THEN
      CLK25SYNC <= NOT clk25Falling;
    END IF;
  END PROCESS;


END BEHAVIORAL;
