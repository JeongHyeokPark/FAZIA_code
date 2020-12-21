----------------------------------------------------------------------------------------------------
-- Company: IPN Orsay
-- Engineer: P. Edelbruck
-- 
-- Create Date:    15:13:12 11/09/2009
--                 repris le 28-10-2010
-- Design Name:    telescope
-- Module Name:    DDR_ADC - Behavioral 
-- Project Name:   fazia
-- Target Devices: virtex-5
-- Tool versions: 
-- Description: Démultiplexeur DDR 8 bit --> 16 bits
--   ibufds + iodelay + iddr nb.
--   Version délai réglable. Les délais sont programmables de 0 à 63
-- Cette DDR est utilisée pour les ADC 100 MHz ET pour les ADC 250 MHz
-- La seule différence est l'ordre des bits en sortie d'ADC. Voir paramètre slowDac
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--USE ieee.numeric_std.ALL;

---- Uncomment the following library declaration if instantiating
---- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

use work.tel_defs.all;
use work.align_defs.all;

--==================================================================================================
entity DDR_ADC is
  generic (D0, D1, D2, D3, D4, D5, D6, D7,
    ADC_NR,
    speed:   integer;  -- 100 = 100 MHz,  250 = 250 MHz
    reverse: boolean   -- inversion à la demande des bits de donnée d'ADC
  );
  port (
    sysClk       : in  std_logic; -- pour les organes de contrôle (les délais)
    sync         : in  std_logic; -- signal de mise en phase 100 / 250 MHz (1)
    --------------------------------
    inputClk_n   : in  std_logic;                      -- horloge des données d'entrée
    inputClk_p   : in  std_logic;
    input_n      : in  std_logic_vector (7 downto 0);  -- entrées différentielles
    input_p      : in  std_logic_vector (7 downto 0);
    --------------------------------
    ddrOut       : out std_logic_vector (15 downto 0); -- sorties démultiplexées
    outputClk    : out std_logic;                      -- restitution de l'horloge bufferisée/retardée
    --------------------------------
    alignBus     : in  alignBusRec;
    alignDataBit : out std_logic;
    inspect      : out std_logic
  );
end DDR_ADC;
-- (1) ce signal a une périodicité de 40 ns, une durée de 10 ns et est actif durant la
--     dernière phase (juste avant les deux fronts montants simultanés 100 / 250 MHz)
--     ** à titre expérimental ** il est produit dans 'telescope' (voir ce module)
--==================================================================================================
architecture Behavioral of DDR_ADC is

signal del_to_ddr : std_logic_vector (7 downto 0);
signal in_to_del  : std_logic_vector (7 downto 0);
signal in_to_del_n  : std_logic_vector (7 downto 0); -- ne sert qui si l'adc doit être inversé
signal inputClk   : std_logic; -- horloge avant délai                         (generic 'reverse')
signal clkDelayedRaw : std_logic; -- l'horloge d'ADC passée par son IDELAY
signal clkDelayed : std_logic;    -- idem après buffer d'horloge
--signal dataIn     : std_logic_vector(7 downto 0); -- le bus de données après buffers

type mes_delais is array (0 to 7) of integer;
constant data_delays : mes_delais := (D0, D1, D2, D3, D4, D5, D6, D7);

signal ce         : std_logic_vector(8 downto 0); -- enable de l'opération définie par inc
signal inc        : std_logic_vector(8 downto 0); -- (0 = décrémenter 1 = incrémenter) qd ce = 1
signal rst        : std_logic_vector(8 downto 0); -- forcer le délai préprogrammé
signal ddrQ       : std_logic_vector(15 downto 0);
signal syncData   : std_logic;
signal sysClkTest : std_logic; -- horloge ADC échantillonnée par l'horloge système
signal decod      : std_logic;
signal bitAdr     : std_logic_vector (3 downto 0);

--===== chipscope ===============================================================================
--signal all_zero_128 : std_logic_vector (127 downto 0) := (others => '0');
----signal etat : std_logic_vector (2 downto 0);
--signal CONTROL0 : std_logic_vector (35 downto 0);
--
--component tel_ila
--  PORT (
--    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
--    CLK   : IN STD_LOGIC;
--    TRIG0 : IN STD_LOGIC_VECTOR(63 DOWNTO 0));
--end component;
--
--component tel_icon
--  PORT (
--    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
--end component;

--===============================================================================================
begin
--===== chipscope ===============================================================================
--make_chipscope: if ADC_NR = 0 generate
--mon_icon : tel_icon
--  port map (
--    CONTROL0 => CONTROL0);
--
--mes_sondes : tel_ila
--  port map (
--    CONTROL => CONTROL0,
--    CLK      => sysClk,
--    ---
--    TRIG0 (63 downto 32)  => all_zero_128(63 downto 32),
--    TRIG0 (31)            => decod,
--    TRIG0 (30 downto 27)  => bitAdr,
--    TRIG0 (26 downto 18)  => rst,
--    TRIG0 (17 downto 9)   => inc,
--    TRIG0 (8  downto 0)   => ce
-- );
--end generate;

--etat <= conv_std_logic_vector(DelState'pos(delCs), 3);
--===============================================================================================


ddrOut    <= ddrQ;
outputClk <= clkDelayed;
bitAdr <= alignBus.bit_nr(2 downto 0) & '0'; -- voir commentaire dans le process dataSample

-- le buffer d'horloge ADC -------------------------------------------------------------------------
--adc_ckl_buf : IBUF
--  port map (
--    I  => inputClk_p,
--    O  => inputClk
--  );
  
adc_ckl_buf : IBUFDS
  port map (
    I  => inputClk_p,
    IB => inputClk_n,
    O  => inputClk
  );

-- le retard associé ---------------------------------------------------------------------------------
adc_clk_del: IDELAY
  generic map (
   IOBDELAY_TYPE  => "VARIABLE",
   IOBDELAY_VALUE => 0
  )
  port map (
    C   => sysClk,    -- pour le contrôle des délais
    CE  => ce(8),
    INC => inc(8),
    RST => rst(8),
    I   => inputClk,
    O   => clkDelayedRaw
  );


-- un buffer d'horloge
bufferR: BUFR
  generic map (
    --BUFR_DIVIDE => "1", -- "BYPASS", "1", "2", "3", "4", "5", "6", "7", "8"
    BUFR_DIVIDE => "BYPASS", -- "BYPASS", "1", "2", "3", "4", "5", "6", "7", "8"
    SIM_DEVICE  => "VIRTEX5" -- Specify target device, "VIRTEX4" or "VIRTEX5"
  )
  port map (
    CE  => '1',
    CLR => '0',
    I   => clkDelayedRaw,
    O   => clkDelayed
  );

-------------------------------------------------------------------------------------------------

dly_cmd_8: process (alignBus)
begin
  if alignBus.adc_adr = ADC_NR and alignBus.bit_nr = 8 then
    ce(8)  <= alignBus.ce;
    inc(8) <= alignBus.inc;
    rst(8) <= alignBus.rst;
  else
    ce(8)  <= '0';
    inc(8) <= '0';
    rst(8) <= '0';
  end if;
end process;

inspect_cmd_8: process (alignBus, del_to_ddr, clkDelayed, sysClkTest)
begin
  inspect <= '0';
  if alignBus.adc_inspect = ADC_NR then
    case conv_integer(alignBus.inspect_nr) is
    when 0 to 7 => inspect <= del_to_ddr(conv_integer(alignBus.inspect_nr(2 downto 0)));
    when 8      => inspect <= clkDelayed;
    when 9      => inspect <= sysClkTest;
    when 10     => inspect <= sync;
    when others => inspect <= '0';
    end case;
  end if;
end process;

-- les ensembles buffer-délai-ddr --------------------------------------------------------------------
make_path:
  for i in 0 to 7 generate

--dly_cmd_i: process (alignBus.adc_adr, alignBus.bit_nr)
dly_cmd_i: process (alignBus)
begin
  if alignBus.adc_adr = ADC_NR and (alignBus.bit_nr = i or alignBus.bit_nr = 15) then
    ce(i)  <= alignBus.ce;
    inc(i) <= alignBus.inc;
    rst(i) <= alignBus.rst;
  else
    ce(i)  <= '0';
    inc(i) <= '0';
    rst(i) <= '0';
  end if;
end process;

--------------------------------------------------
make_ibuf_n: if reverse generate
ibuffer: IBUFDS
  port map (
    I  => input_p(i),
    IB => input_n(i),
    O  => in_to_del_n(i)
  );
  in_to_del(i) <= not in_to_del_n(i);
end generate make_ibuf_n;

make_ibuf: if not reverse generate
ibuffer: IBUFDS
  port map (
    I  => input_p(i),
    IB => input_n(i),
    O  => in_to_del(i)
  );
end generate make_ibuf;

-- délais programmables -------------------------------------------------------------------------
      
    idels: IODELAY
      generic map (
        IDELAY_TYPE  => "VARIABLE",
        IDELAY_VALUE => data_delays(i)
      )
      port map (
        DATAOUT => del_to_ddr(i), --DATAOUT, -- 1-bit delayed data output
        C       => sysClk,        --C, -- 1-bit clock input
        CE      => ce(i),         --CE, -- 1-bit clock enable input
        IDATAIN => in_to_del(i),  --IDATAIN, -- 1-bit input data input (connect to port)
        INC     => inc(i),        --INC, -- 1-bit increment/decrement input
        RST     => rst(i),        --RST, -- 1-bit active high, synch reset input
        T       => '1'            --T -- 1-bit 3-state control input
      );

    --- DDRs -----------------------------------------------------------------------------------------
    -- cas de l'adc lent
    slowInstance: if speed = 100 generate
      iddr_x: IDDR
        generic map (
          DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"
        )
        port map (
          C  =>  clkDelayed,
          CE => '1',
          D  => del_to_ddr(i),
          R  => '0',
          S  => '0',
          Q1 => ddrQ(2*i),
          Q2 => ddrQ(2*i+1)    
        );
      end generate slowInstance;
    -- cas de l'adc rapide
    fastInstance: if speed = 250 generate
      iddr_x: IDDR
        generic map (
          DDR_CLK_EDGE => "SAME_EDGE_PIPELINED"
        )
        port map (
          C  =>  clkDelayed,
          CE => '1',
          D  => del_to_ddr(i),
          R  => '0',
          S  => '0',
          Q1 => ddrQ(2*i+1),
          Q2 => ddrQ(2*i)        
        );
      end generate fastInstance;
  end generate make_path;
  
----------------------------------------------------------------------------------------------------
-- Fourniture d'un bit de donnée au bus de calibration:
-- Le numéro du bit d'entrée à tester est donné par le champ bit_nr du bus de calibration (0 à 7)
-- Le résultat de démultiplexage de ce bit est évalué en échantillonnant avec sa propre horloge le
-- bit pair (0 2 ... 14) correspondant en sortie de ddr. Ledit bit est ensuite mis sur le bus après
-- rééchantillonnage par l'horloge système (process provideSyncData)

dataSample: process (clkDelayed)
begin
  if rising_edge (clkDelayed) then
    syncData   <= ddrQ(conv_integer(bitAdr)); -- l'index doit être "statique" c'est à dire
  end if;                                     -- correspondre à un signal fabriqué en dehors
end process;                                  --  du process (foi de forum...)

----------------------------------------------------------------------------------------------------
-- Échantillonnage de l'horloge ADC par l'horloge système pour aligner les fronts
-- Échantillonné en synchronisme avec sync

--clockSample: process (sysClk)
--begin
--  if rising_edge(sysClk) then
--    if sync = '1' and clkDelayed = '0' then
--      sysClkTest <= '0';
--    elsif sync = '1' and clkDelayed = '1' then
--      sysClkTest <= '1';
--    end if; -- inchangé si sync = '0'
--  end if;
--end process;

clockSample: process (sysClk)
begin
  if rising_edge(sysClk) then
    sysClkTest <= clkDelayed;
  end if;
end process;

----------------------------------------------------------------------------------------------------
-- Rééchantillonnage et fourniture synchrone avec l'horloge système

decod <= '1' when alignBus.adc_adr = ADC_NR else '0';

provideSyncData: process (sysClk)
begin
  if rising_edge(sysClk) then
    if decod = '1' and alignBus.mode = SHOW_DATA_BIT then -- si la donnée est demandée
      alignDataBit <= syncData;
    elsif decod = '1' and alignBus.mode = SHOW_SYS_CLK then
      alignDataBit <= sysClkTest;
    else
      alignDataBit <= '0';
    end if;
  end if;
end process;
----------------------------------------------------------------------------------------------------

end Behavioral;

