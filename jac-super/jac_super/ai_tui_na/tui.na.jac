"""NA-native TUI binary — pure libc FFI, no custom C.

IPC contract (see ipc.na.jac):
  stdin  <- Python: key:value frames terminated by "---"
  fd 3   -> Python: SEND:, STOP, RESET, QUIT, APPLY: commands  (after fd remap)
  /dev/tty: keyboard in; ANSI rendering on fd 1

Build:
  cd ai_tui_na
  ./build.sh
"""

import sys;
import os;

# The lifecycle logic now lives in tui_core; tui.na.jac only needs TuiState,
# ipc_send_cmd, DiffEngine and the tui_core helpers. But the native cross-module
# type resolver is ORDER-SENSITIVE: it resolves types in the DFS order the ENTRY
# module imports them, and if a leaf type (e.g. select_list.SelectItem, reached
# only via tui_core -> input -> overlay) is first seen too deep it resolves to
# <Unknown> and the build dies with E5090/E2018. Importing the same flat module
# set the pre-refactor entry imported (libc_tty, terminal, state, ipc, screen,
# diff, input) PRIMES the resolver into the proven-good order. These imports are
# otherwise unused here -- do not "clean them up" or the build regresses.
# host.na.jac carries the same priming block for the --shared build.
# Upstream fix tracked in jaseci-labs/jaseci#6793.
import from .libc_tty {
    tty_open,
    tty_close,
    tty_update_size,
    tty_rows,
    tty_cols,
    tty_x_pixels,
    tty_y_pixels,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_write,
    tty_init_stdio_remap,
    tty_restore_stdio,
    tty_ipc_fd
}
import from .terminal {
    term_enter_alt_screen,
    term_leave_alt_screen,
    term_hide_cursor,
    term_show_cursor,
    term_enable_mouse,
    term_disable_mouse
}
import from .state { TuiState }
# select_list primed explicitly so SelectItem is resolvable when overlay.na.jac is
# DFS'd via screen; adding AcItem/AcState to state.na.jac (phase 7) disrupted the
# implicit priming path that previously worked without this line.
import from .select_list { SelectList, SelectItem }
import from .ipc { ipc_read_frame_v2, ipc_send_cmd }
import from .screen { screen_render }
import from .diff { DiffEngine }
import from .input { handle_key }
import from .terminal_image { term_hyperlink, image_rows }
import from .tui_core { tui_setup, tui_loop_once, tui_teardown }

glob args = sys.argv;

# Pure object construction (no libc) is safe in glob init.
glob state: TuiState = TuiState(),
     diff_engine: DiffEngine = DiffEngine();

glob proj = os.getenv("JAC_AI_UI_PROJECT");

# Project file list for the file picker. The control plane computes it and
# passes a newline-separated JAC_AI_UI_FILES env var (see
# run_tui_session.impl.jac `_list_project_files`), so the sidecar needs no
# filesystem FFI -- which also sidesteps the NA `str = calloc(...)` refcount
# double-free that bites any in-binary file read.
glob files_env = os.getenv("JAC_AI_UI_FILES");

# Quick-pick model names for the model picker. The control plane copies
# ai_agent._MODEL_PRESETS into JAC_AI_UI_MODEL_PRESETS (newline-separated).
glob presets_env = os.getenv("JAC_AI_UI_MODEL_PRESETS");

# The lifecycle is kept inside a function (invoked from `with entry`), never in
# glob init: tui_setup() calls tty_open() / tty_init_stdio_remap(), which run
# before the imported libc_tty module's `g_tty` glob is constructed if placed in
# glob init -- a no-TTY run (piped/CI) then NULL-derefs `g_tty.fd_saved` and
# segfaults before any output. setup/loop/teardown live in tui_core.na.jac so the
# Phase-1 in-process host shares the same renderer with no duplication.
def _run {
    proj_s: str = "";
    if proj is not None {
        proj_s = proj;
    }
    files_s: str = "";
    if files_env is not None {
        files_s = files_env;
    }
    presets_s: str = "";
    if presets_env is not None {
        presets_s = presets_env;
    }

    if tui_setup(state, proj_s, files_s, presets_s) < 0 {
        sys.exit(1);
    }

    if len(args) > 1 {
        initial = args[1].strip();
        if len(initial) > 0 {
            ipc_send_cmd(state.ipc_fd, f"SEND:{initial}");
        }
    }

    while tui_loop_once(state, diff_engine) { }

    tui_teardown(state);
}

with entry {
    _run();
}
