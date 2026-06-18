"""NA-native TUI binary — pure libc, no OpenTUI, no custom C.

IPC contract (see ipc.na.jac):
  stdin  <- Python: key:value frames terminated by "---"
  fd 3   -> Python: SEND:, STOP, RESET, QUIT, APPLY: commands  (after fd remap)
  /dev/tty: keyboard in; ANSI rendering on fd 1

Build:
  cd jac-super/jac_super/ai_tui_na
  ./build.sh
"""

import sys;
import os;

import from .libc_tty {
    tty_open,
    tty_close,
    tty_update_size,
    tty_rows,
    tty_cols,
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
    term_show_cursor
}
import from .state { TuiState }
import from .ipc { ipc_read_frame_v2, ipc_send_cmd }
import from .screen { screen_render }
import from .diff { DiffEngine }
import from .input { handle_key }

def _sync_size(state: TuiState) {
    tty_update_size();
    new_rows: int = tty_rows();
    new_cols: int = tty_cols();
    state.term_rows = new_rows;
    if new_cols != state.term_cols {
        state.layout_dirty = True;
    }
    state.term_cols = new_cols;
}

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

# tty handles are created here (never in glob init): calling tty_open() /
# tty_init_stdio_remap() during the glob-init phase runs before the imported
# libc_tty module's `g_tty` glob is constructed, so a no-TTY run (piped/CI)
# NULL-derefs `g_tty.fd_saved` and segfaults before any output. Keeping the whole
# flow in a function (invoked from `with entry`) also keeps raw_fd / ipc_fd as
# locals: as module globs they collide on the native linker (E5026), and the jac
# formatter would otherwise hoist `with entry` locals into module globs.
def _run {
    tty_write(2, "[tui] starting\r\n");

    raw_fd: int = tty_open();

    if raw_fd < 0 {
        tty_write(
            2, "[tui] tty open failed (set JAC_AI_TUI_TTY or run from a terminal)\r\n"
        );
        sys.exit(1);
    }
    tty_write(2, "[tui] tty_open ok\r\n");

    if tty_init_stdio_remap() < 0 {
        tty_write(2, "[tui] stdio remap failed\r\n");
        tty_close();
        sys.exit(1);
    }

    ipc_fd: int = tty_ipc_fd();

    state.cwd = os.getcwd();
    if proj is not None {
        if len(proj) > 0 {
            state.cwd = proj;
        }
    }

    if files_env is not None {
        for raw_path in files_env.split("\n") {
            p = raw_path.strip();
            if len(p) > 0 {
                state.files.append(p);
            }
        }
    }

    if presets_env is not None {
        for raw_name in presets_env.split("\n") {
            name = raw_name.strip();
            if len(name) > 0 {
                state.model_presets.append(name);
            }
        }
    }

    term_enter_alt_screen(1);
    term_hide_cursor(1);

    _sync_size(state);
    state.dirty = True;

    if len(args) > 1 {
        initial = args[1].strip();
        if len(initial) > 0 {
            ipc_send_cmd(ipc_fd, f"SEND:{initial}");
        }
    }

    while not state.quit_flag {
        tty_poll(50);

        # Handle keyboard before IPC frames so a steady ui_stream() delta feed
        # cannot starve prompt editing.
        if tty_key_ready() > 0 {
            k = tty_read_key();
            if len(k) > 0 {
                should_quit = handle_key(k, state, ipc_fd);
                if should_quit {
                    state.quit_flag = True;
                }
            }
        }

        if tty_stdin_ready() > 0 {
            ok = ipc_read_frame_v2(state);
            if not ok {
                state.quit_flag = True;
                break;
            }
            _sync_size(state);
            state.dirty = True;
        }

        if state.dirty {
            if state.overlay_full_redraw {
                diff_engine.invalidate();
                state.overlay_full_redraw = False;
            }
            lines = screen_render(state, state.term_cols, state.term_rows);
            diff_engine.paint(lines, state.term_cols, 1);
            state.dirty = False;
        }
    }

    term_show_cursor(1);
    term_leave_alt_screen(1);
    tty_restore_stdio();
    tty_close();
}

with entry {
    _run();
}
