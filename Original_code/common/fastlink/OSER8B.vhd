----------------------------------------------------------------------------------
-- Company:  IPNO - SEP
-- Engineer: Salomon F.
-- 
-- Create Date:    15:21:26 10/25/2011 
-- Design Name: 
-- Module Name:    OSER8B - Behavioral 
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;
--use IEEE.std_logic_unsigned.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity OSER8B is
  Port (
        SR        : in  std_logic;
        CLK400    : in  std_logic;
        CLK50     : in  std_logic;
        DIN       : in  std_logic_vector(7 downto 0);
        DOUT      : out std_logic
       );
end OSER8B;

architecture Behavioral of OSER8B is
  constant C_GND       : std_logic := '0';
  constant C_HIGH      : std_logic := '1';
  signal shift1_iser   : std_logic;
  signal shift2_iser   : std_logic;
begin

	
  moserdes_inst : OSERDES
  generic map(
  DATA_RATE_OQ 	 => "SDR",
  DATA_RATE_TQ 	 => "SDR",
  DATA_WIDTH     => 8,
  --INIT_OQ        => '0',
  --INIT_TQ        => '0',
  SERDES_MODE    => "MASTER",
  --SRVAL_OQ       => '0',
  --SRVAL_TQ       => '0',
  TRISTATE_WIDTH => 1
             )
  port map(
  OQ             => DOUT,
  SHIFTOUT1      => open,
  SHIFTOUT2      => open,
  TQ             => open,
  CLK            => CLK400,
  CLKDIV         => CLK50,
  D1             => DIN(0),
  D2             => DIN(1),
  D3             => DIN(2),
  D4             => DIN(3),
  D5             => DIN(4),
  D6             => DIN(5),
  OCE            => C_HIGH,
  REV            => C_GND,
  SHIFTIN1       => shift1_iser,
  SHIFTIN2       => shift2_iser,
  SR             => SR,
  T1             => C_GND,
  T2             => C_GND,
  T3             => C_GND,
  T4             => C_GND,
  TCE            => C_GND
          );

soserdes_inst : OSERDES
  generic map(
  DATA_RATE_OQ 	 => "SDR",
  DATA_RATE_TQ 	 => "SDR",
  DATA_WIDTH     => 8,
  --INIT_OQ        => '0',
  --INIT_TQ        => '0',
  SERDES_MODE    => "SLAVE",
  --SRVAL_OQ       => '0',
  --SRVAL_TQ       => '0',
  TRISTATE_WIDTH => 1
             )
  port map(
  OQ             => open,
  SHIFTOUT1      => shift1_iser,
  SHIFTOUT2      => shift2_iser,
  TQ             => open,
  CLK            => CLK400,
  CLKDIV         => CLK50,
  D1             => C_GND,
  D2             => C_GND,
  D3             => DIN(6),
  D4             => DIN(7),
  D5             => C_GND,
  D6             => C_GND,
  OCE            => C_HIGH,
  REV            => C_GND,
  SHIFTIN1       => C_GND,
  SHIFTIN2       => C_GND,
  SR             => SR,
  T1             => C_GND,
  T2             => C_GND,
  T3             => C_GND,
  T4             => C_GND,
  TCE            => C_GND
          );

end Behavioral;

