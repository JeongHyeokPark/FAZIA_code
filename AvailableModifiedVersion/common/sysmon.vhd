--------------------------------------------------------------------------------
-- Company:  IPN ORSAY
-- Engineer: Franck SALOMON
--
-- Create Date:    14/06/2012
  
-- Description:   System monitoring pour l'acquisition de
--                - la temperature au coeur du FPGA
--                - la valeur de VCCINT
--                - la valeur de VCCAUX
--------------------------------------------------------------------------------

Library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;

entity USERSYSMON is
port(
  clk100   : in STD_LOGIC;
  reset    : in STD_LOGIC;
  order    : in STD_LOGIC;
  user_channel : in STD_LOGIC_VECTOR(1 DOWNTO 0);
  mydready : out STD_LOGIC;
  value    : out STD_LOGIC_VECTOR(9 DOWNTO 0);
  chanout  : out STD_LOGIC_VECTOR(4 DOWNTO 0)
);
end USERSYSMON;


ARCHITECTURE toto OF USERSYSMON IS

  -- Signaux pour le control monitoring
  signal dobus       : std_logic_vector(15 downto 0);
  signal busy        : std_logic;
  signal dready      : std_logic;
  signal den         : std_logic;
  signal din         : std_logic_vector(15 downto 0);
  signal dwe         : std_logic;
  signal convst      : std_logic;
  signal daddr       : std_logic_vector(6 downto 0);
  

  type state_type is (S0,S1,S2,S2BIS,S3,SRESULT);
  signal state       : state_type;



  COMPONENT My_sysmon
  PORT (
    CONVST_IN     : in  STD_LOGIC;                         -- Convert Start Input
    DADDR_IN      : in  STD_LOGIC_VECTOR (6 downto 0);     -- Address bus for the dynamic reconfiguration port
    DCLK_IN       : in  STD_LOGIC;                         -- Clock input for the dynamic reconfiguration port
    DEN_IN        : in  STD_LOGIC;                         -- Enable Signal for the dynamic reconfiguration port
    DI_IN         : in  STD_LOGIC_VECTOR (15 downto 0);    -- Input data bus for the dynamic reconfiguration port
    DWE_IN        : in  STD_LOGIC;                         -- Write Enable for the dynamic reconfiguration port
    RESET_IN      : in  STD_LOGIC;                         -- Reset signal for the System Monitor control logic
    BUSY_OUT      : out  STD_LOGIC;                        -- ADC Busy signal
    CHANNEL_OUT   : out  STD_LOGIC_VECTOR (4 downto 0);    -- Channel Selection Outputs
    DO_OUT        : out  STD_LOGIC_VECTOR (15 downto 0);   -- Output data bus for dynamic reconfiguration port
    DRDY_OUT      : out  STD_LOGIC;                        -- Data ready signal for the dynamic reconfiguration port
    EOC_OUT       : out  STD_LOGIC;                        -- End of Conversion Signal
    EOS_OUT       : out  STD_LOGIC;                        -- End of Sequence Signal
    VP_IN         : in  STD_LOGIC;                         -- Dedicated Analog Input Pair
    VN_IN         : in  STD_LOGIC
  );
  END COMPONENT;

BEGIN

  --etat <= conv_std_logic_vector(state_type'pos(state),4);

  sysmon_inst: My_sysmon
  PORT MAP(
    CONVST_IN     => convst,
    DADDR_IN      => daddr,
    DCLK_IN       => clk100,
    DEN_IN        => den,
    DI_IN         => din,
    DWE_IN        => dwe,
    RESET_IN      => reset,
    BUSY_OUT      => busy,
    CHANNEL_OUT   => chanout,
    DO_OUT        => dobus,
    DRDY_OUT      => dready,
    EOC_OUT       => open,
    EOS_OUT       => open,
    VP_IN         => '0',
    VN_IN         => '0'
  );

sysmon_proc_sm : process(clk100,reset)
  begin
    if (reset = '1') then
      den             <= '0';
      dwe             <= '0';
      daddr           <= "1000000";
      state           <= S0;
      value           <= (others => '0');
      convst          <= '0';
      mydready        <= '0';
      
    elsif rising_edge(clk100) then        
      case state is
      when S0 =>
        if (order = '1') then
          mydready        <= '0';
          convst <= '0';
          if (busy = '0') then
            daddr           <= "1000000";
            din             <= X"0200" or ("00000000000000" & user_channel);
            den <= '1';
            dwe <= '1';
            state <= S1;
          else
            if (dready = '1') then
              state <= SRESULT;
            else
              state <= S0;
            end if;
          end if;
        else
          state <= S0;
        end if;
      
      when S1 => 
        dwe <= '0';
        den <= '0';
        state <= S2;
        
      
      when S2 =>
        if (busy = '0') then
          state <= S2BIS;
          convst <= '1';
        else
          state <= S2;
        end if;
      
      when S2BIS =>
        if (busy = '1') then
          convst <= '0';
          state <= S3;
        else
          state <= S2BIS;
        end if;
      
      when S3 =>
        if (busy = '0') then
          den <= '1';
          daddr <= "00000" & user_channel;
          state <= SRESULT;
        else
          state <= S3;
        end if;
      
      when SRESULT =>
        den <= '0';   
        if (dready = '1') then
          mydready <= '1';
          value <= dobus(15 downto 6);
          state <= S0;
        else
          state <= SRESULT;
        end if;
       
       when others =>
         den <= '0';
         dwe <= '0';
         convst <= '0';
         state <= S0;
         
      end case;
    end if;
  end process sysmon_proc_sm;

end toto;
