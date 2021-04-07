----------------------------------------------------------------------------------
-- Company:  INF NAPOLI
-- Engineer: 
-- 
-- Create Date:    25/01/10
-- Design Name: 
-- Module Name:    ISER8b - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
--  NECESSITA di   ((((  50 & 400 MHZ CLK da una DCM  )))
--  DATI ad 8bit a 50MHz (20ns)
--
--  SDIN LVDS @2V5
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;


entity ISER8b is
port ( CLK50MHz, BCLK400MHz, CLK400MHz, RESET : in  STD_LOGIC; -- CLK & RESET
       INC_DEL, INC_CE , IBSLIP               : in  STD_LOGIC; --  CONTROLLO  
       SDIN_N , SDIN_P                        : in  STD_LOGIC; --  INPUT
       DOUT                                   : out std_logic_VECTOR(7 downto 0) -- OUT
     );
end ISER8b;

architecture Behavioral of ISER8b is

--===================================================================================
-- COSTANTI & SEGNALI

--constant SDIN_RITARDO: 				integer := 8; -- SDIN RITARDO del Buffer IODELAY

signal SDIN,SDIN_DEL: std_logic; -- SDIN non differenziale
signal SHIFT1_ISER,SHIFT2_ISER:	std_logic; -- Segnali Interconnessione ISERDES
	
----------------------------------------------------------------------------------	

begin


--------------------------------------------------
-- Ricevitore Differenziale
IBUFDS_inst : IBUFDS
   generic map (
      CAPACITANCE => "DONT_CARE", DIFF_TERM => TRUE, 
      IBUF_DELAY_VALUE => "0", IFD_DELAY_VALUE => "AUTO", IOSTANDARD => "DEFAULT")
   port map (I => SDIN_P,IB => SDIN_N, O => SDIN);


------------------------------------------------------------------------------------
-- RITARDO SDIN CONTROLLO 

--IDEL_CTRL: IDELAYCTRL port map (REFCLK => ref_clk, RST => '0', RDY => open);
------------------------------------------------------------------------------------
-- Ritardo Programmabile 

SIN_delay : IODELAY
   generic map (
      --DELAY_SRC => "I", -- Specify which input port to be used
      -- "I"=IDATAIN, "O"=ODATAIN, "DATAIN"=DATAIN, "IO"=Bi-directional
      HIGH_PERFORMANCE_MODE => TRUE, -- TRUE specifies lower jitter
      IDELAY_TYPE => "VARIABLE",  -- "FIXED" or "VARIABLE" 
      --IDELAY_VALUE => 0,   -- 0 to 63 tap values
      --ODELAY_VALUE => 0,   -- 0 to 63 tap values
      REFCLK_FREQUENCY => 200.0,   -- Frequency used for IDELAYCTRL
      SIGNAL_PATTERN => "DATA")    -- Input signal type, "CLOCK" or "DATA" 
   port map (
      DATAOUT => SDIN_DEL,  -- 1-bit delayed data output
      C => CLK50MHz,     -- 1-bit clock input
      CE => INC_CE,   -- 1-bit clock enable input
      --DATAIN => '0', -- 1-bit internal data input
      IDATAIN => SDIN,  -- 1-bit input data input (connect to port)
      INC => INC_DEL, -- 1-bit increment/decrement input
      --ODATAIN => '0',  -- 1-bit output data input
      RST => RESET,  -- 1-bit active high, synch reset input
      T => '1'  -- 1-bit 3-state control input
   );
-----------------------------------------------------------------------------
-- NOTA  NOTA  NOTA  Non piu' usato perche non specifico per Virtex 5 
-- SIN_delay: IDELAY
--		generic map (IOBDELAY_TYPE => "VARIABLE", IOBDELAY_VALUE => '0')
--        port map    (C=>CLK50MHz, CE=>'0', INC=> , RST=> RESET, I=>SDIN, O=>SDIN_DEL);
-------------------------------------------------------------------------------
-- ISERDES 8BIT
	ISERDES_NODELAY_master: ISERDES_NODELAY
                generic map ( DATA_RATE =>"SDR", DATA_WIDTH =>8,
                              BITSLIP_ENABLE =>TRUE, SERDES_MODE =>"MASTER", INTERFACE_TYPE => "NETWORKING",
                              NUM_CE =>1
                            )
                port map (
                              CLK =>CLK400MHz,
                              OCLK =>CLK50MHz,
                              CLKDIV =>CLK50MHz, CLKB => BCLK400MHz,
--                              Q1 =>DOUT(0),Q2 =>DOUT(1),Q3 =>DOUT(2),
--                              Q4 =>DOUT(3),Q5 =>DOUT(4),Q6 =>DOUT(5),
                              Q1 =>DOUT(7),Q2 =>DOUT(6),Q3 =>DOUT(5),
                              Q4 =>DOUT(4),Q5 =>DOUT(3),Q6 =>DOUT(2),
                              SHIFTIN1=>'0',SHIFTIN2=>'0',
                              SHIFTOUT1 =>SHIFT1_ISER, 
                              SHIFTOUT2 =>SHIFT2_ISER,
                              BITSLIP =>IBSLIP,
                              CE1 => '1',
                              --CE2 =>'0',
                              D =>SDIN_DEL, 
                              RST =>RESET
                         );
	
        ISERDES_NODELAY_slave: ISERDES_NODELAY
                generic map (
                                DATA_RATE =>"SDR",DATA_WIDTH =>8,
                                BITSLIP_ENABLE =>TRUE,SERDES_MODE =>"SLAVE",INTERFACE_TYPE =>"NETWORKING",
                                NUM_CE =>1
                            )
                port map (
                                CLK =>CLK400MHz, OCLK =>CLK50MHz, CLKDIV =>CLK50MHz, CLKB => BCLK400MHz,
--                                Q3 =>DOUT(6), Q4 =>DOUT(7),
                                Q3 =>DOUT(1), Q4 =>DOUT(0),
                                SHIFTOUT1 =>open,SHIFTOUT2 =>open,
                                SHIFTIN1 =>SHIFT1_ISER, SHIFTIN2 =>SHIFT2_ISER, 
                                BITSLIP =>IBSLIP,
                                CE1 => '1',
                                --CE2 =>'0',
                                D =>'0',
                                RST =>RESET 
                         );
------------------------------------------------------------------

	


end Behavioral;
