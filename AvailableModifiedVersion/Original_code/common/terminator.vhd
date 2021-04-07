----------------------------------------------------------------------------------
-- Company:        IPNO
-- Engineer:       Pierre Edelbruck
-- 
-- Create Date:    09:19:47 23/09/2011 
-- Design Name: 
-- Module Name:    Terminator - Behavioral 
-- Project Name:   Fazia
-- Target Devices: Virtex-5
-- Tool versions:  ISE 12.4
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
-------------------------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use work.tel_defs.all;

entity Terminator is
  port (
    clk        : in   std_logic;
    reset      : in   std_logic;
    clear      : in  std_logic;
    --
    dataOut    : out  std_logic_vector (DATA_WITH_TAG-1 downto 0);
    acqBusyOut : out std_logic;
    throttle   : in   std_logic;
    readIn     : in   std_logic;
    doneOut    : out  std_logic
  );
end Terminator;

architecture Behavioral of Terminator is

type TermiState is (IDLE, UP, WAITING);
signal termiCs, termiFs : TermiState := IDLE;

-- le compteur de données
signal dataCnter : std_logic_vector(3 downto 0);
-- commandes d'initialisation et de décrémentation du compteur
signal initCnter, decCnter  : std_logic;

begin
dataOut  <= NO_DATA; -- pour fermer le dernier module proprement
--dataOut  <= "10" & x"AA"; -- pour tester

acqBusyOut <= '0';

-------------------------------------------------------------------------------------------------
machineSeq: process (clk, reset, clear)
begin
  if reset = '1' or clear = '1' then
    termiCs   <= IDLE;
    dataCnter <= (others => '0');
  elsif rising_edge(clk) then
    if clear = '1' then
      termiCs <= IDLE;
    else
      termiCs <= termiFs;
    end if;
    if initCnter = '1' then
      dataCnter <= x"2";
    end if;
    if throttle = '1' and decCnter = '1' then -- rien n'avance si throttle = 0 (throttle)
      dataCnter <= unsigned(dataCnter) - 1;
    end if;
  end if;
end process machineSeq;

-----------------------------------------------------------------------
machineComb: process (termiCs, dataCnter, readIn)
begin
  termiFs   <= termiCs;
  doneOut   <= '0';
  decCnter  <= '0';
  initCnter <= '0';
  ----------------------
  case termiCs is
  ----------------------
  when IDLE =>
    if readIn = '1' then
      termiFs <= UP;
      --termiFs <= WAITING;
    else
      initCnter <= '1'; -- le compteur doit être prêt avant de commencer
    end if;
  ----------------------
  when UP => -- délai avant de monter done
    decCnter <= '1';
    if dataCnter = x"0" then
      termiFs <= WAITING;
    end if;
  ----------------------
  when WAITING =>
    doneOut <= '1';
    if readIn = '0' then
      termiFs <= IDLE;
    end if;
  ----------------------
  end case;
end process machineComb;
end Behavioral;


