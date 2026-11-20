-------------------------------------------------------------------------------
-- Title      : tb_stack_bfm_pkg
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack_bfm_pkg.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Helpers of the tb_stack scenarios : DUT signals as two records
--              (inputs driven by the testbench, outputs), reference model of
--              the stack content, one clock cycle (inputs driven, outputs
--              checked against the model, model updated), reset pulse.
-------------------------------------------------------------------------------
-- Copyright (c) 2026
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2026-11-20  1.0      mrosiere Created (cycle procedure and model of the
--                               former tb_stack)
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

package tb_stack_bfm_pkg is

  constant C_TB_SCOPE    : string := "TB_STACK_BFM";
  constant C_CLK_PERIOD  : time   := 10 ns;

  -- Generics of the DUT
  type cfg_t is record
    width     : natural;
    depth     : natural;   -- Power of 2
    overwrite : boolean;   -- OVERWRITE /= 0
    cyclic    : boolean;   -- CYCLIC_PTR
  end record cfg_t;

  -- Inputs of the DUT, driven by the testbench
  type stack_in_t is record
    cke       : std_logic;
    arstn     : std_logic;
    srst      : std_logic;
    push_val  : std_logic;
    push_data : std_logic_vector;
    pop_ack   : std_logic;
  end record stack_in_t;

  -- Outputs of the DUT
  type stack_out_t is record
    push_ack  : std_logic;
    pop_val   : std_logic;
    pop_data  : std_logic_vector;
  end record stack_out_t;

  -- Reference model : stk(0) is the oldest word, stk(nb-1) the top
  type words_t is array (natural range <>) of std_logic_vector;
  type model_t is record
    stk       : words_t;
    nb        : natural;   -- Number of words
    next_data : natural;   -- Number of the next word to push (data(next_data))
  end record model_t;

  function to_sl
    (constant b        : in    boolean
    ) return std_logic;

  -- Word number i, on width bits : i, inverted every other pair of words
  -- (1, not 2, not 3, 4, 5, not 6...) : every bit is 0 and 1
  function data
    (constant i        : in    natural
    ;constant width    : in    natural
    ) return std_logic_vector;

  -- Empty model, first : number of the first word pushed
  procedure init
    (variable m        : inout model_t
    ;constant first    : in    natural
    );

  -- One clock cycle :
  -- * inputs driven on the falling edge of the clock
  -- * outputs checked against the model a quarter period later
  --   (pop_val_o, push_ack_o, and pop_data_o when the stack is not empty)
  -- * model updated with the transfers of the next rising edge
  -- rst  : arstn_i = 0 during this cycle (the stack is empty at once)
  -- srst : srst_i  = 1 during this cycle (the stack is empty after the edge)
  procedure cycle
    (constant push     : in    boolean
    ;constant pop      : in    boolean
    ;constant msg      : in    string
    ;constant cfg      : in    cfg_t
    ;variable m        : inout model_t
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    ;constant cke      : in    boolean := true
    ;constant rst      : in    boolean := false
    ;constant srst     : in    boolean := false
    );

  -- Inputs back to idle on the falling edge (cke_i = 1, no reset, no request)
  procedure idle
    (signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    );

  -- Pop until empty, checking the LIFO order, then one cycle without request
  procedure drain
    (constant msg      : in    string
    ;constant cfg      : in    cfg_t
    ;variable m        : inout model_t
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    );

  -- Reset pulse (arstn_i), inputs idle, released on the falling edge
  procedure do_reset
    (signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    );

end package tb_stack_bfm_pkg;

package body tb_stack_bfm_pkg is

  function to_sl
    (constant b        : in    boolean
    ) return std_logic is
  begin
    if b
    then
      return '1';
    else
      return '0';
    end if;
  end function;

  function data
    (constant i        : in    natural
    ;constant width    : in    natural
    ) return std_logic_vector is
  begin
    if ((i/2) mod 2) = 1
    then
      return not std_logic_vector(to_unsigned(i mod 2**width, width));
    else
      return     std_logic_vector(to_unsigned(i mod 2**width, width));
    end if;
  end function;

  procedure init
    (variable m        : inout model_t
    ;constant first    : in    natural
    ) is
  begin
    m.nb        := 0;
    m.next_data := first;
  end procedure;

  procedure cycle
    (constant push     : in    boolean
    ;constant pop      : in    boolean
    ;constant msg      : in    string
    ;constant cfg      : in    cfg_t
    ;variable m        : inout model_t
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    ;constant cke      : in    boolean := true
    ;constant rst      : in    boolean := false
    ;constant srst     : in    boolean := false
    ) is
    variable v_push_ok : boolean;
    variable v_pop_ok  : boolean;
  begin
    wait until falling_edge(clk);
    din.push_val  <= to_sl(push);
    din.push_data <= data(m.next_data, cfg.width);
    din.pop_ack   <= to_sl(pop);
    din.cke       <= to_sl(cke);
    din.arstn     <= to_sl(not rst);
    din.srst      <= to_sl(srst);
    wait for C_CLK_PERIOD/4;

    -- Asynchronous reset : the stack is already empty (no clock edge needed)
    if rst
    then
      m.nb := 0;
    end if;

    -- Outputs against the model (combinational, independent of cke_i)
    check_value(dout.pop_val , to_sl(m.nb /= 0)                       , ERROR, msg & " : pop_val_o (level " & to_string(m.nb) & ")", C_TB_SCOPE);
    check_value(dout.push_ack, to_sl(m.nb /= cfg.depth or cfg.overwrite), ERROR, msg & " : push_ack_o (level " & to_string(m.nb) & ")", C_TB_SCOPE);
    if m.nb /= 0
    then
      check_value(dout.pop_data, m.stk(m.nb-1), ERROR, msg & " : pop_data_o = top of stack (level " & to_string(m.nb) & ")", C_TB_SCOPE);
    end if;

    -- Transfers expected from the model (not from the DUT outputs)
    v_push_ok := push and (m.nb /= cfg.depth or cfg.overwrite);
    v_pop_ok  := pop  and  m.nb /= 0;

    -- Model update (the resets have priority over cke_i; the synchronous
    -- reset empties the stack on the rising edge)
    if rst or srst
    then
      m.nb := 0;
    elsif cke
    then
      if v_push_ok and v_pop_ok
      then
        -- Replace the top word
        m.stk(m.nb-1) := data(m.next_data, cfg.width);
      elsif v_push_ok
      then
        if m.nb = cfg.depth
        then
          -- OVERWRITE : drop the oldest word
          for i in 0 to cfg.depth-2 loop
            m.stk(i) := m.stk(i+1);
          end loop;
          m.stk(cfg.depth-1) := data(m.next_data, cfg.width);
        else
          m.stk(m.nb) := data(m.next_data, cfg.width);
          m.nb        := m.nb + 1;
        end if;
      elsif v_pop_ok
      then
        m.nb := m.nb - 1;
      end if;
      if v_push_ok
      then
        m.next_data := m.next_data + 1;
      end if;
    end if;

    wait until rising_edge(clk);
  end procedure;

  procedure idle
    (signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ) is
  begin
    wait until falling_edge(clk);
    din.push_val <= '0';
    din.pop_ack  <= '0';
    din.cke      <= '1';
    din.arstn    <= '1';
    din.srst     <= '0';
  end procedure;

  procedure drain
    (constant msg      : in    string
    ;constant cfg      : in    cfg_t
    ;variable m        : inout model_t
    ;signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ;signal   dout     : in    stack_out_t
    ) is
  begin
    while m.nb /= 0 loop
      cycle(false, true , msg & " drain", cfg, m, clk, din, dout);
    end loop;
    cycle(false, false, msg & " empty", cfg, m, clk, din, dout);
  end procedure;

  procedure do_reset
    (signal   clk      : in    std_logic
    ;signal   din      : out   stack_in_t
    ) is
  begin
    din.push_val  <= '0';
    din.push_data <= (din.push_data'range => '0');
    din.pop_ack   <= '0';
    din.cke       <= '1';
    din.srst      <= '0';
    din.arstn     <= '0';
    wait until rising_edge(clk);
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    din.arstn     <= '1';
    wait until rising_edge(clk);
  end procedure;

end package body tb_stack_bfm_pkg;
