"""Handle the special variable reference node."""

impl TypeCheckPass.exit_special_var_ref(
    self: TypeCheckPass, nd: uni.SpecialVarRef
) -> None {
    self.evaluator.get_type_of_expression(nd);
}

"""Handle name nodes to ensure symbol resolution for all variable references."""
impl TypeCheckPass.exit_name(self: TypeCheckPass, nd: uni.Name) -> None {
    # Skip if already resolved or if part of a construct that handles its own resolution
    if nd.sym is None {
        self.evaluator.get_type_of_expression(nd);
    }
}

"""Handle the edge reference trailer node."""
impl TypeCheckPass.exit_edge_ref_trailer(
    self: TypeCheckPass, nd: uni.EdgeRefTrailer
) -> None {
    for chain in nd.chain {
        if isinstance(chain, uni.FilterCompr) {
            self.evaluator.get_type_of_expression(chain);
        }
    }
}

"""Handle the formatted value node."""
impl TypeCheckPass.exit_formatted_value(
    self: TypeCheckPass, nd: uni.FormattedValue
) -> None {
    self.evaluator.get_type_of_expression(nd.format_part);
}

"""Handle the return statement node."""
impl TypeCheckPass.exit_return_stmt(self: TypeCheckPass, nd: uni.ReturnStmt) -> None {
    returning_type = self.evaluator._convert_to_instance(
        self.evaluator.get_none_type()
    );
    if nd.expr {
        returning_type = self.evaluator.get_type_of_expression(nd.expr);
    }
    if (fn := self.evaluator._get_enclosing_function(nd)) {
        # Check if return type annotation is missing.
        has_annotation = (
            isinstance(fn.signature, uni.FuncSignature)
            and fn.signature.return_type is not None
        );
        # If returning a non-None value but no annotation, require one.
        # `return None` and bare `return` don't need an annotation.
        # Skip for nested/inline functions (lambdas, IIFEs, closures).
        is_toplevel_fn = isinstance(
            fn.parent, (uni.Module, uni.Archetype, uni.Enum, uni.ImplDef)
        );
        if (
            nd.expr
            and not has_annotation
            and not isinstance(nd.expr, uni.Null)
            and is_toplevel_fn
        ) {
            self.log_error(
                "Return type annotation required when function returns a value", nd
            );
            return;
        }
        fn_type = self.evaluator.get_type_of_ability(fn);
        return_type = self.evaluator._convert_to_instance(fn_type.return_type);
        if not self.evaluator.assign_type(returning_type, return_type) {
            self.log_error(
                f"Cannot return {returning_type}, expected {fn_type.return_type}", nd
            );
        }
    }
}

"""Handle the edge operation reference node."""
impl TypeCheckPass.exit_filter_compr(self: TypeCheckPass, nd: uni.FilterCompr) -> None {
    self.evaluator.get_type_of_expression(nd);
}

"""Handle the function call node."""
impl TypeCheckPass.exit_func_call(self: TypeCheckPass, nd: uni.FuncCall) -> None {
    self.evaluator.get_type_of_expression(nd);
}

"""Handle the binary expression node."""
impl TypeCheckPass.exit_binary_expr(self: TypeCheckPass, nd: uni.BinaryExpr) -> None {
    self.evaluator.get_type_of_expression(nd);
}

"""Handle the atom trailer node."""
impl TypeCheckPass.exit_atom_trailer(self: TypeCheckPass, nd: uni.AtomTrailer) -> None {
    self.evaluator.get_type_of_expression(nd);
}

"""Pyright: Checker.visitAssignment(node: AssignmentNode): boolean."""
impl TypeCheckPass.exit_assignment(self: TypeCheckPass, nd: uni.Assignment) -> None {
    if ((len(nd.target) == 1) and (nd.value is not None)) {
        target = nd.target[0];
        # For assignment targets, use the declared symbol type (not the
        # narrowed type). Narrowing reflects the *current* value; the
        # variable's declared type determines what can be assigned to it.
        if isinstance(target, uni.Name) and target.sym {
            left_type = self.evaluator.get_type_of_symbol(target.sym);
        } else {
            left_type = self.evaluator.get_type_of_expression(target);
        }
        right_type = self.evaluator.get_type_of_expression(nd.value);
        if not self.evaluator.assign_type(right_type, left_type) {
            self.log_error(f"Cannot assign {right_type} to {left_type}");
        }
    } else {
        ;
    }
}

"""Exit an import node."""
impl TypeCheckPass.exit_import(self: TypeCheckPass, nd: uni.Import) -> None {
    if nd.from_loc {
        self.evaluator.get_type_of_module(nd.from_loc);
        for item in nd.items {
            if isinstance(item, uni.ModuleItem) {
                self.evaluator.get_type_of_module_item(item);
            }
        }
    } else {
        for item in nd.items {
            if isinstance(item, uni.ModulePath) {
                self.evaluator.get_type_of_module(item);
            }
        }
    }
}

"""Enter an ability node."""
impl TypeCheckPass.enter_ability(self: TypeCheckPass, nd: uni.Ability) -> None {
    import from jaclang.compiler.type_system { types as jtypes }
    for decor in (nd.decorators or []) {
        ty = self.evaluator.get_type_of_expression(decor);
        if (isinstance(ty, jtypes.ClassType) and ty.is_builtin('staticmethod')) {
            nd.is_static = True;
            break;
        }
    }
}

"""Exit an ability node - ensure parameter type annotations are evaluated."""
impl TypeCheckPass.exit_ability(self: TypeCheckPass, nd: uni.Ability) -> None {
    # For abilities with ImplDef body (stubs linked to impl files), the original declaration's
    # type annotation Name nodes are orphaned (not in the traversal tree). We need to explicitly
    # process them to enable hover/go-to-definition on the declaration file.
    if isinstance(nd.body, uni.ImplDef) {
        ability_start_line = nd.loc.first_line;
        ability_end_line = nd.loc.last_line;
        # Find orphaned Name nodes in type annotations at this ability's location
        if module := nd.find_parent_of_type(uni.Module) {
            for mod_nd in module._in_mod_nodes {
                if (
                    isinstance(mod_nd, uni.Name)
                    and mod_nd.sym is None
                    and ability_start_line <= mod_nd.loc.first_line <= ability_end_line
                    and isinstance(mod_nd.parent, uni.SubTag)
                ) {  # SubTag is the type annotation wrapper

                    self.evaluator.get_type_of_expression(mod_nd);
                }
            }
        }
        # The ImplDef body is not in the Ability's kid list, so it's not traversed by the pass.
        # We need to explicitly traverse the ImplDef body to evaluate types for hover/go-to-def.
        self.traverse(nd.body);
    }
}

"""Exit an archetype node - traverse ImplDef body if present."""
impl TypeCheckPass.exit_archetype(self: TypeCheckPass, nd: uni.Archetype) -> None {
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
    }
}

"""Exit an enum node - build enum type eagerly and traverse ImplDef body if present."""
impl TypeCheckPass.exit_enum(self: TypeCheckPass, nd: uni.Enum) -> None {
    self.evaluator.get_type_of_enum(nd);
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
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
    self: TypeCheckPass, nd: uni.UniNode, message: str, warning: bool
) -> None {
    if warning {
        self.log_warning(message, nd);
    } else {
        self.log_error(message, nd);
    }
}

"""Initialize the checker pass."""
impl TypeCheckPass.before_pass(self: TypeCheckPass) -> None {
    self.evaluator = self.prog.get_type_evaluator();
    self.evaluator.diagnostic_callback = self._add_diagnostic;
    self._insert_builtin_symbols();
    self.evaluator._narrowing_cache = {};
}
