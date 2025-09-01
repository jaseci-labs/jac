"""Living Workspace of Jac project."""

import asyncio;
import logging;
import time;
import from concurrent.futures { ThreadPoolExecutor }
import from typing { Callable, Optional }

import jaclang.compiler.unitree as uni;
import from jaclang { JacMachineInterface as Jac }
import from jaclang.compiler.constant {SymbolType}
import from jaclang.compiler.program { JacProgram }
import from jaclang.compiler.type_system.types{ ClassType}
import from jaclang.compiler.unitree { UniScopeNode }
import from sem_manager { SemTokManager }
import from jaclang.vendor.pygls { uris }
import from jaclang.vendor.pygls.server { LanguageServer }

import lsprotocol.types as lspt;
import utils;


"""Handles Jac module, semantic manager, and alert management."""
class ModuleManager {
    """Initialize ModuleManager."""
    def init(self: ModuleManager, program: JacProgram, sem_managers: <>dict) -> None {
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
        file_path = file_path.removeprefix('file://');
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
        self.program.errors_had =
            [ e for e in self.program.errors_had if e.loc.mod_path != file_path_fs ];
        self.program.warnings_had =
            [ w for w in self.program.warnings_had if w.loc.mod_path != file_path_fs ];
    }
}


"""Jac Language Server, manages JacProgram and LSP."""
class JacLangServer(JacProgram , LanguageServer) {
    """Initialize JacLangServer."""
    def init(self: JacLangServerV2) -> None {
        LanguageServer.init(self, 'jac-lsp', 'v0.1');
        JacProgram.init(self);
        self.executor = ThreadPoolExecutor();
        self.tasks: <>dict[(str, asyncio.Task)] = {};
        self.sem_managers: <>dict[(str, SemTokManager)] = {};
        self.module_manager = ModuleManager(self, self.sem_managers);
    }

    """Return diagnostics for all files as a dict {uri: diagnostics}."""
    @ property
    def diagnostics(self: JacLangServer, ) -> <>dict[str, <>list] {
        result = {};
        for file_path in self.mod.hub {
            uri = uris.from_fs_path(file_path);
            result[uri] =
                utils.gen_diagnostics(uri, self.errors_had, self.warnings_had);
        }
        return result;
    }

    """Remove errors and warnings for a specific file from the lists."""
    def _clear_alerts_for_file(self: JacLangServer, file_path_fs: str) -> None {
        self.module_manager.clear_alerts_for_file(file_path_fs);
    }

    """Get IR for a file path."""
    def get_ir(self: JacLangServer, file_path: str) -> Optional[uni.Module] {
        file_path = file_path.removeprefix('file://');
        return self.mod.hub.get(file_path);
    }

    """Update modules in JacProgram's hub and semantic managers."""
    def update_modules(
        self: JacLangServer,
        file_path: str,
        build: uni.Module,
        need: bool = True
    ) -> None {
        self.log_py(f"'Updating modules for '{file_path}");
        self.module_manager.update(file_path, build, update_annexed=need);
    }

    """Rebuild a file (syntax only)."""
    def quick_check(self: JacLangServer, file_path: str) -> bool {
        try {
            file_path_fs = file_path.removeprefix('file://');
            document = self.workspace.get_text_document(file_path);
            self._clear_alerts_for_file(file_path_fs);
            build = self.compile(use_str=document.source, file_path=document.path);
            self.update_modules(file_path_fs, build, need=False);
            self.publish_diagnostics(
                file_path,
                utils.gen_diagnostics(file_path, self.errors_had, self.warnings_had)
            );
            build_errors =
                [ e for e in self.errors_had if e.loc.mod_path == file_path_fs ];
            return len(build_errors) == 0;
        } except Exception as e {
            self.log_error(f"'Error during syntax check: '{e}");
            return False;
        }
    }

    """Rebuild a file and its dependencies (typecheck)."""
    def deep_check(
        self: JacLangServer,
        file_path: str,
        annex_view: Optional[str] = None
    ) -> bool {
        try {
            start_time = time.time();
            file_path_fs = file_path.removeprefix('file://');
            document = self.workspace.get_text_document(file_path);
            self._clear_alerts_for_file(file_path_fs);
            build = self.build(use_str=document.source, file_path=document.path,type_check=True);
            self.update_modules(file_path_fs, build);
            if build.annexable_by {
                return self.deep_check(
                    uris.from_fs_path(build.annexable_by),
                    annex_view=file_path
                );
            }
            self.publish_diagnostics(
                annex_view if annex_view else file_path,
                utils.gen_diagnostics(
                    annex_view if annex_view else file_path,
                    self.errors_had,
                    self.warnings_had
                )
            );
            if annex_view {
                self.publish_diagnostics(
                    file_path,
                    utils.gen_diagnostics(file_path, self.errors_had, self.warnings_had)
                );
            }
            self.log_py(
                f"'PROFILE: Deep check took '{(time.time() - start_time)}' seconds.'"
            );
            return len(self.errors_had) == 0;
        } except Exception as e {
            self.log_py(f"'Error during deep check: '{e}");
            return False;
        }
    }

    """Analyze and publish diagnostics."""
    async def launch_quick_check(self: JacLangServer, uri: str) -> bool {
        return await asyncio.get_event_loop().run_in_executor(
            self.executor,
            self.quick_check,
            uri
        );
    }

    """Analyze and publish diagnostics."""
    async def launch_deep_check(self: JacLangServer, uri: str) -> None {
        async def run_in_executor(
            func: Callable[([str, Optional[str]], bool)],
            file_path: str,
            annex_view: Optional[str] = None
        ) -> None {
            loop = asyncio.get_event_loop();
            await loop.run_in_executor(self.executor, func, file_path, annex_view);
        }
        if uri in self.tasks and not self.tasks[uri].done()  {
            self.log_py(f"'Canceling '{uri}' deep check...'");
            self.tasks[uri].cancel();
            del (self.tasks[uri], ) ;
        }
        self.log_py(f"'Analyzing '{uri}'...'");
        task = asyncio.create_task(run_in_executor(self.deep_check, uri));
        self.tasks[uri] = task;
        await task;
    }

    """Return completion for a file."""
    def get_completion(
        self: JacLangServer,
        file_path: str,
        position: lspt.Position,
        completion_trigger: Optional[str]
    ) -> lspt.CompletionList {
        try {
            document = self.workspace.get_text_document(file_path);
            mod_ir = self.get_ir(file_path);
            if not mod_ir {
                return lspt.CompletionList(is_incomplete=False, items=[]);
            }
            current_line = document.lines[position.line];
            current_pos = position.character;
            current_symbol_path = utils.parse_symbol_path(current_line, current_pos);
            builtin_mod =
                next(
                    ( mod for (name, mod) in self.mod.hub.items() if 'builtins' in name )
                );
            builtin_tab = builtin_mod.sym_tab;
            assert isinstance(builtin_tab, UniScopeNode) ;
            completion_items = [];
            node_selected =
                utils.find_deepest_symbol_node_at_pos(
                    mod_ir,
                    position.line,
                    (position.character - 2)
                );
            mod_tab = mod_ir.sym_tab if not node_selected else node_selected.sym_tab;
            current_symbol_table = mod_tab;
            if completion_trigger == '.' {
                if current_symbol_path {
                    temp_tab = mod_tab;
                    for symbol in current_symbol_path {
                        if symbol == 'self' {
                            is_ability_def =
                                temp_tab
                                if isinstance(temp_tab, uni.ImplDef)
                                else temp_tab.find_parent_of_type(uni.ImplDef);
                            if not is_ability_def {
                                archi_owner =
                                    mod_tab.find_parent_of_type(uni.Archetype);
                                temp_tab =
                                    archi_owner.sym_tab
                                    if archi_owner and archi_owner.sym_tab
                                    else mod_tab;
                                continue;
                            } else {
                                archi_owner =
                                    is_ability_def.decl_link.find_parent_of_type(
                                        uni.Archetype
                                    )
                                    if is_ability_def.decl_link
                                    else None;
                                temp_tab =
                                    archi_owner.sym_tab
                                    if archi_owner and archi_owner.sym_tab
                                    else temp_tab;
                                continue;
                            }
                        }
                        symb = temp_tab.lookup(symbol);
                        if symb {
                            fetc_tab = symb.symbol_table;
                            if fetc_tab {
                                temp_tab = fetc_tab;
                            } else {
                                temp_tab =
                                    symb.defn[0].type_sym_tab
                                    if symb.defn[0].type_sym_tab
                                    else temp_tab;
                            }
                        } else {
                            break;
                        }
                    }
                    completion_items += utils.collect_all_symbols_in_scope(
                        temp_tab,
                        up_tree=False
                    );
                    if isinstance(temp_tab, uni.Archetype) and temp_tab.base_classes  {
                        base = [];
                        for base_name in temp_tab.base_classes {
                            if isinstance(base_name, uni.Name) and base_name.sym  {
                                base.append(base_name.sym);
                            }
                        }
                        for base_class_symbol in base {
                            if base_class_symbol.symbol_table {
                                completion_items += utils.collect_all_symbols_in_scope(
                                    base_class_symbol.symbol_table,
                                    up_tree=False
                                );
                            }
                        }
                    }
                }
            } elif node_selected and node_selected.find_parent_of_type(uni.Archetype)
            or node_selected.find_parent_of_type(uni.ImplDef)
             {
                self_symbol =

                    [lspt.CompletionItem(
                        label='self',
                        kind=lspt.CompletionItemKind.Variable
                    )];
            } else {
                self_symbol = [];
            }
            return lspt.CompletionList(is_incomplete=False, items=completion_items);
        } except Exception as e {
            self.log_py(f"'Error during completion: '{e}");
            return lspt.CompletionList(is_incomplete=False, items=[]);
        }
    }

    """Rename module."""
    def rename_module(self: JacLangServer, old_path: str, new_path: str) -> None {
        if old_path in self.mod.hub and new_path != old_path  {
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
    def formatted_jac(self: JacLangServer, file_path: str) -> <>list[lspt.TextEdit] {
        try {
            document = self.workspace.get_text_document(file_path);
            formatted_text =
                JacProgram.jac_str_formatter(
                    source_str=document.source,
                    file_path=document.path
                );
        } except Exception as e {
            self.log_error(f"'Error during formatting: '{e}");
            formatted_text = document.source;
        }
        return
        [lspt.TextEdit(
            range=lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(
                    line=(len(document.source.splitlines()) + 1),
                    character=0
                )
            ),
            new_text=formatted_text
        )];
    }

    """Return hover information for a file."""
    def get_hover_info(
        self: JacLangServer,
        file_path: str,
        position: lspt.Position
    ) -> Optional[lspt.Hover] {
        file_path_fs = file_path.removeprefix('file://');
        if file_path_fs not in self.mod.hub {
            return None;
        }
        sem_mgr = self.sem_managers.get(file_path_fs);
        if not sem_mgr {
            return None;
        }
        token_index =
            utils.find_index(sem_mgr.sem_tokens, position.line, position.character);
        if token_index is None {
            return None;
        }
        node_selected = sem_mgr.static_sem_tokens[token_index][3];
        value = self.get_node_info(node_selected) if node_selected else None;
        if value {
            return lspt.Hover(
                contents=lspt.MarkupContent(
                    kind=lspt.MarkupKind.PlainText,
                    value=f"{value}"
                )
            );
        }
        return None;
    }

    """Extract meaningful information from the AST node."""
    def get_node_info(self: JacLangServer, <>node: uni.AstSymbolNode) -> Optional[str] {
        try {
            if isinstance(<>node, uni.NameAtom) {
                <>node = <>node.name_of;
            }
            access = (<>node.sym.access.value + ' ') if <>node.sym else None;
            node_info =
                f"'('{access if access else ''}{<>node.sym_category.value}') '{<>node.sym_name}";
            if <>node.name_spec.clean_type {
                node_info += f"': '{<>node.name_spec.clean_type}";
            }
            if isinstance(<>node,uni.AstSymbolNode) and isinstance(<>node.name_spec.type,ClassType) {
                node_info += f"': '{<>node.name_spec.type.shared.class_name}";
            }
            if isinstance(<>node, uni.AstDocNode) and <>node.doc  {
                node_info += f"'\n'{<>node.doc.value}";
            }
            if isinstance(<>node, uni.Ability) and <>node.signature  {
                node_info += f"'\n'{<>node.signature.unparse()}";
            }
        } except AttributeError as e {
            self.log_warning(f"'Attribute error when accessing node attributes: '{e}");
        }
        return node_info.strip();
    }

    """Return document symbols for a file."""
    def get_outline(self: JacLangServer, file_path: str) -> <>list[lspt.DocumentSymbol] {
        file_path_fs = file_path.removeprefix('file://');
        if file_path_fs in self.mod.hub
        and (root_node := self.mod.hub[file_path_fs].sym_tab)
         {
            return utils.get_symbols_for_outline(root_node);
        }
        return [];
    }

    """Return definition location for a file."""
    def get_definition(
        self: JacLangServer,
        file_path: str,
        position: lspt.Position
    ) -> Optional[lspt.Location] {
        file_path_fs = file_path.removeprefix('file://');
        if file_path_fs not in self.mod.hub {
            return None;
        }
        sem_mgr = self.sem_managers.get(file_path_fs);
        if not sem_mgr {
            return None;
        }
        token_index =
            utils.find_index(sem_mgr.sem_tokens, position.line, position.character);
        if token_index is None {
            return None;
        }
        node_selected = sem_mgr.static_sem_tokens[token_index][3];
        if node_selected {
            if (node_selected.sym.sym_type == SymbolType.MODULE) {
                spec = node_selected.sym.decl.parent.resolve_relative_path();
                if spec {
                    spec = spec[ 5 : ] if spec.startswith('File:') else spec;
                    return lspt.Location(
                        uri=uris.from_fs_path(spec),
                        range=lspt.Range(
                            start=lspt.Position(line=0, character=0),
                            end=lspt.Position(line=0, character=0)
                        )
                    );
                } else {
                    return None;
                }
            }
            if isinstance(node_selected.sym, uni.NameAtom) {
                node_selected = node_selected.name_of;
            }
            elif isinstance(node_selected, uni.Name)
            and node_selected.parent
            and isinstance(node_selected.parent, uni.ModulePath)
             {
                spec = node_selected.parent.parent.abs_path;
                if spec {
                    spec = spec[ 5 : ] if spec.startswith('File:') else spec;
                    return lspt.Location(
                        uri=uris.from_fs_path(spec),
                        range=lspt.Range(
                            start=lspt.Position(line=0, character=0),
                            end=lspt.Position(line=0, character=0)
                        )
                    );
                } else {
                    return None;
                }
            } elif node_selected.parent
            and isinstance(node_selected.parent, uni.ModuleItem)
             {
                path =
                    node_selected.parent.abs_path
                    or node_selected.parent.from_mod_path.abs_path
                    ;
                loc_range = (0, 0, 0, 0);
                if path and loc_range  {
                    path = path[ 5 : ] if path.startswith('File:') else path;
                    return lspt.Location(
                        uri=uris.from_fs_path(path),
                        range=lspt.Range(
                            start=lspt.Position(
                                line=loc_range[0],
                                character=loc_range[1]
                            ),
                            end=lspt.Position(line=loc_range[2], character=loc_range[3])
                        )
                    );
                }
            } elif isinstance(node_selected, uni.ElementStmt) {
                return None;
            }
            decl_node =
                node_selected.parent.body.target
                if node_selected.parent
                and isinstance(node_selected.parent, uni.AstImplNeedingNode)
                and isinstance(node_selected.parent.body, uni.ImplDef)

                else node_selected.sym.decl
                if node_selected.sym and node_selected.sym.decl
                else node_selected;
            if isinstance(decl_node, list) {
                valid_path = decl_node[0].loc.mod_path;
            } else {
                valid_path = decl_node.loc.mod_path;
            }
            decl_uri = uris.from_fs_path(valid_path);
            if isinstance(decl_node, list) {
                valid_range = decl_node[0].loc;
            } else {
                valid_range = decl_node.loc;
            }
            try {
                decl_range = utils.create_range(valid_range);
            } except ValueError {
                return None;
            }
            decl_location = lspt.Location(uri=decl_uri, range=decl_range);
            return decl_location;
        } else {
            return None;
        }
    }

    """Return references for a file."""
    def get_references(
        self: JacLangServer,
        file_path: str,
        position: lspt.Position
    ) -> <>list[lspt.Location] {
        file_path_fs = file_path.removeprefix('file://');
        if file_path_fs not in self.mod.hub {
            return [];
        }
        sem_mgr = self.sem_managers.get(file_path_fs);
        if not sem_mgr {
            return [];
        }
        index1 =
            utils.find_index(sem_mgr.sem_tokens, position.line, position.character);
        if index1 is None {
            return [];
        }
        node_selected = sem_mgr.static_sem_tokens[index1][3];
        if node_selected and node_selected.sym  {
            list_of_references: <>list[lspt.Location] =
                [ lspt.Location(
                    uri=uris.from_fs_path(<>node.loc.mod_path),
                    range=utils.create_range(<>node.loc)
                ) for <>node in node_selected.sym.uses ];
            return list_of_references;
        }
        return [];
    }

    """Rename a symbol in a file."""
    def rename_symbol(
        self: JacLangServer,
        file_path: str,
        position: lspt.Position,
        new_name: str
    ) -> Optional[lspt.WorkspaceEdit] {
        file_path_fs = file_path.removeprefix('file://');
        if file_path_fs not in self.mod.hub {
            return None;
        }
        sem_mgr = self.sem_managers.get(file_path_fs);
        if not sem_mgr {
            return None;
        }
        index1 =
            utils.find_index(sem_mgr.sem_tokens, position.line, position.character);
        if index1 is None {
            return None;
        }
        node_selected = sem_mgr.static_sem_tokens[index1][3];
        if node_selected and node_selected.sym  {
            changes: <>dict[(str, <>list[lspt.TextEdit])] = {};
            for <>node in [*node_selected.sym.uses, node_selected.sym.defn[0]] {
                key = uris.from_fs_path(<>node.loc.mod_path);
                new_edit =
                    lspt.TextEdit(
                        range=utils.create_range(<>node.loc),
                        new_text=new_name
                    );
                utils.add_unique_text_edit(changes, key, new_edit);
            }
            return lspt.WorkspaceEdit(changes=changes);
        }
        return None;
    }

    """Return semantic tokens for a file."""
    def get_semantic_tokens(self: JacLangServer, file_path: str) -> lspt.SemanticTokens {
        file_path_fs = file_path.removeprefix('file://');
        sem_mgr = self.sem_managers.get(file_path_fs);
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
