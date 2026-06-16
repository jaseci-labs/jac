"""Phase 2 parity tests: JS state evolves the same way as the NA sidecar given the
same frame/command sequence. Run with `bun test ./dist/` after `build.py`.

Multi-statement bodies live in same-module `def`s (Jac lambdas are
single-expression); each `test(...)` wraps `lambda : t_fn()`.
"""

import from 'bun:test' { test, expect }
import from .state { TuiState }
import from .protocol { Protocol }
import from .input { Input, KeyResult }

def t_full_snapshot {
    st = TuiState();
    p = Protocol();
    lines = [
        "TYPE:full",
        "STATUS:running",
        "MODEL:gpt",
        "ACTIVE:Plan",
        "NEEDS_KEY:1",
        "KEY_ENV:OPENAI_API_KEY",
        "EV:1:user::hello world",
        "EV:2:answer::hi"
    ];
    p.apply_frame(st, lines);
    expect(st.status).toBe("running");
    expect(st.model_name).toBe("gpt");
    expect(st.active).toBe("Plan");
    expect(st.needs_key).toBe(True);
    expect(st.key_env).toBe("OPENAI_API_KEY");
    expect(len(st.events)).toBe(2);
    expect(st.events[0].id).toBe(1);
    expect(st.events[0].kind).toBe("user");
    expect(st.events[0].text).toBe("hello world");
    expect(st.events[1].id).toBe(2);
}

def t_delta_appends {
    st = TuiState();
    p = Protocol();
    p.apply_frame(st, ["TYPE:full", "EV:1:user::a", "EV:2:answer::b"]);
    p.apply_frame(st, ["TYPE:delta", "EV:3:reasoning::c"]);
    expect(len(st.events)).toBe(3);
    expect(st.events[2].id).toBe(3);
    expect(st.events[2].kind).toBe("reasoning");
    expect(st.events[2].text).toBe("c");
}

def t_repeated_id_replaces {
    st = TuiState();
    p = Protocol();
    p.apply_frame(st, ["TYPE:full", "EV:3:reasoning::first"]);
    p.apply_frame(st, ["TYPE:delta", "EV:3:answer::second"]);
    # Same id upserts in place: no append, text + kind replaced.
    expect(len(st.events)).toBe(1);
    expect(st.events[0].text).toBe("second");
    expect(st.events[0].kind).toBe("answer");
}

def t_full_resets {
    st = TuiState();
    p = Protocol();
    p.apply_frame(st, ["TYPE:full", "EV:1:user::a", "EV:2:answer::b"]);
    st.scroll_up(5);
    p.apply_frame(st, ["TYPE:full", "EV:9:user::fresh"]);
    expect(len(st.events)).toBe(1);
    expect(st.events[0].id).toBe(9);
    expect(st.follow_tail).toBe(True);
    expect(st.viewport_top).toBe(0);
}

def t_heartbeat_noop {
    st = TuiState();
    p = Protocol();
    p.apply_frame(st, ["TYPE:full", "EV:1:user::a"]);
    p.apply_frame(st, ["TYPE:hb"]);
    expect(len(st.events)).toBe(1);
}

def t_unescape {
    st = TuiState();
    p = Protocol();
    # Frame text carries the control-plane escaping: backslash-n, backslash-backslash.
    p.apply_frame(st, ["TYPE:delta", "EV:1:answer::line1\\nline2\\\\end"]);
    expect(st.events[0].text).toBe("line1\nline2\\end");
}

def t_ev_text_with_colons {
    st = TuiState();
    p = Protocol();
    # Only the first three colons are field separators; text keeps the rest.
    p.apply_frame(st, ["TYPE:delta", "EV:1:system::a:b:c"]);
    expect(st.events[0].text).toBe("a:b:c");
}

def t_send_idle {
    st = TuiState();
    inp = Input();
    st.input_buf = "hello";
    res = inp.handle_key(st, "\r");
    expect(len(res.commands)).toBe(1);
    expect(res.commands[0]).toBe("SEND:hello");
    expect(res.quit).toBe(False);
    expect(st.input_buf).toBe("");
    expect(st.follow_tail).toBe(True);
}

def t_send_blocked_while_running {
    st = TuiState();
    inp = Input();
    st.status = "running";
    st.input_buf = "later";
    res = inp.handle_key(st, "\r");
    expect(len(res.commands)).toBe(0);
    expect(st.input_buf).toBe("");
}

def t_slash_quit {
    st = TuiState();
    inp = Input();
    st.input_buf = "/quit";
    res = inp.handle_key(st, "\r");
    expect(res.commands[0]).toBe("QUIT");
    expect(res.quit).toBe(True);
}

def t_slash_stop {
    st = TuiState();
    inp = Input();
    st.input_buf = "/stop";
    res = inp.handle_key(st, "\r");
    expect(res.commands[0]).toBe("STOP");
    expect(res.quit).toBe(False);
}

def t_slash_reset {
    st = TuiState();
    inp = Input();
    p = Protocol();
    p.apply_frame(st, ["TYPE:full", "EV:1:user::a"]);
    st.input_buf = "/reset";
    res = inp.handle_key(st, "\r");
    expect(res.commands[0]).toBe("RESET");
    expect(len(st.events)).toBe(0);
}

def t_slash_settings {
    st = TuiState();
    inp = Input();
    st.input_buf = "/settings model=gpt-4, temperature=0.2";
    res = inp.handle_key(st, "\r");
    expect(res.commands[0]).toBe("APPLY:model=gpt-4, temperature=0.2");
}

def t_ctrl_keys {
    inp = Input();
    a = inp.handle_key(TuiState(), "\x03");
    expect(a.commands[0]).toBe("QUIT");
    expect(a.quit).toBe(True);
    b = inp.handle_key(TuiState(), "\x07");
    expect(b.commands[0]).toBe("STOP");
    cst = TuiState();
    p = Protocol();
    p.apply_frame(cst, ["TYPE:full", "EV:1:user::a"]);
    c = inp.handle_key(cst, "\x12");
    expect(c.commands[0]).toBe("RESET");
    expect(len(cst.events)).toBe(0);
}

def t_printable_and_backspace {
    st = TuiState();
    inp = Input();
    inp.handle_key(st, "a");
    inp.handle_key(st, "b");
    inp.handle_key(st, "c");
    expect(st.input_buf).toBe("abc");
    inp.handle_key(st, "\x7f");
    expect(st.input_buf).toBe("ab");
}

def t_scroll_follow_tail {
    st = TuiState();
    inp = Input();
    st.viewport_top = 10;
    inp.handle_key(st, "\x1b[A");
    expect(st.viewport_top).toBe(7);
    expect(st.follow_tail).toBe(False);
    inp.handle_key(st, "\x1b[B");
    expect(st.viewport_top).toBe(10);
    st.scroll_to_bottom();
    expect(st.follow_tail).toBe(True);
}

def t_build_rows_wrap {
    st = TuiState();
    p = Protocol();
    st.term_cols = 24;
    # answer prefix "  " (af=18), continuation "    " (ac=16); 50 chars -> 18+16+16.
    p.apply_frame(
        st,
        ["TYPE:full", "EV:1:answer::01234567890123456789012345678901234567890123456789"]
    );
    st.build_rows();
    expect(len(st.display_rows)).toBe(3);
    expect(st.display_rows[0].is_continuation).toBe(False);
    expect(st.display_rows[1].is_continuation).toBe(True);
    expect(len(st.display_rows[0].text)).toBe(20);
}

def t_build_rows_phase_node {
    st = TuiState();
    p = Protocol();
    p.apply_frame(st, ["TYPE:full", "EV:7:phase:Build:"]);
    st.build_rows();
    expect(st.display_rows[0].text).toBe("> Build");
}

with entry {
    test("full snapshot reconstructs state", lambda : t_full_snapshot());
    test("delta appends a new event", lambda : t_delta_appends());
    test("repeated id replaces in place", lambda : t_repeated_id_replaces());
    test("full frame resets transcript", lambda : t_full_resets());
    test("heartbeat is a no-op", lambda : t_heartbeat_noop());
    test("text escaping is reversed", lambda : t_unescape());
    test("EV text keeps colons past field 3", lambda : t_ev_text_with_colons());
    test("enter sends when idle", lambda : t_send_idle());
    test("enter is blocked while running", lambda : t_send_blocked_while_running());
    test("/quit emits QUIT and quits", lambda : t_slash_quit());
    test("/stop emits STOP", lambda : t_slash_stop());
    test("/reset clears events", lambda : t_slash_reset());
    test("/settings emits APPLY", lambda : t_slash_settings());
    test("control keys map to commands", lambda : t_ctrl_keys());
    test("printable + backspace edit the buffer", lambda : t_printable_and_backspace());
    test("scroll keys move viewport + follow_tail", lambda : t_scroll_follow_tail());
    test("build_rows hard-wraps to width", lambda : t_build_rows_wrap());
    test("build_rows renders phase node", lambda : t_build_rows_phase_node());
}
