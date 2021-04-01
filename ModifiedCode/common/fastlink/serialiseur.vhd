--------------------------------------------------------------------------------
-- Company:  IPN ORSAY
-- Engineer: Franck SALOMON
--
-- Create Date:    05/01/2012
  
-- Description:   Module sérialiseur
-- 
--------------------------------------------------------------------------------

Library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;

--------------------------------------------------------------------------------

ENTITY SERIALISEUR IS
PORT(
  clk50        : in  STD_LOGIC;
  clk4x        : in  STD_LOGIC;
  reset        : in  STD_LOGIC;
  din_ser      : in  STD_LOGIC_VECTOR(7 downto 0);
  out400_p     : out STD_LOGIC;
  out400_n     : out STD_LOGIC
  );
END SERIALISEUR;

--------------------------------------------------------------------------------

ARCHITECTURE BEHAVIORAL OF SERIALISEUR IS

  -- déclaration de composants

  COMPONENT OSER8B
  PORT(
        SR        : in  STD_LOGIC;
        CLK400    : in  STD_LOGIC;
        CLK50     : in  STD_LOGIC;
        DIN       : in  STD_LOGIC_VECTOR(7 downto 0);
        DOUT      : out STD_LOGIC
     );
  END COMPONENT;


  -- déclaration de signaux internes
  -- signal de données
  signal out400       : STD_LOGIC;

BEGIN


  OSER8B_inst : OSER8B
  PORT MAP (
            SR     => reset,
            CLK400 => clk4x,
            CLK50  => clk50,
            DIN    => din_ser,
            DOUT   => out400
           );

  obuf_inst: OBUFDS
  GENERIC MAP(
    CAPACITANCE => "DONT_CARE",
    IOSTANDARD  => "LVDS_25"
  )
  PORT MAP(
    O  => out400_p,
    OB => out400_n,
    I  => out400
  );


END BEHAVIORAL;

