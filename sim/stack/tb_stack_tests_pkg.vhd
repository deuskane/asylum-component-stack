-------------------------------------------------------------------------------
-- Title      : tb_stack_tests_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_tests_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenarios of tb_stack : names (valid items of TESTS_LIST),
--              applicability to the generics and dispatch (run_test) to the
--              package of each scenario (tb_stack_<name>_pkg)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.string_pkg.all;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_tests_pkg is

  -- Names of the scenarios (valid items of TESTS_LIST)
  constant C_TESTS : string := "reset_values,lifo,push_full,push_pop,cke,async_reset,random,cyclic,sync_reset";

  -- cyclic needs CYCLIC_PTR = true
  function test_applies
    (constant name     : in    string
    ;constant cfg      : in    cfg_t
    ) return boolean;

  -- Run the scenario name
  procedure run_test
    (constant name     : in    string
    ;constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_tests_pkg;

package body tb_stack_tests_pkg is

  function test_applies
    (constant name     : in    string
    ;constant cfg      : in    cfg_t
    ) return boolean is
  begin
    if string_eq(name, "cyclic")
    then
      return cfg.cyclic;
    end if;
    return true;
  end function;

  procedure run_test
    (constant name     : in    string
    ;constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    ) is
  begin
    if    string_eq(name, "reset_values")
    then
      work.tb_stack_reset_values_pkg.run(cfg, first, clk, din, dout);
    elsif string_eq(name, "lifo")
    then
      work.tb_stack_lifo_pkg.run(cfg, first, clk, din, dout);
    elsif string_eq(name, "push_full")
    then
      work.tb_stack_push_full_pkg.run(cfg, first, clk, din, dout);
    elsif string_eq(name, "push_pop")
    then
      work.tb_stack_push_pop_pkg.run(cfg, first, clk, din, dout);
    elsif string_eq(name, "cke")
    then
      work.tb_stack_cke_pkg.run(cfg, first, clk, din, dout);
    elsif string_eq(name, "async_reset")
    then
      work.tb_stack_async_reset_pkg.run(cfg, first, clk, din, dout);
    elsif string_eq(name, "random")
    then
      work.tb_stack_random_pkg.run(cfg, first, clk, din, dout);
    elsif string_eq(name, "cyclic")
    then
      work.tb_stack_cyclic_pkg.run(cfg, first, clk, din, dout);
    elsif string_eq(name, "sync_reset")
    then
      work.tb_stack_sync_reset_pkg.run(cfg, first, clk, din, dout);
    else
      alert(TB_ERROR, "Unknown test " & name, C_TB_SCOPE);
    end if;
  end procedure;

end package body tb_stack_tests_pkg;
