----------------------------------------------------------------------------------
-- Company:  IPN Orsay
-- Engineer: Pierre EDELBRUCK
-- 
-- Create Date:    12:51:32 07/05/2010 
-- Design Name:    telescope
-- Module Name:    e_trigger - Behavioral 
-- Project Name:   Fazia
-- Target Devices: virtex-5
-- Tool versions:  11.1
-- Description: Dans un premier temps (29-10-2010) un simple seuil programmable
-- sur les deux sorties, directement sur le flux d'entr√©e, sans shaping
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
-- ne pas utiliser les deux biblioth√®ques qui suivent. utiliser ieee.std_logic_arith
-- et caster au moyen de signed(...) et unsigned(...). ceci permet notamment de m√©langer
-- les deux arithm√©tiques.
--use IEEE.STD_LOGIC_UNSIGNED.ALL;
--use ieee.std_logic_signed.all;

library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.slow_ct_defs.all;

--================================================================================
entity ETrigger is
  generic (RegAd : std_logic_vector(15 downto 0));
  port (
    clk        : in  std_logic;        
    reset      : in  std_logic;
    ---
    streamIn   : in  std_logic_vector(ADC_TOP downto 0);                 -- ADC after demux
    streamOut  : out std_logic_vector(TRIG_SHAPER_OUT_WIDTH-1 downto 0); -- after shaping
    avgBaseOut : out std_logic_vector(ADC_TOP+BL_PRECISION_BITS downto 0);
    ---
    trigFastH  : out std_logic;  -- high fast trigger output;  
    trigFastL  : out std_logic;  -- low fast trigger output;
    ---
    timer      : in  std_logic;
    ---
    slowCtBus  : in  slowCtBusRec;
    slowCtBusRd: out std_logic_vector(15 downto 0)
  );
end ETrigger;

--================================================================================
architecture Behavioral of ETrigger is

-- signals =======================================================================
signal filteredStream : std_logic_vector(TRIG_SHAPER_OUT_WIDTH-1 downto 0);
--signal decodRise, decodPlat : std_logic;

-- trigger threshold registers
signal levelLFastReg : std_logic_vector(15 downto 0);
signal levelHFastReg : std_logic_vector(15 downto 0);
-- control register
signal trigCtrl : std_logic_vector(TRIG_CTRL_BITS-1 downto 0);
-- les parametres du shaper sont memorisÈs ici et connectÈs directement
signal shaperRise, shaperFlat : std_logic_vector (9 downto 0);
signal fastCounter : unsigned (9 downto 0);
signal oldTrigFastL, trigFastL_internal : std_logic;
signal invalidTrigH : std_logic;
signal startTrigCount : boolean;

signal basePretrig : std_logic_vector (7 downto 0);
signal baseMeanDepth : std_logic_vector (8 downto 0);
signal baseCalcOut : std_logic_vector (ADC_TOP+BL_PRECISION_BITS downto 0);

constant AD1 : std_logic_vector(SC_AD_WIDTH-1 downto 0) := RegAd or ("000000000000" & LEVEL_L_FAST);
constant AD2 : std_logic_vector(SC_AD_WIDTH-1 downto 0) := RegAd or ("000000000000" & LEVEL_H_FAST);

-- body --------------------------------------------------------------------------
begin
streamOut <= filteredStream;

-- instantiation of shaper
formeur: entity work.shaper
  generic map (
    INPUT_WIDTH  => ADC_DATA_W,
    OUTPUT_WIDTH => TRIG_SHAPER_OUT_WIDTH,
	 SHAPER_FLAT_WIDTH => TRIG_SHAPER_FLAT_WIDTH)
  port map (
    clk       => clk,
    reset     => reset,
    ---
    input     => streamIn,
    output    => filteredStream,
    ---
    rise      => shaperRise,
    flat      => shaperFlat,
    ---
    timer     => timer);
---------------------------------------

-- instantiation of baseline calculation	 
baseMean : entity work.baseline	
   port map( 
      clk         => clk,
      reset       => reset,

      pretrig     => basePretrig,              -- nb of samples before the fast low trigger comparator output
      meanDepth   => baseMeanDepth,            -- nb of samples for baseline mean calculation	
                                               -- should be (a multiple of 2-1) to do the division with a right shift														  		
      din         => streamIn,																				  
      dout        => baseCalcOut);

-- comparateurs synchrones

lowComparator_internal: process (clk)
begin
   if rising_edge(clk) then
      if signed(filteredStream(TRIG_SHAPER_OUT_WIDTH-1 downto TRIG_SHAPER_OUT_WIDTH-16)) > signed(levelLFastReg) then
         trigFastL_internal  <= not trigCtrl(BIT_INV);      -- '1'
      else
         trigFastL_internal  <= trigCtrl(BIT_INV);          -- '0'
      end if;
   end if;
end process lowComparator_internal;

highComparator: process (clk)
begin
   if rising_edge(clk) then
      oldTrigFastL <= trigFastL_internal;	
      if startTrigCount = false then
         trigFastL      <= '0';
         trigFastH      <= '0';
         invalidTrigH   <= '0';
         if oldTrigFastL = '0' and trigFastL_internal = '1' then
            fastCounter   <= (others => '0');
            startTrigCount <= true;
            avgBaseOut <= baseCalcOut;
			end if;
      elsif startTrigCount = true then
            if fastCounter < unsigned(shaperRise) then
               fastCounter <= fastCounter + 1;
               if signed(filteredStream(TRIG_SHAPER_OUT_WIDTH-1 downto TRIG_SHAPER_OUT_WIDTH-16)) > signed(levelHFastReg) then 
                  invalidTrigH <= '1';					   -- levelHFastReg overflow detector 
               end if;				
            elsif fastCounter = unsigned(shaperRise) then
                  trigFastL <= '1';
                  trigFastH <= not(invalidTrigH);     -- '1' if there was no overflow of the levelHFastReg during shaperRise time
                  startTrigCount <= false;            -- being counted from the rising edge of trigFastL_internal
            end if;																	
      end if;			  
   end if;	
end process highComparator;

--<==================== prototype dÈcodeur ====================>
regLoad: process (clk, reset, slowCtBus.addr)
variable decod : std_logic;
variable lowerField : std_logic_vector(LEV_FAST_FLD-1 downto 0); -- pour faciliter le dÈcodage

begin
  if slowCtBus.addr(SC_AD_WIDTH-1 downto LEV_FAST_FLD) = RegAd(SC_AD_WIDTH-1 downto LEV_FAST_FLD)
  then decod := '1';
  else decod := '0';
  end if;
  lowerField := slowCtBus.addr(LEV_FAST_FLD-1 downto 0);

  if reset = '1' then
    levelLFastReg <= conv_std_logic_vector(DEFAULT_LEVEL_L, 16);
    levelHFastReg <= conv_std_logic_vector(DEFAULT_LEVEL_H, 16);
    shaperRise    <= conv_std_logic_vector(DEFAULT_TRIG_RISE, 10);
    shaperFlat    <= conv_std_logic_vector(DEFAULT_TRIG_PLATEAU, 10);
    trigCtrl      <= (others => '0');
    basePretrig   <= conv_std_logic_vector(BL_DEFAULT_PRETRIG, 8);
    baseMeanDepth <= conv_std_logic_vector(BL_DEFAULT_MDEPTH, 9);
  elsif rising_edge(clk) then
    slowCtBusRd <= (others => '0');
    if slowCtBus.wr = '1' and decod = '1' then
      case lowerField is
        when LEVEL_L_FAST   => levelLFastReg <= slowCtBus.data;
        when LEVEL_H_FAST   => levelHFastReg <= slowCtBus.data;
        when TRIG_RISE_REG  => shaperRise    <= slowCtBus.data(9 downto 0);
        when TRIG_PLAT_REG  => shaperFlat    <= slowCtBus.data(9 downto 0);
        when TRIG_CTRL_REG  => trigCtrl      <= slowCtBus.data(TRIG_CTRL_BITS-1 downto 0);
        when BL_PRETRIG_REG => basePretrig   <= slowCtBus.data(7 downto 0);
        when BL_MDEPTH_REG  => baseMeanDepth <= slowCtBus.data(8 downto 0);
        when others => null;
      end case;
    elsif slowCtBus.rd = '1' and decod = '1' then
      case lowerField is
        when LEVEL_L_FAST   => slowCtBusRd <= levelLFastReg;
        when LEVEL_H_FAST   => slowCtBusRd <= levelHFastReg;
        when TRIG_RISE_REG  => slowCtBusRd(9 downto 0) <= shaperRise;
        when TRIG_PLAT_REG  => slowCtBusRd(9 downto 0) <= shaperFlat;
        when BL_PRETRIG_REG => slowCtBusRd(7 downto 0) <= basePretrig;
        when BL_MDEPTH_REG  => slowCtBusRd(8 downto 0) <= baseMeanDepth;
        when others => null;
      end case;
    end if;
  end if;
end process regLoad;
--<=============================================================>
end Behavioral;

