library IEEE;
use IEEE.STD_LOGIC_1164.all;

--================================================================================
package slow_ct_defs is

-- le bus de slow control et son système d'adressage
constant SC_AD_WIDTH : integer := 16;
constant SC_TOP      : integer := SC_AD_WIDTH - 1;

type SlowCtBusRec is
  record
    data   : std_logic_vector (15 downto 0);
    addr   : std_logic_vector (SC_AD_WIDTH-1 downto 0);
    rd     : std_logic;
    wr     : std_logic;
  end record;
  
end slow_ct_defs;
  
package body slow_ct_defs is
 
end slow_ct_defs;
