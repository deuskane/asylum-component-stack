-------------------------------------------------------------------------------
-- Title      : tb_stack_cke_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_cke_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario cke of tb_stack, from reset :
--              cke_i = 0 freezes the stack : push, pop and push+pop ignored,
--              half full and full
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 5 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_cke_pkg is

  -- cke_i = 0 freezes the stack : push, pop and push+pop ignored, half full
  -- and full
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_cke_pkg;

package body tb_stack_cke_pkg is

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
    for i in 1 to cfg.depth/2 loop
      cycle(true, false, "fill", cfg, m, clk, din, dout);
    end loop;
    cycle(true , false, "push with cke_i = 0"    , cfg, m, clk, din, dout, cke => false);
    cycle(false, true , "pop with cke_i = 0"     , cfg, m, clk, din, dout, cke => false);
    cycle(true , true , "push+pop with cke_i = 0", cfg, m, clk, din, dout, cke => false);
    cycle(false, false, "check after cke_i = 0"  , cfg, m, clk, din, dout);
    -- Full stack frozen
    for i in cfg.depth/2+1 to cfg.depth loop
      cycle(true, false, "fill to full", cfg, m, clk, din, dout);
    end loop;
    cycle(true , false, "full, push with cke_i = 0", cfg, m, clk, din, dout, cke => false);
    cycle(false, true , "full, pop with cke_i = 0" , cfg, m, clk, din, dout, cke => false);
    cycle(false, false, "check after cke_i = 0"    , cfg, m, clk, din, dout);
    drain("cke", cfg, m, clk, din, dout);
  end procedure;

end package body tb_stack_cke_pkg;
