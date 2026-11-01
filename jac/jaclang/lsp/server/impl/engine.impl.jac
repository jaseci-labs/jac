impl _uri_of(path: str) -> str {
    return uris.from_fs_path(path) or "";
}

impl _path_of(uri: str) -> str {
    return uris.to_fs_path(uri) or "";
}

impl Task.postinit -> None {
    self.task_id = Task._task_id;
    self.cancel_token = CancelToken();
    Task._task_id += 1;
}

impl JacLangServer.postinit -> None {
    self.name = 'jac-lsp';
    self.version = 'v0.1';
    self._write_lock = threading.Lock();
    self._state_lock = ReadWriteLock();
    self._idle_event = threading.Event();
    self._idle_event.set();
    self.worker_future = flow self.dispatcher() ;
}

impl JacLangServer.client -> SessionClient {
    with self._state_lock.write_lock() {
        if self.session is None {
            root = self.workspace?.root_path;
            self.session = SessionClient(project_root=root or "");
        }
        return self.session;
    }
}

impl JacLangServer._open_documents -> dict[str, str] {
    open_by_real: dict[str, str] = {};
    for open_uri in self.workspace._text_documents {
        open_fs = uris.to_fs_path(open_uri);
        if open_fs {
            open_by_real[os.path.realpath(open_fs)] = open_uri;
        }
    }
    return open_by_real;
}

impl JacLangServer._sync_document(path: str) -> None {
    uri = self._open_documents().get(path);
    if uri is None {
        return;
    }
    text = self.workspace.get_text_document(uri).source;
    with self._state_lock.write_lock() {
        if self._synced.get(path) == text {
            return;
        }
        self._synced[path] = text;
    }
    self.client().update(path, text);
}

impl JacLangServer._unit_files(path: str) -> list[str] {
    base = discover_base_file(path);
    main_path = os.path.realpath(base) if base else path;
    files = [main_path];
    for suffix in ['.impl.jac', '.test.jac'] {
        for annex in discover_annex_files(main_path, suffix) {
            real = os.path.realpath(annex);
            if real not in files {
                files.append(real);
            }
        }
    }
    if path not in files {
        files.append(path);
    }
    return files;
}

impl JacLangServer.type_check(file_uri: str) -> None {
    DEBOUNCE_DELAY = 0.3;
    with self._state_lock.write_lock() {
        if self._debounce_timer {
            self._debounce_timer.cancel();
            self._debounce_timer = None;
        }
        if self.last_task and not self.last_task.cancel_token.is_set() {
            self.last_task.cancel_token.set();
            if file_uri != self.last_task.file_uri {
                self.dirty_files[self.last_task.file_uri] = True;
            }
            self.debug(
                " Cancelling id: "
                    + str(self.last_task.task_id)
                    + " "
                    + str(time.time())
            );
        }
        self._debounce_timer = threading.Timer(
            DEBOUNCE_DELAY, self._do_type_check, args=[file_uri]
        );
        self._debounce_timer.start();
    }
}

impl JacLangServer._do_type_check(file_uri: str) -> None {
    self._fanout_dependents(file_uri);
    with self._state_lock.write_lock() {
        self._debounce_timer = None;
        self._idle_event.clear();
        self.debug("Debounce triggered, starting type check for " + file_uri);
        self.last_task = Task(file_uri);
        self.pipe.append(self.last_task);
        self._work_event.set();
    }
}

impl JacLangServer._fanout_dependents(file_uri: str) -> None {
    fs_path = _path_of(file_uri);
    if not fs_path {
        return;
    }
    dependents = self.client().dependents(os.path.realpath(fs_path));
    if not dependents {
        return;
    }
    with self._state_lock.write_lock() {
        open_by_real = self._open_documents();
        for dep_path in dependents {
            dep_uri = open_by_real.get(dep_path);
            if dep_uri is None or dep_uri == file_uri {
                continue;
            }
            self.dirty_files[dep_uri] = True;
            self._idle_event.clear();
        }
        if self.dirty_files {
            self._work_event.set();
        }
    }
}

impl JacLangServer.type_check_file(
    file_uri: str, cancel_token: (CancelToken | None) = None
) -> bool {
    if cancel_token and cancel_token.is_set() {
        return False;
    }
    try {
        files = self._unit_files(os.path.realpath(_path_of(file_uri)));
        for path in files {
            self._sync_document(path);
        }
        if cancel_token and cancel_token.is_set() {
            return False;
        }
        found = self.client().diagnostics(files[0]);
        if cancel_token and cancel_token.is_set() {
            return False;
        }
        by_file: dict[str, list[KernelDiagnostic]] = {path: [] for path in files};
        for diag in found {
            by_file.setdefault(os.path.realpath(diag.span.path), []).append(diag);
        }
        with self._state_lock.write_lock() {
            self.kernel_diagnostics.update(by_file);
        }
        for (path, diags) in by_file.items() {
            self.publish_diagnostics(
                _uri_of(path), [utils.lsp_diagnostic(diag) for diag in diags]
            );
        }
    } except Exception as e {
        self.log_error(f"Error during type check: {e}");
        return False;
    }
    return True;
}

impl JacLangServer.dispatcher -> None {
    while True {
        start_time = time.time();
        self.debug("Dispatcher waiting for work...");

        self._work_event.`wait();

        task: Task | None = None;
        should_exit = False;
        with self._state_lock.write_lock() {
            if self._shutdown_called {
                should_exit = True;
            } elif self.pipe {
                task = self.pipe.popleft();
            } elif self.dirty_files {
                (file_uri, _) = self.dirty_files.popitem();
                task = Task(file_uri);
            } else {
                self._work_event.clear();
                self._idle_event.set();
            }
        }
        if should_exit {
            self.debug("Shutting down dispatcher");
            break;
        }
        if not task {
            continue;
        }

        self.debug("Dispatching task id: " + str(task.task_id));
        try {
            self.type_check_file(task.file_uri, cancel_token=task.cancel_token);
            self.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
        } finally {}
        if task.cancel_token.is_set() {
            self.debug(
                "Task cancelled id: " + str(task.task_id) + " " + str(time.time())
            );
        } else {
            task.cancel_token.set();
            elapsed = time.time() - start_time;
            self.debug(
                f"Task completed id: {str(task.task_id)}, took: {elapsed:.4f}s {str(
                    task.file_uri
                )}"
            );
        }

        with self._state_lock.read_lock() {
            has_more = bool(self.pipe) or bool(self.dirty_files);
        }
        if not has_more {
            self._idle_event.set();
        }
    }
}

impl JacLangServer.shutdown -> None {
    with self._state_lock.write_lock() {
        if self._shutdown_called {
            return;
        }
        self._shutdown_called = True;
        if self._debounce_timer {
            self._debounce_timer.cancel();
            self._debounce_timer = None;
        }
    }

    try {
        if self?.worker_future and not self?.worker_future.done() {
            self._work_event.set();
            wait self.worker_future ;
        }
    } finally {
        super.shutdown();
    }
}

impl JacLangServer.log_py(message: str) -> None {
    logging.info(message);
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

impl JacLangServer.get_semantic_tokens(file_path: str) -> lspt.SemanticTokens {
    path = os.path.realpath(_path_of(file_path));
    return lspt.SemanticTokens(data=self.client().semantic_tokens(path));
}

impl JacLangServer.rename_symbol(
    file_path: str, position: lspt.Position, new_name: str
) -> Optional[lspt.WorkspaceEdit] {
    path = os.path.realpath(_path_of(file_path));
    edits = self.client().rename(
        path, position.line + 1, position.character + 1, new_name
    );
    if not edits {
        return None;
    }
    changes: dict[(str, list[lspt.TextEdit])] = {};
    for edit in edits {
        utils.add_unique_text_edit(
            changes,
            _uri_of(edit.span.path),
            lspt.TextEdit(range=utils.span_range(edit.span), new_text=edit.text)
        );
    }
    return lspt.WorkspaceEdit(changes=changes);
}

impl JacLangServer.get_references(
    file_path: str, position: lspt.Position
) -> list[lspt.Location] {
    path = os.path.realpath(_path_of(file_path));
    return [
        utils.span_location(span)
        for span in self.client().references(
            path, position.line + 1, position.character + 1
        )
    ];
}

impl JacLangServer.get_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
    path = os.path.realpath(_path_of(file_path));
    spans = self.client().definition(path, position.line + 1, position.character + 1);
    return utils.span_location(spans[0]) if spans else None;
}

impl JacLangServer.get_outline(file_path: str) -> list[lspt.DocumentSymbol] {
    path = os.path.realpath(_path_of(file_path));
    return [utils.document_symbol(symbol) for symbol in self.client().symbols(path)];
}

impl JacLangServer.get_inlay_hints(
    file_path: str, range: lspt.Range
) -> list[lspt.InlayHint] {
    path = os.path.realpath(_path_of(file_path));
    return [
        lspt.InlayHint(
            position=lspt.Position(line=hint.line - 1, character=max(hint.col - 1, 0)),
            label=hint.label,
            kind=(
                lspt.InlayHintKind.Parameter
                    if hint.kind == "parameter"
                    else lspt.InlayHintKind.Type
            ),
            padding_left=hint.label.startswith("(") or hint.label.startswith(" raises")
        )
        for hint in self.client().inlay_hints(
            path, range.start.line + 1, range.end.line + 1
        )
    ];
}

impl JacLangServer.get_hover_info(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Hover] {
    path = os.path.realpath(_path_of(file_path));
    value = self.client().hover(path, position.line + 1, position.character + 1);
    if not value {
        return None;
    }
    return lspt.Hover(
        contents=lspt.MarkupContent(kind=lspt.MarkupKind.PlainText, value=value)
    );
}

impl JacLangServer.format_document(
    file_path: str, auto_lint: bool = False
) -> list[lspt.TextEdit] {
    document = self.workspace.get_text_document(file_path);
    path = os.path.realpath(document.path);
    self._sync_document(path);
    session = self.client();
    laid_out = session.lint_fix(path) if auto_lint else session.format(path);
    if not laid_out.text {
        for diag in laid_out.errors {
            self.log_py(diagnostic_text(diag));
        }
        return [];
    }
    return [
        lspt.TextEdit(
            range=lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(
                    line=(len(document.source.splitlines()) + 1), character=0
                )
            ),
            new_text=laid_out.text
        )
    ];
}

impl JacLangServer.close_module(uri: str) -> None {
    path = os.path.realpath(_path_of(uri));
    with self._state_lock.write_lock() {
        self._synced.pop(path, None);
    }
    self.client().close(path);
}

impl JacLangServer.delete_module(uri: str) -> None {
    path = os.path.realpath(_path_of(uri));
    with self._state_lock.write_lock() {
        self._synced.pop(path, None);
        self.kernel_diagnostics.pop(path, None);
    }
    self.client().forget(path);
}

impl JacLangServer.rename_module(old_uri: str, new_uri: str) -> None {
    old_path = os.path.realpath(_path_of(old_uri));
    new_path = os.path.realpath(_path_of(new_uri));
    if old_path == new_path {
        return;
    }
    with self._state_lock.write_lock() {
        held = self._synced.pop(old_path, None);
        if held is not None {
            self._synced[new_path] = held;
        }
        self.kernel_diagnostics.pop(old_path, None);
    }
    self.client().rename_module(old_path, new_path);
}

impl JacLangServer.wait_till_idle_sync(file_uri: str) -> None {
    self.debug("Waiting for server to be idle (sync)...");

    with self._state_lock.write_lock() {
        if self._debounce_timer {
            self._debounce_timer.cancel();
            self._debounce_timer = None;
        }
    }
    self._do_type_check(file_uri);

    while True {
        self._idle_event.`wait();
        with self._state_lock.read_lock() {
            has_pending_work = bool(
                self.pipe or self.dirty_files or self._debounce_timer
            );
        }
        if not has_pending_work {
            break;
        }
        self._idle_event.clear();
        self._work_event.set();
    }
    self.debug("Server is now idle");
}

impl JacLangServer._flush_completion_state(file_uri: str) -> None {
    needs_refresh = False;
    with self._state_lock.read_lock() {
        needs_refresh = bool(self._debounce_timer or self.pipe or self.dirty_files);
    }
    if needs_refresh {
        self.wait_till_idle_sync(file_uri);
    }
}

impl JacLangServer.get_completion(
    file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
) -> lspt.CompletionList {
    self.debug("Getting completion for " + file_uri + " at " + str(position));
    self._flush_completion_state(file_uri);
    path = os.path.realpath(_path_of(file_uri));
    items = self.client().completion(path, position.line + 1, position.character + 1);
    return lspt.CompletionList(
        is_incomplete=False, items=[utils.completion_item(item) for item in items]
    );
}

impl JacLangServer.debug(msg: str) -> None {
    console.error(f"[Engine] {msg}");
}

impl JacLangServer.diagnostics.getter -> dict[str, list[lspt.Diagnostic]] {
    with self._state_lock.read_lock() {
        return {
            _uri_of(path): [utils.lsp_diagnostic(diag) for diag in diags]
            for (path, diags) in self.kernel_diagnostics.items()
        };
    }
}
