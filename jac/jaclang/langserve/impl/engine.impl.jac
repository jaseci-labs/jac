"""Engine implementation — main process scheduler.

Manages the worker process, implements priority-based scheduling,
debouncing, and cancel-and-request flow for FG preemption.
"""

import from jaclang.cli.console { console }

# ── Lifecycle ─────────────────────────────────────────────────────────

"""Initialize the language server and spawn the worker process."""
impl JacLangServer.postinit -> None {
    LanguageServer.init(self, 'jac-lsp', 'v0.1');

    # Create IPC pipe and shared cancel event.
    (main_conn, worker_conn) = Pipe();
    cancel_event = MPEvent();

    self.main_conn = main_conn;
    self.cancel_event = cancel_event;

    # Spawn worker process.
    self.worker_process = Process(
        target=worker_main,
        args=(worker_conn, cancel_event),
        daemon=True
    );
    self.worker_process.start();
    self.debug("Worker process spawned (pid=" + str(self.worker_process.pid) + ")");
}

"""Shutdown the server and worker process."""
impl JacLangServer.shutdown -> None {
    if self._shutdown_called {
        return;
    }
    self._shutdown_called = True;
    try {
        if self.debounce_handle {
            self.debounce_handle.cancel();
            self.debounce_handle = None;
        }
        # Send shutdown to worker.
        if self.main_conn {
            try {
                self.main_conn.send(make_shutdown_request());
            } except (EOFError, OSError, BrokenPipeError) {
                ;
            }
        }
        # Wait for worker to exit.
        if self.worker_process and self.worker_process.is_alive() {
            self.worker_process.join(timeout=5);
            if self.worker_process.is_alive() {
                self.debug("Worker did not exit in time, terminating.");
                self.worker_process.terminate();
                self.worker_process.join(timeout=2);
            }
        }
        # Close pipe.
        if self.main_conn {
            try {
                self.main_conn.close();
            } except Exception {
                ;
            }
        }
    } finally {
        super.shutdown();
    }
}

# ── Debug / Logging ───────────────────────────────────────────────────

impl JacLangServer.debug(msg: str) -> None {
    print(f"[Engine] {msg}", file=sys.stderr);
}

impl JacLangServer.log_py(message: str) -> None {
    print(f"[Engine] {message}", file=sys.stderr);
}

impl JacLangServer.log_info(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Info);
    self.show_message(message, lspt.MessageType.Info);
}

impl JacLangServer.log_warning(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Warning);
    self.show_message(message, lspt.MessageType.Warning);
}

impl JacLangServer.log_error(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Error);
    self.show_message(message, lspt.MessageType.Error);
}

# ── Low-level IPC ─────────────────────────────────────────────────────

"""Send a request to the worker and wait for the response (blocking)."""
impl JacLangServer._send_and_recv(request: dict) -> dict {
    try {
        self.main_conn.send(request);
        return self.main_conn.recv();
    } except (EOFError, OSError, BrokenPipeError) as e {
        self.debug(f"Pipe error: {e}");
        return {"type": "error", "message": str(e)};
    }
}

"""Cancel the current worker operation and return its response."""
impl JacLangServer._cancel_current -> dict | None {
    if self.worker_state == WORKER_STATE_IDLE {
        return None;
    }
    import time;
    self.debug(f"Cancelling current worker operation..{time.time()}.");

    # Remove any non-blocking reader first so the callback doesn't fire.
    try {
        loop = asyncio.get_running_loop();
        loop.remove_reader(self.main_conn.fileno());
    } except (RuntimeError, Exception) { ; }

    self.cancel_event.set();
    # Wait for the worker to acknowledge (either CANCELLED or completed result).
    try {
        self.debug(f"Waiting for cancel acknowledgement...{time.time()}");
        resp = self.main_conn.recv(); # blocking IPC call
        self.debug(f"Cancel acknowledged: {resp.get('type', 'unknown')} {time.time()}");
    } except (EOFError, OSError) as e {
        self.debug(f"Pipe error during cancel: {e}");
        resp = {"type": "error", "message": str(e)};
    }
    self.worker_state = WORKER_STATE_IDLE;
    self.compiling_file = None;
    return resp;
}

# ── Priority scheduling ──────────────────────────────────────────────

"""Schedule a compilation for a file (called by did_change/did_save/did_open).

Implements debouncing and priority logic:
- P2: Re-edit same file being compiled → cancel, debounce, recompile
- P3: Other dirty files → wait for current, then compile
"""
impl JacLangServer.schedule_compile(file_uri: str) -> None {
    fs_path = uris.to_fs_path(file_uri);
    self.dirty_files[file_uri] = fs_path;

    # Cancel any pending debounce timer.
    if self.debounce_handle {
        self.debounce_handle.cancel();
        self.debounce_handle = None;
    }

    # P2: If compiling, signal the worker to cancel (non-blocking).
    # Don't call _cancel_current() here — it blocks on recv().
    # Instead, just set the event. The _on_compile_response callback will
    # handle the cancelled response and _schedule_next_dirty picks up
    # the dirty file for recompile.
    if self.worker_state == WORKER_STATE_COMPILING {
        self.cancel_event.set();
    }

    # Debounce: delay compilation to batch rapid edits.
    # In production (running asyncio loop), use call_later.
    # In test/sync mode, fire immediately.
    try {
        loop = asyncio.get_running_loop();
        uri = file_uri;
        self.debounce_handle = loop.call_later(
            DEBOUNCE_DELAY,
            lambda: self._fire_compile(uri)
        );
    } except RuntimeError {
        # No running event loop (test mode or sync context) — fire immediately.
        self._fire_compile(file_uri);
    }
}


"""Actually fire the compilation after debounce."""
impl JacLangServer._fire_compile(file_uri: str) -> None {
    self.debounce_handle = None;
    # If worker is busy (compiling another file), just leave in dirty set (P3).
    if self.worker_state != WORKER_STATE_IDLE {
        return;
    }
    # Remove from dirty set and start compilation.
    fs_path = self.dirty_files.pop(file_uri, None);
    if not fs_path {
        return;
    }
    try {
        document = self.workspace.get_text_document(file_uri);
        source = document.source;
    } except Exception as e {
        self.debug(f"Could not get document for {file_uri}: {e}");
        return;
    }

    self.worker_state = WORKER_STATE_COMPILING;
    self.compiling_file = file_uri;

    req = make_compile_request(fs_path, source);
    try {
        self.main_conn.send(req);
    } except (EOFError, OSError, BrokenPipeError) as e {
        self.debug(f"Pipe error sending compile request: {e}");
        self.worker_state = WORKER_STATE_IDLE;
        self.compiling_file = None;
        return;
    }

    # Wait for compile response.
    # In production (asyncio loop running), use non-blocking add_reader
    # so the event loop stays free to handle did_change / FG requests.
    # In test/sync mode (no loop), block on recv.
    try {
        loop = asyncio.get_running_loop();
        uri = file_uri;
        loop.add_reader(
            self.main_conn.fileno(),
            lambda: self._on_compile_response(uri)
        );
    } except RuntimeError {
        # No running event loop — block.
        try {
            resp = self.main_conn.recv();
            self._handle_compile_response(resp, file_uri);
        } except (EOFError, OSError) as e {
            self.debug(f"Pipe error receiving compile response: {e}");
            self.worker_state = WORKER_STATE_IDLE;
            self.compiling_file = None;
        }
    }
}

"""Callback when compile response arrives on the pipe (non-blocking mode)."""
impl JacLangServer._on_compile_response(file_uri: str) -> None {
    # Remove the reader first — add_reader fires on every readable event.
    try {
        loop = asyncio.get_running_loop();
        loop.remove_reader(self.main_conn.fileno());
    } except Exception { ; }

    try {
        resp = self.main_conn.recv();
        self._handle_compile_response(resp, file_uri);
    } except (EOFError, OSError) as e {
        self.debug(f"Pipe error receiving compile response: {e}");
        self.worker_state = WORKER_STATE_IDLE;
        self.compiling_file = None;
    }
}

"""Handle a compile response from the worker."""
impl JacLangServer._handle_compile_response(resp: dict, file_uri: str) -> None {
    self.worker_state = WORKER_STATE_IDLE;
    self.compiling_file = None;

    if resp.get("type") == "cancelled" {
        self.debug(f"Compilation of {file_uri} was cancelled.");
        return;
    }

    if resp.get("type") == "compile_result" {
        # Publish diagnostics for each URI in the response.
        diagnostics_map = parse_diagnostics_response(resp);
        for (uri, diags) in diagnostics_map.items() {
            self._last_diagnostics[uri] = diags;
            self.publish_diagnostics(uri, diags);
        }
        # Request semantic tokens refresh.
        try {
            self.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
        } except Exception as e {
            self.debug(f"Error refreshing semantic tokens: {e}");
        }
        self.debug(f"Compilation complete for {file_uri}");
    }

    # P3: Check if there are more dirty files to compile.
    self._schedule_next_dirty();
}

"""Pick the next dirty file and schedule compilation (P3)."""
impl JacLangServer._schedule_next_dirty -> None {
    if self.dirty_files and self.worker_state == WORKER_STATE_IDLE {
        next_uri = next(iter(self.dirty_files));
        self._fire_compile(next_uri);
    }
}

# ── Foreground request dispatch ───────────────────────────────────────

"""Send a foreground request to the worker.

If the worker is compiling (any file), cancel compilation first (P0/P1).
After FG is served, re-schedule dirty files.
"""
impl JacLangServer.send_fg_request(request: dict) -> dict {
    # P0/P1: If worker is compiling, cancel first.
    if self.worker_state == WORKER_STATE_COMPILING {
        self._cancel_current();
    }

    self.worker_state = WORKER_STATE_SERVING_FG;
    resp = self._send_and_recv(request);
    self.worker_state = WORKER_STATE_IDLE;

    # After FG, re-schedule any dirty files.
    self._schedule_next_dirty();
    return resp;
}

# ── Public API ────────────────────────────────────────────────────────

"""Queue a file for type checking (called from LSP handlers)."""
impl JacLangServer.type_check(file_uri: str) -> None {
    self.schedule_compile(file_uri);
}

"""Synchronous type-check for tests — send compile and wait for response."""
impl JacLangServer.type_check_file(
    file_uri: str,
    cancel_token: object | None = None,
    annex_view: Optional[str] = None
) -> bool {
    # For tests: blocking compile via pipe.
    fs_path = uris.to_fs_path(file_uri);
    try {
        document = self.workspace.get_text_document(file_uri);
        source = document.source;
    } except Exception {
        # If no workspace document, read from disk.
        try {
            with open(fs_path, 'r') as f {
                source = f.read();
            }
        } except Exception as e {
            self.debug(f"Could not read file {fs_path}: {e}");
            return False;
        }
    }

    self.worker_state = WORKER_STATE_COMPILING;
    self.compiling_file = file_uri;
    resp = self._send_and_recv(make_compile_request(fs_path, source));
    self._handle_compile_response(resp, file_uri);
    return resp.get("success", False);
}

"""Return hover info for a position."""
impl JacLangServer.get_hover_info(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Hover] {
    fs_path = uris.to_fs_path(file_path);
    req = make_hover_request(fs_path, position.line, position.character);
    resp = self.send_fg_request(req);
    return parse_hover_response(resp);
}

"""Return definition location for a position."""
impl JacLangServer.get_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
    fs_path = uris.to_fs_path(file_path);
    req = make_definition_request(fs_path, position.line, position.character);
    resp = self.send_fg_request(req);
    return parse_definition_response(resp);
}

"""Return references for a position."""
impl JacLangServer.get_references(
    file_path: str, position: lspt.Position
) -> list[lspt.Location] {
    fs_path = uris.to_fs_path(file_path);
    req = make_references_request(fs_path, position.line, position.character);
    resp = self.send_fg_request(req);
    return parse_references_response(resp);
}

"""Return document symbols (outline)."""
impl JacLangServer.get_outline(file_path: str) -> list[lspt.DocumentSymbol] {
    fs_path = uris.to_fs_path(file_path);
    req = make_outline_request(fs_path);
    resp = self.send_fg_request(req);
    return parse_outline_response(resp);
}

"""Return semantic tokens for a file."""
impl JacLangServer.get_semantic_tokens(
    file_path: str
) -> lspt.SemanticTokens {
    fs_path = uris.to_fs_path(file_path);
    req = make_semantic_tokens_request(fs_path);
    resp = self.send_fg_request(req);
    return parse_semantic_tokens_response(resp);
}

"""Return completion list."""
impl JacLangServer.get_completion(
    file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
) -> lspt.CompletionList {
    fs_path = uris.to_fs_path(file_uri);
    req = make_completion_request(
        fs_path, position.line, position.character, completion_trigger
    );
    resp = self.send_fg_request(req);
    return parse_completion_response(resp);
}

"""Rename a symbol."""
impl JacLangServer.rename_symbol(
    file_path: str, position: lspt.Position, new_name: str
) -> Optional[lspt.WorkspaceEdit] {
    fs_path = uris.to_fs_path(file_path);
    req = make_rename_request(fs_path, position.line, position.character, new_name);
    resp = self.send_fg_request(req);
    return parse_rename_response(resp);
}

"""Format a file."""
impl JacLangServer.formatted_jac(file_path: str) -> list[lspt.TextEdit] {
    try {
        document = self.workspace.get_text_document(file_path);
        source = document.source;
        fs_path = document.path;
    } except Exception as e {
        self.debug(f"Could not get document for formatting: {e}");
        return [];
    }
    req = make_format_request(fs_path, source);
    resp = self.send_fg_request(req);
    return parse_format_response(resp);
}

# ── Module management ─────────────────────────────────────────────────

"""Delete module from worker."""
impl JacLangServer.delete_module(uri: str) -> None {
    fs_path = uris.to_fs_path(uri);
    self._send_and_recv(make_delete_module_request(fs_path));
}

"""Rename module in worker."""
impl JacLangServer.rename_module(old_path: str, new_path: str) -> None {
    self._send_and_recv(make_rename_module_request(old_path, new_path));
}

# ── Idle wait (for tests) ────────────────────────────────────────────

impl JacLangServer.wait_till_idle -> None {
    self.wait_till_idle_sync();
}

"""Flush pending debounce timers and compile all dirty files synchronously."""
impl JacLangServer.wait_till_idle_sync -> None {
    # Cancel any pending debounce timer (may be from a dead event loop).
    if self.debounce_handle {
        try {
            self.debounce_handle.cancel();
        } except Exception {
            ;
        }
        self.debounce_handle = None;
    }

    # If a non-blocking compile is in flight, drain it synchronously.
    if self.worker_state == WORKER_STATE_COMPILING and self.compiling_file is not None {
        # Remove async reader so we can block here instead.
        try {
            loop = asyncio.get_running_loop();
            loop.remove_reader(self.main_conn.fileno());
        } except (RuntimeError, Exception) { ; }

        uri: str = str(self.compiling_file);
        try {
            resp = self.main_conn.recv();
            self._handle_compile_response(resp, uri);
        } except (EOFError, OSError) as e {
            self.debug(f"Pipe error in wait_till_idle_sync: {e}");
            self.worker_state = WORKER_STATE_IDLE;
            self.compiling_file = None;
        }
    }

    # Fire any remaining dirty files synchronously (blocking recv).
    while self.dirty_files and self.worker_state == WORKER_STATE_IDLE {
        next_uri = next(iter(self.dirty_files));
        fs_path = self.dirty_files.pop(next_uri, None);
        if not fs_path {
            continue;
        }
        try {
            document = self.workspace.get_text_document(next_uri);
            source = document.source;
        } except Exception {
            try {
                with open(fs_path, 'r') as f {
                    source = f.read();
                }
            } except Exception {
                continue;
            }
        }
        self.worker_state = WORKER_STATE_COMPILING;
        self.compiling_file = next_uri;
        req = make_compile_request(fs_path, source);
        try {
            self.main_conn.send(req);
            resp = self.main_conn.recv();
            self._handle_compile_response(resp, next_uri);
        } except (EOFError, OSError) as e {
            self.debug(f"Pipe error in wait_till_idle_sync: {e}");
            self.worker_state = WORKER_STATE_IDLE;
            self.compiling_file = None;
        }
    }
}

# ── Diagnostics cache ─────────────────────────────────────────────────

"""Return cached diagnostics (for test compatibility)."""
impl JacLangServer.diagnostics -> dict[str, list] {
    return self._last_diagnostics;
}

"""No-op for test compatibility (type system lives in worker)."""
impl JacLangServer.clear_type_system(clear_hub: bool = False) -> None {
    # Type system state is in the worker process.
    # This is a no-op — worker cleanup happens on shutdown.
}
