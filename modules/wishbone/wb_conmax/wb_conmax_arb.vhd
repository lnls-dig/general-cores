-------------------------------------------------------------------------------
-- Title      : Wishbone interconnect matrix for WR Core
-- Project    : WhiteRabbit
-------------------------------------------------------------------------------
-- File       : wb_conmax_arb.vhd
-- Author     : Grzegorz Daniluk
-- Company    : Elproma
-- Created    : 2011-02-12
-- Last update: 2011-02-16
-- Platform   : FPGA-generics
-- Standard   : VHDL
-------------------------------------------------------------------------------
-- Description:
-- Simple arbiter with round robin. It does not use any prioritization for 
-- WB Masters.
-- 
-------------------------------------------------------------------------------
-- Copyright (C) 2000-2002 Rudolf Usselmann
-- Copyright (c) 2011 Grzegorz Daniluk (VHDL port)
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author          Description
-- 2011-02-12  1.0      greg.d          Created
-------------------------------------------------------------------------------
-- TODO:
-- Code optimization. (now it is more like dummy translation from Verilog)
--
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity wb_conmax_arb is
  port(
    clk_i : in std_logic;
    rst_i : in std_logic;

    --req_i(n) <- wb_cyc from n-th Master
    req_i : in std_logic_vector(7 downto 0);
    next_i  : in std_logic;
    --which master (0 to 7) is granted
    gnt_o : out std_logic_vector(2 downto 0)
  );
end wb_conmax_arb;

architecture behaviour of wb_conmax_arb is
  type t_arb_states is (GRANT0, GRANT1, GRANT2, GRANT3, GRANT4, GRANT5, 
                        GRANT6, GRANT7);
  
  signal s_state  : t_arb_states;
begin

  --state transitions
  process(clk_i)
  begin
    if(clk_i'event and clk_i='1') then
      if(rst_i = '1') then
        s_state <= GRANT0;
      else

        case s_state is
          when GRANT0 =>
            --if this req is dropped or next is asserted, check for other req's
            if(req_i(0)='0' or next_i='1') then
              if   ( req_i(1)='1' ) then
                s_state <= GRANT1;
              elsif( req_i(2)='1' ) then
                s_state <= GRANT2;
              elsif( req_i(3)='1' ) then
                s_state <= GRANT3;
              elsif( req_i(4)='1' ) then
                s_state <= GRANT4;
              elsif( req_i(5)='1' ) then
                s_state <= GRANT5;
              elsif( req_i(6)='1' ) then
                s_state <= GRANT6;
              elsif( req_i(7)='1' ) then
                s_state <= GRANT7;
              end if;
            end if;

          when GRANT1 =>
            if(req_i(1)='0' or next_i='1') then
              if   ( req_i(2)='1' ) then
                s_state <= GRANT2;
              elsif( req_i(3)='1' ) then
                s_state <= GRANT3;
              elsif( req_i(4)='1' ) then
                s_state <= GRANT4;
              elsif( req_i(5)='1' ) then
                s_state <= GRANT5;
              elsif( req_i(6)='1' ) then
                s_state <= GRANT6;
              elsif( req_i(7)='1' ) then
                s_state <= GRANT7;
              elsif( req_i(0)='1' ) then
                s_state <= GRANT0;
              end if;
            end if;

          when GRANT2 =>
            if(req_i(2)='0' or next_i='1') then
              if   ( req_i(3)='1' ) then
                s_state <= GRANT3;
              elsif( req_i(4)='1' ) then
                s_state <= GRANT4;
              elsif( req_i(5)='1' ) then
                s_state <= GRANT5;
              elsif( req_i(6)='1' ) then
                s_state <= GRANT6;
              elsif( req_i(7)='1' ) then
                s_state <= GRANT7;
              elsif( req_i(0)='1' ) then
                s_state <= GRANT0;
              elsif( req_i(1)='1' ) then
                s_state <= GRANT1;
              end if;
            end if;

          when GRANT3 =>
            if(req_i(3)='0' or next_i='1') then
              if   ( req_i(4)='1' ) then
                s_state <= GRANT4;
              elsif( req_i(5)='1' ) then
                s_state <= GRANT5;
              elsif( req_i(6)='1' ) then
                s_state <= GRANT6;
              elsif( req_i(7)='1' ) then
                s_state <= GRANT7;
              elsif( req_i(0)='1' ) then
                s_state <= GRANT0;
              elsif( req_i(1)='1' ) then
                s_state <= GRANT1;
              elsif( req_i(2)='1' ) then
                s_state <= GRANT2;
              end if;
            end if;

          when GRANT4 =>
            if(req_i(4)='0' or next_i='1') then
              if   ( req_i(5)='1' ) then
                s_state <= GRANT5;
              elsif( req_i(6)='1' ) then
                s_state <= GRANT6;
              elsif( req_i(7)='1' ) then
                s_state <= GRANT7;
              elsif( req_i(0)='1' ) then
                s_state <= GRANT0;
              elsif( req_i(1)='1' ) then
                s_state <= GRANT1;
              elsif( req_i(2)='1' ) then
                s_state <= GRANT2;
              elsif( req_i(3)='1' ) then
                s_state <= GRANT3;
              end if;
            end if;

          when GRANT5 =>
            if(req_i(5)='0' or next_i='1') then
              if   ( req_i(6)='1' ) then
                s_state <= GRANT6;
              elsif( req_i(7)='1' ) then
                s_state <= GRANT7;
              elsif( req_i(0)='1' ) then
                s_state <= GRANT0;
              elsif( req_i(1)='1' ) then
                s_state <= GRANT1;
              elsif( req_i(2)='1' ) then
                s_state <= GRANT2;
              elsif( req_i(3)='1' ) then
                s_state <= GRANT3;
              elsif( req_i(4)='1' ) then
                s_state <= GRANT4;
              end if;
            end if;

          when GRANT6 =>
            if(req_i(6)='0' or next_i='1') then
              if   ( req_i(7)='1' ) then
                s_state <= GRANT7;
              elsif( req_i(0)='1' ) then
                s_state <= GRANT0;
              elsif( req_i(1)='1' ) then
                s_state <= GRANT1;
              elsif( req_i(2)='1' ) then
                s_state <= GRANT2;
              elsif( req_i(3)='1' ) then
                s_state <= GRANT3;
              elsif( req_i(4)='1' ) then
                s_state <= GRANT4;
              elsif( req_i(5)='1' ) then
                s_state <= GRANT5;
              end if;
            end if;

          when GRANT7 =>
            if(req_i(7)='0' or next_i='1') then
              if   ( req_i(0)='1' ) then
                s_state <= GRANT0;
              elsif( req_i(1)='1' ) then
                s_state <= GRANT1;
              elsif( req_i(2)='1' ) then
                s_state <= GRANT2;
              elsif( req_i(3)='1' ) then
                s_state <= GRANT3;
              elsif( req_i(4)='1' ) then
                s_state <= GRANT4;
              elsif( req_i(5)='1' ) then
                s_state <= GRANT5;
              elsif( req_i(6)='1' ) then
                s_state <= GRANT6;
              end if;
            end if;

          when others =>
            s_state <= GRANT0;
        end case;

      end if;
    end if;
  end process;

  process(s_state)
  begin
    case(s_state) is
      when GRANT0 =>  gnt_o <= "000";
      when GRANT1 =>  gnt_o <= "001";
      when GRANT2 =>  gnt_o <= "010";
      when GRANT3 =>  gnt_o <= "011";
      when GRANT4 =>  gnt_o <= "100";
      when GRANT5 =>  gnt_o <= "101";
      when GRANT6 =>  gnt_o <= "110";
      when GRANT7 =>  gnt_o <= "111";
      when others =>  gnt_o <= "000";
    end case;
  end process;

end behaviour;
