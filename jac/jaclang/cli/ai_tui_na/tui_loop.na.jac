import from .ipc { ipc_parse_frame }
import from .input { handle_key }
import from .keys { parse_key }
import from .tui_core { tui_render_once, tui_sync_size }
import from .runtime { TuiRuntime }

glob _FRAME_DRAIN_CAP: int = 64;

def tui_process_keys(rt: TuiRuntime) {
    if not rt.transport.key_ready() {
        return;
    }
    raw_key = rt.transport.read_key();
    if not raw_key {
        return;
    }
    if handle_key(parse_key(raw_key), rt) {
        rt.state.quit_flag = True;
    }
    rt.transport.flush_outbound_cmds(rt.cmd_queue);
}

def tui_drain_blobs(rt: TuiRuntime) -> bool {
    state = rt.state;
    for _ in range(_FRAME_DRAIN_CAP) {
        blob: str = rt.transport.recv_blob();
        if rt.transport.stdin_eof() {
            return False;
        }
        if not blob {
            break;
        }
        if not ipc_parse_frame(state, blob) {
            return False;
        }
        tui_sync_size(state);
    }
    return True;
}

def tui_loop_once(rt: TuiRuntime) -> bool {
    rt.transport.poll_gil(50);
    tui_process_keys(rt);
    if not tui_drain_blobs(rt) {
        rt.state.quit_flag = True;
        return False;
    }
    tui_render_once(rt);
    return not rt.state.quit_flag;
}
