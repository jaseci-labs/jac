import os;

import from .libc_tty { tty_open, tty_close }
import from .tui_loop { tui_loop_once }
import from .tui_core { tui_populate_state, tui_enter_screen, tui_leave_screen }
import from .runtime { TuiRuntime }
import from .embed_models { AgentRequest }
import from .embed_runtime { EmbedRuntime }
import from .embed_session_client { EmbedSessionClient }

# Phase 4: CPython imports live only in embed_runtime.na.jac.
# Phase 5: input goes through reducer; InteractiveApp available for injected-key tests.


def _env_or_empty(name: str) -> str {
    v = os.getenv(name);
    return v if v is not None else "";
}

def _bind_runtime(rt: TuiRuntime, embed: EmbedRuntime, session: EmbedSessionClient) {
    rt.embed = embed;
    rt.session = session;
}

def _run_embed -> None {
    proj_s: str = _env_or_empty("JAC_AI_UI_PROJECT");
    files_s: str = _env_or_empty("JAC_AI_UI_FILES");
    presets_s: str = _env_or_empty("JAC_AI_UI_MODEL_PRESETS");

    embed = EmbedRuntime();
    boot = embed.boot();
    if not boot.ok {
        return;
    }

    bind = embed.bind();
    if not bind.ok {
        embed.force_finalize_unsafe();
        return;
    }

    session = EmbedSessionClient(runtime=embed);
    start = session.start(
        AgentRequest(
            cwd=_env_or_empty("PWD"),
            stub=False,
            model_name=_env_or_empty("JAC_AI_UI_MODEL")
        )
    );
    if not start.ok {
        # start() is a side-effecting transaction. If the managed call executed
        # and then failed (decode error or ok=false), session.start() has already
        # performed bounded dispose and set worker safety from runtime-confirmed
        # quiescence. When the managed call never executed, workers_safe stays
        # False. Either way: do NOT override with an unconditional
        # mark_workers_safe(True) — that finalized over a live _legacy_feed
        # thread (the Phase 4 hang). Gate finalization on quiescence, not start.ok.
        embed.finalize_if_safe();
        return;
    }

    rt = TuiRuntime();
    _bind_runtime(rt, embed, session);
    state = rt.state;
    rt.cmd_queue.clear();
    state.ipc_fd = -1;
    tty_fd: int = tty_open();
    if tty_fd < 0 {
        disp = session.dispose(reason="tty_open_failed", deadline_ms=1000);
        embed.mark_workers_safe(not disp.timed_out);
        embed.finalize_if_safe();
        return;
    }
    state.render_fd = tty_fd;
    tui_populate_state(state, proj_s, files_s, presets_s);
    tui_enter_screen(state);

    try {
        while tui_loop_once(rt) { }
    } finally {
        tui_leave_screen(state);
        tty_close();
        disp2 = session.dispose(reason="quit", deadline_ms=2000);
        embed.mark_workers_safe(not disp2.timed_out);
        embed.finalize_if_safe();
    }
}


with entry {
    _run_embed();
}
