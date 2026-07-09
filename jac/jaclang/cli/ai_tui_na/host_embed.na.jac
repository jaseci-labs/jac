"""Entry module for the self-hosting embed TUI (bin/jac-ai-tui).

Boots the fused CPython runtime via libjacpyembed, defines the agent
bridge functions in __main__ (_BOOTSTRAP_PY), opens the tty, and drives
tui_loop_once until quit/EOF. Env contract: JAC_AI_UI_PROJECT (cwd
override), JAC_AI_UI_FILES and JAC_AI_UI_MODEL_PRESETS (newline lists).
"""

import os;

# Suspected load-bearing imports: TuiState, SelectList/SelectItem,
# DiffEngine, and term_hyperlink/image_rows are never named below, but
# they pull their modules into the entry module's native link closure --
# do not remove without a full rebuild + runtime check.
import from .libc_tty { tty_open, tty_close }
import from .state { TuiState }
import from .select_list { SelectList, SelectItem }
import from .diff { DiffEngine }
import from .terminal_image { term_hyperlink, image_rows }
import from .tui_loop { tui_loop_once }
import from .tui_core { tui_populate_state, tui_enter_screen, tui_leave_screen }
import from .runtime { TuiRuntime }

import from jacpyembed {
    def jac_engine_boot -> i32;
    def jpy_Py_Finalize -> None;
    def jpy_PyRun_SimpleString(cmd: str) -> i32;
    def jpy_PyImport_AddModule(name: str) -> int;
    def jpy_PyModule_GetDict(module: int) -> int;
    def jpy_PyRun_String(s: str, start: i32, g: int, l: int) -> int;
    def jpy_Py_DecRef(pyobj: int) -> None;
}

# CPython's Py_eval_input start token for jpy_PyRun_String.
glob PY_EVAL: i32 = 258;

# FROZEN text: the agent bridge defined in the embedded __main__.
glob _BOOTSTRAP_PY: str = (
         "from jaclang.cli.ai_tui.embed_agent import "
         "setup as _agent_setup, poll as _agent_poll, "
         "send as _agent_send, stop as _agent_stop\n"
     );

"""Read an env var, mapping unset to ""."""
def _env_or_empty(name: str) -> str {
    v = os.getenv(name);
    return v if v is not None else "";
}

"""Boot embedded CPython + agent, run the TUI loop, tear down in order.

Failure paths unwind exactly what was brought up so far; the teardown
ORDER here is frozen (arch-verified). The early returns cannot fold into
the finally block: na skips finally when the try body returns.
"""
def _run_embed -> None {
    proj_s: str = _env_or_empty("JAC_AI_UI_PROJECT");
    files_s: str = _env_or_empty("JAC_AI_UI_FILES");
    presets_s: str = _env_or_empty("JAC_AI_UI_MODEL_PRESETS");

    engine_rc: i32 = jac_engine_boot();
    if engine_rc != 0 {
        return;
    }

    bootstrap_rc: i32 = jpy_PyRun_SimpleString(_BOOTSTRAP_PY);
    main_mod: int = jpy_PyImport_AddModule("__main__");
    main_dict: int = jpy_PyModule_GetDict(main_mod);
    setup_rc: i32 = 0;
    if bootstrap_rc == 0 {
        setup_rc = jpy_PyRun_SimpleString("_agent_setup()");
    }
    if bootstrap_rc != 0 or setup_rc != 0 {
        jpy_Py_Finalize();
        return;
    }

    rt = TuiRuntime();
    state = rt.state;
    rt.cmd_queue.clear();
    state.ipc_fd = -1;
    tty_fd: int = tty_open();
    if tty_fd < 0 {
        jpy_PyRun_SimpleString("_agent_stop()");
        jpy_Py_Finalize();
        return;
    }
    state.render_fd = tty_fd;
    tui_populate_state(state, proj_s, files_s, presets_s);
    tui_enter_screen(state);

    poll_fn: int = jpy_PyRun_String("_agent_poll", PY_EVAL, main_dict, main_dict);
    send_fn: int = jpy_PyRun_String("_agent_send", PY_EVAL, main_dict, main_dict);
    rt.transport.bind_py(main_dict, poll_fn, send_fn);

    try {
        while tui_loop_once(rt) { }
    } finally {
        # FROZEN order: stop agent -> drop py refs -> restore terminal ->
        # close tty -> finalize the interpreter.
        jpy_PyRun_SimpleString("_agent_stop()");
        rt.transport.close_py();
        tui_leave_screen(state);
        tty_close();
        jpy_Py_Finalize();
    }
}


with entry {
    _run_embed();
}
