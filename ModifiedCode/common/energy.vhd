----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    12:14:50 07/05/2010 
-- Design Name: 
-- Module Name:    energy - Behavioral 
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.

library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.slow_ct_defs.all;
use work.telescope_conf.all;

--library fazia;
--================================================================================
entity Energy is
  generic (
    RegAd : std_logic_vector(SC_AD_WIDTH-1 downto 0);
    DEFAULT_RISE      : integer;
    DEFAULT_PLATEAU   : integer;
    DEFAULT_PEAKING   : integer;
    DEFAULT_SHAPER_FLAT_WIDTH : integer
  );
  port (
    clk         : in  std_logic; -- horloge systÃ¨me
    reset       : in  std_logic;
    ---
    eRdyPort    : out std_logic; -- fin de peaking
    eReset      : in  std_logic; -- raz track & hold
	 riseTimeOut : out std_logic_vector (9 downto 0);
    energy      : out std_logic_vector(ENER_WIDTH-1 downto 0);     -- Ã©nergie peakÃ©e
    streamIn    : in  std_logic_vector(ADC_TOP downto 0); -- l'ADC aprÃ¨s demux
    streamOut   : out std_logic_vector(ENER_WIDTH-1 downto 0);
    trigSlow    : out std_logic;  -- sortie du comparateur "lent"
    ---
    timer       : in  std_logic;
    ---
    slowCtBus   : in  SlowCtBusRec;
    slowCtBusRd : out std_logic_vector(15 downto 0)
  );
end energy;

--================================================================================
architecture Behavioral of energy is

-- signaux =======================================================================

signal filteredStream : std_logic_vector (ENER_SHAPER_OUT_WIDTH-1 downto 0);
--signal decodRise, decodPlat : std_logic;
signal peakingCnt     : std_logic_vector (DEFAULT_SHAPER_FLAT_WIDTH-1 downto 0); 
signal peaked, oldPeaked, timeToPeak : std_logic;

-- registres ------------------------------------------------------------------------------------

signal levelSlowReg   : std_logic_vector (15 downto 0);
signal energyAccu     : std_logic_vector (ENER_SHAPER_OUT_WIDTH-1 downto 0); -- track & hold
signal peakingReg     : std_logic_vector (DEFAULT_SHAPER_FLAT_WIDTH-1 downto 0); 
-- les parametres du shaper sont memorises ici et connectes directement
signal shaperRise     : std_logic_vector (9 downto 0);
signal shaperFlat     : std_logic_vector (DEFAULT_SHAPER_FLAT_WIDTH-1 downto 0);
signal status         : std_logic_vector(ENER_STATUS_BITS-1 downto 0);
signal eRdy           : std_logic;
signal trigSlowLocal  : std_logic;

--===== chipscope =============================================================================
signal all_zero_80 : std_logic_vector (79 downto 0) := (others => '0');
signal CONTROL0 : std_logic_vector (35 downto 0);

component tel_ila_blknrj
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK     : IN STD_LOGIC;
    TRIG0   : IN STD_LOGIC_VECTOR(79 DOWNTO 0)
  );
end component;

component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
end component;

begin

--===== chipscope ===============================================================================
makeCS: if chip_ener and (RegAd = QL1_SC + ENERGY_SC) generate

mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0
  );

mes_sondes : tel_ila_blknrj
  port map (
    CONTROL => CONTROL0,
    CLK     => clk,
    ---
    trig0 (0) => peaked,
    trig0 (1) => oldPeaked,
    trig0 (2) => timeToPeak,
    trig0 (3) => eRdy,
    trig0 (4) => trigSlowLocal,
    trig0 (15 downto 5)  => all_zero_80(15 downto 5),
    trig0 (39 downto 16) => filteredStream,
    trig0 (63 downto 40) => energyAccu,
    trig0 (79 downto 64) => levelSlowReg
 );
end generate;

--===============================================================================================
eRdyPort <= eRdy;
--trigSlow <= '1' when filteredStream(15 downto 0) > levelSlowReg else '0';
energy     <= energyAccu;
streamOut  <= filteredStream;
timeToPeak <= peaked and not oldPeaked; -- un coup à la montée de peaked
trigSlow   <= trigSlowLocal;

-- instantiation du shaper
formeur: entity work.shaper
  generic map (
    INPUT_WIDTH  => ADC_DATA_W, -- 14 bit signe compris
    OUTPUT_WIDTH => ENER_SHAPER_OUT_WIDTH,
    SHAPER_FLAT_WIDTH => DEFAULT_SHAPER_FLAT_WIDTH )
  port map (
    clk       => clk,
    reset     => reset,
    ---
    input     => streamIn(ADC_DATA_W-1 downto 0),
    output    => filteredStream,
    ---
    rise      => shaperRise, -- montée
    flat      => shaperFlat, -- montée + plateau
    ---
    timer     => timer);
    
-- Track & Hold --------------------------------------
trackAndHoldP: process (clk, reset)
variable levelExtention : std_logic_vector(ENER_SHAPER_OUT_WIDTH-16 downto 0);
variable levelTotal : std_logic_vector(ENER_SHAPER_OUT_WIDTH downto 0);
variable energyMax : std_logic_vector (ENER_SHAPER_OUT_WIDTH-1 downto 0);

begin
   if reset = '1' then
      energyAccu <= (others => '0');
      peakingCnt <= (others => '0');
      eRdy <= '0';
      peaked <= '0';
      trigSlowLocal <= '0'; -- ce signal est maintenant mémorisé au moment du peaking
      energyMax := X"000000"; -- start value 
   elsif rising_edge(clk) then
      eRdy <= '0';
      oldPeaked <= peaked;
      if eReset = '1' then -- ne doit durer qu'un clock
		   riseTimeOut   <= (others => '0');
         energyAccu    <= (others => '0');
         peakingCnt    <= (others => '0');
         peaked        <= '0';
			trigSlowLocal <= '0';
         energyMax := X"000000";
      else
         if peakingReg = 0 then -- peak detection : search of the filter output maximum value
            if peakingCnt = shaperFlat then -- search time is reached
               peaked <= '1'; -- ce signal permet de ne mémoriser l'énergie qu'une seule fois
               eRdy   <= '1'; -- compte atteint, on valide et on n'incrémente plus peakingCnt
					riseTimeOut <= shaperRise;  -- on mémorise le temps de montée correspondant pour la normalisation ultérieure
               if peaked = '0' then
                  energyAccu <= energyMax; -- deliver the memorised maximum signal value
                  if levelSlowReg(15) = '0' then
                     levelExtention := (others => '0');
                  else
                     levelExtention := (others => '1');
                  end if;
                  levelTotal := levelExtention & levelSlowReg;
                  if signed(filteredStream) > signed(levelTotal) then
                     trigSlowLocal <= '1';
                  end if;
               end if;
            else
               if filteredStream > energyMax then -- look for the filter output maximum value
                  energyMax := filteredStream;
               end if;  
               peakingCnt <= peakingCnt + 1; -- counter increment as long as searchMaxTime is not reached
            end if;
         else
            if peakingCnt = peakingReg then -- peakingCnt plafonne (et reste) à peakingReg
               peaked <= '1'; -- ce signal permet de ne mémoriser l'énergie qu'une seule fois
               eRdy   <= '1'; -- compte atteint, on valide et on n'incrémente plus peakingCnt
					riseTimeOut <= shaperRise; -- on mémorise le temps de montée correspondant pour la normalisation ultérieure
               if peaked = '0' then
                  energyAccu <= filteredStream; -- peaking de l'énergie
                  if levelSlowReg(15) = '0' then
                     levelExtention := (others => '0');
                  else
                     levelExtention := (others => '1');
                  end if;
                  levelTotal := levelExtention & levelSlowReg;
                  if signed(filteredStream) > signed(levelTotal) then
                     trigSlowLocal <= '1';
                  end if;
               end if;
            else
               peakingCnt <= peakingCnt + 1;
            end if;
         end if;
      end if;
   end if;
end process;

-------------------------------------------------------------------------------------------------
--    Gestion des registres
-------------------------------------------------------------------------------------------------

regLoad: process (clk, reset, slowCtBus)
variable decod : std_logic;
variable lowerField : std_logic_vector(LEV_EN_FLD-1 downto 0); -- pour faciliter le décodage

begin
  if slowCtBus.addr(SC_AD_WIDTH-1 downto LEV_EN_FLD) = RegAd(SC_AD_WIDTH-1 downto LEV_EN_FLD)
  then decod := '1';
  else decod := '0';
  end if;
  lowerField := slowCtBus.addr(LEV_EN_FLD-1 downto 0);
  
  if reset = '1' then
    levelSlowReg <= conv_std_logic_vector(DEFAULT_LEVEL_SLOW, 16);
    peakingReg   <= conv_std_logic_vector(DEFAULT_PEAKING, DEFAULT_SHAPER_FLAT_WIDTH);
    shaperRise   <= conv_std_logic_vector(DEFAULT_RISE, 10);    -- montée
    shaperFlat   <= conv_std_logic_vector(DEFAULT_PLATEAU, DEFAULT_SHAPER_FLAT_WIDTH); -- montée + plateau
    status       <= (others => '0');
  elsif rising_edge(clk) then
   slowCtBusRd <= (others => '0'); -- slowCtBusRd est un registre clocké par clk
   if timeToPeak = '1' then status(ENER_RDY) <= '1'; end if;
   if slowCtBus.wr = '1' and decod = '1' then
      case lowerField is
        when LEVEL_SLOW    => levelSlowReg <= slowCtBus.data;
        when ENER_RISE_REG => shaperRise   <= slowCtBus.data(9 downto 0); -- montée
        when ENER_PLAT_REG => shaperFlat   <= slowCtBus.data(DEFAULT_SHAPER_FLAT_WIDTH-1 downto 0); -- montée + plateau
        when PEAKING_REG   => peakingReg   <= slowCtBus.data(DEFAULT_SHAPER_FLAT_WIDTH-1 downto 0);
        when others => null;
      end case;
    elsif slowCtBus.rd = '1' and decod = '1' then
      case lowerField is
        when ENERGY_REG_H =>
          for i in ENER_SHAPER_OUT_WIDTH-16 to 15 loop
            slowCtBusRd(i) <= energyAccu(ENER_SHAPER_OUT_WIDTH-1); -- bit de signe
          end loop;
          slowCtBusRd(ENER_SHAPER_OUT_WIDTH-16-1 downto 0) <= energyAccu(ENER_SHAPER_OUT_WIDTH-1 downto 16);
          status(ENER_RDY) <= '0'; -- raz bit 'énergie ready'
        when ENERGY_REG_L  => slowCtBusRd <= energyAccu(15 downto 0);
        when LEVEL_SLOW    => slowCtBusRd <= levelSlowReg;
        when ENER_RISE_REG => slowCtBusRd(9 downto 0) <= shaperRise; -- montée
        when ENER_PLAT_REG => slowCtBusRd(DEFAULT_SHAPER_FLAT_WIDTH-1 downto 0) <= shaperFlat; -- montée + plateau
        when PEAKING_REG   => slowCtBusRd(DEFAULT_SHAPER_FLAT_WIDTH-1 downto 0) <= peakingReg;
        when ENER_STATUS   => slowCtBusRd(ENER_STATUS_BITS-1 downto 0) <= status;
        when others => null;
      end case;
    end if;
  end if;
end process regLoad;

end Behavioral;

