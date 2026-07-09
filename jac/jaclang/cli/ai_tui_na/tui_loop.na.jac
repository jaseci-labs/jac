"""One tick of the embed TUI event loop: keys, agent frames, render.

host_embed drives tui_loop_once until it returns False (quit or EOF).
"""

import from .ipc { ipc_parse_frame }
import from .input { handle_key }
import from .keys { parse_key }
import from .tui_core { tui_render_once, tui_sync_size }
import from .runtime { TuiRuntime }

# Max agent frames applied per tick, so a chatty agent cannot starve key
# handling and rendering.
glob _FRAME_DRAIN_CAP: int = 64;

"""Read at most one pending key, dispatch it, and flush queued commands."""
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

"""Apply pending agent frames; return False when the host must quit.

Per frame: transport EOF -> quit (False), empty blob -> nothing buffered
(stop for this tick), unparseable frame -> quit (False). Terminal size is
re-synced after every applied frame so redraws see fresh dimensions.
"""
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

"""Run one poll/keys/frames/render tick; return False when the TUI exits."""
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
