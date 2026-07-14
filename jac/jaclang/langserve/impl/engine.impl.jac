impl Task.postinit -> None {
    self.task_id = Task._task_id;
    self.cancel_token = threading.Event();
    Task._task_id += 1;
}

impl JacLangServer.postinit -> None {
    self.name = 'jac-lsp';
    self.version = 'v0.1';
    self._write_lock = threading.Lock();
    JacProgram.init(self);

    self._track_dependencies = True;
    self._state_lock = ReadWriteLock();
    self.module_manager = ModuleManager(self, self.sem_managers);

    self._idle_event = threading.Event();
    self._idle_event.set();

    self.worker_future = flow self.dispatcher() ;
    logging.getLogger().setLevel(logging.CRITICAL);
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
                " Cancelling id: " + str(self.last_task.task_id) + " " + str(
                    time.time()
                )
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

    self.invalidate_module(resolved);
    dependents = self.transitive_dependents(resolved);
    if not dependents {
        return;
    }
    with self._state_lock.write_lock() {
        for dep_path in dependents {
            dep_uri = uris.from_fs_path(dep_path);
            if dep_uri is None or dep_uri == file_uri {
                continue;
            }

            if dep_uri in self.workspace._text_documents {
                self.dirty_files[dep_uri] = True;
                self._idle_event.clear();
            }
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

        import from jaclang.jac0core.compile_options { CompileOptions }
        main_doc = self.workspace.get_text_document(uris.from_fs_path(main_path));
        build = self.compile(
            file_path=main_path,
            use_str=main_doc.source,
            options=CompileOptions(
                type_check=True,
                no_cgen=True,
                force_target_program=True,
                cancel_token=cancel_token
            )
        );

        if cancel_token and cancel_token.is_set() {
            return False;
        }
        self.update_modules(main_path, build, files=files_to_check);

        all_errors = list(self.errors_had);
        all_warnings = list(self.warnings_had);
        for f in files_to_check {
            self.publish_diagnostics(
                uris.from_fs_path(f), utils.gen_diagnostics(f, all_errors, all_warnings)
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

        self._work_event.wait();

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
        } finally { }
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
    fs_path = uris.to_fs_path(file_path);
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
            key = uris.from_fs_path(nd.loc.mod_path);
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
                uri=uris.from_fs_path(cur_node.loc.mod_path),
                range=utils.create_range(cur_node.loc)
            ) for cur_node in [*node_selected.sym.defn, *node_selected.sym.uses]
        ];
        return list_of_references;
    }
    return [];
}

impl JacLangServer.get_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
    import from pathlib { Path }

    def make_location(node_: uni.UniNode, is_module: bool = False) -> lspt.Location {
        mod_path = node_.type.file_uri if is_module else node_.loc.mod_path;
        decl_range = (
            utils.create_range(node_.loc)
                if not is_module
                else lspt.Range(
                    start=lspt.Position(line=0, character=0),
                    end=lspt.Position(line=0, character=0)
                )
        );
        return lspt.Location(uri=uris.from_fs_path(str(mod_path)), range=decl_range);
    }
    def make_module_location(file_path_str: str) -> lspt.Location {
        return lspt.Location(
            uri=uris.from_fs_path(file_path_str),
            range=lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(line=0, character=0)
            )
        );
    }
    node_selected = self.get_token_at_position(file_path, position);
    if not node_selected {
        return None;
    }
    node_type = node_selected.type;
    parent = node_selected.parent;

    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        if isinstance(parent.body, uni.ImplDef) {
            return make_location(parent.body.sym.decl);
        }
    }

    if isinstance(parent, uni.ModulePath) {
        if node_type and isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        }

        import_node = parent.parent_of_type(uni.Import) if parent else None;
        if import_node and parent.path {
            try {
                idx = `list(parent.path).index(node_selected);
                path_list = parent.resolve_relative_path_list();
                if idx < len(path_list) {
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
                        target_mod = self.mod.hub.get(resolved_path);
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
            } except Exception as e {
                self.log_py(f"Error resolving imported item: {e}");
            }
        }
    }

    if node_type {
        if isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        } elif isinstance(node_type, ClassType) and node_selected.sym {
            return make_location(node_selected.sym.decl);
        } elif isinstance(node_type, (FunctionType, OverloadedType))
        and node_selected.sym {
            return make_location(node_selected.sym.decl);
        }
    }

    if not parent {
        return None;
    }
    if isinstance(parent, uni.ImplDef) and parent.decl_link {
        return make_location(parent.decl_link.sym.decl);
    }

    if node_selected.sym and node_selected.sym.defn {
        try {
            return make_location(node_selected.sym.defn[0]);
        } except Exception as e {
            self.log_py(f"Error navigating to definition: {e}");
        }
    }
    return None;
}

impl JacLangServer.get_outline(file_path: str) -> list[lspt.DocumentSymbol] {
    fs_path = uris.to_fs_path(file_path);
    with self._state_lock.read_lock() {
        if fs_path in self.mod.hub and (root_node := self.mod.hub[fs_path].sym_tab) {
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
                return f"(dynamic attribute) {sym_node.value}: {sym_node.type}";
            }
            sym_node = sym_node.name_of;
        }
        access = (sym_node.sym.access.value + ' ') if sym_node.sym else None;
        node_info = f"'('{(access or '')}{sym_node.sym_category.value}') '{sym_node.sym_name}";

        if not isinstance(sym_node, uni.Ability) {
            if sym_node?.type and sym_node.type {
                node_info += f"': '{sym_node.type}";
            } elif sym_node.name_spec.clean_type {
                node_info += f"': '{sym_node.name_spec.clean_type}";
            } elif (
                isinstance(sym_node, uni.AstSymbolNode)
                and isinstance(sym_node.name_spec.type, ClassType)
            ) {
                node_info += f"': '{sym_node.name_spec.type.shared.class_name}";
            }
        }
        if sym_node.sym and (doc := doc_of_sym(sym_node.sym)) {
            node_info += f"'\n'{doc}";
        }
        if isinstance(sym_node, uni.Ability) and sym_node.signature {
            node_info += f"'\n'{sym_node.signature.unparse()}";
        }
    } except AttributeError as e {
        self.log_warning(f"'Attribute error when accessing node attributes: '{e}");
    }
    return node_info.strip() if node_info else None;
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
            del (self.sem_managers[fs_path], );
        }
    }
}

impl JacLangServer.delete_module(uri: str) -> None {
    with self._state_lock.write_lock() {
        if uri in self.mod.hub {
            del (self.mod.hub[uri], );
        }
        if uri in self.sem_managers {
            del (self.sem_managers[uri], );
        }
    }
}

impl JacLangServer.rename_module(old_path: str, new_path: str) -> None {
    with self._state_lock.write_lock() {
        if old_path in self.mod.hub and new_path != old_path {
            self.mod.hub[new_path] = self.mod.hub[old_path];
            self.sem_managers[new_path] = self.sem_managers[old_path];
            del (self.mod.hub[old_path], );
            del (self.sem_managers[old_path], );
        }
    }
}

impl JacLangServer.get_completion_items_of(
    ty: TypeBase | uni.UniScopeNode
) -> lspt.CompletionList {
    items: list[lspt.CompletionItem] = [];
    for item in get_completion_items(ty) {
        detail: lspt.CompletionItemLabelDetails | None = None;
        if item.detail {
            detail = lspt.CompletionItemLabelDetails(detail=item.detail);
        }
        documentation: lspt.MarkupContent | None = None;
        if item.documentation {
            documentation = lspt.MarkupContent(
                kind=lspt.MarkupKind.PlainText, value=item.documentation
            );
        }
        items.append(
            lspt.CompletionItem(
                label=item.label,
                kind=item.kind,
                label_details=detail,
                documentation=documentation,
            )
        );
    }
    return lspt.CompletionList(is_incomplete=False, items=items,);
}

impl JacLangServer.get_node_type(n: uni.UniNode) -> Optional[TypeBase] {
    if isinstance(n, uni.Expr) {
        typ = self.get_type_evaluator().get_type_of_expression(n);
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
        return self.get_completion_items_of(nd);
    }
    self.debug("no type found for node " + str(nd));
    return lspt.CompletionList(is_incomplete=False, items=[]);
}

impl JacLangServer.get_node_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.UniNode] {
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
        if file_path in self.mod.hub {
            return self.mod.hub[file_path];
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
        self._idle_event.wait();
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

impl JacLangServer.get_completion(
    file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
) -> lspt.CompletionList {
    self.debug("Getting completion for " + file_uri + " at " + str(position));
    try {
        file_path = uris.to_fs_path(file_uri);
        if (
            node_at_pos := self.get_node_at_position(
                file_path, position.line, position.character - 1
            )
        ) {
            self.debug(
                "found the node at pos " + str(position) + " " + str(node_at_pos)
            );

            if isinstance(node_at_pos, uni.Token) {
                if node_at_pos.name == "DOT" {
                    member_access = node_at_pos.parent;
                    self.debug("found dot " + str(member_access));
                    if isinstance(member_access, uni.AtomTrailer) {
                        self.debug("before returning the list");
                        return self.get_completion_of_node(member_access.target);
                    }
                } elif node_at_pos.name == "NAME" {
                    if (
                        node_at_pos.parent
                        and isinstance(node_at_pos.parent, uni.AtomTrailer)
                    ) {
                        self.debug(
                            "found name in atom trailer " + str(node_at_pos.parent)
                        );
                        return self.get_completion_of_node(node_at_pos.parent.target);
                    }
                    if scope_node := node_at_pos.find_parent_of_type(
                        uni.UniScopeNode
                    ) {
                        self.debug("found name in scope node " + str(scope_node));
                        return self.get_completion_of_node(scope_node);
                    }
                }
            }
        }
        return lspt.CompletionList(is_incomplete=False, items=[]);
    } except Exception as e {
        self.log_py(f"'Error during completion: '{e}");
        return lspt.CompletionList(is_incomplete=False, items=[]);
    }
}

impl JacLangServer.debug(msg: str) -> None {
    console.error(f"[Engine] {msg}");
}

impl JacLangServer.get_token_at_position(
    file_path: str, position: lspt.Position
) -> Optional[uni.UniNode] {
    fs_path = uris.to_fs_path(file_path);
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
    self.log_py(f"'Updating modules for '{file_path}");
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
        all_errors = list(self.errors_had);
        all_warnings = list(self.warnings_had);
        result = {};
        for file_path in self.mod.hub {
            uri = uris.from_fs_path(file_path);
            result[uri] = utils.gen_diagnostics(file_path, all_errors, all_warnings);
        }
        return result;
    }
}
