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
        left_type = self.evaluator.get_type_of_expression(<>node.target[0]);
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
}
