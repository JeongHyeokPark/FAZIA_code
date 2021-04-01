----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    13:23:41 05/03/2012 
-- Design Name: 
-- Module Name:    GlobalTrigger - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: Un petit module qui remplit la fonction de global trigger, pour le test
-- de la carte en stand alone uniquement. Cette fonction est normalement assurée par la
-- blockcard. Le paramètre 'LATENCY' permet de programmer un timer (fixe) entre l'arrivée
-- d'une requête (A ou B) et la délivrance d'une validation.
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
-------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use ieee.std_logic_unsigned.all; -- pour le compteur
use work.tel_defs.all;

--library UNISIM;
--use UNISIM.VComponents.all;

--===============================================================================================
entity GlobalTrigger is
  port (
    clk          : in  std_logic;
    reset        : in  std_logic;
    ltA          : in  std_logic;
    ltB          : in  std_logic;
    localWaitOut : in std_logic;
    glt          : out std_logic
  );
end GlobalTrigger;

--===============================================================================================
architecture Behavioral of GlobalTrigger is

constant LATENCY : integer := 40; -- 40 coups = 400 ns
constant LAT_BITS : integer := bits(LATENCY);
signal timer : std_logic_vector (LAT_BITS-1 downto 0);

type etat is (IDLE, LATENT, HOLD, ACQUIT);
signal state : etat;

begin

machine: process (clk, reset)
begin
  if reset = '1' then
    state <= IDLE;
    glt <= '0';
  elsif rising_edge(clk) then
    case state is
    -----------------------
    when IDLE   =>
      if ltA = '1' or ltB = '1' then
        timer <= conv_std_logic_vector(LATENCY, LAT_BITS);
        state  <= LATENT;
      end if;
    -----------------------
    when LATENT => -- délai fixe avant de délivrer la validation
      if timer = 0 then
        if localWaitOut = '0' then
          state <= IDLE;
        else
          glt   <= '1';
          state <= ACQUIT;
          timer <= conv_std_logic_vector(5, LAT_BITS); -- on va faire durer un peu le global trigger
        end if;
      else
        timer <= timer - 1;
      end if;
    -----------------------
    when ACQUIT => -- on attend l'extinction de la demande
      if timer /= 0 then
        timer <= timer - 1;
      elsif ltA = '0' and ltB = '0' then
        glt <= '0';
        state <= IDLE;
      end if;
    -----------------------
    when others => state <= IDLE;
    -----------------------
    end case;
  end if;
end process machine;
end Behavioral;

