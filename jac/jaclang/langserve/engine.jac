"""Living Workspace of Jac project."""

import asyncio;
import logging;
import os;
import sys;
import time;
import threading;
import from concurrent.futures { ThreadPoolExecutor }
import from typing { Callable, Optional }

import jaclang.compiler.unitree as uni;
import from jaclang { JacMachineInterface as Jac }
import from jaclang.compiler.constant { SymbolType }
import from jaclang.compiler.program { JacProgram }
import from jaclang.compiler.type_system.type_utils { get_completion_items }
import from jaclang.compiler.type_system.types {
    ClassType,
    FunctionType,
    ModuleType,
    TypeBase
}
import from jaclang.compiler.unitree { UniScopeNode }
import from .sem_manager { SemTokManager }
import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.server { LanguageServer }

import lsprotocol.types as lspt;
import from . { utils }


"""Handles Jac module, semantic manager, and alert management."""
class ModuleManager {
    """Initialize ModuleManager."""
    def init(self: ModuleManager, program: JacProgram, sem_managers: dict) -> None {
        self.program = program;
        self.sem_managers = sem_managers;
    }

    """Update modules in JacProgram's hub and semantic managers."""
    def update(
        self: ModuleManager,
        file_path: str,
        build: uni.Module,
        update_annexed: bool = True
    ) -> None {
        self.program.mod.hub[file_path] = build;
        if update_annexed {
            self.sem_managers[file_path] = SemTokManager(ir=build);
            for (p, mod) in self.program.mod.hub.items() {
                if p != file_path {
                    self.sem_managers[p] = SemTokManager(ir=mod);
                }
            }
        }
    }

    """Remove errors and warnings for a specific file from the lists."""
    def clear_alerts_for_file(self: ModuleManager, file_path_fs: str) -> None {
        self.program.errors_had = [
            e
            for e in self.program.errors_had
            if e.loc.mod_path != file_path_fs
        ];
        self.program.warnings_had = [
            w
            for w in self.program.warnings_had
            if w.loc.mod_path != file_path_fs
        ];
    }
}


"""Jac Language Server, manages JacProgram and LSP."""
class JacLangServer(JacProgram , LanguageServer) {
    """Initialize JacLangServer."""
    def init(self: JacLangServer) -> None {
        LanguageServer.init(self, 'jac-lsp', 'v0.1');
        JacProgram.init(self);
        self.sem_managers: dict[(str, SemTokManager)] = {};
        self.module_manager = ModuleManager(self, self.sem_managers);

        # Threading support - per file thread with cancellation token
        self.type_check_threads: dict[str, threading.Thread] = {};
        self.cancel_tokens: dict[str, threading.Event] = {};

        self.debounce_timers: dict[str, threading.Timer] = {};

        # Disable logging library from logging anything
        # logging.getLogger().setLevel(logging.CRITICAL);
    }

    """Return diagnostics for all files as a dict {uri: diagnostics}."""
    @property
    def diagnostics(self: JacLangServer,) -> dict[str, list] {
        result = {};
        for file_path in self.mod.hub {
            uri = uris.from_fs_path(file_path);
            result[uri] = utils.gen_diagnostics(
                file_path, self.errors_had, self.warnings_had
            );
        }
        return result;
    }

    """Remove errors and warnings for a specific file from the lists."""
    def _clear_alerts_for_file(self: JacLangServer, file_path: str) -> None {
        self.module_manager.clear_alerts_for_file(file_path);
    }

    """Get IR for a file path."""
    def get_ir(self: JacLangServer, file_path: str) -> Optional[uni.Module] {
        return self.mod.hub.get(file_path);
    }

    """Update modules in JacProgram's hub and semantic managers."""
    def update_modules(
        self: JacLangServer, file_path: str, build: uni.Module, need: bool = True
    ) -> None {
        self.log_py(f"'Updating modules for '{file_path}");
        self.module_manager.update(file_path, build, update_annexed=need);
    }

    """Rebuild a file and its dependencies (typecheck)."""
    def type_check_file(
        self: JacLangServer, file_path: str,cancel_token: Event | None = None, annex_view: Optional[str] = None
    ) -> bool {
        try {
            start_time = time.time();
            document = self.workspace.get_text_document(file_path);
            fs_path = document.path;
            self._clear_alerts_for_file(fs_path);

            t = time.time();
            f = file_path.split("/")[-1].split("\\")[-1];
            self.debug("Type checking started for " + f + " t=" + str(t));

            build = self.compile(
                use_str=document.source, file_path=document.path, type_check=True
            );
            self.debug(f"     'Type checking for '{f}' done {str(time.time())} in '{(time.time() - t)}' seconds.'");
            if cancel_token and cancel_token.is_set(){
                self.debug("      ** Type checking canceled for " + f + " t=" + str(time.time()));
                self.debug(f"     'Type checking for '{f}' was canceled in '{(time.time() - t)}' seconds.'");
                return;
            }

            self.update_modules(fs_path, build);
            if build.annexable_by {
                return self.type_check_file(
                    uris.from_fs_path(build.annexable_by), cancel_token=cancel_token, annex_view=fs_path
                );
            }
            self.publish_diagnostics(
                (
                    # to display diagnostic , it need URI starts with "file://"
                    uris.from_fs_path(
                        annex_view
                    )
                    if annex_view
                    else uris.from_fs_path(fs_path)
                ),
                utils.gen_diagnostics(
                    (annex_view if annex_view else fs_path),
                    self.errors_had,
                    self.warnings_had
                )
            );
            if annex_view {
                self.publish_diagnostics(
                    uris.from_fs_path(fs_path),
                    utils.gen_diagnostics(fs_path, self.errors_had, self.warnings_had)
                );
            }
            self.log_py(
                f"'PROFILE: Deep check took '{(time.time() - start_time)}' seconds.'"
            );
        } except Exception as e {
            if cancel_token and not cancel_token.is_set() {
                self.log_py(f"'Error during type check: '{e}");
            }
        }
    }

    """Check if debounce timer is active for a file."""
    def is_debounce_active(self: JacLangServer, file_path: str) -> bool {
        return (
            file_path in self.debounce_timers and
            self.debounce_timers[file_path].is_alive()
        );
    }

    """Check if type check thread is active for a file."""
    def is_type_check_thread_active(self: JacLangServer, file_path: str) -> bool {
        return (
            file_path in self.type_check_threads and
            self.type_check_threads[file_path].is_alive()
        );
    }

    """Type check with thread cancellation and proper debouncing."""
    async def type_check(self: JacLangServer, file_path: str) -> None {
        # Cancel existing debounce timer for this file
        if file_path in self.debounce_timers {
            self.debounce_timers[file_path].cancel();
        }

        # Cancel existing type check thread for this file if running
        if file_path in self.cancel_tokens {
            self.cancel_tokens[file_path].set();
        }

        # Create new cancellation token for the upcoming type check
        self.cancel_tokens[file_path] = threading.Event();

        # Create a debounced function that will run the actual type check
        def debounced_type_check() -> None {
            # Start new thread for type checking
            print(" debounced_type_check ->", time.time(), file=sys.stderr);
            self.type_check_threads[file_path] = threading.Thread(
                target=self.type_check_file,
                args=(file_path, self.cancel_tokens[file_path])
            );
            self.type_check_threads[file_path].start();
            self.type_check_threads[file_path].join();
        }

        # Set up debounce timer with the actual type check function
        self.debounce_timers[file_path] = threading.Timer(0.5, debounced_type_check);
        self.debounce_timers[file_path].start();

        # Wait for the current type check thread to finish (if any)
        await asyncio.to_thread(self.debounce_timers[file_path].join);

    }

    def get_token_at_position(
        self: JacLangServer, file_path: str, position: lspt.Position
    ) -> Optional[uni.AstNode] {
        fs_path = uris.to_fs_path(file_path);
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
    }

    def debug(self: JacLangServer, msg: str) -> None {
        print(f"[DEBUG] {msg}", file=sys.stderr);
        self.log_py(f"[DEBUG] {msg}");
    }

    """Return completion for a file."""
    def get_completion(
        self: JacLangServer,
        file_uri: str,
        position: lspt.Position,
        completion_trigger: Optional[str]
    ) -> lspt.CompletionList {
        self.debug("getting completion for " + file_uri + " at " + str(position));
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
                            return self.get_completion_of_node(
                                node_at_pos.parent.target
                            );
                        }
                        # Just a name field.
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
        self.debug("returning empty list");
    }

    def get_ast_of_file(self: JacLangServer, file_path: str) -> Optional[uni.AstNode] {
        if file_path in self.mod.hub {
            return self.mod.hub[file_path];
        }
        return None;
    }

    def get_node_at_position(
        self: JacLangServer, file_path: str, line: int, col: int
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

    def get_completion_of_node(
        self: JacLangServer, node: uni.AstNode
    ) -> lspt.CompletionList {
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

    """Return the type of an AST node if it has one."""
    def get_node_type(self: JacLangServer, n: uni.AstNode) -> Optional[TypeBase] {
        if isinstance(n, uni.Expr) {
            typ = self.get_type_evaluator().get_type_of_expression(n);
            self.debug("found type " + str(typ) + " for expr " + str(n));
            return typ;
        }
        self.debug("no type found for node " + str(n));
        return None;
    }

    """Get type members for completion."""
    def get_completion_items_of(
        self: JacLangServer, ty: TypeBase | uni.UniScopeNode
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

    """Rename module."""
    def rename_module(self: JacLangServer, old_path: str, new_path: str) -> None {
        if old_path in self.mod.hub and new_path != old_path {
            self.mod.hub[new_path] = self.mod.hub[old_path];
            self.sem_managers[new_path] = self.sem_managers[old_path];
            del (self.mod.hub[old_path], ) ;
            del (self.sem_managers[old_path], ) ;
        }
    }

    """Delete module."""
    def delete_module(self: JacLangServer, uri: str) -> None {
        if uri in self.mod.hub {
            del (self.mod.hub[uri], ) ;
        }
        if uri in self.sem_managers {
            del (self.sem_managers[uri], ) ;
        }
    }

    """Return formatted jac."""
    def formatted_jac(self: JacLangServer, file_path: str) -> list[lspt.TextEdit] {
        try {
            document = self.workspace.get_text_document(file_path);
            formatted_text = JacProgram.jac_str_formatter(
                source_str=document.source, file_path=document.path
            );
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

    """Return hover information for a file."""
    def get_hover_info(
        self: JacLangServer, file_path: str, position: lspt.Position
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

    """Extract meaningful information from the AST node."""
    def get_node_info(
        self: JacLangServer, sym_node: uni.AstSymbolNode
    ) -> Optional[str] {
        try {
            if isinstance(sym_node, uni.NameAtom) {
                sym_node = sym_node.name_of;
            }
            access = (sym_node.sym.access.value + ' ') if sym_node.sym else None;
            node_info = f"'('{(access if access else '')}{sym_node.sym_category.value}') '{sym_node.sym_name}";
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

    """Return document symbols for a file."""
    def get_outline(self: JacLangServer, file_path: str) -> list[lspt.DocumentSymbol] {
        fs_path = uris.to_fs_path(file_path);
        if fs_path in self.mod.hub and (root_node := self.mod.hub[fs_path].sym_tab) {
            return utils.get_symbols_for_outline(root_node);
        }
        return [];
    }

    """Return definition location for a file."""
    def get_definition(
        self: JacLangServer, file_path: str, position: lspt.Position
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
            return lspt.Location(
                uri=uris.from_fs_path(str(mod_path)), range=decl_range
            );
        }
        node_selected = self.get_token_at_position(file_path, position);
        if not node_selected {
            return None;
        }
        node_type = node_selected.type;
        ####################################################################
         ##          Handle go to def for types and variables               ##
         ####################################################################
         if node_type {
            if isinstance(node_type, ModuleType) {
                return make_location(node_selected, is_module=True);
            } elif isinstance(node_type, ClassType) {
                return make_location(node_selected.sym.decl);
            } elif isinstance(node_type, FunctionType) {
                return make_location(node_selected.sym.decl);
            }
        }
        ####################################################################
        ##         Ad-hoc handling for impl-def go to def                 ##
        ####################################################################
        parent = node_selected.parent;
        if not parent {
            return None;
        }
        if isinstance(parent, uni.ImplDef) and parent.decl_link {
            return make_location(parent.decl_link.sym.decl);
        }
        if isinstance(parent, uni.AstImplNeedingNode) and parent.body {
            return make_location(parent.body.sym.decl);
        }
        if not node_selected or not node_selected.type {
            return None;
        }
        return None;
    }

    """Return references for a file."""
    def get_references(
        self: JacLangServer, file_path: str, position: lspt.Position
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

    """Rename a symbol in a file."""
    def rename_symbol(
        self: JacLangServer, file_path: str, position: lspt.Position, new_name: str
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

    """Return semantic tokens for a file."""
    def get_semantic_tokens(self: JacLangServer, file_path: str) -> lspt.SemanticTokens {
        fs_path = uris.to_fs_path(file_path);
        sem_mgr = self.sem_managers.get(fs_path);
        if not sem_mgr {
            return lspt.SemanticTokens(data=[]);
        }
        return lspt.SemanticTokens(data=sem_mgr.sem_tokens);
    }

    """Log an error message."""
    def log_error(self: JacLangServer, message: str) -> None {
        self.show_message_log(message, lspt.MessageType.Error);
        self.show_message(message, lspt.MessageType.Error);
    }

    """Log a warning message."""
    def log_warning(self: JacLangServer, message: str) -> None {
        self.show_message_log(message, lspt.MessageType.Warning);
        self.show_message(message, lspt.MessageType.Warning);
    }

    """Log an info message."""
    def log_info(self: JacLangServer, message: str) -> None {
        self.show_message_log(message, lspt.MessageType.Info);
        self.show_message(message, lspt.MessageType.Info);
    }

    """Log a message."""
    def log_py(self: JacLangServer, message: str) -> None {
        logging.info(message);
    }

}
