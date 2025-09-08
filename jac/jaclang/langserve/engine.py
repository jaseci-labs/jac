"""Living Workspace of Jac project."""
from __future__ import annotations
from jaclang.runtimelib.builtin import *
from jaclang import JacMachineInterface as _
import asyncio
import logging
import time
from concurrent.futures import ThreadPoolExecutor
from typing import Callable, Optional
import jaclang.compiler.unitree as uni
from jaclang import JacMachineInterface as Jac
from jaclang.compiler.constant import SymbolType
from jaclang.compiler.program import JacProgram
from jaclang.compiler.type_system.types import ClassType
from jaclang.compiler.unitree import UniScopeNode
from jaclang.langserve.sem_manager import SemTokManager
import jaclang.langserve.utils as utils
from jaclang.vendor.pygls import uris
from jaclang.vendor.pygls.server import LanguageServer
import lsprotocol.types as lspt


class JacLangServer(LanguageServer):
    """Jac Language Server, manages JacProgram and LSP."""

    def __init__(self: JacLangServer) -> None:
        """Initialize JacLangServer."""
        LanguageServer.__init__(self, 'jac-lsp', 'v0.1')
        # DON'T inherit from JacProgram - create instances per operation
        # Limit thread pool to prevent resource exhaustion during rapid typing
        self.executor = ThreadPoolExecutor(max_workers=2)
        # Task tracking for cancellation (separate for quick and deep checks)
        self.tasks: dict[str, asyncio.Task] = {}  # Deep check tasks
        self.quick_tasks: dict[str, asyncio.Task] = {}  # Quick check tasks
        self.sem_managers: dict[str, SemTokManager] = {}
        
        # Main program for shared module storage (protected by locks)
        self._main_program = JacProgram()
        self._program_lock = asyncio.Lock()
        
        # Add debouncing timers for rapid typing (separate for quick and deep checks)
        self.debounce_timers: dict[str, asyncio.Handle] = {}
        self.quick_debounce_timers: dict[str, asyncio.Handle] = {}

    @property
    def diagnostics(self: JacLangServer) -> dict[str, list]:
        """Return diagnostics for all files as a dict {uri: diagnostics}."""
        result = {}
        # Note: Reading mod.hub is safe since it's only modified in update_modules which is locked
        for file_path in self._main_program.mod.hub:
            uri = uris.from_fs_path(file_path)
            # We should lock when reading errors/warnings, but this is a sync property
            # Consider making this async or use a different approach for production
            result[uri] = utils.gen_diagnostics(file_path, self._main_program.errors_had, self._main_program.warnings_had)
        return result

    async def _clear_alerts_for_file(self: JacLangServer, file_path: str) -> None:
        """Remove errors and warnings for a specific file from the lists."""
        async with self._program_lock:
            self._main_program.errors_had = [e for e in self._main_program.errors_had if e.loc.mod_path != file_path]
            self._main_program.warnings_had = [w for w in self._main_program.warnings_had if w.loc.mod_path != file_path]

    def get_ir(self: JacLangServer, file_path: str) -> Optional[uni.Module]:
        """Get IR for a file path."""
        return self._main_program.mod.hub.get(file_path)

    async def update_modules(self: JacLangServer, file_path: str, build: uni.Module, need: bool=True) -> None:
        """Update modules in JacProgram's hub and semantic managers."""
        self.log_py(f'Updating modules for {file_path}')
        # Thread-safe module update
        async with self._program_lock:
            self._main_program.mod.hub[file_path] = build
        if need:
            self.sem_managers[file_path] = SemTokManager(ir=build)
            for p, mod in self._main_program.mod.hub.items():
                if p != file_path:
                    self.sem_managers[p] = SemTokManager(ir=mod)

    async def quick_check(self: JacLangServer, file_path: str) -> bool:
        """Rebuild a file (syntax only) - Thread-safe version."""
        try:
            start_time = time.time()
            document = self.workspace.get_text_document(file_path)
            fs_path = document.path
            self.log_py(f'PROFILE: Quick check - Document retrieval took {time.time() - start_time:.4f}s')
            
            # Create thread-local JacProgram instance to avoid conflicts
            thread_program = JacProgram()
            
            parse_start = time.time()
            await self._clear_alerts_for_file(fs_path)
            build = thread_program.compile(use_str=document.source, file_path=fs_path)
            self.log_py(f'PROFILE: Quick check - Parsing took {time.time() - parse_start:.4f}s')
            
            update_start = time.time()
            await self.update_modules(fs_path, build, need=False)
            # Copy errors from thread-local instance to main program with locking
            async with self._program_lock:
                self._main_program.errors_had.extend(thread_program.errors_had)
                self._main_program.warnings_had.extend(thread_program.warnings_had)
            self.log_py(f'PROFILE: Quick check - Module update took {time.time() - update_start:.4f}s')
            
            diag_start = time.time()
            # Need to read errors under lock for diagnostics
            async with self._program_lock:
                errors_copy = [e for e in self._main_program.errors_had if e.loc.mod_path == fs_path]
                warnings_copy = [w for w in self._main_program.warnings_had if w.loc.mod_path == fs_path]
            self.publish_diagnostics(file_path, utils.gen_diagnostics(fs_path, errors_copy, warnings_copy))
            self.log_py(f'PROFILE: Quick check - Diagnostics took {time.time() - diag_start:.4f}s')
            
            total_time = time.time() - start_time
            self.log_py(f'PROFILE: Quick check total time: {total_time:.4f}s, errors: {len(errors_copy)}')
            return len(errors_copy) == 0
        except Exception as e:
            self.log_error(f'Error during syntax check: {e}')
            return False

    async def deep_check(self: JacLangServer, file_path: str, annex_view: Optional[str]=None) -> bool:
        """Rebuild a file and its dependencies (typecheck) - Thread-safe version."""
        try:
            start_time = time.time()
            document = self.workspace.get_text_document(file_path)
            fs_path = document.path
            self.log_py(f'PROFILE: Deep check - Document retrieval took {time.time() - start_time:.4f}s')
            
            # Create thread-local JacProgram instance to avoid conflicts
            thread_program = JacProgram()
            
            clear_start = time.time()
            await self._clear_alerts_for_file(fs_path)
            self.log_py(f'PROFILE: Deep check - Alert clearing took {time.time() - clear_start:.4f}s')
            
            build_start = time.time()
            build = thread_program.build(use_str=document.source, file_path=document.path, type_check=True)
            build_time = time.time() - build_start
            self.log_py(f'PROFILE: Deep check - Build (including parsing) took {build_time:.4f}s')
            
            update_start = time.time()
            await self.update_modules(fs_path, build)
            # Copy errors from thread-local instance to main program with locking
            async with self._program_lock:
                self._main_program.errors_had.extend(thread_program.errors_had)
                self._main_program.warnings_had.extend(thread_program.warnings_had)
            self.log_py(f'PROFILE: Deep check - Module update took {time.time() - update_start:.4f}s')
            
            if build.annexable_by:
                recursive_start = time.time()
                result = await self.deep_check(uris.from_fs_path(build.annexable_by), annex_view=fs_path)
                self.log_py(f'PROFILE: Deep check - Recursive check took {time.time() - recursive_start:.4f}s')
                return result
                
            diag_start = time.time()
            # Need to read errors under lock for diagnostics
            async with self._program_lock:
                errors_copy = list(self._main_program.errors_had)
                warnings_copy = list(self._main_program.warnings_had)
            
            self.publish_diagnostics(uris.from_fs_path(annex_view) if annex_view else uris.from_fs_path(fs_path), utils.gen_diagnostics(annex_view if annex_view else fs_path, errors_copy, warnings_copy))
            if annex_view:
                self.publish_diagnostics(uris.from_fs_path(fs_path), utils.gen_diagnostics(fs_path, errors_copy, warnings_copy))
            self.log_py(f'PROFILE: Deep check - Diagnostics took {time.time() - diag_start:.4f}s')
            
            total_time = time.time() - start_time
            self.log_py(f'PROFILE: Deep check total time: {total_time:.4f}s, errors: {len(errors_copy)}')
            return len(errors_copy) == 0
        except Exception as e:
            self.log_py(f'Error during deep check: {e}')
            return False

    async def launch_quick_check(self: JacLangServer, uri: str) -> bool:
        """Analyze and publish diagnostics with task cancellation."""
        
        # Cancel any existing quick check task for this URI
        if uri in self.quick_tasks and not self.quick_tasks[uri].done():
            self.log_py(f'Canceling existing quick check for {uri}...')
            self.quick_tasks[uri].cancel()
            try:
                await self.quick_tasks[uri]
            except asyncio.CancelledError:
                pass
            del self.quick_tasks[uri]

        self.log_py(f'Starting quick check for {uri}...')
        start_time = time.time()
        
        try:
            # Create task and track it for potential cancellation
            task = asyncio.create_task(self.quick_check(uri))
            self.quick_tasks[uri] = task
            result = await task
            self.log_py(f'PROFILE: Quick check task completed in {time.time() - start_time:.4f} seconds for {uri}')
            return result
        except asyncio.CancelledError:
            self.log_py(f'Quick check cancelled for {uri}')
            return False
        except Exception as e:
            self.log_py(f'Error in launch_quick_check: {e}')
            return False
        finally:
            if uri in self.quick_tasks:
                del self.quick_tasks[uri]

    async def launch_deep_check(self: JacLangServer, uri: str) -> None:
        """Analyze and publish diagnostics."""
        
        # Cancel any existing task for this URI
        if uri in self.tasks and not self.tasks[uri].done():
            self.log_py(f'Canceling existing deep check for {uri}...')
            self.tasks[uri].cancel()
            try:
                await self.tasks[uri]
            except asyncio.CancelledError:
                pass
            del self.tasks[uri]

        self.log_py(f'Starting deep check for {uri}...')
        start_time = time.time()
        
        try:
            # Now call directly since deep_check is async
            task = asyncio.create_task(self.deep_check(uri))
            self.tasks[uri] = task
            await task
            self.log_py(f'PROFILE: Deep check task completed in {time.time() - start_time:.4f} seconds for {uri}')
        except asyncio.CancelledError:
            self.log_py(f'Deep check cancelled for {uri}')
        except Exception as e:
            self.log_py(f'Error in launch_deep_check: {e}')
        finally:
            if uri in self.tasks:
                del self.tasks[uri]

    def cancel_debounce_timer(self: JacLangServer, uri: str) -> None:
        """Cancel existing debounce timer for a URI (deep check)."""
        if uri in self.debounce_timers:
            self.debounce_timers[uri].cancel()
            del self.debounce_timers[uri]

    def cancel_quick_debounce_timer(self: JacLangServer, uri: str) -> None:
        """Cancel existing quick check debounce timer for a URI."""
        if uri in self.quick_debounce_timers:
            self.quick_debounce_timers[uri].cancel()
            del self.quick_debounce_timers[uri]

    async def debounced_quick_check(self: JacLangServer, uri: str, delay: float = 0.2) -> None:
        """Launch quick check with debouncing to prevent rapid successive calls during typing."""
        # Cancel existing timer
        self.cancel_quick_debounce_timer(uri)
        
        # Also cancel any running quick check task for this URI
        if uri in self.quick_tasks and not self.quick_tasks[uri].done():
            self.log_py(f'Canceling running quick check task for debounced operation: {uri}')
            self.quick_tasks[uri].cancel()
            try:
                await self.quick_tasks[uri]
            except asyncio.CancelledError:
                pass
            if uri in self.quick_tasks:
                del self.quick_tasks[uri]
        
        def delayed_quick_check():
            asyncio.create_task(self.launch_quick_check(uri))
        
        loop = asyncio.get_event_loop()
        handle = loop.call_later(delay, delayed_quick_check)
        self.quick_debounce_timers[uri] = handle

    async def debounced_deep_check(self: JacLangServer, uri: str, delay: float = 0.5) -> None:
        """Launch deep check with debouncing to prevent rapid successive calls."""
        # Cancel existing timer
        self.cancel_debounce_timer(uri)
        
        # Also cancel any running deep check task for this URI
        if uri in self.tasks and not self.tasks[uri].done():
            self.log_py(f'Canceling running deep check task for debounced operation: {uri}')
            self.tasks[uri].cancel()
            try:
                await self.tasks[uri]
            except asyncio.CancelledError:
                pass
            if uri in self.tasks:
                del self.tasks[uri]
        
        def delayed_deep_check():
            asyncio.create_task(self.launch_deep_check(uri))
        
        loop = asyncio.get_event_loop()
        handle = loop.call_later(delay, delayed_deep_check)
        self.debounce_timers[uri] = handle


    def get_completion(self: JacLangServer, file_path: str, position: lspt.Position, completion_trigger: Optional[str]) -> lspt.CompletionList:
        """Return completion for a file."""
        try:
            document = self.workspace.get_text_document(file_path)
            mod_ir = self.get_ir(document.path)
            if not mod_ir:
                return lspt.CompletionList(is_incomplete=False, items=[])
            current_line = document.lines[position.line]
            current_pos = position.character
            current_symbol_path = utils.parse_symbol_path(current_line, current_pos)
            builtin_mod = next((mod for name, mod in self._main_program.mod.hub.items() if 'builtins' in name))
            builtin_tab = builtin_mod.sym_tab
            assert isinstance(builtin_tab, UniScopeNode)
            completion_items = []
            node_selected = utils.find_deepest_symbol_node_at_pos(mod_ir, position.line, position.character - 2)
            mod_tab = mod_ir.sym_tab if not node_selected else node_selected.sym_tab
            current_symbol_table = mod_tab
            if completion_trigger == '.':
                if current_symbol_path:
                    temp_tab = mod_tab
                    for symbol in current_symbol_path:
                        if symbol == 'self':
                            is_ability_def = temp_tab if isinstance(temp_tab, uni.ImplDef) else temp_tab.find_parent_of_type(uni.ImplDef)
                            if not is_ability_def:
                                archi_owner = mod_tab.find_parent_of_type(uni.Archetype)
                                temp_tab = archi_owner.sym_tab if archi_owner and archi_owner.sym_tab else mod_tab
                                continue
                            else:
                                archi_owner = is_ability_def.decl_link.find_parent_of_type(uni.Archetype) if is_ability_def.decl_link else None
                                temp_tab = archi_owner.sym_tab if archi_owner and archi_owner.sym_tab else temp_tab
                                continue
                        symb = temp_tab.lookup(symbol)
                        if symb:
                            fetc_tab = symb.symbol_table
                            if fetc_tab:
                                temp_tab = fetc_tab
                            else:
                                temp_tab = symb.defn[0].type_sym_tab if symb.defn[0].type_sym_tab else temp_tab
                        else:
                            break
                    completion_items += utils.collect_all_symbols_in_scope(temp_tab, up_tree=False)
                    if isinstance(temp_tab, uni.Archetype) and temp_tab.base_classes:
                        base = []
                        for base_name in temp_tab.base_classes:
                            if isinstance(base_name, uni.Name) and base_name.sym:
                                base.append(base_name.sym)
                        for base_class_symbol in base:
                            if base_class_symbol.symbol_table:
                                completion_items += utils.collect_all_symbols_in_scope(base_class_symbol.symbol_table, up_tree=False)
            elif node_selected and node_selected.find_parent_of_type(uni.Archetype) or node_selected.find_parent_of_type(uni.ImplDef):
                self_symbol = [lspt.CompletionItem(label='self', kind=lspt.CompletionItemKind.Variable)]
            else:
                self_symbol = []
            return lspt.CompletionList(is_incomplete=False, items=completion_items)
        except Exception as e:
            self.log_py(f'Error during completion: {e}')
            return lspt.CompletionList(is_incomplete=False, items=[])

    async def rename_module(self: JacLangServer, old_path: str, new_path: str) -> None:
        """Rename module."""
        async with self._program_lock:
            if old_path in self._main_program.mod.hub and new_path != old_path:
                self._main_program.mod.hub[new_path] = self._main_program.mod.hub[old_path]
                del self._main_program.mod.hub[old_path]
        # Sem managers can be updated outside the lock since they're not shared across requests
        if old_path in self.sem_managers:
            self.sem_managers[new_path] = self.sem_managers[old_path]
            del self.sem_managers[old_path]

    async def delete_module(self: JacLangServer, uri: str) -> None:
        """Delete module."""
        async with self._program_lock:
            if uri in self._main_program.mod.hub:
                del self._main_program.mod.hub[uri]
        # Sem managers can be updated outside the lock since they're not shared across requests  
        if uri in self.sem_managers:
            del self.sem_managers[uri]

    def formatted_jac(self: JacLangServer, file_path: str) -> list[lspt.TextEdit]:
        """Return formatted jac."""
        try:
            document = self.workspace.get_text_document(file_path)
            formatted_text = JacProgram.jac_str_formatter(source_str=document.source, file_path=document.path)
        except Exception as e:
            self.log_error(f'Error during formatting: {e}')
            formatted_text = document.source
        return [lspt.TextEdit(range=lspt.Range(start=lspt.Position(line=0, character=0), end=lspt.Position(line=len(document.source.splitlines()) + 1, character=0)), new_text=formatted_text)]

    def get_hover_info(self: JacLangServer, file_path: str, position: lspt.Position) -> Optional[lspt.Hover]:
        """Return hover information for a file."""
        fs_path = uris.to_fs_path(file_path)
        if fs_path not in self._main_program.mod.hub:
            return None
        sem_mgr = self.sem_managers.get(fs_path)
        if not sem_mgr:
            return None
        token_index = utils.find_index(sem_mgr.sem_tokens, position.line, position.character)
        if token_index is None:
            return None
        node_selected = sem_mgr.static_sem_tokens[token_index][3]
        value = self.get_node_info(node_selected) if node_selected else None
        if value:
            return lspt.Hover(contents=lspt.MarkupContent(kind=lspt.MarkupKind.PlainText, value=f'{value}'))
        return None

    def get_node_info(self: JacLangServer, sym_node: uni.AstSymbolNode) -> Optional[str]:
        """Extract meaningful information from the AST node."""
        try:
            if isinstance(sym_node, uni.NameAtom):
                sym_node = sym_node.name_of
            access = sym_node.sym.access.value + ' ' if sym_node.sym else None
            node_info = f"({(access if access else '')}{sym_node.sym_category.value}) {sym_node.sym_name}"
            if sym_node.name_spec.clean_type:
                node_info += f': {sym_node.name_spec.clean_type}'
            if isinstance(sym_node, uni.AstSymbolNode) and isinstance(sym_node.name_spec.type, ClassType):
                node_info += f': {sym_node.name_spec.type.shared.class_name}'
            if isinstance(sym_node, uni.AstDocNode) and sym_node.doc:
                node_info += f'\n{sym_node.doc.value}'
            if isinstance(sym_node, uni.Ability) and sym_node.signature:
                node_info += f'\n{sym_node.signature.unparse()}'
        except AttributeError as e:
            self.log_warning(f'Attribute error when accessing node attributes: {e}')
        return node_info.strip()

    def get_outline(self: JacLangServer, file_path: str) -> list[lspt.DocumentSymbol]:
        """Return document symbols for a file."""
        fs_path = uris.to_fs_path(file_path)
        if fs_path in self._main_program.mod.hub and (root_node := self._main_program.mod.hub[fs_path].sym_tab):
            return utils.get_symbols_for_outline(root_node)
        return []

    def get_definition(self: JacLangServer, file_path: str, position: lspt.Position) -> Optional[lspt.Location]:
        """Return definition location for a file."""
        fs_path = uris.to_fs_path(file_path)
        if fs_path not in self._main_program.mod.hub:
            return None
        sem_mgr = self.sem_managers.get(fs_path)
        if not sem_mgr:
            return None
        token_index = utils.find_index(sem_mgr.sem_tokens, position.line, position.character)
        if token_index is None:
            return None
        node_selected = sem_mgr.static_sem_tokens[token_index][3]
        if node_selected:
            if node_selected.sym.sym_type == SymbolType.MODULE:
                spec = node_selected.sym.decl.parent.resolve_relative_path()
                if spec:
                    spec = spec[5:] if spec.startswith('File:') else spec
                    return lspt.Location(uri=uris.from_fs_path(spec), range=lspt.Range(start=lspt.Position(line=0, character=0), end=lspt.Position(line=0, character=0)))
                else:
                    return None
            if isinstance(node_selected.sym, uni.NameAtom):
                node_selected = node_selected.name_of
            elif isinstance(node_selected, uni.Name) and node_selected.parent and isinstance(node_selected.parent, uni.ModulePath):
                spec = node_selected.parent.parent.abs_path
                if spec:
                    spec = spec[5:] if spec.startswith('File:') else spec
                    return lspt.Location(uri=uris.from_fs_path(spec), range=lspt.Range(start=lspt.Position(line=0, character=0), end=lspt.Position(line=0, character=0)))
                else:
                    return None
            elif node_selected.parent and isinstance(node_selected.parent, uni.ModuleItem):
                path = node_selected.parent.abs_path or node_selected.parent.from_mod_path.abs_path
                loc_range = (0, 0, 0, 0)
                if path and loc_range:
                    path = path[5:] if path.startswith('File:') else path
                    return lspt.Location(uri=uris.from_fs_path(path), range=lspt.Range(start=lspt.Position(line=loc_range[0], character=loc_range[1]), end=lspt.Position(line=loc_range[2], character=loc_range[3])))
            elif isinstance(node_selected, uni.ElementStmt):
                return None
            decl_node = node_selected.parent.body.target if node_selected.parent and isinstance(node_selected.parent, uni.AstImplNeedingNode) and isinstance(node_selected.parent.body, uni.ImplDef) else node_selected.sym.decl if node_selected.sym and node_selected.sym.decl else node_selected
            if isinstance(decl_node, list):
                valid_path = decl_node[0].loc.mod_path
            else:
                valid_path = decl_node.loc.mod_path
            decl_uri = uris.from_fs_path(valid_path)
            if isinstance(decl_node, list):
                valid_range = decl_node[0].loc
            else:
                valid_range = decl_node.loc
            try:
                decl_range = utils.create_range(valid_range)
            except ValueError:
                return None
            decl_location = lspt.Location(uri=decl_uri, range=decl_range)
            return decl_location
        else:
            return None

    def get_references(self: JacLangServer, file_path: str, position: lspt.Position) -> list[lspt.Location]:
        """Return references for a file."""
        fs_path = uris.to_fs_path(file_path)
        if fs_path not in self._main_program.mod.hub:
            return []
        sem_mgr = self.sem_managers.get(fs_path)
        if not sem_mgr:
            return []
        index1 = utils.find_index(sem_mgr.sem_tokens, position.line, position.character)
        if index1 is None:
            return []
        node_selected = sem_mgr.static_sem_tokens[index1][3]
        if node_selected and node_selected.sym:
            list_of_references: list[lspt.Location] = [lspt.Location(uri=uris.from_fs_path(cur_node.loc.mod_path), range=utils.create_range(cur_node.loc)) for cur_node in node_selected.sym.uses]
            return list_of_references
        return []

    def rename_symbol(self: JacLangServer, file_path: str, position: lspt.Position, new_name: str) -> Optional[lspt.WorkspaceEdit]:
        """Rename a symbol in a file."""
        fs_path = uris.to_fs_path(file_path)
        if fs_path not in self._main_program.mod.hub:
            return None
        sem_mgr = self.sem_managers.get(fs_path)
        if not sem_mgr:
            return None
        index1 = utils.find_index(sem_mgr.sem_tokens, position.line, position.character)
        if index1 is None:
            return None
        node_selected = sem_mgr.static_sem_tokens[index1][3]
        if node_selected and node_selected.sym:
            changes: dict[str, list[lspt.TextEdit]] = {}
            for node in [*node_selected.sym.uses, node_selected.sym.defn[0]]:
                key = uris.from_fs_path(node.loc.mod_path)
                new_edit = lspt.TextEdit(range=utils.create_range(node.loc), new_text=new_name)
                utils.add_unique_text_edit(changes, key, new_edit)
            return lspt.WorkspaceEdit(changes=changes)
        return None

    def get_semantic_tokens(self: JacLangServer, file_path: str) -> lspt.SemanticTokens:
        """Return semantic tokens for a file."""
        fs_path = uris.to_fs_path(file_path)
        sem_mgr = self.sem_managers.get(fs_path)
        if not sem_mgr:
            return lspt.SemanticTokens(data=[])
        return lspt.SemanticTokens(data=sem_mgr.sem_tokens)

    def log_error(self: JacLangServer, message: str) -> None:
        """Log an error message."""
        self.show_message_log(message, lspt.MessageType.Error)
        self.show_message(message, lspt.MessageType.Error)

    def log_warning(self: JacLangServer, message: str) -> None:
        """Log a warning message."""
        self.show_message_log(message, lspt.MessageType.Warning)
        self.show_message(message, lspt.MessageType.Warning)

    def log_info(self: JacLangServer, message: str) -> None:
        """Log an info message."""
        self.show_message_log(message, lspt.MessageType.Info)
        self.show_message(message, lspt.MessageType.Info)

    def log_py(self: JacLangServer, message: str) -> None:
        """Log a message."""
        logging.info(message)

    def shutdown(self: JacLangServer) -> None:
        """Shutdown the language server and cleanup resources."""
        # Cancel all pending deep check tasks
        for uri, task in self.tasks.items():
            if not task.done():
                task.cancel()
        
        # Cancel all pending quick check tasks
        for uri, task in self.quick_tasks.items():
            if not task.done():
                task.cancel()
        
        # Cancel all debounce timers
        for uri, handle in self.debounce_timers.items():
            handle.cancel()
        
        # Cancel all quick debounce timers
        for uri, handle in self.quick_debounce_timers.items():
            handle.cancel()
        
        # Shutdown the thread pool executor
        self.executor.shutdown(wait=False)
