"""Implementation of JacLangServer - simplified LSP engine.

Single worker process architecture:
- WorkerManager handles compilation with debounce scheduling
- Worker reads source from disk (saved files only)
- Foreground queries (hover, definition) handled in worker process
- Only lightweight diagnostics sent back to main process
"""

import threading;
import time;
import logging;


impl JacLangServer.postinit -> None {
    # Must call Python __init__ directly for parent classes
    LanguageServer.__init__(self, 'jac-lsp', 'v0.1');
    JacProgram.__init__(self);

    self._logger = logging.getLogger("jac.lsp");
    self.debug("Initializing JacLangServer...");

    self.module_manager = ModuleManager(self, self.sem_managers);

    # Initialize and start worker
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

impl JacLangServer.debug(msg: str) -> None {
    print(f"[Engine] {msg}", file=sys.stderr);
}

impl JacLangServer.log_py(message: str) -> None {
    logging.info(message);
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

impl JacLangServer.schedule_analysis(file_uri: str) -> None {
    # Worker reads source from disk (saved files only)
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

impl JacLangServer.type_check(file_uri: str) -> None {
    try {
        self.schedule_analysis(file_uri);
    } except Exception as e {
        self.debug(f"Error in type_check: {e}");
    }
}

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

impl JacLangServer.wait_till_idle -> None {
    if self._worker_manager is not None {
        while self._worker_manager.is_busy() {
            await asyncio.sleep(0.05);
        }
    }
}

impl JacLangServer.wait_till_idle_sync -> None {
    if self._worker_manager is not None {
        while self._worker_manager.is_busy() {
            time.sleep(0.05);
        }
    }
}

impl JacLangServer._on_worker_diagnostics(response: dict) -> None {
    # Check if server is ready to publish (lsp attribute must exist)
    if not hasattr(self, 'lsp') or not self.lsp {
        self.debug("Server not ready yet, skipping diagnostics");
        return;
    }

    # Handle lightweight dict format from worker
    diagnostics_data = response.get('diagnostics', {});
    file_path = response.get('file_path', '');
    hub_files = response.get('hub_files', []);

    self.debug(f"Diagnostics received: {file_path}, {len(hub_files)} files in hub");

    # Publish diagnostics for the compiled file
    if file_path {
        uri = uris.from_fs_path(file_path);
        diagnostics = utils.gen_diagnostics_from_dict(file_path, diagnostics_data);
        try {
            self.publish_diagnostics(uri, diagnostics);
        } except Exception { }
    }

    # Also publish for any other files that have diagnostics
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

    # Refresh semantic tokens
    try {
        self.lsp.send_request(lspt.WORKSPACE_SEMANTIC_TOKENS_REFRESH);
    } except Exception { }
}

# Response polling
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

# LSP features
impl JacLangServer.get_semantic_tokens(file_path: str) -> lspt.SemanticTokens {
    fs_path = uris.to_fs_path(file_path);

    # Try worker first
    if self._worker_manager and self._worker_manager.is_running() {
        try {
            response = self._worker_manager.request_semantic_tokens(fs_path, timeout_ms=2000);
            if response and response.get('success') and response.get('tokens') {
                return lspt.SemanticTokens(data=response.get('tokens'));
            }
        } except Exception { }
    }

    # Fallback to local
    try {
        sem_mgr = self.sem_managers.get(fs_path);
        if sem_mgr {
            return lspt.SemanticTokens(data=sem_mgr.sem_tokens);
        }
    } except Exception { }
    return lspt.SemanticTokens(data=[]);
}

impl JacLangServer.get_completion(
    file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
) -> lspt.CompletionList {
    fs_path = uris.to_fs_path(file_uri);

    # Try worker first
    if self._worker_manager and self._worker_manager.is_running() {
        try {
            response = self._worker_manager.request_completion(
                fs_path, position.line, position.character, completion_trigger, timeout_ms=2000
            );
            if response and response.get('success') {
                items = response.get('items', []);
                return lspt.CompletionList(
                    is_incomplete=False,
                    items=[
                        lspt.CompletionItem(
                            label=item.get('label', ''),
                            kind=lspt.CompletionItemKind(item.get('kind', 1)) if item.get('kind') else None,
                            label_details=lspt.CompletionItemLabelDetails(detail=item.get('detail')) if item.get('detail') else None
                        ) for item in items
                    ]
                );
            }
        } except Exception { }
    }

    # Fallback to local
    await self.wait_till_idle();
    try {
        file_path = uris.to_fs_path(file_uri);
        node_at_pos = self.get_node_at_position(file_path, position.line, position.character - 1);
        if node_at_pos and isinstance(node_at_pos, uni.Token) {
            if node_at_pos.name == "DOT" {
                member_access = node_at_pos.parent;
                if isinstance(member_access, uni.AtomTrailer) {
                    return self.get_completion_of_node(member_access.target);
                }
            } elif node_at_pos.name == "NAME" {
                if node_at_pos.parent and isinstance(node_at_pos.parent, uni.AtomTrailer) {
                    return self.get_completion_of_node(node_at_pos.parent.target);
                }
                if scope_node := node_at_pos.find_parent_of_type(uni.UniScopeNode) {
                    return self.get_completion_of_node(scope_node);
                }
            }
        }
    } except Exception { }
    return lspt.CompletionList(is_incomplete=False, items=[]);
}

impl JacLangServer.get_hover_info(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Hover] {
    fs_path = uris.to_fs_path(file_path);

    # Try worker first
    if self._worker_manager and self._worker_manager.is_running() {
        try {
            response = self._worker_manager.request_hover(fs_path, position.line, position.character, timeout_ms=2000);
            if response and response.get('success') {
                hover_text = response.get('hover_text');
                if hover_text {
                    return lspt.Hover(
                        contents=lspt.MarkupContent(kind=lspt.MarkupKind.PlainText, value=hover_text)
                    );
                }
            }
        } except Exception { }
    }

    # # Fallback to local
    # node_selected = self.get_token_at_position(file_path, position);
    # if node_selected {
    #     value = self.get_node_info(node_selected);
    #     if value {
    #         return lspt.Hover(
    #             contents=lspt.MarkupContent(kind=lspt.MarkupKind.PlainText, value=value)
    #         );
    #     }
    # }
    return None;
}

impl JacLangServer.get_definition(
    file_path: str, position: lspt.Position
) -> Optional[lspt.Location] {
    fs_path = uris.to_fs_path(file_path);

    # Try worker first
    if self._worker_manager and self._worker_manager.is_running() {
        try {
            response = self._worker_manager.request_definition(fs_path, position.line, position.character, timeout_ms=2000);
            if response and response.get('success') {
                loc = response.get('location');
                if loc {
                    return lspt.Location(
                        uri=uris.from_fs_path(loc.get('uri', '')),
                        range=lspt.Range(
                            start=lspt.Position(line=loc.get('line', 0), character=loc.get('character', 0)),
                            end=lspt.Position(line=loc.get('end_line', 0), character=loc.get('end_character', 0))
                        )
                    );
                }
            }
        } except Exception { }
    }

    # Fallback to local
    def make_location(node_: uni.UniNode, is_module: bool = False) -> lspt.Location {
        mod_path = node_.type.file_uri if is_module else node_.loc.mod_path;
        decl_range = (
            utils.create_range(node_.loc) if not is_module
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

    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        if isinstance(parent.body, uni.ImplDef) {
            return make_location(parent.body.sym.decl);
        }
    }

    if node_type {
        if isinstance(node_type, ModuleType) {
            return make_location(node_selected, is_module=True);
        } elif isinstance(node_type, ClassType) {
            return make_location(node_selected.sym.decl);
        } elif isinstance(node_type, (FunctionType, OverloadedType)) {
            return make_location(node_selected.sym.decl);
        }
    }

    if parent and isinstance(parent, uni.ImplDef) and parent.decl_link {
        return make_location(parent.decl_link.sym.decl);
    }

    if node_selected.sym and node_selected.sym.defn {
        try {
            return make_location(node_selected.sym.defn[0]);
        } except Exception { }
    }
    return None;
}

impl JacLangServer.get_references(
    file_path: str, position: lspt.Position
) -> list[lspt.Location] {
    fs_path = uris.to_fs_path(file_path);

    # Try worker first
    if self._worker_manager and self._worker_manager.is_running() {
        try {
            response = self._worker_manager.request_references(fs_path, position.line, position.character, timeout_ms=2000);
            if response and response.get('success') {
                locations = response.get('locations', []);
                return [
                    lspt.Location(
                        uri=uris.from_fs_path(loc.get('uri', '')),
                        range=lspt.Range(
                            start=lspt.Position(line=loc.get('line', 0), character=loc.get('character', 0)),
                            end=lspt.Position(line=loc.get('end_line', 0), character=loc.get('end_character', 0))
                        )
                    ) for loc in locations
                ];
            }
        } except Exception { }
    }

    # Fallback to local
    node_selected = self.get_token_at_position(file_path, position);
    if node_selected and node_selected.sym {
        return [
            lspt.Location(
                uri=uris.from_fs_path(cur_node.loc.mod_path),
                range=utils.create_range(cur_node.loc)
            ) for cur_node in node_selected.sym.uses
        ];
    }
    return [];
}

impl JacLangServer.rename_symbol(
    file_path: str, position: lspt.Position, new_name: str
) -> Optional[lspt.WorkspaceEdit] {
    fs_path = uris.to_fs_path(file_path);

    # Try worker first
    if self._worker_manager and self._worker_manager.is_running() {
        try {
            response = self._worker_manager.request_rename(
                fs_path, position.line, position.character, new_name, timeout_ms=3000
            );
            if response and response.get('success') {
                edits = response.get('edits', {});
                if edits {
                    changes: dict[(str, list[lspt.TextEdit])] = {};
                    for (uri_path, file_edits) in edits.items() {
                        key = uris.from_fs_path(uri_path);
                        for edit in file_edits {
                            new_edit = lspt.TextEdit(
                                range=lspt.Range(
                                    start=lspt.Position(line=edit.get('line', 0), character=edit.get('character', 0)),
                                    end=lspt.Position(line=edit.get('end_line', 0), character=edit.get('end_character', 0))
                                ),
                                new_text=edit.get('new_text', new_name)
                            );
                            utils.add_unique_text_edit(changes, key, new_edit);
                        }
                    }
                    return lspt.WorkspaceEdit(changes=changes);
                }
            }
        } except Exception { }
    }

    # Fallback to local
    node_selected = self.get_token_at_position(file_path, position);
    if node_selected and node_selected.sym {
        changes: dict[(str, list[lspt.TextEdit])] = {};
        for node in [*node_selected.sym.uses, node_selected.sym.defn[0]] {
            key = uris.from_fs_path(node.loc.mod_path);
            new_edit = lspt.TextEdit(range=utils.create_range(node.loc), new_text=new_name);
            utils.add_unique_text_edit(changes, key, new_edit);
        }
        return lspt.WorkspaceEdit(changes=changes);
    }
    return None;
}

impl JacLangServer.get_outline(file_path: str) -> list[lspt.DocumentSymbol] {
    fs_path = uris.to_fs_path(file_path);

    # Try worker first
    if self._worker_manager and self._worker_manager.is_running() {
        try {
            response = self._worker_manager.request_outline(fs_path, timeout_ms=2000);
            if response and response.get('success') {
                symbols_data = response.get('symbols', []);
                return self._convert_outline_dict_to_lsp(symbols_data);
            }
        } except Exception { }
    }

    # Fallback to local
    if fs_path in self.mod.hub and (root_node := self.mod.hub[fs_path].sym_tab) {
        return utils.get_symbols_for_outline(root_node);
    }
    return [];
}

impl JacLangServer._convert_outline_dict_to_lsp(symbols_data: list) -> list[lspt.DocumentSymbol] {
    # Convert outline dict format to LSP DocumentSymbol objects
    result = [];
    for sym in symbols_data {
        rng = sym.get('range', {});
        pos = lspt.Range(
            start=lspt.Position(line=rng.get('start_line', 0), character=rng.get('start_char', 0)),
            end=lspt.Position(line=rng.get('end_line', 0), character=rng.get('end_char', 0))
        );
        children = self._convert_outline_dict_to_lsp(sym.get('children', []));
        result.append(lspt.DocumentSymbol(
            name=sym.get('name', ''),
            kind=lspt.SymbolKind(sym.get('kind', 13)),  # 13 = Variable as default
            range=pos,
            selection_range=pos,
            children=children
        ));
    }
    return result;
}

impl JacLangServer.formatted_jac(file_path: str) -> list[lspt.TextEdit] {
    try {
        document = self.workspace.get_text_document(file_path);
        fs_path = uris.to_fs_path(file_path);
        formatted_text = document.source;

        # Try worker first
        if self._worker_manager and self._worker_manager.is_running() {
            try {
                response = self._worker_manager.request_format(fs_path, document.source, timeout_ms=5000);
                if response and response.get('success') {
                    formatted_text = response.get('formatted', document.source);
                }
            } except Exception { }
        } else {
            # Fallback to local
            prog = JacProgram.jac_str_formatter(source_str=document.source, file_path=document.path);
            formatted_text = prog.mod.main.gen.jac if not prog.errors_had else document.source;
        }
    } except Exception {
        formatted_text = document.source;
    }
    return [
        lspt.TextEdit(
            range=lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(line=(len(document.source.splitlines()) + 1), character=0)
            ),
            new_text=formatted_text
        )
    ];
}

# Helper methods
impl JacLangServer.get_token_at_position(
    file_path: str, position: lspt.Position
) -> Optional[uni.AstNode] {
    fs_path = uris.to_fs_path(file_path);
    try {
        if fs_path not in self.mod.hub {
            return None;
        }
        sem_mgr = self.sem_managers.get(fs_path);
        if not sem_mgr {
            return None;
        }
        token_index = utils.find_index(sem_mgr.sem_tokens, position.line, position.character);
        if token_index is not None {
            return sem_mgr.static_sem_tokens[token_index][3];
        }
    } except Exception { }
    return None;
}

impl JacLangServer.get_node_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.AstNode] {
    if (ast := self.get_ast_of_file(file_path)) {
        for ast_node in ast._in_mod_nodes {
            if isinstance(ast_node, uni.Token) and utils.position_within_node(ast_node, line + 1, col + 1) {
                return ast_node;
            }
        }
    }
    return None;
}

impl JacLangServer.get_ast_of_file(file_path: str) -> Optional[uni.AstNode] {
    return self.mod.hub.get(file_path);
}

impl JacLangServer.get_ir(file_path: str) -> Optional[uni.Module] {
    return self.mod.hub.get(file_path);
}

impl JacLangServer.get_node_info(sym_node: uni.AstSymbolNode) -> Optional[str] {
    try {
        if isinstance(sym_node, uni.NameAtom) {
            sym_node = sym_node.name_of;
        }
        access = (sym_node.sym.access.value + ' ') if sym_node.sym else None;
        node_info = f"({(access or '')}{sym_node.sym_category.value}) {sym_node.sym_name}";
        if sym_node.name_spec.clean_type {
            node_info += f": {sym_node.name_spec.clean_type}";
        }
        if isinstance(sym_node, uni.AstSymbolNode) and isinstance(sym_node.name_spec.type, ClassType) {
            node_info += f": {sym_node.name_spec.type.shared.class_name}";
        }
        if isinstance(sym_node, uni.AstDocNode) and sym_node.doc {
            node_info += f"\n{sym_node.doc.value}";
        }
        if isinstance(sym_node, uni.Ability) and sym_node.signature {
            node_info += f"\n{sym_node.signature.unparse()}";
        }
        return node_info.strip();
    } except AttributeError {
        return None;
    }
}

impl JacLangServer.get_node_type(n: uni.AstNode) -> Optional[TypeBase] {
    if isinstance(n, uni.Expr) {
        return self.get_type_evaluator().get_type_of_expression(n);
    }
    return None;
}

impl JacLangServer.get_completion_of_node(node: uni.AstNode) -> lspt.CompletionList {
    if (node_type := self.get_node_type(node)) {
        return self.get_completion_items_of(node_type);
    } elif isinstance(node, UniScopeNode) {
        return self.get_completion_items_of(node);
    }
    return lspt.CompletionList(is_incomplete=False, items=[]);
}

impl JacLangServer.get_completion_items_of(ty: TypeBase | uni.UniScopeNode) -> lspt.CompletionList {
    items: list[lspt.CompletionItem] = [];
    for item in get_completion_items(ty) {
        detail = lspt.CompletionItemLabelDetails(detail=item.detail) if item.detail else None;
        items.append(lspt.CompletionItem(label=item.label, kind=item.kind, label_details=detail));
    }
    return lspt.CompletionList(is_incomplete=False, items=items);
}

impl JacLangServer.update_modules(file_path: str, build: uni.Module, need: bool = True) -> None {
    self.module_manager.update(file_path, build, update_annexed=need);
}

impl JacLangServer._clear_alerts_for_file(file_path: str) -> None {
    self.module_manager.clear_alerts_for_file(file_path);
}

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

impl JacLangServer.diagnostics -> dict[str, list] {
    result = {};
    for file_path in self.mod.hub {
        uri = uris.from_fs_path(file_path);
        result[uri] = utils.gen_diagnostics(file_path, self.errors_had, self.warnings_had);
    }
    return result;
}
