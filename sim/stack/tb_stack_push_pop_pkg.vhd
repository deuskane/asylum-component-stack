-------------------------------------------------------------------------------
-- Title      : tb_stack_push_pop_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_push_pop_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario push_pop of tb_stack, from reset :
--              Simultaneous push and pop at every level 0 to DEPTH (reset
--              before each level) : the top word is replaced ; push only on an
--              empty stack ; pop only on a full stack with OVERWRITE = 0
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 4 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_push_pop_pkg is

  -- Simultaneous push and pop at every level 0 to DEPTH (reset before each
  -- level) : the top word is replaced ; push only on an empty stack ; pop
  -- only on a full stack with OVERWRITE = 0
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_push_pop_pkg;

package body tb_stack_push_pop_pkg is

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
    for level in 0 to cfg.depth loop
      cycle(false, false, "level " & to_string(level) & " reset", cfg, m, clk, din, dout, rst => true);
      idle(clk, din);
      for i in 1 to level loop
        cycle(true, false, "level " & to_string(level) & " fill", cfg, m, clk, din, dout);
      end loop;
      cycle(true , true , "level " & to_string(level) & " push+pop", cfg, m, clk, din, dout);
      cycle(false, false, "level " & to_string(level) & " check", cfg, m, clk, din, dout);
      for i in 1 to 3 loop
        cycle(true, true, "level " & to_string(level) & " push+pop burst", cfg, m, clk, din, dout);
      end loop;
      drain("level " & to_string(level), cfg, m, clk, din, dout);
    end loop;
  end procedure;

end package body tb_stack_push_pop_pkg;
