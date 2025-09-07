-------------------------------------------------------------------------------
-- Title      : tb_stack
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack.vhd
-- Author     : mrosiere
-- Company    : 
-- Created    : 2016-11-11
-- Last update: 2021-08-29
-- Platform   : 
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: 
-------------------------------------------------------------------------------
-- Copyright (c) 2016 
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2016-11-11  1.0      mrosiere	Created
-------------------------------------------------------------------------------

library std;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
--use ieee.numeric_bit.all;
--use ieee.std_logic_arith.all;

library asylum;
use asylum.stack_pkg.all;

entity tb_stack is

end tb_stack;

architecture tb of tb_stack is

  -- =====[ Constants ]===========================
  constant WIDTH     : natural := 8;
  constant DEPTH     : natural := 4;
  constant OVERWRITE : natural := 0;

  -- =====[ Signals ]=============================
  signal clk_i        : std_logic := '0';
  signal cke_i        : std_logic;
  signal arstn_i      : std_logic;
  signal push_val_i   : std_logic;
  signal push_ack_o   : std_logic;
  signal push_data_i  : std_logic_vector(WIDTH -1 downto 0);
  signal pop_val_o    : std_logic;
  signal pop_ack_i    : std_logic;
  signal pop_data_o   : std_logic_vector(WIDTH -1 downto 0);
  
  -------------------------------------------------------
  -- run
  -------------------------------------------------------
  procedure xrun
    (constant n     : in positive;           -- nb cycle
     signal   clk_i : in std_logic
     ) is
    
  begin
    for i in 0 to n-1
    loop
      wait until rising_edge(clk_i);        
    end loop;  -- i
  end xrun;

  procedure run
    (constant n     : in positive           -- nb cycle
     ) is
    
  begin
    xrun(n,clk_i);
  end run;

  -----------------------------------------------------
  -- Test signals
  -----------------------------------------------------
  signal test_done : std_logic := '0';
  signal test_ok   : std_logic := '0';
  
begin

  ------------------------------------------------
  -- Instance of DUT
  ------------------------------------------------
  dut : stack
    generic map
    (WIDTH     => WIDTH
    ,DEPTH     => DEPTH
    ,OVERWRITE => OVERWRITE
     )
    port map
    (clk_i       => clk_i  
    ,cke_i       => cke_i  
    ,arstn_i      => arstn_i 
    ,push_val_i  => push_val_i 
    ,push_ack_o  => push_ack_o 
    ,push_data_i => push_data_i
    ,pop_val_o   => pop_val_o  
    ,pop_ack_i   => pop_ack_i  
    ,pop_data_o  => pop_data_o 
     );

  ------------------------------------------------
  -- Clock process
  ------------------------------------------------
  clk_i <= not test_done and not clk_i after 5 ns;
  
  ------------------------------------------------
  -- Test process
  ------------------------------------------------
  -- purpose: Testbench process
  -- type   : combinational
  -- inputs : 
  -- outputs: All dut design with clk_i
  tb_gen: process is
  begin  -- process tb_gen
    report "[TESTBENCH] Test Begin";

    run(1);

    -- Reset
    report "[TESTBENCH] Reset";
    arstn_i    <= '0';
    cke_i      <= '1';
    push_val_i <= '0';
    pop_ack_i  <= '0';
    run(1);
    arstn_i    <= '1';
    run(1);

    assert pop_val_o ='0' report "Error : invalid pop_val" severity failure;
    assert push_ack_o='1' report "Error : invalid push_ack" severity failure;

    -- Write stack
    report "[TESTBENCH] Push in the stack";
    for i in 0 to DEPTH-1 loop
      push_val_i  <= '1';
      push_data_i <= not std_logic_vector(to_unsigned(i,push_data_i'length));
      run(1);
      push_val_i <= '0';

      if i=0
      then
      assert pop_val_o ='0' report "Error : invalid pop_val" severity failure;
      else
      assert pop_val_o ='1' report "Error : invalid pop_val" severity failure;
      end if;
      assert push_ack_o='1' report "Error : invalid push_ack" severity failure;

    end loop;  -- i

    -- Read stack
    report "[TESTBENCH] Pop in the stack";
    for i in DEPTH-1 downto 0 loop
      pop_ack_i  <= '1';
      run(1);
      assert pop_data_o = not std_logic_vector(to_unsigned(i,pop_data_o'length)) report "Error : Unexpected value for pop_data" severity failure;
      pop_ack_i <= '0';

      assert pop_val_o ='1' report "Error : invalid pop_val" severity failure;
      if i=DEPTH-1
      then
      assert push_ack_o='0' report "Error : invalid push_ack" severity failure;
      else
      assert push_ack_o='1' report "Error : invalid push_ack" severity failure;
      end if;
    end loop;  -- i

    -- Write and Read
    report "[TESTBENCH] Push/Pop in the stack";
    
    push_val_i  <= '1';
    push_data_i <= std_logic_vector(to_unsigned(0,push_data_i'length));
    run(1);
    
    for i in 1 to 4*DEPTH-1 loop
      push_val_i  <= '1';
      pop_ack_i   <= '1';
      push_data_i <= std_logic_vector(to_unsigned(i,push_data_i'length));
--      assert pop_data_o = std_logic_vector(to_unsigned(i-1,pop_data_o'length)) report "Error : Unexpected value for pop_data" severity failure;
      run(1);

      assert pop_val_o ='1' report "Error : invalid pop_val" severity failure;
      assert pop_data_o = std_logic_vector(to_unsigned(i-1,pop_data_o'length)) report "Error : Unexpected value for pop_data" severity failure;
      assert push_ack_o='1' report "Error : invalid push_ack" severity failure;

    end loop;  -- i

    push_val_i  <= '0';
    pop_ack_i  <= '1';
    run(1);

    assert pop_val_o = '1' report "Error : invalid pop_val" severity failure;
    assert pop_data_o = std_logic_vector(to_unsigned(4*DEPTH-1,pop_data_o'length)) report "Error : Unexpected value for pop_data" severity failure;
    
    pop_ack_i  <= '0';
    
    report "[TESTBENCH] Test End";

    test_ok   <= '1';

    run(1);
    test_done <= '1';
    run(1);
  end process tb_gen;

  gen_test_done: process (test_done) is
  begin  -- process gen_test_done
    if test_done'event and test_done = '1' then  -- rising clock edge
      if test_ok = '1' then
        report "[TESTBENCH] Test OK";
      else
        report "[TESTBENCH] Test KO" severity failure;
      end if;
      
    end if;
  end process gen_test_done;
  
end tb;
