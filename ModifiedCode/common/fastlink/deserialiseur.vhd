--------------------------------------------------------------------------------
-- Company:  IPN ORSAY
-- Engineer: Franck SALOMON
--
-- Create Date:    05/01/2012
  
-- Description:   Module désérialiseur
-- 
--------------------------------------------------------------------------------

Library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;

--------------------------------------------------------------------------------

ENTITY DESERIALISEUR IS
GENERIC(
  cs : boolean
  );
PORT(
  clk50     : in STD_LOGIC;
  clk4x     : in STD_LOGIC;
  alignIn   : in STD_LOGIC;
  reset     : in  STD_LOGIC;
  sdi_p     : in  STD_LOGIC;
  sdi_n     : in  STD_LOGIC;
  dout_des  : out STD_LOGIC_VECTOR(7 downto 0)
  );
END DESERIALISEUR;

--------------------------------------------------------------------------------

ARCHITECTURE BEHAVIORAL OF DESERIALISEUR IS

  -- déclaration de composant

  COMPONENT N_ISERDES8b_MsAllign
  GENERIC(
  withChipScope : boolean
  );
  port(
    CLK50MHz   : in  STD_LOGIC;
    BCLK400MHz : in  STD_LOGIC;
    CLK400MHz  : in  STD_LOGIC;
    RESET      : in  STD_LOGIC;
    Allinea    : in  STD_LOGIC;
    SDIN_N     : in  STD_LOGIC;
    SDIN_P     : in  STD_LOGIC;
    DOUT       : out std_logic_VECTOR(7 downto 0)
    );			 
  END COMPONENT;

  -- déclaration de signaux internes

  -- signaux d'horloges
  signal clk50_buf  : STD_LOGIC;
  signal clk4x_buf  : STD_LOGIC;
  signal clk4x_bufn : STD_LOGIC;

  -- signal reset
  signal SR_sig     : STD_LOGIC;

  -- signal de demande d'alignement
  signal alinea     : STD_LOGIC;

  -- signaux de données
  signal sdi_int_p  : STD_LOGIC;
  signal sdi_int_n  : STD_LOGIC;
  signal dout_int   : STD_LOGIC_VECTOR(7 downto 0);

BEGIN

  deser_inst: N_ISERDES8b_MsAllign
  generic map (
  withChipScope => cs
  )
  PORT MAP (
            CLK50MHz   => clk50_buf,
            BCLK400MHz => clk4x_bufn,
            CLK400MHz  => clk4x_buf,
            RESET      => SR_sig,
            Allinea    => alinea,
            SDIN_N     => sdi_int_n,
            SDIN_P     => sdi_int_p,
            DOUT       => dout_int
           );

  clk4x_bufn <= not clk4x_buf;

  clk50_buf <= clk50;
  clk4x_buf <= clk4x;
  alinea    <= alignIn;
  sdi_int_p <= sdi_p;
  sdi_int_n <= sdi_n;
  SR_sig    <= reset;
  dout_des  <= dout_int;

END BEHAVIORAL;
