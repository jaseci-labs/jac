impl _uri_of(path: str) -> str {
    return uris.from_fs_path(path) or "";
}

impl _path_of(uri: str) -> str {
    return uris.to_fs_path(uri) or "";
}

impl _merge_app_alerts(
    collected: list[tuple[str, list, list]], app_count: int
) -> tuple[list, list] {
    def key_of(alert: any) -> tuple {
        code = alert.code.code if alert.code else '';
        return (
            alert.loc.mod_path,
            alert.loc.first_line,
            alert.loc.col_start,
            code,
            alert.msg
        );
    }

    def merge(index: int) -> list {
        seen_apps: dict[tuple, set[str]] = {};
        first: dict[tuple, any] = {};
        order: list[tuple] = [];
        tagged: list[tuple[str, any]] = [];
        for entry_item in collected {
            app_name = entry_item[0];
            for alert in entry_item[index] {
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
            if len(seen_apps[key]) >= app_count
        };
        out: list = [];
        emitted: set[tuple] = set();
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

    return (merge(1), merge(2));
}

import from jaclang.compiler.tools.unparse_pass { unparse_node }

impl Task.postinit -> None {
    self.task_id = Task._task_id;
    self.cancel_token = threading.Event();
    Task._task_id += 1;
}

impl JacLangServer.postinit -> None {
    self.name = 'jac-lsp';
    self.version = 'v0.1';
    self._write_lock = threading.Lock();
    self.program = JacProgram();

    self.program.deps.tracking = True;
    self._state_lock = ReadWriteLock();
    self.module_manager = ModuleManager(self.program, self.sem_managers);

    self._idle_event = threading.Event();
    self._idle_event.set();

    self.worker_future = flow self.dispatcher() ;
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
    import from pathlib { Path }
    fs_path = uris.to_fs_path(file_uri);
    if fs_path is None {
        return;
    }
    try {
        resolved = str(Path(fs_path).resolve());
    } except OSError {
        return;
    }

    if not self._dep_edges_seeded {
        self._dep_edges_seeded = True;
        try {
            ws_root = self.workspace?.root_path;
            if isinstance(ws_root, str) and ws_root {
                import from jaclang.compiler.driver.ifacecache { seed_dep_edges }
                seed_dep_edges(self.program, ws_root);
            }
        } except Exception {}
    }
    self.program.invalidate_module(resolved);
    dependents = self.program.transitive_dependents(resolved);
    if not dependents {
        return;
    }
    with self._state_lock.write_lock() {
        open_by_real: dict[str, str] = {};
        for open_uri in self.workspace._text_documents {
            open_fs = uris.to_fs_path(open_uri);
            if open_fs is None {
                continue;
            }
            try {
                open_by_real[str(Path(open_fs).resolve())] = open_uri;
            } except OSError {
                continue;
            }
        }
        for dep_path in dependents {
            dep_uri = open_by_real.get(dep_path);
            if dep_uri is None {
                try {
                    dep_uri = open_by_real.get(str(Path(dep_path).resolve()));
                } except OSError {
                    dep_uri = None;
                }
            }
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
    file_uri: str, cancel_token: threading.Event | None = None
) -> bool {
    if cancel_token and cancel_token.is_set() {
        return False;
    }
    try {
        document = self.workspace.get_text_document(file_uri);
        fs_path = document.path;

        base = discover_base_file(fs_path);
        main_path = base or fs_path;

        files_to_check = [main_path];
        files_to_check.extend(discover_annex_files(main_path, '.impl.jac'));
        files_to_check.extend(discover_annex_files(main_path, '.test.jac'));

        for f in files_to_check {
            self._clear_alerts_for_file(f);
        }

        import from jaclang.compiler.driver.compile_options { CompileOptions }
        main_doc = self.workspace.get_text_document(_uri_of(main_path));

        import from jaclang.compiler.frontend.parser.frontend {
            parse_diags,
            _replay_diags
        }
        import from jaclang.compiler.frontend.parser.lexer { Lexer as _Lexer }
        import from jaclang.compiler.frontend.parser.parser { Parser as _SyntaxParser }
        import from jaclang.compiler.frontend.unitree { Source as _Src }
        (_syn_had, _pd, _ld) = parse_diags(main_doc.source, main_path);
        if _pd or _ld {
            _dsrc = _Src(main_doc.source, mod_path=main_path);
            _replay_diags(_ld, _Lexer, self.program, _dsrc);
            _replay_diags(_pd, _SyntaxParser, self.program, _dsrc);
            _syn_errors = list(self.program.errors_had);
            _syn_warnings = list(self.program.warnings_had);
            self.publish_diagnostics(
                _uri_of(main_path),
                utils.gen_diagnostics(main_path, _syn_errors, _syn_warnings)
            );
            for f in files_to_check {
                self._clear_alerts_for_file(f);
            }
        }
        if cancel_token and cancel_token.is_set() {
            return False;
        }
        import from jaclang.compiler.placement.workspace { workspace_for_path }
        ws = workspace_for_path(main_path);
        app = ws.app_for_path(main_path) if ws is not None else None;
        proj_root = ws.project_root if ws is not None else None;
        targets: list[tuple[str, str]] = [];
        if ws is None or app is not None {
            targets = [(app.name if app else '', app.kind if app else '')];
        } else {
            targets = [
                (a.name, a.kind) for a in list(ws.apps.values())[:LSP_SHARED_APP_LIMIT]
            ];
        }
        multi = len(targets) > 1;
        collected: list[tuple[str, list, list]] = [];
        build: (uni.Module | None) = None;
        for (app_name, app_kind) in targets {
            build = self.program.compile(
                file_path=main_path,
                use_str=main_doc.source,
                options=CompileOptions(
                    no_cgen=True,
                    cancel_token=cancel_token,
                    target_app=app_name,
                    app_kind=app_kind,
                    project_root=proj_root
                )
            );
            if cancel_token and cancel_token.is_set() {
                return False;
            }
            if multi {
                collected.append(
                    (
                        app_name,
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
            (merged_errs, merged_warns) = _merge_app_alerts(collected, len(targets));
            self.program.errors_had.extend(merged_errs);
            self.program.warnings_had.extend(merged_warns);
        }
        assert build is not None;
        self.update_modules(main_path, build, files=files_to_check);

        all_errors = list(self.program.errors_had);
        all_warnings = list(self.program.warnings_had);
        for f in files_to_check {
            self.publish_diagnostics(
                _uri_of(f), utils.gen_diagnostics(f, all_errors, all_warnings)
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
    fs_path = _path_of(file_path);
    with self._state_lock.read_lock() {
        sem_mgr = self.sem_managers.get(fs_path);
        if not sem_mgr {
            return lspt.SemanticTokens(data=[]);
        }
        return lspt.SemanticTokens(data=list(sem_mgr.sem_tokens));
    }
}

impl JacLangServer.rename_symbol(
    file_path: str, position: lspt.Position, new_name: str
) -> Optional[lspt.WorkspaceEdit] {
    node_selected = self.get_token_at_position(file_path, position);
    if node_selected and node_selected.sym {
        changes: dict[(str, list[lspt.TextEdit])] = {};
        for nd in [*node_selected.sym.uses, node_selected.sym.defn[0]] {
            key = _uri_of(nd.loc.mod_path);
            new_edit = lspt.TextEdit(
                range=utils.create_range(nd.loc), new_text=new_name
            );
            utils.add_unique_text_edit(changes, key, new_edit);
        }
        return lspt.WorkspaceEdit(changes=changes);
    }
    return None;
}

impl JacLangServer.get_references(
    file_path: str, position: lspt.Position
) -> list[lspt.Location] {
    node_selected = self.get_token_at_position(file_path, position);
    if node_selected and node_selected.sym {
        list_of_references: list[lspt.Location] = [
            lspt.Location(
                uri=_uri_of(cur_node.loc.mod_path),
                range=utils.create_range(cur_node.loc)
            ) for cur_node in [*node_selected.sym.defn, *node_selected.sym.uses]
        ];
        return list_of_references;
    }
    return [];
}

def _definition_symbol(sym: any) -> any {
    cur = sym;
    seen: set[int] = set();
    while cur is not None and cur.provider is not None and id(cur) not in seen {
        seen.add(id(cur));
        target = cur.provider.definition();
        if target is None or target is cur {
            break;
        }
        cur = target;
    }
    return cur;
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
                    with self._state_lock.read_lock() {
                        target_mod = self.program.mod.hub.get(resolved_path);
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
    import from jaclang.compiler.driver.modresolver {
        is_client_npm_import,
        resolve_client_npm_declarations,
        resolve_client_npm_package
    }
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
    import from jaclang.compiler.driver.modresolver {
        is_client_npm_import,
        resolve_client_npm_declarations,
        resolve_client_npm_package
    }
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
    with self._state_lock.read_lock() {
        if fs_path in self.program.mod.hub
            and (root_node := self.program.mod.hub[fs_path].sym_tab) {
            return utils.get_symbols_for_outline(root_node);
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
    mod = self.program.mod.hub.get(fs_path);
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
    fs_path = uris.to_fs_path(uri);
    with self._state_lock.write_lock() {
        if fs_path in self.sem_managers {
            del self.sem_managers[fs_path];
        }
    }
}

impl JacLangServer.delete_module(uri: str) -> None {
    with self._state_lock.write_lock() {
        if uri in self.program.mod.hub {
            self.program.mod.hub.pop(uri);
        }
        if uri in self.sem_managers {
            del self.sem_managers[uri];
        }
    }
}

impl JacLangServer.rename_module(old_path: str, new_path: str) -> None {
    with self._state_lock.write_lock() {
        if old_path in self.program.mod.hub and new_path != old_path {
            self.program.mod.hub[new_path] = self.program.mod.hub[old_path];
            self.sem_managers[new_path] = self.sem_managers[old_path];

            self.program.mod.hub.pop(old_path);
            del self.sem_managers[old_path];
        }
    }
}

impl JacLangServer.get_completion_items_of(
    ty: TypeBase | uni.UniScopeNode
) -> lspt.CompletionList {
    return lspt.CompletionList(is_incomplete=False, items=get_completion_items(ty));
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
            typ = self.program.get_type_evaluator().get_type_of_expression(n);
        }
        self.debug("found type " + str(typ) + " for expr " + str(n));
        return typ;
    }
    self.debug("no type found for node " + str(n));
    return None;
}

impl JacLangServer.get_completion_of_node(nd: uni.UniNode) -> lspt.CompletionList {
    if (node_type := self.get_node_type(nd)) {
        self.debug("found type " + str(node_type));
        return self.get_completion_items_of(node_type);
    } elif isinstance(nd, UniScopeNode) {
        self.debug("found scope node " + str(nd));
        return self.get_scope_completion(nd);
    }
    self.debug("no type found for node " + str(nd));
    return lspt.CompletionList(is_incomplete=False, items=[]);
}

impl JacLangServer.get_node_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.UniNode] {
    if col < 0 {
        return None;
    }
    if (ast := self.get_ast_of_file(file_path)) {
        for ast_node in ast._in_mod_nodes {
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
    with self._state_lock.read_lock() {
        if file_path in self.program.mod.hub {
            return self.program.mod.hub[file_path];
        }
    }
    return None;
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

impl JacLangServer._position_in_string_or_comment(
    file_uri: str, line: int, col: int
) -> bool {
    ln = line + 1;
    co = col + 1;
    try {
        text_doc = self.workspace.get_text_document(file_uri);
        result = tokenize_full(text_doc.source, _path_of(file_uri));
        tokens = result[0];
        comments = result[1];
        for t in tokens {
            k = t.kind;
            if not (
                k == TokenKind.STRING
                or k == TokenKind.F_TEXT_DQ
                or k == TokenKind.F_TEXT_SQ
                or k == TokenKind.F_TEXT_TDQ
                or k == TokenKind.F_TEXT_TSQ
            ) {
                continue;
            }
            loc = t.loc;
            if loc.line < ln < loc.end_line {
                return True;
            }
            if ln < loc.line or ln > loc.end_line {
                continue;
            }
            if ln == loc.line and co < loc.col_start {
                continue;
            }
            if ln == loc.end_line and co >= loc.col_end {
                continue;
            }
            return True;
        }
        for c in comments {
            if c.line < ln < c.end_line {
                return True;
            }
            if ln < c.line or ln > c.end_line {
                continue;
            }
            if ln == c.line and co < c.col_start {
                continue;
            }
            if ln == c.end_line and co >= c.col_end {
                continue;
            }
            return True;
        }
        return False;
    } except Exception {
        return False;
    }
}

impl JacLangServer.get_completion(
    file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
) -> lspt.CompletionList {
    self.debug("Getting completion for " + file_uri + " at " + str(position));
    try {
        self._flush_completion_state(file_uri);
        if self._position_in_string_or_comment(
            file_uri, position.line, position.character
        ) {
            self.debug("completion suppressed (cursor in string or comment)");
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

        if node_at_pos {
            self.debug(
                "found the node at pos " + str(position) + " " + str(node_at_pos)
            );
        }

        if isinstance(node_at_pos, uni.Token) {
            if node_at_pos.name == "DOT" {
                member_access = node_at_pos.parent;
                self.debug("found dot " + str(member_access));
                if isinstance(member_access, uni.AtomTrailer) {
                    self.debug("before returning the list");
                    return self.get_completion_of_node(member_access.target);
                }
            } elif isinstance(node_at_pos, uni.Name) {
                parent = node_at_pos.parent;
                if (
                    isinstance(parent, uni.AtomTrailer)
                    and parent.is_attr
                    and node_at_pos is parent.right
                ) {
                    self.debug("found attribute name in atom trailer " + str(parent));
                    return self.get_completion_of_node(parent.target);
                }
                if scope_node := node_at_pos.find_parent_of_type(uni.UniScopeNode) {
                    self.debug("found name in scope node " + str(scope_node));
                    return self.get_scope_completion(scope_node);
                }
            }
        }

        if scope_node
            := self.get_scope_at_position(
                file_path, position.line, position.character
            ) {
            self.debug("fallback scope completion " + str(scope_node));
            return self.get_scope_completion(scope_node);
        }
        return lspt.CompletionList(is_incomplete=False, items=[]);
    } except Exception as e {
        self.log_py(f"Error during completion: {e}");
        return lspt.CompletionList(is_incomplete=False, items=[]);
    }
}

impl JacLangServer.debug(msg: str) -> None {
    console.error(f"[Engine] {msg}");
}

impl JacLangServer.get_token_at_position(
    file_path: str, position: lspt.Position
) -> Optional[uni.AstSymbolNode] {
    fs_path = _path_of(file_path);
    with self._state_lock.read_lock() {
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
            return sem_mgr.static_sem_tokens[token_index][3];
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
    with self._state_lock.write_lock() {
        self.module_manager.update(file_path, build, update_annexed=need, files=files);
    }
}

impl JacLangServer._clear_alerts_for_file(file_path: str) -> None {
    with self._state_lock.write_lock() {
        self.module_manager.clear_alerts_for_file(file_path);
    }
}

impl JacLangServer.diagnostics.getter -> dict[str, list] {
    with self._state_lock.read_lock() {
        all_errors = list(self.program.errors_had);
        all_warnings = list(self.program.warnings_had);
        result = {};
        for file_path in self.program.mod.hub {
            uri = uris.from_fs_path(file_path);
            result[uri] = utils.gen_diagnostics(file_path, all_errors, all_warnings);
        }
        return result;
    }
}
