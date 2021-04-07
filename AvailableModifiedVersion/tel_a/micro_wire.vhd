---------------------------------------------------------------------------------
-- Module Name:                      micro_wire
---------------------------------------------------------------------------------
-- Company: IPNOrsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date: 25/05/2010
-- Design Name: fpga_com
-- Project Name: Fazia
-- Module name: MicroWire
-- Target Devices: 
-- Tool versions: 
-- Description: Sérialiseur 32-bit vers microwire. Prend en entrée le mot 32-bit
-- à émettre et l'adresse du port (0 ou 1). Génère donnée, horloge et
-- chip select (uWire1 pour adresse=0 et uWire2 pour adresse=1). Signale la fin
-- de l'opération en montant done.
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
---------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--===============================================================================
entity MicroWire is
-- generic (scaling : std_logic_vector(1 downto 0)); -- le ratio entre les fréquences clk et ckUWire
  generic (scaling : integer); -- le ratio entre les fréquences clk et ckUWire
  port (
    clk       : in  std_logic;
    resetIn   : in  std_logic;
    dataIn    : in  std_logic_vector(31 downto 0);
    adIn      : in  std_logic; -- le numéro de chip LMK (0 ou 1)
    send      : in  std_logic; -- ordre de sérialisation
    done      : out std_logic;
    uWire1    : out std_logic;
    uWire2    : out std_logic;
    ckUWire   : out std_logic;
    dataUWire : out std_logic);
end MicroWire;

--===============================================================================
architecture Behavioral of MicroWire is

--signal bit_ct     : std_logic_vector(4 downto 0); -- compteur de bits du sérialisateur
signal razBitCt : std_logic;
signal incBitCt : std_logic;
signal maxBit    : std_logic;
--signal pre_scaler : std_logic_vector(1 downto 0); -- pour diviser l'horloge au + par 4
signal runPre    : std_logic;
signal razPre    : std_logic;
signal lowCk     : std_logic; -- l'horloge issue de presclarer (dure 1 coup de clk)
signal shiftReg  : std_logic_vector(31 downto 0);

signal shift_load : std_logic; -- commande de chargement parallèle du registre
type   MwState is (IDLE, PREAMB, SERIALIZE_0, SERIALIZE_1, WAIT_SEND_0, POSTAMB);
signal mwCs, mwFs : MwState := IDLE;

--================================================================================
begin

scaler: entity work.Compteur
	generic map (WIDTH => 2, modulo => scaling)
	port map (
    clk   => clk,
    reset => resetIn,
    raz   => razPre,
    carry => lowCk,
    incr  => runPre);
				 
-------------------------------------------
-- le compteur de bits
ctbits: entity work.Compteur
  generic map (WIDTH => 5, modulo => 32)
  port map (
    clk   => clk,
    reset => resetIn,
    raz   => razBitCt,
    carry => maxBit,
    incr  => incBitCt);

---------------------------------------------------
-- le registre à décalage commandé par le
-- bit d'incrémentation du compteur
decaler: process(clk)
begin
  if rising_edge(clk) then
    if shift_load = '1' then
      shiftReg <= dataIn;
    elsif incBitCt = '1' then
      shiftReg <= shiftReg(30 downto 0) & '0';
    end if;
  end if;
end process;

---------------------------------------------------
-- machine d'état
-- le process séquentiel

sm_seq: process (clk, resetIn)
begin
  if resetIn = '1' then
    mwCs <= IDLE;
  elsif rising_edge(clk) then
    mwCs <= mwFs;
  end if;
end process;

-- le process combinatoire --------------------------------------------
--type   MwState is (IDLE, PREAMB, SERIALIZE_0, SERIALIZE_1, WAIT_SEND_0, POSTAMB);

sm_comb: process (mwCs, send, lowCk, maxBit, adIn, shiftReg)
begin
  --- init par défaut ---
  ckUWire    <= '0';
  dataUWire  <= shiftReg(31); -- la sortie série du registre
  mwFs       <= mwCs; -- pas de changement d'état
  razPre     <= '0';
  runPre     <= '1'; -- le presacaler tourne
  razBitCt   <= '0';
  incBitCt   <= '0';
  done       <= '0';
  shift_load <= '0';
  uWire1     <= '0';
  uWire2     <= '0';
  ---------------------------------------------------------------------
  case mwCs is
	-----------------------
	when IDLE =>
      runPre <= '0';      -- si IDLE, bloquer le prescaler
      if send = '1' then
        mwFs <= PREAMB;
      else
        dataUWire <= '0';  -- pour une sortie clean au repos, sinon
      end if;              -- c'est par défaut la sortie du registre à décalage
      -----------------------
	when PREAMB =>
      if lowCk = '1' then -- attente prescaler
        razBitCt <= '1'; -- initialiser le compteur de bits
        mwFs <= SERIALIZE_0;
        shift_load <= '1';
      end if;
      -----------------------
	when SERIALIZE_0 =>
      if lowCk = '1' then
        mwFs <= SERIALIZE_1;
      end if;
      -----------------------
	when SERIALIZE_1 =>
      ckUWire <= '1';       -- un coup de clock en sortie
      if lowCk = '1' then
        incBitCt <= '1';
        if maxBit = '1' then
          mwFs <= POSTAMB;
        else
          mwFs <= SERIALIZE_0;
        end if;
      end if;
      -----------------------
	when POSTAMB =>
      if adIn = '0' then -- un coup de clock parallèle
        uWire1 <= '1';
      else
        uWire2 <= '1';
      end if;

      if lowCk = '1' then
        mwFs <= WAIT_SEND_0;
      end if;
      -----------------------
	when WAIT_SEND_0 =>
      done <= '1';
      if lowCk = '1' then -- done dure un coup d'horloge divisée
        razPre <= '1';
        mwFs <= IDLE;
      end if;
	-----------------------
	when others =>
      mwFs <= IDLE;
      -----------------------
  end case;
end process;
-------------------------------------------

end Behavioral;

