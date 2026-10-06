-------------------------------------------------------------------------------
-- Title      : tb_stack
-- Project    : stack
-------------------------------------------------------------------------------
-- File       : tb_stack.vhd
-- Author     : mrosiere
-------------------------------------------------------------------------------
-- Description: Self-checking UVVM testbench of the stack. The DUT handshakes
--              are driven cycle by cycle and compared against a reference
--              model (scoreboard) of the stack content.
-------------------------------------------------------------------------------
-- Copyright (c) 2016
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author   Description
-- 2016-11-11  1.0      mrosiere Created
-- 2026-10-05  2.0      mrosiere Convert to UVVM, add WIDTH/DEPTH/OVERWRITE
--                               generics, OVERWRITE, cke_i, reset and random
--                               tests
-------------------------------------------------------------------------------

library ieee;
use     ieee.std_logic_1164.all;
use     ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library asylum;
use     asylum.stack_pkg.all;

entity tb_stack is
  generic (
    WIDTH     : natural := 8;
    DEPTH     : natural := 8;  -- Power of 2
    OVERWRITE : natural := 0
    );
end tb_stack;

architecture tb of tb_stack is

  constant C_SCOPE      : string := "TB_STACK";
  constant C_CLK_PERIOD : time   := 10 ns;

  -- =====[ Signals ]=============================
  signal clk_i        : std_logic := '0';
  signal clk_ena      : boolean   := true;
  signal cke_i        : std_logic := '1';
  signal arstn_i      : std_logic := '0';
  signal push_val_i   : std_logic := '0';
  signal push_ack_o   : std_logic;
  signal push_data_i  : std_logic_vector(WIDTH -1 downto 0) := (others => '0');
  signal pop_val_o    : std_logic;
  signal pop_ack_i    : std_logic := '0';
  signal pop_data_o   : std_logic_vector(WIDTH -1 downto 0);

begin

  ------------------------------------------------
  -- Instance of DUT
  ------------------------------------------------
  dut : stack
    generic map
    (WIDTH     => WIDTH
    ,DEPTH     => DEPTH
    ,OVERWRITE => OVERWRITE
     )
    port map
    (clk_i       => clk_i
    ,cke_i       => cke_i
    ,arstn_i     => arstn_i
    ,push_val_i  => push_val_i
    ,push_ack_o  => push_ack_o
    ,push_data_i => push_data_i
    ,pop_val_o   => pop_val_o
    ,pop_ack_i   => pop_ack_i
    ,pop_data_o  => pop_data_o
     );

  ------------------------------------------------
  -- Clock
  ------------------------------------------------
  clock_generator(clk_i, clk_ena, C_CLK_PERIOD, "TB Clock");

  ------------------------------------------------
  -- Sequencer
  ------------------------------------------------
  p_main : process

    -- Reference model: v_stk(0) is the oldest word, v_stk(v_nb-1) the top
    type     t_stk is array (0 to DEPTH-1) of std_logic_vector(WIDTH-1 downto 0);
    variable v_stk       : t_stk;
    variable v_nb        : natural := 0;
    variable v_next_data : natural := 1;
    variable v_nb_checks : natural := 0;
    variable v_push      : boolean;
    variable v_pop       : boolean;
    variable v_cke       : boolean;
    variable v_start     : natural;

    function to_sl(b : boolean) return std_logic is
    begin
      if b then return '1'; else return '0'; end if;
    end function;

    function data(i : natural) return std_logic_vector is
    begin
      return std_logic_vector(to_unsigned(i mod 2**WIDTH, WIDTH));
    end function;

    ----------------------------------------------
    -- One clock cycle
    -- * inputs driven on the falling edge
    -- * outputs checked against the model a quarter period later
    -- * model updated with the transfers of the next rising edge
    ----------------------------------------------
    procedure cycle(constant push : in boolean;
                    constant pop  : in boolean;
                    constant msg  : in string;
                    constant cke  : in boolean := true;
                    constant rst  : in boolean := false) is
      variable v_push_ok : boolean;
      variable v_pop_ok  : boolean;
    begin
      wait until falling_edge(clk_i);
      push_val_i  <= to_sl(push);
      push_data_i <= data(v_next_data);
      pop_ack_i   <= to_sl(pop);
      cke_i       <= to_sl(cke);
      arstn_i     <= to_sl(not rst);
      wait for C_CLK_PERIOD/4;

      -- Outputs against the model (combinational, independent of cke_i and arstn_i)
      check_value(pop_val_o , to_sl(v_nb /= 0)                     , ERROR, msg & ": pop_val_o (level " & to_string(v_nb) & ")", C_SCOPE);
      check_value(push_ack_o, to_sl(v_nb /= DEPTH or OVERWRITE /= 0), ERROR, msg & ": push_ack_o (level " & to_string(v_nb) & ")", C_SCOPE);
      v_nb_checks := v_nb_checks + 2;
      if v_nb /= 0 then
        check_value(pop_data_o, v_stk(v_nb-1), ERROR, msg & ": pop_data_o = top of stack (level " & to_string(v_nb) & ")", C_SCOPE);
        v_nb_checks := v_nb_checks + 1;
      end if;

      v_push_ok := push and push_ack_o = '1';
      v_pop_ok  := pop  and pop_val_o  = '1';

      -- Model update (synchronous reset has priority over cke_i)
      if rst then
        v_nb := 0;
      elsif cke then
        if v_push_ok and v_pop_ok then
          -- Replace the top word
          v_stk(v_nb-1) := data(v_next_data);
        elsif v_push_ok then
          if v_nb = DEPTH then
            -- OVERWRITE: drop the oldest word
            for i in 0 to DEPTH-2 loop
              v_stk(i) := v_stk(i+1);
            end loop;
            v_stk(DEPTH-1) := data(v_next_data);
          else
            v_stk(v_nb) := data(v_next_data);
            v_nb        := v_nb + 1;
          end if;
        elsif v_pop_ok then
          v_nb := v_nb - 1;
        end if;
        if v_push_ok then
          v_next_data := v_next_data + 1;
        end if;
      end if;

      wait until rising_edge(clk_i);
    end procedure;

    -- Release all the inputs (cke_i = 1, no reset)
    procedure idle is
    begin
      wait until falling_edge(clk_i);
      push_val_i <= '0';
      pop_ack_i  <= '0';
      cke_i      <= '1';
      arstn_i    <= '1';
    end procedure;

    -- Synchronous reset of the DUT and of the model
    procedure reset(constant msg : in string) is
    begin
      cycle(false, false, msg & " reset", rst => true);
      idle;
    end procedure;

    -- Pop until empty, checking the LIFO order
    procedure drain(constant msg : in string) is
    begin
      while v_nb /= 0 loop
        cycle(false, true, msg & " drain");
      end loop;
      cycle(false, false, msg & " empty");
    end procedure;

  begin
    log(ID_LOG_HDR, "Start of simulation: WIDTH = " & to_string(WIDTH) & ", DEPTH = " & to_string(DEPTH) & ", OVERWRITE = " & to_string(OVERWRITE), C_SCOPE);

    -- Positive acknowledges are not logged (several checks per cycle)
    disable_log_msg(ID_POS_ACK);

    -- Initial reset: the first edge with arstn_i = 0 clears the pointers
    arstn_i <= '0';
    wait until rising_edge(clk_i);
    wait until rising_edge(clk_i);

    ----------------------------------------------
    log(ID_LOG_HDR, "Test 1: Flags after reset", C_SCOPE);
    ----------------------------------------------
    reset("T1");
    cycle(false, false, "T1 after reset");

    ----------------------------------------------
    log(ID_LOG_HDR, "Test 2: Push up to full, then pop in LIFO order", C_SCOPE);
    ----------------------------------------------
    reset("T2");
    for i in 1 to DEPTH loop
      cycle(true, false, "T2 push " & to_string(i));
    end loop;
    check_value(v_nb, DEPTH, ERROR, "T2 stack full", C_SCOPE);
    drain("T2");

    ----------------------------------------------
    log(ID_LOG_HDR, "Test 3: Push on a full stack (OVERWRITE = " & to_string(OVERWRITE) & ")", C_SCOPE);
    ----------------------------------------------
    -- OVERWRITE  = 0 : the push is refused (push_ack_o = 0), the content is kept
    -- OVERWRITE /= 0 : the push is accepted, the stack keeps the last DEPTH words
    reset("T3");
    v_start := v_next_data;
    for i in 1 to DEPTH+3 loop
      cycle(true, false, "T3 push " & to_string(i));
    end loop;
    if OVERWRITE = 0 then
      check_value(v_next_data-v_start, DEPTH  , ERROR, "T3 only DEPTH words accepted", C_SCOPE);
    else
      check_value(v_next_data-v_start, DEPTH+3, ERROR, "T3 all the words accepted", C_SCOPE);
    end if;
    drain("T3");

    ----------------------------------------------
    log(ID_LOG_HDR, "Test 4: Simultaneous push and pop at every level (replaces the top word)", C_SCOPE);
    ----------------------------------------------
    for level in 0 to DEPTH loop
      reset("T4 level " & to_string(level));
      for i in 1 to level loop
        cycle(true, false, "T4 level " & to_string(level) & " fill");
      end loop;
      cycle(true , true , "T4 level " & to_string(level) & " push+pop");
      cycle(false, false, "T4 level " & to_string(level) & " check");
      for i in 1 to 3 loop
        cycle(true, true, "T4 level " & to_string(level) & " push+pop burst");
      end loop;
      drain("T4 level " & to_string(level));
    end loop;

    ----------------------------------------------
    log(ID_LOG_HDR, "Test 5: cke_i = 0 freezes the stack", C_SCOPE);
    ----------------------------------------------
    reset("T5");
    for i in 1 to DEPTH/2 loop
      cycle(true, false, "T5 fill");
    end loop;
    cycle(true , false, "T5 push with cke_i = 0"    , cke => false);
    cycle(false, true , "T5 pop with cke_i = 0"     , cke => false);
    cycle(true , true , "T5 push+pop with cke_i = 0", cke => false);
    cycle(false, false, "T5 check after cke_i = 0");
    check_value(v_nb, DEPTH/2, ERROR, "T5 level unchanged", C_SCOPE);
    -- Full stack frozen
    for i in DEPTH/2+1 to DEPTH loop
      cycle(true, false, "T5 fill to full");
    end loop;
    cycle(true , false, "T5 full, push with cke_i = 0", cke => false);
    cycle(false, true , "T5 full, pop with cke_i = 0" , cke => false);
    cycle(false, false, "T5 check after cke_i = 0");
    drain("T5");

    ----------------------------------------------
    log(ID_LOG_HDR, "Test 6: Synchronous reset arstn_i", C_SCOPE);
    ----------------------------------------------
    reset("T6");
    for i in 1 to DEPTH/2 loop
      cycle(true, false, "T6 fill");
    end loop;
    -- arstn_i = 0 driven on the falling edge: no effect before the rising edge
    wait until falling_edge(clk_i);
    arstn_i <= '0';
    wait for C_CLK_PERIOD/4;
    check_value(pop_val_o, '1', ERROR, "T6 reset is synchronous: stack not cleared before the clock edge", C_SCOPE);
    check_value(pop_data_o, v_stk(v_nb-1), ERROR, "T6 reset is synchronous: top unchanged before the clock edge", C_SCOPE);
    wait until rising_edge(clk_i);
    v_nb := 0;
    wait for C_CLK_PERIOD/4;
    check_value(pop_val_o , '0', ERROR, "T6 stack empty after the clock edge with arstn_i = 0", C_SCOPE);
    check_value(push_ack_o, '1', ERROR, "T6 push_ack_o after reset", C_SCOPE);
    v_nb_checks := v_nb_checks + 4;
    idle;
    -- Reset while cke_i = 0 (the reset does not depend on cke_i) and with push requested
    for i in 1 to 3 loop
      cycle(true, false, "T6 refill");
    end loop;
    cycle(true, true, "T6 reset with cke_i = 0 and push+pop", cke => false, rst => true);
    cycle(false, false, "T6 check after reset");
    -- Stack usable after reset
    for i in 1 to DEPTH loop
      cycle(true, false, "T6 push after reset");
    end loop;
    drain("T6");

    ----------------------------------------------
    log(ID_LOG_HDR, "Test 7: Random push / pop / cke_i", C_SCOPE);
    ----------------------------------------------
    reset("T7");
    for phase in 0 to 2 loop
      for i in 1 to 400 loop
        case phase is
          when 0      => v_push := random(1, 100) <= 70; v_pop := random(1, 100) <= 30; -- tends to full
          when 1      => v_push := random(1, 100) <= 30; v_pop := random(1, 100) <= 70; -- tends to empty
          when others => v_push := random(1, 100) <= 50; v_pop := random(1, 100) <= 50;
        end case;
        v_cke := random(1, 100) <= 85;
        cycle(v_push, v_pop, "T7 phase " & to_string(phase) & " cycle " & to_string(i), cke => v_cke);
      end loop;
    end loop;
    drain("T7");
    idle;

    enable_log_msg(ID_POS_ACK);
    log(ID_SEQUENCER, to_string(v_nb_checks) & " checks done, " & to_string(v_next_data-1) & " words pushed", C_SCOPE);

    ----------------------------------------------
    -- End of simulation
    ----------------------------------------------
    wait for 10*C_CLK_PERIOD;
    report_alert_counters(FINAL);
    log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);
    clk_ena <= false;
    std.env.stop;
    wait;
  end process p_main;

end tb;
