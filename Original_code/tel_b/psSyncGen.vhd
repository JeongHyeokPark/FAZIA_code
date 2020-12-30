-------------------------------------------------------------------------------------------------
-- Module Name:                          PsSyncGen
-------------------------------------------------------------------------------------------------
-- Company: IPNOrsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date: 28/09/2012
-- Design Name:
-- Project Name: Fazia
-- Target Devices: Virtex-5
-- Tool versions:  12.4
-- Description: Module de configuration des générateurs de synchro des alimentations
-- Deux compteurs main1 et main2. Tous deux comptent de 0 à psPeriod, ils sont décalés
-- d'une demi période. Chaque sortie monte quand main1 atteint la phase programmée
-- et redescend quand main2 atteint la phase programmée. La sortie reste au repos
-- si psPeriod = 0. La plage de réglage va de 2 (50 MHz) à 255 (1000000/2550 = 392 kHz)

--
-- Dependencies: 
--
-- Revision: 
--
---------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

use work.tel_defs.all;
use work.slow_ct_defs.all;

--===============================================================================
entity PsSyncGen is
  generic (
    RegAd : std_logic_vector(SC_AD_WIDTH-1 downto 0) -- adresse absolue
  );
	port (
    clk         : in  std_logic;
    reset       : in  std_logic;
    ---
    sync_vp2_5  : out std_logic;
    sync_vp3_7  : out std_logic;
    sync_vm2_7  : out std_logic;
    sync_hv     : out std_logic;
    ---
    slowCtBus   : in  SlowCtBusRec;
    slowCtBusRd : out std_logic_vector(SC_AD_WIDTH-1 downto 0)
  );
end PsSyncGen;

--===============================================================================
architecture Behavioral of PsSyncGen is

-- signaux ---------------------------------------------

constant TIMER_BITS : integer := 8;
signal main1       : std_logic_vector (TIMER_BITS-1 downto 0); -- le compteur de période suffisant pour 2550 ns = 392 kHz
signal main2       : std_logic_vector (TIMER_BITS-1 downto 0);
signal main1Hv     : std_logic_vector (TIMER_BITS-1 downto 0); -- le compteur de période suffisant pour 2550 ns = 392 kHz
signal main2Hv     : std_logic_vector (TIMER_BITS-1 downto 0);
signal psPeriod    : std_logic_vector (TIMER_BITS-1 downto 0); -- le registre de période
signal psPeriodHv  : std_logic_vector (TIMER_BITS-1 downto 0); -- le registre de période
signal psPhase25   : std_logic_vector (TIMER_BITS-1 downto 0); -- le registre de phase 2.5 V
signal psPhase37   : std_logic_vector (TIMER_BITS-1 downto 0); -- le registre de phase 3.7 V
signal psPhase27   : std_logic_vector (TIMER_BITS-1 downto 0); -- le registre de phase -2.7 V
signal psPhaseHv   : std_logic_vector (TIMER_BITS-1 downto 0); -- le registre de phase hautes tensions

begin



compteurs: process (clk, reset)
begin
  if reset = '1' then
    main1 <= (others => '0'); -- compteur principal
    main2 <= '0' & psPeriod(TIMER_BITS-1 downto 1); -- compteur décalé d'une demi période
	 main1Hv <= (others => '0'); -- compteur principal
    main2Hv <= '0' & psPeriodHv(TIMER_BITS-1 downto 1); -- compteur décalé d'une demi période
    sync_vp2_5  <= '0';
    sync_vp3_7  <= '0';
    sync_vm2_7  <= '0';
    sync_hv     <= '0';
  elsif rising_edge(clk) then
    if psPeriod /= 0 then -- si comptage autorisé
      -- compteur principal
      if main1 = psPeriod then main1 <= (others => '0');
      else main1 <= main1+1; end if;
      -- compteur secondaire décalé d'une demi période
      if main1 = '0' & psPeriod(TIMER_BITS-1 downto 1) then main2 <= (others => '0');
      else main2 <= main2+1; end if;
		
		-- compteur principal
      if main1Hv = psPeriodHv then main1Hv <= (others => '0');
      else main1Hv <= main1Hv+1; end if;
      -- compteur secondaire décalé d'une demi période
      if main1Hv = '0' & psPeriodHv(TIMER_BITS-1 downto 1) then main2Hv <= (others => '0');
      else main2Hv <= main2Hv+1; end if;
		
      -- toutes les sorties
      if main1 = psPhase25 then sync_vp2_5  <= '1'; end if;
      if main1 = psPhase37 then sync_vp3_7  <= '1'; end if;
      if main1 = psPhase27 then sync_vm2_7  <= '1'; end if;
      if main1Hv = psPhasehv then sync_hv     <= '1'; end if;
      
      if main2 = psPhase25 then sync_vp2_5  <= '0'; end if;
      if main2 = psPhase37 then sync_vp3_7  <= '0'; end if;
      if main2 = psPhase27 then sync_vm2_7  <= '0'; end if;
      if main2Hv = psPhasehv then sync_hv     <= '0'; end if;
    else
      main1 <= (others => '0');
      main2 <= (others => '0');
		main1Hv <= (others => '0');
      main2Hv <= (others => '0');
      sync_vp2_5  <= '0';
      sync_vp3_7  <= '0';
      sync_vm2_7  <= '0';
      sync_hv     <= '0';
    end if;
  end if;
end process compteurs;

--------------------------------------------------------------------------------------------------
regLoad: process (clk, reset)
variable decod : std_logic;
begin
  -- chip-select du module
  if slowCtBus.addr(SC_AD_WIDTH-1 downto LMK_FIELD)
          = RegAd(SC_AD_WIDTH-1 downto LMK_FIELD) then
    decod := '1';
  else
    decod := '0';
  end if;
  
  if reset = '1' then
    psPeriod  <= conv_std_logic_vector(200, TIMER_BITS); -- 200 --> 2000 ns = 2 µs ==> 500 kHz
    psPeriodHv <= conv_std_logic_vector(500, TIMER_BITS); -- 500 --> 5000 ns ==> 200kHz
    psPhase25 <= (others => '0');
    psPhase37 <= (others => '0');
    psPhase27 <= (others => '0');
    psPhaseHv <= (others => '0');
  elsif rising_edge(clk) then
    slowCtBusRd <= (others => '0');
    if decod = '1' and slowCtBus.wr = '1' then
      case slowCtBus.addr(PS_FIELD-1 downto 0) is
        when PS_PERIOD      => psPeriod   <= slowCtBus.data(TIMER_BITS-1 downto 0);
		  when PS_PERIODHV    => psPeriodHv <= slowCtBus.data(TIMER_BITS-1 downto 0);
        when PS_PHASE_VP2_5 => psPhase25  <= slowCtBus.data(TIMER_BITS-1 downto 0);
        when PS_PHASE_VP3_7 => psPhase37  <= slowCtBus.data(TIMER_BITS-1 downto 0);
        when PS_PHASE_VM2_7 => psPhase27  <= slowCtBus.data(TIMER_BITS-1 downto 0);
        when PS_PHASE_HV    => psPhaseHv  <= slowCtBus.data(TIMER_BITS-1 downto 0);
        when others     => null;
      end case;
    elsif decod = '1' and slowCtBus.rd = '1' then
      case slowCtBus.addr(PS_FIELD-1 downto 0) is
        when PS_PERIOD      => slowCtBusRd(TIMER_BITS-1 downto 0) <= psPeriod;
		  when PS_PERIODHV    => slowCtBusRd(TIMER_BITS-1 downto 0) <= psPeriodHv;
        when PS_PHASE_VP2_5 => slowCtBusRd(TIMER_BITS-1 downto 0) <= psPhase25;
        when PS_PHASE_VP3_7 => slowCtBusRd(TIMER_BITS-1 downto 0) <= psPhase37;
        when PS_PHASE_VM2_7 => slowCtBusRd(TIMER_BITS-1 downto 0) <= psPhase27;
        when PS_PHASE_HV    => slowCtBusRd(TIMER_BITS-1 downto 0) <= psPhaseHv;
        when others     => null;
      end case;
    end if;
  end if;
end process regLoad;


end;

