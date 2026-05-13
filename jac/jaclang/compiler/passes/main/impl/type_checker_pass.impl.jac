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
        if isinstance(nd.parent, uni.AtomTrailer) and nd.parent.right is nd {
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

"""Handle the function call node."""
impl TypeCheckPass.exit_func_call(self: TypeCheckPass, nd: uni.FuncCall) -> None {
    self.evaluator.get_type_of_expression(nd);

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
    self.evaluator.get_type_of_expression(nd);
}

"""Handle the atom trailer node."""
impl TypeCheckPass.exit_atom_trailer(self: TypeCheckPass, nd: uni.AtomTrailer) -> None {
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
        # declaration has no type annotation.  For such variables the
        # declared type is *inferred* from the first assignment, so
        # later reassignments should be allowed to widen the inferred
        # type — matching Pyright's behaviour for patterns like
        # `x = None; …; x = value` or `x = 0; …; x = "str"`.
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
            }
            # `target.type` is the hover cache — show the post-write type
            # for re-assignments, declared type otherwise. `left_type`
            # stays declared for the compat check and bare-generic warnings.
            if hover_type := self.evaluator._get_type_of_lhs_assignment(target) {
                target.type = self.evaluator._convert_to_instance(hover_type);
            } else {
                target.type = left_type;
            }
            # Warn on bare generic type annotations (e.g. x: list = [])
            if nd.type_tag and nd.type_tag.tag {
                self._check_bare_generic(nd.type_tag.tag, left_type);
            }
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
                    self.emit(E1020, node_override=nd, type=str(right_type));
                }
            }
            return;
        } else {
            # Handle typed assignment: target: Type = value
            # Propagate type annotation to the target node
            if nd.type_tag and nd.type_tag.tag {
                declared_type = self.evaluator.get_type_of_expression(nd.type_tag.tag);
                # Warn on bare generic type annotations (e.g. list instead of list[T])
                self._check_bare_generic(nd.type_tag.tag, declared_type);
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
        } elif (
            not is_unannotated_reassign
            and not self.evaluator.assign_type(
                right_type, left_type, strict=self.evaluator._is_strict_site(nd)
            )
        ) {
            self.emit(E1001, actual=str(right_type), expected=str(left_type));
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
    owner_kind = owner.arch_type.value;
    if owner_kind not in ("walker", "node", "edge") {
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

    # Tuple form `(A, B)` desugars to a union annotation in pyast_gen —
    # validate per element so each bad type gets its own diagnostic.
    targets: list[uni.Expr] = (
        list(sig.arch_tag_info.values)
            if (
                isinstance(sig.arch_tag_info, uni.TupleVal) and sig.arch_tag_info.values
            )
            else [sig.arch_tag_info]
    );
    err = E1116 if walker_owner else E1117;
    for arg in targets {
        ty = self.evaluator.get_type_of_expression(arg);
        if not is_valid(ty) {
            self.emit(err, node_override=arg, type=str(ty));
        }
    }
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
    self.evaluator._pass = self;
    self._insert_builtin_symbols();
    self.evaluator._narrowing_cache = {};
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
        # Warn on bare generic type annotations (e.g. has items: list instead of list[T])
        if nd.type_tag and nd.type_tag.tag {
            self._check_bare_generic(nd.type_tag.tag, declared_type);
        }
        # Walker-specific: `has reports` is the typed view of the walker's
        # report channel. Require a list shape so `report X` (write side)
        # and `(spawn W).reports` (read side) share a single element type.
        self._check_walker_reports_shape(nd, declared_type);
        # If there's an initializer, check that its type is compatible
        # with the declared type (e.g., bad1: int = unknown_val;).
        if nd.value is not None and nd.type is not None {
            right_type = self.evaluator.get_type_of_expression(nd.value);
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
    if arch.arch_type.value != "walker" {
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
    if not isinstance(arch, uni.Archetype) or arch.arch_type.value != "walker" {
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
                self.emit(E1091, node_override=nd, type=str(expr_type));
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
