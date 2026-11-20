-------------------------------------------------------------------------------
-- Title      : tb_stack_lifo_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_lifo_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario lifo of tb_stack, from reset :
--              Push up to full, then pop in LIFO order : pop_data_o is the
--              last word pushed at every level
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 2 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_lifo_pkg is

  -- Push up to full, then pop in LIFO order : pop_data_o is the last word
  -- pushed at every level
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_lifo_pkg;

package body tb_stack_lifo_pkg is

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
      cycle(true, false, "push " & to_string(i), cfg, m, clk, din, dout);
    end loop;
    drain("lifo", cfg, m, clk, din, dout);
  end procedure;

end package body tb_stack_lifo_pkg;
