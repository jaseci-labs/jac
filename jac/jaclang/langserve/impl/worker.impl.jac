"""Worker process implementation.

Ports all compilation and FG request logic from the old engine.impl.jac.
The worker is dumb — it does whatever the main process asks, checking the
cancel_event during compilation.
"""

import from jaclang.cli.console { console }

# ── Helpers for serializing LSP-like data into dicts ──────────────────

def _range_to_dict(r: lspt.Range) -> dict {
    return {
        "start_line": r.start.line,
        "start_char": r.start.character,
        "end_line": r.end.line,
        "end_char": r.end.character
    };
}

def _loc_info_to_range_dict(loc: object) -> dict {
    """Convert a CodeLocInfo to a range dict."""
    return {
        "start_line": (loc.first_line - 1) if loc.first_line > 0 else 0,
        "start_char": (loc.col_start - 1) if loc.col_start > 0 else 0,
        "end_line": (loc.last_line - 1) if loc.last_line > 0 else 0,
        "end_char": (loc.col_end - 1) if loc.col_end > 0 else 0
    };
}

def _symbol_to_dict(sym: lspt.DocumentSymbol) -> dict {
    """Recursively convert a DocumentSymbol to a dict."""
    return {
        "name": sym.name,
        "kind": sym.kind.value,
        "range": _range_to_dict(sym.range),
        "selection_range": _range_to_dict(sym.selection_range),
        "children": [_symbol_to_dict(c) for c in (sym.children or [])]
    };
}

# ── Worker lifecycle ──────────────────────────────────────────────────

"""Initialize the worker."""
impl Worker.postinit -> None {
    self.program = JacProgram();
    self.module_manager = ModuleManager(self.program, self.sem_managers);
}

"""Debug logging."""
impl Worker.debug(msg: str) -> None {
    import sys;
    print(f"[Worker] {msg}", file=sys.stderr);
}

"""Main loop: receive command, dispatch, send response."""
impl Worker.run -> None {
    self.debug("Worker process started.");
    while True {
        try {
            cmd = self.conn.recv();
        } except (EOFError, OSError) {
            self.debug("Pipe closed, worker exiting.");
            break;
        }
        if cmd is None or cmd.get("type") == "shutdown" {
            self.debug("Shutdown received, worker exiting.");
            break;
        }
        # Drain any stale cancel signals before processing.
        self.cancel_event.clear();
        try {
            result = self.dispatch(cmd);
            if result is not None {
                self.conn.send(result);
            }
        } except Exception as e {
            self.debug(f"Error dispatching command: {e}");
            try {
                self.conn.send({"type": "error", "message": str(e)});
            } except (EOFError, OSError) {
                break;
            }
        }
    }
    self.debug("Worker process exited.");
}

"""Dispatch a command dict to the appropriate handler."""
impl Worker.dispatch(cmd: dict) -> dict | None {
    cmd_type = cmd["type"];
    if cmd_type == "compile" {
        return self.handle_compile(cmd["file_path"], cmd["source"]);
    } elif cmd_type == "hover" {
        return self.handle_hover(cmd["file_path"], cmd["line"], cmd["character"]);
    } elif cmd_type == "definition" {
        return self.handle_definition(cmd["file_path"], cmd["line"], cmd["character"]);
    } elif cmd_type == "references" {
        return self.handle_references(cmd["file_path"], cmd["line"], cmd["character"]);
    } elif cmd_type == "outline" {
        return self.handle_outline(cmd["file_path"]);
    } elif cmd_type == "semantic_tokens" {
        return self.handle_semantic_tokens(cmd["file_path"]);
    } elif cmd_type == "completion" {
        return self.handle_completion(
            cmd["file_path"], cmd["line"], cmd["character"], cmd.get("trigger")
        );
    } elif cmd_type == "rename" {
        return self.handle_rename(
            cmd["file_path"], cmd["line"], cmd["character"], cmd["new_name"]
        );
    } elif cmd_type == "format" {
        return self.handle_format(cmd["file_path"], cmd["source"]);
    } elif cmd_type == "delete_module" {
        self.handle_delete_module(cmd["file_path"]);
        return {"type": "ok"};
    } elif cmd_type == "rename_module" {
        self.handle_rename_module(cmd["old_path"], cmd["new_path"]);
        return {"type": "ok"};
    }
    return {"type": "error", "message": f"Unknown command: {cmd_type}"};
}

# ── Compilation ───────────────────────────────────────────────────────

"""Handle a compile request. Returns diagnostics or cancelled."""
impl Worker.handle_compile(file_path: str, source: str) -> dict {
    return self.type_check_file(file_path, source);
}

"""Collect diagnostics from program errors/warnings into a dict keyed by URI.

Checks both the main program and the compiler's internal_program (used for
jaclang.* files) so diagnostics appear regardless of which program was used.
"""
impl Worker._collect_diagnostics(
    file_path: str, annex_view: Optional[str] = None
) -> dict {
    # Gather errors/warnings from both programs (main + internal).
    all_errors = list(self.program.errors_had);
    all_warnings = list(self.program.warnings_had);
    try {
        internal = self.program._get_compiler().internal_program;
        if internal is not self.program {
            all_errors += internal.errors_had;
            all_warnings += internal.warnings_had;
        }
    } except Exception { ; }

    diagnostics: dict = {};
    target_path = annex_view or file_path;
    target_uri = uris.from_fs_path(target_path);
    diag_list = [];
    for error in all_errors {
        if error.loc.mod_path == target_path {
            diag_list.append({
                "start_line": (error.loc.first_line - 1) if error.loc.first_line > 0 else 0,
                "start_char": (error.loc.col_start - 1) if error.loc.col_start > 0 else 0,
                "end_line": (error.loc.last_line - 1) if error.loc.last_line > 0 else 0,
                "end_char": (error.loc.col_end - 1) if error.loc.col_end > 0 else 0,
                "message": error.msg,
                "severity": lspt.DiagnosticSeverity.Error.value
            });
        }
    }
    for warning in all_warnings {
        if warning.loc.mod_path == target_path {
            diag_list.append({
                "start_line": (warning.loc.first_line - 1) if warning.loc.first_line > 0 else 0,
                "start_char": (warning.loc.col_start - 1) if warning.loc.col_start > 0 else 0,
                "end_line": (warning.loc.last_line - 1) if warning.loc.last_line > 0 else 0,
                "end_char": (warning.loc.col_end - 1) if warning.loc.col_end > 0 else 0,
                "message": warning.msg,
                "severity": lspt.DiagnosticSeverity.Warning.value
            });
        }
    }
    diagnostics[target_uri] = diag_list;

    # If annex_view is set, also include diagnostics for the original file.
    if annex_view {
        annex_uri = uris.from_fs_path(file_path);
        annex_diag_list = [];
        for error in all_errors {
            if error.loc.mod_path == file_path {
                annex_diag_list.append({
                    "start_line": (error.loc.first_line - 1) if error.loc.first_line > 0 else 0,
                    "start_char": (error.loc.col_start - 1) if error.loc.col_start > 0 else 0,
                    "end_line": (error.loc.last_line - 1) if error.loc.last_line > 0 else 0,
                    "end_char": (error.loc.col_end - 1) if error.loc.col_end > 0 else 0,
                    "message": error.msg,
                    "severity": lspt.DiagnosticSeverity.Error.value
                });
            }
        }
        for warning in all_warnings {
            if warning.loc.mod_path == file_path {
                annex_diag_list.append({
                    "start_line": (warning.loc.first_line - 1) if warning.loc.first_line > 0 else 0,
                    "start_char": (warning.loc.col_start - 1) if warning.loc.col_start > 0 else 0,
                    "end_line": (warning.loc.last_line - 1) if warning.loc.last_line > 0 else 0,
                    "end_char": (warning.loc.col_end - 1) if warning.loc.col_end > 0 else 0,
                    "message": warning.msg,
                    "severity": lspt.DiagnosticSeverity.Warning.value
                });
            }
        }
        diagnostics[annex_uri] = annex_diag_list;
    }
    return diagnostics;
}

"""Compile a file, checking cancel_event during compilation."""
impl Worker.type_check_file(
    file_path: str,
    source: str,
    annex_view: Optional[str] = None
) -> dict {
    if self.cancel_event.is_set() {
        return {"type": "cancelled"};
    }
    success = False;
    # Clear old alerts for this file.
    self.module_manager.clear_alerts_for_file(file_path);
    try {
        build = self.program.compile(
            use_str=source,
            file_path=file_path,
            type_check=True,
            cancel_token=self.cancel_event
        );

        if self.cancel_event.is_set() {
            return {"type": "cancelled"};
        }

        # Update modules in hub and rebuild SemTokManagers.
        self.program.mod.hub[file_path] = build;
        hub = self.program.mod.hub;
        self.sem_managers[file_path] = SemTokManager(ir=build, hub=hub);
        for (p, mod) in hub.items() {
            if p != file_path {
                self.sem_managers[p] = SemTokManager(ir=mod, hub=hub);
            }
        }

        # Handle annexed files (impl files that need parent recompile).
        if build.annexable_by {
            annex_path = build.annexable_by;
            try {
                with open(annex_path, 'r') as f {
                    annex_source = f.read();
                }
                return self.type_check_file(
                    annex_path,
                    annex_source,
                    annex_view=file_path
                );
            } except Exception as e {
                self.debug(f"Error reading annexed file {annex_path}: {e}");
            }
        }
        success = True;
    } except Exception as e {
        self.debug(f"Error during type check: {e}");
    }

    # Always collect diagnostics — errors_had is populated even on syntax errors.
    diagnostics = self._collect_diagnostics(file_path, annex_view);
    return {"type": "compile_result", "diagnostics": diagnostics, "success": success};
}

# ── Foreground request handlers ───────────────────────────────────────

"""Handle hover request."""
impl Worker.handle_hover(file_path: str, line: int, character: int) -> dict {
    node_selected = self.get_token_at_position(file_path, line, character);
    value = self.get_node_info(node_selected) if node_selected else None;
    return {"type": "hover_result", "contents": value};
}

"""Handle go-to-definition request."""
impl Worker.handle_definition(file_path: str, line: int, character: int) -> dict {
    def make_loc_dict(node_: uni.UniNode, is_module: bool = False) -> dict {
        mod_path = node_.type.file_uri if is_module else node_.loc.mod_path;
        if is_module {
            return {
                "uri": uris.from_fs_path(str(mod_path)),
                "range": {"start_line": 0, "start_char": 0, "end_line": 0, "end_char": 0}
            };
        }
        return {
            "uri": uris.from_fs_path(node_.loc.mod_path),
            "range": _loc_info_to_range_dict(node_.loc)
        };
    }

    node_selected = self.get_token_at_position(file_path, line, character);
    if not node_selected {
        return {"type": "definition_result", "uri": None, "range": None};
    }

    node_type = node_selected.type;
    parent = node_selected.parent;

    # Check for impl body first (stub -> impl navigation).
    if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
        if isinstance(parent.body, uni.ImplDef) {
            loc = make_loc_dict(parent.body.sym.decl);
            return {"type": "definition_result", "uri": loc["uri"], "range": loc["range"]};
        }
    }

    # Handle go to def for types and variables.
    if node_type {
        if isinstance(node_type, ModuleType) {
            loc = make_loc_dict(node_selected, is_module=True);
            return {"type": "definition_result", "uri": loc["uri"], "range": loc["range"]};
        } elif isinstance(node_type, ClassType) {
            loc = make_loc_dict(node_selected.sym.decl);
            return {"type": "definition_result", "uri": loc["uri"], "range": loc["range"]};
        } elif isinstance(node_type, (FunctionType, OverloadedType)) {
            loc = make_loc_dict(node_selected.sym.decl);
            return {"type": "definition_result", "uri": loc["uri"], "range": loc["range"]};
        }
    }

    # Ad-hoc handling for impl-def go to def.
    if not parent {
        return {"type": "definition_result", "uri": None, "range": None};
    }
    if isinstance(parent, uni.ImplDef) and parent.decl_link {
        loc = make_loc_dict(parent.decl_link.sym.decl);
        return {"type": "definition_result", "uri": loc["uri"], "range": loc["range"]};
    }

    # Fallback: use symbol resolution if available.
    if node_selected.sym and node_selected.sym.defn {
        try {
            loc = make_loc_dict(node_selected.sym.defn[0]);
            return {"type": "definition_result", "uri": loc["uri"], "range": loc["range"]};
        } except Exception { }
    }
    return {"type": "definition_result", "uri": None, "range": None};
}

"""Handle references request."""
impl Worker.handle_references(file_path: str, line: int, character: int) -> dict {
    node_selected = self.get_token_at_position(file_path, line, character);
    locations = [];
    if node_selected and node_selected.sym {
        for cur_node in [*node_selected.sym.defn, *node_selected.sym.uses] {
            locations.append({
                "uri": uris.from_fs_path(cur_node.loc.mod_path),
                "range": _loc_info_to_range_dict(cur_node.loc)
            });
        }
    }
    return {"type": "references_result", "locations": locations};
}

"""Handle outline (document symbols) request."""
impl Worker.handle_outline(file_path: str) -> dict {
    fs_path = file_path;
    if fs_path in self.program.mod.hub
    and (root_node := self.program.mod.hub[fs_path].sym_tab) {
        symbols = get_symbols_for_outline(root_node);
        return {
            "type": "outline_result",
            "symbols": [_symbol_to_dict(s) for s in symbols]
        };
    }
    return {"type": "outline_result", "symbols": []};
}

"""Handle semantic tokens request."""
impl Worker.handle_semantic_tokens(file_path: str) -> dict {
    fs_path = file_path;
    sem_mgr = self.sem_managers.get(fs_path);
    if not sem_mgr {
        return {"type": "semantic_tokens_result", "data": []};
    }
    return {"type": "semantic_tokens_result", "data": sem_mgr.sem_tokens};
}

"""Handle completion request."""
impl Worker.handle_completion(
    file_path: str, line: int, character: int, trigger: Optional[str]
) -> dict {
    try {
        node_at_pos = self.get_node_at_position(file_path, line, character - 1);
        if node_at_pos {
            self.debug("found node at pos " + str(node_at_pos));
            if isinstance(node_at_pos, uni.Token) {
                if node_at_pos.name == "DOT" {
                    member_access = node_at_pos.parent;
                    if isinstance(member_access, uni.AtomTrailer) {
                        return {
                            "type": "completion_result",
                            "items": self.get_completion_of_node(member_access.target),
                            "is_incomplete": False
                        };
                    }
                } elif node_at_pos.name == "NAME" {
                    if (
                        node_at_pos.parent
                        and isinstance(node_at_pos.parent, uni.AtomTrailer)
                    ) {
                        return {
                            "type": "completion_result",
                            "items": self.get_completion_of_node(node_at_pos.parent.target),
                            "is_incomplete": False
                        };
                    }
                    if scope_node := node_at_pos.find_parent_of_type(uni.UniScopeNode) {
                        return {
                            "type": "completion_result",
                            "items": self.get_completion_of_node(scope_node),
                            "is_incomplete": False
                        };
                    }
                }
            }
        }
        return {"type": "completion_result", "items": [], "is_incomplete": False};
    } except Exception as e {
        self.debug(f"Error during completion: {e}");
        return {"type": "completion_result", "items": [], "is_incomplete": False};
    }
}

"""Handle rename request."""
impl Worker.handle_rename(
    file_path: str, line: int, character: int, new_name: str
) -> dict {
    node_selected = self.get_token_at_position(file_path, line, character);
    if node_selected and node_selected.sym {
        changes: dict = {};
        for node in [*node_selected.sym.uses, node_selected.sym.defn[0]] {
            key = uris.from_fs_path(node.loc.mod_path);
            r = _loc_info_to_range_dict(node.loc);
            edit = {
                "start_line": r["start_line"],
                "start_char": r["start_char"],
                "end_line": r["end_line"],
                "end_char": r["end_char"],
                "new_text": new_name
            };
            if key not in changes {
                changes[key] = [edit];
            } else {
                # Check for duplicates.
                is_dup = False;
                for existing in changes[key] {
                    if (existing["start_line"] == edit["start_line"]
                        and existing["start_char"] == edit["start_char"]
                        and existing["end_line"] == edit["end_line"]
                        and existing["end_char"] == edit["end_char"]) {
                        is_dup = True;
                        break;
                    }
                }
                if not is_dup {
                    changes[key].append(edit);
                }
            }
        }
        return {"type": "rename_result", "changes": changes};
    }
    return {"type": "rename_result", "changes": None};
}

"""Handle format request."""
impl Worker.handle_format(file_path: str, source: str) -> dict {
    try {
        prog = JacProgram.jac_str_formatter(
            source_str=source, file_path=file_path
        );
        formatted_text = prog.mod.main.gen.jac
        if not prog.errors_had
        else source;
    } except Exception as e {
        self.debug(f"Error during formatting: {e}");
        formatted_text = source;
    }
    num_lines = len(source.splitlines()) + 1;
    return {
        "type": "format_result",
        "edits": [{
            "start_line": 0,
            "start_char": 0,
            "end_line": num_lines,
            "end_char": 0,
            "new_text": formatted_text
        }]
    };
}

# ── Module management ─────────────────────────────────────────────────

"""Handle delete module."""
impl Worker.handle_delete_module(file_path: str) -> None {
    if file_path in self.program.mod.hub {
        del (self.program.mod.hub[file_path], );
    }
    if file_path in self.sem_managers {
        del (self.sem_managers[file_path], );
    }
}

"""Handle rename module."""
impl Worker.handle_rename_module(old_path: str, new_path: str) -> None {
    if old_path in self.program.mod.hub and new_path != old_path {
        self.program.mod.hub[new_path] = self.program.mod.hub[old_path];
        self.sem_managers[new_path] = self.sem_managers[old_path];
        del (self.program.mod.hub[old_path], );
        del (self.sem_managers[old_path], );
    }
}

# ── Internal helpers ──────────────────────────────────────────────────

"""Find the AST node at a given position using semantic tokens."""
impl Worker.get_token_at_position(
    file_path: str, line: int, character: int
) -> Optional[uni.AstNode] {
    if file_path not in self.program.mod.hub {
        return None;
    }
    sem_mgr = self.sem_managers.get(file_path);
    if not sem_mgr {
        return None;
    }
    token_index = find_index(sem_mgr.sem_tokens, line, character);
    if token_index is None {
        return None;
    }
    node_selected = sem_mgr.static_sem_tokens[token_index][3];
    return node_selected;
}

"""Find an AST node at a given position by scanning tokens."""
impl Worker.get_node_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.AstNode] {
    ast = self.program.mod.hub.get(file_path);
    if ast {
        for ast_node in ast._in_mod_nodes {
            if not isinstance(ast_node, uni.Token) {
                continue;
            }
            if position_within_node(ast_node, line + 1, col + 1) {
                return ast_node;
            }
        }
    }
    return None;
}

"""Extract meaningful information from an AST symbol node."""
impl Worker.get_node_info(sym_node: uni.AstSymbolNode) -> Optional[str] {
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
        self.debug(f"Attribute error when accessing node attributes: {e}");
    }
    return node_info.strip();
}

"""Return the type of an AST node if it has one."""
impl Worker.get_node_type(n: uni.AstNode) -> Optional[TypeBase] {
    if isinstance(n, uni.Expr) {
        typ = self.program.get_type_evaluator().get_type_of_expression(n);
        return typ;
    }
    return None;
}

"""Get completion items for a type or scope, returned as list of dicts."""
impl Worker.get_completion_items_of(ty: TypeBase | uni.UniScopeNode) -> list[dict] {
    evaluator = self.program.get_type_evaluator();
    items: list[dict] = [];
    for item in get_completion_items(ty) {
        items.append({
            "label": item.label,
            "kind": item.kind.value if item.kind else None,
            "detail": item.detail
        });
    }
    return items;
}

"""Get completion items for a node."""
impl Worker.get_completion_of_node(node: uni.AstNode) -> list[dict] {
    if (node_type := self.get_node_type(node)) {
        return self.get_completion_items_of(node_type);
    } elif isinstance(node, UniScopeNode) {
        return self.get_completion_items_of(node);
    }
    return [];
}

# ── Entry point ───────────────────────────────────────────────────────

"""Top-level entry point for the worker process."""
impl worker_main(conn: Connection, cancel_event: Event) -> None {
    w = Worker(conn=conn, cancel_event=cancel_event);
    w.run();
}
