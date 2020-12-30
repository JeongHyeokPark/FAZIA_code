-------------------------------------------------------------------------------------------------
-- Company:  IPNO
-- Engineer: Pierre Edelbruck
-- 
-- Create Date: 26-11-2012
-- Design Name: telescope
--===============================================================================================
-- Module Name:                       ===== Gene =====
--===============================================================================================
-- File:   gene.vhd
-- Project Name:  Fazia
-- Target Devices: Virtex-5
-- Tool versions: 12.4
-- Description: Nouvelle version du pulser. Les deux paramÃ¨tres sont maintenant la pÃ©riode et
--              la durÃ©e. Il y a Ã©galement une entrÃ©e externe qui dÃ©clenche le pulser sur son
--              front montant.
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
--use IEEE.std_logic_ARITH.ALL;
use IEEE.std_logic_UNSIGNED.ALL;
use IEEE.std_logic_arith.ALL;

use work.tel_defs.all;
use work.slow_ct_defs.all;

--use UNISIM.VComponents.all;

entity Gene is
  port (
    clk       : in  std_logic;
    reset     : in  std_logic;
    ---
    trigExt   : in  std_logic;
    microsec  : in  std_logic;
    clkGene   : out std_logic;
    ---
    slowCtBus : in  SlowCtBusRec;
	 slowCtBusRd : out std_logic_vector(15 downto 0)
  );
end Gene;

architecture Behavioral of gene is

constant DURATION_BITS : integer := 16; -- maximum 65,535 ms
signal periodReg,    periodCt    : std_logic_vector (DURATION_BITS-1 downto 0); -- consigne et ct pulser bas  (us)
signal dureeHighReg, dureeHighCt : std_logic_vector (DURATION_BITS-1 downto 0); -- consigne et ct pulser haut (us)
signal trigExtOld  : std_logic;
signal trigInt     : std_logic;
signal oldMicrosec : std_logic;

type GeneState is (IDLE, BAS, HAUT);
signal geneCs : Genestate;

begin

-------------------------------------------------------------------------------------------------
-- le générateur local (récurrent) de période PULSER_PERIOD
freeRunProc: process (reset, clk)
begin
  if reset = '1' then
    periodCt    <= (others => '0');
  elsif rising_edge(clk) then
    trigInt     <= '0';
    oldMicrosec <= microsec;
    if periodReg /= 0 then -- si zéro, pulser local inactif
      if microsec = '1' and oldMicrosec = '0' then
        if periodCt = 0 then
          periodCt <= periodReg; -- rechargement du compteur
          trigInt  <= '1';       -- un coup de clk
        else
          periodCt <= periodCt -1;
        end if;
      end if;
    end if;
  end if;
end process freeRunProc;

-------------------------------------------------------------------------------------------------
-- le monostable déclenché par le géné local ou l'entrée externe (inclusivement)
monoProc: process (reset, clk)
begin
  if reset = '1' then
    dureeHighCt <= (others => '0');
    clkGene <= '0';
  elsif rising_edge(clk) then
    trigExtOld <= trigExt;
    if microsec = '1' and oldMicrosec = '0' then
      if dureeHighCt /= 0 then
        dureeHighCt <= dureeHighCt -1;
        clkGene <= '1';
      else
        clkGene <= '0';
      end if;
    end if;
      
    if trigInt = '1' or (trigExt = '1' and trigExtOld = '0') then
      clkGene <= '1';
      dureeHighCt <= dureeHighReg;
    end if;
  end if;
end process monoProc;

               
-- registres ------------------------------------------------------------------------------------
regLoad: process (clk, reset)
begin
  if reset = '1' then
    periodReg    <= (others => '0'); -- off par défaut
    dureeHighReg <= conv_std_logic_vector(DEFAULT_HIGH, DURATION_BITS);
  elsif rising_edge(clk) then
  
    slowCtBusRd <= (others => '0');
  
    if slowCtBus.wr = '1' then
      if slowCtBus.addr = PULSER_PERIOD then
        periodReg <= slowCtBus.data(DURATION_BITS-1 downto 0);
      elsif slowCtBus.addr = PULSER_HIGH then
        dureeHighReg <= slowCtBus.data(DURATION_BITS-1 downto 0);
      end if;
    end if;
	 
	 --partie programmée par Franck
	 if slowCtBus.rd = '1' then
	   if slowCtBus.addr = PULSER_PERIOD then
		  slowCtBusRd(DURATION_BITS-1 downto 0) <= periodReg;
		end if;
		if slowCtBus.addr = PULSER_HIGH then
		  slowCtBusRd(DURATION_BITS-1 downto 0) <= dureeHighReg;
		end if;
	 end if;
  end if;
end process;
end Behavioral;

