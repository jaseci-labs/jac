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
    returning_type = self.evaluator._convert_to_instance(self.evaluator.get_none_type());
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
        import from jaclang.compiler.type_system { types }
        fn_type_base = self.evaluator.get_type_of_ability(fn);
        fn_type: types.FunctionType = fn_type_base;
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

    # Validate TypeVar usage in runtime context (e.g., list[T]())
    # Pyright: Type variable "T" has no meaning in this context
    if isinstance(nd.target, uni.AtomTrailer) and not nd.target.is_attr {
        if isinstance(nd.target.right, uni.IndexSlice) {
            idx_slice: uni.IndexSlice = nd.target.right;
            for slice in idx_slice.slices {
                slice_item: uni.IndexSlice.Slice = slice;
                if slice_item.start {
                    self.evaluator.validate_typevar_in_type_expr(slice_item.start);
                }
            }
        }
    }
}

"""Handle the binary expression node."""
impl TypeCheckPass.exit_binary_expr(self: TypeCheckPass, nd: uni.BinaryExpr) -> None {
    self.evaluator.get_type_of_expression(nd);
}

"""Enter a boolean expression - set up narrowing scope for AND expressions."""
impl TypeCheckPass.enter_bool_expr(self: TypeCheckPass, nd: uni.BoolExpr) -> None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    # For AND expressions, push a narrowing scope
    if nd.op.name == Tok.KW_AND {
        self.evaluator.push_narrowing_scope();
        # Pre-process conditions to add narrowings BEFORE children are evaluated
        for val in nd.values {
            self.evaluator.process_condition(val);
        }
    }
}

"""Exit a boolean expression - clean up narrowing scope."""
impl TypeCheckPass.exit_bool_expr(self: TypeCheckPass, nd: uni.BoolExpr) -> None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    # Pop the narrowing scope for AND expressions
    if nd.op.name == Tok.KW_AND {
        self.evaluator.pop_narrowing_scope();
    }
}

"""Enter an if statement - set up narrowing scope for the if body."""
impl TypeCheckPass.enter_if_stmt(self: TypeCheckPass, nd: uni.IfStmt) -> None {
    # Push a narrowing scope for the if body
    self.evaluator.push_narrowing_scope();
    # Process the condition to add narrowings
    self.evaluator.process_condition(nd.condition);
}

"""Exit an if statement - clean up narrowing scope."""
impl TypeCheckPass.exit_if_stmt(self: TypeCheckPass, nd: uni.IfStmt) -> None {
    self.evaluator.pop_narrowing_scope();
}

"""Handle the atom trailer node."""
impl TypeCheckPass.exit_atom_trailer(self: TypeCheckPass, nd: uni.AtomTrailer) -> None {
    self.evaluator.get_type_of_expression(nd);
}

"""Pyright: Checker.visitAssignment(node: AssignmentNode): boolean."""
impl TypeCheckPass.exit_assignment(self: TypeCheckPass, nd: uni.Assignment) -> None {
    import from jaclang.compiler.type_system { types }
    if ((len(nd.target) == 1) and (nd.value is not None)) {
        target = nd.target[0];
        # For assignment targets, use the declared symbol type (not the
        # narrowed type). Narrowing reflects the *current* value; the
        # variable's declared type determines what can be assigned to it.
        if isinstance(target, uni.Name) and target.sym {
            left_type = self.evaluator.get_type_of_symbol(target.sym);
            # Cache the type on the Name node for hover info
            target.type = left_type;
        } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
            # Tuple/list unpacking: (px, py) = p; or [a, b] = lst;
            # Individual element types are inferred by _eval_unpacking_names.
            # Skip whole-expression assign_type check since the LHS container
            # type (tuple/list) is not directly comparable to the RHS iterable.
            self._eval_unpacking_names(target);
            right_type = self.evaluator.get_type_of_expression(nd.value);
            # Check that the RHS is iterable for destructuring
            if not isinstance(right_type, types.UnknownType) {
                iter_result = self.evaluator.get_type_of_magic_method_call(
                    right_type, "__iter__", [], nd.value
                );
                if iter_result is None {
                    self.log_error(f"Cannot unpack non-iterable {right_type}", nd);
                }
            }
            return;
        } else {
            left_type = self.evaluator.get_type_of_expression(target);
        }
        right_type = self.evaluator.get_type_of_expression(nd.value);

        # Pyright: assignTypeToExpression() - TypeVar assignment validation
        # When RHS is a TypeVar() call, validate that:
        # 1. Target is a simple Name (not index expression like my_dict["key"])
        # 2. Target name matches the TypeVar name (T = TypeVar("T"), not T2 = TypeVar("T3"))
        if isinstance(right_type, types.TypeVarType)
        and isinstance(nd.value, uni.FuncCall) {
            # Check if it's a TypeVar call by checking the caller type
            caller_type = self.evaluator.get_type_of_expression(nd.value.target);
            is_typevar_call = self.evaluator.is_typevar_class(caller_type);
            if is_typevar_call {
                # Validation 1: TypeVar cannot be assigned to index expression
                # e.g., my_dict["var"] = TypeVar("T5") is an error
                if not isinstance(target, uni.Name) {
                    self.log_error(
                        f'TypeVar "{right_type.name}" must be assigned to a simple variable, '
                        f'not an index or member expression',
                        target
                    );
                } else {
                    # Validation 2: TypeVar name must match the variable name
                    # e.g., T2 = TypeVar("T3") is an error
                    name_target: uni.Name = target;
                    if name_target.value != right_type.name {
                        self.log_error(
                            f'TypeVar name "{right_type.name}" must match the assigned variable name "{name_target.value}"',
                            name_target
                        );
                    }
                }
            }
        }

        # Augmented assignment TypeVar check (Pyright: typeVar5/6)
        # e.g., a += 3 where a is TypeVar is an error (unless bound supports it)
        if nd.aug_op and isinstance(left_type, types.TypeVarType) {
            if left_type.bound and isinstance(left_type.bound, types.ClassType) {
                # Bounded TypeVar - check if bound supports __iadd__ (etc)
                # Use operations module to check via magic method lookup
                import from jaclang.compiler.type_system { operations }
                op_name = operations.AUG_OPERATOR_MAP.get(nd.aug_op.name);
                if op_name {
                    result = self.evaluator.get_type_of_magic_method_call(
                        left_type.bound, op_name, [nd.value], nd
                    );
                    if result is None {
                        self.log_error(
                            f'Operator "{nd.aug_op.name}" not supported for type "{left_type.bound}"',
                            nd
                        );
                    }
                } else {
                    self.log_error(
                        f'Operator "{nd.aug_op.name}" not supported for type "{left_type.bound}"',
                        nd
                    );
                }
            } else {
                # Unbounded TypeVar
                self.log_error(
                    f'Operator "{nd.aug_op.name}" not supported for type "{left_type.name}"',
                    nd
                );
            }
        } elif not self.evaluator.assign_type(right_type, left_type) {
            self.log_error(f"Cannot assign {right_type} to {left_type}");
        }
        # Validate augmented assignment operator (+=, -=, etc.)
        if nd.aug_op is not None {
            import from jaclang.compiler.type_system { types }
            import from jaclang.compiler.type_system.operations {
                AUG_OPERATOR_MAP,
                AUG_TO_BINARY_MAP,
                BINARY_OPERATOR_MAP,
                ARITHMETIC_OPERATORS,
                get_numeric_promotion_type
            }
            if (
                not isinstance(left_type, types.UnknownType)
                and not isinstance(right_type, types.UnknownType)
            ) {
                aug_magic = AUG_OPERATOR_MAP.get(nd.aug_op.name);
                if aug_magic is not None {
                    # Try in-place magic method first (e.g., __iadd__)
                    result = self.evaluator.get_type_of_magic_method_call(
                        left_type, aug_magic, [nd.value], nd.value
                    );
                    if result is None {
                        # Fall back to base binary operator (e.g., __add__/__radd__)
                        base_op = AUG_TO_BINARY_MAP.get(nd.aug_op.name);
                        if base_op is not None {
                            # Try numeric promotion first (int += float, etc.)
                            if base_op in ARITHMETIC_OPERATORS {
                                promoted = get_numeric_promotion_type(
                                    self.evaluator, left_type, right_type, base_op
                                );
                                if promoted is not None {
                                    result = promoted;
                                }
                            }
                            if result is None {
                                binary_methods = BINARY_OPERATOR_MAP.get(base_op);
                                if binary_methods is not None {
                                    (magic, rmagic) = binary_methods;
                                    result = self.evaluator.get_type_of_magic_method_call(
                                        left_type, magic, [nd.value], nd.value
                                    );
                                    if result is None {
                                        result = self.evaluator.get_type_of_magic_method_call(
                                            right_type, rmagic, [nd.value], nd.value
                                        );
                                    }
                                }
                            }
                        }
                        if result is None {
                            self.log_error(
                                f"Unsupported operand types for {nd.aug_op.value}: "
                                f"{left_type} and {right_type}",
                                nd
                            );
                        }
                    }
                }
            }
        }
    } else {
        # Handle multi-target assignments: set type on each target for hover
        for target in nd.target {
            if isinstance(target, uni.Name) and target.sym {
                target.type = self.evaluator.get_type_of_symbol(target.sym);
            } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
                self._eval_unpacking_names(target);
            } else {
                self.evaluator.get_type_of_expression(target);
            }
        }
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

"""Exit an ability node - ensure parameter type annotations are evaluated and check return completeness."""
impl TypeCheckPass.exit_ability(self: TypeCheckPass, nd: uni.Ability) -> None {
    import from jaclang.compiler.type_system { types }

    # Validate TypeVar variance (covariant in params, contravariant in returns)
    self.evaluator.validate_typevar_variance(nd);

    # ImplDef body is not in kid list, traverse it explicitly
    # Only process stubs linked to an impl file
    if isinstance(nd.body, uni.ImplDef) {
        # ImplDef body is not in kid list, traverse it explicitly
        self.traverse(nd.body);
    }
    # Check for missing return statements on non-None return type functions
    if (
        isinstance(nd.signature, uni.FuncSignature)
        and nd.signature.return_type is not None
        and not isinstance(nd.body, uni.ImplDef)
        and isinstance(nd.body, list)
        and len(nd.body) > 0
        and not nd.is_abstract
    ) {
        # Skip @overload decorated functions (stubs with no real body)
        is_overload = False;
        for decor in (nd.decorators or []) {
            if isinstance(decor, uni.Name) and decor.value == "overload" {
                is_overload = True;
                break;
            }
        }
        # Skip generator functions (contain yield) — they don't need explicit return
        is_generator = len(nd.get_all_sub_nodes(uni.YieldExpr)) > 0;
        if not is_overload and not is_generator {
            ret_type = self.evaluator.get_type_of_expression(nd.signature.return_type);
            ret_inst = self.evaluator._convert_to_instance(ret_type);
            none_type = self.evaluator._convert_to_instance(
                self.evaluator.get_none_type()
            );
            if not self.evaluator.assign_type(none_type, ret_inst) {
                if not self._body_always_returns(nd.body) {
                    self.log_error(
                        f"Function '{nd.name_spec.sym_name}' declared return type "
                        f"{ret_type} but may implicitly return None",
                        nd
                    );
                }
            }
        }
    }
}

"""Check if a code block always returns a value on all paths."""
impl TypeCheckPass._body_always_returns(
    self: TypeCheckPass, body: list[uni.CodeBlockStmt]
) -> bool {
    for stmt in reversed(body) {
        if isinstance(stmt, uni.ReturnStmt) {
            return True;
        }
        if isinstance(stmt, uni.IfStmt) {
            if_returns = self._body_always_returns(list(stmt.body));
            else_returns = False;
            if isinstance(stmt.else_body, uni.ElseIf) {
                else_returns = self._body_always_returns(list(stmt.else_body.body));
                if not else_returns {
                    continue;
                }
                if stmt.else_body.else_body {
                    if isinstance(stmt.else_body.else_body, uni.ElseStmt) {
                        else_returns = self._body_always_returns(
                            list(stmt.else_body.else_body.body)
                        );
                    } elif isinstance(stmt.else_body.else_body, uni.ElseIf) {
                        else_returns = self._body_always_returns(
                            [stmt.else_body.else_body]
                        );
                    }
                } else {
                    else_returns = False;
                }
            } elif isinstance(stmt.else_body, uni.ElseStmt) {
                else_returns = self._body_always_returns(list(stmt.else_body.body));
            }
            if if_returns and else_returns {
                return True;
            }
        }
        if isinstance(stmt, uni.MatchStmt) {
            # Match statement always returns if all cases return.
            # This handles both explicit wildcard (case _:) and exhaustive
            # union coverage (case A() + case B() covering A|B).
            if stmt.cases {
                all_cases_return = True;
                for case in stmt.cases {
                    match_case: uni.MatchCase = case;
                    if not self._body_always_returns(list(match_case.body)) {
                        all_cases_return = False;
                        break;
                    }
                }
                if all_cases_return {
                    return True;
                }
            }
        }
        if isinstance(stmt, uni.SwitchStmt) {
            if stmt.cases {
                has_default = False;
                all_cases_return = True;
                for case in stmt.cases {
                    switch_case: uni.SwitchCase = case;
                    if switch_case.pattern is None {
                        has_default = True;
                    }
                    if not self._body_always_returns(list(switch_case.body)) {
                        all_cases_return = False;
                    }
                }
                if has_default and all_cases_return {
                    return True;
                }
            }
        }
        if isinstance(stmt, uni.WithStmt) {
            if self._body_always_returns(list(stmt.body)) {
                return True;
            }
        }
        if isinstance(stmt, uni.TryStmt) {
            try_returns = self._body_always_returns(list(stmt.body));
            if try_returns {
                if not stmt.excepts or len(stmt.excepts) == 0 {
                    return True;
                }
                all_excepts_return = True;
                for exc in stmt.excepts {
                    except_clause: uni.Except = exc;
                    if not self._body_always_returns(list(except_clause.body)) {
                        all_excepts_return = False;
                        break;
                    }
                }
                if all_excepts_return {
                    return True;
                }
            }
        }
        if isinstance(stmt, uni.RaiseStmt) {
            return True;
        }
    }
    return False;
}

"""Exit a type alias node."""
impl TypeCheckPass.exit_type_alias(self: TypeCheckPass, nd: uni.TypeAlias) -> None { }

"""Exit an archetype node - traverse ImplDef body if present."""
impl TypeCheckPass.exit_archetype(self: TypeCheckPass, nd: uni.Archetype) -> None {
    self.evaluator.get_type_of_class(nd);
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

"""Set type on function/method parameters for hover info."""
impl TypeCheckPass.exit_param_var(self: TypeCheckPass, nd: uni.ParamVar) -> None {
    if (sym := nd.sym) {
        nd.type = self.evaluator.get_type_of_symbol(sym);
    }
}

"""Set type on class fields (has vars) and validate initializer type."""
impl TypeCheckPass.exit_has_var(self: TypeCheckPass, nd: uni.HasVar) -> None {
    if (sym := nd.sym) {
        nd.type = self.evaluator.get_type_of_symbol(sym);
        # If there's an initializer, check that its type is compatible
        # with the declared type (e.g., bad1: int = unknown_val;).
        if nd.value is not None and nd.type is not None {
            right_type = self.evaluator.get_type_of_expression(nd.value);
            if not self.evaluator.assign_type(right_type, nd.type) {
                self.log_error(f"Cannot assign {right_type} to {nd.type}", nd);
            }
        }
    }
}

"""Set type on for loop iteration variable and check iterability."""
impl TypeCheckPass.exit_in_for_stmt(self: TypeCheckPass, nd: uni.InForStmt) -> None {
    import from jaclang.compiler.type_system { types }
    # Cache type on the iteration target (e.g., 'coord' in 'for coord in p')
    if isinstance(nd.target, uni.Name) {
        self.evaluator.get_type_of_expression(nd.target);
    } elif isinstance(nd.target, (uni.TupleVal, uni.ListVal)) {
        self._eval_unpacking_names(nd.target);
    }
    # Check that the collection is iterable
    collection_type = self.evaluator.get_type_of_expression(nd.collection);
    # Check TypeVarType before is_any_type() — TypeVars are any-like but still need special handling.
    if isinstance(collection_type, types.TypeVarType) {
        if collection_type.bound
        and isinstance(collection_type.bound, types.ClassType) {
            # Bounded TypeVar - check if bound type has __iter__
            iter_result = self.evaluator.get_type_of_magic_method_call(
                collection_type.bound, "__iter__", [], nd.collection
            );
            if iter_result is None {
                self.log_error(f'Type "{collection_type.bound}" is not iterable', nd);
            }
        } else {
            # Unbounded TypeVar - not iterable
            self.log_error(f'Type "{collection_type.name}" is not iterable', nd);
        }
        # Skip check for UnknownType and any-like types (Any, object)
        # Following Pyright's pattern: these types are assumed to be iterable.
    } elif not isinstance(collection_type, types.UnknownType)
    and not collection_type.is_any_type() {
        # Enum classes are iterable via EnumMeta.__iter__ which is not in the
        # Jac type system's MRO. Skip the __iter__ check for enum classes.
        is_enum = (
            isinstance(collection_type, types.ClassType)
            and collection_type.is_enum_class()
        );
        if not is_enum {
            iter_result = self.evaluator.get_type_of_magic_method_call(
                collection_type, "__iter__", [], nd.collection
            );
            if iter_result is None {
                self.log_error(
                    f"Type {collection_type} is not iterable (no __iter__ method)", nd
                );
            }
        }
    }
}

"""Type-check raise statements — ensure raised value is an exception."""
impl TypeCheckPass.exit_raise_stmt(self: TypeCheckPass, nd: uni.RaiseStmt) -> None {
    import from jaclang.compiler.type_system { types }
    if nd.cause {
        cause_type = self.evaluator.get_type_of_expression(nd.cause);
        if isinstance(cause_type, types.ClassType)
        and not isinstance(cause_type, types.UnknownType) {
            is_exception = False;
            for cls in cause_type.shared.mro {
                if isinstance(cls, types.ClassType)
                and (cls.is_builtin("BaseException") or cls.is_builtin("Exception")) {
                    is_exception = True;
                    break;
                }
            }
            if not is_exception {
                self.log_error(
                    f"Cannot raise {cause_type} (not an exception type)", nd
                );
            }
        }
    }
}

"""Bind alias types from context manager BEFORE visiting body."""
impl TypeCheckPass.enter_with_stmt(self: TypeCheckPass, nd: uni.WithStmt) -> None {
    import from jaclang.compiler.type_system { types }
    for item in nd.exprs {
        ctx_item: uni.ExprAsItem = item;
        expr_type = self.evaluator.get_type_of_expression(ctx_item.expr);
        # Bind alias type - context managers typically return self from __enter__
        if ctx_item.alias is not None
        and not isinstance(expr_type, types.UnknownType) {
            if isinstance(ctx_item.alias, uni.Name) {
                ctx_item.alias.type = expr_type;
            }
        }
    }
}

"""Type-check with statements — verify context manager protocol."""
impl TypeCheckPass.exit_with_stmt(self: TypeCheckPass, nd: uni.WithStmt) -> None {
    import from jaclang.compiler.type_system { types }
    for item in nd.exprs {
        ctx_item: uni.ExprAsItem = item;
        expr_type = self.evaluator.get_type_of_expression(ctx_item.expr);
        if not isinstance(expr_type, types.UnknownType) {
            enter_result = self.evaluator.get_type_of_magic_method_call(
                expr_type, "__enter__", [], ctx_item.expr
            );
            if enter_result is None {
                self.log_error(
                    f"Type {expr_type} cannot be used in 'with' statement "
                    f"(no __enter__ method)",
                    nd
                );
            }
            # Check __exit__ method exists (required for context manager protocol).
            # Use direct member lookup instead of magic method call because
            # __exit__ takes 3 params (exc_type, exc_val, exc_tb) that we
            # don't have at this point — magic method call would fail on
            # argument matching even when __exit__ exists.
            if isinstance(expr_type, types.ClassType) {
                has_exit = (
                    self.evaluator._lookup_class_member(
                        expr_type, "__exit__"
                    ) is not None
                    or self.evaluator._lookup_object_member(
                        expr_type, "__exit__"
                    ) is not None
                );
                if not has_exit and not expr_type.is_any_type() {
                    self.log_error(
                        f"Type {expr_type} cannot be used in 'with' statement "
                        f"(no __exit__ method)",
                        nd
                    );
                }
            }
        }
    }
}

"""Type-check while statement condition expression."""
impl TypeCheckPass.exit_while_stmt(self: TypeCheckPass, nd: uni.WhileStmt) -> None {
    self.evaluator.get_type_of_expression(nd.condition);
}

"""Type-check assert statement condition and error message."""
impl TypeCheckPass.exit_assert_stmt(self: TypeCheckPass, nd: uni.AssertStmt) -> None {
    self.evaluator.get_type_of_expression(nd.condition);
    if nd.error_msg is not None {
        self.evaluator.get_type_of_expression(nd.error_msg);
    }
}

"""Type-check yield expressions against enclosing function's return type."""
impl TypeCheckPass.exit_yield_expr(self: TypeCheckPass, nd: uni.YieldExpr) -> None {
    import from jaclang.compiler.type_system { types }
    if nd.expr is None {
        return;
    }
    yielded_type = self.evaluator.get_type_of_expression(nd.expr);
    if (fn := self.evaluator._get_enclosing_function(nd)) {
        has_annotation = (
            isinstance(fn.signature, uni.FuncSignature)
            and fn.signature.return_type is not None
        );
        if has_annotation {
            fn_type_base = self.evaluator.get_type_of_ability(fn);
            fn_type: types.FunctionType = fn_type_base;
            return_type = self.evaluator._convert_to_instance(fn_type.return_type);
            if not isinstance(return_type, types.UnknownType) {
                if not nd.with_from {
                    # Regular yield: check yielded value against declared return type
                    if not self.evaluator.assign_type(yielded_type, return_type) {
                        self.log_error(
                            f"Cannot yield {yielded_type}, expected {fn_type.return_type}",
                            nd
                        );
                    }
                }
            }
        }
    }
}

"""Type-check delete statement target expression."""
impl TypeCheckPass.exit_delete_stmt(self: TypeCheckPass, nd: uni.DeleteStmt) -> None {
    self.evaluator.get_type_of_expression(nd.target);
}

"""Type-check visit statement target expression — must be a node type."""
impl TypeCheckPass.exit_visit_stmt(self: TypeCheckPass, nd: uni.VisitStmt) -> None {
    import from jaclang.compiler.type_system { types }
    target_type = self.evaluator.get_type_of_expression(nd.target);
    # Validate the visit target is a node (or unknown/any which we can't check)
    if (
        not isinstance(target_type, types.UnknownType)
        and not target_type.is_any_type()
    ) {
        is_valid = False;
        if isinstance(target_type, types.ClassType) {
            if target_type.is_node_type() {
                is_valid = True;
            }
            # Allow collections of nodes (e.g., list[NodeType])
            if (
                target_type.is_builtin()
                and target_type.shared.class_name in (
                    "list",
                    "tuple",
                    "set",
                    "frozenset"
                )
            ) {
                is_valid = True;
            }
        }
        if isinstance(target_type, types.UnionType) {
            is_valid = True;  # Could contain nodes, don't over-diagnose
        }
        if not is_valid {
            self.log_error(f"Visit target must be a node type, got {target_type}", nd);
        }
    }
}

"""Type-check report statement expression."""
impl TypeCheckPass.exit_report_stmt(self: TypeCheckPass, nd: uni.ReportStmt) -> None {
    self.evaluator.get_type_of_expression(nd.expr);
}

"""Validate postinit bodies assign to all 'by postinit' fields."""
impl TypeCheckPass.exit_impl_def(self: TypeCheckPass, nd: uni.ImplDef) -> None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    # Only check postinit impl definitions
    if not (
        nd.decl_link
        and isinstance(nd.decl_link, uni.Ability)
        and isinstance(nd.decl_link.name_ref, uni.SpecialVarRef)
        and nd.decl_link.name_ref.name == Tok.KW_POST_INIT
    ) {
        return;
    }
    # Find the parent archetype
    archetype = nd.decl_link.find_parent_of_type(uni.Archetype);
    if not archetype {
        return;
    }
    arch: uni.Archetype = archetype;
    # Collect by-postinit fields
    deferred_fields: dict[str, uni.HasVar] = {};
    for has_var_node in arch.get_has_vars() {
        has_var: uni.HasVar = has_var_node;
        if has_var.defer {
            deferred_fields[has_var.name.value] = has_var;
        }
    }
    if not deferred_fields {
        return;
    }
    # Scan for self.field = ... assignments in the impl body
    assigned: set[str] = set();
    for trailer in nd.get_all_sub_nodes(uni.AtomTrailer) {
        atom_trailer: uni.AtomTrailer = trailer;
        if not (
            atom_trailer.parent and isinstance(atom_trailer.parent, uni.Assignment)
        ) {
            continue;
        }
        if atom_trailer != atom_trailer.parent.target[0] {
            continue;
        }
        chain: list[uni.AstSymbolNode] = atom_trailer.as_attr_list;
        if len(chain) >= 2 and chain[0].sym_name == 'self' {
            assigned.add(chain[1].sym_name);
        }
    }
    # Report missing assignments
    for (field_name, field_node) in deferred_fields.items() {
        if field_name not in assigned {
            self.log_error(
                f"Field '{field_name}' declared 'by postinit' is never assigned "
                f"in {arch.name_spec.sym_name}.postinit",
                nd
            );
        }
    }
}

"""Validate TypeVar scope in type annotations.

Pyright: validateTypeVarUsage - TypeVars must be used in a valid scope.
A SubTag wraps type annotations (e.g., `x: int`, `has name: str`).
This validates all TypeVar usages including nested ones like `list[T]`.
"""
impl TypeCheckPass.exit_sub_tag(self: TypeCheckPass, nd: uni.SubTag[uni.T]) -> None {
    if isinstance(nd.tag, uni.Expr) {
        self.evaluator.validate_typevar_in_type_expr(nd.tag);
    }
}

"""Evaluate types for each Name in a tuple/list unpacking pattern."""
impl TypeCheckPass._eval_unpacking_names(
    self: TypeCheckPass, container: uni.Expr
) -> None {
    if isinstance(container, (uni.TupleVal, uni.ListVal)) {
        for val in container.values {
            if isinstance(val, uni.Name) {
                self.evaluator.get_type_of_expression(val);
            }
        }
    }
}
