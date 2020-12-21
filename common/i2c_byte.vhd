----------------------------------------------------------------------------------
-- Company:  IPN Orsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:    11:17:05 03/16/2011
-- Imprimé le      30-03-2011
-- Project Name:   fazia
-- Design Name:    telescope
-- Module Name:    i2c_wr - Behavioral 
-- Target Devices:   virtex-5
-- Tool versions:  ISE 12.3

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description:
-- ~~~~~~~~~~~~
-- Sérialiseur I2C simple, un seul octet
-- destiné à ếtre utilisé par un module maître qui génère une trame complète
-- de plusieurs octets. Bits start et stop optionnels commandés par les
-- signaux 'start' et 'stop'
-- Vitesse paramétrable (generic 'scaling')
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
--================================================================================================
entity i2c_byte is
  generic (
    PRESCALER : integer -- le ratio entre la fréquence de l'horloge système et la fréquence de scl
  );
  port (
    clk   : in    std_logic;
    reset : in    std_logic;
    ---
    start : in    std_logic;
    stop  : in    std_logic;
    run   : in    std_logic;
    data  : in    std_logic_vector (7 downto 0);
    rdy   : out   std_logic;
    ---
    scl   : out   std_logic;
    sda   : out   std_logic
  );
end i2c_byte;

--================================================================================================
architecture Behavioral of i2c_byte is

--------------------------------------------------------------------------------------------------
type I2cState is (IDLE, START_BIT, BITS, ACK0, ACK, STOP_BIT);
signal i2cCs, i2cFs : I2cState := IDLE; -- les variables d'état
signal slowClk : std_logic; -- impulsion (1 clk) issu du prescaler
signal razAll, runPre : std_logic;
signal phaseCnt : std_logic_vector(1 downto 0); -- compteur quatre phases de l'horloge scl
signal dataRegister : std_logic_vector(7 downto 0); -- le registre à décalage de sortie
signal loadData, shiftData : std_logic;             -- les commandes du registe à décalage
signal bitCnt : std_logic_vector(2 downto 0); -- csli
signal incBitCnt : std_logic;                 -- commande du compteur de bits
signal preMove, move : std_logic;             -- avant-dernier et dernier coup de clock
signal sdaInternal, sclInternal : std_logic;                       -- de chaque état de la machine
signal preCompte : std_logic_vector (5 downto 0); -- le prescaler (compte jusqu'à 63)
signal lateStop : std_logic; -- csli
--------------------------------------------------------------------------------------------------
begin
-- le prescaler préscale au quadruple de la fréquence de sortie de scl
-- afin de gérer les quatre phases de chaque bit
	
compter: process (reset, clk)
begin
  if (reset = '1') then
    preCompte <= (others => '0');
  elsif rising_edge (clk) then
    if runPre = '1' then
      if slowClk = '1' then
        preCompte <= (others => '0');
      else
        preCompte <= preCompte + 1;
      end if;
    end if;
  end if;
end process;

slowClk <= '1' when preCompte = PRESCALER-1 else '0';
move    <= '1' when SlowClk = '1' and phaseCnt = 3 else '0';
preMove <= '1' when preCompte = PRESCALER-2 and phaseCnt = 3 else '0';
--------------------------------------------------------------------------------------------------
-- machine d'état
-- le processus séquentiel, registres et compteurs divers

sda <= sdaInternal; -- modif le 13-03-2012

smSeq: process (clk, reset)
begin
  if reset = '1' then
    i2cCs <= IDLE;
  elsif rising_edge(clk) then
    i2cCs <= i2cFs;
    lateStop <= stop;
    --sda <= sdaInternal; -- resynchro du signal combinatoire
    scl <= sclInternal;
    
    if razAll = '1' then
      phaseCnt <= (others => '0');
    elsif slowClk = '1' then
      phaseCnt <= phaseCnt + 1;
    end if;
    
    if loadData = '1' then
      dataRegister <= data;
    elsif shiftData = '1' then
      dataRegister <= dataRegister(6 downto 0) & "0";
    end if;
    
    if razAll = '1' then
      bitCnt <= (others => '0');
    elsif incBitCnt = '1' then
      bitCnt <= bitCnt + 1;
    end if;
  end if;
end process;

--------------------------------------------------------------------------------------------------
-- le processus combinatoire
smComb: process (i2cCs, start, stop, run, preMove, move, phaseCnt, bitCnt, dataRegister, lateStop)
--variable move_stop_run : std_logic_vector (2 downto 0) := move & stop & run;
begin
  rdy <= '0';
  sdaInternal <= '1';
  sclInternal <= '1';
  i2cFs <= i2cCs;
  razAll <= '0';
  runPre <= '1';
  loadData <= '0';
  shiftData <= '0';
  incBitCnt <= '0';
  case i2cCs is
    -----------------------------
    when IDLE =>
      razAll <= '1';
      runPre <= '0';
      rdy    <= '1';
      if run = '1' and start = '1' then
        loadData <= '1';
        i2cFs <= START_BIT;
      elsif run = '1' and start = '0' then
        loadData <= '1';
        i2cFs <= BITS;
      end if;
    -----------------------------
    when START_BIT =>
      sdaInternal <= '0';
      if phaseCnt = 3 then
        sclInternal <= '0';
      else
        sclInternal <= '1';
      end if;
      
      if move = '1' then
        i2cFs <= BITS;
      end if;
    -----------------------------
    when BITS =>
      sdaInternal <= dataRegister(7);

      case phaseCnt is
        when "01" | "10" => sclInternal <= '1';
        when others      => sclInternal <= '0';
      end case;

      if move = '1' then
        incBitCnt <= '1';
        shiftData <= '1';
      end if;
      
      if move = '1' and bitCnt = 7 then      
        i2cFs <= ACK0;
      end if;
    -----------------------------
    when ACK0 => -- un coup de clock mort
      sdaInternal <= 'Z'; -- modif le 13-03-2012
      if move = '1' then
        i2cFs <= ACK;
      end if;
      
      case phaseCnt is
        when "00" | "11" => sclInternal <= '0';
        when others => null;
      end case;
    -----------------------------
    when ACK =>
      sdaInternal <= 'Z'; -- modif le 13-03-2012
      if move = '1' then
        loadData <= '1';
      end if;
      
      if    move = '1' and lateStop = '0' and run = '0' then
        i2cFs <= IDLE;
      elsif move = '1' and lateStop = '0' and run = '1' then
        i2cFs <= BITS;
      elsif move = '1' and lateStop = '1' then
        i2cFs <= STOP_BIT;
      end if;
      
      if (preMove = '1' or move = '1') and lateStop = '0' then
        rdy <= '1';
      end if;

      sclInternal <= '0';      
    -----------------------------
    when STOP_BIT =>
      if preMove = '1' or move = '1' then
        rdy <= '1';
      end if;
      
      case phaseCnt is
        when "00" => sclInternal <= '0';
                     sdaInternal <= '0';
        when "01" => sdaInternal <= '0';
      when others => null;
      end case;
          
      if move = '1' then
        i2cFs <= IDLE;
      end if;
      
  end case;
end process;

end Behavioral;

