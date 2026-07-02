import from .libc_tty {
    tty_open,
    tty_open_dev,
    tty_close,
    tty_fd,
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

import from .select_list { SelectList, SelectItem }
import from .ipc {
    ipc_read_frame_v2,
    ipc_send_cmd,
    ipc_parse_frame,
    ipc_next_command,
    ipc_clear_cmd_queue
}
import from .screen { screen_render }
import from .diff { DiffEngine, diff_take_buf }
import from .input { handle_key }
import from .keys { parse_key }
import from .terminal_image { term_hyperlink, image_rows }
import from .tui_core {
    tui_populate_state,
    tui_enter_screen,
    tui_leave_screen,
    tui_render_once,
    _sync_size
}

glob host_state: TuiState = TuiState(),
     host_diff: DiffEngine = DiffEngine();

def:pub tui_init(project: str, files_env: str, presets_env: str, tty_dev: str) -> int {
    ipc_clear_cmd_queue();
    host_state.reset_events();
    host_state.files = [];
    host_state.model_presets = [];
    host_state.quit_flag = False;

    host_state.ipc_fd = -1;

    host_state.status = "idle";
    host_state.active = "";
    host_state.model_name = "";
    host_state.needs_key = False;
    host_state.key_env = "";
    host_state.editor.clear();
    host_state.overlay_active = False;
    host_state.overlay_kind = "palette";
    host_state.overlay_filter = "";
    host_diff.invalidate();

    fd: int = tty_open_dev(tty_dev);
    if fd < 0 {
        return 1;
    }
    tui_populate_state(host_state, project, files_env, presets_env);
    tui_enter_screen(host_state, fd);
    return 0;
}

def:pub tui_apply_frame(blob: str) -> int {
    ok = ipc_parse_frame(host_state, blob);
    if ok {
        return 0;
    }
    return 1;
}

def:pub tui_wait_key(timeout_ms: int) -> int {
    tty_poll(timeout_ms);
    return tty_key_ready();
}

def:pub tui_handle_key -> int {
    raw = tty_read_key();
    if len(raw) == 0 {
        return 0;
    }
    quit = handle_key(parse_key(raw), host_state, host_state.ipc_fd);
    if quit {
        host_state.quit_flag = True;
        return 1;
    }
    return 0;
}

def:pub tui_next_command -> str {
    return ipc_next_command();
}

def:pub tui_quit_requested -> int {
    if host_state.quit_flag {
        return 1;
    }
    return 0;
}

def:pub tui_render -> int {
    fd: int = tty_fd();
    if fd < 0 {
        return 0;
    }

    _sync_size(host_state);
    if tui_render_once(host_state, host_diff, fd) {
        return 1;
    }
    return 0;
}

def:pub tui_render_buf -> str {
    host_diff.invalidate();
    host_state.dirty = True;
    tui_render_once(host_state, host_diff, -1);
    return diff_take_buf();
}

def:pub tui_shutdown -> int {
    fd: int = tty_fd();
    if fd >= 0 {
        tui_leave_screen(host_state, fd);
    }
    tty_close();
    return 0;
}
