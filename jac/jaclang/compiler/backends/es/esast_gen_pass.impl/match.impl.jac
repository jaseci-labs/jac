impl EsastGenPass.exit_switch_case with uni.SwitchCase exit {
    case_test: (es.Expression | None) = None;
    if (here.pattern and isinstance(here.pattern, uni.MatchValue)) {
        case_test = self._get_ast_or_default(
            here.pattern.value,
            default_factory=lambda (_src: any) { es.Literal(value=None); }
        );
    }
    body_stmts = self._collect_stmt_body(here.body);
    here.gen.es_ast = self.sync_loc(
        es.SwitchCase(`test=case_test, consequent=body_stmts), jac_node=here
    );
}

impl EsastGenPass.exit_switch_stmt with uni.SwitchStmt exit {
    `test = self._get_ast_or_default(
        here.target, default_factory=lambda (_src: any) { es.Literal(value=None); }
    );
    cases: list[es.SwitchCase] = [];
    for stmt in here.cases {
        if (stmt.gen.es_ast and isinstance(stmt.gen.es_ast, es.SwitchCase)) {
            switch_case = cast(es.SwitchCase, stmt.gen.es_ast);
            cases.append(switch_case);
        }
    }
    here.gen.es_ast = self.sync_loc(
        es.SwitchStatement(discriminant=`test, cases=cases), jac_node=here
    );
}

impl EsastGenPass.exit_match_stmt with uni.MatchStmt exit {
    subj_expr = cast(
        es.Expression,
        self._get_ast_or_default(
            here.target, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );
    self.match_seq += 1;
    subj_name = f"__jac_match_subj_{self.match_seq}";
    flag_name = f"__jac_matched_{self.match_seq}";
    stmts: list[es.Statement] = [];
    stmts.append(
        self.sync_loc(
            es.VariableDeclaration(
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=es.Identifier(name=subj_name), `init=subj_expr
                        ),
                        jac_node=here
                    )
                ],
                kind='let'
            ),
            jac_node=here
        )
    );
    stmts.append(
        self.sync_loc(
            es.VariableDeclaration(
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=es.Identifier(name=flag_name),
                            `init=es.Literal(value=False)
                        ),
                        jac_node=here
                    )
                ],
                kind='let'
            ),
            jac_node=here
        )
    );
    for mcase in here.cases {
        (cond, binds, ok) = self._lower_match_pattern(
            mcase.pattern, self.sync_loc(es.Identifier(name=subj_name), jac_node=mcase)
        );
        if not ok {
            here.gen.es_ast = self.sync_loc(es.BlockStatement(body=[]), jac_node=here);
            return;
        }
        body_stmts = self._collect_stmt_body(mcase.body);
        set_flag = self.sync_loc(
            es.ExpressionStatement(
                expression=self.sync_loc(
                    es.AssignmentExpression(
                        operator='=',
                        left=es.Identifier(name=flag_name),
                        right=es.Literal(value=True)
                    ),
                    jac_node=mcase
                )
            ),
            jac_node=mcase
        );
        inner: list[es.Statement] = list(binds);
        if mcase.guard is not None {
            guard_expr = self._coerce_truthy(
                mcase.guard,
                cast(
                    es.Expression,
                    self._get_ast_or_default(
                        mcase.guard,
                        default_factory=lambda (_src: any) { es.Literal(value=True); }
                    )
                ),
                mcase
            );
            inner.append(
                self.sync_loc(
                    es.IfStatement(
                        `test=guard_expr,
                        consequent=self.sync_loc(
                            es.BlockStatement(body=[set_flag] + body_stmts),
                            jac_node=mcase
                        )
                    ),
                    jac_node=mcase
                )
            );
        } else {
            inner.append(set_flag);
            inner.extend(body_stmts);
        }
        test_expr: es.Expression = self.sync_loc(
            es.UnaryExpression(
                operator='!', prefix=True, argument=es.Identifier(name=flag_name)
            ),
            jac_node=mcase
        );
        if cond is not None {
            test_expr = self.sync_loc(
                es.LogicalExpression(operator='&&', left=test_expr, right=cond),
                jac_node=mcase
            );
        }
        stmts.append(
            self.sync_loc(
                es.IfStatement(
                    `test=test_expr,
                    consequent=self.sync_loc(
                        es.BlockStatement(body=inner), jac_node=mcase
                    )
                ),
                jac_node=mcase
            )
        );
    }
    here.gen.es_ast = stmts;
}

impl EsastGenPass._match_subj_member(subj: es.Expression, field: str) -> es.Expression {
    return es.MemberExpression(
        object=subj, property=es.Identifier(name=field), computed=False
    );
}

impl EsastGenPass._match_bind_name(
    name_node: uni.UniNode, value: es.Expression
) -> es.Statement {
    bind_name = name_node.sym_name
        if isinstance(name_node, uni.AstSymbolNode)
        else str(name_node);
    self._ensure_identifier_declared(bind_name, name_node);
    return self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.AssignmentExpression(
                    operator='=', left=es.Identifier(name=bind_name), right=value
                ),
                jac_node=name_node
            )
        ),
        jac_node=name_node
    );
}

impl EsastGenPass._match_arch_field_order(pat: uni.MatchArch) -> (list[str] | None) {
    nm = pat.name;
    sym = nm.sym if isinstance(nm, uni.AstSymbolNode) else None;
    if sym is None {
        return None;
    }
    arch_node: (uni.UniNode | None) = sym.decl;
    while arch_node is not None and not isinstance(arch_node, uni.Archetype) {
        arch_node = arch_node.parent;
    }
    if arch_node is None {
        return None;
    }
    inner = ModuleFacts.unwrap_body(arch_node);
    if inner is None {
        return None;
    }
    order: list[str] = [];
    for stmt in inner {
        if isinstance(stmt, uni.ArchHas) {
            for hv in stmt.vars {
                order.append(hv.name.value);
            }
        }
    }
    return order or None;
}

impl EsastGenPass._lower_match_pattern(
    pat: uni.MatchPattern, subj: es.Expression
) -> tuple[(es.Expression | None), list[es.Statement], bool] {
    no_binds: list[es.Statement] = [];
    if isinstance(pat, uni.MatchWild) {
        return (None, no_binds, True);
    }
    if isinstance(pat, uni.MatchAs) {
        cond: (es.Expression | None) = None;
        binds: list[es.Statement] = [];
        if pat.pattern is not None {
            (cond, binds, ok) = self._lower_match_pattern(pat.pattern, subj);
            if not ok {
                return (None, no_binds, False);
            }
        }
        binds.append(self._match_bind_name(pat.name, subj));
        return (cond, binds, True);
    }
    if isinstance(pat, (uni.MatchValue, uni.MatchSingleton)) {
        val_node = pat.value;
        val_expr = cast(
            es.Expression,
            self._get_ast_or_default(
                val_node, default_factory=lambda (_src: any) { es.Literal(value=None); }
            )
        );

        op = '==' if self._is_null_literal(val_node) else '===';
        return (
            self.sync_loc(
                es.BinaryExpression(operator=op, left=subj, right=val_expr),
                jac_node=pat
            ),
            no_binds,
            True
        );
    }
    if isinstance(pat, uni.MatchOr) {
        or_cond: (es.Expression | None) = None;
        for sub in pat.patterns {
            (c, b, ok) = self._lower_match_pattern(sub, subj);
            if not ok {
                return (None, no_binds, False);
            }
            if b {
                self.emit(
                    E5018,
                    node_override=sub,
                    construct='binding in an or-pattern',
                    fix="Give each '|' alternative its own 'case', so the binding "
                    "appears once per branch."
                );
                return (None, no_binds, False);
            }
            if c is None {
                return (None, no_binds, True);
            }
            or_cond = c
                if or_cond is None
                else self.sync_loc(
                    es.LogicalExpression(operator='||', left=or_cond, right=c),
                    jac_node=pat
                );
        }
        return (or_cond, no_binds, True);
    }
    if isinstance(pat, uni.MatchSequence) {
        values = list(pat.values);
        star_idx = -1;
        for i in range(len(values)) {
            if isinstance(values[i], uni.MatchStar) {
                star_idx = i;
                break;
            }
        }
        conds: list[es.Expression] = [
            self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Array'),
                        property=es.Identifier(name='isArray'),
                        computed=False
                    ),
                    arguments=[subj]
                ),
                jac_node=pat
            )
        ];
        seq_binds: list[es.Statement] = [];
        subj_len = self._match_subj_member(subj, 'length');
        if star_idx < 0 {
            conds.append(
                self.sync_loc(
                    es.BinaryExpression(
                        operator='===',
                        left=subj_len,
                        right=es.Literal(value=len(values))
                    ),
                    jac_node=pat
                )
            );
        } else {
            conds.append(
                self.sync_loc(
                    es.BinaryExpression(
                        operator='>=',
                        left=subj_len,
                        right=es.Literal(value=len(values) - 1)
                    ),
                    jac_node=pat
                )
            );
        }
        for i in range(len(values)) {
            sub = values[i];
            if isinstance(sub, uni.MatchStar) {
                after = len(values) - 1 - i;
                slice_args: list[es.Expression] = [es.Literal(value=i)];
                if after > 0 {
                    slice_args.append(
                        self.sync_loc(
                            es.BinaryExpression(
                                operator='-',
                                left=self._match_subj_member(subj, 'length'),
                                right=es.Literal(value=after)
                            ),
                            jac_node=sub
                        )
                    );
                }
                seq_binds.append(
                    self._match_bind_name(
                        sub.name,
                        self.sync_loc(
                            es.CallExpression(
                                callee=self._match_subj_member(subj, 'slice'),
                                arguments=slice_args
                            ),
                            jac_node=sub
                        )
                    )
                );
                continue;
            }
            if star_idx >= 0 and i > star_idx {
                elem_idx: es.Expression = self.sync_loc(
                    es.BinaryExpression(
                        operator='-',
                        left=self._match_subj_member(subj, 'length'),
                        right=es.Literal(value=len(values) - i)
                    ),
                    jac_node=sub
                );
            } else {
                elem_idx = es.Literal(value=i);
            }
            elem = self.sync_loc(
                es.MemberExpression(object=subj, property=elem_idx, computed=True),
                jac_node=sub
            );
            (c, b, ok) = self._lower_match_pattern(sub, elem);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                conds.append(c);
            }
            seq_binds.extend(b);
        }
        seq_cond: es.Expression = conds[0];
        for c in conds[1:] {
            seq_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=seq_cond, right=c),
                jac_node=pat
            );
        }
        return (seq_cond, seq_binds, True);
    }
    if isinstance(pat, uni.MatchMapping) {
        map_conds: list[es.Expression] = [];
        map_binds: list[es.Statement] = [];
        rest_star: (uni.MatchStar | None) = None;
        matched_keys: list[es.Expression] = [];
        for `entry in pat.values {
            if isinstance(`entry, uni.MatchStar) {
                rest_star = `entry;
                continue;
            }
            key_node = `entry.key;
            if isinstance(key_node, uni.MatchValue) {
                key_node = key_node.value;
            }
            key_expr = cast(
                es.Expression,
                self._get_ast_or_default(
                    key_node,
                    default_factory=lambda (_src: any) { es.Literal(value=None); }
                )
            );
            map_conds.append(
                self.sync_loc(
                    es.CallExpression(
                        callee=es.MemberExpression(
                            object=es.MemberExpression(
                                object=es.MemberExpression(
                                    object=es.Identifier(name='Object'),
                                    property=es.Identifier(name='prototype'),
                                    computed=False
                                ),
                                property=es.Identifier(name='hasOwnProperty'),
                                computed=False
                            ),
                            property=es.Identifier(name='call'),
                            computed=False
                        ),
                        arguments=[subj, key_expr]
                    ),
                    jac_node=`entry
                )
            );
            val_at_key = self.sync_loc(
                es.MemberExpression(object=subj, property=key_expr, computed=True),
                jac_node=`entry
            );
            matched_keys.append(key_expr);
            (c, b, ok) = self._lower_match_pattern(`entry.value, val_at_key);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                map_conds.append(c);
            }
            map_binds.extend(b);
        }
        if rest_star is not None {
            filter_arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[es.ArrayPattern(elements=[es.Identifier(name='__jac_k')])],
                    body=self.sync_loc(
                        es.UnaryExpression(
                            operator='!',
                            prefix=True,
                            argument=self.sync_loc(
                                es.CallExpression(
                                    callee=es.MemberExpression(
                                        object=es.ArrayExpression(
                                            elements=list(matched_keys)
                                        ),
                                        property=es.Identifier(name='includes'),
                                        computed=False
                                    ),
                                    arguments=[es.Identifier(name='__jac_k')]
                                ),
                                jac_node=rest_star
                            )
                        ),
                        jac_node=rest_star
                    ),
                    expression=True
                ),
                jac_node=rest_star
            );
            rest_value = self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Object'),
                        property=es.Identifier(name='fromEntries'),
                        computed=False
                    ),
                    arguments=[
                        self.sync_loc(
                            es.CallExpression(
                                callee=es.MemberExpression(
                                    object=self.sync_loc(
                                        es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name='Object'),
                                                property=es.Identifier(name='entries'),
                                                computed=False
                                            ),
                                            arguments=[subj]
                                        ),
                                        jac_node=rest_star
                                    ),
                                    property=es.Identifier(name='filter'),
                                    computed=False
                                ),
                                arguments=[filter_arrow]
                            ),
                            jac_node=rest_star
                        )
                    ]
                ),
                jac_node=rest_star
            );
            map_binds.append(self._match_bind_name(rest_star.name, rest_value));
        }
        if not map_conds {
            return (None, map_binds, True);
        }
        map_cond: es.Expression = map_conds[0];
        for c in map_conds[1:] {
            map_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=map_cond, right=c),
                jac_node=pat
            );
        }
        return (map_cond, map_binds, True);
    }
    if isinstance(pat, uni.MatchArch) {
        cls_name = pat.name.sym_name
            if isinstance(pat.name, uni.AstSymbolNode)
            else None;
        if cls_name is None {
            self.emit(
                E5018,
                node_override=pat,
                construct='dotted class pattern',
                fix="Import the archetype directly and match on its bare name."
            );
            return (None, no_binds, False);
        }
        arch_conds: list[es.Expression] = [
            self.sync_loc(
                es.BinaryExpression(
                    operator='instanceof', left=subj, right=es.Identifier(name=cls_name)
                ),
                jac_node=pat
            )
        ];
        arch_binds: list[es.Statement] = [];
        pairs: list = [];
        arg_pats = list(pat.arg_patterns) if pat.arg_patterns else [];
        if arg_pats {
            order = self._match_arch_field_order(pat);
            if order is None or len(arg_pats) > len(order) {
                self.emit(
                    E5018,
                    node_override=pat,
                    construct='positional class pattern with unresolvable field order',
                    fix="Match the fields by keyword, 'Cls(field=pattern)', instead "
                    "of by position."
                );
                return (None, no_binds, False);
            }
            for i in range(len(arg_pats)) {
                pairs.append((order[i], arg_pats[i]));
            }
        }
        for kv in (list(pat.kw_patterns) if pat.kw_patterns else []) {
            fname = kv.key.sym_name if isinstance(kv.key, uni.AstSymbolNode) else None;
            if fname is None {
                self.emit(
                    E5018,
                    node_override=kv,
                    construct='computed class-pattern field',
                    fix="Name the field with a plain identifier instead of a "
                    "computed key."
                );
                return (None, no_binds, False);
            }
            pairs.append((fname, kv.value));
        }
        for (fname, sub_pat) in pairs {
            field_expr = self.sync_loc(
                self._match_subj_member(subj, fname), jac_node=pat
            );
            (c, b, ok) = self._lower_match_pattern(sub_pat, field_expr);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                arch_conds.append(c);
            }
            arch_binds.extend(b);
        }
        arch_cond: es.Expression = arch_conds[0];
        for c in arch_conds[1:] {
            arch_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=arch_cond, right=c),
                jac_node=pat
            );
        }
        return (arch_cond, arch_binds, True);
    }
    self.emit(
        E5018,
        node_override=pat,
        construct=pat.__class__.__name__,
        fix="Rewrite it with literal, capture, sequence, mapping, or class patterns."
    );
    return (None, no_binds, False);
}
