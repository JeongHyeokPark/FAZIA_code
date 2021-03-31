----------------------------------------------------------------------------------
-- Company:  IPN Orsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:    21 déc. 2010 
-- Design Name:    lib
-- Module Name:    scItf
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions:  ise-12.3
-- Description: wrapper pour les modules picItf et usbItf
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;
use work.slow_ct_defs.all;

----------------------------------------------------------------------------------
entity ScItf is
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    -- pic -----------------------
    ucSpiSdi   : out std_logic; -- nommé (i/o) du point de vue du pic
    ucSpiSdo   : in  std_logic;
    ucSpiSck   : in  std_logic;
    ucSpiSs_n  : in  std_logic;
    -- Interface USB -------------
    -- le numéro de port USB 00 = com   01 = tel_a 10 = tel_b (step 1)
    --                       00 = tel_a 01 = tel_b            (step 2)
    addrUsb    : in    std_logic_vector (1 downto 0);
    dataUsb    : inout std_logic_vector (7 downto 0);
    rxf_n      : in    std_logic;
    txe_n      : in    std_logic;
    rdUsb_n    : inout std_logic; -- sortie tristate
    wrUsb      : out   std_logic; -- sortie tristate
    -- Interface to bus side -----
    slowCtBus   : out  SlowCtBusRec;
    slowCtBusRd : in   std_logic_vector (SC_TOP downto 0)
  );
end ScItf;

----------------------------------------------------------------------------------
architecture Behavioral of ScItf is

-- signaux ------------------------------------------------

signal selectSpi : std_logic;
signal slowCtBusUsb, slowCtBusSpi : SlowCtBusRec;

signal all_zero_128 : std_logic_vector (127 downto 0) := (others => '0');
signal CONTROL0 : std_logic_vector (35 downto 0);


---- composants à déclarer ----
--component tel_ila
--  PORT (
--    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
--    CLK     : IN STD_LOGIC;
--    TRIG0   : IN STD_LOGIC_VECTOR(  127 DOWNTO 0)
--  );
--end component;
--
--component tel_icon
--  PORT (
--    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
--end component;


-------------------------------------------------------------------------------------------------
begin

-- multiplexage bus de slow-control
slowCtBus.rd   <= slowCtBusSpi.rd   when selectSpi = '1' else slowCtBusUsb.rd;
slowCtBus.wr   <= slowCtBusSpi.wr   when selectSpi = '1' else slowCtBusUsb.wr;
slowCtBus.data <= slowCtBusSpi.data when selectSpi = '1' else slowCtBusUsb.data;
slowCtBus.addr <= slowCtBusSpi.addr when selectSpi = '1' else slowCtBusUsb.addr;
---------------------------------------------------------
-- 
--  mon_icon : tel_icon
--    port map (
--    CONTROL0 => CONTROL0);
--	 
--  mes_sondes : tel_ila
--  port map (
--    CONTROL => CONTROL0,
--    CLK     => clk,
--    ---
--    TRIG0 (0) 					=> selectSpi,
--    TRIG0 (1) 					=> slowCtBusUsb.rd,
--    TRIG0 (17 downto 2)	 	=> slowCtBusUsb.addr,
--	 TRIG0 (33 downto 18) 	=> slowCtBusUsb.data,
--	 TRIG0 (49 downto 34)   => slowCtBusSpi.addr,
--	 TRIG0 (65 downto 50)   => slowCtBusSpi.data,
--	 TRIG0 (66)					=> slowCtBusSpi.rd,
--	 TRIG0 (67)					=> slowCtBusSpi.wr,
--	 trig0 (127 downto 68)  => all_zero_128 (127 downto 68)
-- );
 
 
  usb: entity work.UsbItf_new
    port map (
      clk         => clk,
      reset       => reset,
      ---
      addrUsb     => addrUsb,
      dataUsb     => dataUsb,
      rd_n        => rdUsb_n,
      wr          => wrUsb,
      rxf_n       => rxf_n,
      txe_n       => txe_n,
      ---
      slowCtBus   => slowCtBusUsb,
      slowCtBusRd => slowCtBusRd    -- depuis le bus vers l'extérieur
    );
    
picItfBloc: entity work.PicItf
    port map (
      clk         => clk,
      reset       => reset,
      ---------------------------------------
      ucSpiSS_n   => ucSpiSS_n,
      ucSpiSdi    => ucSpiSdi,
      ucSpiSdo    => ucSpiSdo,
      ucSpiSck    => ucSpiSck,
      -- Interface to bus side --------------
      selectSpi   => selectSpi,
      slowCtBus   => slowCtBusSpi,
      slowCtBusRd => slowCtBusRd    -- depuis le bus vers l'extérieur
    );

end Behavioral;

    
    
