----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    09:52:23 10/21/2011 
-- Design Name: 
-- Module Name:    reader - Behavioral 
-- Project Name:   fazia 
-- Target Devices: virtex-5 
-- Tool versions: 
-- Description: Lecteur nouvelle mouture. Fait partie intégrante de Waver
-- a été créé pour réduire la taille et la complexité dudit Waver.

-- Archivé le 12-12-2011  à  14:17
-- tout fonctionne. les données (16 bit) sont sorties @ 50 MHz (2 cycles par mot)
-- un cycle throttle=0 diffère les données d'exactement 1 cycle (10 ns)
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.ALL;
use IEEE.std_logic_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

--use IEEE.NUMERIC_STD.ALL;

library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.align_defs.all;
use work.slow_ct_defs.all;
use work.telescope_conf.all;

entity reader is
  generic (
    detId   : integer;
    WaveId   : integer;
    MebSize  : integer; -- taille en mots du MEB
    Items    : integer  -- nombre réel d'items de la mémoire segments, pointeur MEB 
  );                    -- et pretrig etc. non compris
  port (
    clk        : in  std_logic;
    reset      : in  std_logic;
    telId      : in std_logic_vector(3 downto 0);
    ---
    dataRemote : in  std_logic_vector (DATA_WITH_TAG-1 downto 0);
    fromFifo   : in  std_logic_vector (15 downto 0);
    segsIn     : in  std_logic_vector (15 downto 0);
    saveWave   : in  boolean;
    dataOut    : out std_logic_vector (DATA_WITH_TAG-1 downto 0);
    fifoLd     : out std_logic;
    fifoInc    : out std_logic;
    --storeDepth : in  std_logic_vector (bits(MebSize)-1 downto 0);
    ---
    segsLd     : out std_logic;
    segsInc    : out std_logic;
    ---
    throttle   : in  std_logic; -- bloquer l'émission si throttle = '0'
    doneIn     : in  std_logic;
    doneOut    : out std_logic;
    ---
    statemach  : out std_logic_vector (3 downto 0);
    errbit     : out std_logic;
    ---
    readIn     : in  std_logic;
    readOut    : out std_logic
  );
end reader;

architecture Behavioral of reader is

constant MebBits  : integer := bits(MebSize); -- nbre de bits du bus d'adresse de MEB
constant ItemBits : integer := bits(Items);   -- pour dimensionner le compteur. les vrais items
--signal throttleOld  : std_logic;
--signal readInOld   : std_logic;
-- le compteur d'items
signal itemCntr  : std_logic_vector(ItemBits-1 downto 0);
-- fifoCnter nécessite un bit supplémentaire pour pouvoir admettre des comptes négatifs
signal fifoCnter : std_logic_vector(MebBits downto 0);
signal timer     : std_logic_vector(2 downto 0);

--=== La machine de lecture =====================================================================
type ReadState is (IDLE, START_0, START_1, START_2,RD_ITEM_0, RD_ITEM, 
                   PRETRIG_HEADER, PRETRIG_LENGTH_0, PRETRIG_LENGTH, TEMPO_0, WAVE_HEADER,
                   RD_FIFO_0, RD_FIFO, RD_NULL_0, RD_NULL, REMOTE_0, REMOTE, FINISH, ACQUIT);
						 
signal readCs : ReadState := IDLE;
signal inputReg, outputReg : std_logic_vector (DATA_WITH_TAG-1 downto 0);

--===== chipscope ===============================================================================
signal all_zero_64  : std_logic_vector (63 downto 0) := (others => '0');
signal CONTROL0     : std_logic_vector (35 downto 0);
signal etatReader   : std_logic_vector(3 downto 0);
signal jeSuisB      : std_logic; -- pour le debug
signal readOutLocal : std_logic;

constant c_four     : std_logic_vector(15 downto 0) := X"0004";

component tel_ila
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK     : IN STD_LOGIC;
    trig0   : IN STD_LOGIC_VECTOR(63 DOWNTO 0)
  );
end component;

component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
end component;

begin

identTelesA: if build_a generate
  jeSuisB <= '0';
end generate;

identTelesB: if not build_a generate
  jeSuisB <= '1';
end generate;

readOut <= readOutLocal;
statemach <= etatReader;

--===== chipscope ===============================================================================
makeCS: if chip_reader and detId = SI_2 and WaveId = WAVE_Q2 generate

mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0
  );

mes_sondes : tel_ila
  port map (
    CONTROL => CONTROL0,
    CLK     => clk,
    ---
    trig0 ( 3 downto  0) => etatReader,
    trig0 (19 downto  4) => fromFifo,
    trig0 (32 downto 20) => fifoCnter,
    trig0 (33)           => readIn,
    trig0 (34)           => throttle,
    trig0 (35)           => readOutLocal,
    --trig0 () => 
    --trig0 () =>
    trig0 (63 downto 36) => all_zero_64(63 downto 36)
 );
end generate;

dataOut  <= outputReg;
etatReader <= conv_std_logic_vector(ReadState'pos(readCs), 4);

--=== La machine de lecture =====================================================================
-- les états de transmission sont doublés pour obtenir une cadence à 50 MHz

-- le process séquentiel ------------------------------
readSeq: process (reset, clk)
begin

  if reset = '1' then
    readOutLocal      <= '0';
    ---
    inputReg  <= NO_DATA(15 downto 1) & jeSuisB; -- pour le debug
    outputReg <= NO_DATA;
    readCs    <= IDLE;
    fifoCnter <= (others => '0');
    itemCntr  <= (others => '0');
    timer     <= (others => '0');
    doneOut   <= '0';
    errbit  <= '0';
    
  elsif rising_edge(clk) then
    if throttle = '1' then -- bloquer l'émission si throttle = '0' (la machine n'évolue pas)
      case readCs is
      -----------------------------------------------------
      when IDLE => -- 0
        errbit  <= '0';
        if readIn = '1' then
          readCs <= START_0;
        end if;
      -----------------------------------------------------
      when START_0 => readCs <= START_1; -- 1
      -----------------------------------------------------
      when START_1 => readCs <= START_2; -- 2
      -----------------------------------------------------
      when START_2 => -- 3
        itemCntr  <= conv_std_logic_vector(Items, ItemBits);
        fifoCnter <= conv_std_logic_vector(-1, MebBits+1); -- on anticipera les deux paramètres
        inputReg <= DETID_TAG & conv_std_logic_vector(WaveId, 3) & conv_std_logic_vector(detId, 3) & '0' & telId;
        --             5                +                4      +    3    +  4  =  16
        if Items = 0 then
		    if saveWave then
             readCs <= RD_FIFO_0; 
			 else
             fifoCnter <= conv_std_logic_vector(4, MebBits+1);
             readCs <= RD_NULL_0;
          end if;			 
        else
          readCs <= RD_ITEM_0;
        end if;
      -----------------------------------------------------
      when RD_ITEM_0 => -- 4
        readCs <= RD_ITEM;
      -----------------------------------------------------
      when RD_ITEM => -- 5
        inputReg  <= segsIn;
        outputReg <= inputReg;
        itemCntr  <= itemCntr - 1;
        if itemCntr = 1 then
          if saveWave then
             readCs <= RD_FIFO_0; 
          else
             fifoCnter <= conv_std_logic_vector(4, MebBits+1);			 
             readCs <= RD_NULL_0;
          end if;		
        else
          itemCntr <= itemCntr - 1;
          readCs   <= RD_ITEM_0;
        end if;
      -----------------------------------------------------
      when RD_FIFO_0 => -- 6
        if fifoCnter = conv_std_logic_vector(-1, MebBits+1) then
          readCs <= PRETRIG_HEADER;
        elsif 
          fifoCnter = conv_std_logic_vector(-2, MebBits+1) then
			 readCs <= WAVE_HEADER;
        else			 
          readCs <= RD_FIFO;
		  end if;	 
      -----------------------------------------------------
		when PRETRIG_HEADER => -- 7
		  inputReg  <= '0' & '1' & '1' & '1' & PRETRIG_TAG;
		  outputReg <= inputReg;
		  readCs    <= PRETRIG_LENGTH_0;
      -----------------------------------------------------
      when PRETRIG_LENGTH_0 => -- 8		 
        readCs <= PRETRIG_LENGTH;	 
      -----------------------------------------------------		
      when PRETRIG_LENGTH	=> -- 9	
		  inputReg (15)  <= '0'; -- c'est le protocole : MSBs = '0' if data
        inputReg(14 downto 0) <= conv_std_logic_vector(PRETRIG_LEN, 15);
		  outputReg <= inputReg;	  
		  readCs    <= TEMPO_0;
      -----------------------------------------------------	
      when TEMPO_0 => -- 10			
        readCs <= RD_FIFO;	 
      -----------------------------------------------------				
		when WAVE_HEADER => -- 11
		  inputReg  <= '0' & '1' & '1' & '1' & WAVE_TAG;
		  outputReg <= inputReg;
		  readCs    <= TEMPO_0;
      -----------------------------------------------------					
      when RD_FIFO => -- 12
        inputReg  <= fromFifo;
        outputReg <= inputReg;
        if fifoCnter = conv_std_logic_vector(-2, MebBits+1) then
          fifoCnter <= fromFifo(MebBits downto 0); -- charger la longueur
          if (fromFifo(MebBits downto 0) < c_four(MebBits downto 0)) then
            errbit <= '1';
          end if;
        else
          fifoCnter <= fifoCnter - 1;
        end if;
        -- nota molto bene : il faut passer par 4 pour que le transfert passe au niveau supérieur
        -- on ne doit donc pas demander une taille d'enregistrement inférieure à 4
        if fifoCnter = 4 then
          readOutLocal <= '1';
        end if;
        if fifoCnter = 0 then
          --readOutLocal <= '1'; -- essais de Franck
          if doneIn = '0' then
            inputReg <= dataRemote;
            readCs   <= REMOTE_0;
          else -- il n'y a personne au dessus, on saute REMOTE
            timer <= conv_std_logic_vector(0, 3);
            doneOut <= '1';
            readCs <= FINISH ;
          end if;
        else
          readCs   <= RD_FIFO_0;
        end if;
      -----------------------------------------------------
		when RD_NULL_0 => readCs <= RD_NULL; 
      -----------------------------------------------------
		when RD_NULL =>
        inputReg  <= NO_DATA;
        outputReg <= inputReg;
        fifoCnter <= fifoCnter - 1;	
        if fifoCnter = 4 then
          readOutLocal <= '1';
        end if;
        if fifoCnter = 0 then
          if doneIn = '0' then
            inputReg <= dataRemote;
            readCs   <= REMOTE_0;
          else -- il n'y a personne au dessus, on saute REMOTE
            timer <= conv_std_logic_vector(0, 3);
            doneOut <= '1';
            readCs <= FINISH ;
          end if;
			else 
			  readCs <= RD_NULL_0;
			end if;  
		-----------------------------------------------------		
      when REMOTE_0 => readCs <= REMOTE; -- 13
      -----------------------------------------------------
      when REMOTE => -- 14
        inputReg  <= dataRemote;
        outputReg <= inputReg;
        if doneIn = '1' then
          timer <= conv_std_logic_vector(2, 3);
          readCs <= FINISH;
        else
          readCs <= REMOTE_0;
        end if;
      -----------------------------------------------------
      when FINISH => -- différer la montée de doneOut  -- 15
        timer <= timer - 1;
        if timer = 0 then
          readCs <= ACQUIT;
        elsif timer = 1 then
          doneOut <= '1';
          outputReg <= inputReg;
        end if;
      -----------------------------------------------------
      when ACQUIT => -- 16
        outputReg <= NO_DATA;
        if readIn = '0' then
          doneOut <= '0';
          readOutLocal <= '0';
          readCs  <= IDLE;
        end if;
      -----------------------------------------------------
      end case;
    end if;
  end if;
end process;
  
-- le processus combinatoire --------------------------

readComb: process (readCs, throttle)
begin
  fifoLd  <= '0';
  fifoInc <= '0';
  segsLd  <= '0';
  segsInc <= '0';
--  doneOut <= '0';
  if throttle = '1' then
    case readCs is
      ---------------------------------
      when IDLE      => null;
      ---------------------------------
      when START_0   => segsLd  <= '1';
      ---------------------------------
      when START_1   => fifoLd  <= '1';
      ---------------------------------
      when START_2   => segsInc <= '1';
      ---------------------------------
      when RD_ITEM_0 => null;
      ---------------------------------
      when RD_ITEM   => segsInc <= '1';
      ---------------------------------
      when PRETRIG_HEADER => null;
      ---------------------------------
      when PRETRIG_LENGTH_0 => null;
      ---------------------------------	
      when PRETRIG_LENGTH => null;
      ---------------------------------
      when TEMPO_0 => null;
      ---------------------------------
      when WAVE_HEADER => null;
      ---------------------------------		
      when RD_FIFO_0 => null;
      ---------------------------------
      when RD_FIFO   => fifoInc <= '1';
      ---------------------------------		
      when RD_NULL_0 => null;
      ---------------------------------
      when RD_NULL   => null;		
      ---------------------------------
      when REMOTE_0  => null;
      ---------------------------------
      when REMOTE    => null;
      ---------------------------------
      when FINISH    => null;
      ---------------------------------
      when ACQUIT    => null; --doneOut <= '1';
    end case;--------------------------
  end if;
end process;

end Behavioral;





