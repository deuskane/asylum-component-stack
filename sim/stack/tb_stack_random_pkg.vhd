-------------------------------------------------------------------------------
-- Title      : tb_stack_random_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_random_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Scenario random of tb_stack, from reset :
--              1200 cycles of random push / pop / cke_i in three phases (tends
--              to full, tends to empty, balanced) ; with CYCLIC_PTR no pop on
--              an empty stack (see the scenario cyclic)
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (test 7 of the former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use     work.tb_stack_bfm_pkg.all;

package tb_stack_random_pkg is

  -- 1200 cycles of random push / pop / cke_i in three phases (tends to full,
  -- tends to empty, balanced) ; with CYCLIC_PTR no pop on an empty stack
  -- (see the scenario cyclic)
  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

end package tb_stack_random_pkg;

package body tb_stack_random_pkg is

  procedure run
    (constant cfg      : in    cfg_t
    ;constant first    : in    natural      -- Number of the first word pushed
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    ) is
    variable m         : model_t(stk(0 to cfg.depth-1)(cfg.width-1 downto 0));
    variable v_push    : boolean;
    variable v_pop     : boolean;
    variable v_cke     : boolean;
  begin
    init(m, first);
    -- Same sequence whatever the scenarios run before
    randomize(1, 1, "seeds of the scenario random", C_TB_SCOPE);
    for phase in 0 to 2 loop
      for i in 1 to 400 loop
        case phase is
          when 0      => v_push := random(1, 100) <= 70; v_pop := random(1, 100) <= 30; -- tends to full
          when 1      => v_push := random(1, 100) <= 30; v_pop := random(1, 100) <= 70; -- tends to empty
          when others => v_push := random(1, 100) <= 50; v_pop := random(1, 100) <= 50;
        end case;
        v_cke := random(1, 100) <= 85;
        -- CYCLIC_PTR : no pop on an empty stack here (the model does not follow
        -- the pointer, see the scenario cyclic)
        if cfg.cyclic and m.nb = 0
        then
          v_pop := v_pop and v_push;
        end if;
        cycle(v_push, v_pop, "phase " & to_string(phase) & " cycle " & to_string(i), cfg, m, clk, din, dout, cke => v_cke);
      end loop;
    end loop;
    drain("random", cfg, m, clk, din, dout);
  end procedure;

end package body tb_stack_random_pkg;
