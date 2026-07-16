# Main tick — keys via reducer-backed handle_key, then drain + paint.

import from .libc_tty { tty_poll }
import from .runtime { TuiRuntime }
import from .input { handle_key }
import from .keys { parse_key }
import from .tui_core { tui_render_once, tui_sync_size }
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
    should_quit = handle_key(parse_key(raw_key), rt);
    rt.session.flush_outbound_cmds(rt.cmd_queue, rt.state);
    if should_quit {
        rt.state.quit_flag = True;
    }
}

def tui_drain_session(rt: TuiRuntime) -> bool {
    state = rt.state;
    if not rt.session.drain_into(state, _FRAME_DRAIN_CAP) {
        if rt.session.backend_dead {
            state.upsert_event(
                -101, EventKind.ERROR, "agent backend stopped responding", "host"
            );
            state.dirty = True;
            rt.transport.mark_backend_dead();
            return False;
        }
        return False;
    }
    tui_sync_size(state);
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
    # GIL is released by EmbedRuntime after bind; tty wait is plain libc poll.
    rt.embed.run_without_gil();
    tty_poll(50);
    tui_process_keys(rt);
    if not tui_drain_session(rt) {
        rt.state.quit_flag = True;
        tui_render_once(rt);
        return False;
    }
    tui_render_once(rt);
    return not rt.state.quit_flag;
}
