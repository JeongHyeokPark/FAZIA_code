                           -------------------------------------
                           --   Company:  IPN Orsay           --
                           --   Engineer: Pierre Edelbruck    --
                           --                 ----------      --
                           --   Module Name:    PicItf        --
                           --                 ----------      --
                           --   Create Date:    21 déc. 2010  --
                           --   Print date :    23 mar. 2011  --
                           --   Design Name:    lib           --
                           --   Project Name:   fazia         --
                           --   Target Devices: virtex-5      --
                           --   Tool versions:  ise-12.3      --
                           -------------------------------------

--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Description:
-- ~~~~~~~~~~~~
-- Interface spi entre pic et slow-control interne
--~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
-- Dependencies: 
--
-- Revision: 
-- Revision 1.0
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

library UNISIM;
use UNISIM.VComponents.all;
use work.slow_ct_defs.all;

----------------------------------------------------------------------------------
entity PicItf is
  port (
    clk :        in   std_logic;
    reset :      in   std_logic;
    -- vers l'extérieur -----------   --  type SlowCtBusRec is
    ucSpiSS_n   : in  std_logic;      --  record
    ucSpiSdi    : out std_logic;      --    data   : std_logic_vector (15 downto 0);
    ucSpiSdo    : in  std_logic;      --    addr   : std_logic_vector (SC_AD_WIDTH-1 downto 0);
    ucSpiSck    : in  std_logic;      --    rd     : std_logic;
    -- Interface to bus side -------  --    wr     : std_logic;
    selectSpi   : out std_logic;      --  end record;
    slowCtBus   : out SlowCtBusRec;
    slowCtBusRd : in  std_logic_vector (SC_TOP downto 0)
  );
end PicItf;

----------------------------------------------------------------------------------

architecture Behavioral of PicItf is

-- constantes
constant MODE_BITS : integer := 2;
constant MODE_TOP  : integer := MODE_BITS-1;

constant BYTE_AD_H : std_logic_vector := "000";
constant BYTE_AD_L : std_logic_vector := "001";
constant BYTE_MODE : std_logic_vector := "010";
constant BYTE_D_H  : std_logic_vector := "011";
constant BYTE_D_L  : std_logic_vector := "100";

-- signaux
signal selectLocal    : std_logic;
signal addrRegister, busData, dataFromPic, dataToPic : std_logic_vector (15 downto 0);
signal bitCnt         : std_logic_vector (2 downto 0); -- 8 bits max
signal byteCnt        : std_logic_vector (2 downto 0); -- 5 octets max
signal mode           : std_logic_vector (MODE_TOP downto 0); --, shiftedMode
signal busWrite, busWriteSync, busWriteLate : std_logic;
signal busRead,  busReadSync,  busReadLate0, busReadLate1 , busReadLate2 : std_logic;
--signal CONTROL0 : std_logic_vector (35 downto 0);
--signal all_zero : std_logic_vector (255 downto 0) := (others => '0');
signal slowCtBusLocal : SlowCtBusRec;

--===== chipscope ===============================================================================
--component tel_chip
--  PORT (
--    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
--    CLK : IN STD_LOGIC;
--    TRIG0 : IN STD_LOGIC_VECTOR(255 DOWNTO 0));
--
--end component;
--
--component tel_icon
--  PORT (
--    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
--end component;
--================================================================================================
begin
--mon_chip : tel_icon
--  port map (
--    CONTROL0 => CONTROL0);
--
--
--mes_sondes : tel_chip
--  port map (
--    CONTROL => CONTROL0,
--    CLK => clk,
--    TRIG0(0) => reset,
--	 TRIG0(1) => ucSpiSS_n,
--	 TRIG0(2) => ucSpiSdo,
--	 TRIG0(3) => ucSpiSck,
--	 TRIG0(4) => slowCtBusLocal.wr,
--	 TRIG0(20 downto 5)  => slowCtBusLocal.data,
--	 TRIG0(36 downto 21) => slowCtBusLocal.addr,
--	 TRIG0(255 downto 37) => all_zero (255 downto 37)
--  );

selectSpi   <= not ucSpiSS_n; -- froidement. C'est le PIC qui décide (combinatoirement)
selectLocal <= not ucSpiSS_n;
ucSpiSdi    <= dataToPic(15) when ucSpiSS_n = '0' else 'Z';
slowctBus   <= slowCtBusLocal;
------------------------------------------------
resyncp : process (reset, clk)
begin
  if reset = '1' then
    slowCtBusLocal.rd <= '0';
    slowCtBusLocal.wr <= '0';
	  busData      <= (others => '0');
  elsif rising_edge(clk) then
	 
    busWriteSync <= busWrite;
    busWriteLate <= busWriteSync;
	 
    busReadSync  <= busRead;
    busReadLate0 <= busReadSync;
    busReadLate1 <= busReadLate0;
    busReadLate2 <= busReadLate1;
	 
    slowCtBusLocal.rd <= '0';
    slowCtBusLocal.wr <= '0';

    if busWriteLate = '0' and busWriteSync = '1' then
      slowCtBusLocal.data <= dataFromPic;
      slowCtBusLocal.addr <= addrRegister;
      slowCtBusLocal.wr <= '1';
    elsif busReadLate0 = '0' and busReadSync = '1' then
      slowCtBusLocal.addr <= addrRegister;
	    slowCtBusLocal.rd <= '1'; -- requête dont le résultat arrivera 2 clock plus tard
    elsif busReadLate2 = '0' and busReadLate1 = '1' then
	    busData <= slowCtBusRd; -- tampon en amont du registre dataToPic
	 else
      slowCtBusLocal.data <= (others => '0');
      slowCtBusLocal.addr <= (others => '0');
    end if;
  end if;
end process;

--------------------------------------------------------------------------------------------------
-- la machine SPI --
-- elle est séquencée par l'horloge spi entrante (ucSpiSck)
-- ses états sont définis par les compteurs d'octets byteCnt et de bits bitCnt
-- un cycle SPI comprend 5 octets
-- octet 0 : spi --> fpga  adresse H
-- octet 1 : spi --> fpga  adresse L
-- octet 2 : spi --> fpga  mode
-- octet 3 : si mode = 0 (lecture)  fpga --> spi  data H
--           si mode = 1 (écriture) spi --> fpga  data H
-- octet 4 : si mode = 0 (lecture)  fpga --> spi  data L
--           si mode = 1 (écriture) spi --> fpga  data L
-- c'est la montée du signal selectLocal (= not ucSpiSS_n) qui initie une transaction
-- il doit impérativement retomber en fin de transaction pour remettre l'interface en attente
--                                                                (de façon asynchrone)

cntAll: process (reset, ucSpiSck, selectLocal)
begin
  if reset = '1' or selectLocal = '0' then
    bitCnt   <= (others => '0');
    byteCnt  <= (others => '0');
    busRead  <= '0'; -- requête qui sera resynchronisée par resyncp
    busWrite <= '0'; -- idem
    addrRegister <= (others => '0');
    dataFromPic  <= (others => '0');
    
  elsif falling_edge(ucSpiSck) then -- donnée sur le front descendant depuis step_2
    busRead  <= '0'; -- requête qui sera resynchronisée par resyncp
    busWrite <= '0'; -- idem
    if selectLocal = '1' then
      bitCnt <= bitCnt + 1; -- modulo 8 par construction
      case byteCnt is
        -- lecture des données, poids fort en tête
        when BYTE_AD_H | BYTE_AD_L => -- addr
          addrRegister <= addrRegister(14 downto 0) & ucSpiSdo; -- 16 bits à la queue leuleu
        when BYTE_MODE => -- mode
          mode <= mode (MODE_TOP-1 downto 0) & ucSpiSdo; -- shift left
        when BYTE_D_H | BYTE_D_L =>
          dataFromPic <= dataFromPic(14 downto 0) & ucSpiSdo; -- data depuis le pic
        when others => null;  -- rien à faire
      end case;
      
      -- on examine ce qui doit être fait en fin d'octet (sur le bit N° 7)
      if bitCnt = 7 then
        byteCnt <= byteCnt+1;
        -- juste avant le 3 ème octet (on ne préjuge pas de celui qui précède)
        if byteCnt = BYTE_D_H-1 then
          if mode(0) = '0' then -- lecture (le pic lit le bus)
            busRead <= '1'; -- transaction de lecture + bus de données --> busData
          end if;
        elsif byteCnt = BYTE_D_L then
          if mode(0) = '1' then -- écriture (le pic écrit sur le bus)
            busWrite <= '1'; -- transaction d'écriture dataFromPic --> bus de données
          end if;
        end if; -- byteCnt = 4
      end if; -- bitCnt = 7
    end if; -- selectLocal = '1'
  end if; -- falling_edge(ucSpiSck)
end process;

-------------------------------------------------------------------------------------------------
-- ajouté le 19-04-2012 écriture maintenant sur front montant
-------------------------------------------------------------------------------------------------
writeProcess: process (reset, ucSpiSck, selectLocal)
begin
  if reset = '1' or selectLocal = '0' then
    dataToPic    <= (others => '0');
  elsif rising_edge(ucSpiSck) then
    if selectLocal = '1' then
      if byteCnt = BYTE_D_H or byteCnt = BYTE_D_L then
        if byteCnt = BYTE_D_H and bitCnt = 0 then
          dataToPic <= busData;
        else
          dataToPic <= dataToPic(14 downto 0) & '0'; -- data vers le pic
        end if;
      end if;
    end if;
  end if;
end process;

------------------------------------------------
end Behavioral;




