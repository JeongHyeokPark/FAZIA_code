--------------------------------------------------------------------------------
-- Company:  IPN ORSAY
-- Engineer: Franck SALOMON
--
-- Create Date:    13/01/2012
  
-- Description:   Module Fastlink
-- 
--------------------------------------------------------------------------------

Library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;

--------------------------------------------------------------------------------

ENTITY FASTLINK IS
GENERIC(
  last          : boolean;
  withChipScope : boolean
  );

PORT(
  clk100MHz_sys : in  STD_LOGIC;
  clk25MHz_sys  : in  STD_LOGIC;
  reset         : in  STD_LOGIC;
  sdi_p         : in  STD_LOGIC;
  sdi_n         : in  STD_LOGIC;
  sdi_H_p       : in  STD_LOGIC;
  sdi_H_n       : in  STD_LOGIC;
  sdi_L_p       : in  STD_LOGIC;
  sdi_L_n       : in  STD_LOGIC;
  alignIn       : in  STD_LOGIC;
  voieInt       : in  STD_LOGIC;
  --voieInt_VM    : in  STD_LOGIC;
  hostIn        : in  STD_LOGIC_VECTOR(15 downto 0);
  --hostInVM      : in  STD_LOGIC_VECTOR(15 downto 0);
  hostOut       : out STD_LOGIC_VECTOR( 7 downto 0);
  spyvd16bus    : out STD_LOGIC_VECTOR(15 downto 0);
  alignOut      : out STD_LOGIC;
  sdo_p         : out STD_LOGIC;
  sdo_n         : out STD_LOGIC;
  sdo_H_p       : out STD_LOGIC;
  sdo_H_n       : out STD_LOGIC;
  sdo_L_p       : out STD_LOGIC;
  sdo_L_n       : out STD_LOGIC
  );
END FASTLINK;

--------------------------------------------------------------------------------

ARCHITECTURE BEHAVIORAL OF FASTLINK IS

  -- déclaration de composants
  
  COMPONENT clkgenerator
  PORT(
  CLK100IN    : in  STD_LOGIC;
  CLK25IN     : in  STD_LOGIC;
  reset       : in  STD_LOGIC;
  CLK50OUT    : out STD_LOGIC;
  CLK200OUT   : out STD_LOGIC;
  CLK400OUT   : out STD_LOGIC;
  CLK100OUT   : out STD_LOGIC;
  CLK25SYNC   : out STD_LOGIC;
  LOCKED_PLL  : out STD_LOGIC
  );
  END COMPONENT;

  COMPONENT SERIALISEUR
  PORT(
  clk50        : in  STD_LOGIC;
  clk4x        : in  STD_LOGIC;
  reset        : in  STD_LOGIC;
  din_ser      : in  STD_LOGIC_VECTOR(7 downto 0);
  out400_p     : out STD_LOGIC;
  out400_n     : out STD_LOGIC
  );
  END COMPONENT;

  COMPONENT DESERIALISEUR
  GENERIC(
  cs : boolean
  );  
  PORT(
  clk50     : in STD_LOGIC;
  clk4x     : in STD_LOGIC;
  alignIn   : in STD_LOGIC;
  reset     : in  STD_LOGIC;
  sdi_p     : in  STD_LOGIC;
  sdi_n     : in  STD_LOGIC;
  dout_des  : out STD_LOGIC_VECTOR(7 downto 0)
    );
  END COMPONENT;

  COMPONENT myfifo
  PORT(
	rst       : IN STD_LOGIC;
	wr_clk    : IN STD_LOGIC;
	rd_clk    : IN STD_LOGIC;
	din       : IN STD_LOGIC_VECTOR(15 downto 0);
	wr_en     : IN STD_LOGIC;
	rd_en     : IN STD_LOGIC;
	dout      : OUT STD_LOGIC_VECTOR(15 downto 0);
	full      : OUT STD_LOGIC;
	empty     : OUT STD_LOGIC
 	--rd_data_count: out std_logic_vector(3 downto 0);
	--wr_data_count: out std_logic_vector(3 downto 0)
  );
  END COMPONENT;
  
  COMPONENT myfifo2
  PORT(
	rst       : IN STD_LOGIC;
	wr_clk    : IN STD_LOGIC;
	rd_clk    : IN STD_LOGIC;
	din       : IN STD_LOGIC_VECTOR(7 downto 0);
	wr_en     : IN STD_LOGIC;
	rd_en     : IN STD_LOGIC;
	dout      : OUT STD_LOGIC_VECTOR(7 downto 0);
	full      : OUT STD_LOGIC;
	empty     : OUT STD_LOGIC
  );
  END COMPONENT;
  
--===== chipscope =============================================================================

signal all_zero_128 : std_logic_vector (128 downto 0) := (others => '0');
signal CONTROL0 : std_logic_vector (35 downto 0);

component tel_ila_128
  PORT (
    CONTROL : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0);
    CLK     : IN STD_LOGIC;
    TRIG0   : IN STD_LOGIC_VECTOR(127 DOWNTO 0)
  );
end component;

component tel_icon
  PORT (
    CONTROL0 : INOUT STD_LOGIC_VECTOR(35 DOWNTO 0));
end component;

--=============================================================================================

  -- déclaration de signaux internes
  
  -- signaux d'horloge
  signal clk50MHz         : STD_LOGIC;
  signal clk100MHz        : STD_LOGIC;
  signal clk200MHz        : STD_LOGIC;
  signal clk400MHz        : STD_LOGIC;
  signal clk25MHz_sync    : STD_LOGIC;
  signal locked_pll       : STD_LOGIC;

  -- signal de demande d'alignement
  signal align_int        : STD_LOGIC;

  -- signaux de reset
  signal SR_sig           : STD_LOGIC;
  signal reset_eff2       : STD_LOGIC;
  signal reset_eff        : STD_LOGIC;
  signal reset_int        : STD_LOGIC;

  -- signal pour IDELAYCTRL
  signal idlayctrl_rdy    : STD_LOGIC;
  
  -- compteur pour générer le reset SR_SIG (process)
  signal compteur         : STD_LOGIC_VECTOR(3 downto 0);

  -- signaux de données
  signal din_ser          : STD_LOGIC_VECTOR(7 downto 0);
  signal octet_ser_VM     : STD_LOGIC_VECTOR(7 downto 0);
  signal dout_H           : STD_LOGIC_VECTOR(7 downto 0);
  signal dout_L           : STD_LOGIC_VECTOR(7 downto 0);
  signal MSB              : STD_LOGIC_VECTOR(7 downto 0);
  --signal MSB_VM           : STD_LOGIC_VECTOR(7 downto 0);
  --signal LSB_VM           : STD_LOGIC_VECTOR(7 downto 0);
  signal LSB              : STD_LOGIC_VECTOR(7 downto 0);
  signal hout             : STD_LOGIC_VECTOR(7 downto 0);
  signal hout_int         : STD_LOGIC_VECTOR(7 downto 0);
  signal hostin_int       : STD_LOGIC_VECTOR(15 downto 0);
  --signal hostin_int_rdy   : STD_LOGIC;
  --signal hostInVM_int     : STD_LOGIC_VECTOR(15 downto 0);
  signal voieInt_int      : STD_LOGIC;
  signal MSB_sync         : STD_LOGIC;
  signal LSB_sync         : STD_LOGIC;
  signal clk25Resync_late : STD_LOGIC;
  signal sync_50          : STD_LOGIC;
  signal spyvd16busInt    : STD_LOGIC_VECTOR(15 downto 0);
  
  --type state_typewr is (WRMSB,WRLSB);
  --signal statewr : state_typewr;
  
-----------------------------------------------------------
-- signaux fictifs uniquement pour 'last'
signal sdi_h, sdi_l : std_logic;
signal sdi_vm       : std_logic;
-----------------------------------------------------------

--signal 	rd_data_count_1: std_logic_vector(3 downto 0);
--signal 	wr_data_count_1: std_logic_vector(3 downto 0);
--signal 	rd_data_count_3: std_logic_vector(3 downto 0);
--signal 	wr_data_count_3: std_logic_vector(3 downto 0);


BEGIN

makeCS: if withChipScope generate
mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0);

mes_sondes : tel_ila_128
  port map (
    CONTROL => CONTROL0,
    CLK     => clk100MHz,
    ---
   TRIG0 (0) => reset,
   trig0 (1) => reset_eff,
   trig0 (2) => reset_eff2,
	 trig0 (3) => alignIn,
   
	 TRIG0 (46  downto 4)   => all_zero_128(46 downto 4),
   
--   trig0 (51 downto 48) => rd_data_count_1,
--   trig0 (55 downto 52) => wr_data_count_1,
--   trig0 (59 downto 56) => rd_data_count_3,
--   trig0 (63 downto 60) => wr_data_count_3,
 
   trig0 (47)   => voieInt_int, 
   trig0 (55 downto 48) => hout, 
   trig0 (63 downto 56 ) => hout_int,
   trig0 (71  downto 64)  => MSB,
   trig0 (79  downto 72)  => LSB,
   trig0 (95  downto 80)  => hostIn,
   trig0 (111 downto 96)  => hostin_int,
	 TRIG0 (127 downto 112) => spyvd16busInt
	);
end generate;
	 
	 
  spyvd16bus     <= spyvd16busInt;
  align_int      <= alignIn;
  alignOut       <= align_int;
  reset_int      <= reset;
  
  
  voieInt_int    <= '1' when last else voieInt;
  
  
  idel_ctrl: IDELAYCTRL
  PORT MAP(
  refClk => clk200MHz,
  rst    => reset_eff,
  rdy    => idlayctrl_rdy
  );
  
  reset_eff  <= reset_int OR NOT locked_pll;
  reset_eff2 <= reset_eff OR NOT idlayctrl_rdy;

  clkgen_inst : clkgenerator
  PORT MAP(
  CLK100IN    => clk100MHz_sys,
  CLK25IN     => clk25MHz_sys,
  reset       => reset,
  CLK50OUT    => clk50MHz,
  CLK200OUT   => clk200MHz,
  CLK400OUT   => clk400MHz,
  CLK100OUT   => clk100MHz,
  CLK25SYNC   => clk25MHz_sync,
  LOCKED_PLL  => locked_pll
  );

    deser_VM : DESERIALISEUR
	 GENERIC MAP (
	   cs => false
	 )
    PORT MAP(
    clk50     => clk50MHz,
    clk4x     => clk400MHz,
    alignIn   => align_int,
    reset     => SR_sig,
    sdi_p     => sdi_p,
    sdi_n     => sdi_n,
    dout_des  => din_ser
    );


  DESER_GEN : IF not last GENERATE
    deser_H : DESERIALISEUR
	 GENERIC MAP (
	   cs => false
	 )
    PORT MAP(
    clk50     => clk50MHz,
    clk4x     => clk400MHz,
    alignIn   => align_int,
    reset     => SR_sig,
    sdi_p     => sdi_H_p,
    sdi_n     => sdi_H_n,
    dout_des  => dout_H
    );

    deser_L : DESERIALISEUR
	 GENERIC MAP (
	   cs => false
	 )
    PORT MAP(
    clk50     => clk50MHz,
    clk4x     => clk400MHz,
    alignIn   => align_int,
    reset     => SR_sig,
    sdi_p     => sdi_L_p,
    sdi_n     => sdi_L_n,
    dout_des  => dout_L
    );

    ser_VM : SERIALISEUR
    PORT MAP(
    clk50        => clk50MHz,
    clk4x        => clk400MHz,
    reset        => SR_sig,
    din_ser      => octet_ser_VM,
    out400_p     => sdo_p,
    out400_n     => sdo_n
    );
  END GENERATE DESER_GEN;

-------------------------------------------------
buffers_muets: if last generate
  --sdo_p <= '0' WHEN last;
  --sdo_n <= '1' WHEN last;
  
obuf_inst: OBUFDS
  GENERIC MAP(
    CAPACITANCE => "DONT_CARE",
    IOSTANDARD  => "LVDS_25"
  )
  PORT MAP(
    O  => sdo_p,
    OB => sdo_n,
    I  => '0'
  );

IBUFDS_inst_1 : IBUFDS
   generic map (
      CAPACITANCE => "DONT_CARE", DIFF_TERM => FALSE, 
      IBUF_DELAY_VALUE => "0", IFD_DELAY_VALUE => "AUTO", IOSTANDARD => "DEFAULT")
   port map (I => sdi_h_p, IB => sdi_h_n, O => sdi_h);

IBUFDS_inst_2 : IBUFDS
   generic map (
      CAPACITANCE => "DONT_CARE", DIFF_TERM => FALSE, 
      IBUF_DELAY_VALUE => "0", IFD_DELAY_VALUE => "AUTO", IOSTANDARD => "DEFAULT")
   port map (I => sdi_l_p, IB => sdi_l_n, O => sdi_l);
   
end generate buffers_muets;
-------------------------------------------------

--buffer_muet_deux: if deservm_dev generate
--IBUFDS_inst_3 : IBUFDS
--   generic map (
--      CAPACITANCE => "DONT_CARE", DIFF_TERM => FALSE, 
--      IBUF_DELAY_VALUE => "0", IFD_DELAY_VALUE => "AUTO", IOSTANDARD => "DEFAULT")
--   port map (I => sdi_p, IB => sdi_n, O => sdi_vm);
--end generate;

--------------------------------------------------
 
  ser_H : SERIALISEUR
  PORT MAP(
  clk50        => clk50MHz,
  clk4x        => clk400MHz,
  reset        => SR_sig,
  din_ser      => MSB,
  out400_p     => sdo_H_p,
  out400_n     => sdo_H_n
  );

  ser_L : SERIALISEUR
  PORT MAP(
  clk50        => clk50MHz,
  clk4x        => clk400MHz,
  reset        => SR_sig,
  din_ser      => LSB,
  out400_p     => sdo_L_p,
  out400_n     => sdo_L_n
  );

  fifo1: myfifo
  PORT MAP(
  rst              => reset_eff2,
  wr_clk           => clk100MHz,
  rd_clk           => clk100MHz_sys,
  din(15 downto 8) => MSB,
  din(7 downto 0)  => LSB,
  wr_en            => '1',
  rd_en            => '1',
  dout             => spyvd16busInt,
  full             => open,
  empty            => open
  --rd_data_count    => rd_data_count_1,
	--wr_data_count    => wr_data_count_1

  );
  
  fifo2: myfifo2
  PORT MAP(
  rst              => reset_eff2,
  wr_clk           => clk100MHz,
  rd_clk           => clk100MHz_sys,
  din              => hout,
  wr_en            => '1',
  rd_en            => '1',
  dout             => hout_int,
  full             => open,
  empty            => open
  );

  fifo3: myfifo
  PORT MAP(
  rst              => reset_eff2,
  wr_clk           => clk100MHz_sys,
  rd_clk           => clk100MHz,
  din              => hostIn,
  wr_en            => '1',
  rd_en            => '1',
  dout             => hostin_int,
  full             => open,
  empty            => open
  --rd_data_count    => rd_data_count_3,
	--wr_data_count    => wr_data_count_3
  );

  hostOut <= hout_int;
  

---------- Process dédié au reset des sérialiseurs et désérialiseurs -----
  SR_sig_proc: PROCESS(clk100MHz,reset_eff2)
  BEGIN
    IF (reset_eff2 = '1') THEN
      compteur <= (others => '0');
      SR_sig <= '1';
    ELSIF rising_edge(clk100MHz) THEN
      IF (compteur < 5) THEN
        compteur <= compteur + 1;
        SR_sig <= '1';
      ELSE
        SR_sig <= '0';
      END IF;
    END IF;
  END PROCESS SR_sig_proc;
-----------------------------------------------------------------------------

  send_data_VM : process(clk100MHz,SR_sig)
  begin
    if (SR_sig = '1') then
      octet_ser_VM <= X"80";
      --MSB_VM <= X"80";
      --LSB_VM <= X"80";
      --dataVM_rdy_int <= '0';
      hout <= X"80";
    elsif rising_edge(clk100MHz) then
      if (align_int = '0') then
        if (sync_50 = '1') then
          octet_ser_VM <= din_ser;
          hout         <= din_ser;
        end if;
		else
		  octet_ser_VM <= X"80";
		  hout <= X"80";
      end if;
    end if;
  end process send_data_VM;



-------------------------------------------------------------------------------------------------
-- génération des signaux de synchro
gen_25_late: process (clk100MHz)
begin
  if rising_edge(clk100MHz) then
    clk25Resync_late <= clk25MHz_sync;
  end if;
end process;
------------------------------------
-- sync: période 40 ns (synchro 25 MHz) durée 10 ns
MLSB_sync_proc: process (clk100MHz, reset_eff2)
begin
  if reset_eff2 = '1' then
    MSB_sync <= '0';
    LSB_sync <= '0';
  elsif rising_edge(clk100MHz) then
    if (align_int = '0') then
      MSB_sync <= not clk25MHz_sync and not clk25Resync_late;
      LSB_sync <= clk25Resync_late and clk25MHz_sync;
      sync_50  <= (not clk25MHz_sync and not clk25Resync_late) or (clk25MHz_sync and clk25Resync_late);
    end if;
  end if;
end process;



----------- Process de transmission de données des DESER vers les SER dans les deux voies descendantes ----------------
  data_proc: process(clk100MHz,SR_sig)
  begin
    if (SR_sig = '1') then
      MSB          <= X"80";
      LSB          <= X"80";
    elsif rising_edge(clk100MHz) then
      if (align_int = '0') then
        if (voieInt_int = '1') then
          if (sync_50 = '1') then
            --if (hostin_int_rdy = '0') then
              MSB      <= hostin_int(15 downto 8);
              LSB      <= hostin_int(7  downto 0);
            --end if;
          end if; -- if (sync_50 = '1')
        else
          if (sync_50 = '1') then
            MSB      <= dout_H;
            LSB      <= dout_L;
          end if;
        end if; -- if (voieInt_int = '1')
		else
		  MSB <= X"80";
		  LSB <= X"80";
      end if; -- if (align_int = '0')
    end if;
  end process data_proc; 


END BEHAVIORAL;


