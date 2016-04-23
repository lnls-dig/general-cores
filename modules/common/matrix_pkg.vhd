library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package matrix_pkg is

    type matrix is array(natural range <>, natural range <>) of std_logic;

    -- assign row

    function mrst(slm : matrix) return matrix;

    -- assign row

    ---function mset(slm : matrix; slv : std_logic_vector; rowindex : natural) return matrix;

    procedure mset(signal slm : out matrix; slv : std_logic_vector; rowindex : natural);

    procedure mset_no_rng(signal slm : out matrix; slv : std_logic_vector; rowindex : natural);

    -- get std logic vector from matrix row

    function mget(slm : matrix; rowindex : natural) return std_logic_vector;

    -- flatten matrix to std logic vector

    function mflat(slm : matrix) return std_logic_vector;

    -- inflate std logic vector to matrix 
    function minfl(slm : matrix; slv : std_logic_vector ) return matrix;

    --  inflate std logic vector to m x n matrix

    function minflmn(slv : std_logic_vector; col_len : natural; row_len : natural) return matrix;

  end matrix_pkg;

  package body matrix_pkg is  



    function mrst(slm : matrix) return matrix is
      variable res : matrix(slm'length(1)-1 downto 0, slm'length(2)-1 downto 0);
      variable row, col : natural := 0;      
      constant row_len : natural := slm'length(2);
      constant col_len : natural := slm'length(1);
    begin
      for row in 0 to col_len-1 loop
        for col in 0 to row_len-1 loop
          res(row, col) := '0';
        end loop;
      end loop;
      return res;		
    end function;

  
    procedure mset(signal slm : out matrix; slv : std_logic_vector; rowindex : natural) is
      variable i : natural := 0;
    begin
      for i in slv'range loop
        slm(rowindex, i) <= slv(i);
      end loop;	
    end procedure;

    procedure mset_no_rng(signal slm : out matrix; slv : std_logic_vector; rowindex : natural) is
      variable i : natural := 0;
      variable j : natural := 0;
    begin
      j := 0;
      for i in slv'range loop
        slm(rowindex, j) <= slv(i);
        j := j+1;
      end loop;	
    end procedure;
    

    -- set matrix row
--     function mset(slm : matrix; slv : std_logic_vector; rowindex : natural) return matrix is
 --      variable i : natural := 0;
 --      variable res : matrix(slm'length(1)-1 downto 0, slm'length(2)-1 downto 0);
--     begin
 --      res := slm;
 --      for i in slv'range loop
 --        res(rowindex, i) := slv(i);
 --      end loop;
 --      return res;		
--     end function;

    
    -- get matrix row
    function mget(slm : matrix; rowindex : natural) return std_logic_vector is
      variable i : natural := 0;
      variable slv : std_logic_vector(slm'high(2) downto 0);
    begin
      for i in slv'range loop
        slv(i)  := slm(rowindex, i);
      end loop;
      return slv;
    end function;

    
    -- flatten matrix to std logic vector
    function mflat(slm : matrix) return std_logic_vector is
      constant row_len : natural := slm'length(2);
      constant col_len : natural := slm'length(1);
      variable res : std_logic_vector(col_len*row_len-1 downto 0);  
    begin
      for row in 0 to col_len-1 loop
        for col in 0 to row_len-1 loop
          res(row*row_len+col)  := slm(row, col);
        end loop;
      end loop;
      return res;
    end function;


    -- inflate std logic vector to matrix
    function minfl(slm : matrix; slv : std_logic_vector) return matrix is
      constant row_len : natural := slm'length(2);
      constant col_len : natural := slm'length(1);
      variable res : matrix(slm'length(1)-1 downto 0, slm'length(2)-1 downto 0);
    begin
      for row in 0 to col_len-1 loop
         for col in 0 to row_len-1 loop
              res(row, col)  := slv(row*row_len+col);
         end loop;
      end loop;
      return res;
    end function;
    

    -- -- inflate std logic vector to m*n matrix 
    function minflmn(slv : std_logic_vector; col_len : natural; row_len : natural) return matrix is
      variable res : matrix(col_len-1 downto 0, row_len-1 downto 0);
    begin
      for row in 0 to col_len-1 loop
         for col in 0 to row_len-1 loop
              res(row, col)  := slv(slv'length-1 - (row*row_len+col));
         end loop;
      end loop;
      return res;
    end function;

  end matrix_pkg;
