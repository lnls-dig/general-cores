--! @file dec_8b10b.vhd

--! Standard library
library ieee;

--! Standard packages    
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- --
-- GSI Darmstadt, Dept. BEL: 8b10b Decoder--
-- --
-------------------------------------------------------------------------------
--
-- unit name: dec_8b10b 
--
--! @brief 8b/10b Decoder \n
--!     This module provides 10bit-to-8bit decoding. \n
--!     It accepts 10-bit encoded data input and generates 8-bit parallel data \n
--!     output in accordance with the 8b/10b standard. IO latency is 2 clock cycles.  \n
--
--! @author     Vladimir Cherkashyn\n
--! v.cherkashyn@gsi.de
--
--! @date 11.05.2009
--
--! @version             1.0
--
--! @details This approach uses a mix of LUTs and stacked ifs, unlike the suggested \n
--! approach that only used gates. This uses more logic cells, but also runs about \n
--! twice as fast (420 opposed to 240MHz). \n
--! The reverse vector function is used because all code tables are provided in \n
--! literature as LSB first. This way, the sourcecode is easier to compare.


--! 99 LUTs in Cyclone3
--!
--! <b>Dependencies:</b>\n
--! -
--!
--! <b>References:</b>\n
--! -
--!
--! <b>Modified by:</b>\n
--! Author: Vladimir Cherkashyn\n
--! v.cherkashyn@gsi.de
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 11.05.2009 initial code\n
-------------------------------------------------------------------------------
--! @todo Test 
--
-------------------------------------------------------------------------------

--=======================================================================================
--///////////////////////////////////////////////////////////////////////////////////////
--! Entity declaration for dec_8b10b
--=======================================================================================
entity gc_dec_8b10b is
  port (

    clk_i   : in std_logic;             --! byte clock, trigger on rising edge
    rst_n_i : in std_logic;             --! reset, assert HI   

    in_10b_i : in std_logic_vector(9 downto 0);  --! 10bit input to be decoded

    ctrl_o      : out std_logic;        --! control char, assert HI
    code_err_o  : out std_logic;  --! HI if invalid 10bit group has been recieved
    rdisp_err_o : out std_logic;  --! HI if running disparity error has occured

    out_8b_o : out std_logic_vector(7 downto 0)  --! 8bit data output

    );
end gc_dec_8b10b;

--=======================================================================================
--///////////////////////////////////////////////////////////////////////////////////////
--! Architecture Declaration rtl of dec_8b10b  - 8b10b decoding
--=======================================================================================
architecture rtl of gc_dec_8b10b is

-- LUT and CTRL components

  component dec_8b10b_lut is
    port (
      in_10b_i : in  std_logic_vector(9 downto 0);
      out_8b_o : out std_logic_vector(7 downto 0)
      );
  end component;

  component dec_8b10b_ctrl is
    port (
      in_10b_i   : in  std_logic_vector(9 downto 0);  --! 10bit input to be decoded
      ctrl_o     : out std_logic;       --! control char, assert HI
      code_err_o : out std_logic  --! HI if invalid 10bit group has been recieved 
      );
  end component;

  component dec_8b10b_disp is
    port(

      clk_i       : in  std_logic;      --! byte clock, trigger on rising edge
      rst_n_i     : in  std_logic;      --! reset, assert HI   
      in_10b_i    : in  std_logic_vector(9 downto 0);  --! 10bit input to be decoded
      disp_err_o  : out std_logic;  --! HI if running disparity error has occured
      rdisp_err_o : out std_logic  --! HI if running disparity error has occured
      );
  end component;

--=======================================================================================
-- FUNCTIONS                        
--=======================================================================================

--! function f_reverse_vector - bit reversal
  function f_reverse_vector (a : in std_logic_vector)
    return std_logic_vector is
    variable v_result : std_logic_vector(a'reverse_range);
  begin
    for i in a'range loop
      v_result(i) := a(i);
    end loop;
    return v_result;
  end;  -- function f_reverse_vector

--=======================================================================================
-- INTERNAL SIGNALS                         
--=======================================================================================

-- input clocked buffer
  signal s_in10b         : std_logic_vector(9 downto 0);
-- output clocked buffers
  signal s_out8b         : std_logic_vector(7 downto 0);
  signal s_ctrl          : std_logic;
  signal s_code_err      : std_logic;
  signal s_disp_err      : std_logic;
-- LUT & CTRL wires
  signal s_out8b_lut     : std_logic_vector(7 downto 0);
  signal s_ctrl_ctrl     : std_logic;
  signal s_code_err_ctrl : std_logic;
  signal s_code_err_disp : std_logic;
  signal s_rdisp_err     : std_logic;


begin

-- LUT and CTRL instances
  
  LUT : dec_8b10b_lut
    port map (
      in_10b_i => s_in10b,
      out_8b_o => s_out8b_lut
      );

  CTRL : dec_8b10b_ctrl
    port map (
      in_10b_i   => s_in10b,
      ctrl_o     => s_ctrl_ctrl,
      code_err_o => s_code_err_ctrl
      );

  DISP : dec_8b10b_disp
    port map (
      clk_i       => clk_i,
      rst_n_i     => rst_n_i,
      in_10b_i    => s_in10b,
      disp_err_o  => s_code_err_disp,
      rdisp_err_o => s_rdisp_err
      );

--=======================================================================================
-- CONCURRENT COMMANDS                         
--======================================================================================= 
-- Wires from buffers to module I/O
  out_8b_o    <= s_out8b;
  ctrl_o      <= s_ctrl;
  code_err_o  <= s_code_err;
  rdisp_err_o <= s_disp_err;

--============================================================================
-- Begin of p_decoding
--! Process decodes 10bit codeword to 8 bit value using LUT
--============================================================================
  p_decoding : process (clk_i, rst_n_i)
  begin
    if rising_edge(clk_i) then
      --==========================================================================
      -- SYNC RESET                         
      --========================================================================== 
      if (rst_n_i = '0') then
        -- reset buffer triggers   
        s_in10b    <= B"111010_1000";   -- reset input buffer
        s_out8b    <= B"111_10111";     -- reset output buffer
        s_ctrl     <= '1';              -- reset control output buffer
        s_code_err <= '0';              -- reset code error output buffer
        s_disp_err <= '0';              -- reset disparity error output buffer
      else
        -- save input in clocked buffer in the inverse bit order
        s_in10b    <= f_reverse_vector(in_10b_i);
        -- lut unit output to clocked buffers
        s_out8b    <= s_out8b_lut;
        -- control and error signals from ctrl unit to clocked buffers
        s_ctrl     <= s_ctrl_ctrl;
        s_code_err <= s_code_err_ctrl or s_code_err_disp;
        s_disp_err <= s_rdisp_err;
      end if;
    end if;
  end process;

end rtl;

--! Standard library
library ieee;

--! Standard packages    
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--! @brief CTRL module for 10b/8b Decoder \n
--!     This module sets command code flag if the 10 bit recieved code was a \n
--! command character. It also checks for invalid code violations. \n
--!     It accepts 10-bit encoded data input. Combinational logic only.  \n

--=======================================================================================
--///////////////////////////////////////////////////////////////////////////////////////
--! Entity declaration for dec_8b10b_ctrl
--=======================================================================================
entity dec_8b10b_ctrl is port
                           (
                             in_10b_i   : in  std_logic_vector(9 downto 0);  --! 10bit input to be decoded
                             ctrl_o     : out std_logic;  --! control char, assert HI
                             code_err_o : out std_logic  --! HI if invalid 10bit group has been recieved 
                             );
end dec_8b10b_ctrl;

architecture rtl of dec_8b10b_ctrl is

--=======================================================================================
-- INTERNAL SIGNALS AND ALIASES                         
--=======================================================================================

  alias a_abcd   : std_logic_vector(3 downto 0) is in_10b_i(9 downto 6);
  alias a_ei     : std_logic_vector(1 downto 0) is in_10b_i(5 downto 4);
  alias a_fghj   : std_logic_vector(3 downto 0) is in_10b_i(3 downto 0);
  alias a_fgh    : std_logic_vector(2 downto 0) is in_10b_i(3 downto 1);
  alias a_fg     : std_logic_vector(1 downto 0) is in_10b_i(3 downto 2);
  alias a_cde    : std_logic_vector(2 downto 0) is in_10b_i(7 downto 5);
  alias a_cdei   : std_logic_vector(3 downto 0) is in_10b_i(7 downto 4);
  alias a_dei    : std_logic_vector(2 downto 0) is in_10b_i(6 downto 4);
  alias a_eifgh  : std_logic_vector(4 downto 0) is in_10b_i(5 downto 1);
  alias a_eifghj : std_logic_vector(5 downto 0) is in_10b_i(5 downto 0);

  alias a_in6b : std_logic_vector(5 downto 0) is in_10b_i(9 downto 4);
  alias a_in4b : std_logic_vector(3 downto 0) is in_10b_i(3 downto 0);

  signal s_eighj : std_logic_vector(4 downto 0);

  signal s_p13, s_p31 : std_logic;

  signal s_err1, s_err2, s_err3, s_err4, s_err5, s_err6 : std_logic;
  signal s_err7a, s_err7b, s_err8, s_err9, s_err10      : std_logic;
  signal s_err11, s_err12, s_err13, s_err14             : std_logic;

  signal s_ctrl_1, s_ctrl_2, s_ctrl_3 : std_logic;

begin

--=======================================================================================
-- CONCURRENT COMMANDS                         
--=======================================================================================

  s_eighj <= in_10b_i(5 downto 4) & in_10b_i(2 downto 0);

-- invalid code checking

  s_err1  <= '1' when ((a_abcd = "0000") or (a_abcd = "1111"))                        else '0';
  s_err2  <= '1' when ((a_ei = "00") and (s_p13 = '1'))                               else '0';
  s_err3  <= '1' when ((a_ei = "11") and (s_p31 = '1'))                               else '0';
  s_err4  <= '1' when ((a_fghj = "0000") or (a_fghj = "1111"))                        else '0';
  s_err5  <= '1' when ((a_eifgh = "00000") or (a_eifgh = "11111"))                    else '0';
  s_err6  <= '1' when ((s_eighj = "10111") or (s_eighj = "01000"))                    else '0';
  s_err7a <= '1' when ((s_eighj = "00111") and (a_cde /= "000") and (a_cde /= "111")) else '0';
  s_err7b <= '1' when ((s_eighj = "11000") and (a_cde /= "000") and (a_cde /= "111")) else '0';
  s_err8  <= '1' when ((s_eighj = "10000") and (s_p31 = '0'))                         else '0';
  s_err9  <= '1' when ((s_eighj = "01111") and (s_p13 = '0'))                         else '0';
  s_err10 <= '1' when ((in_10b_i = "0011110001") or (in_10b_i = "1100001110"))        else '0';
  s_err11 <= '1' when ((a_cdei = "0000") and (a_fg = "00"))                           else '0';
  s_err12 <= '1' when ((a_cdei = "1111") and (a_fg = "11"))                           else '0';
  s_err13 <= '1' when ((a_dei = "000") and (a_fgh = "000"))                           else '0';
  s_err14 <= '1' when ((a_dei = "111") and (a_fgh = "111"))                           else '0';

  code_err_o <= s_err1 or s_err2 or s_err3 or s_err4 or s_err5 or
                s_err6 or s_err7a or s_err7b or s_err8 or s_err9 or s_err10 or
                s_err11 or s_err12 or s_err13 or s_err14;

-- command code checking

  -- K28.x
  s_ctrl_1 <= '1' when ((a_cdei = "0000") or (a_cdei = "1111"))
              else '0';
  -- K23,27,29,30, positive disparity                       
  s_ctrl_2 <= '1' when ((a_eifghj = "010111") and (s_p13 = '1'))
              else '0';
-- K23,27,29,30, negative disparity                     
  s_ctrl_3 <= '1' when ((a_eifghj = "101000") and (s_p31 = '1'))
              else '0';
  
  ctrl_o <= s_ctrl_1 or s_ctrl_2 or s_ctrl_3;


  p_p13_p31_func : process(a_abcd)
  begin

    s_p13 <= '0';
    s_p31 <= '0';

    case a_abcd is
      when "0001" | "0010" | "0100" | "1000" =>
        s_p13 <= '1';
        s_p31 <= '0';
      when "1110" | "1101" | "1011" | "0111" =>
        s_p13 <= '0';
        s_p31 <= '1';
      when others => s_p13 <= '0';
                     s_p31 <= '0';
    end case;
    
  end process;


end rtl;  --! @file dec_8b10b_disp.vhd

--! Standard library
library ieee;

--! Standard packages    
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-------------------------------------------------------------------------------
-- --
-- GSI Darmstadt, Dept. BEL: 8b10b Decoder--
-- --
-------------------------------------------------------------------------------
--
-- unit name: dec_8b10b_disp 
--
--! @brief 8b/10b Decoder \n
--!     This module provides 10bit-to-8bit decoding. \n
--!     It accepts 10-bit encoded data input and generates 8-bit parallel data \n
--!     output in accordance with the 8b/10b standard. IO latency is 2 clock cycles.  \n
--
--! @author     Vladimir Cherkashyn\n
--! v.cherkashyn@gsi.de
--
--! @date 11.05.2009
--
--! @version             1.0
--
--! @details This approach uses a mix of LUTs and stacked ifs, unlike the suggested \n
--! approach that only used gates. This uses more logic cells, but also runs about \n
--! twice as fast (420 opposed to 240MHz). \n
--! The reverse vector function is used because all code tables are provided in \n
--! literature as LSB first. This way, the sourcecode is easier to compare.
--!
--! <b>Dependencies:</b>\n
--! -
--!
--! <b>References:</b>\n
--! -
--!
--! <b>Modified by:</b>\n
--! Author: Vladimir Cherkashyn\n
--! v.cherkashyn@gsi.de
-------------------------------------------------------------------------------
--! \n\n<b>Last changes:</b>\n
--! 11.05.2009 initial code\n
-------------------------------------------------------------------------------
--! @todo Test 
--
-------------------------------------------------------------------------------

--=======================================================================================
--///////////////////////////////////////////////////////////////////////////////////////
--! Entity declaration for dec_8b10b_disp
--=======================================================================================
entity dec_8b10b_disp is
  port (

    clk_i       : in  std_logic;        --! byte clock, trigger on rising edge
    rst_n_i     : in  std_logic;        --! reset, assert HI   
    in_10b_i    : in  std_logic_vector(9 downto 0);  --! 10bit input to be decoded
    disp_err_o  : out std_logic;        --! HI if 10bit code disparity violated
    rdisp_err_o : out std_logic   --! HI if running disparity error has occured
    );
end dec_8b10b_disp;

--=======================================================================================
--///////////////////////////////////////////////////////////////////////////////////////
--! Architecture Declaration rtl of dec_8b10b_disp  - 8b10b_disp decoding
--=======================================================================================
architecture rtl of dec_8b10b_disp is

--=======================================================================================
-- FUNCTIONS                        
--=======================================================================================
--! function f_cnt4bit - counts ones in a bit vector
  function f_cnt4bit (vec : in std_logic_vector)
    return std_logic_vector is
    variable v_cnt : std_logic_vector(3 downto 0) := "0000";
  begin
    for i in vec'range loop
      if (vec(i) = '1') then
        v_cnt := std_logic_vector(unsigned(v_cnt) + 1);
      end if;
    end loop;
    return v_cnt;
  end;  -- function f_cnt4bit

--=======================================================================================
-- INTERNAL SIGNALS                         
--=======================================================================================
  type t_state_type is (RD_MINUS, RD_PLUS);

  signal s_RunDisp : t_state_type;

  signal s_disp : std_logic_vector(3 downto 0);

  signal s_disp_err1, s_disp_err2 : std_logic;
--signal s_disp_err3 : std_logic;

  alias a_in6b : std_logic_vector(5 downto 0) is in_10b_i(9 downto 4);
  alias a_in4b : std_logic_vector(3 downto 0) is in_10b_i(3 downto 0);

begin

  s_disp <= f_cnt4bit(in_10b_i);

-- disparity of 10bit input    
--s_disp_err3 <= '0' when ( (s_disp = "0100") or 
--                          (s_disp = "0110") or 
--                          (s_disp = "0101") )
--                   else '1';

-- disparity of 4bit part (2,0,-2)                  
  s_disp_err2 <= '1' when ((a_in4b = "0000") or
                           (a_in4b = "1111"))
                 else '0';

  disp_err_o <= s_disp_err1 or s_disp_err2;  -- or s_disp_err3;

-- disparity of 6bit part (2,0,-2)
  p_6bit_disp_err : process(a_in6b)
  begin

    s_disp_err1 <= '0';

    case a_in6b is
      when "000001" | "000010" | "000100" | "001000" | "010000" | "100000" =>
        s_disp_err1 <= '1';
      when "011111" | "101111" | "110111" | "111011" | "111101" | "111110" =>
        s_disp_err1 <= '1';
      when "111111" | "000000" =>
        s_disp_err1 <= '1';
      when others =>
        s_disp_err1 <= '0';
        
    end case;
    
  end process;

  p_state_out : process (s_RunDisp, s_disp)
  begin
    rdisp_err_o <= '1';

    case s_RunDisp is
      when RD_MINUS =>
        if (s_disp = "0110") or (s_disp = "0101") then
          rdisp_err_o <= '0';
        end if;
      when RD_PLUS =>
        if (s_disp = "0100") or (s_disp = "0101") then
          rdisp_err_o <= '0';
        end if;
      when others => null;

    end case;
  end process;

--============================================================================
-- Begin of p_state_disp
--! 
--============================================================================
  p_state_disp : process (clk_i, rst_n_i)
  begin
    if rising_edge(clk_i) then
      --==========================================================================
      -- SYNC RESET                         
      --========================================================================== 
      if (rst_n_i = '0') then
        s_RunDisp <= RD_PLUS;
      else

        case s_RunDisp is
          when RD_MINUS =>
            if (s_disp = "0110") then
              s_RunDisp <= RD_PLUS;
            end if;
          when RD_PLUS =>
            if (s_disp = "0100") then
              s_RunDisp <= RD_MINUS;
            end if;
          when others =>
            s_RunDisp <= RD_MINUS;
        end case;
        
      end if;
    end if;
  end process;

end rtl;

--! @brief LUT module for 10b/8b Decoder \n
--!     This module provides 10bit-to-8bit decoding tables. \n
--!     It accepts 10-bit encoded data input and generates 8-bit parallel data \n
--!     output in accordance with the 8b/10b standard. Combinational logic only.  \n
--

--! Standard library
library ieee;

--! Standard packages    
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


--=======================================================================================
--///////////////////////////////////////////////////////////////////////////////////////
--! Entity declaration for dec_8b10b_lut
--=======================================================================================
entity dec_8b10b_lut is port
                          (
                            in_10b_i : in  std_logic_vector(9 downto 0);  --! 10bit input to be decoded
                            out_8b_o : out std_logic_vector(7 downto 0)  --! 8bit data output
                            );
end dec_8b10b_lut;

architecture rtl of dec_8b10b_lut is

--=======================================================================================
-- INTERNAL SIGNALS                         
--=======================================================================================

-- aliases to input vector
  alias a_in6b : std_logic_vector(5 downto 0) is in_10b_i(9 downto 4);
  alias a_in4b : std_logic_vector(3 downto 0) is in_10b_i(3 downto 0);

-- aliases to output vector
  alias a_out5b : std_logic_vector(4 downto 0) is out_8b_o(4 downto 0);
  alias a_out3b : std_logic_vector(2 downto 0) is out_8b_o(7 downto 5);

begin

  dec_4b_lut : process(a_in4b, a_in6b)

  begin

    -- 4 bits of data code (MSB)
    B4 : case a_in4b is
      when "1011" | "0100" => a_out3b <= "000";  -- Dx.0

      when "1001" =>
        if (a_in6b = "110000") then
          a_out3b <= "110";             -- D28.6
        else
          a_out3b <= "001";             -- Dx.1
        end if;
        
      when "0101" =>
        if (a_in6b = "110000") then
          a_out3b <= "101";             -- K28.5
        else
          a_out3b <= "010";             -- Dx.2
        end if;

      when "1100" | "0011" => a_out3b <= "011";  -- Dx.3
      when "1101" | "0010" => a_out3b <= "100";  -- Dx.4

      when "1010" =>
        if (a_in6b = "110000") then
          a_out3b <= "010";             -- K28.2
        else
          a_out3b <= "101";             -- Dx.5
        end if;
      when "0110" =>
        if (a_in6b = "110000") then
          a_out3b <= "001";             -- K28.1
        else
          a_out3b <= "110";             -- Dx.6
        end if;

      when "1110" | "0001" => a_out3b <= "111";  -- Dx.7

      when "1000" | "0111" => a_out3b <= "111";  -- Kx.7

      when others => a_out3b <= (others => '0');

    end case B4;
    
  end process;

  dec_6b_lut : process(a_in6b)

  begin

    -- 6 bits of data code (LSB)
    B6 : case a_in6b is
      when "100111" | "011000" => a_out5b <= "00000";  -- D0.x
      when "011101" | "100010" => a_out5b <= "00001";
      when "101101" | "010010" => a_out5b <= "00010";

      when "110001" => a_out5b <= "00011";

      when "110101" | "001010" => a_out5b <= "00100";

      when "101001" => a_out5b <= "00101";
      when "011001" => a_out5b <= "00110";

      when "111000" | "000111" => a_out5b <= "00111";
      when "111001" | "000110" => a_out5b <= "01000";

      when "100101" => a_out5b <= "01001";
      when "010101" => a_out5b <= "01010";
      when "110100" => a_out5b <= "01011";
      when "001101" => a_out5b <= "01100";
      when "101100" => a_out5b <= "01101";
      when "011100" => a_out5b <= "01110";

      when "010111" | "101000" => a_out5b <= "01111";
      when "011011" | "100100" => a_out5b <= "10000";

      when "100011" => a_out5b <= "10001";
      when "010011" => a_out5b <= "10010";
      when "110010" => a_out5b <= "10011";
      when "001011" => a_out5b <= "10100";
      when "101010" => a_out5b <= "10101";
      when "011010" => a_out5b <= "10110";

      when "111010" | "000101" => a_out5b <= "10111";
      when "110011" | "001100" => a_out5b <= "11000";

      when "100110" => a_out5b <= "11001";
      when "010110" => a_out5b <= "11010";

      when "110110" | "001001" => a_out5b <= "11011";

      when "001110" => a_out5b <= "11100";

      when "101110" | "010001" => a_out5b <= "11101";
      when "011110" | "100001" => a_out5b <= "11110";
      when "101011" | "010100" => a_out5b <= "11111";  -- D31.x

      when "001111" | "110000" => a_out5b <= "11100";  -- K28.x

      when others => a_out5b <= (others => '0');

    end case B6;

  end process;

end rtl;
