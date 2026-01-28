"""Implementation of JacLangServer - LSP engine core.

Handles:
- Server lifecycle (init, shutdown)
- Worker management and diagnostics callback
- File event coordination
- Response polling
"""

import time;
import logging;

impl JacLangServer.postinit -> None {
    LanguageServer.__init__(self, 'jac-lsp', 'v0.1');
    JacProgram.__init__(self);

    self._logger = logging.getLogger("jac.lsp");
    self.debug("Initializing JacLangServer...");

    self.module_manager = ModuleManager(self, self.sem_managers);

    config = WorkerConfig.default();
    self.debug(f"Worker config: debounce={config.debounce_ms}ms");
    self._worker_manager = WorkerManager(_config=config);
    self._worker_manager.set_diagnostics_callback(self._on_worker_diagnostics);
    self._worker_manager.start();

    self.debug("JacLangServer ready");
}

impl JacLangServer.shutdown -> None {
    if self._shutdown_called {
        return;
    }
    self._shutdown_called = True;
    self.debug("Shutting down...");

    try {
        self.stop_response_polling();
        if self._worker_manager is not None {
            self._worker_manager.stop();
            self._worker_manager = None;
        }
    } finally {
        super.shutdown();
    }
}

# ============== Logging ==============

impl JacLangServer.debug(msg: str) -> None {
    print(f"[Engine] {msg}", file=sys.stderr);
}

impl JacLangServer.log_info(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Info);
}

impl JacLangServer.log_warning(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Warning);
}

impl JacLangServer.log_error(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Error);
}

# ============== File Event Coordination ==============

impl JacLangServer.schedule_analysis(file_uri: str) -> None {
    if self._worker_manager is not None {
        self._worker_manager.schedule_file(file_uri);
    }
}

impl JacLangServer.on_file_opened(file_uri: str) -> None {
    if self._polling_task is None {
        self.start_response_polling();
    }
}

impl JacLangServer.on_file_closed(file_uri: str) -> None {
}

impl JacLangServer.on_file_focused(file_uri: str) -> None {
}

# ============== Testing Utilities ==============
# Used by: tests/langserve/test_server.py, tests/langserve/server_test/utils.py

impl JacLangServer.type_check_file(file_uri: str) -> bool {
    try {
        self.schedule_analysis(file_uri);
        self.wait_till_idle_sync();
        return True;
    } except Exception as e {
        self.debug(f"Error in type_check_file: {e}");
        return False;
    }
}

impl JacLangServer.wait_till_idle_sync -> None {
    if self._worker_manager is not None {
        while self._worker_manager.is_busy() {
            time.sleep(0.05);
        }
    }
}

# ============== Diagnostics Callback ==============

impl JacLangServer._on_worker_diagnostics(response: dict) -> None {
    if not hasattr(self, 'lsp') or not self.lsp {
        self.debug("Server not ready yet, skipping diagnostics");
        return;
    }

    diagnostics_data = response.get('diagnostics', {});
    file_path = response.get('file_path', '');
    hub_files = response.get('hub_files', []);

    self.debug(f"Diagnostics received: {file_path}, {len(hub_files)} files in hub");

    if file_path {
        uri = uris.from_fs_path(file_path);
        diagnostics = utils.gen_diagnostics_from_dict(file_path, diagnostics_data);
        try {
            self.publish_diagnostics(uri, diagnostics);
        } except Exception { }
    }

    all_paths = set();
    for e in diagnostics_data.get('errors', []) {
        if e.get('mod_path') {
            all_paths.add(e.get('mod_path'));
        }
    }
    for w in diagnostics_data.get('warnings', []) {
        if w.get('mod_path') {
            all_paths.add(w.get('mod_path'));
        }
    }
    for path in all_paths {
        if path != file_path {
            uri = uris.from_fs_path(path);
            diagnostics = utils.gen_diagnostics_from_dict(path, diagnostics_data);
            try {
                self.publish_diagnostics(uri, diagnostics);
            } except Exception { }
        }
    }

    try {
        self.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
    } except Exception { }
}

# ============== Response Polling ==============

impl JacLangServer.start_response_polling -> None {
    if self._polling_task is not None {
        return;
    }
    try {
        loop = asyncio.get_event_loop();
        self._polling_task = loop.create_task(self._response_polling_loop());
    } except RuntimeError { }
}

impl JacLangServer.stop_response_polling -> None {
    if self._polling_task is not None {
        self._polling_task.cancel();
        self._polling_task = None;
    }
}

impl JacLangServer._response_polling_loop -> None {
    interval_sec = self._polling_interval_ms / 1000.0;
    while not self._shutdown_called {
        try {
            if self._worker_manager is not None {
                self._worker_manager.process_pending_responses();
            }
            await asyncio.sleep(interval_sec);
        } except asyncio.CancelledError {
            break;
        } except Exception {
            await asyncio.sleep(interval_sec);
        }
    }
}

# ============== Module Management ==============

impl JacLangServer.delete_module(uri: str) -> None {
    if uri in self.mod.hub {
        del (self.mod.hub[uri], );
    }
    if uri in self.sem_managers {
        del (self.sem_managers[uri], );
    }
}

impl JacLangServer.rename_module(old_path: str, new_path: str) -> None {
    if old_path in self.mod.hub and new_path != old_path {
        self.mod.hub[new_path] = self.mod.hub[old_path];
        self.sem_managers[new_path] = self.sem_managers[old_path];
        del (self.mod.hub[old_path], );
        del (self.sem_managers[old_path], );
    }
}
