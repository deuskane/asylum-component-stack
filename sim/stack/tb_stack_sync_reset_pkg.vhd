-------------------------------------------------------------------------------
-- Title      : tb_stack_sync_reset_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_sync_reset_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario sync_reset of tb_stack, from reset :
--              Synchronous reset srst_i on a full stack : the stack is kept
--              until the clock edge, then empty (and accepts a push), even
--              with cke_i = 0 ; srst_i wins over a push+pop request ; the
--              stack is usable after the reset
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 9 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_sync_reset_pkg is

  -- Synchronous reset srst_i on a full stack : the stack is kept until the
  -- clock edge, then empty (and accepts a push), even with cke_i = 0 ;
  -- srst_i wins over a push+pop request ; the stack is usable after the
  -- reset
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_sync_reset_pkg;

package body tb_stack_sync_reset_pkg is

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
    -- srst_i = 1 driven on the falling edge : the stack is kept until the rising
    -- edge (synchronous), then empty even with cke_i = 0
    wait until falling_edge(clk);
    din.srst <= '1';
    din.cke  <= '0';
    wait for C_CLK_PERIOD/4;
    check_value(dout.pop_val , '1'                  , ERROR, "reset is synchronous : stack kept before the clock edge", C_TB_SCOPE);
    check_value(dout.push_ack, to_sl(cfg.overwrite), ERROR, "reset is synchronous : push_ack_o of a full stack before the clock edge", C_TB_SCOPE);
    wait until rising_edge(clk);
    wait for C_CLK_PERIOD/4;
    m.nb := 0;
    check_value(dout.pop_val , '0', ERROR, "stack empty after the clock edge with srst_i = 1 and cke_i = 0", C_TB_SCOPE);
    check_value(dout.push_ack, '1', ERROR, "push_ack_o after the synchronous reset", C_TB_SCOPE);
    idle(clk, din);
    -- Synchronous reset with push and pop requested : the reset wins
    for i in 1 to 3 loop
      cycle(true, false, "refill", cfg, m, clk, din, dout);
    end loop;
    cycle(true , true , "srst_i with push+pop", cfg, m, clk, din, dout, srst => true);
    cycle(false, false, "check after srst_i", cfg, m, clk, din, dout);
    -- Stack usable after the synchronous reset
    for i in 1 to cfg.depth loop
      cycle(true, false, "push after srst_i", cfg, m, clk, din, dout);
    end loop;
    drain("sync_reset", cfg, m, clk, din, dout);
  end procedure;

end package body tb_stack_sync_reset_pkg;
