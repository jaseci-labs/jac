impl TypeCheckPass.exit_special_var_ref(
    self: TypeCheckPass, nd: SpecialVarRef
) -> None {
    self.evaluator.get_type_of_expression(nd);
}

impl TypeCheckPass.exit_name(self: TypeCheckPass, nd: Name) -> None {
    if self.evaluator._is_non_expression_name(nd) {
        return;
    }
    is_bare_field = (
        nd.sym is not None
        and nd.sym.sym_type == SymbolType.HAS_VAR
        and isinstance(nd.sym.parent_tab, Archetype)
        and nd.expr_ctx == ExprCtx.LOAD
    );
    if nd.sym is None or is_bare_field {
        self.evaluator.get_type_of_expression(nd);
    }
}

impl TypeCheckPass.exit_edge_ref_trailer(
    self: TypeCheckPass, nd: EdgeRefTrailer
) -> None {
    for chain in nd.chain {
        if isinstance(chain, FilterCompr) {
            self.evaluator.get_type_of_expression(chain);
        }
    }
}

impl TypeCheckPass.exit_formatted_value(
    self: TypeCheckPass, nd: FormattedValue
) -> None {
    self.evaluator.get_type_of_expression(nd.format_part);
}

impl TypeCheckPass.exit_return_stmt(self: TypeCheckPass, nd: ReturnStmt) -> None {
    scope = self.evaluator._get_enclosing_return_scope(nd);
    if scope is None {
        return;
    }

    if isinstance(scope, Ability) {
        if (
            isinstance(scope.signature, EventSignature)
            and nd.expr
            and not isinstance(nd.expr, Null)
        ) {
            self.emit(W2014, node_override=nd);
            return;
        }

        if (
            nd.expr
            and not isinstance(nd.expr, Null)
            and isinstance(scope.parent, (Module, Archetype, Enum, ImplDef))
        ) {
            has_annotation = (
                isinstance(scope.signature, FuncSignature)
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

    if isinstance(scope, Ability) and scope.get_all_sub_nodes(YieldExpr) {
        gen_return = get_declared_generator_return_type(return_type);
        if gen_return is not None {
            return_type = self.evaluator._convert_to_instance(gen_return);
        } elif is_generator_family_type(return_type) {
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

impl TypeCheckPass.exit_filter_compr(self: TypeCheckPass, nd: FilterCompr) -> None {
    self.evaluator.get_type_of_expression(nd);
}

impl TypeCheckPass.enter_lambda_expr(self: TypeCheckPass, nd: LambdaExpr) -> None {
    if (isinstance(nd.body, Expr) or nd.tail_return_expr() is not None) {
        self._lambda_depth += 1;
    }
}

impl TypeCheckPass.exit_lambda_expr(self: TypeCheckPass, nd: LambdaExpr) -> None {
    if (isinstance(nd.body, Expr) or nd.tail_return_expr() is not None) {
        self._lambda_depth -= 1;
    }
}

def _chunks_receiver_type(nd: FuncCall) -> (str | None) {
    if not (
        isinstance(nd.target, AtomTrailer)
        and nd.target.is_attr
        and isinstance(nd.target.right, Name)
        and nd.target.right.sym_name == "chunks"
        and nd.params is not None
        and len(nd.params) == 1
    ) {
        return None;
    }
    try {
        recv = nd.target.target.type;
        if recv is None {
            return None;
        }
        return recv.mangle();
    } except Exception {
        return None;
    }
}

impl TypeCheckPass.exit_func_call(self: TypeCheckPass, nd: FuncCall) -> None {
    import from jaclang.compiler.symbol_utils {
        CallKind,
        classify_call,
        ability_of_symbol,
        resolve_expr_symbol
    }

    if self._lambda_depth > 0 {
        nd.call_kind = classify_call(nd).value;
        nd.chunks_recv_type = _chunks_receiver_type(nd);
        nd.callee_decl = ability_of_symbol(resolve_expr_symbol(nd.target));
        return;
    }
    self.evaluator.get_type_of_expression(nd);

    nd.call_kind = classify_call(nd).value;

    nd.chunks_recv_type = _chunks_receiver_type(nd);

    nd.callee_decl = ability_of_symbol(resolve_expr_symbol(nd.target));

    if nd.call_kind == CallKind.INTRINSIC.value {
        self._check_intrinsic_call(nd);
    }

    if isinstance(nd.target, AtomTrailer) and not nd.target.is_attr {
        if isinstance(nd.target.right, IndexSlice) {
            idx_slice: IndexSlice = nd.target.right;
            for slice in idx_slice.slices {
                slice_item: Slice = slice;
                if slice_item.start {
                    self.evaluator.validate_typevar_in_type_expr(slice_item.start);
                }
            }
        }
    }
}

impl TypeCheckPass._check_intrinsic_call(self: TypeCheckPass, nd: FuncCall) -> None {
    import from jaclang.compiler.symbol_utils { intrinsic_registry_if_ready }

    intrinsics = intrinsic_registry_if_ready();
    name = nd.target.sym_name if isinstance(nd.target, Name) else None;
    intr = intrinsics.get(name)
        if intrinsics is not None and name is not None
        else None;
    if intr is None {
        return;
    }
    positional: list = [];
    has_kw = False;
    for p in (nd.params or []) {
        if isinstance(p, KWPair) {
            has_kw = True;
        } else {
            positional.append(p);
        }
    }
    if has_kw {
        self.emit(
            E5095,
            node_override=nd,
            name=intr.name,
            reason="keyword arguments are not accepted"
        );
    } elif len(positional) != intr.arity() {
        self.emit(
            E5095,
            node_override=nd,
            name=intr.name,
            reason=f"expected {intr.arity()} argument(s), got {len(positional)}"
        );
    }
    if intr.result_spec in ("i64", "f64") {
        if self.evaluator.na_builtins_module is not None {
            result_cls = self.evaluator._get_type_from_module(
                self.evaluator.na_builtins_module, intr.result_spec
            );
            if not isinstance(result_cls, UnknownType) {
                nd.type = self.evaluator._convert_to_instance(result_cls);
            }
        }
    } else {
        nd.type = self.evaluator._convert_to_instance(self.evaluator.get_none_type());
    }
}

impl TypeCheckPass._check_intrinsic_collision(
    self: TypeCheckPass, nd: Ability
) -> None {
    import from jaclang.compiler.symbol_utils { intrinsic_registry_if_ready }

    intrinsics = intrinsic_registry_if_ready();
    if intrinsics is None {
        return;
    }
    name = nd.name_ref.sym_name if nd.name_ref is not None else None;
    if name is None or not intrinsics.is_intrinsic(name) {
        return;
    }
    if str(nd.loc.mod_path).endswith(".pyi") {
        return;
    }
    for w in self.prog.warnings_had {
        if (
            w.code is W6008
            and w.loc.mod_path == nd.loc.mod_path
            and w.loc.first_line == nd.loc.first_line
        ) {
            return;
        }
    }
    self.emit(W6008, node_override=nd, name=name);
}

impl TypeCheckPass.exit_jsx_element(self: TypeCheckPass, nd: JsxElement) -> None {
    self.evaluator.get_type_of_expression(nd);
}

impl TypeCheckPass.exit_compare_expr(self: TypeCheckPass, nd: CompareExpr) -> None {
    if self._lambda_depth > 0 {
        return;
    }
    _cmp_mod = nd.find_parent_of_type(Module);
    if _cmp_mod is None or _cmp_mod.is_raised_from_py {
        return;
    }
    _ord_ops = (Tok.LT, Tok.LTE, Tok.GT, Tok.GTE);
    _mem_ops = (Tok.KW_IN, Tok.KW_NIN);
    operands: list = [nd.left];
    operands.extend(nd.rights);
    for (i, op) in enumerate(nd.ops) {
        _opname = op.name if isinstance(op, Token) else str(op);
        if _opname in _mem_ops {
            _optext = op.value if isinstance(op, Token) else str(op);
            self._diag_erased_membership(nd, operands[i + 1], _optext);
            continue;
        }
        if _opname not in _ord_ops {
            continue;
        }
        for side in (operands[i], operands[i + 1]) {
            _side_t = self.evaluator.get_type_of_expression(side);
            self.evaluator._diag_unnarrowed_optional(nd, _side_t, "an ordered operand");
        }
    }
}

impl TypeCheckPass._diag_erased_membership(
    self: TypeCheckPass, nd: CompareExpr, hay: Expr, op_text: str
) -> None {
    if not self.evaluator._in_native_context()
        or not self.evaluator._is_strict_site(nd) {
        return;
    }
    hay_t = self.evaluator.get_type_of_expression(hay);

    if hay_t is None
        or isinstance(hay_t, UnknownType)
        or hay_t.is_any_type()
        or hay_t.is_any_instance() {
        self.emit(
            E1124,
            node_override=hay,
            op=op_text,
            type=str(hay_t) if hay_t is not None else "<unknown>"
        );
    }
}

impl TypeCheckPass.exit_binary_expr(self: TypeCheckPass, nd: BinaryExpr) -> None {
    if self._lambda_depth > 0 {
        return;
    }
    self.evaluator.get_type_of_expression(nd);
}

impl TypeCheckPass.exit_atom_trailer(self: TypeCheckPass, nd: AtomTrailer) -> None {
    if self._lambda_depth > 0 {
        return;
    }
    self.evaluator.get_type_of_expression(nd);
    _at_mod = nd.find_parent_of_type(Module);
    if (
        not nd.is_attr
        and _at_mod is not None
        and not _at_mod.is_raised_from_py
        and isinstance(nd.right, IndexSlice)
        and not nd.right.is_range
        and nd.right.slices
        and nd.right.slices[0].start is not None
    ) {
        _idx_expr = nd.right.slices[0].start;
        _idx_t = self.evaluator.get_type_of_expression(_idx_expr);
        if isinstance(_idx_t, UnionType) {
            _base_t = self.evaluator.get_type_of_expression(nd.target);
            if isinstance(_base_t, ClassType)
                and _base_t.is_class_instance()
                and not _base_t.is_any_type()
                and self.evaluator.get_type_of_magic_method_call(
                    _base_t, "__getitem__", [_idx_expr], None
                )
                    is None {
                self.evaluator._diag_unnarrowed_optional(
                    nd, _idx_t, "a subscript index"
                );
            }
        }
    }
}

impl TypeCheckPass.exit_assignment(self: TypeCheckPass, nd: Assignment) -> None {
    if nd.is_enum_stmt {
        return;
    }
    if ((len(nd.target) == 1) and (nd.value is not None)) {
        target = nd.target[0];

        is_unannotated_reassign = False;

        if isinstance(target, Name) and target.sym {
            left_type = self.evaluator.get_type_of_symbol(target.sym);

            if (
                target.sym.decl.name_of is not target
                and isinstance(target.sym.decl.name_of.parent, Assignment)
                and target.sym.decl.name_of.parent.type_tag is None
            ) {
                is_unannotated_reassign = True;

                left_type = self.evaluator._widen_literal_for_declaration(left_type);
            }

            if isinstance(left_type, UnknownType) and left_type.is_incomplete {
                return;
            }

            if hover_type := self.evaluator._get_type_of_lhs_assignment(target) {
                target.type = self.evaluator._convert_to_instance(hover_type);
            } else {
                target.type = left_type;
            }

            if nd.type_tag and nd.type_tag.tag {
                self._check_bare_generic(nd.type_tag.tag, left_type);
                self._check_explicit_any(nd.type_tag.tag);
            }
        } elif isinstance(target, (TupleVal, ListVal)) {
            self._eval_unpacking_names(target);
            right_type = self.evaluator.get_type_of_expression(nd.value);
            if not isinstance(right_type, UnknownType)
                and not right_type.is_any_instance() {
                iter_result = self.evaluator.get_type_of_magic_method_call(
                    right_type, "__iter__", [], nd.value
                );
                if iter_result is None {
                    self.emit(E1020, node_override=nd, type=str(right_type));
                }
            }
            return;
        } else {
            if nd.type_tag and nd.type_tag.tag {
                declared_type = self.evaluator.get_type_of_expression(nd.type_tag.tag);

                self._check_bare_generic(nd.type_tag.tag, declared_type);
                self._check_explicit_any(nd.type_tag.tag);

                declared_inst = self.evaluator._convert_to_instance(declared_type);
                target.type = declared_inst;

                if isinstance(target, AtomTrailer) {
                    chain = target.as_attr_list;
                    if len(chain) >= 2 {
                        chain[-1].type = declared_inst;
                    }
                }
                left_type = declared_inst;
            } else {
                left_type = self.evaluator.get_type_of_expression(target);
                if isinstance(target, Name) and target.sym is not None {
                    sym_declared = self.evaluator.get_type_of_symbol(target.sym);
                    if (
                        sym_declared is not None
                        and not isinstance(sym_declared, (UnknownType, AnyType))
                    ) {
                        left_type = sym_declared;
                    }
                }
                if isinstance(target, AtomTrailer) and target.is_attr {
                    if isinstance(target.right, Name) and target.right.sym {
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
                            declared = self.evaluator.get_type_of_symbol(target_sym);
                            if declared {
                                left_type = declared;
                            }
                        }
                    }
                }
            }
        }

        right_type = self.evaluator.get_type_of_expression(
            nd.value, expected_type=left_type
        );

        if isinstance(right_type, TypeVarType) and isinstance(nd.value, FuncCall) {
            caller_type = self.evaluator.get_type_of_expression(nd.value.target);
            is_typevar_call = self.evaluator.is_typevar_class(caller_type);
            if is_typevar_call {
                if not isinstance(target, Name) {
                    self.emit(E1060, node_override=target, name=right_type.name);
                } else {
                    name_target: Name = target;
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

        if nd.aug_op and isinstance(left_type, TypeVarType) {
            op_name = AUG_OPERATOR_MAP.get(nd.aug_op.name);

            if left_type.constraints {
                for constraint_type in left_type.constraints {
                    if isinstance(constraint_type, ClassType) {
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
            } elif left_type.bound and isinstance(left_type.bound, ClassType) {
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
                self.emit(
                    E1010, node_override=nd, op=nd.aug_op.name, type=left_type.name
                );
            }
        } else {
            is_evolving_reassign = is_unannotated_reassign
                and (
                    self.evaluator.is_none_type(left_type)
                    or (isinstance(target, Name) and target.value == "_")
                );
            if (
                nd.aug_op is None
                and not is_evolving_reassign
                and not self.evaluator.assign_type(
                    right_type, left_type, strict=self.evaluator._is_strict_site(nd)
                )
                and not self.evaluator.slice_assignment_is_valid(target, nd.value)
            ) {
                if self.evaluator._is_awaitable_type(right_type) {
                    self.emit(E1042, actual=str(right_type), expected=str(left_type));
                } else {
                    self.emit(E1001, actual=str(right_type), expected=str(left_type));
                }
            }
        }

        if nd.aug_op is not None {
            if (
                not isinstance(left_type, UnknownType)
                and not isinstance(right_type, UnknownType)
            ) {
                aug_magic = AUG_OPERATOR_MAP.get(nd.aug_op.name);
                if aug_magic is not None {
                    result = self.evaluator.get_type_of_magic_method_call(
                        left_type, aug_magic, [nd.value], nd.value
                    );
                    if result is None {
                        base_op = AUG_TO_BINARY_MAP.get(nd.aug_op.name);
                        if base_op is not None {
                            if base_op in ARITHMETIC_OPERATORS {
                                if nd.aug_op is not None and nd.aug_op.value == "**=" {
                                    promoted = get_pow_result_type(
                                        self.evaluator, left_type, right_type, nd.value
                                    );
                                } else {
                                    promoted = get_numeric_promotion_type(
                                        self.evaluator, left_type, right_type, base_op
                                    );
                                }
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
                    if result is not None
                        and not self.evaluator.assign_type(result, left_type) {
                        self.emit(E1001, actual=str(result), expected=str(left_type));
                    }
                }
            }
        }
    } else {
        for target in nd.target {
            if isinstance(target, Name) and target.sym {
                target_type = self.evaluator.get_type_of_symbol(target.sym);
                if not (
                    isinstance(target_type, UnknownType) and target_type.is_incomplete
                ) {
                    target.type = target_type;
                }
            } elif isinstance(target, (TupleVal, ListVal)) {
                self._eval_unpacking_names(target);
            } else {
                self.evaluator.get_type_of_expression(target);
            }
        }
    }
}

impl TypeCheckPass.exit_import(self: TypeCheckPass, nd: Import) -> None {
    if nd.clib_decls {
        return;
    }
    if nd.from_loc {
        self.evaluator.get_type_of_module(nd.from_loc);
        for item in nd.items {
            if isinstance(item, ModuleItem) {
                self.evaluator.get_type_of_module_item(item);
            }
        }
    } else {
        for item in nd.items {
            if isinstance(item, ModulePath) {
                self.evaluator.get_type_of_module(item);
            }
        }
    }
}

impl TypeCheckPass.enter_ability(self: TypeCheckPass, nd: Ability) -> None {
    for decor in (nd.decorators or []) {
        ty = self.evaluator.get_type_of_expression(decor);
        if (isinstance(ty, ClassType) and ty.is_builtin('staticmethod')) {
            nd.is_static = True;
            break;
        }
    }
}

impl TypeCheckPass.exit_ability(self: TypeCheckPass, nd: Ability) -> None {
    self.evaluator.validate_typevar_variance(nd);

    self._check_intrinsic_collision(nd);

    if (
        isinstance(nd.signature, FuncSignature)
        and not nd.is_static
        and not nd.is_classmethod
    ) {
        owner = nd.method_owner;
        if (
            isinstance(owner, Archetype)
            and owner.arch_type.value in ("obj", "node", "edge", "walker")
        ) {
            all_params = nd.signature.get_parameters();
            if (
                len(all_params) > 0
                and isinstance(all_params[0].name, Name)
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

    if (
        isinstance(nd.body, ImplDef)
        and nd.body.find_parent_of_type(Module) is not self.ir_in
    ) {
        self.traverse(nd.body);
    }

    if (
        isinstance(nd.signature, FuncSignature)
        and nd.signature.return_type is not None
        and nd.find_parent_of_type(ImplDef) is None
    ) {
        ret_ann_type = self.evaluator.get_type_of_expression(nd.signature.return_type);
        self._check_bare_generic(nd.signature.return_type, ret_ann_type);
        self._check_explicit_any(nd.signature.return_type);
    }

    if (
        isinstance(nd.signature, FuncSignature)
        and nd.signature.return_type is not None
        and not isinstance(nd.body, ImplDef)
        and isinstance(nd.body, list)
        and len(nd.body) > 0
        and not nd.is_abstract
    ) {
        is_overload = False;
        for decor in (nd.decorators or []) {
            if isinstance(decor, Name) and decor.value == "overload" {
                is_overload = True;
                break;
            }
        }

        is_generator = len(nd.get_all_sub_nodes(YieldExpr)) > 0;

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

    if (
        isinstance(nd.signature, EventSignature)
        and nd.signature.arch_tag_info is not None
    ) {
        self._check_event_trigger_archetype(nd);
    }

    if (
        isinstance(nd.signature, FuncSignature)
        and nd.signature.return_type is not None
        and nd.find_parent_of_type(ImplDef) is None
    ) {
        comp_params = [
            p
            for p in nd.signature.get_parameters()
            if isinstance(p.name, Name) and p.name.value not in ("self", "cls")
        ];
        if (
            len(comp_params) == 1
            and isinstance(comp_params[0].name, Name)
            and comp_params[0].name.value == "props"
        ) {
            props_param = comp_params[0];
            any_cls = self.evaluator.prefetch.any_class
                if self.evaluator.prefetch
                else None;

            is_untyped_bag = (
                props_param.type_tag is None
                or isinstance(props_param.type, AnyType)
                or (
                    any_cls is not None
                    and isinstance(props_param.type, ClassType)
                    and props_param.type.shared == any_cls.shared
                )
            );
            jsx_cls = self.evaluator.prefetch.jsx_element_class
                if self.evaluator.prefetch
                else None;
            ret_type = self.evaluator.get_type_of_expression(nd.signature.return_type);
            is_jsx_component = (
                jsx_cls is not None
                and isinstance(ret_type, ClassType)
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

impl TypeCheckPass._check_event_trigger_archetype(
    self: TypeCheckPass, nd: Ability
) -> None {
    sig = nd.signature;
    if not isinstance(sig, EventSignature) or sig.arch_tag_info is None {
        return;
    }
    owner = nd.method_owner;
    if not isinstance(owner, Archetype) {
        return;
    }
    owner_kind = owner.arch_kind;
    if owner_kind is None {
        return;
    }
    walker_owner = owner_kind == "walker";

    def is_valid(t: TypeBase) -> bool {
        if t.is_any_type() or isinstance(t, UnknownType) {
            return True;
        }
        if isinstance(t, UnionType) {
            return all(is_valid(m) for m in t.types);
        }
        if isinstance(t, ClassType) {
            if walker_owner {
                return t.is_node_type() or t.is_edge_type();
            }
            return t.is_walker_type();
        }
        return False;
    }

    def collect_union_leaves(expr: Expr) -> list[Expr] {
        if (
            isinstance(expr, BinaryExpr)
            and isinstance(expr.op, Token)
            and expr.op.name == Tok.BW_OR
        ) {
            return collect_union_leaves(expr.left) + collect_union_leaves(expr.right);
        }
        return [expr];
    }

    targets: list[Expr] = (
        list(sig.arch_tag_info.values)
            if (isinstance(sig.arch_tag_info, TupleVal) and sig.arch_tag_info.values)
            else collect_union_leaves(sig.arch_tag_info)
    );
    err = E1116 if walker_owner else E1117;
    resolved: list[TypeBase] = [];
    for arg in targets {
        ty = self.evaluator.get_type_of_expression(arg);
        resolved.append(ty);

        if isinstance(arg, Name) and arg.value == "root" {
            self.emit(err, node_override=arg, type="root");
            continue;
        }
        if isinstance(ty, ClassType) and ty.is_instance() {
            label = arg.value if isinstance(arg, Name) else str(ty);
            self.emit(err, node_override=arg, type=label);
            continue;
        }
        if not is_valid(ty) {
            self.emit(err, node_override=arg, type=str(ty));
        }
    }

    nd.event_triggers = resolved;
}

impl TypeCheckPass._body_always_returns(
    self: TypeCheckPass, body: list[CodeBlockStmt]
) -> bool {
    return self.evaluator._collect_return_types(body, []);
}

impl TypeCheckPass._check_bare_generic(
    self: TypeCheckPass, ann_node: UniNode, ty: object
) -> None {
    if isinstance(ty, UnionType) and ty.types {
        for branch in ty.types {
            self._check_bare_generic(ann_node, branch);
        }
        return;
    }
    if (
        isinstance(ty, ClassType)
        and ty.shared
        and ty.shared.type_params
        and (not ty.private or not ty.private.type_args)
    ) {
        self.emit(W1036, node_override=ann_node, type=ty.shared.class_name);
    }
}

impl TypeCheckPass._check_unresolved_lambda_params(self: TypeCheckPass) -> None {
    if self.ir_in is None {
        return;
    }
    for lam in self.ir_in.get_all_sub_nodes(LambdaExpr) {
        if lam.signature is None {
            continue;
        }
        for param in lam.signature.get_parameters() {
            if param.type_tag is not None {
                continue;
            }

            resolved = param.name.type;
            if resolved is None or isinstance(resolved, UnknownType) {
                self.emit(E1119, node_override=param.name, name=param.name.value);
            }
        }
    }
}

impl TypeCheckPass._check_explicit_any(self: TypeCheckPass, ann_node: UniNode) -> None {
    if isinstance(ann_node, BuiltinType) and ann_node.value == "any" {
        self.emit(W1037, node_override=ann_node);
    }
    for sub in ann_node.get_all_sub_nodes(BuiltinType) {
        if sub.value == "any" {
            self.emit(W1037, node_override=sub);
        }
    }

    names = ann_node.get_all_sub_nodes(Name);
    if isinstance(ann_node, Name) {
        names = [ann_node] + names;
    }
    for nm in names {
        if nm.sym_name != "Any" {
            continue;
        }

        resolve_target: Expr = nm;
        parent = nm.parent;
        if (
            isinstance(parent, AtomTrailer) and parent.is_attr and (parent.right is nm)
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

impl TypeCheckPass.exit_type_alias(self: TypeCheckPass, nd: TypeAlias) -> None {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if not nd.is_distinct {
        return;
    }
    resolved = self.evaluator._resolve_type_alias_rhs(nd.value);
    if not isinstance(resolved, ClassType)
        or not JAC_TYPE_REGISTRY.is_primitive(resolved.shared.class_name) {
        self.emit(E1107, node_override=nd.value, base=str(resolved));
    }
}

impl TypeCheckPass.exit_archetype(self: TypeCheckPass, nd: Archetype) -> None {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    cls_type = self.evaluator.get_type_of_class(nd);
    if isinstance(cls_type, ClassType)
        and nd.arch_type.name == Tok.KW_OBJECT
        and not cls_type.shared.is_from_stdlib_stub
        and cls_type.shared.base_classes {
        for base in cls_type.shared.base_classes {
            if isinstance(base, ClassType)
                and base.is_builtin()
                and JAC_TYPE_REGISTRY.is_primitive(base.shared.class_name) {
                self.emit(
                    E1106,
                    node_override=nd.name,
                    name=nd.name.value,
                    base=base.shared.class_name
                );
            }
        }
    }
    if (
        isinstance(nd.body, ImplDef)
        and nd.body.find_parent_of_type(Module) is not self.ir_in
    ) {
        self.traverse(nd.body);
    }
}

impl TypeCheckPass.exit_enum(self: TypeCheckPass, nd: Enum) -> None {
    cls_type = self.evaluator.get_type_of_enum(nd);

    for child in nd.kid {
        if isinstance(child, Assignment) {
            for target in child.target {
                self.evaluator.get_type_of_expression(target);
            }
        }
    }
    if (
        isinstance(nd.body, ImplDef)
        and nd.body.find_parent_of_type(Module) is not self.ir_in
    ) {
        self.traverse(nd.body);
    }
}

impl TypeCheckPass._insert_builtin_symbols(self: TypeCheckPass) -> None {
    if (self.ir_in == self.evaluator.builtins_module) {
        return;
    }
    if (self.ir_in.parent_scope is not None) {
        return;
    }
    self.ir_in.parent_scope = self.evaluator.builtins_module;
}

impl TypeCheckPass._client_state_field_owner(
    self: TypeCheckPass, nd: HasVar
) -> (Ability | None) {
    if not isinstance(nd.parent, ArchHas) {
        return None;
    }
    owner: (UniNode | None) = nd.parent;
    while (owner is not None and not isinstance(owner, (Ability, Archetype))) {
        owner = owner.parent;
    }
    if not isinstance(owner, Ability) {
        return None;
    }
    if not nd.in_client_context() {
        return None;
    }
    for probe in (nd.value, nd.type_tag.tag if nd.type_tag else None) {
        cur: (UniNode | None) = probe;
        while isinstance(cur, (FuncCall, AtomTrailer)) {
            cur = cur.target;
        }
        if isinstance(cur, Name) and cur.value == 'Ref' {
            return None;
        }
    }
    return owner;
}

impl TypeCheckPass._install_client_state_setters(self: TypeCheckPass) -> None {
    import from jaclang.compiler.passes.ecmascript.framework_backend {
        state_setter_name
    }
    import from jaclang.compiler.type_system.types { create_callable_type }
    mod = self.ir_in;
    if mod is None {
        return;
    }

    prev_emit = getattr(self, '_emit_diagnostics', True);
    self._emit_diagnostics = False;
    try {
        none_type = self.evaluator._convert_to_instance(self.evaluator.get_none_type());
        for nd in mod.get_all_sub_nodes(typ=HasVar) {
            owner = self._client_state_field_owner(nd);
            if owner is None {
                continue;
            }
            setter_name = state_setter_name(nd.name.value);
            if not setter_name {
                continue;
            }
            scope = nd.sym_tab;
            if (scope is None) or (scope.names_in_scope.get(setter_name) is not None) {
                continue;
            }
            sym = nd.sym;
            if sym is None {
                continue;
            }
            stub = Name.gen_stub_from_node(nd.name, setter_name);
            stub.type = create_callable_type(
                [self.evaluator.get_type_of_symbol(sym)], none_type
            );
            scope.def_insert(stub);
        }
    } finally {
        self._emit_diagnostics = prev_emit;
    }
}

impl TypeCheckPass.before_pass(self: TypeCheckPass) -> None {
    self.evaluator = self.prog.get_type_evaluator();

    self._prev_eval_pass = self.evaluator._pass;
    self.evaluator._pass = self;
    self._insert_builtin_symbols();
    self.evaluator._narrowing_cache = {};

    _opts = self.prog?._compile_options;
    _tc_requested = bool(_opts?.type_check);
    _emit_intent = (_opts is None) or bool(_opts.emit_diagnostics);

    emit_full = (not self.inference_only) or _tc_requested;
    if not emit_full {
        mod = self.ir_in;
        emit_full = mod is not None and mod.decided_codespace == 'native';
    }

    if self.inference_only and not _emit_intent {
        emit_full = False;
    }
    self._emit_diagnostics = emit_full;

    if emit_full and self.ir_in?._deferred_type_diags {
        stack = [self.ir_in];
        while stack {
            cur = stack.pop();
            if isinstance(cur, Expr) {
                cur.type = None;
            }
            stack.extend(cur.kid);
        }

        self.evaluator._flow_node_type_cache.clear();
        self.evaluator._flow_key_type_cache.clear();
        self.evaluator._and_narrowing_overrides.clear();
    }
    self._install_client_state_setters();
}

impl TypeCheckPass.after_pass(self: TypeCheckPass) -> None {
    if getattr(self, '_emit_diagnostics', True) {
        self._check_unresolved_lambda_params();

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

    if self._prev_eval_pass is not None and self.evaluator._pass is self {
        self.evaluator._pass = self._prev_eval_pass;
    }
}

impl TypeCheckPass.emit(
    self: TypeCheckPass,
    diag: DiagnosticInfo,
    node_override: (UniNode | None) = None,
    related: (list[tuple[str, UniNode]] | None) = None,
    help_text: (str | None) = None,
    **kwargs: any
) -> bool {
    if diag.category != Category.ICE {
        stash = self.ir_in?._deferred_type_diags;
        key = (
            diag.code,
            id(node_override) if node_override is not None else 0,
            str(kwargs)
        );
        if not getattr(self, '_emit_diagnostics', True) {
            if stash is None {
                stash = {};
                self.ir_in._deferred_type_diags = stash;
            }
            if key not in stash {
                stash[key] = (diag, node_override, related, help_text, kwargs);
            }
            return False;
        }

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


impl TypeCheckPass.exit_param_var(self: TypeCheckPass, nd: ParamVar) -> None {
    if (sym := nd.sym) {
        declared_type = self.evaluator.get_type_of_symbol(sym);
        nd.type = declared_type;

        if (
            nd.type_tag and nd.type_tag.tag and nd.find_parent_of_type(ImplDef) is None
        ) {
            self._check_bare_generic(nd.type_tag.tag, declared_type);
            self._check_explicit_any(nd.type_tag.tag);
        }
    }
}

impl TypeCheckPass.exit_has_var(self: TypeCheckPass, nd: HasVar) -> None {
    if (nd.defer and nd.kid and isinstance(nd.kid[-1], Name)) {
        postinit_nd: Name = nd.kid[-1];
        if postinit_nd.sym is None {
            arch = nd.parent.parent if isinstance(nd.parent, ArchHas) else None;
            if isinstance(arch, Archetype) {
                postinit_sym = arch.names_in_scope.get("__post_init__");
                if postinit_sym is not None {
                    postinit_nd._sym = postinit_sym;
                }
            } elif isinstance(arch, ImplDef)
                and isinstance(arch.decl_link, Archetype) {
                if (postinit_sym := arch.decl_link.names_in_scope.get("__post_init__"))
                    is not None {
                    postinit_nd._sym = postinit_sym;
                }
            }
        }
    }
    if (sym := nd.sym) {
        declared_type = self.evaluator.get_type_of_symbol(sym);
        nd.type = declared_type;

        if nd.type_tag and nd.type_tag.tag {
            self._check_bare_generic(nd.type_tag.tag, declared_type);
            self._check_explicit_any(nd.type_tag.tag);
        }

        self._check_walker_reports_shape(nd, declared_type);

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

impl TypeCheckPass._check_walker_reports_shape(
    self: TypeCheckPass, nd: HasVar, declared_type: object
) -> None {
    if nd.name.value != "reports" {
        return;
    }
    arch = nd.parent.parent if isinstance(nd.parent, ArchHas) else None;
    if isinstance(arch, ImplDef) and isinstance(arch.decl_link, Archetype) {
        arch = arch.decl_link;
    }
    if not isinstance(arch, Archetype) {
        return;
    }
    if arch.arch_kind != "walker" {
        return;
    }

    if isinstance(declared_type, UnknownType) {
        return;
    }
    if isinstance(declared_type, ClassType) {
        if declared_type.is_any_type() or declared_type.is_builtin("list") {
            return;
        }
    }
    self.emit(E1112, node_override=nd, type=str(declared_type));
}

impl TypeCheckPass._enclosing_walker_report_elem_type(
    self: TypeCheckPass, nd: UniNode
) -> object {
    arch = nd.find_parent_of_type(Archetype);
    if arch is None {
        impl_def = nd.find_parent_of_type(ImplDef);
        if impl_def is not None and isinstance(impl_def.decl_link, Archetype) {
            arch = impl_def.decl_link;
        }
    }
    if not isinstance(arch, Archetype) or arch.arch_kind != "walker" {
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
            isinstance(declared, ClassType)
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

impl TypeCheckPass.exit_in_for_stmt(self: TypeCheckPass, nd: InForStmt) -> None {
    if isinstance(nd.target, Name) {
        self.evaluator.get_type_of_expression(nd.target);
    } elif isinstance(nd.target, (TupleVal, ListVal)) {
        self._eval_unpacking_names(nd.target);
    }

    collection_type = self.evaluator.get_type_of_expression(nd.collection);

    if isinstance(collection_type, TypeVarType) {
        if collection_type.constraints {
            for constraint_type in collection_type.constraints {
                if isinstance(constraint_type, ClassType) {
                    iter_result = self.evaluator.get_type_of_magic_method_call(
                        constraint_type, "__iter__", [], None
                    );
                    if iter_result is None {
                        self.emit(E1021, node_override=nd, type=str(constraint_type));
                    }
                }
            }
        } elif collection_type.bound and isinstance(collection_type.bound, ClassType) {
            iter_result = self.evaluator.get_type_of_magic_method_call(
                collection_type.bound, "__iter__", [], nd.collection
            );
            if iter_result is None {
                self.emit(E1021, node_override=nd, type=str(collection_type.bound));
            }
        } else {
            self.emit(E1021, node_override=nd, type=collection_type.name);
        }
    } elif not isinstance(collection_type, UnknownType)
        and not self.evaluator.is_any_type(collection_type) {
        is_enum = (
            isinstance(collection_type, ClassType) and collection_type.is_enum_class()
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

impl TypeCheckPass.exit_raise_stmt(self: TypeCheckPass, nd: RaiseStmt) -> None {
    if nd.cause {
        cause_type = self.evaluator.get_type_of_expression(nd.cause);
        if isinstance(cause_type, ClassType)
            and not isinstance(cause_type, UnknownType) {
            is_exception = False;
            for cls in cause_type.shared.mro {
                if isinstance(cls, ClassType)
                    and (
                        cls.is_builtin("BaseException") or cls.is_builtin("Exception")
                    ) {
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

impl TypeCheckPass.enter_with_stmt(self: TypeCheckPass, nd: WithStmt) -> None {
    enter_method = "__aenter__" if nd.is_async else "__enter__";
    for item in nd.exprs {
        ctx_item: ExprAsItem = item;
        expr_type = self.evaluator.get_type_of_expression(ctx_item.expr);
        if ctx_item.alias is None
            or not isinstance(ctx_item.alias, Name)
            or isinstance(expr_type, UnknownType) {
            continue;
        }

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

impl TypeCheckPass.exit_with_stmt(self: TypeCheckPass, nd: WithStmt) -> None {
    enter_method = "__aenter__" if nd.is_async else "__enter__";
    exit_method = "__aexit__" if nd.is_async else "__exit__";
    for item in nd.exprs {
        ctx_item: ExprAsItem = item;
        expr_type = self.evaluator.get_type_of_expression(ctx_item.expr);
        if not isinstance(expr_type, UnknownType) {
            enter_result = self.evaluator.get_type_of_magic_method_call(
                expr_type, enter_method, [], ctx_item.expr
            );
            if enter_result is None {
                self.emit(E1091, node_override=nd, type=str(expr_type));
            }

            if isinstance(expr_type, ClassType) {
                has_exit = (
                    self.evaluator._lookup_class_member(expr_type, exit_method)
                        is not None
                    or self.evaluator._lookup_object_member(expr_type, exit_method)
                        is not None
                );
                if not has_exit and not expr_type.is_any_type() {
                    self.emit(E1092, node_override=nd, type=str(expr_type));
                }
            }
        }
    }
}

impl TypeCheckPass.exit_while_stmt(self: TypeCheckPass, nd: WhileStmt) -> None {
    self.evaluator.get_type_of_expression(nd.condition);
}

impl TypeCheckPass.exit_assert_stmt(self: TypeCheckPass, nd: AssertStmt) -> None {
    self.evaluator.get_type_of_expression(nd.condition);
    if nd.error_msg is not None {
        self.evaluator.get_type_of_expression(nd.error_msg);
    }
}

impl TypeCheckPass.exit_yield_expr(self: TypeCheckPass, nd: YieldExpr) -> None {
    if nd.expr is None {
        return;
    }
    yielded_type = self.evaluator.get_type_of_expression(nd.expr);
    scope = self.evaluator._get_enclosing_return_scope(nd);
    if scope is None {
        return;
    }

    return_type = self.evaluator._get_declared_return_type(scope);
    if return_type is None or isinstance(return_type, UnknownType) {
        return;
    }

    is_async = isinstance(scope, Ability) and scope.is_async;
    yield_type = get_generator_yield_type(return_type, is_async);
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

impl TypeCheckPass.exit_delete_stmt(self: TypeCheckPass, nd: DeleteStmt) -> None {
    self.evaluator.get_type_of_expression(nd.target);
}

impl TypeCheckPass.exit_visit_stmt(self: TypeCheckPass, nd: VisitStmt) -> None {
    target_type = self.evaluator.get_type_of_expression(nd.target);
    path_class = self.evaluator.prefetch.path_class;

    def is_valid_visit_target(t: TypeBase) -> bool {
        if t.is_any_type() or isinstance(t, UnknownType) {
            return True;
        }
        if isinstance(t, ClassType) {
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

                return True;
            }
        }
        if isinstance(t, UnionType) {
            return all(is_valid_visit_target(m) for m in t.types);
        }
        return False;
    }

    if not is_valid_visit_target(target_type) {
        self.emit(E1094, node_override=nd, type=str(target_type));
    }
}

impl TypeCheckPass.exit_report_stmt(self: TypeCheckPass, nd: ReportStmt) -> None {
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

impl TypeCheckPass.exit_impl_def(self: TypeCheckPass, nd: ImplDef) -> None {
    import from jaclang.jac0core.constant { Tokens as Tok }

    if not (
        nd.decl_link
        and isinstance(nd.decl_link, Ability)
        and isinstance(nd.decl_link.name_ref, SpecialVarRef)
        and nd.decl_link.name_ref.name == Tok.KW_POST_INIT
    ) {
        return;
    }

    archetype = nd.decl_link.find_parent_of_type(Archetype);
    if not archetype {
        return;
    }
    arch: Archetype = archetype;

    deferred_fields: dict[str, HasVar] = {};
    for has_var_node in arch.get_has_vars() {
        has_var: HasVar = has_var_node;
        if has_var.defer {
            deferred_fields[has_var.name.value] = has_var;
        }
    }
    if not deferred_fields {
        return;
    }

    assigned: set[str] = set();
    for trailer in nd.get_all_sub_nodes(AtomTrailer) {
        atom_trailer: AtomTrailer = trailer;
        if not (atom_trailer.parent and isinstance(atom_trailer.parent, Assignment)) {
            continue;
        }
        if atom_trailer != atom_trailer.parent.target[0] {
            continue;
        }
        chain: list[AstSymbolNode] = atom_trailer.as_attr_list;
        if len(chain) >= 2 and chain[0].sym_name == 'self' {
            assigned.add(chain[1].sym_name);
        }
    }

    for (field_name, field_node) in deferred_fields.items() {
        if field_name not in assigned {
            self.emit(
                E1095, node_override=nd, field=field_name, arch=arch.name_spec.sym_name
            );
        }
    }
}

impl TypeCheckPass.exit_sub_tag(self: TypeCheckPass, nd: SubTag) -> None {
    if isinstance(nd.tag, Expr) {
        self.evaluator.validate_typevar_in_type_expr(nd.tag);

        if nd.tag?.type is None {
            self.evaluator.get_type_of_expression(nd.tag);
        }
    }
}

impl TypeCheckPass._eval_unpacking_names(self: TypeCheckPass, container: Expr) -> None {
    if isinstance(container, (TupleVal, ListVal)) {
        for val in container.values {
            if isinstance(val, Name) {
                self.evaluator.get_type_of_expression(val);
            } elif isinstance(val, (TupleVal, ListVal)) {
                self._eval_unpacking_names(val);
            }
        }
    }
}
