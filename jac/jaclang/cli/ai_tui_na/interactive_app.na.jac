# InteractiveApp — agent-aware tick: keys → reduce → drain → effects → paint.

import from .libc_tty { tty_poll }
import from .tui { Tui }
import from .keys { parse_key, Key }
import from .input_types {
    UiAction,
    UiActionKind,
    Effect,
    EffectKind,
    FocusTarget
}
import from .reducer { reduce_input, reduce_session }
import from .embed_session_client { EmbedSessionClient }
import from .embed_runtime { EmbedRuntime }
import from .transport { EmbedPyTransport, CmdQueue }
import from .state { EventKind, TuiState }
import from .ipc_schema { CMD_SEND, CMD_STOP, CMD_RESET, CMD_QUIT, CMD_APPLY }

glob _FRAME_DRAIN_CAP: int = 64;

obj LoopResult {
    has cont: bool = True,
        painted: bool = False;
}

obj InteractiveApp {
    has tui: Tui = Tui(),
        session: EmbedSessionClient = EmbedSessionClient(),
        embed: EmbedRuntime = EmbedRuntime(),
        transport: EmbedPyTransport = EmbedPyTransport(),
        cmd_queue: CmdQueue = CmdQueue(),
        poll_profile: bool = False,
        poll_calls: int = 0,
        poll_muts: int = 0,
        poll_snaps: int = 0;

    def bind_host(
        embed: EmbedRuntime,
        session: EmbedSessionClient,
        transport: EmbedPyTransport,
        cmd_queue: CmdQueue,
        state: TuiState
    ) {
        self.embed = embed;
        self.session = session;
        self.transport = transport;
        self.cmd_queue = cmd_queue;
        self.tui.bind_state(state);
    }

    def run -> int {
        while self.step(50).cont { }
        return 0;
    }

    def _execute_effects(effects: list[Effect]) {
        state = self.tui.state;
        for e in effects {
            if e.kind == EffectKind.QUIT {
                self.cmd_queue.send(state.ipc_fd, CMD_QUIT);
                state.quit_flag = True;
            } elif e.kind == EffectKind.STOP {
                self.cmd_queue.send(state.ipc_fd, CMD_STOP);
            } elif e.kind == EffectKind.RESET {
                self.cmd_queue.send(state.ipc_fd, CMD_RESET);
            } elif e.kind == EffectKind.SEND_PROMPT {
                self.cmd_queue.send(state.ipc_fd, CMD_SEND + ":" + e.payload);
            } elif e.kind == EffectKind.APPLY_SETTINGS {
                self.cmd_queue.send(state.ipc_fd, CMD_APPLY + ":" + e.payload);
            } elif e.kind == EffectKind.REQUEST_RENDER {
                self.tui.request_render(False);
            }
        }
    }

    def inject_key(k: Key) -> bool {
        action = UiAction(kind=UiActionKind.KEY, key=k);
        res = reduce_input(self.tui.state, action);
        self._execute_effects(res.effects);
        self.session.flush_outbound_cmds(self.cmd_queue, self.tui.state);
        if res.quit {
            self.tui.state.quit_flag = True;
        }
        return res.quit;
    }

    def set_focus(target: FocusTarget) {
        action = UiAction(kind=UiActionKind.SET_FOCUS, focus=target);
        reduce_input(self.tui.state, action);
    }

    def _process_keys {
        if not self.transport.key_ready() {
            return;
        }
        raw_key = self.transport.read_key();
        if not raw_key {
            return;
        }
        self.inject_key(parse_key(raw_key));
    }

    def _drain_session -> bool {
        state = self.tui.state;
        if self.poll_profile {
            self.poll_calls += 1;
        }
        if not self.session.drain_into(state, _FRAME_DRAIN_CAP) {
            if self.session.backend_dead {
                state.upsert_event(
                    -101, EventKind.ERROR, "agent backend stopped responding", "host"
                );
                state.dirty = True;
                self.transport.mark_backend_dead();
                return False;
            }
            return False;
        }
        self.tui.sync_size();
        if self.transport.stdin_eof() {
            return False;
        }
        if self.transport.backend_dead() {
            state.upsert_event(
                -101, EventKind.ERROR, "agent backend stopped responding", "host"
            );
            state.dirty = True;
            return False;
        }
        reduce_session(state, state.dirty);
        return True;
    }

    def step(timeout_ms: int) -> LoopResult {
        self.embed.run_without_gil();
        tty_poll(timeout_ms);
        self._process_keys();
        if not self._drain_session() {
            self.tui.state.quit_flag = True;
            painted = self.tui.paint_once();
            return LoopResult(cont=False, painted=painted);
        }
        painted = self.tui.paint_once();
        return LoopResult(cont=not self.tui.state.quit_flag, painted=painted);
    }

    def shutdown {
        self.tui.stop();
    }
}
