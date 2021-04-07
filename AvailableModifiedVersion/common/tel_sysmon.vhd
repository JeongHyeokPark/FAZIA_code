-------------------------------------------------------------------------------------------------
-- Company:  IPNO
-- Engineer: Pierre Edelbruck
-- 
-- Create Date: 24/07/2012
-- Design Name: telescope
--===============================================================================================
-- Module Name:                       ===== SysMonitor =====
--===============================================================================================
-- File:   tel_sysmon.vhd
-- Project Name:  Fazia
-- Target Devices: Virtex-5
-- Tool versions: 12.4
-- Description:
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
--------------------------------------------------------------------------------------------------
LIBRARY IEEE;
USE IEEE.std_logic_1164.ALL;
use IEEE.std_logic_arith.ALL;
use IEEE.std_logic_unsigned.ALL;
library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.slow_ct_defs.all;

--------------------------------------------------------------------------------------------------
entity SysMonitor is
   generic (
    regAd : std_logic_vector(SC_AD_WIDTH-1 downto 0)
  );
  port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    ---
    slowCtBus   : in  SlowCtBusRec;
    slowCtBusRd : out std_logic_vector (15 downto 0)
  );
end SysMonitor;

--------------------------------------------------------------------------------------------------
architecture behavioral of SysMonitor is

signal order   : std_logic;
signal channel : std_logic_vector (1 downto 0);
signal ready   : std_logic;
signal value   : std_logic_vector (9 downto 0);

type MonitorType is (IDLE, WAITING);
signal monState : MonitorType;

--------------------------------------------------------------------------------------------------
begin  -- behavioral

system_mon: entity work.UserSysMon
  port map (
    clk100       => clk,
    reset        => reset,
    ---
    order        => order,
    user_channel => channel,
    mydready     => ready,
    value        => value,
    chanout      => open 
  );

--- gestion du bus --------------------------------------------------------------------------------
regLoad: process (clk, reset, slowCtBus)
variable decod : std_logic;
begin
  -- chip-select du module
  if slowCtBus.addr(SC_AD_WIDTH-1 downto SYS_MON_FIELD)
          = RegAd(SC_AD_WIDTH-1 downto SYS_MON_FIELD) then
    decod := '1';
  else
    decod := '0';
  end if;

  if reset = '1' then
    monState <= IDLE;
  elsif rising_edge(clk) then
    slowCtBusRd <= (others => '0');
    if monState = WAITING then
      if ready ='1' then
        order <= '0';
        monState <= IDLE;
      end if;
    end if;
    if decod = '1' then
      if slowCtBus.wr = '1' then ---------------------------------------------------------
        channel  <= slowCtBus.addr(1 downto 0);
        order    <= '1';
        monState <= WAITING; -- on attendra que ready monte
      elsif slowCtBus.rd = '1' then ------------------------------------------------------
        slowCtBusRd <= ready & "00000" & value;
      end if;
    end if;
  end if;  -- reset = '1'
end process regLoad;
        
--------------------------------------------------------------------------------------------------

end behavioral;
