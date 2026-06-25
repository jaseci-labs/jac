"""In-process TUI driver.

Mirrors the subprocess backend's two-thread shape (feeder ≈ stream_writer,
ticker ≈ cmd_reader) but both threads call into one in-process `TuiHost` over
ctypes instead of pipes. The render lock serializes every TuiState-touching call
(apply_frame / handle_key / next_command / quit_requested / render); only the
50 ms `wait_key` poll runs lock-free (GIL released). Commands are pulled into a
local list under the lock and dispatched AFTER releasing it, so the render lock
and the agent bus lock are never nested.
"""

import from jaclang.cli.agent_api { AgentRequest }

impl run_tui_in_process(req: AgentRequest) -> int {
    import os;
    import threading;
    import from pathlib { Path }
    import from jaclang.cli.ai_agent { ui_configure, ui_stop, ui_stream }
    import from jaclang.cli.console { console }
    import from jaclang.cli.ai_tui.tui_shared {
        _configure_ui_env,
        _debug_log,
        _dispatch_cmd,
        _frame_blob,
        _require_tty
    }
    import from jaclang.cli.ai_tui.tui_host { TuiHost, _ensure_tui_lib, _tui_lib_path }

    # run_tui_in_process.jac lives in jaclang/cli/ai_tui/; the .so in ai_tui_na/.
    pkg_root = Path(__file__).resolve().parent.parent;

    typed_req: AgentRequest = req;
    r: any = typed_req;

    ensured = _ensure_tui_lib(pkg_root);
    if not ensured.get("ok") {
        console.error(str(ensured.get("error", "failed to build TUI backend")));
        hint = str(ensured.get("hint", ""));
        if hint {
            console.error(hint);
        }
        return 1;
    }

    tty_dev = _require_tty();
    if tty_dev is None {
        return 1;
    }

    # JAC_AI_UI_* env contract + ACTIVE capture gate, set through tui_shared so
    # the subprocess and in-process backends share one copy of the contract. The
    # restore closure unwinds every mutated JAC_AI_UI_* key on every exit path;
    # project/files/presets come back typed (the helper computed them) for host.start below.
    env = _configure_ui_env(r);
    restore_ui = env["restore"];
    project = env["project"] as str;
    files_env = env["files_env"] as str;
    presets_env = env["presets_env"] as str;

    ui_configure();

    host = TuiHost();
    try {
        host.load(_tui_lib_path(pkg_root));
    } except Exception as e {
        _debug_log(f"libtui.so load failed: {e}");
        try {
            ui_stop();
        } except Exception as e {
            _debug_log(f"ui_stop error (on load fail): {e}");
        }
        restore_ui();
        console.error(f"Failed to load in-process TUI library: {e}");
        return 1;
    }

    # Stray-output guard (§12.2): in-process fd 1/2 ARE the controlling tty the
    # native layer puts into raw+alt-screen. Redirect them for the TUI's lifetime
    # so stray prints/tracebacks can't scribble over the render. When
    # JAC_AI_TUI_DEBUG_LOG is set we redirect to that file (captured for post-mortem
    # inspection); otherwise to /dev/null. The native TUI opens its own tty fd
    # (relocated ≥ 10), so this does not touch its output. Restored in `finally`.
    _log_path = os.environ.get("JAC_AI_TUI_DEBUG_LOG", "").strip();
    if _log_path {
        try {
            redirect_fd = os.open(
                _log_path, os.O_WRONLY | os.O_CREAT | os.O_APPEND, 0o644
            );
        } except Exception {
            redirect_fd = os.open(os.devnull, os.O_WRONLY);
        }
    } else {
        redirect_fd = os.open(os.devnull, os.O_WRONLY);
    }
    saved_out = os.dup(1);
    saved_err = os.dup(2);
    os.dup2(redirect_fd, 1);
    os.dup2(redirect_fd, 2);
    os.close(redirect_fd);

    def _restore_fds {
        try {
            os.dup2(saved_out, 1);
            os.close(saved_out);
        } except Exception as e {
            _debug_log(f"restore stdout fd error: {e}");
        }
        try {
            os.dup2(saved_err, 2);
            os.close(saved_err);
        } except Exception as e {
            _debug_log(f"restore stderr fd error: {e}");
        }
    }

    # `start` wraps native tui_init; named `start` because Jac reserves `init` as
    # the obj constructor name.
    rc = host.start(project, files_env, presets_env, tty_dev);
    if rc != 0 {
        _restore_fds();
        try {
            ui_stop();
        } except Exception as e {
            _debug_log(f"ui_stop error (on init fail): {e}");
        }
        restore_ui();
        console.error(f"in-process TUI init failed (tty={tty_dev}, rc={rc})");
        return 1;
    }
    _debug_log(f"in-process TUI init ok tty={tty_dev}");

    stop_evt = threading.Event();
    lock = threading.Lock();

    def _feeder {
        try {
            for frame in ui_stream() {
                if stop_evt.is_set() {
                    break;
                }
                if frame.get("heartbeat") {
                    continue;
                }
                blob = _frame_blob(frame);
                with lock {
                    host.apply_frame(blob);
                }
            }
            _debug_log("feeder: ui_stream ended");
        } except Exception as e {
            _debug_log(f"feeder error: {e}");
        }
    }

    def _ticker {
        try {
            while not stop_evt.is_set() {
                # Lock-free poll: GIL released for ≤50 ms; the feeder keeps running.
                n = host.wait_key(50);
                cmds: list = [];
                quit = False;
                with lock {
                    if n > 0 {
                        host.handle_key();
                        while True {
                            cmd = host.next_command();
                            if not cmd {
                                break;
                            }
                            cmds.append(cmd);
                        }
                    }
                    if host.quit_requested() {
                        quit = True;
                    }
                    host.render();
                }
                # Dispatch OUTSIDE the render lock: _dispatch_cmd -> ui_send takes
                # the agent bus lock, which must never be held under the render lock.
                for cmd in cmds {
                    _dispatch_cmd(cmd, stop_evt, None);
                }
                if quit {
                    stop_evt.set();
                }
            }
            _debug_log("ticker: stop_evt set");
        } except Exception as e {
            _debug_log(f"ticker error: {e}");
            stop_evt.set();
        }
    }

    feeder_thread = threading.Thread(target=_feeder, daemon=True);
    ticker_thread = threading.Thread(target=_ticker, daemon=True);
    feeder_thread.start();
    ticker_thread.start();

    try {
        # The ticker owns quit: it exits when stop_evt is set (QUIT command / quit
        # key via tui_quit_requested). In raw mode Ctrl-C is a keystroke, not
        # SIGINT, so this except is belt-and-suspenders for the pre-raw window.
        ticker_thread.join();
    } except KeyboardInterrupt {
        stop_evt.set();
    } finally {
        stop_evt.set();
        try {
            ui_stop();
        } except Exception as e {
            _debug_log(f"ui_stop error: {e}");
        }
        with lock {
            try {
                host.shutdown();
            } except Exception as e {
                _debug_log(f"shutdown error: {e}");
            }
        }
        _restore_fds();
        restore_ui();
    }

    _debug_log("in-process session exit rc=0");
    return 0;
}
