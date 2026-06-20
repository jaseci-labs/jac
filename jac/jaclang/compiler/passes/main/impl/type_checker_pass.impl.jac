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
        # Skip Name nodes that only make sense in the context of their parent
        # node. Evaluating them as standalone names returns Unknown and emits
        # spurious W1051 warnings. The parent's exit handler resolves them
        # with proper context.
        #
        # - AtomTrailer.right: member access (e.g. `x.strip`) — resolved by
        #   the AtomTrailer handler with the base type.
        # - KWPair.key: keyword argument names (e.g. `name=` in `Thing(name="x")`)
        #   — these are parameter labels, not variable references.
        # - SubTag child: type annotation tags (e.g. `: int` in `has x: int`)
        #   — resolved during type annotation processing, not expression eval.
        # - JsxElementName part: JSX tag names (e.g. `div` in `<div>`, or
        #   `UI`/`Button` in `<UI.Button>`) — lowercase intrinsics resolve
        #   against the _JsxIntrinsicElements registry (not module scope) and
        #   uppercase component parts are resolved with JSX context by the
        #   JsxElement handler in the type evaluator.
        # - ModuleCode.name: the label of a named entry block (e.g. `__main__`
        #   in `with entry:__main__`) — an entry-point name, not a variable
        #   reference; it has no symbol and is not an expression.
        # - HasVar `by postinit` name: `postinit` names __post_init__, bound by the HasVar handler.
        if isinstance(nd.parent, uni.AtomTrailer) and nd.parent.right is nd {
            return;
        }
        if isinstance(nd.parent, uni.HasVar)
        and nd.parent.defer
        and nd is not nd.parent.name {
            return;
        }
        if isinstance(nd.parent, uni.KWPair) and nd.parent.key is nd {
            return;
        }
        if isinstance(nd.parent, uni.SubTag) {
            return;
        }
        if isinstance(nd.parent, uni.JsxElementName) {
            return;
        }
        if isinstance(nd.parent, uni.ModuleCode) and nd.parent.name is nd {
            return;
        }
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
    scope = self.evaluator._get_enclosing_return_scope(nd);
    if scope is None {
        return;
    }

    # Only Ability scopes need the E1003 / W2014 guards (lambdas skip these).
    if isinstance(scope, uni.Ability) {
        # Warn if returning a value from an event-driven ability.
        if (
            isinstance(scope.signature, uni.EventSignature)
            and nd.expr
            and not isinstance(nd.expr, uni.Null)
        ) {
            self.emit(W2014, node_override=nd);
            return;
        }
        # For top-level abilities without a return annotation, require one.
        if (
            nd.expr
            and not isinstance(nd.expr, uni.Null)
            and isinstance(
                scope.parent, (uni.Module, uni.Archetype, uni.Enum, uni.ImplDef)
            )
        ) {
            has_annotation = (
                isinstance(scope.signature, uni.FuncSignature)
                and scope.signature.return_type is not None
            );
            if not has_annotation {
                self.emit(E1003, node_override=nd);
                return;
            }
        }
    }

    return_type = self.evaluator._get_declared_return_type(scope);
    if return_type is None {
        return;
    }

    # In a generator function, `return x` is validated against the R
    # parameter of `Generator[Y, S, R]`, or skipped for iterator-family
    # types that carry no R.
    import from jaclang.compiler.type_system { type_utils }
    if isinstance(scope, uni.Ability) and scope.get_all_sub_nodes(uni.YieldExpr) {
        gen_return = type_utils.get_declared_generator_return_type(return_type);
        if gen_return is not None {
            return_type = self.evaluator._convert_to_instance(gen_return);
        } elif type_utils.is_generator_family_type(return_type) {
            return;
        }
    }

    returning_type = self.evaluator._convert_to_instance(
        self.evaluator.get_none_type()
    );
    if nd.expr {
        returning_type = self.evaluator.get_type_of_expression(
            nd.expr, expected_type=return_type
        );
    }

    if not self.evaluator.assign_type(
        returning_type, return_type, strict=self.evaluator._is_strict_site(nd)
    ) {
        # Returning an un-awaited coroutine where its resolved value is
        # expected: surface the missing `await` explicitly.
        if self.evaluator._is_awaitable_type(returning_type)
        and not self.evaluator._is_awaitable_type(return_type) {
            self.emit(
                E1042,
                node_override=nd,
                actual=str(returning_type),
                expected=str(return_type)
            );
            return;
        }
        self.emit(
            E1002,
            node_override=nd,
            actual=str(returning_type),
            expected=str(return_type)
        );
    }
}

"""Handle the edge operation reference node."""
impl TypeCheckPass.exit_filter_compr(self: TypeCheckPass, nd: uni.FilterCompr) -> None {
    self.evaluator.get_type_of_expression(nd);
}

# Count only expression-bodied lambdas: their body is re-typed in-context
# once params are seeded, so the expr exit handlers can safely defer it. A
# block body has no such re-eval, so its statements stay on normal traversal.
impl TypeCheckPass.enter_lambda_expr(self: TypeCheckPass, nd: uni.LambdaExpr) -> None {
    if isinstance(nd.body, uni.Expr) {
        self._lambda_depth += 1;
    }
}

impl TypeCheckPass.exit_lambda_expr(self: TypeCheckPass, nd: uni.LambdaExpr) -> None {
    if isinstance(nd.body, uni.Expr) {
        self._lambda_depth -= 1;
    }
}

"""Handle the function call node."""
impl TypeCheckPass.exit_func_call(self: TypeCheckPass, nd: uni.FuncCall) -> None {
    import from jaclang.compiler.symbol_utils {
        classify_call,
        ability_of_symbol,
        resolve_expr_symbol
    }
    # Inside a lambda body: defer arg validation to the lambda's own re-eval
    # (params not yet seeded). Stamp call-kind/callee from shape/symbol only;
    # evaluating the target would resolve it against an unseeded param.
    if self._lambda_depth > 0 {
        nd.call_kind = classify_call(nd).value;
        nd.callee_decl = ability_of_symbol(resolve_expr_symbol(nd.target));
        return;
    }
    self.evaluator.get_type_of_expression(nd);

    # Stamp the call-site classification on the tree so backends dispatch
    # on a stored fact instead of re-classifying at emission time.
    nd.call_kind = classify_call(nd).value;

    # Stamp the resolved callee declaration (Phase 4, analysis
    # centralization): backends read the resolved signature (parameters,
    # default-arg exprs) off the call node instead of keeping name-keyed
    # AST-signature caches. The expression evaluation above has already
    # populated `.sym` on the target, so this is a pure stamped-fact read.
    nd.callee_decl = ability_of_symbol(resolve_expr_symbol(nd.target));

    # Validate TypeVar usage in runtime context (e.g., list[T]())
    # Pyright: Type variable "T" has no meaning in this context
    if isinstance(nd.target, uni.AtomTrailer) and not nd.target.is_attr {
        if isinstance(nd.target.right, uni.IndexSlice) {
            idx_slice: uni.IndexSlice = nd.target.right;
            for slice in idx_slice.slices {
                slice_item: uni.Slice = slice;
                if slice_item.start {
                    self.evaluator.validate_typevar_in_type_expr(slice_item.start);
                }
            }
        }
    }
}

"""Handle JSX element node — validates props against component signature or intrinsic types."""
impl TypeCheckPass.exit_jsx_element(self: TypeCheckPass, nd: uni.JsxElement) -> None {
    self.evaluator.get_type_of_expression(nd);
}

"""Handle the binary expression node."""
impl TypeCheckPass.exit_binary_expr(self: TypeCheckPass, nd: uni.BinaryExpr) -> None {
    # Defer inside a lambda body (see exit_func_call).
    if self._lambda_depth > 0 {
        return;
    }
    self.evaluator.get_type_of_expression(nd);
}

"""Handle the atom trailer node."""
impl TypeCheckPass.exit_atom_trailer(self: TypeCheckPass, nd: uni.AtomTrailer) -> None {
    # Defer inside a lambda body (see exit_func_call).
    if self._lambda_depth > 0 {
        return;
    }
    self.evaluator.get_type_of_expression(nd);
}

"""Pyright: Checker.visitAssignment(node: AssignmentNode): boolean."""
impl TypeCheckPass.exit_assignment(self: TypeCheckPass, nd: uni.Assignment) -> None {
    import from jaclang.compiler.type_system { types }
    # Enum member declarations reuse the Assignment AST node but are a
    # distinct construct: the `=` binds the literal value, not for
    # variable-assignment type compatibility. The parser marks these with
    # is_enum_stmt=True for both inline (`enum Color { RED = 1 }`) and
    # impl-based (`enum Color; impl Color { RED = 1 }`) forms. Value-type
    # validation (against enum_value_type and per-member type annotations)
    # is owned by build_enum_members.
    if nd.is_enum_stmt {
        return;
    }
    if ((len(nd.target) == 1) and (nd.value is not None)) {
        target = nd.target[0];
        # Track whether this is a reassignment of a variable whose
        # declaration has no type annotation. Such a variable's declared
        # type is *inferred* and FROZEN at its first binding, exactly as
        # if that inferred type had been written as an explicit
        # annotation — so `a = 0; …; a = "str"` is a type error.
        #
        # Two exceptions keep idiomatic code annotation-free:
        #   * the `None`-sentinel pattern (`x = None; …; x = value`):
        #     when the first binding infers `NoneType`, the inferred type
        #     may evolve on later writes — mirroring TypeScript's
        #     strict-mode evolving locals.
        #   * the discard name `_`: it is a throwaway sink, so every
        #     binding to it is independent and carries no frozen type.
        # Any other first-binding type is enforced like an annotation.
        is_unannotated_reassign = False;
        # For assignment targets, use the declared symbol type (not the
        # narrowed type). Narrowing reflects the *current* value; the
        # variable's declared type determines what can be assigned to it.
        if isinstance(target, uni.Name) and target.sym {
            left_type = self.evaluator.get_type_of_symbol(target.sym);
            # Detect unannotated reassignment: the current target is not
            # the declaration site and the declaration has no type
            # annotation (plain `x = expr` form).
            if (
                target.sym.decl.name_of is not target
                and isinstance(target.sym.decl.name_of.parent, uni.Assignment)
                and target.sym.decl.name_of.parent.type_tag is None
            ) {
                is_unannotated_reassign = True;
                # `node_.type` caches the narrow literal as the hover type, so
                # widen it to the frozen declared type before the compat check.
                # See `_widen_literal_for_declaration`.
                left_type = self.evaluator._widen_literal_for_declaration(left_type);
            }
            # `target.type` is the hover cache — show the post-write type
            # for re-assignments, declared type otherwise. `left_type`
            # stays declared for the compat check and bare-generic warnings.
            if hover_type := self.evaluator._get_type_of_lhs_assignment(target) {
                target.type = self.evaluator._convert_to_instance(hover_type);
            } else {
                target.type = left_type;
            }
            # Warn on bare generic / explicit-any type annotations (e.g. x: list = [])
            if nd.type_tag and nd.type_tag.tag {
                self._check_bare_generic(nd.type_tag.tag, left_type);
                self._check_explicit_any(nd.type_tag.tag);
            }
        } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
            # Tuple/list unpacking: (px, py) = p; or [a, b] = lst;
            # Individual element types are inferred by _eval_unpacking_names.
            # Skip whole-expression assign_type check since the LHS container
            # type (tuple/list) is not directly comparable to the RHS iterable.
            self._eval_unpacking_names(target);
            right_type = self.evaluator.get_type_of_expression(nd.value);
            # Check that the RHS is iterable for destructuring. `any` (the
            # gradual-typing escape hatch) and an unresolved type are treated as
            # unpackable — under gradual typing an `Any` value may be a tuple at
            # runtime, so unpacking it is always allowed. This also keeps native
            # codespace congruent with the server: there `list.pop()` on a bare
            # `list` infers `any`, and rejecting that would be a portability
            # asymmetry (see #6435).
            if not isinstance(right_type, (types.UnknownType, types.AnyType)) {
                iter_result = self.evaluator.get_type_of_magic_method_call(
                    right_type, "__iter__", [], nd.value
                );
                if iter_result is None {
                    self.emit(E1020, node_override=nd, type=str(right_type));
                }
            }
            return;
        } else {
            # Handle typed assignment: target: Type = value
            # Propagate type annotation to the target node
            if nd.type_tag and nd.type_tag.tag {
                declared_type = self.evaluator.get_type_of_expression(nd.type_tag.tag);
                # Warn on bare generic / explicit-any type annotations
                self._check_bare_generic(nd.type_tag.tag, declared_type);
                self._check_explicit_any(nd.type_tag.tag);
                # Convert class type to instance for assignment checking.
                # Type annotations like `x: int` resolve to the class `int`
                # (instantiable), but the LHS of an assignment represents an
                # instance. Without this, `self.x: int = 5` falsely reports
                # "Cannot assign int to int" (instance vs class mismatch).
                declared_inst = self.evaluator._convert_to_instance(declared_type);
                target.type = declared_inst;
                # For AtomTrailer (e.g., self.attr), also set type on the attribute Name
                if isinstance(target, uni.AtomTrailer) {
                    chain = target.as_attr_list;
                    if len(chain) >= 2 {
                        chain[-1].type = declared_inst;
                    }
                }
                left_type = declared_inst;
            } else {
                left_type = self.evaluator.get_type_of_expression(target);
                # For field assignments (e.g., obj.field = value), the target
                # expression type may be narrowed (e.g., NoneType inside an
                # `if obj.field is None` block). Use the declared field type
                # for the assignment check instead of the narrowed type.
                if isinstance(target, uni.AtomTrailer) and target.is_attr {
                    if isinstance(target.right, uni.Name) and target.right.sym {
                        import from jaclang.compiler.type_system.type_utils {
                            PropertyWriteKind
                        }
                        target_sym = target.right.sym;
                        prop_result = self.evaluator.get_property_write_type(
                            target_sym
                        );
                        if prop_result.kind == PropertyWriteKind.WRITABLE {
                            left_type = prop_result.write_type;
                        } elif prop_result.kind == PropertyWriteKind.READ_ONLY {
                            self.emit(
                                E1005, node_override=target, name=target.right.value
                            );
                            return;
                        } else {
                            # NOT_PROPERTY — use the declared symbol type.
                            declared = self.evaluator.get_type_of_symbol(target_sym);
                            if declared {
                                left_type = declared;
                            }
                        }
                    }
                }
            }
        }
        # Pass declared LHS type as expected_type for bidirectional inference
        right_type = self.evaluator.get_type_of_expression(
            nd.value, expected_type=left_type
        );

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
                    self.emit(E1060, node_override=target, name=right_type.name);
                } else {
                    # Validation 2: TypeVar name must match the variable name
                    # e.g., T2 = TypeVar("T3") is an error
                    name_target: uni.Name = target;
                    if name_target.value != right_type.name {
                        self.emit(
                            E1061,
                            node_override=name_target,
                            name=right_type.name,
                            var=name_target.value
                        );
                    }
                }
            }
        }

        # Augmented assignment TypeVar check
        # e.g., a += 3 where a is TypeVar is an error (unless bound/constraints support it)
        if nd.aug_op and isinstance(left_type, types.TypeVarType) {
            import from jaclang.compiler.type_system { operations }
            op_name = operations.AUG_OPERATOR_MAP.get(nd.aug_op.name);
            # Constrained TypeVar - check all constraint types
            if left_type.constraints {
                for constraint_type in left_type.constraints {
                    if isinstance(constraint_type, types.ClassType) {
                        if op_name {
                            result = self.evaluator.get_type_of_magic_method_call(
                                constraint_type, op_name, [nd.value], None
                            );
                            if result is None {
                                self.emit(
                                    E1010,
                                    node_override=nd,
                                    op=nd.aug_op.name,
                                    type=str(constraint_type)
                                );
                            }
                        }
                    }
                }
            } elif left_type.bound and isinstance(left_type.bound, types.ClassType) {
                # Bounded TypeVar - check if bound supports __iadd__ (etc)
                if op_name {
                    result = self.evaluator.get_type_of_magic_method_call(
                        left_type.bound, op_name, [nd.value], nd
                    );
                    if result is None {
                        self.emit(
                            E1010,
                            node_override=nd,
                            op=nd.aug_op.name,
                            type=str(left_type.bound)
                        );
                    }
                } else {
                    self.emit(
                        E1010,
                        node_override=nd,
                        op=nd.aug_op.name,
                        type=str(left_type.bound)
                    );
                }
            } else {
                # Unbounded TypeVar
                self.emit(
                    E1010, node_override=nd, op=nd.aug_op.name, type=left_type.name
                );
            }
        } else {
            # An unannotated reassignment skips the compatibility check
            # only for a `None`-sentinel (inferred type may still evolve)
            # or the `_` discard (every binding to it is independent).
            # All other unannotated variables are frozen to their
            # first-binding type (`left_type`) and enforced here.
            is_evolving_reassign = is_unannotated_reassign
            and (
                self.evaluator.is_none_type(left_type)
                or (isinstance(target, uni.Name) and target.value == "_")
            );
            if (
                not is_evolving_reassign
                and not self.evaluator.assign_type(
                    right_type, left_type, strict=self.evaluator._is_strict_site(nd)
                )
            ) {
                # A coroutine assigned where its awaited value is expected is
                # a missing-`await` bug — point at the fix rather than the
                # generic "cannot assign Coroutine[...]" message.
                if self.evaluator._is_awaitable_type(right_type) {
                    self.emit(E1042, actual=str(right_type), expected=str(left_type));
                } else {
                    self.emit(E1001, actual=str(right_type), expected=str(left_type));
                }
            }
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
                            self.emit(
                                E1011,
                                node_override=nd,
                                op=nd.aug_op.value,
                                left=str(left_type),
                                right=str(right_type)
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
    # A native C-FFI import (`import from foo { def ...; }`) names a shared
    # library, not a managed module: its symbols come from `clib_decls`, and the
    # from-path is resolved per-platform by the native backend. Resolving it as a
    # managed module would (for a bare-name path like `raylib`) hit sys.path and
    # spuriously emit W1100 "module not found". Treat it as fully inert here.
    if nd.clib_decls {
        return;
    }
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

    # Error if an obj/node/edge/walker method has an explicit 'self' parameter.
    # In these archetype types, 'self' is implicit and must not appear in the signature.
    if (
        isinstance(nd.signature, uni.FuncSignature)
        and not nd.is_static
        and not nd.is_classmethod
    ) {
        owner = nd.method_owner;
        if (
            isinstance(owner, uni.Archetype)
            and owner.arch_type.value in ("obj", "node", "edge", "walker")
        ) {
            all_params = nd.signature.get_parameters();
            if (
                len(all_params) > 0
                and isinstance(all_params[0].name, uni.Name)
                and all_params[0].name.value == "self"
            ) {
                self.emit(
                    E2015,
                    node_override=all_params[0],
                    arch_type=owner.arch_type.value,
                    name=nd.name_spec.sym_name
                );
            }
        }
    }

    # ImplDef body is not in kid list, traverse it explicitly.
    if isinstance(nd.body, uni.ImplDef) {
        self.traverse(nd.body);
    }
    # Warn on bare generic return type annotations (e.g. def f -> list).
    # Runs regardless of body shape — abstract/overload/stub decls also benefit.
    # Skip impl-side abilities to avoid double-firing (see exit_param_var).
    if (
        isinstance(nd.signature, uni.FuncSignature)
        and nd.signature.return_type is not None
        and nd.find_parent_of_type(uni.ImplDef) is None
    ) {
        ret_ann_type = self.evaluator.get_type_of_expression(nd.signature.return_type);
        self._check_bare_generic(nd.signature.return_type, ret_ann_type);
        self._check_explicit_any(nd.signature.return_type);
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
        # Skip stub functions (body is only ellipsis and/or semicolons)
        is_stub = self.evaluator._is_ellipsis_only_body(nd.body);
        if not is_overload and not is_generator and not is_stub {
            ret_type = self.evaluator.get_type_of_expression(nd.signature.return_type);
            ret_inst = self.evaluator._convert_to_instance(ret_type);
            none_type = self.evaluator._convert_to_instance(
                self.evaluator.get_none_type()
            );
            if not self.evaluator.assign_type(none_type, ret_inst) {
                if not self._body_always_returns(nd.body) {
                    self.emit(
                        E1004,
                        node_override=nd,
                        name=nd.name_spec.sym_name,
                        ret_type=str(ret_type)
                    );
                }
            }
        }
    }
    # Validate event-signature trigger matches the owning archetype kind:
    # walker abilities fire on nodes/edges/Root; node and edge abilities
    # fire on walkers. See JacWalker._execute_entries / _execute_exits.
    if (
        isinstance(nd.signature, uni.EventSignature)
        and nd.signature.arch_tag_info is not None
    ) {
        self._check_event_trigger_archetype(nd);
    }
    # Warn on a JSX component defined with an untyped props bag (`props: any`).
    # A single parameter named `props` is the props-bag pattern (see the
    # codegen heuristic in esast_gen_pass); when that parameter is untyped,
    # every JSX prop on the component is unchecked — flag it once here (W1052).
    if (
        isinstance(nd.signature, uni.FuncSignature)
        and nd.signature.return_type is not None
        and nd.find_parent_of_type(uni.ImplDef) is None
    ) {
        comp_params = [
            p
            for p in nd.signature.get_parameters()
            if isinstance(p.name, uni.Name) and p.name.value not in ("self", "cls")
        ];
        if (
            len(comp_params) == 1
            and isinstance(comp_params[0].name, uni.Name)
            and comp_params[0].name.value == "props"
        ) {
            props_param = comp_params[0];
            any_cls = self.evaluator.prefetch.any_class
                if self.evaluator.prefetch
                else None;
            # `props: any` resolves to the prefetched `any` ClassType, not
            # AnyType — an unannotated param has no type_tag.
            is_untyped_bag = (
                props_param.type_tag is None
                or isinstance(props_param.type, types.AnyType)
                or (
                    any_cls is not None
                    and isinstance(props_param.type, types.ClassType)
                    and props_param.type.shared == any_cls.shared
                )
            );
            jsx_cls = self.evaluator.prefetch.jsx_element_class
                if self.evaluator.prefetch
                else None;
            ret_type = self.evaluator.get_type_of_expression(nd.signature.return_type);
            is_jsx_component = (
                jsx_cls is not None
                and isinstance(ret_type, types.ClassType)
                and ret_type.shared == jsx_cls.shared
            );
            if is_untyped_bag and is_jsx_component {
                self.emit(
                    W1052, node_override=props_param, component=nd.name_spec.sym_name
                );
            }
        }
    }
}

"""Validate `can ... with X entry/exit` triggers against the owning
archetype.

The runtime contract (jac0core/runtime.jac `JacWalker._execute_entries`
and `_execute_exits`) is:
    walker._jac_entry_funcs_   trigger ⊆ NodeArchetype | EdgeArchetype
    node/edge._jac_entry_funcs_  trigger ⊆ WalkerArchetype

`with entry` / `with exit` (no trigger) is always valid — those handlers
fire on every step. The trigger expression can be a single class, a
tuple `(A, B)` (treated element-wise), or a `|` union; all elements /
members must satisfy the rule. Any/Unknown is skipped to avoid
duplicating W2001 / W1051 diagnostics on the same span."""
impl TypeCheckPass._check_event_trigger_archetype(
    self: TypeCheckPass, nd: uni.Ability
) -> None {
    import from jaclang.compiler.type_system { types }
    sig = nd.signature;
    if not isinstance(sig, uni.EventSignature) or sig.arch_tag_info is None {
        return;
    }
    owner = nd.method_owner;
    if not isinstance(owner, uni.Archetype) {
        return;
    }
    owner_kind = owner.arch_kind;
    if owner_kind is None {
        return;
    }
    walker_owner = owner_kind == "walker";

    def is_valid(t: types.TypeBase) -> bool {
        if t.is_any_type() or isinstance(t, types.UnknownType) {
            return True;
        }
        if isinstance(t, types.UnionType) {
            return all(is_valid(m) for m in t.types);
        }
        if isinstance(t, types.ClassType) {
            if walker_owner {
                return t.is_node_type() or t.is_edge_type();
            }
            return t.is_walker_type();
        }
        return False;
    }

    def collect_union_leaves(expr: uni.Expr) -> list[uni.Expr] {
        if (
            isinstance(expr, uni.BinaryExpr)
            and isinstance(expr.op, uni.Token)
            and expr.op.name == Tok.BW_OR
        ) {
            return collect_union_leaves(expr.left) + collect_union_leaves(expr.right);
        }
        return [expr];
    }

    # Tuple form `(A, B)` and union form `A | B` are both expanded
    # per element so each bad type (including `root` keyword) gets its
    # own diagnostic rather than being masked by type evaluation.
    targets: list[uni.Expr] = (
        list(sig.arch_tag_info.values)
            if (
                isinstance(sig.arch_tag_info, uni.TupleVal) and sig.arch_tag_info.values
            )
            else collect_union_leaves(sig.arch_tag_info)
    );
    err = E1116 if walker_owner else E1117;
    resolved: list[types.TypeBase] = [];
    for arg in targets {
        ty = self.evaluator.get_type_of_expression(arg);
        resolved.append(ty);
        if isinstance(ty, types.ClassType) and ty.is_instance() {
            # Only name leaves carry `.value`; other exprs (e.g. `N()`) fall back to the type name.
            label = arg.value if isinstance(arg, uni.Name) else str(ty);
            self.emit(err, node_override=arg, type=label);
            continue;
        }
        if not is_valid(ty) {
            self.emit(err, node_override=arg, type=str(ty));
        }
    }
    # Record the resolved trigger types on the Ability so backends can
    # consume them without re-walking the trigger expression AST.
    nd.event_triggers = resolved;
}

"""Check if a code block always returns a value on all paths.

Delegates to TypeEvaluator._collect_return_types which is the canonical
control-flow analysis for return statements — used both here (boolean only)
and in lambda block-body return type inference (boolean + collected types)."""
impl TypeCheckPass._body_always_returns(
    self: TypeCheckPass, body: list[uni.CodeBlockStmt]
) -> bool {
    return self.evaluator._collect_return_types(body, []);
}

"""Emit W1036 for bare generic type annotations.

A "bare generic" is a generic class (one declared with type_params) used
without explicit type_args at the use site — e.g. `list` instead of
`list[int]`, `dict` instead of `dict[str, int]`. PEP 484 says these
default to `T[Any]`, which silently erases element types and weakens
downstream inference.

`ann_node` is the AST location to attach the warning to (typically the
type-tag expression). Walks union branches so `list | None` warns on the
bare `list`. Does not recurse into existing type_args — `dict[str, list]`
warns only on the outer if outer is bare; nested bare generics are out of
scope for now (locating the inner AST node would require parallel walking)."""
impl TypeCheckPass._check_bare_generic(
    self: TypeCheckPass, ann_node: uni.UniNode, ty: object
) -> None {
    import from jaclang.compiler.type_system { types }
    if isinstance(ty, types.UnionType) and ty.types {
        for branch in ty.types {
            self._check_bare_generic(ann_node, branch);
        }
        return;
    }
    if (
        isinstance(ty, types.ClassType)
        and ty.shared
        and ty.shared.type_params
        and (not ty.private or not ty.private.type_args)
    ) {
        self.emit(W1036, node_override=ann_node, type=ty.shared.class_name);
    }
}

"""Flag E1119 on lambda params left Unknown once the module is fully typed.

Runs in after_pass, not exit_lambda_expr: a param is seeded by the enclosing
call/assignment, whose handler runs after the lambda's own, so the settled
type is only trustworthy once the whole module is typed."""
impl TypeCheckPass._check_unresolved_lambda_params(self: TypeCheckPass) -> None {
    import from jaclang.compiler.type_system { types }
    if self.ir_in is None {
        return;
    }
    for lam in self.ir_in.get_all_sub_nodes(uni.LambdaExpr) {
        if lam.signature is None {
            continue;
        }
        for param in lam.signature.get_parameters() {
            if param.type_tag is not None {
                continue;
            }
            # Context-seeding writes the inferred type onto the param's Name.
            resolved = param.name.type;
            if resolved is None or isinstance(resolved, types.UnknownType) {
                self.emit(E1119, node_override=param.name, name=param.name.value);
            }
        }
    }
}

"""Emit W1037 for explicit `any` type annotations.

`any` is the gradual-typing escape hatch: annotating something `any`
silently disables member-access, call-signature, and assignment checking
on it. That is occasionally intentional (interop boundaries, genuinely
dynamic data), so this is a warning rather than an error — but most uses
are oversights that hide real bugs behind an un-checkable type.

`ann_node` is the annotation AST node (a type-tag expression or signature
return type). Walks the whole subtree so nested forms each warn at their
own `any` — `list[any]`, `any | None`, callable params/returns.

Both spellings of explicit Any are caught: the lowercase `any` builtin
keyword (matched syntactically on its `BuiltinType` node) and `typing.Any`
(matched by type identity against the prefetched `Any` class). Matching
`typing.Any` by resolved type rather than by name means an alias such as
`from typing import Any as A` still warns, while a user-defined class that
happens to be named `Any` does not."""
impl TypeCheckPass._check_explicit_any(
    self: TypeCheckPass, ann_node: uni.UniNode
) -> None {
    if isinstance(ann_node, uni.BuiltinType) and ann_node.value == "any" {
        self.emit(W1037, node_override=ann_node);
    }
    for sub in ann_node.get_all_sub_nodes(uni.BuiltinType) {
        if sub.value == "any" {
            self.emit(W1037, node_override=sub);
        }
    }
    # `typing.Any` is the same gradual-typing escape hatch as `any`, but
    # spelled as a name reference. Only `Any`-named candidates are resolved
    # (cheap, and avoids touching unrelated names); the type check then
    # confirms the reference truly is the prefetched `typing.Any` class.
    names = ann_node.get_all_sub_nodes(uni.Name);
    if isinstance(ann_node, uni.Name) {
        names = [ann_node] + names;
    }
    for nm in names {
        if nm.sym_name != "Any" {
            continue;
        }
        # For the `typing.Any` attribute form the bare `Any` token is the
        # member of a trailer, not a standalone reference — resolve the whole
        # trailer, but still anchor the warning at the `Any` token.
        resolve_target: uni.Expr = nm;
        parent = nm.parent;
        if (
            isinstance(parent, uni.AtomTrailer)
            and parent.is_attr
            and (parent.right is nm)
        ) {
            resolve_target = parent;
        }
        if self.evaluator.is_explicit_any(
            self.evaluator.get_type_of_expression(resolve_target)
        ) {
            self.emit(W1037, node_override=nm);
        }
    }
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
    cls_type = self.evaluator.get_type_of_enum(nd);
    # Type-check each enum member name so W1051 fires for unresolved members.
    for child in nd.kid {
        if isinstance(child, uni.Assignment) {
            for target in child.target {
                self.evaluator.get_type_of_expression(target);
            }
        }
    }
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

"""Initialize the checker pass."""
impl TypeCheckPass.before_pass(self: TypeCheckPass) -> None {
    self.evaluator = self.prog.get_type_evaluator();
    # Nested compiles (TypeEvaluator import resolution, boundary walks) run
    # their own TypeCheckPass on the shared evaluator. Save the previous
    # reporter so after_pass can restore it — otherwise an inner inference
    # run would leave itself installed and the OUTER pass's remaining
    # evaluator diagnostics would be misattributed (and mode-gated wrong).
    self._prev_eval_pass = self.evaluator._pass;
    self.evaluator._pass = self;
    self._insert_builtin_symbols();
    self.evaluator._narrowing_cache = {};
    # Typed-tree contract diagnostic mode: inference itself is unconditional
    # (every full compile runs this pass so Expr.type is populated for all
    # backends), but when scheduled as the inference entry (TypeInferencePass,
    # inference_only=True) TYPE diagnostics are only *surfaced* when (a) the
    # compile explicitly asked for type checking (`jac check` /
    # options.type_check), or (b) the module is native-context — a .na.jac
    # file, a .jac with a `na {}` block, or an auto-promoted module —
    # preserving native type discipline (#6049) without leaking checker
    # false positives into plain sv/cl builds (#6262). Direct TypeCheckPass
    # invocations (tests, tooling) always emit in full.
    #
    # The check intent is read from the module (stamped by JacCompiler.compile
    # right before scheduling inference), NOT from prog._compile_options:
    # get_type_evaluator() above triggers nested compiles (stub prefetch,
    # builtin imports) that each overwrite the program's ambient options
    # before this gate runs, which silently downgraded `jac check` runs to
    # suppressed mode (diagnostics stashed, never replayed).
    emit_full = (not self.inference_only) or bool(self.ir_in?._type_check_requested);
    if not emit_full {
        mod = self.ir_in;
        mp = mod.loc.mod_path if mod?.loc else '';
        is_native_mod = bool(mp) and mp.endswith('.na.jac');
        if not is_native_mod and mod?.body {
            for _stmt in mod.body {
                if isinstance(_stmt, uni.NativeBlock) {
                    is_native_mod = True;
                    break;
                }
            }
        }
        if (
            not is_native_mod
            and self.prog._auto_promote_native
            and mod?.gen
            and mod.gen.native_compat
        ) {
            is_native_mod = True;
        }
        emit_full = is_native_mod;
    }
    # Re-typing sweeps over JIR-loaded dependency modules (see the dep loop
    # in JacCompiler.compile) exist solely to repopulate Expr.type for
    # codegen. Their cross-module link state is degraded relative to a fresh
    # front-end run, so checking them in full mode produces false positives;
    # the entry module's own run owns user-facing diagnostics.
    if self.inference_only and self.ir_in?._inference_quiet {
        emit_full = False;
    }
    self._emit_diagnostics = emit_full;
    # A full-diagnostic run over a tree already typed by a suppressed
    # inference run would cache-hit Expr.type everywhere, never re-deriving
    # the diagnostics that run deferred (and emitting the rest out of
    # traversal order). Reset the module's type memoization so this run
    # re-derives — and re-emits — everything in natural order; emit() evicts
    # each stash entry as its live twin lands, and after_pass replays only
    # cross-module leftovers.
    if emit_full and self.ir_in?._deferred_type_diags {
        stack = [self.ir_in];
        while stack {
            cur = stack.pop();
            if isinstance(cur, uni.Expr) {
                cur.type = None;
            }
            stack.extend(cur.kid);
        }
        # Flow-narrowing caches from the suppressed run were computed against
        # the now-cleared Expr.type results; stale entries would skew the
        # re-derivation. Clear them so narrowing re-runs from scratch too.
        self.evaluator._flow_node_type_cache.clear();
        self.evaluator._and_narrowing_overrides.clear();
    }
}

impl TypeCheckPass.after_pass(self: TypeCheckPass) -> None {
    # Full-diagnostic-only. Lambda check first, so a live E1119 evicts any
    # stashed copy before the replay loop reaches it.
    if getattr(self, '_emit_diagnostics', True) {
        self._check_unresolved_lambda_params();
        # Replay diagnostics deferred by earlier suppressed inference runs:
        # Expr.type memoization means this run couldn't re-derive them live.
        stash = self.ir_in?._deferred_type_diags;
        if stash {
            for (diag, node_override, related, help_text, kwargs) in list(
                stash.values()
            ) {
                super.emit(
                    diag,
                    node_override=node_override,
                    related=related,
                    help_text=help_text,
                    **kwargs
                );
            }
            stash.clear();
        }
    }
    # Restore the evaluator's previous diagnostic reporter (see before_pass)
    # for nested runs only. Top-level runs (no previous reporter) stay
    # installed, matching the historical contract: evaluator queries during
    # later codegen passes still have a diagnostic sink (deferred or live
    # per this pass's mode) instead of dropping on the floor.
    if self._prev_eval_pass is not None and self.evaluator._pass is self {
        self.evaluator._pass = self._prev_eval_pass;
    }
}

impl TypeCheckPass.emit(
    self: TypeCheckPass,
    diag: DiagnosticInfo,
    node_override: (uni.UniNode | None) = None,
    related: (list[tuple[str, uni.UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: any
) -> bool {
    import from jaclang.jac0core.diagnostics { Category }
    if diag.category != Category.ICE {
        stash = self.ir_in?._deferred_type_diags;
        key = (
            diag.code,
            id(node_override) if node_override is not None else 0,
            str(kwargs)
        );
        if not getattr(self, '_emit_diagnostics', True) {
            # Defer instead of drop: the evaluator memoizes on Expr.type, so
            # a later full-diagnostic run (direct TypeCheckPass / `jac
            # check`) cache-hits and can never re-derive what this run
            # found. after_pass of that run replays the stash.
            if stash is None {
                stash = {};
                self.ir_in._deferred_type_diags = stash;
            }
            if key not in stash {
                stash[key] = (diag, node_override, related, help_text, kwargs);
            }
            return False;
        }
        # Full-emit mode: a live emission supersedes its deferred copy.
        if stash is not None and key in stash {
            del stash[key];
        }
    }
    return super.emit(
        diag,
        node_override=node_override,
        related=related,
        help_text=help_text,
        **kwargs
    );
}


"""Set type on function/method parameters for hover info."""
impl TypeCheckPass.exit_param_var(self: TypeCheckPass, nd: uni.ParamVar) -> None {
    if (sym := nd.sym) {
        declared_type = self.evaluator.get_type_of_symbol(sym);
        nd.type = declared_type;
        # Warn on bare generic parameter annotations (e.g. def f(x: list)).
        # Skip when this param is inside an `impl` block — the decl-side
        # ParamVar carries the same annotation and will emit the warning.
        # Without this guard, top-level ImplDefs are visited twice (once by
        # natural module traversal, once by the explicit traverse(nd.body)
        # in exit_ability for the decl), producing duplicate warnings.
        if (
            nd.type_tag
            and nd.type_tag.tag
            and nd.find_parent_of_type(uni.ImplDef) is None
        ) {
            self._check_bare_generic(nd.type_tag.tag, declared_type);
            self._check_explicit_any(nd.type_tag.tag);
        }
    }
}

"""Set type on class fields (has vars) and validate initializer type."""
impl TypeCheckPass.exit_has_var(self: TypeCheckPass, nd: uni.HasVar) -> None {
    import from jaclang.compiler.type_system { types }
    if (nd.defer and nd.kid and isinstance(nd.kid[-1], uni.Name)) {
        postinit_nd: uni.Name = nd.kid[-1];
        if postinit_nd.sym is None {
            arch = nd.parent.parent if isinstance(nd.parent, uni.ArchHas) else None;
            if isinstance(arch, uni.Archetype) {
                postinit_sym = arch.names_in_scope.get("__post_init__");
                if postinit_sym is not None {
                    postinit_nd._sym = postinit_sym;
                }
            } elif isinstance(arch, uni.ImplDef)
            and isinstance(arch.decl_link, uni.Archetype) {
                # has field in a separate impl block: decl_link points to the archetype
                if (
                    postinit_sym := arch.decl_link.names_in_scope.get("__post_init__")
                ) is not None {
                    postinit_nd._sym = postinit_sym;
                }
            }
        }
    }
    if (sym := nd.sym) {
        declared_type = self.evaluator.get_type_of_symbol(sym);
        nd.type = declared_type;
        # Warn on bare generic / explicit-any annotations (e.g. has items: list)
        if nd.type_tag and nd.type_tag.tag {
            self._check_bare_generic(nd.type_tag.tag, declared_type);
            self._check_explicit_any(nd.type_tag.tag);
        }
        # Walker-specific: `has reports` is the typed view of the walker's
        # report channel. Require a list shape so `report X` (write side)
        # and `(spawn W).reports` (read side) share a single element type.
        self._check_walker_reports_shape(nd, declared_type);
        # If there's an initializer, check that its type is compatible
        # with the declared type (e.g., bad1: int = unknown_val;). The
        # declared type flows as the expected type so empty collection
        # literal defaults (`has xs: list[str] = []`) are stamped with the
        # declared element type (bidirectional inference).
        if nd.value is not None and nd.type is not None {
            right_type = self.evaluator.get_type_of_expression(
                nd.value, expected_type=nd.type
            );
            if not self.evaluator.assign_type(
                right_type, nd.type, strict=self.evaluator._is_strict_site(nd)
            ) {
                self.emit(
                    E1001,
                    node_override=nd,
                    actual=str(right_type),
                    expected=str(nd.type)
                );
            }
        }
    }
}

"""Validate that `has reports` on a walker archetype is a list type.

Untyped/inherited `reports: list[Any]` (from the builtin `Walker` class)
is unaffected — this check only fires when the user *explicitly* shadows
`reports` with a concrete shape on a walker archetype.
"""
impl TypeCheckPass._check_walker_reports_shape(
    self: TypeCheckPass, nd: uni.HasVar, declared_type: object
) -> None {
    import from jaclang.compiler.type_system { types }
    if nd.name.value != "reports" {
        return;
    }
    arch = nd.parent.parent if isinstance(nd.parent, uni.ArchHas) else None;
    if isinstance(arch, uni.ImplDef) and isinstance(arch.decl_link, uni.Archetype) {
        arch = arch.decl_link;
    }
    if not isinstance(arch, uni.Archetype) {
        return;
    }
    if arch.arch_kind != "walker" {
        return;
    }
    # Don't pile errors on top of upstream type-resolution failures.
    if isinstance(declared_type, types.UnknownType) {
        return;
    }
    if isinstance(declared_type, types.ClassType) {
        if declared_type.is_any_type() or declared_type.is_builtin("list") {
            return;
        }
    }
    self.emit(E1112, node_override=nd, type=str(declared_type));
}

"""Find the element type of the enclosing walker's declared `has reports: list[T]`.

Returns None when (a) there is no enclosing walker, (b) the walker doesn't
locally declare `reports`, or (c) the declared shape isn't `list[T]` with a
concrete element type. Inherited `list[Any]` from the builtin `Walker`
returns None too — `Any` already permits everything via assign_type, so
there's nothing to enforce.
"""
impl TypeCheckPass._enclosing_walker_report_elem_type(
    self: TypeCheckPass, nd: uni.UniNode
) -> object {
    import from jaclang.compiler.type_system { types }
    arch = nd.find_parent_of_type(uni.Archetype);
    if arch is None {
        impl_def = nd.find_parent_of_type(uni.ImplDef);
        if impl_def is not None and isinstance(impl_def.decl_link, uni.Archetype) {
            arch = impl_def.decl_link;
        }
    }
    if not isinstance(arch, uni.Archetype) or arch.arch_kind != "walker" {
        return None;
    }
    for has_var in arch.get_has_vars() {
        if has_var.name.value != "reports" {
            continue;
        }
        if has_var.sym is None {
            return None;
        }
        declared = self.evaluator.get_type_of_symbol(has_var.sym);
        if (
            isinstance(declared, types.ClassType)
            and declared.is_builtin("list")
            and declared.private
            and declared.private.type_args
            and len(declared.private.type_args) >= 1
        ) {
            return declared.private.type_args[0];
        }
        return None;
    }
    return None;
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
        # Constrained TypeVar - check all constraint types
        if collection_type.constraints {
            for constraint_type in collection_type.constraints {
                if isinstance(constraint_type, types.ClassType) {
                    iter_result = self.evaluator.get_type_of_magic_method_call(
                        constraint_type, "__iter__", [], None
                    );
                    if iter_result is None {
                        self.emit(E1021, node_override=nd, type=str(constraint_type));
                    }
                }
            }
        } elif collection_type.bound
        and isinstance(collection_type.bound, types.ClassType) {
            # Bounded TypeVar - check if bound type has __iter__
            iter_result = self.evaluator.get_type_of_magic_method_call(
                collection_type.bound, "__iter__", [], nd.collection
            );
            if iter_result is None {
                self.emit(E1021, node_override=nd, type=str(collection_type.bound));
            }
        } else {
            # Unbounded TypeVar - not iterable
            self.emit(E1021, node_override=nd, type=collection_type.name);
        }
        # Skip check for UnknownType and any-like types (Any, object)
        # Following Pyright's pattern: these types are assumed to be iterable.
    } elif not isinstance(collection_type, types.UnknownType)
    and not self.evaluator.is_any_type(collection_type) {
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
                self.emit(E1022, node_override=nd, type=str(collection_type));
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
                self.emit(E1090, node_override=nd, type=str(cause_type));
            }
        }
    }
}

"""Bind alias types from context manager BEFORE visiting body."""
impl TypeCheckPass.enter_with_stmt(self: TypeCheckPass, nd: uni.WithStmt) -> None {
    import from jaclang.compiler.type_system { types }
    enter_method = "__aenter__" if nd.is_async else "__enter__";
    for item in nd.exprs {
        ctx_item: uni.ExprAsItem = item;
        expr_type = self.evaluator.get_type_of_expression(ctx_item.expr);
        if ctx_item.alias is None
        or not isinstance(ctx_item.alias, uni.Name)
        or isinstance(expr_type, types.UnknownType) {
            continue;
        }
        # `as x` binds the enter method's return, not the manager itself
        # (`async with` awaits __aenter__). Fall back to the manager when the
        # protocol can't be resolved.
        enter_ret = self.evaluator.get_type_of_magic_method_call(
            expr_type, enter_method, [], ctx_item.expr
        );
        if enter_ret is not None {
            if nd.is_async {
                enter_ret = self.evaluator._unwrap_awaitable_type(
                    enter_ret, ctx_item.expr
                );
            }
            ctx_item.alias.type = enter_ret;
        } else {
            ctx_item.alias.type = expr_type;
        }
    }
}

"""Type-check with statements: verify the (async) context manager protocol."""
impl TypeCheckPass.exit_with_stmt(self: TypeCheckPass, nd: uni.WithStmt) -> None {
    import from jaclang.compiler.type_system { types }
    enter_method = "__aenter__" if nd.is_async else "__enter__";
    exit_method = "__aexit__" if nd.is_async else "__exit__";
    for item in nd.exprs {
        ctx_item: uni.ExprAsItem = item;
        expr_type = self.evaluator.get_type_of_expression(ctx_item.expr);
        if not isinstance(expr_type, types.UnknownType) {
            enter_result = self.evaluator.get_type_of_magic_method_call(
                expr_type, enter_method, [], ctx_item.expr
            );
            if enter_result is None {
                self.emit(E1091, node_override=nd, type=str(expr_type));
            }
            # Direct member lookup, not a magic method call: __exit__/__aexit__
            # take 3 args (exc_type, exc_val, exc_tb) we don't have here, so a
            # call would fail arg-matching even when the method exists.
            if isinstance(expr_type, types.ClassType) {
                has_exit = (
                    self.evaluator._lookup_class_member(
                        expr_type, exit_method
                    ) is not None
                    or self.evaluator._lookup_object_member(
                        expr_type, exit_method
                    ) is not None
                );
                if not has_exit and not expr_type.is_any_type() {
                    self.emit(E1092, node_override=nd, type=str(expr_type));
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

"""Type-check `yield x` against the yield type of the enclosing function."""
impl TypeCheckPass.exit_yield_expr(self: TypeCheckPass, nd: uni.YieldExpr) -> None {
    import from jaclang.compiler.type_system { types, type_utils }
    if nd.expr is None {
        return;
    }
    yielded_type = self.evaluator.get_type_of_expression(nd.expr);
    scope = self.evaluator._get_enclosing_return_scope(nd);
    if scope is None {
        return;
    }

    return_type = self.evaluator._get_declared_return_type(scope);
    if return_type is None or isinstance(return_type, types.UnknownType) {
        return;
    }

    is_async = isinstance(scope, uni.Ability) and scope.is_async;
    yield_type = type_utils.get_generator_yield_type(return_type, is_async);
    expected_yield = (
        self.evaluator._convert_to_instance(yield_type)
            if yield_type is not None
            else return_type
    );

    if not nd.with_from {
        if not self.evaluator.assign_type(
            yielded_type, expected_yield, strict=self.evaluator._is_strict_site(nd)
        ) {
            self.emit(
                E1093,
                node_override=nd,
                actual=str(yielded_type),
                expected=str(expected_yield)
            );
        }
    }
}

"""Type-check delete statement target expression."""
impl TypeCheckPass.exit_delete_stmt(self: TypeCheckPass, nd: uni.DeleteStmt) -> None {
    self.evaluator.get_type_of_expression(nd.target);
}

"""Type-check visit statement target expression.

The runtime accepts (see `JacWalker.visit` in jac0core/runtime.jac):
    Node | Edge | ObjectSpatialPath
    | list/tuple/set/frozenset of (Node | Edge)

The validator recurses into collection element types and union members so
that the element type itself is constrained, not just the container kind.
Unparameterized containers and Any/Unknown pass — there's not enough
information to diagnose without false positives.
"""
impl TypeCheckPass.exit_visit_stmt(self: TypeCheckPass, nd: uni.VisitStmt) -> None {
    import from jaclang.compiler.type_system { types }
    target_type = self.evaluator.get_type_of_expression(nd.target);
    path_class = self.evaluator.prefetch.path_class;

    def is_valid_visit_target(t: types.TypeBase) -> bool {
        if t.is_any_type() or isinstance(t, types.UnknownType) {
            return True;
        }
        if isinstance(t, types.ClassType) {
            if t.is_node_type() or t.is_edge_type() {
                return True;
            }
            if path_class is not None and t.shared == path_class.shared {
                return True;
            }
            if (
                t.is_builtin()
                and t.shared.class_name in ("list", "tuple", "set", "frozenset")
            ) {
                if t.private.type_args and len(t.private.type_args) > 0 {
                    return all(is_valid_visit_target(a) for a in t.private.type_args);
                }
                # Unparameterized collection — accept (matches connect operand).
                return True;
            }
        }
        if isinstance(t, types.UnionType) {
            return all(is_valid_visit_target(m) for m in t.types);
        }
        return False;
    }

    if not is_valid_visit_target(target_type) {
        self.emit(E1094, node_override=nd, type=str(target_type));
    }
}

"""Type-check report statement expression against the enclosing walker's
declared `has reports: list[T]` element type.

If the walker doesn't declare a typed `reports` shape, fall back to the
inherited `list[Any]` and emit no diagnostic — `Any` already permits
anything. The check only fires when the walker has opted in by writing
`has reports: list[T]`.
"""
impl TypeCheckPass.exit_report_stmt(self: TypeCheckPass, nd: uni.ReportStmt) -> None {
    expr_type = self.evaluator.get_type_of_expression(nd.expr);
    elem_type = self._enclosing_walker_report_elem_type(nd);
    if elem_type is None {
        return;
    }
    if not self.evaluator.assign_type(expr_type, elem_type) {
        self.emit(
            E1113, node_override=nd, actual=str(expr_type), expected=str(elem_type)
        );
    }
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
            self.emit(
                E1095, node_override=nd, field=field_name, arch=arch.name_spec.sym_name
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
        # Evaluate the annotation so the tag Expr carries a resolved `.type`.
        # Symbol-type resolution only annotates the tag for the symbol kinds
        # whose path happens to evaluate it; doing it here covers every
        # annotation uniformly. Codegen backends (notably NaIRGenPass) lower
        # Expr.type directly instead of re-deriving structure from the
        # annotation AST. get_type_of_expression is memoized, so this is a
        # no-op when the tag was already evaluated.
        if nd.tag?.type is None {
            self.evaluator.get_type_of_expression(nd.tag);
        }
    }
}

"""Evaluate types for each Name leaf in a destructure pattern, recursing
into nested containers."""
impl TypeCheckPass._eval_unpacking_names(
    self: TypeCheckPass, container: uni.Expr
) -> None {
    if isinstance(container, (uni.TupleVal, uni.ListVal)) {
        for val in container.values {
            if isinstance(val, uni.Name) {
                self.evaluator.get_type_of_expression(val);
            } elif isinstance(val, (uni.TupleVal, uni.ListVal)) {
                self._eval_unpacking_names(val);
            }
        }
    }
}
