----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date:    10:52:49 01/12/2017 
-- Design Name: 
-- Module Name:    baseline - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
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
--use IEEE.STD_LOGIC_ARITH.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

--library fazia;
use work.tel_defs.all;

entity baseline is
   port ( 
      clk            : in  std_logic;
      reset          : in  std_logic;

      pretrig        : in std_logic_vector(7 downto 0);                    -- nb of samples before the fast low trigger comparator output [0..255]
      meanDepth      : in std_logic_vector(8 downto 0);                    -- nb of samples for baseline mean calculation  [1,2,4,8,16,32,64,128,256]
                                                                           -- should be a multiple of 2  to do the division with a right shift		

      din            : in  std_logic_vector(ADC_TOP downto 0);																				  
      dout           : out std_logic_vector(BL_TOP downto 0)               -- BL_TOP = ADC_TOP+BL_PRECISION_BITS
   );
end baseline;

architecture Behavioral of baseline is

  type BSL_STATE is (IDLE, LOAD_DATA);
  type CFG_STATE is (WAITING, UPDATE);
  type T_LUT_ARRAY is array (0 to 255) of integer range 0 to 8;  

-- bits function defined in tel_defs package
  constant BSL_BUF_SIZE       : integer := 256;                        -- dual port RAM 256x14 - maximum pretrig and meanDepth buffers size
  constant BSL_BUF_BITS       : integer := bits(BSL_BUF_SIZE);         -- circular buffer address bit size (8)
  constant MAX_POW2_BITS_NB   : integer := 8;					           -- maximum shift value for baseline mean calculation 2^8 = 256                                                                
  
--  constant wrEnCircBase : std_logic := '1';             -- à revoir / desactiver pendant slow control

-- power of 2 parameter look-up table
  constant LUT_ARRAY : T_LUT_ARRAY := (                                                                                                           -- end line index
  0               , 1               , 2               , 2               , 2               , 2               , 3               , 3               , --7
  3               , 3               , 3               , 4               , 4               , 4               , 4               , 4               , --15
  4               , 4               , 4               , 4               , 4               , 4               , 4               , 4               , --23
  5               , 5               , 5               , 5               , 5               , 5               , 5               , 5               , --31
  5               , 5               , 5               , 5               , 5               , 5               , 5               , 5               , --39
  5               , 5               , 5               , 5               , 5               , 5               , 5               , 5               , --47
  6               , 6               , 6               , 6               , 6               , 6               , 6               , 6               , --55
  6               , 6               , 6               , 6               , 6               , 6               , 6               , 6               , --63
  6               , 6               , 6               , 6               , 6               , 6               , 6               , 6               , --71
  6               , 6               , 6               , 6               , 6               , 6               , 6               , 6               , --79
  6               , 6               , 6               , 6               , 6               , 6               , 6               , 6               , --87
  6               , 6               , 6               , 6               , 6               , 6               , 6               , 6               , --95
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --103
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --111
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --119
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --127
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --135
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --143
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --151
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --159 
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --167
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --175
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --183
  7               , 7               , 7               , 7               , 7               , 7               , 7               , 7               , --191
  MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, --199
  MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, --207
  MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, --215
  MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, --223
  MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, --231
  MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, --239
  MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, --247
  MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB, MAX_POW2_BITS_NB  --255
);  

  signal bslSeq         : BSL_STATE;
  signal configSeq      : CFG_STATE;
  signal change         : std_logic;                                     -- set to '1' to load new pretrig and meanDepth value
  signal init           : std_logic;                                     -- set to '1' to reset the mean register content
  signal regCounter     : unsigned(7 downto 0); 
  signal wrEn           : std_logic;
  signal indexLUT       : integer range 0 to 255;
  signal uPretrig       : unsigned(BSL_BUF_BITS - 1 downto 0);           -- for conversion of std_logic_vector pretrig 
  signal oldPretrig     : unsigned(BSL_BUF_BITS - 1 downto 0);           -- for conversion of std_logic_vector pretrig 
  signal pretrigPtWr    : std_logic_vector(BSL_BUF_BITS - 1 downto 0);
  signal pretrigPtRd    : std_logic_vector(BSL_BUF_BITS - 1 downto 0); 
  signal pretrigOut     : std_logic_vector(ADC_TOP downto 0);
  signal sPretrigOut    : signed(ADC_TOP downto 0); 
  signal uMeanDepth     : unsigned(BSL_BUF_BITS - 1 downto 0);           -- for conversion of std_logic_vector meanDepth   
  signal oldMeanDepth   : unsigned(BSL_BUF_BITS - 1 downto 0);           -- for conversion of std_logic_vector meanDepth   
  signal meanPtWr       : std_logic_vector(BSL_BUF_BITS - 1 downto 0);
  signal meanPtRd       : std_logic_vector(BSL_BUF_BITS - 1 downto 0);
  signal meanIn         : std_logic_vector(ADC_TOP downto 0);
  signal meanOut        : std_logic_vector(ADC_TOP downto 0); 
  signal sMeanOut       : signed(ADC_TOP downto 0);   
--  signal sSum           : signed((ADC_TOP + MAX_POW2_BITS_NB) downto 0);
  signal pow2_bits_nb   : integer range 0 to 8;	                       -- shift factor for mean calculation
                                                                       -- for example if meanDepth = (2^8)-1 = 255  pow2_bits_nb = log2(2^8)

  signal oneValue       : std_logic_vector(7 downto 0) := "00000001";
  signal bl_precision   : integer range 1 to 256;

  signal sMeani         : signed((ADC_TOP + MAX_POW2_BITS_NB) downto 0);

  
-- circular buffer version 256 bytes
  component ram_256x14_modified
     port (
        clka:  in  std_logic;
        wea:   in  std_logic_vector(0 downto 0);
        addra: in  std_logic_vector(7 downto 0);
        dina:  in  std_logic_vector(13 downto 0);
        ---
        clkb:  in  std_logic;
        addrb: in  std_logic_vector(7 downto 0);
        doutb: out std_logic_vector(13 downto 0)
     );
 end component;

begin
   make_256_cirBufBsl: if BSL_BUF_SIZE = 256 generate
      pretrigBufCir: ram_256x14_modified
         port map (
           clka  => clk,
           wea(0)=> wrEn,   
           addra => pretrigPtWr, 
           dina  => din,
           ---
           clkb  => clk,
           addrb => pretrigPtRd,
           doutb => pretrigOut
         );
  
      meanBufCir: ram_256x14_modified
         port map (
           clka  => clk, 
           wea(0)=> wrEn,   
           addra => meanPtWr, 
           dina  => meanIn,
           ---
           clkb  => clk,
           addrb => meanPtRd,
           doutb => meanOut
         );  
  
   end generate;

   bl_precision <= TO_INTEGER(SHIFT_LEFT(signed(oneValue),BL_PRECISION_BITS));  -- a signal is needed for the shift left expression
   indexLUT     <= TO_INTEGER(unsigned(meanDepth)-1);  
   pow2_bits_nb <= (LUT_ARRAY(indexLUT)- BL_PRECISION_BITS) when (indexLUT+1) >= bl_precision else -- i.e if meanDepth > bl_precision
	                0;

   uPretrig   <= unsigned(pretrig);
   uMeanDepth <= TO_UNSIGNED(indexLUT,8);    -- we use the integer value to get (meanDepth-1) on 8 bits 
                                             -- since its max possible value is 0xFF(hex)

   meanIn <= din when (init = '0' and uPretrig = X"01") else
	          pretrigOut when init = '0' else
             (others => '0');	
 
   configure: process(clk, reset)
   begin
      if reset = '1' then
         oldPretrig   <= (others => '0');
         oldMeanDepth <= (others => '0');
         change       <= '0';
         configSeq    <= WAITING;
      elsif rising_edge(clk) then
         oldPretrig   <= uPretrig;
         oldMeanDepth <= uMeanDepth;
         case configSeq is
            when WAITING =>
               if uPretrig /= oldPretrig then
                  change    <= '0';
                  configSeq <= UPDATE;
               elsif uMeanDepth /= oldMeanDepth then
                  change    <= '0';
                  configSeq <= UPDATE;
               end if;	
            when UPDATE =>
               change <= '1';
               configSeq <= WAITING;
            when others =>
      null;          
        end case;
      end if;  
   end process configure;

-- cicular buffer address pointers	
   cirBufReadWrite: process (clk, reset)
   begin
     if reset = '1' then
        wrEn        <= '0';  
        pretrigPtWr <= (others => '0'); 
        pretrigPtRd <= (others => '0'); 
        meanPtWr    <= (others => '0'); 
        meanPtRd    <= (others => '0'); 
        regCounter  <= (others => '0');
        init        <= '0';    
        bslSeq  <= IDLE;   
     elsif rising_edge(clk) then
        case bslSeq is
           when IDLE =>
               wrEn        <= '0';
               pretrigPtWr <= std_logic_vector(uPretrig - 1);					
               pretrigPtRd <= (others => '0');
               meanPtWr    <= std_logic_vector(uMeanDepth); 
               meanPtRd    <= (others => '0');
               regCounter  <= (others => '0');
               init        <= '1';
               if change = '1' then
                  bslSeq  <= LOAD_DATA;
               end if;
           when LOAD_DATA =>
               wrEn        <= '1';
               pretrigPtWr <= pretrigPtWr + 1; 
               pretrigPtRd <= pretrigPtRd + 1; 
               meanPtWr    <= meanPtWr + 1; 
               meanPtRd    <= meanPtRd + 1; 
               if regCounter < TO_UNSIGNED((BSL_BUF_SIZE - 1),8) then
                  regCounter <= regCounter + 1;
               else
                  init <= '0';
               end if;
               if change = '0' then
                  bslSeq<= IDLE;
               end if;
            when others =>
                  null;
        end case;
     end if;  
   end process cirBufReadWrite;

-- baseline mean value calculation 
   sPretrigOut <= signed(pretrigOut);
   sMeanOut <= signed(meanOut);

   meanCalculation: process (clk, reset)
	   variable sSum   : signed((ADC_TOP + MAX_POW2_BITS_NB) downto 0);
   begin
      if reset = '1' then
         sSum    := "0000000000000000000000";
         sMeani  <= (others => '0');
      elsif rising_edge(clk) then
         if init = '1' then
            sSum    := "0000000000000000000000";
            sMeani  <= (others => '0');
         else
			   if uPretrig = X"01" then
               sSum	  := sSum + resize(signed(din),sSum'high+1) - resize(sMeanOut,sSum'high+1);
            else				
               sSum	  := sSum + resize(sPretrigOut,sSum'high+1) - resize(sMeanOut,sSum'high+1);
				end if;
			   if uMeanDepth = X"00" then
				   sMeani  <= resize(sPretrigOut,sMeani'high+1);
				else
               sMeani  <= SHIFT_RIGHT(sSum,pow2_bits_nb);
				end if;	
         end if;	 
      end if;
   end process;

   dout <= std_logic_vector(sMeani(BL_TOP downto 0)); 

end Behavioral;
