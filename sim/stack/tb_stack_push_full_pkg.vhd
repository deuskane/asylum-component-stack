-------------------------------------------------------------------------------
-- Title      : tb_stack_push_full_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_push_full_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario push_full of tb_stack, from reset :
--              DEPTH+3 pushes on a full stack : with OVERWRITE = 0 the push is
--              refused (push_ack_o = 0) and the content kept ; with OVERWRITE
--              /= 0 it is accepted and the stack keeps the last DEPTH words
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 3 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_push_full_pkg is

  -- DEPTH+3 pushes on a full stack : with OVERWRITE = 0 the push is refused
  -- (push_ack_o = 0) and the content kept ; with OVERWRITE /= 0 it is
  -- accepted and the stack keeps the last DEPTH words
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_push_full_pkg;

package body tb_stack_push_full_pkg is

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
    for i in 1 to cfg.depth+3 loop
      cycle(true, false, "push " & to_string(i), cfg, m, clk, din, dout);
    end loop;
    drain("push_full", cfg, m, clk, din, dout);
  end procedure;

end package body tb_stack_push_full_pkg;
