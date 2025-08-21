"""Binding Pass for the Jac compiler."""

import ast as py_ast
import os
from typing import Optional

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import UniPass
from jaclang.compiler.unitree import UniScopeNode
from jaclang.runtimelib.utils import read_file_with_encoding


class BinderPass(UniPass):
    """Jac Binder pass."""

    def before_pass(self) -> None:
        """Before pass."""
        if self.prog.mod.main == self.ir_in:
            self.load_builtins()
        self.scope_stack: list[UniScopeNode] = []
        self.globals_stack: list[list[uni.Symbol]] = []

    ###########################################################
    ## Helper functions for symbol table stack manipulations ##
    ###########################################################
    def push_scope_and_link(self, key_node: uni.UniScopeNode) -> None:
        """Add scope into scope stack."""
        if not len(self.scope_stack):
            self.scope_stack.append(key_node)
        else:
            self.scope_stack.append(self.cur_scope.link_kid_scope(key_node=key_node))

    def pop_scope(self) -> UniScopeNode:
        """Remove current scope from scope stack."""
        return self.scope_stack.pop()

    @property
    def cur_scope(self) -> UniScopeNode:
        """Return current scope."""
        return self.scope_stack[-1]

    @property
    def cur_globals(self) -> list[uni.Symbol]:
        """Get current global symbols."""
        if len(self.globals_stack):
            return self.globals_stack[-1]
        else:
            return []

    # TODO: Every call for this function should be moved to symbol table it self
    def check_global(self, node_name: str) -> Optional[uni.Symbol]:
        """Check if symbol exists in global scope."""
        for symbol in self.cur_globals:
            if symbol.sym_name == node_name:
                return symbol
        return None

    @property
    def cur_module_scope(self) -> UniScopeNode:
        """Return the current module."""
        return self.scope_stack[0]

    ###############################################
    ## Handling for nodes that creates new scope ##
    ###############################################
    SCOPE_NODES = (
        uni.MatchCase,
        uni.DictCompr,
        uni.ListCompr,
        uni.GenCompr,
        uni.SetCompr,
        uni.LambdaExpr,
        uni.WithStmt,
        uni.WhileStmt,
        uni.InForStmt,
        uni.IterForStmt,
        uni.TryStmt,
        uni.Except,
        uni.FinallyStmt,
        uni.IfStmt,
        uni.ElseIf,
        uni.ElseStmt,
        uni.TypedCtxBlock,
        uni.Module,
        uni.Ability,
        uni.Test,
        uni.Archetype,
        uni.ImplDef,
        uni.SemDef,
        uni.Enum,
    )

    GLOBAL_STACK_NODES = (uni.Ability, uni.Archetype)

    def enter_node(self, node: uni.UniNode) -> None:
        if isinstance(node, self.SCOPE_NODES):
            self.push_scope_and_link(node)
        if isinstance(node, self.GLOBAL_STACK_NODES):
            self.globals_stack.append([])
        super().enter_node(node)

    def exit_node(self, node: uni.UniNode) -> None:
        if isinstance(node, self.SCOPE_NODES):
            self.pop_scope()
        if isinstance(node, self.GLOBAL_STACK_NODES):
            self.globals_stack.pop()
        super().exit_node(node)

    #########################################
    ## AtomTrailer and Symbol Chain Helpers ##
    #########################################
    def handle_symbol_chain(self, node: uni.AtomTrailer, operation: str) -> bool:
        """Handle symbol chains in AtomTrailer nodes."""
        attr_list = node.as_attr_list
        if not attr_list:
            return False

        first_obj = attr_list[0]
        first_obj_sym = self.cur_scope.lookup(first_obj.sym_name)

        if not first_obj_sym:
            return False

        if first_obj_sym.imported:
            return self._handle_imported_chain(node, operation)
        else:
            return self._handle_local_chain(first_obj_sym, attr_list, operation)

    def _handle_imported_chain(self, node: uni.AtomTrailer, operation: str) -> bool:
        """Handle chains that start with imported symbols."""
        try:
            self.resolve_import(node)
            return True
        except Exception:
            return False

    def _handle_local_chain(
        self, first_sym: uni.Symbol, attr_list: list[uni.AstSymbolNode], operation: str
    ) -> bool:
        """Handle chains within local scope."""
        try:
            current_sym_tab = first_sym.symbol_table

            if operation == "define":
                first_sym.add_defn(attr_list[0].name_spec)
            else:  # operation == 'use'
                first_sym.add_use(attr_list[0].name_spec)

            for attr_node in attr_list[1:]:
                if not current_sym_tab:
                    break

                attr_sym = current_sym_tab.lookup(attr_node.sym_name)
                if not attr_sym:
                    # TODO # self.log_error(
                    #     f"Could not resolve attribute '{attr_node.sym_name}' in chain"
                    # )
                    return False

                if operation == "define":
                    attr_sym.add_defn(attr_node)
                else:  # operation == 'use'
                    attr_sym.add_use(attr_node)

                current_sym_tab = attr_sym.symbol_table
            return True
        except Exception:
            return False

    def handle_simple_symbol(
        self, symbol_node: uni.AstSymbolNode, operation: str
    ) -> bool:
        """Handle simple symbol nodes (non-chain)."""
        glob_sym = self.check_global(symbol_node.sym_name)

        if glob_sym:
            symbol_node.name_spec._sym = glob_sym
            if operation == "define":
                glob_sym.add_defn(symbol_node)
            else:  # operation == 'use'
                glob_sym.add_use(symbol_node)
            return True
        else:
            if operation == "define":
                self.cur_scope.def_insert(symbol_node, single_decl="assignment")
            else:  # operation == 'use'
                found_symbol = self.cur_scope.lookup(symbol_node.sym_name)
                if found_symbol:
                    found_symbol.add_use(symbol_node)
                else:
                    # Symbol not found, could be first use - define it
                    self.cur_scope.def_insert(symbol_node)
            return True

    #####################################
    ## Main logic for symbols creation ##
    #####################################
    def enter_assignment(self, node: uni.Assignment) -> None:
        """Enter assignment node."""
        for target in node.target:
            self._process_assignment_target(target)

    def _process_assignment_target(self, target: uni.Expr) -> None:
        """Process individual assignment target."""
        if isinstance(target, uni.AtomTrailer):
            self.handle_symbol_chain(target, "define")
        elif isinstance(target, uni.AstSymbolNode):
            self.handle_simple_symbol(target, "define")
        else:
            pass
            # TODO
            # self.log_error("Assignment target not valid")

    def enter_ability(self, node: uni.Ability) -> None:
        """Enter ability node and set up method context."""
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, access_spec=node, single_decl="ability")

        if node.is_method:
            self._setup_method_context(node)

    def _setup_method_context(self, node: uni.Ability) -> None:
        """Set up method context by defining 'self', 'super', and event context symbols if needed."""
        self_name = uni.Name.gen_stub_from_node(node, "self")
        self.cur_scope.def_insert(self_name)
        node.parent_of_type(uni.Archetype)

        self.cur_scope.def_insert(
            uni.Name.gen_stub_from_node(node, "super", set_name_of=node.method_owner)
        )

        if node.signature and isinstance(node.signature, uni.EventSignature):
            self._setup_event_context(node)

    def _setup_event_context(self, node: uni.Ability) -> None:
        """Set up 'here' and 'visitor' symbols for event signatures."""
        try:
            arch_type = node.method_owner.arch_type.name

            if arch_type == "KW_WALKER":
                self._setup_walker_context(node)
            elif arch_type == "KW_NODE":
                self._setup_node_context(node)
        except Exception:
            pass
            # TODO
            # self.log_error(f"Error while setting up event context: {str(e)}")

    def _setup_walker_context(self, node: uni.Ability) -> None:
        """Init 'here' for walker; link symbol table to parent."""
        self.cur_scope.def_insert(
            uni.Name.gen_stub_from_node(node, "here", set_name_of=node.method_owner)
        )
        node_name = node.signature.arch_tag_info.unparse()
        self.cur_scope.lookup(node_name).symbol_table

    def _setup_node_context(self, node: uni.Ability) -> None:
        """Init 'visitor' for node; link symbol table to parent."""
        self.cur_scope.def_insert(
            uni.Name.gen_stub_from_node(node, "visitor", set_name_of=node.method_owner)
        )
        walker_name = node.signature.arch_tag_info.unparse()
        self.cur_scope.lookup(walker_name).symbol_table

    def enter_global_stmt(self, node: uni.GlobalStmt) -> None:
        """Enter global statement."""
        for name in node.target:
            sym = self.cur_module_scope.lookup(name.sym_name)
            if not sym:
                sym = self.cur_module_scope.def_insert(name, single_decl="assignment")
            self.globals_stack[-1].append(sym)

    def enter_import(self, node: uni.Import) -> None:
        """Enter import statement."""
        if node.is_absorb:
            return None
        for item in node.items:
            if item.alias:
                self.cur_scope.def_insert(
                    item.alias, imported=True, single_decl="import"
                )
            else:
                self.cur_scope.def_insert(item, imported=True)

    def enter_test(self, node: uni.Test) -> None:
        """Enter test node and add unittest methods."""
        import unittest

        for method_name in [
            j for j in dir(unittest.TestCase()) if j.startswith("assert")
        ]:
            self.cur_scope.def_insert(
                uni.Name.gen_stub_from_node(node, method_name, set_name_of=node)
            )

    def enter_archetype(self, node: uni.Archetype) -> None:
        """Enter archetype node."""
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, access_spec=node, single_decl="archetype")

    def enter_impl_def(self, node: uni.ImplDef) -> None:
        """Enter implementation definition."""
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, single_decl="impl")

    def enter_sem_def(self, node: uni.SemDef) -> None:
        """Enter semantic definition."""
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, single_decl="sem")

    def enter_enum(self, node: uni.Enum) -> None:
        """Enter enum node."""
        assert node.parent_scope is not None
        node.parent_scope.def_insert(node, access_spec=node, single_decl="enum")

    def enter_param_var(self, node: uni.ParamVar) -> None:
        """Enter parameter variable."""
        self.cur_scope.def_insert(node)

    def enter_has_var(self, node: uni.HasVar) -> None:
        """Enter has variable."""
        if isinstance(node.parent, uni.ArchHas):
            self.cur_scope.def_insert(
                node, single_decl="has var", access_spec=node.parent
            )
        else:
            self.ice("Inconsistency in AST, has var should be under arch has")

    def enter_in_for_stmt(self, node: uni.InForStmt) -> None:
        """Enter for-in statement."""
        self._process_assignment_target(node.target)

    def enter_func_call(self, node: uni.FuncCall) -> None:
        """Enter function call node."""
        if isinstance(node.target, uni.AtomTrailer):
            self.handle_symbol_chain(node.target, "use")
        elif isinstance(node.target, uni.AstSymbolNode):
            if self._handle_builtin_symbol(node.target.sym_name, node.target):
                return

            self.handle_simple_symbol(node.target, "use")
        else:
            pass
            # TODO
            # self.log_error("Function call target not valid")

    ##################################
    ##    Comprehensions support    ##
    ##################################
    def enter_list_compr(self, node: uni.ListCompr) -> None:
        """Enter list comprehension with correct traversal order."""
        self.prune()
        for compr in node.compr:
            self.traverse(compr)
        self.traverse(node.out_expr)

    def enter_gen_compr(self, node: uni.GenCompr) -> None:
        """Enter generator comprehension."""
        self.enter_list_compr(node)

    def enter_set_compr(self, node: uni.SetCompr) -> None:
        """Enter set comprehension."""
        self.enter_list_compr(node)

    def enter_dict_compr(self, node: uni.DictCompr) -> None:
        """Enter dictionary comprehension."""
        self.prune()
        for compr in node.compr:
            self.traverse(compr)
        self.traverse(node.kv_pair)

    def enter_inner_compr(self, node: uni.InnerCompr) -> None:
        """Enter inner comprehension."""
        if isinstance(node.target, uni.AtomTrailer):
            self.cur_scope.chain_def_insert(node.target.as_attr_list)
        elif isinstance(node.target, uni.AstSymbolNode):
            self.cur_scope.def_insert(node.target)
        else:
            pass
            # TODO
            # self.log_error("Named target not valid")

    #####################
    ## Collecting uses ##
    #####################
    def exit_name(self, node: uni.Name) -> None:
        """Exit name node and record usage."""
        if isinstance(node.parent, uni.AtomTrailer):
            return

        # Check if this is a builtin symbol first
        if self._handle_builtin_symbol(node.value, node):
            return

        glob_sym = self.check_global(node.value)
        if glob_sym:
            if not node.sym:
                glob_sym.add_use(node)
        else:
            self.cur_scope.use_lookup(node, sym_table=self.cur_scope)

    def enter_builtin_type(self, node: uni.BuiltinType) -> None:
        """Enter builtins node like str, int, list, etc."""
        self._handle_builtin_symbol(node.value, node)

    def enter_expr_as_item(self, node: uni.ExprAsItem) -> None:
        """Enter expression as item (for with statements)."""
        if node.alias:
            self._process_assignment_target(node.alias)

    ############################
    ## Import Resolution Logic ##
    ############################
    def resolve_import(self, node: uni.UniNode) -> None:
        """Resolve imports for atom trailers like 'apple.color.bla.blah'."""
        if isinstance(node, uni.AtomTrailer):
            self._resolve_atom_trailer_import(node)
        else:
            self.log_warning(
                f"Import resolution not implemented for {type(node).__name__}"
            )

    def _resolve_assignment_imports(self, node: uni.Assignment) -> None:
        """Handle import resolution for assignment statements."""
        for target in node.target:
            if isinstance(target, uni.AtomTrailer):
                self._resolve_atom_trailer_import(target)

    def _resolve_for_loop_imports(self, node: uni.InForStmt) -> None:
        """Handle import resolution for for-loop statements."""
        if isinstance(node.target, uni.AtomTrailer):
            self._resolve_atom_trailer_import(node.target)

    def _resolve_atom_trailer_import(self, atom_trailer: uni.AtomTrailer) -> None:
        """Resolve imports for atom trailer chains."""
        attr_list = atom_trailer.as_attr_list
        if not attr_list:
            raise ValueError("Atom trailer must have at least one attribute")

        first_obj = attr_list[0]
        first_obj_sym = self.cur_scope.lookup(first_obj.sym_name)
        if not first_obj_sym or not first_obj_sym.imported:
            return

        import_node = self._find_import_for_symbol(first_obj_sym)
        if not import_node:
            # TODO
            # self.log_error(
            #     f"Could not find import statement for symbol '{first_obj_sym.sym_name}'"
            # )
            return

        module_path = self._get_module_path_from_symbol(first_obj_sym)
        if not module_path:
            # TODO
            # self.log_error("Could not resolve module path for import")
            return

        linked_module = self._parse_and_link_module(module_path, first_obj_sym)
        if linked_module:
            self._link_attribute_chain(attr_list, first_obj_sym, linked_module)

    def _find_import_for_symbol(self, symbol: uni.Symbol) -> Optional[uni.Import]:
        """Find the import statement that declares the given symbol."""
        if not symbol.decl:
            return None

        import_node: uni.Import = symbol.decl.find_parent_of_type(uni.Import)
        if import_node:
            return import_node
        self.ice(f"Symbol '{symbol.sym_name}' does not have a valid import declaration")
        return None

    # TODO: this is an important function: it should support all 7 types of imports here
    def _get_module_path_from_symbol(self, symbol: uni.Symbol) -> Optional[str]:
        """Extract module path from symbol's import declaration."""
        mod_item_node = symbol.decl.find_parent_of_type(uni.ModuleItem)
        if mod_item_node:
            mod_path_node = mod_item_node.find_parent_of_type(uni.Import).from_loc
        else:
            mod_path_node = symbol.decl.find_parent_of_type(uni.ModulePath)

        return mod_path_node.resolve_relative_path() if mod_path_node else None

    def _link_attribute_chain(
        self,
        attr_list: list[uni.AstSymbolNode],
        first_symbol: uni.Symbol,
        current_module: uni.Module,
    ) -> None:
        """Link the full attribute chain by resolving each symbol."""
        current_symbol = first_symbol
        current_sym_table = current_module.sym_tab

        # Add use for the first symbol
        first_obj = attr_list[0]
        current_symbol.add_use(first_obj)

        # Iterate through remaining attributes in the chain
        for attr_node in attr_list[1:]:
            if not current_sym_table:
                return

            attr_symbol = current_sym_table.lookup(attr_node.sym_name)
            if not attr_symbol:
                # self.log_error(
                #     f"Could not resolve attribute '{attr_node.sym_name}' in chain"
                # )
                # TODO:
                break

            attr_symbol.add_use(attr_node)
            current_symbol = attr_symbol
            current_sym_table = current_symbol.symbol_table

    # TODO:move this to Jac Program
    def _parse_and_link_module(
        self, module_path: str, symbol: uni.Symbol
    ) -> Optional[uni.Module]:
        """Parse the module and link it to the symbol."""
        try:
            if module_path in self.prog.mod.hub:
                existing_module = self.prog.mod.hub[module_path]
                # symbol.symbol_table = existing_module.sym_tab
                return existing_module

            source_str = read_file_with_encoding(module_path)

            parsed_module: uni.Module = self.prog.parse_str(
                source_str=source_str, file_path=module_path
            )
            BinderPass(ir_in=parsed_module, prog=self.prog)
            # symbol.symbol_table = parsed_module.sym_tab

            return parsed_module

        except Exception:
            # TODO
            # self.log_error(f"Failed to parse module '{module_path}': {str(e)}")
            return None

    def load_builtins(self) -> None:
        """Load built-in symbols from the builtins.pyi file."""
        try:
            builtins_path = os.path.join(
                os.path.dirname(__file__),
                "../../../vendor/typeshed/stdlib/builtins.pyi",
            )

            # lets keep this line until typeshed are merged with jaclang
            if not os.path.exists(builtins_path):
                self.log_warning(f"Builtins file not found at {builtins_path}")
                return

            file_source = read_file_with_encoding(builtins_path)

            from jaclang.compiler.passes.main.pyast_load_pass import PyastBuildPass

            mod = PyastBuildPass(
                ir_in=uni.PythonModuleAst(
                    py_ast.parse(file_source),
                    orig_src=uni.Source(file_source, builtins_path),
                ),
                prog=self.prog,
            ).ir_out

            if mod:
                self.prog.mod.hub["builtins"] = mod
                BinderPass(ir_in=mod, prog=self.prog)

        except Exception as e:
            self.log_error(f"Failed to load builtins: {str(e)}")

    def _is_builtin_symbol(self, symbol_name: str) -> bool:
        """Check if a symbol is a builtin symbol."""
        builtins_mod = self.prog.mod.hub["builtins"]
        return symbol_name in builtins_mod.sym_tab.names_in_scope

    def _handle_builtin_symbol(
        self, symbol_name: str, target_node: uni.AstSymbolNode
    ) -> bool:
        """Handle builtin symbol lookup and linking."""
        if not self._is_builtin_symbol(symbol_name):
            return False

        builtins_mod = self.prog.mod.hub["builtins"]
        builtin_symbol = builtins_mod.sym_tab.lookup(symbol_name)

        if not builtin_symbol:
            return False

        target_node.name_spec._sym = builtin_symbol
        builtin_symbol.add_use(target_node)
        return True
