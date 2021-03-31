----------------------------------------------------------------------------------
-- Company:  IPN Orsay
-- Engineer: Pierre Edelbruck
-- 
-- Create Date:    18/03/2011
-- Project Name:   fazia
-- Design Name:    telescope
-- Module Name:    I2cMaster - Behavioral 
-- Target Devices: virtex-5
-- Tool versions:  ISE 12.3

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description:
-- ~~~~~~~~~~~~
-- Sérialiseur I2C simple, un 3 octets
-- module maître qui génère une trame complète
-- de plusieurs octets.
-- Vitesse paramétrable (generic 'scaling')
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

-- Dependencies: i2c_byte
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
--------------------------------------------------------------------------------------------------
entity I2cMaster is
  generic (
    PRESCALER   : integer; -- le ratio entre la fréquence de l'horloge système et la fréquence de scl
    i2cAddr : integer
  );
  port (
    reset   : in    std_logic;
    clk     : in    std_logic;
    ---
    data    : in    std_logic_vector (15 downto 0);
    wr      : in    std_logic;
    done    : out   std_logic;
    ---
    scl     : out   std_logic;
    sda     : out   std_logic
  );
end I2cMaster;

--------------------------------------------------------------------------------------------------
architecture Behavioral of I2cMaster is

signal start, stop, run, rdy : std_logic;
signal byteData : std_logic_vector (7 downto 0);
type I2cState is (IDLE, BYTE_1, BYTE_2, BYTE_3);
signal i2cCs, i2cFs : I2cState;
signal rdyLate : std_logic;
--------------------------------------------------------------------------------------------------
begin
i2cByte: entity work.i2c_byte
  generic map (PRESCALER => PRESCALER)
  port map (
    clk   => clk,
    reset => reset,
    ---
    start => start,
    stop  => stop,
    run   => run,
    data  => byteData,
    rdy   => rdy,
    ---
    scl   => scl,
    sda   => sda
  );
  
-- La machine d'état séquentielle ----------------------------------------------------------------
smSeq: process (clk, reset)
begin
  if reset = '1' then
    i2cCs <= IDLE;
  elsif rising_edge(clk) then
    i2cCs <= i2cFs;
		rdyLate <= rdy;
  end if;
end process;

-- La machine d'état combinatoire ----------------------------------------------------------------
smComb: process (i2cCs, wr, rdy, rdyLate, data)
begin
  i2cFs <= i2cCs;
  done  <= '0'; -- sauf idle
  run   <= '1'; -- sauf idle
  start <= '0';
  stop  <= '0';
  byteData <= (others => '0');
  
  case i2cCs is
    -----------------------------
    when IDLE =>
      done  <= '1';
      run   <= '0';
      if wr = '1'  then
        i2cFs <= BYTE_1;
      end if;
    -----------------------------
    when BYTE_1 =>
      start <= '1';
      byteData <= conv_std_logic_vector(i2cAddr, 8);
      if rdy = '1' and rdyLate = '0' then -- front montant de rdy
        i2cFs <= BYTE_2;
      end if;
    -----------------------------
    when BYTE_2 =>
      byteData <= data(15 downto 8);
      if rdy = '1'  and rdyLate = '0'then
        i2cFs <= BYTE_3;
      end if;
    -----------------------------
    when BYTE_3 =>
      stop <= '1';
      byteData <= data(7 downto 0);
      if rdy = '1'  and rdyLate = '0'then
			  run <= '0';
        i2cFs <= IDLE;
      end if;
  end case;
end process;

end Behavioral;

