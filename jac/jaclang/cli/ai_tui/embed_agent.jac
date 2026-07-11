import os;
import sys;
import from queue { Queue, Empty }
import from threading { Event, Thread }

glob _q: Queue[str] = Queue(),
     _stop: Event = Event(),
     _stub: bool = False;


def _apply_path_env {
    byllm = os.environ.get("JAC_AI_TUI_BYLLM_SRC", "");
    if byllm and byllm not in sys.path {
        sys.path.insert(0, byllm);
    }
    for d in os.environ.get("JAC_AI_TUI_DEPS", "").split(os.pathsep) {
        if d and d not in sys.path {
            sys.path.append(d);
        }
    }
}


def _start_real {
    import from jaclang.cli.ai_agent { ui_configure }
    import from jaclang.cli.ai_tui.tui_shared { _debug_log }

    _debug_log("_start_real: calling ui_configure");
    ui_configure();

    import from jaclang.cli.ai_agent { agent as _agent_rt, agent_model as _am }
    _debug_log(
        f"_start_real: ui_configure done; bus.model_name={_agent_rt.bus.model_name!r} agent_model={_am.model_name!r}"
    );

    def _feed {
        import from jaclang.cli.ai_agent { ui_stream }
        import from jaclang.cli.ai_tui.tui_shared { _frame_blob, _debug_log }
        try {
            for frame in ui_stream() {
                if _stop.is_set() {
                    break;
                }
                if frame.get("heartbeat") {
                    continue;
                }
                _debug_log(
                    f"_feed: queueing frame model_name={frame.get(
                        'model_name', '<missing>'
                    )!r} full={frame.get('full', False)}"
                );
                _q.put(_frame_blob(frame));
            }
        } except Exception as e {
            _debug_log(f"_feed crashed: {e}");
            _q.put(
                _frame_blob(
                    {
                        "status": "idle",
                        "ev": {
                            "id": -100,
                            "kind": "error",
                            "node": "feed",
                            "text": "agent feed stopped: " + repr(e),

                        },

                    }
                )
            );
        }
    }

    Thread(target=_feed, daemon=True).start();
}


def _start_stub(reason: str = "") {
    import time;
    import from jaclang.cli.ai_tui.tui_shared { _frame_blob }

    global _stub;
    _stub = True;
    if reason {
        sys.stderr.write(f"jac-ai-tui: using stub agent ({reason})\n");
        sys.stderr.write(
            "  set JAC_AI_TUI_BYLLM_SRC=<jac-byllm checkout> and "
            "JAC_AI_TUI_DEPS=<dep dirs (litellm, openai, ...)> for the real agent.\n"
        );
    }

    def _feed {
        import from jaclang.cli.ai_tui.tui_shared { _frame_blob }
        _q.put(
            _frame_blob(
                {
                    "full": True,
                    "status": "idle",
                    "model_name": "stub",
                    "events": [
                        {
                            "id": 1,
                            "kind": "system",
                            "node": "stub",
                            "text": "embed host booted (stub agent)"
                        }
                    ],

                }
            )
        );
        n = 0;
        while not _stop.is_set() {
            n += 1;
            _q.put(
                _frame_blob(
                    {
                        "ev": {
                            "id": 1,
                            "kind": "system",
                            "node": "stub",
                            "text": "tick " + str(n)
                        }
                    }
                )
            );
            time.sleep(1.0);
        }
    }

    Thread(target=_feed, daemon=True).start();
}


def setup {
    _apply_path_env();
    import os as _os;
    import from jaclang.cli.ai_tui.tui_shared { _debug_log, _silence_logging_for_tui }
    _silence_logging_for_tui();
    _debug_log(
        f"setup: JAC_AI_UI_MODEL={_os.environ.get('JAC_AI_UI_MODEL', '<unset>')!r}"
    );
    _debug_log(
        f"setup: JAC_AI_TUI_BYLLM_SRC={_os.environ.get(
            'JAC_AI_TUI_BYLLM_SRC', '<unset>'
        )!r}"
    );
    try {
        _start_real();
        _debug_log("setup: _start_real succeeded");
    } except Exception as e {
        import from jaclang.cli.ai_tui.tui_shared { _frame_blob, _debug_log }
        _debug_log(f"_start_real failed: {e}");
        err_text = (
            "agent boot failed — check JAC_AI_TUI_BYLLM_SRC / JAC_AI_TUI_DEPS.\n" + repr(
                e
            )
        );
        _q.put(
            _frame_blob(
                {
                    "full": True,
                    "status": "idle",
                    "model_name": "error",
                    "events": [
                        {"id": 1, "kind": "error", "node": "boot", "text": err_text}
                    ],

                }
            )
        );
        if os.environ.get("JAC_AI_TUI_NO_STUB") {
            raise;
        }
        _start_stub("");
    }
}


glob _poll_count: int = 0;

def poll -> str {
    global _poll_count;
    _poll_count += 1;
    import from jaclang.cli.ai_tui.tui_shared { _debug_log }

    parts = [];
    while True {
        try {
            parts.append(_q.get_nowait());
        } except Empty {
            break;
        }
    }
    if not parts {
        return "";
    }
    if _poll_count <= 5 or _poll_count % 100 == 0 {
        _debug_log(
            f"poll called #{_poll_count} batched={len(parts)} qsize={_q.qsize()}"
        );
    }
    return "\n".join(parts);
}


def send(line: str) {
    if _stub {
        import from jaclang.cli.ai_tui.tui_shared { _frame_blob }
        _q.put(
            _frame_blob(
                {
                    "ev": {
                        "id": 2,
                        "kind": "user",
                        "node": "stub",
                        "text": "sent " + line
                    }
                }
            )
        );
        return;
    }
    import from jaclang.cli.ai_tui.tui_shared { _dispatch_cmd }
    _dispatch_cmd(line, _stop, None);
}


def stop {
    _stop.set();
    try {
        import from jaclang.cli.ai_agent { ui_stop }
        ui_stop();
    } except Exception as e {
        import from jaclang.cli.ai_tui.tui_shared { _debug_log }
        _debug_log(f"stop: ui_stop failed: {e}");
    }
}
