-------------------------------------------------------------------------------------------------
-- Module Name:                          TalkToLmk
-------------------------------------------------------------------------------------------------
-----0---|----1----|----2----|----3----|----4----|----5----|----6----|----7----|----8----|---9--|
-- Company: IPNOrsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date: 25/05/2010
-- Design Name: fpga_com
-- Project Name: Fazia
-- Target Devices: 
-- Tool versions: 
-- Description: Module de configuration des générateurs d'horloge LMK2000. S'active
-- automatiquement au reset général. Les données sont en ROM.
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

use work.tel_defs.all;
use work.slow_ct_defs.all;
--use work.com_defs.all;

--===============================================================================
entity TalkToLmk is
  generic (
    RegAd : std_logic_vector(SC_AD_WIDTH-1 downto 0) -- adresse absolue
  );
	port (
    clk       : in   std_logic; -- horloge à 25 MHz
    sysClk    : in   std_logic; -- horloge système à 100 MHz
    resetIn   : in   std_logic;
    ---
    uWire1    : out  std_logic;
    uWire2    : out  std_logic;
    ckUWire   : out  std_logic;
    dataUWire : out  std_logic;
    ---
    slowCtBus : in   SlowCtBusRec);
end TalkToLmk;

--===============================================================================
architecture Behavioral of TalkToLmk is

-- signaux ---------------------------------------------
signal lmkNr, chipCt, scChip:   std_logic;        -- 2 chips, 1 bit suffit
signal razChipCt, incChipCt:   std_logic;
signal razWordCt, incWordCt, maxWord:   std_logic;
signal romData, microwireData:  std_logic_vector(31 downto 0); -- liaison rom-sérialiseur
signal romAd:    std_logic_vector(4 downto 0);  -- adresse rom pour 32 mots max
signal razRomAd, incRomAd:   std_logic;
signal send, sendMan, sendAuto : std_logic;        -- ordre d'écriture
signal done:      std_logic;        -- micro_wire a fini (acquitement)
type RstMwState is (RESET_STATE, WAIT_DONE_1, WAIT_DONE_0, IDLE);
signal rstMwCs, rstMwFs : RstMwState := RESET_STATE;
-- écriture par le slowcontrol
constant AUTO : std_logic := '0';
constant MANU : std_logic := '1';
signal lmkRegister:  std_logic_vector(31 downto 0);
signal manuWrite: std_logic; -- le signal de commande d'écriture
signal manuReset: std_logic; -- le signal d'arrêt
signal selectManu:std_logic; -- le signal de sélection des données vers le bloc MicroWire
type ScWrState is (IDLE, WRITING);
signal scWrCs, scWrFs : ScWrState := IDLE;

---------------------------------------------------
component micro_wire_rom -- voir fichier de données micro_wire_rom
	port (
	a:   in  std_logic_vector(4 downto 0);
	spo: out std_logic_vector(31 downto 0));
end component;

attribute box_type : string;
attribute box_type of micro_wire_rom : component is "black_box";

--================================================================================
begin

-- aiguillage des données vers le bloc MicroWire

microwireData <= lmkRegister when selectManu = MANU else
                 romData;
lmkNr         <= scChip when selectManu = MANU else
                 chipCt;
                 
-- déclencheur
send <= sendMan or sendAuto;

---------------------------------------------------
-- instantiation du sérialisateur
mw: entity work.MicroWire
	generic map (scaling => 2) -- division par ...
	port map (
		clk       => clk,
		resetIn   => resetIn,
		dataIn    => microwireData,
		adIn      => lmkNr,
		send      => send,
		done      => done,
		uWire1    => uWire1,
		uWire2    => uWire2,
		ckUWire   => ckUWire,
		dataUWire => dataUWire);
	
-------------------------------------------
-- la rom de configration
rom: micro_wire_rom
	port map (
		a   => romAd,
		spo => romData
	);
--------------------------------------------------------------------
ct_mots: entity work.compteur
	generic map (WIDTH => 4, MODULO=>13) -- 13 mots à envoyer pour chaque LMK
	port map (
    clk   => clk,
    reset => resetIn,
    raz   => razWordCt,
    carry => maxWord,
    incr  => incWordCt
  );
--------------------------------------------------------------------
-- le compteur de chips lmk2000 (compte jusqu'à 1 ...)
compter_chips: process (clk)
begin
	if rising_edge(clk) then
		if razChipCt = '1' then
			chipCt <= '0';
		elsif incChipCt = '1' then
			chipCt <= '1';
		end if;
	end if;
end process;
-----------------------------------------------------------------------
-- le compteur d'adresse rom
adresser_rom: process (clk)
begin
	if rising_edge(clk) then
		if razRomAd = '1' then
			romAd <= "00000";
		elsif incRomAd = '1' then
			romAd <= romAd + 1;
		end if;
	end if;
end process;

-----------------------------------------------------------------------
-- machine d'état
-- le process séquentiel
sm_seq: process (resetIn,clk)
begin
	if resetIn = '1' then
		rstMwCs <= RESET_STATE;
	elsif rising_edge(clk) then
		rstMwCs <= rstMwFs;
	end if;
end process;

-- le process combinatoire --------------------------------------------
sm_comb: process (rstMwCs, done, resetIn, maxWord, chipCt)
begin
	--- init par défaut ---
	rstMwFs   <= rstMwCs; -- pas de changement d'état
	razChipCt <= '0';
	incChipCt <= '0';
	razWordCt <= '0';
	incWordCt <= '0';
	razRomAd  <= '0';
	incRomAd  <= '0';
	sendAuto  <= '0';
	------------------------------
	case rstMwCs is
	------------------------------
	when IDLE => NULL;       -- état initial RESET_STATE positionné
	------------------------ -- dans le process séquentiel
	when RESET_STATE =>      -- attendre que reset retombe
		if resetIn = '0' then  -- nb. resetIn doit être resynchronisé
			razChipCt <= '1';
			razWordCt <= '1';
			razRomAd  <= '1';
			rstMwFs   <= wait_done_1;
		end if;
	------------------------------
	when WAIT_DONE_1 =>
		sendAuto <= '1';
		if done = '1' then -- done est le signal d'occupation du module MicroWire
			rstMwFs <= WAIT_DONE_0;
		end if;
	------------------------------
	when WAIT_DONE_0 =>
		if done = '0' then -- attendre d'abord que done retombe ...
			incRomAd <= '1'; -- car il dure un coup d'horloge divisée
			incWordCt <= '1';
			if maxWord = '1' then  -- dernier mot de la ROM transmis ?
				if chipCt = '1' then -- dernier chip ? (il n'y en a que deux --> compteur 1-bit)
					rstMwFs <= IDLE;
				else
					incChipCt <= '1';
					rstMwFs <= wait_done_1;
				end if;
			else
				rstMwFs <= wait_done_1;
			end if;
		end if;
	------------------------------
	when others =>
		rstMwFs <= RESET_STATE;
	------------------------------
	end case;
end process;

--------------------------------------------------------------------------------------------------
regLoad: process (sysClk, resetIn, slowCtBus.addr)
variable decod : std_logic;
begin
  -- chip-select du module
  if slowCtBus.addr(SC_AD_WIDTH-1 downto LMK_FIELD)
          = RegAd(SC_AD_WIDTH-1 downto LMK_FIELD) then
    decod := '1';
  else
    decod := '0';
  end if;
  
  if resetIn = '1' then
    lmkRegister <= x"00000000";
  elsif rising_edge(sysClk) then
    manuWrite <= '0'; -- ordre d'écriture par le slowcontrol
    if decod = '1' and slowCtBus.wr = '1' then
      scChip <= slowCtBus.addr(1);
      case slowCtBus.addr(LMK_FIELD-1 downto 0) is
        when LMK_1H | LMK_2H => lmkRegister(31 downto 16) <= slowCtBus.data;
        when LMK_1L =>
          lmkRegister(15 downto 0) <= slowCtBus.data;
          manuWrite <= '1'; -- l'ordre dure un clk à 100 MHz
        when LMK_2L =>
          lmkRegister(15 downto 0) <= slowCtBus.data;
          manuWrite <= '1';
        when others     => null;
      end case;
    end if;
  end if;
end process regLoad;

--------------------------------------------------------------------------------------------------
-- machine d'état d'écriture par le slowcontrol
wrSeq: process (resetIn, clk) -- cette machine est séquencée par l'horloge à 25 MHz
begin
  if resetIn = '1' then
    scWrCs <= IDLE;
  elsif rising_edge(clk) then
    scWrCs <= scWrFs;
  end if;
end process;

wrComb: process (scWrCs, selectManu, done)
begin
  manuReset <= '0';
  sendMan   <= '0';
  scWrFs    <= scWrCs;
  case scWrCs is
	------------------------------
  when IDLE =>
    if selectManu = MANU then
      scWrfs <= WRITING;
    end if;
	------------------------------
  when WRITING =>
    sendMan   <= '1';
    if done = '1' then
      manuReset <= '1';
      scWrfs    <= IDLE;
    end if;
	------------------------------
  end case;
end process;

-- une simple bascule pour enregistrer la demande et positionner le multiplexeur de données
bascule: process (resetIn, sysClk)
begin
  if resetIn = '1' then
    selectManu <= AUTO;
  elsif rising_edge(sysClk) then
    if manuWrite = '1' then
      selectManu <= MANU;
    elsif manuReset = '1' then
      selectManu <= AUTO;
    end if;
  end if;
end process;

end Behavioral;

