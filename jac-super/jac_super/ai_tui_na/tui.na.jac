"""NA-native TUI binary for `jac ai --tui`.

IPC contract (see ipc.na.jac):
  stdin  <- Python: key:value frames terminated by "---"
  fd 3   -> Python: SEND:, STOP, RESET, QUIT, APPLY: commands  (after fd remap)
  /dev/tty: keyboard in; ANSI rendering via OpenTUI on fd 1

Build:
  cd jac-super/jac_super/ai_tui_na
  ./build.sh
"""

import sys;
import os;

import from .tui_helpers {
    def tui_open -> i32;  def tui_close(fd: i32) -> None;  def tui_poll(
        tty_fd: i32, timeout_ms: i32
    ) -> None;  def tui_stdin_ready -> i32;  def tui_key_ready -> i32;  def tui_read_key(
        fd: i32
    ) -> str;  def tui_write(fd: i32, s: str) -> None;
}

import from .opentui_helpers {
    def otui_init -> i32;  def otui_close -> None;  def otui_ipc_fd -> i32;  def otui_update_size -> None;  def otui_rows -> i32;  def otui_cols -> i32;
}

import from .state { TuiState }
import from .ipc { ipc_read_frame_v2, ipc_send_cmd }
import from .render { render_full }
import from .input { handle_key }

def _sync_size(state: TuiState) {
    otui_update_size();
    state.term_rows = otui_rows();
    # Typed as int so the i32 from otui_cols coerces to the i64 field width
    # before the comparison below (avoids an i32/i64 IR type mismatch).
    new_cols: int = otui_cols();
    # A width change invalidates the wrapped row cache; height does not (only the
    # number of rows shown changes, which render derives each frame).
    if new_cols != state.term_cols {
        state.layout_dirty = True;
    }
    state.term_cols = new_cols;
}

glob args = sys.argv;

with entry {
    tui_write(2, "[tui] starting\r\n");
}

# Open /dev/tty for keyboard I/O before the fd remap so raw mode is set
# on the controlling terminal before OpenTUI touches it.
glob raw_fd = tui_open();

with entry {
    if raw_fd < 0 {
        tui_write(2, "[tui] tui_open failed\r\n");
        sys.exit(1);
    }

    tui_write(2, "[tui] tui_open ok\r\n");
}

# Remap fds, load libopentui.so, create renderer, enter alt screen.
glob rc = otui_init();

with entry {
    if rc < 0 {
        tui_write(2, "[tui] otui_init failed\r\n");
        tui_close(raw_fd);
        sys.exit(1);
    }

    tui_write(2, "[tui] otui_init ok\r\n");
}

# After otui_init(): fd 1 = terminal, fd 3 = IPC out pipe.
glob ipc_fd: i32 = otui_ipc_fd(),
     state = TuiState();

with entry {
    state.cwd = os.getcwd();
}

glob proj = os.getenv("JAC_AI_UI_PROJECT");

with entry {
    if proj is not None {
        if len(proj) > 0 {
            state.cwd = proj;
        }
    }

    _sync_size(state);
    state.dirty = True;

    if len(args) > 1 {
        initial = args[1].strip();
        if len(initial) > 0 {
            ipc_send_cmd(ipc_fd, f"SEND:{initial}");
        }
    }

    while not state.quit_flag {
        tui_poll(raw_fd, 50);

        has_stdin = tui_stdin_ready();
        if has_stdin > 0 {
            ok = ipc_read_frame_v2(state);
            if not ok {
                state.quit_flag = True;
                break;
            }
            _sync_size(state);
            state.dirty = True;
        }

        has_key = tui_key_ready();
        if has_key > 0 {
            k = tui_read_key(raw_fd);
            if len(k) > 0 {
                should_quit = handle_key(k, state, ipc_fd);
                if should_quit {
                    state.quit_flag = True;
                }
            }
        }

        if state.dirty {
            render_full(state);
            state.dirty = False;
        }
    }

    otui_close();
    tui_close(raw_fd);
}
