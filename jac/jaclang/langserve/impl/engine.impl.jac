"""Implementation of JacLangServer - production-grade LSP engine.

This implementation uses a scheduler-first architecture:
- All analysis is routed through AnalysisScheduler
- Worker process handles CPU-bound compilation
- Immutable snapshots enable lock-free foreground queries
- Full LSP request cancellation support
"""

import threading;
import time;
import logging;

"""Initialize JacLangServer with scheduler-based architecture."""
impl JacLangServer.postinit -> None {
    LanguageServer.init(self, 'jac-lsp', 'v0.1');
    JacProgram.init(self);

    # Initialize logger
    self._logger = logging.getLogger("jac.lsp");

    # Initialize module manager
    self.module_manager = ModuleManager(self, self.sem_managers);

    # Initialize lock manager for thread-safe updates
    self._lock_manager = LockManager();

    # Initialize request tracking for cancellation
    self._pending_requests = {};
    self._pending_requests_lock = threading.Lock();

    # Initialize snapshot manager
    self._snapshot_manager = SnapshotManager();
    self._snapshot_manager.initialize_empty();

    # Initialize and start scheduler
    config = SchedulerConfig.default();
    self._scheduler = AnalysisScheduler(
        _config=config,
        _snapshot_manager=self._snapshot_manager
    );
    self._scheduler.set_diagnostics_callback(self._on_scheduler_diagnostics);
    self._scheduler.start();

    self.debug("JacLangServer initialized with scheduler architecture");
}

"""Shutdown the language server."""
impl JacLangServer.shutdown -> None {
    if self._shutdown_called {
        return;
    }
    self._shutdown_called = True;

    try {
        # Stop scheduler (which stops the worker)
        if self._scheduler is not None {
            self._scheduler.stop();
            self._scheduler = None;
        }
    } finally {
        super.shutdown();
    }
    self.debug("JacLangServer shutdown complete");
}

"""Log a message."""
impl JacLangServer.log_py(message: str) -> None {
    if self._logger {
        self._logger.info(message);
    } else {
        logging.info(message);
    }
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
    try {
        self._lock_manager.sem_managers_lock.acquire_read();
        try {
            sem_mgr = self.sem_managers.get(fs_path);
            if not sem_mgr {
                return lspt.SemanticTokens(data=[]);
            }
            # Copy the tokens list to avoid holding lock during serialization
            tokens_copy = list(sem_mgr.sem_tokens);
        } finally {
            self._lock_manager.sem_managers_lock.release_read();
        }
        return lspt.SemanticTokens(data=tokens_copy);
    } except Exception as e {
        self.debug(f"Error getting semantic tokens: {e}");
        return lspt.SemanticTokens(data=[]);
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
            ) for cur_node in node_selected.sym.uses
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
    # Check for impl body first (stub -> impl navigation)
    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        if isinstance(parent.body, uni.ImplDef) {
            return make_location(parent.body.sym.decl);
        }
    }
    # Handle go to def for types and variables
    if node_type {
        if isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        } elif isinstance(node_type, ClassType) {
            return make_location(node_selected.sym.decl);
        } elif isinstance(node_type, (FunctionType, OverloadedType)) {
            return make_location(node_selected.sym.decl);
        }
    }
    # Ad-hoc handling for impl-def go to def
    if not parent {
        return None;
    }
    if isinstance(parent, uni.ImplDef) and parent.decl_link {
        return make_location(parent.decl_link.sym.decl);
    }
    # Fallback: use symbol resolution if available
    if node_selected.sym and node_selected.sym.defn {
        try {
            return make_location(node_selected.sym.defn[0]);
        } except Exception { }
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
    return node_info.strip();
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
    try {
        document = self.workspace.get_text_document(file_path);
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

"""Delete module."""
impl JacLangServer.delete_module(uri: str) -> None {
    if uri in self.mod.hub {
        del (self.mod.hub[uri], ) ;
    }
    if uri in self.sem_managers {
        del (self.sem_managers[uri], ) ;
    }
}

"""Rename module."""
impl JacLangServer.rename_module(old_path: str, new_path: str) -> None {
    if old_path in self.mod.hub and new_path != old_path {
        self.mod.hub[new_path] = self.mod.hub[old_path];
        self.sem_managers[new_path] = self.sem_managers[old_path];
        del (self.mod.hub[old_path], ) ;
        del (self.sem_managers[old_path], ) ;
    }
}

"""Get type members for completion."""
impl JacLangServer.get_completion_items_of(
    ty: TypeBase | uni.UniScopeNode
) -> lspt.CompletionList {
    evaluator = self.get_type_evaluator();
    self.debug("getting completion of " + str(ty));
    items = get_completion_items(ty);
    self.debug("completion items are " + str(items));
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
    try {
        self._lock_manager.hub_lock.acquire_read();
        try {
            if file_path in self.mod.hub {
                return self.mod.hub[file_path];
            }
            return None;
        } finally {
            self._lock_manager.hub_lock.release_read();
        }
    } except Exception as e {
        self.debug(f"Error getting AST: {e}");
        return None;
    }
}

"""Wait for all pending analysis to complete."""
impl JacLangServer.wait_till_idle -> None {
    self.debug("Waiting for analysis to complete...");
    if self._scheduler is not None {
        # Wait for scheduler to finish ALL work: pending queue, backoff timer, and current analysis
        while self._scheduler.is_busy() {
            await asyncio.sleep(0.05);
        }
    }
    self.debug("Analysis complete");
}

"""Synchronous version of wait_till_idle for testing."""
impl JacLangServer.wait_till_idle_sync -> None {
    self.debug("Waiting for analysis to complete (sync)...");
    if self._scheduler is not None {
        # Wait for scheduler to finish ALL work: pending queue, backoff timer, and current analysis
        while self._scheduler.is_busy() {
            time.sleep(0.05);
        }
    }
    self.debug("Analysis complete");
}

"""Return completion for a file."""
impl JacLangServer.get_completion(
    file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
) -> lspt.CompletionList {
    # Wait for analysis to complete before providing completions
    await self.wait_till_idle();
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
    self.debug("returning empty list");
}

impl JacLangServer.debug(msg: str) -> None {
    print(f"[Engine] {msg}", file=sys.stderr);
}

impl JacLangServer.get_token_at_position(
    file_path: str, position: lspt.Position
) -> Optional[uni.AstNode] {
    fs_path = uris.to_fs_path(file_path);

    # Acquire read locks for thread-safe access
    try {
        self._lock_manager.hub_lock.acquire_read();
        try {
            self._lock_manager.sem_managers_lock.acquire_read();
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
                node_selected = sem_mgr.static_sem_tokens[token_index][3];
                return node_selected;
            } finally {
                self._lock_manager.sem_managers_lock.release_read();
            }
        } finally {
            self._lock_manager.hub_lock.release_read();
        }
    } except Exception as e {
        self.debug(f"Error getting token at position: {e}");
        return None;
    }
}

"""Request type checking for a file.

Schedules analysis via the scheduler, which dispatches to the worker process.
Compilation does NOT happen in the main process - it happens in the worker
to bypass the GIL for CPU-bound type checking.
"""
impl JacLangServer.type_check(file_uri: str) -> None {
    try {
        document = self.workspace.get_text_document(file_uri);
        if document and document.source {
            # Route to scheduler -> worker (compilation in separate process)
            self.schedule_analysis(file_uri, document.source);
        }
    } except Exception as e {
        self.debug(f"Error getting document for type_check: {e}");
    }
}

"""Synchronous type check for testing.

Schedules analysis and waits for completion. This is a blocking call
that should only be used in tests, not in production LSP handlers.

Returns True if analysis completed, False on error.
"""
impl JacLangServer.type_check_file(file_uri: str) -> bool {
    try {
        document = self.workspace.get_text_document(file_uri);
        if document and document.source {
            # Schedule analysis
            self.schedule_analysis(file_uri, document.source);
            # Wait for completion (blocking)
            self.wait_till_idle_sync();
            return True;
        }
        return False;
    } except Exception as e {
        self.debug(f"Error in type_check_file: {e}");
        return False;
    }
}

"""Update modules in JacProgram's hub and semantic managers."""
impl JacLangServer.update_modules(
    file_path: str, build: uni.Module, need: bool = True
) -> None {
    self.log_py(f"'Updating modules for '{file_path}");
    self.module_manager.update(file_path, build, update_annexed=need);
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

"""Schedule a file for analysis."""
impl JacLangServer.schedule_analysis(file_uri: str, source: str) -> None {
    if self._scheduler is not None {
        self._scheduler.schedule_file(file_uri, source);
    }
}

"""Called when a file is opened in the editor."""
impl JacLangServer.on_file_opened(file_uri: str) -> None {
    if self._scheduler is not None {
        self._scheduler.mark_file_open(file_uri);
    }
}

"""Called when a file is closed in the editor."""
impl JacLangServer.on_file_closed(file_uri: str) -> None {
    if self._scheduler is not None {
        self._scheduler.mark_file_closed(file_uri);
    }
}

"""Called when a file gains focus in the editor."""
impl JacLangServer.on_file_focused(file_uri: str) -> None {
    if self._scheduler is not None {
        self._scheduler.set_focused_file(file_uri);
    }
}

"""Handle diagnostics from the scheduler.

Called when the worker completes analysis and provides a new snapshot.
"""
impl JacLangServer._on_scheduler_diagnostics(snapshot: ProgramSnapshot) -> None {
    # Sync snapshot to main process state
    self._sync_snapshot_to_state(snapshot);

    # Publish diagnostics for all files in the snapshot
    for file_path in snapshot.hub.keys() {
        uri = uris.from_fs_path(file_path);
        diagnostics = utils.gen_diagnostics(
            file_path, snapshot.errors, snapshot.warnings
        );
        self.publish_diagnostics(uri, diagnostics);
    }

    # Refresh semantic tokens
    try {
        self.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
    } except Exception as e {
        self.debug(f"Failed to refresh semantic tokens: {e}");
    }
}

"""Sync snapshot data to main process state.

Updates mod.hub and recreates sem_managers from the snapshot.
This runs in the main process after receiving a snapshot from the worker.
Uses LockManager for thread-safe updates.
"""
impl JacLangServer._sync_snapshot_to_state(snapshot: ProgramSnapshot) -> None {
    # Acquire write locks in consistent order to prevent deadlocks
    # Order: hub_lock -> sem_managers_lock (as defined in LockManager)
    try {
        self._lock_manager.hub_lock.acquire_write();
        try {
            self._lock_manager.sem_managers_lock.acquire_write();
            try {
                # Update the hub with snapshot data
                for (path, module) in snapshot.hub.items() {
                    self.mod.hub[path] = module;
                    # Recreate semantic manager for this module
                    self.sem_managers[path] = SemTokManager(ir=module, hub=self.mod.hub);
                }

                # Update errors and warnings
                self.errors_had = list(snapshot.errors);
                self.warnings_had = list(snapshot.warnings);
            } finally {
                self._lock_manager.sem_managers_lock.release_write();
            }
        } finally {
            self._lock_manager.hub_lock.release_write();
        }
    } except Exception as e {
        self.debug(f"Error syncing snapshot: {e}");
    }

    self.debug(f"Synced snapshot version {snapshot.version} to state");
}

"""Register a pending LSP request for cancellation tracking."""
impl JacLangServer.register_request(request_id: str) -> CancellationToken {
    source = CancellationTokenSource();
    with self._pending_requests_lock {
        self._pending_requests[request_id] = source;
    }
    return source.token;
}

"""Unregister a completed LSP request."""
impl JacLangServer.unregister_request(request_id: str) -> None {
    with self._pending_requests_lock {
        if request_id in self._pending_requests {
            source = self._pending_requests.pop(request_id);
            source.dispose();
        }  
    }
}

"""Cancel a pending LSP request (called from $/cancelRequest handler)."""
impl JacLangServer.cancel_request(request_id: str) -> None {
    with self._pending_requests_lock {
        if request_id in self._pending_requests {
            source = self._pending_requests[request_id];
            source.cancel();
            self.debug(f"Cancelled request {request_id}");
        }
    }
}

"""Get current snapshot for queries (non-blocking)."""
impl JacLangServer.get_current_snapshot -> Optional[ProgramSnapshot] {
    if self._snapshot_manager is not None {
        return self._snapshot_manager.get_snapshot();
    }
    return None;
}
