--------------------------------------------------------------------------------
-- Company:  INFN / IPN ORSAY
-- Engineer: Alphonso BOIANO /  modifié par Franck SALOMON
--
-- Create Date:    05/01/2012
  
-- Description:   Module désérialiseur
-- 
--------------------------------------------------------------------------------
Library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
library UNISIM;
use UNISIM.vcomponents.all;
 
ENTITY N_ISERDES8b_MsAllign IS
GENERIC(
  withChipScope : boolean
  );
port (CLK50MHz, BCLK400MHz, CLK400MHz, RESET : 	in  STD_LOGIC; -- CLK & RESET
--      ref_clk : in  STD_LOGIC; --  CLK 200MHZ
      Allinea : in  STD_LOGIC; --  CONTROLLO 
      SDIN_N , SDIN_P :	in  STD_LOGIC; --  INPUT
      DOUT : out std_logic_VECTOR(7 downto 0) -- OUT
);			 
END N_ISERDES8b_MsAllign;

architecture Behavioral of N_ISERDES8b_MsAllign is


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

-- ===========================================================
    -- Component Declaration 
 
COMPONENT ISER8b
PORT(
       CLK50MHz   : IN  std_logic;
       CLK400MHz  : IN  std_logic;
       BCLK400MHz : IN  std_logic;
       RESET      : IN  std_logic;
       SDIN_N     : IN  std_logic;
       SDIN_P     : IN  std_logic;
       IBSLIP     : IN  std_logic;
       INC_DEL    : IN  std_logic;
       INC_CE     : IN  std_logic;
       DOUT       : OUT std_logic_vector(7 downto 0)
      );
END COMPONENT;


--===================================================================================
-- COSTANTI & SEGNALI 
 -- x mS    STATI
type state_type is (S0,SWAIT,LATCH,INCR,CONFR,INCR2,CONFR2,DECR2,CONFR3,ZEROa,SET_INCR,ZEROb,S_BSLIP,BSWAIT,MATCH,FINE,ERROR);  

signal state        : state_type ; -- Variabili per gli STATI

signal CONTA        : std_logic_vector(7 downto 0); -- Conta le fasi nella MS
signal DLATCH       : std_logic_vector(7 downto 0); -- Conta le fasi nella MS
signal Sync_Allinea : std_logic;       -- Segnali  Sincronizzati
signal IBSLIP       : std_logic;       -- BITSLIP ISERDES
signal INC_DEL      : std_logic;       -- INC_DEL  DELAY
signal INC_CE       : std_logic;       -- INC_CE  DELAY
signal intdout      : std_logic_vector (7 downto 0);

signal cp1          : std_logic_vector (5 downto 0);
signal cp2          : std_logic_vector (5 downto 0);
signal cptest       : std_logic_vector (7 downto 0);
signal mylisten     : std_logic_vector (4 downto 0);
--signal eye_area_rdy : std_logic;


BEGIN

makeCS: if withChipScope generate
mon_icon : tel_icon
  port map (
    CONTROL0 => CONTROL0);

mes_sondes : tel_ila_128
  port map (
   CONTROL => CONTROL0,
   CLK     => CLK50MHz,
    ---
   TRIG0 (0) => RESET,
   TRIG0 (1) => Allinea,
	TRIG0 (2) => INC_CE,
	TRIG0 (3) => IBSLIP,
   TRIG0 (11 downto 4) => intdout,
	TRIG0 (16 downto 12) => mylisten,
	TRIG0 (22 downto 17) => cp1,
	TRIG0 (30 downto 23) => cptest,
	TRIG0 (36 downto 31) => cp2,
	TRIG0 (127  downto 37)   => all_zero_128(127 downto 37)
	);
end generate;



 --  ISTANZIA COMPONENTI   --------------------------------
 ------------------------------------------------------------
	-- Instantiate the ISER8b 
AISER8b: ISER8b 
PORT MAP (
          CLK50MHz => CLK50MHz,
          CLK400MHz => CLK400MHz,
          BCLK400MHz => BCLK400MHz,
          RESET => RESET,
          SDIN_N => SDIN_N,
          SDIN_P => SDIN_P,
          DOUT => intdout,
          IBSLIP =>  IBSLIP, 
          INC_DEL => INC_DEL,
          INC_CE => INC_CE
         );


--------------------------------------------------------------------


DOUT <= intdout;

mylisten <= conv_std_logic_vector(state_type'pos(state), 5);

-- Processo sequenziale X MS
-- STATI  S0,SWAIT,LATCH,INCR,CONFR,ZEROa,SET_INCR,ZEROb,S_BSLIP,BSWAIT,MATCH,FINE,ERROR

MS_P1: process (CLK50MHz,RESET)  
begin  
  if (RESET = '1') then   -- RESET
     state <=S0;  
     Sync_Allinea <= '0'; -- sEGNALE sYNCRONIZZ
     DLATCH <= X"00"; --
     CONTA <=  X"00"; --
	  
  elsif (CLK50MHz='1' and CLK50MHz'Event) then  
 --    SINCRONIZZA ------------------------
     Sync_Allinea <= Allinea ;
 --   STATI 
     case state is 
     when s0       => state        <= SWAIT ;
                      cp1          <= (others => '0');
                      cp2          <= (others => '0');
                      cptest       <= (others => '0');
                      INC_DEL      <= '1';
                      --eye_area_rdy <= '0';
                      CONTA <=  X"00";
  
     when SWAIT    => if (Sync_Allinea = '1') then 
                        --state <= LATCH;
                      --else
                        --state <= SWAIT;
                      --end if;
                        if CONTA = X"FF" then
                          state <= LATCH;  
                        else
                          CONTA <= CONTA + 1;
                          state <= SWAIT;
                        end if;
                      else 
                        state <= SWAIT;  
                      end if;  
							
     when LATCH    => DLATCH <= intdout;
                      if intdout = X"00" then 
                        state <= LATCH;                
                      else 
                        state <= INCR; 
                      end if;
                      CONTA <=  X"00";
                        
     when INCR     => state <= CONFR;
                      CONTA <= CONTA + 1; -- INCREMENTA 
		
     when CONFR    => if CONTA > X"50" then state <= ERROR ;  -- TIMEOUT ERRORE 
                      elsif (DLATCH = intdout) then 
                        state <= INCR ;  -- Incrementa delay
                      else 
                        DLATCH <= intdout;
                        state <= CONFR2;  -- Incrementa delay        
                      end if; 

     when INCR2    => cp1 <= cp1 + 1;
                      state <= CONFR2;
     
     when CONFR2   => if (DLATCH = intdout) then
                        if (cptest < X"FF") then
                          cptest <= cptest + 1;
                          state <= CONFR2;
                        else
                          cptest       <= (others => '0');
                          state        <= INCR2;
                          --eye_area_rdy <= '1';
                        end if;
                      else
								DLATCH <= intdout;
                        if (cp1>X"19") then
                          INC_DEL <= '0';
                          state <= DECR2;
                        else
								  cp1    <= (others => '0');
								  cptest <= (others => '0');
								  CONTA  <= (others => '0');
                          state  <= INCR;
                        end if;
                      end if;

     when DECR2    => cp2 <= cp2 +1;
                      state <= CONFR3;
                      
     when CONFR3   => if (cp2 = cp1(5 downto 1)) then
                        state    <= ZEROa;
                      else
                        state <= DECR2;
                      end if;                        
								
     when ZEROa    => state <= SET_INCR;
                      CONTA <=  X"00";
					  
		
     when SET_INCR => CONTA <= CONTA + 1; -- INCREMENTA
		                  if CONTA > X"0F" then state <= ZEROb ;  -- Setta a met della durata
                      else state <= SET_INCR ;  -- Rimane nello STATO      
                      end if; 
		
     when ZEROb    => state <= S_BSLIP;
	                    CONTA <=  X"00";
		
     when S_BSLIP  => state <= BSWAIT;
	                    CONTA <= CONTA + 1; -- INCREMENTA

     when BSWAIT   => CONTA <= CONTA + 1;
                      if (CONTA(1 downto 0)/="00") then state <= BSWAIT;
                      else state <= MATCH;
                      end if;
		
     when MATCH    => if CONTA > X"F0" 	then state <= ERROR ;  -- TIMEOUT ERRORE 
		                  elsif (intdout = X"80") then state <= FINE ;  -- OK FINE
                      else state <= S_BSLIP;  -- Rimane nello STATO      
                      end if; 
	
								
     when FINE     => if Sync_Allinea = '0' then state <= s0 ;   --    FINE
                      else 
                        state     <= FINE;  
                      end if; 
								
     when OTHERS   => if Sync_Allinea = '0' then state <= s0 ;  --   ERROR
                      else state <= ERROR;  
                      end if; 
								
     end case;  
  end if;  
end process MS_P1;
---------------------------------------------------  
 --    Assegnazione  USCITE
 -- STATI  S0,SWAIT,LATCH,INCR,CONFR,ZEROa,SET_INCR,ZEROb,S_BSLIP,MATCH,FINE,ERROR

MS_OUT : process (state)  
begin  
    case state is  
	
    when S0       => IBSLIP <= '0';  --S0
                     INC_CE <= '0'; 
	  
    when SWAIT    => IBSLIP <= '0';  --SWAIT
                     INC_CE <= '0';
					   
    when LATCH    => IBSLIP <= '0';  -- LATCH
                     INC_CE <= '0';
					   
    when INCR     => IBSLIP <= '0';  -- INCR 
                     INC_CE <= '1';

    when CONFR    => IBSLIP <= '0';  -- CONFR
                     INC_CE <= '0';

    when INCR2    => IBSLIP <= '0';  -- INCR2 
                     INC_CE <= '1';

    when CONFR2   => IBSLIP <= '0';  -- CONFR2
                     INC_CE <= '0';
                     
    when DECR2    => IBSLIP <= '0';  -- DECR2
                     INC_CE <= '1';

    when CONFR3   => IBSLIP <= '0';  -- CONFR3
                     INC_CE <= '0';                 
					   
    when ZEROa    => IBSLIP <= '0';  -- ZEROa
                     INC_CE <= '0';
					   
    when SET_INCR => IBSLIP <= '0';  -- SET_INCR
                     INC_CE <= '0';
			   
    when ZEROb    => IBSLIP <= '0';  -- ZEROb
                     INC_CE <= '0';
					   
    when S_BSLIP  => IBSLIP <= '1';  -- S_BSLIP 
                     INC_CE <= '0';

    when BSWAIT   => IBSLIP <= '0';
                     INC_CE <= '0';
					   
    when MATCH 	  => IBSLIP <= '0';  -- MATCH
                     INC_CE <= '0';
					   
    when FINE     => IBSLIP <= '0';  -- FINE
                     INC_CE <= '0';
                     
    when OTHERS   => IBSLIP <= '0';  -- ERROR
                     INC_CE <= '0';				 
    end case;           
end process MS_OUT;  
----------------------------------------------------------------------------
END;
