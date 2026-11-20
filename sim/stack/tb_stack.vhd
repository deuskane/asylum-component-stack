-------------------------------------------------------------------------------
-- Title      : tb_stack
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Self-checking UVVM testbench of the stack. The DUT handshakes
--              are driven cycle by cycle and compared against a reference
--              model of the stack content (tb_stack_bfm_pkg).
--              TESTS_LIST : scenarios run in sequence, separated by ','
--                           (tb_stack_tests_pkg), each one after a reset
--                           pulse ; "" : build and elaboration only
--              WIDTH, DEPTH, OVERWRITE, CYCLIC_PTR : generics of the DUT
-------------------------------------------------------------------------------
-- Copyright (c) 2016
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2016-11-11  1.0      mrosiere Created
-- 2026-10-05  2.0      mrosiere Convert to UVVM, add WIDTH/DEPTH/OVERWRITE
--                               generics, OVERWRITE, cke_i, reset and random
--                               tests
-- 2026-11-16  2.1      mrosiere Test 9 : synchronous reset srst_i
-- 2026-11-20  3.0      mrosiere TESTS_LIST, one package per scenario
--                               (tb_stack_<name>_pkg), helpers and model in
--                               tb_stack_bfm_pkg, reset pulse before each
--                               scenario
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.string_pkg.all;
use     asylum.stack_pkg.all;

library work;
use     work.tb_stack_bfm_pkg.all;
use     work.tb_stack_tests_pkg.all;

entity tb_stack is
  generic (
    TESTS_LIST : string  := ""     -- Scenarios, e.g. "lifo,push_full"
   ;WIDTH      : natural := 8
   ;DEPTH      : natural := 8      -- Power of 2
   ;OVERWRITE  : natural := 0
   ;CYCLIC_PTR : boolean := false  -- Needs OVERWRITE /= 0
  );
end entity tb_stack;

architecture sim of tb_stack is

  constant C_SCOPE : string := "TB_STACK";
  constant C_CFG   : cfg_t  := (width     => WIDTH
                               ,depth     => DEPTH
                               ,overwrite => OVERWRITE /= 0
                               ,cyclic    => CYCLIC_PTR
                               );

  signal   clk_i   : std_logic := '0';
  signal   clk_ena : boolean   := true;
  signal   din     : stack_in_t (push_data(WIDTH-1 downto 0))
                             := (cke       => '1'
                                ,arstn     => '0'
                                ,srst      => '0'
                                ,push_val  => '0'
                                ,push_data => (WIDTH-1 downto 0 => '0')
                                ,pop_ack   => '0'
                                );
  signal   dout    : stack_out_t(pop_data (WIDTH-1 downto 0));

begin

  clock_generator(clk_i, clk_ena, C_CLK_PERIOD, "TB Clock");

  -----------------------------------------------------------------------------
  -- DUT
  -----------------------------------------------------------------------------
  dut : stack
    generic map
    (WIDTH       => WIDTH
    ,DEPTH       => DEPTH
    ,OVERWRITE   => OVERWRITE
    ,CYCLIC_PTR  => CYCLIC_PTR
    )
    port map
    (clk_i       => clk_i
    ,cke_i       => din.cke
    ,arstn_i     => din.arstn
    ,srst_i      => din.srst
    ,push_val_i  => din.push_val
    ,push_ack_o  => dout.push_ack
    ,push_data_i => din.push_data
    ,pop_val_o   => dout.pop_val
    ,pop_ack_i   => din.pop_ack
    ,pop_data_o  => dout.pop_data
    );

  -----------------------------------------------------------------------------
  -- Sequencer
  -----------------------------------------------------------------------------
  p_sequencer : process
  begin
    log(ID_LOG_HDR, "WIDTH = " & to_string(WIDTH) & ", DEPTH = " & to_string(DEPTH) & ", OVERWRITE = " & to_string(OVERWRITE) & ", CYCLIC_PTR = " & to_string(CYCLIC_PTR) & ", TESTS_LIST : " & TESTS_LIST, C_SCOPE);

    -- Every name is checked before the first scenario
    for i in 1 to list_length(TESTS_LIST) loop
      if not list_contains(C_TESTS, list_item(TESTS_LIST, i))
      then
        alert(TB_ERROR, "Unknown test """ & list_item(TESTS_LIST, i) & """ (tests : " & C_TESTS & ")", C_SCOPE);
      elsif not test_applies(list_item(TESTS_LIST, i), C_CFG)
      then
        alert(TB_ERROR, "Test """ & list_item(TESTS_LIST, i) & """ does not apply to the generics (cyclic : CYCLIC_PTR = true)", C_SCOPE);
      end if;
    end loop;

    for i in 1 to list_length(TESTS_LIST) loop
      -- Reset pulse, inputs idle : each scenario starts from reset
      do_reset(clk_i, din);

      log(ID_LOG_HDR, "TEST " & integer'image(i) & "/" & integer'image(list_length(TESTS_LIST)) & " : " & list_item(TESTS_LIST, i), C_SCOPE);
      -- The RAM is not reset : each scenario pushes other words than the
      -- previous one, a missing write can not read back an equal stale word
      run_test(list_item(TESTS_LIST, i), C_CFG, 1 + 1000*(i-1), clk_i, din, dout);
    end loop;

    report_alert_counters(FINAL);
    clk_ena <= false;
    std.env.stop;
    wait;
  end process p_sequencer;

end architecture sim;
