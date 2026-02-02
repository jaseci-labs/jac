"""Handle the special variable reference node."""

impl TypeCheckPass.exit_special_var_ref(
    self: TypeCheckPass, <>node: uni.SpecialVarRef
) -> None {
    self.evaluator.get_type_of_expression(<>node);
}

"""Handle name nodes to ensure symbol resolution for all variable references."""
impl TypeCheckPass.exit_name(self: TypeCheckPass, <>node: uni.Name) -> None {
    # Skip if already resolved or if part of a construct that handles its own resolution
    if <>node.sym is None {
        self.evaluator.get_type_of_expression(<>node);
    }
}

"""Handle the edge reference trailer node."""
impl TypeCheckPass.exit_edge_ref_trailer(
    self: TypeCheckPass, <>node: uni.EdgeRefTrailer
) -> None {
    for chain in <>node.chain {
        if isinstance(chain, uni.FilterCompr) {
            self.evaluator.get_type_of_expression(chain);
        }
    }
}

"""Handle the formatted value node."""
impl TypeCheckPass.exit_formatted_value(
    self: TypeCheckPass, <>node: uni.FormattedValue
) -> None {
    self.evaluator.get_type_of_expression(<>node.format_part);
}

"""Handle the return statement node."""
impl TypeCheckPass.exit_return_stmt(
    self: TypeCheckPass, <>node: uni.ReturnStmt
) -> None {
    returning_type = self.evaluator._convert_to_instance(
        self.evaluator.get_none_type()
    );
    if <>node.expr {
        returning_type = self.evaluator.get_type_of_expression(<>node.expr);
    }
    if (fn := self.evaluator._get_enclosing_function(<>node)) {
        fn_type = self.evaluator.get_type_of_ability(fn);
        return_type = self.evaluator._convert_to_instance(fn_type.return_type);
        if not self.evaluator.assign_type(returning_type, return_type) {
            self.log_error(
                f"Cannot return {returning_type}, expected {fn_type.return_type}",
                <>node
            );
        }
    }
}

"""Handle the edge operation reference node."""
impl TypeCheckPass.exit_filter_compr(
    self: TypeCheckPass, <>node: uni.FilterCompr
) -> None {
    self.evaluator.get_type_of_expression(<>node);
}

"""Handle the function call node."""
impl TypeCheckPass.exit_func_call(self: TypeCheckPass, <>node: uni.FuncCall) -> None {
    self.evaluator.get_type_of_expression(<>node);
}

"""Handle the binary expression node."""
impl TypeCheckPass.exit_binary_expr(
    self: TypeCheckPass, <>node: uni.BinaryExpr
) -> None {
    self.evaluator.get_type_of_expression(<>node);
}

"""Handle the atom trailer node."""
impl TypeCheckPass.exit_atom_trailer(
    self: TypeCheckPass, <>node: uni.AtomTrailer
) -> None {
    self.evaluator.get_type_of_expression(<>node);
}

"""Pyright: Checker.visitAssignment(node: AssignmentNode): boolean."""
impl TypeCheckPass.exit_assignment(self: TypeCheckPass, <>node: uni.Assignment) -> None {
    if ((len(<>node.target) == 1) and (<>node.value is not None)) {
        target = <>node.target[0];
        # For assignment targets, use the declared symbol type (not the
        # narrowed type). Narrowing reflects the *current* value; the
        # variable's declared type determines what can be assigned to it.
        if isinstance(target, uni.Name) and target.sym {
            left_type = self.evaluator.get_type_of_symbol(target.sym);
        } else {
            left_type = self.evaluator.get_type_of_expression(target);
        }
        right_type = self.evaluator.get_type_of_expression(<>node.value);
        if not self.evaluator.assign_type(right_type, left_type) {
            self.log_error(f"Cannot assign {right_type} to {left_type}");
        }
    } else {
        ;
    }
}

"""Exit an import node."""
impl TypeCheckPass.exit_import(self: TypeCheckPass, <>node: uni.Import) -> None {
    if <>node.from_loc {
        self.evaluator.get_type_of_module(<>node.from_loc);
        for item in <>node.items {
            if isinstance(item, uni.ModuleItem) {
                self.evaluator.get_type_of_module_item(item);
            }
        }
    } else {
        for item in <>node.items {
            if isinstance(item, uni.ModulePath) {
                self.evaluator.get_type_of_module(item);
            }
        }
    }
}

"""Enter an ability node."""
impl TypeCheckPass.enter_ability(self: TypeCheckPass, <>node: uni.Ability) -> None {
    import from jaclang.compiler.type_system { types as jtypes }
    for decor in (<>node.decorators or []) {
        ty = self.evaluator.get_type_of_expression(decor);
        if (isinstance(ty, jtypes.ClassType) and ty.is_builtin('staticmethod')) {
            <>node.is_static = True;
            break;
        }
    }
}

"""Exit an ability node - ensure parameter type annotations are evaluated."""
impl TypeCheckPass.exit_ability(self: TypeCheckPass, <>node: uni.Ability) -> None {
    # For abilities with ImplDef body (stubs linked to impl files), the original declaration's
    # type annotation Name nodes are orphaned (not in the traversal tree). We need to explicitly
    # process them to enable hover/go-to-definition on the declaration file.
    if isinstance(<>node.body, uni.ImplDef) {
        ability_start_line = <>node.loc.first_line;
        ability_end_line = <>node.loc.last_line;
        # Find orphaned Name nodes in type annotations at this ability's location
        if module := <>node.find_parent_of_type(uni.Module) {
            for nd in module._in_mod_nodes {
                if (
                    isinstance(nd, uni.Name)
                    and nd.sym is None
                    and ability_start_line <= nd.loc.first_line <= ability_end_line
                    and isinstance(nd.parent, uni.SubTag)
                ) {  # SubTag is the type annotation wrapper

                    self.evaluator.get_type_of_expression(nd);
                }
            }
        }
        # The ImplDef body is not in the Ability's kid list, so it's not traversed by the pass.
        # We need to explicitly traverse the ImplDef body to evaluate types for hover/go-to-def.
        self._traverse_impl_body(<>node.body);
    }
}

"""Traverse an ImplDef body and evaluate types for all expression nodes."""
impl TypeCheckPass._traverse_impl_body(
    self: TypeCheckPass, impl_def: uni.ImplDef
) -> None {
    # Recursively traverse all nodes in the ImplDef body and call type evaluation
    def traverse_node(node: uni.UniNode) -> None {
        if node is None {
            return;
        }

        # Call the appropriate exit handler for expression nodes
        if isinstance(node, uni.SpecialVarRef) {
            self.evaluator.get_type_of_expression(node);
        } elif isinstance(node, uni.AtomTrailer) {
            self.evaluator.get_type_of_expression(node);
        } elif isinstance(node, uni.FuncCall) {
            self.evaluator.get_type_of_expression(node);
        } elif isinstance(node, uni.BinaryExpr) {
            self.evaluator.get_type_of_expression(node);
        } elif isinstance(node, uni.Assignment) {
            # Handle assignments - evaluate both sides
            for target in node.target {
                self.evaluator.get_type_of_expression(target);
            }
            if node.value {
                self.evaluator.get_type_of_expression(node.value);
            }
        } elif isinstance(node, uni.ReturnStmt) {
            if node.expr {
                self.evaluator.get_type_of_expression(node.expr);
            }
        } elif isinstance(node, uni.Name) {
            if node.sym is None {
                self.evaluator.get_type_of_expression(node);
            }
        }

        # Recursively traverse children
        if node?.kid {
            for child in node.kid {
                if child {
                    traverse_node(child);
                }
            }
        }
    }
    # Start traversing from the ImplDef's children
    for child in impl_def.kid {
        if child {
            traverse_node(child);
        }
    }
}

"""Exit an impl def node - ensure parameter type annotations are evaluated."""
impl TypeCheckPass.exit_impl_def(self: TypeCheckPass, <>node: uni.ImplDef) -> None {
    # For impl blocks, process type annotation Name nodes to enable hover/go-to-definition.
    # Directly traverse the FuncSignature's params to find type annotations.
    if isinstance(<>node.spec, uni.FuncSignature) {
        sig = <>node.spec;
        all_params = (
            list(sig.posonly_params) + list(sig.params) + (
                [sig.varargs] if sig.varargs else []
            ) + list(sig.kwonlyargs) + ([sig.kwargs] if sig.kwargs else [])
        );
        for param in all_params {
            # Process the type annotation - access via tag directly
            if param.type_tag and isinstance(param.type_tag, uni.SubTag) {
                tag = param.type_tag.tag;
                if isinstance(tag, uni.Name) {
                    # Try to resolve the symbol from the module scope if not already resolved
                    if tag.sym is None {
                        # Try to find the symbol from all loaded modules
                        symbol: uni.Symbol | None = None;
                        # Check all modules in the program hub
                        for (path, mod) in self.prog.mod.hub.items() {
                            if symbol := mod.lookup(
                                tag.value, deep=True, incl_inner_scope=True
                            ) {
                                break;
                            }
                        }
                        if symbol {
                            symbol = self.evaluator.resolve_imported_symbols(symbol);
                            symbol.add_use(tag);
                            tag.sym = symbol;
                            if symbol.decl and symbol.decl.name_of {
                                tag.name_of = symbol.decl.name_of;
                            }
                        }
                    }
                    # Also call evaluator for full type processing
                    self.evaluator.get_type_of_expression(tag);
                }
            }
        }
        # Also process return type annotation
        if sig.return_type and isinstance(sig.return_type, uni.Name) {
            self.evaluator.get_type_of_expression(sig.return_type);
        }
    }
}

impl TypeCheckPass._insert_builtin_symbols(self: TypeCheckPass) -> None {
    if (self.ir_in == self.evaluator.builtins_module) {
        return;
    }
    if (self.ir_in.parent_scope is not None) {
        self.log_info('Builtins module is already bound, skipping.');
        return;
    }
    self.ir_in.parent_scope = self.evaluator.builtins_module;
}

"""Add a diagnostic message to the pass."""
impl TypeCheckPass._add_diagnostic(
    self: TypeCheckPass, <>node: uni.UniNode, message: str, warning: bool
) -> None {
    if warning {
        self.log_warning(message, <>node);
    } else {
        self.log_error(message, <>node);
    }
}

"""Initialize the checker pass."""
impl TypeCheckPass.before_pass(self: TypeCheckPass) -> None {
    self.evaluator = self.prog.get_type_evaluator();
    self.evaluator.diagnostic_callback = self._add_diagnostic;
    self._insert_builtin_symbols();
    self.evaluator._narrowing_cache = {};
}
