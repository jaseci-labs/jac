import from .state { TuiState }
import from .diff { DiffEngine }
import from .ipc { ipc_parse_frame }
import from .input { handle_key }
import from .keys { parse_key }
import from .transport { Transport }
import from .tui_core { tui_render_once, _sync_size }

def tui_process_keys(state: TuiState, transport: Transport) {
    if transport.key_ready() <= 0 {
        return;
    }
    k = transport.read_key();
    if len(k) == 0 {
        return;
    }
    should_quit = handle_key(parse_key(k), state, state.ipc_fd);
    if should_quit {
        state.quit_flag = True;
    }
    transport.flush_outbound_cmds();
}

def tui_drain_blobs(state: TuiState, transport: Transport) -> bool {
    frames_drained: int = 0;
    while frames_drained < 64 {
        blob: str = transport.recv_blob();
        if transport.stdin_eof() {
            return False;
        }
        if len(blob) == 0 {
            break;
        }
        if not ipc_parse_frame(state, blob) {
            return False;
        }
        _sync_size(state);
        frames_drained = frames_drained + 1;
    }
    return True;
}

def tui_loop_once(
    state: TuiState, diff_engine: DiffEngine, transport: Transport, render_fd: int
) -> bool {
    transport.poll(50);
    tui_process_keys(state, transport);
    if not tui_drain_blobs(state, transport) {
        state.quit_flag = True;
        return False;
    }
    tui_render_once(state, diff_engine, render_fd);
    return not state.quit_flag;
}
