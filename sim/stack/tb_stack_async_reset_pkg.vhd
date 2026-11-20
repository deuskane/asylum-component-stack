-------------------------------------------------------------------------------
-- Title      : tb_stack_async_reset_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_async_reset_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario async_reset of tb_stack, from reset :
--              Asynchronous reset arstn_i on a full stack : the stack is empty
--              (and accepts a push) before the next clock edge and after it ;
--              also with cke_i = 0 and a push+pop request ; the stack is
--              usable after the reset
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 6 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_async_reset_pkg is

  -- Asynchronous reset arstn_i on a full stack : the stack is empty (and
  -- accepts a push) before the next clock edge and after it ; also with
  -- cke_i = 0 and a push+pop request ; the stack is usable after the reset
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_async_reset_pkg;

package body tb_stack_async_reset_pkg is

  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    ) is
    variable m         : model_t(stk(0 to cfg.depth-1)(cfg.width-1 downto 0));
  begin
    init(m, first);
    for i in 1 to cfg.depth loop
      cycle(true, false, "fill", cfg, m, clk, din, dout);
    end loop;
    -- arstn_i = 0 driven on the falling edge : stack empty before the rising edge
    wait until falling_edge(clk);
    din.arstn <= '0';
    wait for C_CLK_PERIOD/4;
    m.nb := 0;
    check_value(dout.pop_val , '0', ERROR, "reset is asynchronous : stack empty before the clock edge", C_TB_SCOPE);
    check_value(dout.push_ack, '1', ERROR, "reset is asynchronous : push_ack_o before the clock edge", C_TB_SCOPE);
    wait until rising_edge(clk);
    wait for C_CLK_PERIOD/4;
    check_value(dout.pop_val , '0', ERROR, "stack empty after the clock edge with arstn_i = 0", C_TB_SCOPE);
    check_value(dout.push_ack, '1', ERROR, "push_ack_o after reset", C_TB_SCOPE);
    idle(clk, din);
    -- Reset while cke_i = 0 (the reset does not depend on cke_i), push+pop requested
    for i in 1 to 3 loop
      cycle(true, false, "refill", cfg, m, clk, din, dout);
    end loop;
    cycle(true , true , "reset with cke_i = 0 and push+pop", cfg, m, clk, din, dout, cke => false, rst => true);
    cycle(false, false, "check after reset", cfg, m, clk, din, dout);
    -- Stack usable after the reset
    for i in 1 to cfg.depth loop
      cycle(true, false, "push after reset", cfg, m, clk, din, dout);
    end loop;
    drain("async_reset", cfg, m, clk, din, dout);
  end procedure;

end package body tb_stack_async_reset_pkg;
