impl _uri_of(path: str) -> str {
    return uris.from_fs_path(path) or "";
}

impl _path_of(uri: str) -> str {
    return uris.to_fs_path(uri) or "";
}

impl _merge_app_alerts(
    collected: list[AppDiagnostics]
) -> tuple[list[Alert], list[Alert]] {
    def key_of(alert: Alert) -> tuple[str, int, int, str, str] {
        code = alert.code.code if alert.code else '';
        return (
            alert.loc.mod_path,
            alert.loc.first_line,
            alert.loc.col_start,
            code,
            alert.msg
        );
    }

    def merge(select_warnings: bool) -> list[Alert] {
        seen_apps: dict[tuple[str, int, int, str, str], set[str]] = {};
        first: dict[tuple[str, int, int, str, str], Alert] = {};
        order: list[tuple[str, int, int, str, str]] = [];
        tagged: list[tuple[str, Alert]] = [];
        for entry_item in collected {
            app_name = entry_item.app;
            for alert in (
                entry_item.warnings if select_warnings else entry_item.errors
            ) {
                key = key_of(alert);
                if key not in seen_apps {
                    seen_apps[key] = set();
                    first[key] = alert;
                    order.append(key);
                }
                seen_apps[key].add(app_name);
                tagged.append((app_name, alert));
            }
        }
        shared = {
            key
            for key in order
            if len(seen_apps[key]) >= len(collected)
        };
        out: list[Alert] = [];
        emitted: set[tuple[str, int, int, str, str]] = set();
        for (app_name, alert) in tagged {
            key = key_of(alert);
            if key in shared {
                if key not in emitted {
                    emitted.add(key);
                    out.append(first[key]);
                }
                continue;
            }
            alert.msg = f"[app:{app_name}] {alert.msg}";
            out.append(alert);
        }
        return out;
    }

    return (merge(False), merge(True));
}

import from jaclang.compiler.tools.unparse_pass { unparse_node }

impl JacLangServer.postinit -> None {
    super.postinit();
    self.name = 'jac-lsp';
    self.version = 'v0.1';
    self.watch_patterns = [
        '**/*.{jac,py,pyi}',
        '**/{jac.toml,jac.*.toml,jac.lock,.env}'
    ];
    self.program = JacProgram.for_analysis();
    self._compiler_lock = threading.RLock();
    self.module_manager = ModuleManager(self.program, self.sem_managers);
    self.work = WorkQueue();
    self.worker = threading.Thread(
        target=self.dispatcher, name='jac-analysis', daemon=True
    );
    self.worker.start();
}

impl JacLangServer.type_check(file_uri: str) -> None {
    path = _path_of(file_uri);
    self.work.schedule(_uri_of(discover_base_file(path) or path));
}

impl JacLangServer.submit_request(request: Request) -> None {
    if not self.work.submit(
        request,
        after_workspace=request.method
            in (lspt.TEXT_DOCUMENT_REFERENCES, lspt.TEXT_DOCUMENT_RENAME)
    ) {
        self._finish_request(
            request,
            error=ResponseErrorCode.ServerCancelled,
            message='Request queue is full or server is stopping'
        );
    }
}

impl JacLangServer._sync_sources(
    snapshot: WorkspaceSnapshot, changed_paths: set[str] | None = None
) -> None {
    changed = self.program.source_store.set_overrides(snapshot.sources());
    changed.update(changed_paths or set());
    for context in self.program.owned_contexts() {
        for path in list(context.mod.hub) {
            if not context.is_hub_entry_fresh(path) {
                changed.add(path);
            }
        }
    }
    affected: set[str] = set();
    open_units = {
        discover_base_file(os.path.realpath(document.path))
            or os.path.realpath(document.path)
        for document in snapshot.documents.values()
    };
    for path in changed {
        owner = discover_base_file(path) or path;
        affected.add(owner);
        affected.update(self.program.transitive_dependents(owner));
    }
    for path in affected {
        self.module_manager.invalidate(path);
        uri = _uri_of(path);
        if path in open_units {
            with self.work.condition {
                if uri not in self.work.pending
                    and not (
                        isinstance(self.work.active, WorkItem)
                        and self.work.active.uri == uri
                        and self.work.active.kind == WorkKind.CHECK
                    ) {
                    self.work.schedule(uri, immediate=True, interrupt=False);
                }
            }
        } elif path.endswith('.jac') and os.path.isfile(path) {
            self.work.schedule(uri, WorkKind.INDEX, immediate=True, interrupt=False);
        }
    }
}

impl JacLangServer.files_changed(uris: list[str]) -> None {
    self.workspace.touch();
    for uri in uris {
        self.work.schedule(uri, WorkKind.REFRESH, immediate=True);
    }
}

impl JacLangServer.start_indexing -> None {
    directory = self.workspace._root_path;
    if directory is not None {
        self.work.schedule(
            _uri_of(directory), WorkKind.SCAN, immediate=True, interrupt=False
        );
    }
}

impl JacLangServer._scan_workspace(uri: str) -> None {
    import from jaclang.project.source { iter_source_units }
    if self._index_paths is None {
        self._index_paths = iter_source_units(_path_of(uri));
    }
    path = next(self._index_paths, None);
    if path is None {
        self._index_paths = None;
        return;
    }
    self.work.schedule(_uri_of(path), WorkKind.INDEX, immediate=True, interrupt=False);
    self.work.schedule(uri, WorkKind.SCAN, immediate=True, interrupt=False);
}

impl JacLangServer._index_file(item: WorkItem) -> None {
    self._sync_sources(self.workspace.snapshot());
    path = discover_base_file(_path_of(item.uri)) or _path_of(item.uri);
    if not item.cancel_token.is_set()
        and os.path.isfile(path)
        and not self.module_manager.indexer.load(path) {
        self.type_check_file(_uri_of(path), item.cancel_token, publish=False);
    }
}

impl JacLangServer.get_workspace_symbols(query: str) -> list[lspt.SymbolInformation] {
    kinds = {
        'ability': lspt.SymbolKind.Function,
        'enum': lspt.SymbolKind.Enum,
        'module': lspt.SymbolKind.Module,
        'field': lspt.SymbolKind.Field,
        'obj': lspt.SymbolKind.Class,
        'class': lspt.SymbolKind.Class,
        'node': lspt.SymbolKind.Class,
        'edge': lspt.SymbolKind.Class,
        'walker': lspt.SymbolKind.Class
    };
    return [
        lspt.SymbolInformation(
            info.name,
            kinds.get(info.kind, lspt.SymbolKind.Variable),
            lspt.Location(
                _uri_of(info.file),
                lspt.Range(
                    lspt.Position(max(0, info.line - 1), max(0, info.col - 1)),
                    lspt.Position(
                        max(0, info.line - 1), max(0, info.col - 1) + len(info.name)
                    )
                )
            )
        ) for info in self.module_manager.index.search(query, self.program.source_store)
    ];
}

impl JacLangServer._refresh_file(uri: str) -> None {
    path = _path_of(uri);
    snapshot = self.workspace.snapshot();
    changed = {path};
    name = os.path.basename(path);
    if name in ('jac.toml', 'jac.lock', '.env')
        or (name.startswith('jac.') and name.endswith('.toml')) {
        changed.update(snapshot.sources());
        for context in self.program.owned_contexts() {
            changed.update(context.mod.hub);
        }
        self._index_paths = None;
        self.start_indexing();
    }
    self._sync_sources(snapshot, changed);
}

impl JacLangServer._ensure_query(request: Request) -> None {
    if request.responded
        or request.cancel_token.is_set()
        or request.revision != self.workspace.revision {
        return;
    }
    document = request.params.get('textDocument');
    if not isinstance(document, dict) {
        return;
    }
    uri = document.get('uri');
    if not isinstance(uri, str) {
        return;
    }
    self._sync_sources(self.workspace.snapshot());
    path = discover_base_file(_path_of(uri)) or _path_of(uri);
    products = self.module_manager.products.get(_path_of(uri));
    if products is not None
        and products.inputs is not None
        and not products.inputs.is_current(self.program.source_store) {
        self.module_manager.invalidate(products.unit_path);
        products = None;
    }
    if products is not None
        and request.method
            in (
                lspt.TEXT_DOCUMENT_DOCUMENT_SYMBOL,
                lspt.TEXT_DOCUMENT_SEMANTIC_TOKENS_FULL
            ) {
        return;
    }
    needs_types = request.method
        in (lspt.TEXT_DOCUMENT_REFERENCES, lspt.TEXT_DOCUMENT_RENAME);
    module = self.program.find_module(path);
    owner = self.program.module_owner(module) if module is not None else None;
    if module is None
        or _path_of(uri) not in self.sem_managers
        or (
            needs_types
            and owner is not None
            and not owner.analysis.analyses_run.provides(module, AnalysisFact.TYPE_OF)
        ) {
        self.type_check_file(uri, request.cancel_token, symbols_only=not needs_types);
    }
}

impl JacLangServer.type_check_file(
    file_uri: str,
    cancel_token: threading.Event | None = None,
    symbols_only: bool = False,
    publish: bool = True
) -> bool {
    with self._compiler_lock {
        if cancel_token and cancel_token.is_set() {
            return False;
        }
        touched: set[str] = set();
        try {
            snapshot = self.workspace.snapshot();
            self._sync_sources(snapshot);
            import from pathlib { Path }
            import from jaclang.project.config { config_scope }
            with self.program.source_store.capture() as inputs {
                touched = inputs.modules;
                inputs.watch_configuration(_path_of(file_uri));
                with config_scope(Path(_path_of(file_uri)).parent) {
                    fs_path = _path_of(file_uri);
                    main_path = discover_base_file(fs_path) or fs_path;
                    inputs.watch_configuration(main_path);
                    files_to_check = [main_path];
                    files_to_check.extend(
                        path
                        for (_, path) in self.program.source_store.annexes(main_path)
                    );
                    import from jaclang.compiler.driver.compilation_context {
                        analysis_options
                    }
                    targets = analysis_options(
                        main_path, self.program, symbols_only, cancel_token
                    );
                    multi = len(targets) > 1;
                    collected: list[AppDiagnostics] = [];
                    build: (uni.Module | None) = None;
                    builds: list[uni.Module] = [];
                    for options in targets {
                        build = self.program.compile(
                            file_path=main_path, options=options
                        );
                        builds.append(build);
                        if cancel_token and cancel_token.is_set() {
                            for path in inputs.modules {
                                self.module_manager.invalidate(path);
                            }
                            return False;
                        }
                        if multi {
                            collected.append(
                                AppDiagnostics(
                                    options.target_app,
                                    [
                                        e
                                        for e in self.program.errors_had
                                        if e.loc.mod_path in files_to_check
                                    ],
                                    [
                                        w
                                        for w in self.program.warnings_had
                                        if w.loc.mod_path in files_to_check
                                    ]
                                )
                            );
                            for f in files_to_check {
                                self._clear_alerts_for_file(f);
                            }
                        }
                    }
                    if multi {
                        (merged_errs, merged_warns) = _merge_app_alerts(collected);
                        self.program.errors_had.extend(merged_errs);
                        self.program.warnings_had.extend(merged_warns);
                    }
                    assert build is not None;
                    inputs_current = inputs.is_current(self.program.source_store);
                    with self.workspace.lock {
                        if not inputs_current
                            or snapshot.revision != self.workspace.revision
                            or (cancel_token is not None and cancel_token.is_set()) {
                            for path in inputs.modules {
                                self.module_manager.invalidate(path);
                            }
                            if not inputs_current {
                                self.workspace.touch();
                                self.work.schedule(
                                    file_uri,
                                    WorkKind.CHECK if publish else WorkKind.INDEX,
                                    immediate=True,
                                    interrupt=False
                                );
                            }
                            return False;
                        }
                        manifest = inputs.manifest();
                        for checked in builds {
                            self.module_manager.indexer.collect(checked, manifest);
                        }
                        if publish {
                            self.update_modules(main_path, build, files=files_to_check);
                        }
                        if publish and not symbols_only {
                            all_errors = list(self.program.errors_had);
                            all_warnings = list(self.program.warnings_had);
                            for path in files_to_check {
                                uri = _uri_of(path);
                                file_diags = utils.gen_diagnostics(
                                    path, all_errors, all_warnings
                                );
                                document = snapshot.documents.get(uri);
                                self._published_diagnostics[uri] = file_diags;
                                self.publish_diagnostics(
                                    uri,
                                    file_diags,
                                    version=document.version
                                        if document is not None
                                        else None
                                );
                            }
                        }
                    }
                }
            }
        } except Exception as e {
            for path in touched {
                self.module_manager.invalidate(path);
            }
            self.log_error(f"Error during type check: {e}");
            return False;
        }
        return True;
    }
}

impl JacLangServer._run_query(request: Request) -> None {
    import from pathlib { Path }
    import from jaclang.project.config { config_scope }
    if request.responded
        or request.cancel_token.is_set()
        or request.revision != self.workspace.revision {
        self._run_request(request);
        return;
    }
    snapshot = self.workspace.snapshot();
    self._sync_sources(snapshot);
    if request.method in (lspt.TEXT_DOCUMENT_REFERENCES, lspt.TEXT_DOCUMENT_RENAME) {
        with self.work.condition {
            if self.work.pending {
                self.submit_request(request);
                return;
            }
        }
    }
    document = request.params.get('textDocument', {});
    uri = document.get('uri', '') if isinstance(document, dict) else '';
    start = Path(_path_of(uri)).parent
        if uri
        else Path(self.workspace._root_path or os.getcwd());
    with self.program.source_store.capture() as inputs, config_scope(start) {
        for context in self.program.owned_contexts() {
            for path in context.mod.hub {
                self.program.source_store.record_module(path);
                self.program.source_store.annexes(path);
            }
        }
        def current -> bool {
            return inputs.is_current(self.program.source_store);
        }
        request.inputs_current = current;
        try {
            self._ensure_query(request);
            self._run_request(request);
        } finally {
            request.inputs_current = None;
            if not current() {
                for path in inputs.modules {
                    self.module_manager.invalidate(path);
                }
                self.workspace.touch();
                for open_uri in snapshot.documents {
                    self.work.schedule(open_uri, immediate=True, interrupt=False);
                }
            }
        }
    }
}

impl JacLangServer.dispatcher -> None {
    while (item := self.work.take()) is not None {
        complete = True;
        try {
            with self._compiler_lock {
                if isinstance(item, Request) {
                    self._run_query(item);
                } elif item.kind == WorkKind.CHECK {
                    complete = self.type_check_file(item.uri, item.cancel_token);
                    if complete {
                        self.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
                    }
                } elif item.kind == WorkKind.REFRESH {
                    self._refresh_file(item.uri);
                } elif item.kind == WorkKind.SCAN {
                    self._scan_workspace(item.uri);
                } elif item.kind == WorkKind.INDEX {
                    self._index_file(item);
                } else {
                    self._release_document(
                        item.uri, deleted=item.kind == WorkKind.DELETE
                    );
                }
            }
        } except Exception {
            logging.getLogger(__name__).exception('Language service task failed');
            if isinstance(item, Request) {
                self._finish_request(
                    item,
                    error=ResponseErrorCode.InternalError,
                    message='Analysis failed'
                );
            }
        } finally {
            with self._compiler_lock {
                self.module_manager.trim();
            }
            self.work.finish(item, complete=not item.cancel_token.is_set());
        }
    }
}

impl JacLangServer.shutdown -> None {
    if self._shutdown_called {
        return;
    }
    self._shutdown_called = True;
    for request in self.work.stop() {
        self._finish_request(
            request, error=ResponseErrorCode.RequestCancelled, message='Server stopping'
        );
    }
    if threading.current_thread() is not self.worker {
        self.worker.join();
    }
    self.sem_managers.clear();
    self.program.release_compile_closure();
    super.shutdown();
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
    fs_path = _path_of(file_path);
    with self._compiler_lock {
        products = self.module_manager.products.get(fs_path);
        if products is None {
            return lspt.SemanticTokens(data=[]);
        }
        return lspt.SemanticTokens(data=list(products.semantic_tokens));
    }
}

impl JacLangServer.rename_symbol(
    file_path: str, position: lspt.Position, new_name: str
) -> Optional[lspt.WorkspaceEdit] {
    references = self.get_references(file_path, position);
    if references {
        changes: dict[str, list[lspt.TextEdit]] = {};
        for ref in references {
            utils.add_unique_text_edit(
                changes, ref.uri, lspt.TextEdit(range=ref.range, new_text=new_name)
            );
        }
        return lspt.WorkspaceEdit(changes=changes);
    }
    return None;
}

impl JacLangServer.get_references(
    file_path: str, position: lspt.Position, include_declaration: bool = True
) -> list[lspt.Location] {
    node_selected = self.get_token_at_position(file_path, position);
    if node_selected and node_selected.sym {
        return [
            lspt.Location(
                uri=_uri_of(ref.file),
                range=lspt.Range(
                    start=lspt.Position(max(0, ref.line - 1), max(0, ref.col - 1)),
                    end=lspt.Position(max(0, ref.end_line - 1), max(0, ref.end_col - 1))
                )
            )
            for ref in self.module_manager.index.references_for_symbol(
                node_selected.sym, self.program.source_store, include_declaration
            )
        ];
    }
    return [];
}

impl JacLangServer.get_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
    import from pathlib { Path }

    def make_location(node_: uni.UniNode, is_module: bool = False) -> lspt.Location {
        mod_path: str = node_.loc.mod_path;
        if is_module
            and isinstance(node_, uni.Expr)
            and isinstance(node_.type, ModuleType) {
            mod_path = str(node_.type.file_uri);
        }
        decl_range = (
            utils.create_range(node_.loc)
                if not is_module
                else lspt.Range(
                    start=lspt.Position(line=0, character=0),
                    end=lspt.Position(line=0, character=0)
                )
        );
        return lspt.Location(uri=_uri_of(str(mod_path)), range=decl_range);
    }
    def make_module_location(file_path_str: str) -> lspt.Location {
        return lspt.Location(
            uri=_uri_of(file_path_str),
            range=lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(line=0, character=0)
            )
        );
    }
    node_selected = self.get_token_at_position(file_path, position);
    if not node_selected {
        return self._string_import_definition(file_path, position);
    }
    node_type: (TypeBase | None) = (
        node_selected.type if isinstance(node_selected, uni.Expr) else None
    );
    parent = node_selected.parent;

    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        body_nd = parent.body;
        if isinstance(body_nd, uni.ImplDef) and body_nd.sym {
            return make_location(body_nd.sym.decl);
        }
    }

    if isinstance(parent, uni.ModulePath) {
        if node_type and isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        }

        import_node = parent.parent_of_type(uni.Import) if parent else None;
        if import_node and parent.path {
            try {
                idx = (
                    `list(parent.path).index(node_selected)
                        if isinstance(node_selected, (uni.Name, uni.String))
                        else -1
                );
                path_list = parent.resolve_relative_path_list();
                if idx >= 0 and idx < len(path_list) {
                    resolved = path_list[idx];
                    if Path(resolved).exists() {
                        return make_module_location(resolved);
                    }
                }
            } except (ValueError, Exception) as e {
                self.log_py(f"Error resolving module path segment: {e}");
            }
        }
    }
    if isinstance(parent, uni.ModuleItem) and isinstance(node_selected, uni.Name) {
        if node_type and isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        }

        if (
            node_selected.sym
            and node_selected.sym.defn
            and node_selected.sym.defn[0].loc.mod_path != node_selected.loc.mod_path
        ) {
            decl = node_selected.sym.defn[0];
            return make_location(decl);
        }

        import_node = parent.parent_of_type(uni.Import) if parent else None;
        if import_node and import_node.from_loc {
            try {
                mod_path = import_node.from_loc.resolve_relative_path();
                if Path(mod_path).exists() and not Path(mod_path).is_dir() {
                    resolved_path = str(Path(mod_path).resolve());
                    with self._compiler_lock {
                        target_mod = self.program.find_module(resolved_path);
                    }
                    if target_mod {
                        sym = target_mod.lookup(
                            node_selected.value, deep=True, incl_inner_scope=True
                        );
                        if sym and sym.defn {
                            return make_location(sym.defn[0]);
                        }
                    }

                    return make_module_location(mod_path);
                }

                npm_loc = self._npm_item_location(
                    import_node.from_loc, parent.name.value
                );
                if npm_loc {
                    return npm_loc;
                }
            } except Exception as e {
                self.log_py(f"Error resolving imported item: {e}");
            }
        }
    }

    if node_type {
        if isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        } elif isinstance(node_type, ClassType) and node_selected.sym {
            return make_location(_definition_symbol(node_selected.sym).decl);
        } elif isinstance(node_type, (FunctionType, OverloadedType))
            and node_selected.sym {
            return make_location(_definition_symbol(node_selected.sym).decl);
        }
    }

    if not parent {
        return None;
    }
    if isinstance(parent, uni.ImplDef) and parent.decl_link {
        decl_link = parent.decl_link;
        if isinstance(decl_link, uni.AstSymbolNode) and decl_link.sym {
            return make_location(decl_link.sym.decl);
        }
    }

    if node_selected.sym and node_selected.sym.defn {
        defn0 = _definition_symbol(node_selected.sym).defn[0];

        if defn0 is node_selected
            or (
                defn0.loc.mod_path == node_selected.loc.mod_path
                and defn0.loc.first_line == node_selected.loc.first_line
                and defn0.loc.col_start == node_selected.loc.col_start
            ) {
            return None;
        }
        try {
            return make_location(defn0);
        } except Exception as e {
            self.log_py(f"Error navigating to definition: {e}");
        }
    }
    return None;
}

impl JacLangServer._string_import_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
    fs_path = uris.to_fs_path(file_path);
    if fs_path is None {
        return None;
    }
    tok = self.get_node_at_position(fs_path, position.line, position.character);
    if not isinstance(tok, uni.String) or not isinstance(tok.parent, uni.ModulePath) {
        return None;
    }
    target = self._module_spec_target(tok.parent);
    if target is None {
        return None;
    }
    target_uri = uris.from_fs_path(target);
    if target_uri is None {
        return None;
    }
    return lspt.Location(
        uri=target_uri,
        range=lspt.Range(
            start=lspt.Position(line=0, character=0),
            end=lspt.Position(line=0, character=0)
        )
    );
}

impl JacLangServer._module_spec_target(mp: uni.ModulePath) -> Optional[str] {
    import os;
    import from jaclang.project.modresolver {
        resolve_client_npm_declarations,
        resolve_client_npm_package
    }
    import from jaclang.compiler.placement.placement_pins { is_client_npm_import }
    try {
        resolved = mp.resolve_relative_path();
        if os.path.isfile(resolved) {
            return resolved;
        }
    } except Exception as e {
        self.log_py(f"Error resolving module path: {e}");
    }
    spec = mp.string_path_value or mp.dot_path_str;
    src_path = mp.loc.mod_path if mp.loc else None;
    if not spec or not src_path {
        return None;
    }
    try {
        if is_client_npm_import(spec, src_path) {
            return (
                resolve_client_npm_declarations(spec, src_path)
                or resolve_client_npm_package(spec, src_path)
            );
        }
    } except Exception as e {
        self.log_py(f"Error resolving npm module path: {e}");
    }
    return None;
}

impl JacLangServer._npm_item_location(
    from_loc: uni.ModulePath, item_name: str
) -> Optional[lspt.Location] {
    import from jaclang.project.modresolver {
        resolve_client_npm_declarations,
        resolve_client_npm_package
    }
    import from jaclang.compiler.placement.placement_pins { is_client_npm_import }
    def at_file(path_: str, rng: Optional[lspt.Range]) -> Optional[lspt.Location] {
        path_uri = uris.from_fs_path(path_);
        if path_uri is None {
            return None;
        }
        return lspt.Location(
            uri=path_uri,
            range=rng
                or lspt.Range(
                    start=lspt.Position(line=0, character=0),
                    end=lspt.Position(line=0, character=0)
                )
        );
    }
    spec = from_loc.string_path_value or from_loc.dot_path_str;
    src_path = from_loc.loc.mod_path if from_loc.loc else None;
    if not spec or not src_path or not is_client_npm_import(spec, src_path) {
        return None;
    }
    dts = resolve_client_npm_declarations(spec, src_path);
    if dts {
        return at_file(dts, utils.find_dts_decl_range(dts, item_name));
    }
    `entry = resolve_client_npm_package(spec, src_path);
    if `entry {
        return at_file(`entry, None);
    }
    return None;
}

impl JacLangServer.get_outline(file_path: str) -> list[lspt.DocumentSymbol] {
    fs_path = _path_of(file_path);
    with self._compiler_lock {
        products = self.module_manager.products.get(fs_path);
        if products is not None and products.outline is not None {
            return list(products.outline);
        }
        manager = self.sem_managers.get(fs_path);
        if manager is not None {
            symbols = utils.get_symbols_for_outline(manager.ir.sym_tab, fs_path);
            if products is not None {
                products.outline = symbols;
            }
            return list(symbols);
        }
    }
    return [];
}

impl JacLangServer.get_node_info(sym_node: uni.AstSymbolNode) -> Optional[str] {
    node_info: Optional[str] = None;
    try {
        if isinstance(sym_node, uni.NameAtom) {
            if sym_node.is_getattr_resolved {
                return f"(dynamic attribute) {sym_node?.value}: {sym_node.type}";
            }
            sym_node = sym_node.name_of;
        }
        access = (sym_node.sym.access.value + ' ') if sym_node.sym else None;
        node_info = f"({(access or '')}{sym_node.sym_category.value}) {sym_node.sym_name}";

        if not isinstance(sym_node, uni.Ability) {
            if sym_node?.type {
                node_info += f": {sym_node?.type}";
            } elif sym_node.name_spec.clean_type {
                node_info += f": {sym_node.name_spec.clean_type}";
            } elif (
                isinstance(sym_node, uni.AstSymbolNode)
                and isinstance(sym_node.name_spec.type, ClassType)
            ) {
                node_info += f": {sym_node.name_spec.type.shared.class_name}";
            }
        }
        if sym_node.sym and (doc := doc_of_sym(sym_node.sym)) {
            node_info += f"\n{doc}";
        }
        if isinstance(sym_node, uni.Ability) and sym_node.signature {
            node_info += f"\n{unparse_node(sym_node.signature)}";
        }
        try {
            top: (uni.UniNode | None) = sym_node;
            while (
                top is not None
                and not isinstance(top.parent, uni.Module)
                and top.parent is not None
            ) {
                top = top.parent;
            }
            if isinstance(top, uni.ContextAwareNode) {
                space = sym_node.codespace().value;
                tags: list[str] = [];
                if top.codespace_dual {
                    tags.append('dual');
                }
                tags.append('inferred');
                node_info += f"\nplacement: {space} ({', '.join(tags)})";
            }
        } except Exception {}
    } except AttributeError as e {
        self.log_warning(f"Attribute error when accessing node attributes: {e}");
    }
    return node_info.strip() if node_info else None;
}

impl JacLangServer.get_inlay_hints(
    file_path: str, range: lspt.Range
) -> list[lspt.InlayHint] {
    import from jaclang.compiler.passes.ownership_hints { inferred_hints }
    fs_path = _path_of(file_path);
    mod = self.program.find_module(fs_path);
    if mod is None {
        return [];
    }
    out: list[lspt.InlayHint] = [];
    for h in inferred_hints(mod) {
        line = h.line - 1;
        if line < range.start.line or line > range.end.line {
            continue;
        }
        out.append(
            lspt.InlayHint(
                position=lspt.Position(line=line, character=h.col),
                label=h.label,
                kind=(
                    lspt.InlayHintKind.Parameter
                        if h.kind == "parameter"
                        else lspt.InlayHintKind.Type
                ),
                padding_left=h.label.startswith("(") or h.label.startswith(" raises")
            )
        );
    }
    return out;
}

impl JacLangServer.get_hover_info(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Hover] {
    node_selected = self.get_token_at_position(file_path, position);
    value = self.get_node_info(node_selected) if node_selected else None;
    if value {
        return lspt.Hover(
            contents=lspt.MarkupContent(
                kind=lspt.MarkupKind.PlainText, value=f"{value}"
            )
        );
    }
    return None;
}

impl JacLangServer.format_document(
    file_path: str, auto_lint: bool = False
) -> list[lspt.TextEdit] {
    document = self.workspace.get_text_document(file_path);
    try {
        prog = JacProgram.jac_str_formatter(
            source_str=document.source, file_path=document.path, auto_lint=auto_lint
        );
        formatted_text = prog.mod.main.gen.jac
            if not prog.errors_had
            else document.source;
    } except Exception as e {
        self.log_error(
            f"Error during {'lintfix ' if auto_lint else ''}formatting: {e}"
        );
        formatted_text = document.source;
    }
    return [
        lspt.TextEdit(
            range=lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(
                    line=(len(document.source.splitlines()) + 1), character=0
                )
            ),
            new_text=formatted_text
        )
    ];
}

impl JacLangServer.close_module(uri: str) -> None {
    self.work.schedule(uri, WorkKind.CLOSE, immediate=True);
}

impl JacLangServer.delete_module(uri: str) -> None {
    self.workspace.remove_text_document(uri);
    self.work.schedule(uri, WorkKind.DELETE, immediate=True);
}

impl JacLangServer.rename_module(old_path: str, new_path: str) -> None {
    self.workspace.rename_text_document(old_path, new_path);
    self.delete_module(old_path);
    self.files_changed([new_path]);
}

impl JacLangServer._release_document(uri: str, deleted: bool = False) -> None {
    path = _path_of(uri);
    self._sync_sources(self.workspace.snapshot(), {path} if deleted else None);
    self.module_manager.forget(path);
    self._published_diagnostics.pop(uri, None);
    self.program.release_module(path);
    if deleted {
        for edges in self.program.dependency_graphs() {
            edges.forget(path);
        }
        for (context, indexed_path) in list(self.module_manager.index.shards) {
            if indexed_path == path {
                self.module_manager.index.discard(path, context);
            }
        }
    } elif path.endswith('.jac') and os.path.isfile(path) {
        self.work.schedule(uri, WorkKind.INDEX, immediate=True, interrupt=False);
    }
    self.publish_diagnostics(uri, []);
}

impl JacLangServer.get_completion_items_of(
    ty: TypeBase | uni.UniScopeNode
) -> lspt.CompletionList {
    items = self.module_manager.completions.get(id(ty));
    if items is None {
        items = get_completion_items(ty);
        self.module_manager.completions[id(ty)] = items;
    }
    return lspt.CompletionList(is_incomplete=False, items=list(items));
}

impl JacLangServer.get_scope_completion(
    scope: uni.UniScopeNode
) -> lspt.CompletionList {
    result = self.get_completion_items_of(scope);
    seen = {item.label for item in result.items};
    for (tok_name, text) in TOKEN_MAP.items() {
        if not text or not (text[0].isalpha() or text[0] == "_") {
            continue;
        }
        if not all(c.isalnum() or c == "_" for c in text) {
            continue;
        }
        if not (tok_name.startswith("KW_") or tok_name in ("NULL", "NOT", "BOOL")) {
            continue;
        }
        if text in seen {
            continue;
        }
        result.items.append(
            lspt.CompletionItem(label=text, kind=lspt.CompletionItemKind.Keyword)
        );
        seen.add(text);
    }
    return result;
}

impl JacLangServer.get_scope_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.UniScopeNode] {
    ast = self.get_ast_of_file(file_path);
    if not isinstance(ast, uni.UniScopeNode) {
        return None;
    }
    best: uni.UniScopeNode = ast;
    stack = list(ast.kid_scope);
    while stack {
        scope = stack.pop();
        if utils.position_within_node(scope, line + 1, col + 1) {
            best = scope;
            stack.extend(scope.kid_scope);
        }
    }
    return best;
}

impl JacLangServer.get_node_type(n: uni.UniNode) -> Optional[TypeBase] {
    if isinstance(n, uni.Expr) {
        typ = n.type;
        if typ is None {
            manager = self.sem_managers.get(n.loc.mod_path);
            owner = self.program.module_owner(manager.ir)
                if manager is not None
                else None;
            program = owner if owner is not None else self.program;
            typ = program.get_type_evaluator().get_type_of_expression(n);
        }
        return typ;
    }
    return None;
}

impl JacLangServer.get_completion_of_node(nd: uni.UniNode) -> lspt.CompletionList {
    if (node_type := self.get_node_type(nd)) {
        return self.get_completion_items_of(node_type);
    } elif isinstance(nd, UniScopeNode) {
        return self.get_scope_completion(nd);
    }
    return lspt.CompletionList(is_incomplete=False, items=[]);
}

impl JacLangServer.get_node_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.UniNode] {
    if col < 0 {
        return None;
    }
    manager = self.sem_managers.get(file_path);
    if manager is not None {
        for ast_node in manager.tokens_by_line.get(line, []) {
            if not isinstance(ast_node, uni.Token) {
                continue;
            }
            if (utils.position_within_node(ast_node, line + 1, col + 1)) {
                return ast_node;
            }
        }
    }
    return None;
}

impl JacLangServer.get_ast_of_file(file_path: str) -> Optional[uni.UniNode] {
    with self._compiler_lock {
        manager = self.sem_managers.get(file_path);
        if manager is not None {
            return manager.ir;
        }
        return self.program.find_module(file_path);
    }
    return None;
}

impl JacLangServer.wait_till_idle_sync(file_uri: str) -> None {
    if threading.current_thread() is self.worker {
        raise RuntimeError('The analysis worker cannot wait for itself');
    }
    self.type_check(file_uri);
    self.work.flush();
}

impl JacLangServer._position_in_string_or_comment(
    file_uri: str, line: int, col: int
) -> bool {
    document = self.workspace.get_text_document(file_uri);
    return self.module_manager.source_view(document.path, document.source).excludes(
        line, col
    );
}

impl JacLangServer.get_completion(
    file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
) -> lspt.CompletionList {
    try {
        if self._position_in_string_or_comment(
            file_uri, position.line, position.character
        ) {
            return lspt.CompletionList(is_incomplete=False, items=[]);
        }
        file_path = _path_of(file_uri);
        look_col = position.character - 1 if position.character > 0 else 0;
        node_at_pos = self.get_node_at_position(file_path, position.line, look_col);

        if not node_at_pos {
            node_at_pos = self.get_node_at_position(
                file_path, position.line, position.character
            );
        }

        if isinstance(node_at_pos, uni.Token) {
            if node_at_pos.name == "DOT" {
                member_access = node_at_pos.parent;
                if isinstance(member_access, uni.AtomTrailer) {
                    return self.get_completion_of_node(member_access.target);
                }
            } elif isinstance(node_at_pos, uni.Name) {
                parent = node_at_pos.parent;
                if (
                    isinstance(parent, uni.AtomTrailer)
                    and parent.is_attr
                    and node_at_pos is parent.right
                ) {
                    return self.get_completion_of_node(parent.target);
                }
                if scope_node := node_at_pos.find_parent_of_type(uni.UniScopeNode) {
                    return self.get_scope_completion(scope_node);
                }
            }
        }

        if scope_node
            := self.get_scope_at_position(
                file_path, position.line, position.character
            ) {
            return self.get_scope_completion(scope_node);
        }
        return lspt.CompletionList(is_incomplete=False, items=[]);
    } except Exception as e {
        self.log_py(f"Error during completion: {e}");
        return lspt.CompletionList(is_incomplete=False, items=[]);
    }
}

impl JacLangServer.get_token_at_position(
    file_path: str, position: lspt.Position
) -> Optional[uni.AstSymbolNode] {
    fs_path = _path_of(file_path);
    with self._compiler_lock {
        sem_mgr = self.sem_managers.get(fs_path);
        if not sem_mgr {
            return None;
        }
        token_index = utils.find_index(
            sem_mgr.sem_tokens, position.line, position.character
        );
        if token_index is None {
            return None;
        }
        if token_index < len(sem_mgr.static_sem_tokens) {
            return sem_mgr.static_sem_tokens[token_index].symbol;
        }
        return None;
    }
}

impl JacLangServer.update_modules(
    file_path: str,
    build: uni.Module,
    need: bool = True,
    files: (list[str] | None) = None
) -> None {
    self.log_py(f"Updating modules for {file_path}");
    with self._compiler_lock {
        self.module_manager.update(file_path, build, update_annexed=need, files=files);
    }
}

impl JacLangServer._clear_alerts_for_file(file_path: str) -> None {
    with self._compiler_lock {
        self.module_manager.clear_alerts_for_file(file_path);
    }
}

impl JacLangServer.diagnostics.getter -> dict[str, list[lspt.Diagnostic]] {
    with self._compiler_lock {
        return {
            uri: list(items) for (uri, items) in self._published_diagnostics.items()
        };
    }
}
