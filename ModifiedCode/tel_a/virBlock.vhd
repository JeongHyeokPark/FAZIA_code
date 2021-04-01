-------------------------------------------------------------------------------------------------
-- Company:  IPNO
-- Engineer: Pierre Edelbruck
-- 
-- Create Date: 26/09/2012 
-- Design Name: virBlock
--===============================================================================================
-- Module Name:                       ===== virBlock =====
--===============================================================================================
-- File:   virBlock.vhd
-- Project Name:  Fazia
-- Target Devices: Virtex-5
-- Tool versions: 12.4
-- Description:
-- Module de substitution à la blockCard pour tests sur table
-- Nécessite le banc de test doté des interconnexions adéquates

-- Revision: 
--
--------------------------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;
library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
--use work.align_defs.all;
use work.slow_ct_defs.all;
--use work.telescope_conf.all;

-------------------------------------------------------------------------------------------------
entity VirBlock is
  port (
    clk         : in     std_logic;
    reset       : in     std_logic;
    clk25MHz    : in     std_logic;
    ---
    ioFpga_4    : out  std_logic;
    ioFpga_5    : out  std_logic;
    ioFpga_6    : out  std_logic;
    ioFpga_7    : out  std_logic;
    ioFpga_8    : out  std_logic;
    ioFpga_9    : inout  std_logic;
 --   ioFpga_10   : inout  std_logic;
    ---
    slowCtBus   : in     SlowCtBusRec;
    slowCtBusRd : out    std_logic_vector(15 downto 0)
  );
end VirBlock;

-------------------------------------------------------------------------------------------------
architecture virBlock_arch of virBlock is
alias syncZer is ioFpga_4;


signal clk25Resync : std_logic;
signal oldClk25MHz : std_logic;
signal scaler      : std_logic_vector (13 downto 0);

-----------------------------------------------------------------------------------------------
begin

ioFpga_5 <= clk25MHz;
ioFpga_6 <= scaler(13);
ioFpga_7 <= scaler(12);
ioFpga_8 <= scaler(11);

makeSync: process (reset, clk)
begin
  if reset = '1' then
    scaler <= (others => '0');
  elsif rising_edge(clk) then
    clk25Resync <= clk25MHz;
    oldClk25MHz <= clk25Resync;
    if oldClk25MHz = '0' and clk25Resync = '1' then
      scaler <= scaler + 1;
    end if;
    if scaler = 0 then
      syncZer <='1';
    else
      syncZer <= '0';
    end if;
  end if;
end process;
    
end virBlock_arch;

