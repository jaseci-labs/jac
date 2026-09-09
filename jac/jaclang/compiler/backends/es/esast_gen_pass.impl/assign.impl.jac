import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

impl EsastGenPass.exit_assignment with uni.Assignment exit {
    if not here.target {
        here.gen.es_ast = None;
        return;
    }
    if here.is_comptime and here.value is not None {
        folded = self._ct_es_expr(here.value.ct_value, here.value);
        if folded is not None {
            here.value.gen.es_ast = folded;
        }
    }
    value_expr = cast(
        es.Expression | None, here.value.gen.es_ast if here.value is not None else None
    );

    if (
        len(here.target) == 1
        and isinstance(here.target[0], uni.Name)
        and here.target[0].sym_name == '_'
        and not here.aug_op
        and '_' not in self.reactive_vars
    ) {
        discard_value = cast(
            es.Expression, value_expr or es.Identifier(name='undefined')
        );
        void_expr = self.sync_loc(
            es.UnaryExpression(operator='void', prefix=True, argument=discard_value),
            jac_node=here
        );
        here.gen.es_ast = self.sync_loc(
            es.ExpressionStatement(expression=void_expr), jac_node=here
        );
        return;
    }

    if len(here.target) == 1 and isinstance(here.target[0], uni.Name) {
        target_name = here.target[0].sym_name;
        if target_name in self.reactive_vars {
            setter_arg: es.Expression;
            aug_op: (str | None) = None;
            if here.aug_op {
                aug_tok = Tok(here.aug_op.name)
                    if (here.aug_op.name in Tok.__members__)
                    else None;
                aug_to_binary: dict[Tok, str] = {
                    Tok.ADD_EQ: '+',
                    Tok.SUB_EQ: '-',
                    Tok.MUL_EQ: '*',
                    Tok.DIV_EQ: '/',
                    Tok.MOD_EQ: '%'
                };
                binary_op = aug_to_binary.get(aug_tok, '+') if aug_tok else '+';
                aug_op = binary_op;

                setter_arg = cast(es.Expression, value_expr or es.Literal(value=0));
            } else {
                setter_arg = cast(
                    es.Expression, value_expr or es.Identifier(name='undefined')
                );
            }
            state_update = StateUpdate(
                name=target_name, value=setter_arg, aug_op=aug_op
            );
            backend = self._ensure_backend();
            setter_call = self.sync_loc(
                backend.lower_state_update(state_update), jac_node=here
            );
            expr_stmt = self.sync_loc(
                es.ExpressionStatement(expression=setter_call), jac_node=here
            );
            here.gen.es_ast = expr_stmt;
            return;
        }
    }
    if here.aug_op {
        (left, _, _) = self._convert_assignment_target(here.target[0]);
        aug_tok = Tok(here.aug_op.name)
            if (here.aug_op.name in Tok.__members__)
            else None;
        right = cast(
            es.Expression,
            (
                value_expr
                or self._get_ast_or_default(
                    here.value,
                    default_factory=lambda (_src: any) { es.Identifier(
                        name='undefined'
                    ); }
                )
            )
        );

        _aug_base = AUG_TO_BINARY_TOK.get(aug_tok) if aug_tok else None;
        if _aug_base is not None and _aug_base in FW_BINARY_OPS {
            _fw_aug = self._fw_binary(
                here.target[0],
                FW_BINARY_OPS[_aug_base],
                cast(es.Expression, left),
                right
            );
            if _fw_aug is not None {
                here.gen.es_ast = self.sync_loc(
                    es.ExpressionStatement(
                        expression=self.sync_loc(
                            es.AssignmentExpression(
                                operator='=', left=left, right=_fw_aug
                            ),
                            jac_node=here
                        )
                    ),
                    jac_node=here
                );
                return;
            }
        }
        _aug_emit_name = AUG_EMIT_MAP.get(aug_tok) if aug_tok else None;
        if _aug_emit_name {
            _prim_result = self._try_primitive_op(
                here.target[0], _aug_emit_name, cast(es.Expression, left), right, here
            );
            if _prim_result is not None {
                expr_stmt = self.sync_loc(
                    es.ExpressionStatement(expression=_prim_result), jac_node=here
                );
                here.gen.es_ast = expr_stmt;
                return;
            }
        }
        operator = ES_AUG_ASSIGN_OPS.get(aug_tok) if aug_tok else None;
        operator = operator or '=';
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator=operator, left=left, right=right),
            jac_node=here
        );
        expr_stmt = self.sync_loc(
            es.ExpressionStatement(expression=assign_expr), jac_node=here
        );
        here.gen.es_ast = expr_stmt;
        return;
    }

    if len(here.target) == 1 {
        _setitem = self._try_subscript_setitem(here.target[0], value_expr, here);
        if _setitem is not None {
            here.gen.es_ast = _setitem;
            return;
        }
    }
    targets_info: list[AssignmentTargetInfo] = [];
    for target_node in here.target {
        (left, reference, decl_name) = self._convert_assignment_target(target_node);
        pattern_names = self._collect_pattern_names(target_node);
        targets_info.append(
            AssignmentTargetInfo(
                nd=target_node,
                left=left,
                reference=reference,
                decl_name=decl_name,
                pattern_names=pattern_names
            )
        );
    }
    statements: list[es.Statement] = [];
    current_value: es.Expression = cast(
        es.Expression,
        (
            value_expr
            or self._get_ast_or_default(
                here.value,
                default_factory=lambda (_src: any) { es.Identifier(name='undefined'); }
            )
        )
    );
    for info in reversed(targets_info) {
        target_node = info.nd;
        left = info.left;
        decl_name = info.decl_name;
        pattern_names = info.pattern_names;
        should_declare = False;
        cur_scope = self._current_scope();

        if decl_name {
            owning = self._declaring_scope_for(target_node);
            if owning is None {
                should_declare = not self._is_declared_in_any_scope(decl_name);
            } elif owning is cur_scope {
                should_declare = decl_name not in owning.declared;
            } elif decl_name not in owning.declared {
                self._hoist_into(owning, decl_name, target_node);
            }
        } elif pattern_names {
            inline_ok = True;
            for (name, name_node) in pattern_names {
                p_owning = self._declaring_scope_for(name_node);
                if p_owning is None {
                    if self._is_declared_in_any_scope(name) {
                        inline_ok = False;
                    }
                } elif (p_owning is not cur_scope) or (name in p_owning.declared) {
                    inline_ok = False;
                }
            }
            should_declare = inline_ok;
            if not inline_ok {
                for (name, name_node) in pattern_names {
                    p_owning = self._declaring_scope_for(name_node) or cur_scope;
                    if (
                        p_owning
                        and (name not in p_owning.declared)
                        and not self._is_declared_in_any_scope(name)
                    ) {
                        self._hoist_into(p_owning, name, name_node);
                    }
                }
            }
        }
        if should_declare {
            declarator = self.sync_loc(
                es.VariableDeclarator(
                    id=cast(es.Pattern, left),
                    `init=current_value if (value_expr is not None) else None
                ),
                jac_node=target_node
            );
            decl_stmt = self.sync_loc(
                es.VariableDeclaration(declarations=[declarator], kind='let'),
                jac_node=target_node
            );
            statements.append(decl_stmt);
            if decl_name {
                self._register_declaration(decl_name);
            } else {
                for (name, _) in pattern_names {
                    self._register_declaration(name);
                }
            }
        } else {
            assign_expr = self.sync_loc(
                es.AssignmentExpression(operator='=', left=left, right=current_value),
                jac_node=target_node
            );
            expr_stmt = self.sync_loc(
                es.ExpressionStatement(expression=assign_expr), jac_node=target_node
            );
            statements.append(expr_stmt);
        }
        if isinstance(left, es.Identifier) {
            current_value = self.sync_loc(
                es.Identifier(name=left.name), jac_node=target_node
            );
        } elif isinstance(info.reference, es.Identifier) {
            ref_ident = info.reference;
            current_value = self.sync_loc(
                es.Identifier(name=ref_ident.name), jac_node=target_node
            );
        } else {
            current_value = info.reference or current_value;
        }
    }
    if (len(statements) == 1) {
        here.gen.es_ast = statements[0];
    } else {
        here.gen.es_ast = statements;
    }
}

impl EsastGenPass._collect_pattern_names(
    target: uni.UniNode
) -> list[tuple[(str, uni.Name)]] {
    names: list[tuple[(str, uni.Name)]] = [];
    if isinstance(target, uni.Name) {
        names.append((target.sym_name, target));
    } elif (
        isinstance(target, uni.UnaryExpr)
        and isinstance(target.op, uni.Token)
        and target.op.name == Tok.STAR_MUL.value
    ) {
        names.extend(self._collect_pattern_names(target.operand));
    } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
        for value in target.values {
            names.extend(self._collect_pattern_names(value));
        }
    } elif isinstance(target, uni.DictVal) {
        for kv in target.kv_pairs {
            if isinstance(kv, uni.KVPair) {
                names.extend(self._collect_pattern_names(kv.value));
            }
        }
    } elif isinstance(target, uni.SubTag) {
        names.extend(self._collect_pattern_names(target.tag));
    }
    return names;
}

impl EsastGenPass._convert_assignment_target(
    target: uni.UniNode
) -> tuple[(es.Pattern | es.Expression), (es.Expression | None), (str | None)] {
    if isinstance(target, uni.Name) {
        identifier = self.sync_loc(
            es.Identifier(name=target.sym_name), jac_node=target
        );
        return (identifier, identifier, target.sym_name);
    }
    if (
        isinstance(target, uni.UnaryExpr)
        and isinstance(target.op, uni.Token)
        and target.op.name == Tok.STAR_MUL.value
    ) {
        (argument, _, _) = self._convert_assignment_target(target.operand);
        pattern = self.sync_loc(
            es.RestElement(argument=cast(es.Pattern, argument)), jac_node=target
        );
        return (pattern, None, None);
    }
    if isinstance(target, (uni.TupleVal, uni.ListVal)) {
        elements: list[(es.Pattern | None)] = [];
        for value in target.values {
            if (value is None) {
                elements.append(None);
                continue;
            }
            (pattern, _, _) = self._convert_assignment_target(value);
            elements.append(cast(es.Pattern, pattern));
        }
        pattern = self.sync_loc(es.ArrayPattern(elements=elements), jac_node=target);
        return (pattern, None, None);
    }
    if isinstance(target, uni.DictVal) {
        properties: list[(es.AssignmentProperty | es.RestElement)] = [];
        for kv in target.kv_pairs {
            if (not isinstance(kv, uni.KVPair) or (kv.key is None)) {
                continue;
            }
            key_expr = cast(
                es.Expression,
                kv.key.gen.es_ast
                    or self.sync_loc(es.Identifier(name='key'), jac_node=kv.key)
            );
            (value_pattern, _, _) = self._convert_assignment_target(kv.value);
            assignment = self.sync_loc(
                es.AssignmentProperty(
                    key=key_expr, value=cast(es.Pattern, value_pattern), shorthand=False
                ),
                jac_node=kv
            );
            properties.append(assignment);
        }
        pattern = self.sync_loc(
            es.ObjectPattern(properties=properties), jac_node=target
        );
        return (pattern, None, None);
    }
    if isinstance(target, uni.SubTag) {
        return self._convert_assignment_target(target.tag);
    }

    if (
        isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.IndexSlice)
        and (not target.right.is_range)
    ) {
        _si = target.right.gen.es_ast;
        if isinstance(_si, es.IndexInfo) {
            _obj = cast(
                es.Expression,
                target.target.gen.es_ast
                    or self.sync_loc(es.Identifier(name='obj'), jac_node=target)
            );
            _idx = cast(
                es.Expression,
                _si.value or self.sync_loc(es.Literal(value=0), jac_node=target)
            );
            _member = self.sync_loc(
                es.MemberExpression(object=_obj, property=_idx, computed=True),
                jac_node=target
            );
            return (_member, _member, None);
        }
    }
    left = cast(
        (es.Pattern | es.Expression),
        target.gen.es_ast or self.sync_loc(es.Identifier(name='temp'), jac_node=target)
    );
    reference = cast(es.Expression, left) if isinstance(left, es.Node) else None;
    return (left, reference, None);
}

impl EsastGenPass._target_to_pattern(target: es.Node, loc: uni.UniNode) -> es.Node {
    if isinstance(target, es.SpreadElement) {
        inner = self._target_to_pattern(target.argument, loc)
            if target.argument
            else self.sync_loc(es.Identifier(name='_item'), jac_node=loc);
        return self.sync_loc(es.RestElement(argument=inner), jac_node=loc);
    }
    if isinstance(target, es.ArrayExpression) {
        elements: list[(es.Node | None)] = [];
        for elem in target.elements {
            elements.append(
                self._target_to_pattern(elem, loc) if elem is not None else None
            );
        }
        return self.sync_loc(es.ArrayPattern(elements=elements), jac_node=loc);
    }
    pattern_nodes = (
        es.Identifier,
        es.ArrayPattern,
        es.ObjectPattern,
        es.AssignmentPattern,
        es.RestElement
    );
    if isinstance(target, pattern_nodes) {
        return target;
    }
    return self.sync_loc(es.Identifier(name='_item'), jac_node=loc);
}
