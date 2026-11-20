-------------------------------------------------------------------------------
-- Title      : tb_stack_reset_values_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_reset_values_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario reset_values of tb_stack, from reset :
--              Outputs during the reset and after it : empty stack (pop_val_o
--              = 0), push accepted (push_ack_o = 1)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 1 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_reset_values_pkg is

  -- Outputs during the reset and after it : empty stack (pop_val_o = 0),
  -- push accepted (push_ack_o = 1)
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_reset_values_pkg;

package body tb_stack_reset_values_pkg is

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
    cycle(false, false, "reset asserted", cfg, m, clk, din, dout, rst => true);
    idle(clk, din);
    cycle(false, false, "after reset", cfg, m, clk, din, dout);
  end procedure;

end package body tb_stack_reset_values_pkg;
