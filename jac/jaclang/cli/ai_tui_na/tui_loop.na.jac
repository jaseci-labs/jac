import from .ipc { ipc_parse_frame }
import from .input { handle_key }
import from .keys { parse_key }
import from .tui_core { tui_render_once, tui_sync_size }
import from .runtime { TuiRuntime }
import from .state { EventKind }

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
    frames = rt.transport.recv_frames(_FRAME_DRAIN_CAP);
    for blob in frames {
        if not ipc_parse_frame(state, blob) {
            return False;
        }
    }
    if frames {
        tui_sync_size(state);
    }
    if rt.transport.stdin_eof() {
        return False;
    }
    if rt.transport.backend_dead() {
        state.upsert_event(
            -101, EventKind.ERROR, "agent backend stopped responding", "host"
        );
        state.dirty = True;
        return False;
    }
    return True;
}

def tui_loop_once(rt: TuiRuntime) -> bool {
    rt.transport.poll_gil(50);
    tui_process_keys(rt);
    if not tui_drain_blobs(rt) {
        rt.state.quit_flag = True;
        tui_render_once(rt);
        return False;
    }
    tui_render_once(rt);
    return not rt.state.quit_flag;
}
