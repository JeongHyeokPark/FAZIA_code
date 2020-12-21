library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.tel_defs.all;
use work.slow_ct_defs.all;
use work.telescope_conf.all;

entity identity is
  generic (RegAd : std_logic_vector(SC_AD_WIDTH-1 downto 0));
  port(
    clk         : in  std_logic;
    reset       : in  std_logic;
    slowCtBus   : in  slowCtBusRec;
    slowCtBusRd : out std_logic_vector (15 downto 0)
  );
end identity;


architecture Behavioral of identity is

signal identification : std_logic_vector (SC_TOP downto 0);

begin

regLoad: process (clk, reset)
begin
  if rising_edge(clk) then
    if reset = '1' then
      identification <= (others => '0');
    else
      slowCtBusRd <= (others => '0'); -- laisser le bus de lecture libre

      if slowCtBus.addr(SC_AD_WIDTH-1 downto 0) = RegAd(SC_AD_WIDTH-1 downto 0) then
        if slowCtBus.wr = '1' then
          identification <= slowCtBus.data(SC_TOP downto 0);
        elsif slowCtBus.rd = '1' then
          slowCtBusRd(SC_TOP downto 0) <= identification;
        end if;
      end if;
    end if;
  end if;
end process regLoad;
------------
end Behavioral;
