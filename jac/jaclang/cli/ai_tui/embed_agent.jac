import os;
import sys;
import from queue { Queue, Empty }
import from threading { Event, Thread }

glob _q: Queue = Queue(),
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

    ui_configure();

    def _feed {
        import from jaclang.cli.ai_agent { ui_stream }
        import from jaclang.cli.ai_tui.tui_shared { _frame_blob }
        try {
            for frame in ui_stream() {
                if _stop.is_set() {
                    break;
                }
                if frame.get("heartbeat") {
                    continue;
                }
                _q.put(_frame_blob(frame));
            }
        } except Exception { }
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
    try {
        _start_real();
    } except Exception as e {
        _start_stub(repr(e));
    }
}


def poll -> str {
    try {
        return _q.get_nowait();
    } except Empty {
        return "";
    }
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
    } except Exception { }
}
