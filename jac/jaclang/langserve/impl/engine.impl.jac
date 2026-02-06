import from jaclang.cli.console { console }
import time;

impl Task.postinit -> None {
    self.task_id = Task._task_id;
    self.cancel_token = threading.Event();
    Task._task_id += 1;
}

"""Initialize JacLangServer."""
impl JacLangServer.postinit -> None {
    LanguageServer.init(self, 'jac-lsp', 'v0.1');
    JacProgram.init(self);
    self._state_lock = threading.RLock();
    self.module_manager = ModuleManager(self, self.sem_managers);
    # Initialize idle event as set (server starts idle)
    self._idle_event = threading.Event();
    self._idle_event.set();
    # Worker for type checking using flow.
    self.worker_future = flow self.dispatcher() ;
    logging.getLogger().setLevel(logging.CRITICAL);
}

"""Debounced type check - waits for typing to pause before starting analysis."""
impl JacLangServer.type_check(file_uri: str) -> None {
    DEBOUNCE_DELAY = 0.3;  # 300ms debounce delay
    with self._state_lock {
        # Cancel any pending debounce timer
        if self._debounce_timer {
            self._debounce_timer.cancel();
            self._debounce_timer = None;
        }
        # Cancel any running task
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
        # Store for _flush_debounce and start timer with file_uri as argument
        self._debounce_timer = threading.Timer(
            DEBOUNCE_DELAY, self._do_type_check, args=[file_uri]
        );
        self._debounce_timer.start();
    }
}

"""Actually queue the type check task after debounce delay."""
impl JacLangServer._do_type_check(file_uri: str) -> None {
    with self._state_lock {
        # Clear timer reference and pending file
        self._debounce_timer = None;
        # Clear idle event since we're about to add work
        self._idle_event.clear();
    }
    self.debug("Debounce triggered, starting type check for " + file_uri);
    self.last_task = Task(file_uri);
    self.pipe.append(self.last_task);
    # Trigger the worker to pick up the new task.
    self._work_event.set();
}

"""Rebuild a file and its dependencies (typecheck)."""
impl JacLangServer.type_check_file(
    file_uri: str, cancel_token: Event | None = None, annex_view: Optional[str] = None,
    # This parameter will be passed recursively
    # and dont need to pass when the function itself is called
    # outside.
) -> bool {
    if cancel_token and cancel_token.is_set() {
        return False;
    }
    try {
        document = self.workspace.get_text_document(file_uri);
        fs_path = document.path;
        self._clear_alerts_for_file(fs_path);

        build = self.compile(
            use_str=document.source,
            file_path=document.path,
            type_check=True,
            no_cgen=True,
            cancel_token=cancel_token,
        );

        if cancel_token and cancel_token.is_set() {
            return False;
        }
        self.update_modules(fs_path, build);

        if build.annexable_by {
            return self.type_check_file(
                uris.from_fs_path(build.annexable_by),
                cancel_token=cancel_token,
                annex_view=fs_path,
            );
        }
        self.publish_diagnostics(
            (
                uris.from_fs_path(annex_view)
                if annex_view
                else uris.from_fs_path(fs_path)
                # to display diagnostic , it need URI starts with "file://"
            ),
            utils.gen_diagnostics(
                (annex_view or fs_path), self.errors_had, self.warnings_had
            )
        );
        if annex_view {
            self.publish_diagnostics(
                uris.from_fs_path(fs_path),
                utils.gen_diagnostics(fs_path, self.errors_had, self.warnings_had)
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
        self.debug(
            "Dispatcher waiting for work..." + str(start_time) + str(
                self.dirty_files.keys()
            )
        );
        # Wait until there's a task to process or shutdown is called.
        self._work_event.wait();
        if self._shutdown_called {
            self.debug("Shutting down dispatcher");
            break;
        } elif self.pipe {
            task = self.pipe.popleft();
        } elif self.dirty_files {
            # Get the most recent dirty file and create a NEW task for it
            (file_uri, _) = self.dirty_files.popitem();
            task = Task(file_uri);
        } else {
            # No tasks to process, signal idle and wait for the next one.
            self._work_event.clear();
            self._idle_event.set();
            continue;
        }

        self.debug("Dispatching task id: " + str(task.task_id));
        try {
            self.type_check_file(task.file_uri, cancel_token=task.cancel_token);
            self.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
        } finally {
        # self.queue.task_done();
        }
        if task.cancel_token.is_set() {
            self.debug(
                "Task cancled id: " + str(task.task_id) + " " + str(time.time())
            );
        } else {
            # Mark task as done so type_check won't try to "cancel" it later
            task.cancel_token.set();
            elapsed = time.time() - start_time;
            self.debug(
                f"Task completed id: {str(task.task_id)}, took: {elapsed:.4f}s {str(
                    task.file_uri
                )}"
            );
        }
        # Check if there's more work, otherwise signal idle
        if not self.pipe and not self.dirty_files {
            self._idle_event.set();
        }
    }
}

impl JacLangServer.shutdown -> None {
    # Guard against double shutdown.
    if self._shutdown_called {
        return;
    }
    self._shutdown_called = True;
    try {
        # Cancel any pending debounce timer
        with self._state_lock {
            if self._debounce_timer {
                self._debounce_timer.cancel();
                self._debounce_timer = None;
            }
        }
        if self?.worker_future and not self?.worker_future.done() {
            self._work_event.set();  # Wake up the worker to let it exit gracefully.
            wait self.worker_future ;  # Wait for the worker to finish
        }
    } finally {
        super.shutdown();
    }
}

"""Log a message."""
impl JacLangServer.log_py(message: str) -> None {
    logging.info(message);
}

"""Log an info message."""
impl JacLangServer.log_info(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Info);
    self.show_message(message, lspt.MessageType.Info);
}

"""Log a warning message."""
impl JacLangServer.log_warning(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Warning);
    self.show_message(message, lspt.MessageType.Warning);
}

"""Log an error message."""
impl JacLangServer.log_error(message: str) -> None {
    self.show_message_log(message, lspt.MessageType.Error);
    self.show_message(message, lspt.MessageType.Error);
}

"""Return semantic tokens for a file."""
impl JacLangServer.get_semantic_tokens(file_path: str) -> lspt.SemanticTokens {
    fs_path = uris.to_fs_path(file_path);
    self._state_lock.acquire();
    try {
        sem_mgr = self.sem_managers.get(fs_path);
        if not sem_mgr {
            return lspt.SemanticTokens(data=[]);
        }
        return lspt.SemanticTokens(data=list(sem_mgr.sem_tokens));
    } finally {
        self._state_lock.release();
    }
}

"""Rename a symbol in a file."""
impl JacLangServer.rename_symbol(
    file_path: str, position: lspt.Position, new_name: str
) -> Optional[lspt.WorkspaceEdit] {
    node_selected = self.get_token_at_position(file_path, position);
    if node_selected and node_selected.sym {
        changes: dict[(str, list[lspt.TextEdit])] = {};
        for node in [*node_selected.sym.uses, node_selected.sym.defn[0]] {
            key = uris.from_fs_path(node.loc.mod_path);
            new_edit = lspt.TextEdit(
                range=utils.create_range(node.loc), new_text=new_name
            );
            utils.add_unique_text_edit(changes, key, new_edit);
        }
        return lspt.WorkspaceEdit(changes=changes);
    }
    return None;
}

"""Return references for a file."""
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

"""Return definition location for a file."""
impl JacLangServer.get_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
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
    node_selected = self.get_token_at_position(file_path, position);
    if not node_selected {
        return None;
    }
    node_type = node_selected.type;
    parent = node_selected.parent;
    ####################################################################
    ##         Check for impl body first (stub -> impl navigation)    ##
    ####################################################################
    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        if isinstance(parent.body, uni.ImplDef) {
            return make_location(parent.body.sym.decl);
        }
    }
    ####################################################################
    ##          Handle go to def for types and variables              ##
    ####################################################################
    if node_type {
        if isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        } elif isinstance(node_type, ClassType) {
            return make_location(node_selected.sym.decl);
        } elif isinstance(node_type, (FunctionType, OverloadedType)) {
            return make_location(node_selected.sym.decl);
        }
    }
    ####################################################################
    ##         Ad-hoc handling for impl-def go to def                 ##
    ####################################################################
    if not parent {
        return None;
    }
    if isinstance(parent, uni.ImplDef) and parent.decl_link {
        return make_location(parent.decl_link.sym.decl);
    }
    ####################################################################
    ##         Fallback: use symbol resolution if available           ##
    ####################################################################
    # Even if type is not available, we can still navigate using the symbol
    # reference. This is important for symbols resolved in impl bodies where
    # type inference may not have run yet.
    if node_selected.sym and node_selected.sym.defn {
        try {
            return make_location(node_selected.sym.defn[0]);
        } except Exception as e {
            self.log_py(f"Error navigating to definition: {e}");
        }
    }
    return None;
}

"""Return document symbols for a file."""
impl JacLangServer.get_outline(file_path: str) -> list[lspt.DocumentSymbol] {
    fs_path = uris.to_fs_path(file_path);
    if fs_path in self.mod.hub and (root_node := self.mod.hub[fs_path].sym_tab) {
        return utils.get_symbols_for_outline(root_node);
    }
    return [];
}

"""Extract meaningful information from the AST node."""
impl JacLangServer.get_node_info(sym_node: uni.AstSymbolNode) -> Optional[str] {
    node_info: Optional[str] = None;
    try {
        if isinstance(sym_node, uni.NameAtom) {
            sym_node = sym_node.name_of;
        }
        access = (sym_node.sym.access.value + ' ') if sym_node.sym else None;
        node_info = f"'('{(access or '')}{sym_node.sym_category.value}') '{sym_node.sym_name}";
        if sym_node.name_spec.clean_type {
            node_info += f"': '{sym_node.name_spec.clean_type}";
        }
        if (
            isinstance(sym_node, uni.AstSymbolNode)
            and isinstance(sym_node.name_spec.type, ClassType)
        ) {
            node_info += f"': '{sym_node.name_spec.type.shared.class_name}";
        }
        if isinstance(sym_node, uni.AstDocNode) and sym_node.doc {
            node_info += f"'\n'{sym_node.doc.value}";
        }
        if isinstance(sym_node, uni.Ability) and sym_node.signature {
            node_info += f"'\n'{sym_node.signature.unparse()}";
        }
    } except AttributeError as e {
        self.log_warning(f"'Attribute error when accessing node attributes: '{e}");
    }
    return node_info.strip() if node_info else None;
}

"""Return hover information for a file."""
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

"""Return formatted jac."""
impl JacLangServer.formatted_jac(file_path: str) -> list[lspt.TextEdit] {
    document = self.workspace.get_text_document(file_path);
    try {
        prog = JacProgram.jac_str_formatter(
            source_str=document.source, file_path=document.path
        );
        formatted_text = prog.mod.main.gen.jac
        if not prog.errors_had
        else document.source;
    } except Exception as e {
        self.log_error(f"'Error during formatting: '{e}");
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

"""Close module (didClose cleanup - remove sem_manager only)."""
impl JacLangServer.close_module(uri: str) -> None {
    fs_path = uris.to_fs_path(uri);
    if fs_path in self.sem_managers {
        del (self.sem_managers[fs_path], );
    }
}

"""Delete module."""
impl JacLangServer.delete_module(uri: str) -> None {
    if uri in self.mod.hub {
        del (self.mod.hub[uri], );
    }
    if uri in self.sem_managers {
        del (self.sem_managers[uri], );
    }
}

"""Rename module."""
impl JacLangServer.rename_module(old_path: str, new_path: str) -> None {
    if old_path in self.mod.hub and new_path != old_path {
        self.mod.hub[new_path] = self.mod.hub[old_path];
        self.sem_managers[new_path] = self.sem_managers[old_path];
        del (self.mod.hub[old_path], );
        del (self.sem_managers[old_path], );
    }
}

"""Get type members for completion."""
impl JacLangServer.get_completion_items_of(
    ty: TypeBase | uni.UniScopeNode
) -> lspt.CompletionList {
    items: list[lspt.CompletionItem] = [];
    for item in get_completion_items(ty) {
        detail: lspt.CompletionItemLabelDetails | None = None;
        if item.detail {
            detail = lspt.CompletionItemLabelDetails(detail=item.detail);
        }
        items.append(
            lspt.CompletionItem(
                label=item.label, kind=item.kind, label_details=detail,
            )
        );
    }
    return lspt.CompletionList(is_incomplete=False, items=items,);
}

"""Return the type of an AST node if it has one."""
impl JacLangServer.get_node_type(n: uni.AstNode) -> Optional[TypeBase] {
    if isinstance(n, uni.Expr) {
        typ = self.get_type_evaluator().get_type_of_expression(n);
        self.debug("found type " + str(typ) + " for expr " + str(n));
        return typ;
    }
    self.debug("no type found for node " + str(n));
    return None;
}

impl JacLangServer.get_completion_of_node(node: uni.AstNode) -> lspt.CompletionList {
    if (node_type := self.get_node_type(node)) {
        self.debug("found type " + str(node_type));
        return self.get_completion_items_of(node_type);
    } elif isinstance(node, UniScopeNode) {
        self.debug("found scope node " + str(node));
        return self.get_completion_items_of(node);
    }
    self.debug("no type found for node " + str(node));
    return lspt.CompletionList(is_incomplete=False, items=[]);
}

impl JacLangServer.get_node_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.AstNode] {
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

impl JacLangServer.get_ast_of_file(file_path: str) -> Optional[uni.AstNode] {
    if file_path in self.mod.hub {
        return self.mod.hub[file_path];
    }
    return None;
}

"""Synchronous version of wait_till_idle for testing."""
impl JacLangServer.wait_till_idle_sync(file_uri: str) -> None {
    self.debug("Waiting for server to be idle (sync)...");
    # First, flush any pending debounce timer
    with self._state_lock {
        if self._debounce_timer {
            self._debounce_timer.cancel();
            self._debounce_timer = None;
        }
    }
    self._do_type_check(file_uri);
    # Wait for dispatcher to become idle
    self._idle_event.wait();
    self.debug("Server is now idle");
}

"""Return completion for a file."""
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
            # For each trigger character we need to handle the completion differently
            if isinstance(node_at_pos, uni.Token) {
                if node_at_pos.name == "DOT" {
                    member_access = node_at_pos.parent;
                    self.debug("found dot " + str(member_access));
                    if isinstance(member_access, uni.AtomTrailer) {
                        self.debug("before returning the list");
                        return self.get_completion_of_node(member_access.target);
                    }
                    # FIXME: This is wrong but imma do it anyways like this for now.
                } elif node_at_pos.name == "NAME" {
                    # Name of atom trailer.
                    if (
                        node_at_pos.parent
                        and isinstance(node_at_pos.parent, uni.AtomTrailer)
                    ) {
                        self.debug(
                            "found name in atom trailer " + str(node_at_pos.parent)
                        );
                        return self.get_completion_of_node(node_at_pos.parent.target);
                    }
                    # Just a name field.
                    if scope_node := node_at_pos.find_parent_of_type(uni.UniScopeNode) {
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
) -> Optional[uni.AstNode] {
    fs_path = uris.to_fs_path(file_path);
    self._state_lock.acquire();
    try {
        if fs_path not in self.mod.hub {
            return None;
        }
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
    } finally {
        self._state_lock.release();
    }
}

"""Update modules in JacProgram's hub and semantic managers."""
impl JacLangServer.update_modules(
    file_path: str, build: uni.Module, need: bool = True
) -> None {
    self.log_py(f"'Updating modules for '{file_path}");
    self._state_lock.acquire();
    try {
        self.module_manager.update(file_path, build, update_annexed=need);
    } finally {
        self._state_lock.release();
    }
}

"""Get IR for a file path."""
impl JacLangServer.get_ir(file_path: str) -> Optional[uni.Module] {
    return self.mod.hub.get(file_path);
}

"""Remove errors and warnings for a specific file from the lists."""
impl JacLangServer._clear_alerts_for_file(file_path: str) -> None {
    self.module_manager.clear_alerts_for_file(file_path);
}

"""Return diagnostics for all files as a dict {uri: diagnostics}."""
impl JacLangServer.diagnostics -> dict[str, list] {
    result = {};
    for file_path in self.mod.hub {
        uri = uris.from_fs_path(file_path);
        result[uri] = utils.gen_diagnostics(
            file_path, self.errors_had, self.warnings_had
        );
    }
    return result;
}
