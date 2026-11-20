-------------------------------------------------------------------------------
-- Title      : tb_stack_cyclic_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_cyclic_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario cyclic of tb_stack, from reset :
--              CYCLIC_PTR only : a pop on an empty stack moves the pointer
--              (KCPSM3), the next pop reads the word below. DEPTH+1 pushes,
--              DEPTH+3 pops (the level saturates at DEPTH, 3 of them on the
--              empty stack), 2 pushes, 4 pops ; then srst_i puts the pointer
--              back to 0 : DEPTH-1 pops on the empty stack read the RAM from
--              its last word down ; then arstn_i puts the pointer back to 0
--              again : DEPTH pops. Circular model of the RAM (written words,
--              pointer, level)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 8 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_cyclic_pkg is

  -- CYCLIC_PTR only : a pop on an empty stack moves the pointer (KCPSM3),
  -- the next pop reads the word below. DEPTH+1 pushes, DEPTH+3 pops (the
  -- level saturates at DEPTH, 3 of them on the empty stack), 2 pushes, 4
  -- pops ; then srst_i puts the pointer back to 0 : DEPTH-1 pops on the
  -- empty stack read the RAM from its last word down ; then arstn_i puts the
  -- pointer back to 0 again : DEPTH pops. Circular model of the RAM (written
  -- words, pointer, level)
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_cyclic_pkg;

package body tb_stack_cyclic_pkg is

  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    ) is
    variable m         : model_t(stk(0 to cfg.depth-1)(cfg.width-1 downto 0));
    constant C_NB      : natural := 4*cfg.depth+11;
    -- Circular model : RAM image, written flags, pointer, level
    variable v_mem     : words_t(0 to cfg.depth-1)(cfg.width-1 downto 0);
    variable v_wr      : boolean_vector(0 to cfg.depth-1) := (others => false);
    variable v_ptr     : natural := 0;
    variable v_nb      : natural := 0;
    variable v_top     : natural;
    variable v_push    : boolean;
    variable v_pop     : boolean;
    variable v_srst    : boolean;
    variable v_rst     : boolean;
  begin
    init(m, first);
    for i in 1 to C_NB loop
      v_push := false; v_pop := false; v_srst := false; v_rst := false;
      -- Up to full, then 1 overwrite
      if    i <= cfg.depth+1
      then
        v_push := true;
      -- Down to empty, then 3 pops on the empty stack
      elsif i <= 2*cfg.depth+4
      then
        v_pop  := true;
      elsif i <= 2*cfg.depth+6
      then
        v_push := true;
      elsif i <= 2*cfg.depth+10
      then
        v_pop  := true;
      -- Pointer back to 0, then DEPTH-1 pops : the RAM read from its last word down
      elsif i =  2*cfg.depth+11
      then
        v_srst := true;
      elsif i <= 3*cfg.depth+10
      then
        v_pop  := true;
      -- Pointer (1) back to 0, then DEPTH pops
      elsif i =  3*cfg.depth+11
      then
        v_rst  := true;
      else
        v_pop  := true;
      end if;
      wait until falling_edge(clk);
      din.push_val  <= to_sl(v_push);
      din.push_data <= data(m.next_data, cfg.width);
      din.pop_ack   <= to_sl(v_pop);
      din.srst      <= to_sl(v_srst);
      din.arstn     <= to_sl(not v_rst);
      wait for C_CLK_PERIOD/4;
      -- Asynchronous reset : pointer and level already cleared
      if v_rst
      then
        v_ptr := 0;
        v_nb  := 0;
      end if;
      v_top := (v_ptr + cfg.depth - 1) mod cfg.depth;
      check_value(dout.pop_val , to_sl(v_nb /= 0), ERROR, "cycle " & to_string(i) & " : pop_val_o (level " & to_string(v_nb) & ")", C_TB_SCOPE);
      check_value(dout.push_ack, '1'             , ERROR, "cycle " & to_string(i) & " : push_ack_o (OVERWRITE)", C_TB_SCOPE);
      if v_wr(v_top)
      then
        check_value(dout.pop_data, v_mem(v_top), ERROR, "cycle " & to_string(i) & " : pop_data_o = word below the pointer (" & to_string(v_ptr) & ")", C_TB_SCOPE);
      end if;
      if v_srst
      then
        v_ptr := 0;
        v_nb  := 0;
      elsif v_push
      then
        v_mem(v_ptr)  := data(m.next_data, cfg.width);
        v_wr(v_ptr)   := true;
        v_ptr         := (v_ptr + 1) mod cfg.depth;
        v_nb          := minimum(v_nb + 1, cfg.depth);
        m.next_data   := m.next_data + 1;
      elsif v_pop
      then
        v_ptr         := (v_ptr + cfg.depth - 1) mod cfg.depth;  -- also on an empty stack
        v_nb          := maximum(v_nb, 1) - 1;
      end if;
      wait until rising_edge(clk);
    end loop;
    idle(clk, din);
  end procedure;

end package body tb_stack_cyclic_pkg;
