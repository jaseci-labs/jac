import from jaclang.compiler.symbol_utils { return_type_is_jsx }

impl EsastGenPass._ability_is_generator(nd: uni.Ability) -> bool {
    for y in nd.get_all_sub_nodes(uni.YieldExpr) {
        if y.find_parent_of_type(uni.Ability) is nd {
            return True;
        }
    }
    return False;
}

impl EsastGenPass.exit_has_var with uni.HasVar exit {
    here.gen.es_ast = None;
}

impl EsastGenPass.exit_param_var with uni.ParamVar exit {
    param_id = self.sync_loc(
        es.Identifier(name=here.name.sym_name), jac_node=here.name
    );
    self._register_declaration(param_id.name);
    if here.is_vararg or here.is_kwargs {
        here.gen.es_ast = self.sync_loc(
            es.RestElement(argument=param_id), jac_node=here
        );
    } elif here.value and here.value.gen.es_ast {
        here.gen.es_ast = self.sync_loc(
            es.AssignmentPattern(
                left=param_id, right=cast(es.Expression, here.value.gen.es_ast)
            ),
            jac_node=here
        );
    } else {
        here.gen.es_ast = param_id;
    }
}

impl EsastGenPass.exit_func_signature with uni.FuncSignature exit {
    here.gen.es_ast = None;
}

impl EsastGenPass.exit_ability with uni.Ability exit {
    if self._view_stack {
        self._view_stack.pop();
    }

    if self.reactive_vars_stack {
        self.reactive_vars = self.reactive_vars_stack.pop();
    }

    if here.is_comptime {
        here.gen.es_ast = None;
        return;
    }

    osp_info = self._osp_ability_info(here);
    if osp_info is not None {
        self._emit_osp_slot_method(here, osp_info);
        return;
    }

    if (isinstance(here.signature, uni.EventSignature) and here.in_client_context()) {
        self._transform_to_useeffect(here);
        return;
    }

    ref_param: (uni.ParamVar | None) = None;
    if (
        here.code_context == CodeContext.CLIENT
        and not here.is_method
        and self._component_call_abi(here) in ('props_destructure', 'props_passthrough')
    ) {
        ref_param = self._ref_forward_param(here);
    }
    if (here.code_context == CodeContext.CLIENT and not here.is_method) {
        self.client_manifest.has_client = True;
        is_pub = here.access and (here.access.tag.name == Tok.KW_PUB);
        route_role: (str | None) = None;
        if (
            isinstance(here.signature, uni.FuncSignature)
            and here.signature.return_type is not None
        ) {
            route_role = self._return_type_route_role(here.signature.return_type);
        }

        if is_pub or route_role or here.codespace_dual {
            name = here.name_ref.sym_name;
            self.client_manifest.exports.append(name);
            if (
                isinstance(here.signature, uni.FuncSignature)
                and here.signature.return_type is not None
                and return_type_is_jsx(here.signature.return_type)
            ) {
                self.component_export_names.add(name);
            }

            self.client_manifest.params[name] = [
                p.name.sym_name
                for p in here.signature.params
                if p is not ref_param
            ]
                if isinstance(here.signature, uni.FuncSignature)
                else [];
            if route_role == 'page' and self.client_manifest.page_export is None {
                self.client_manifest.page_export = name;
            } elif route_role == 'layout'
                and self.client_manifest.layout_export is None {
                self.client_manifest.layout_export = name;
            }
        }
    }
    component_call_abi = self._component_call_abi(here);
    params: list[es.Pattern] = [];
    destructure_stmts: list[es.Statement] = [];
    destructure_props: list[es.AssignmentProperty | es.RestElement] = [];

    sig_params = (
        [
            p
            for p in here.signature.params
            if p is not ref_param
        ]
            if isinstance(here.signature, uni.FuncSignature)
            else []
    );
    value_params = (
        [
            p
            for p in here.signature.get_parameters()
            if p is not ref_param
        ]
            if isinstance(here.signature, uni.FuncSignature)
            else []
    );
    if value_params {
        if component_call_abi == 'props_destructure' {
            params.append(es.Identifier(name="props"));
            for param in sig_params {
                param_key = self.sync_loc(
                    es.Identifier(name=param.name.sym_name), jac_node=param.name
                );
                destructure_props.append(
                    self.sync_loc(
                        es.AssignmentProperty(
                            key=param_key,
                            value=cast(es.Pattern, param.gen.es_ast),
                            shorthand=not isinstance(
                                param.gen.es_ast, es.AssignmentPattern
                            ),
                        ),
                        jac_node=param,
                    )
                );
            }
            destructure_stmts = [
                self.sync_loc(
                    es.VariableDeclaration(
                        declarations=[
                            self.sync_loc(
                                es.VariableDeclarator(
                                    id=self.sync_loc(
                                        es.ObjectPattern(properties=destructure_props),
                                        jac_node=here,
                                    ),
                                    `init=self.sync_loc(
                                        es.Identifier(name="props"), jac_node=here
                                    ),
                                ),
                                jac_node=here,
                            )
                        ],
                        kind="const",
                    ),
                    jac_node=here,
                )
            ];
        } else {
            if component_call_abi == 'props_passthrough' {
                self.emit(
                    W5015,
                    node_override=value_params[0],
                    component=here.name_ref.sym_name
                );
            }
            for param in value_params {
                if param.gen.es_ast {
                    params.append(cast(es.Pattern, param.gen.es_ast));
                }
            }
        }
    }
    if ref_param is not None {
        if not params {
            params.append(self.sync_loc(es.Identifier(name="props"), jac_node=here));
        }
        params.append(
            cast(es.Pattern, ref_param.gen.es_ast)
                if ref_param.gen.es_ast
                else self.sync_loc(
                    es.Identifier(name=ref_param.name.sym_name), jac_node=ref_param.name
                )
        );
    }
    inner = ModuleFacts.unwrap_body(here);
    body_stmts = self._collect_stmt_body(inner);
    body_stmts = self._prepend_hoisted(here, body_stmts);
    block = self.sync_loc(
        es.BlockStatement(body=destructure_stmts + body_stmts), jac_node=here
    );
    func_id = self.sync_loc(
        es.Identifier(name=here.name_ref.sym_name), jac_node=here.name_ref
    );
    is_gen = self._ability_is_generator(here);
    if here.is_method {
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=None,
                params=params,
                body=block,
                generator=is_gen,
                async_=here.is_async
            ),
            jac_node=here
        );
        method_def = self.sync_loc(
            es.MethodDefinition(
                key=func_id, value=func_expr, kind='method', `static=here.is_static
            ),
            jac_node=here
        );
        here.gen.es_ast = method_def;
    } elif ref_param is not None {
        self._inject_runtime_import('forwardRef', here);
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=func_id,
                params=params,
                body=block,
                generator=is_gen,
                async_=here.is_async
            ),
            jac_node=here
        );
        forward_call = self.sync_loc(
            es.CallExpression(
                callee=es.Identifier(name='forwardRef'), arguments=[func_expr]
            ),
            jac_node=here
        );
        declarator = self.sync_loc(
            es.VariableDeclarator(
                id=self.sync_loc(
                    es.Identifier(name=here.name_ref.sym_name), jac_node=here.name_ref
                ),
                `init=forward_call,
            ),
            jac_node=here
        );
        here.gen.es_ast = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'),
            jac_node=here
        );
    } else {
        pascal = self._component_pascal_name(here);
        if pascal is not None {
            func_decl = self.sync_loc(
                es.FunctionDeclaration(
                    id=self.sync_loc(
                        es.Identifier(name=pascal), jac_node=here.name_ref
                    ),
                    params=params,
                    body=block,
                    generator=is_gen,
                    async_=here.is_async
                ),
                jac_node=here
            );
            alias_decl = self.sync_loc(
                es.VariableDeclaration(
                    declarations=[
                        self.sync_loc(
                            es.VariableDeclarator(
                                id=self.sync_loc(
                                    es.Identifier(name=here.name_ref.sym_name),
                                    jac_node=here.name_ref
                                ),
                                `init=self.sync_loc(
                                    es.Identifier(name=pascal), jac_node=here.name_ref
                                ),
                            ),
                            jac_node=here
                        )
                    ],
                    kind='const'
                ),
                jac_node=here
            );
            here.gen.es_ast = [func_decl, alias_decl];
        } else {
            func_decl = self.sync_loc(
                es.FunctionDeclaration(
                    id=func_id,
                    params=params,
                    body=block,
                    generator=is_gen,
                    async_=here.is_async
                ),
                jac_node=here
            );
            here.gen.es_ast = func_decl;
        }
    }
}

impl EsastGenPass.enter_ability with uni.Ability entry {
    if isinstance(here.body, uni.ImplDef) and (here.body not in here.kid) {
        here.add_kids_right([here.body], pos_update=False, parent_update=True);
    }

    self._view_stack.append(None);
    self.reactive_vars_stack.append(self.reactive_vars);
    self.reactive_vars = set(self.reactive_vars);
}

impl EsastGenPass.exit_enum with uni.Enum exit {
    if here.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = here.access and (here.access.tag.name == Tok.KW_PUB);
        if is_pub or here.codespace_dual {
            self.client_manifest.exports.append(here.name.sym_name);
        }
    }
    properties: list[(es.Property | es.SpreadElement)] = [];
    inner = ModuleFacts.unwrap_body(here);
    next_auto = 1;
    if inner {
        for stmt in inner {
            if isinstance(stmt, uni.Assignment) {
                for target in stmt.target {
                    if isinstance(target, uni.AstSymbolNode) {
                        key = self.sync_loc(
                            es.Identifier(name=target.sym_name), jac_node=target
                        );
                        enum_value: es.Expression;
                        if (stmt.value and stmt.value.gen.es_ast) {
                            enum_value = cast(es.Expression, stmt.value.gen.es_ast);
                            if (
                                isinstance(enum_value, es.Literal)
                                and isinstance(enum_value.value, int)
                                and not isinstance(enum_value.value, bool)
                            ) {
                                next_auto = enum_value.value + 1;
                            }
                        } else {
                            enum_value = self.sync_loc(
                                es.Literal(value=next_auto), jac_node=stmt
                            );
                            next_auto += 1;
                        }
                        prop = self.sync_loc(
                            es.Property(key=key, value=enum_value, kind='init'),
                            jac_node=stmt
                        );
                        properties.append(prop);
                    }
                }
            }
        }
    }
    obj_expr = self.sync_loc(es.ObjectExpression(properties=properties), jac_node=here);
    var_id = self.sync_loc(es.Identifier(name=here.name.sym_name), jac_node=here.name);
    var_decl = self.sync_loc(
        es.VariableDeclaration(
            declarations=[
                self.sync_loc(
                    es.VariableDeclarator(id=var_id, `init=obj_expr), jac_node=here
                )
            ],
            kind='const'
        ),
        jac_node=here
    );
    here.gen.es_ast = var_decl;
}

impl EsastGenPass.exit_type_alias with uni.TypeAlias exit {
    here.gen.es_ast = [];
}

impl EsastGenPass.exit_type_param with uni.TypeParam exit {
    here.gen.es_ast = [];
}

impl EsastGenPass.exit_archetype with uni.Archetype exit {
    if here.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = here.access and (here.access.tag.name == Tok.KW_PUB);
        if is_pub or here.codespace_dual {
            self.client_manifest.exports.append(here.name.sym_name);
        }
    }
    body_stmts: list[es.MethodDefinition | es.PropertyDefinition] = [];
    has_members: list[uni.ArchHas] = [];
    inner = ModuleFacts.unwrap_body(here);
    if inner {
        for stmt in inner {
            if isinstance(stmt, uni.ArchHas) {
                has_members.append(stmt);
                continue;
            }
            if isinstance(stmt, uni.GlobalVars) and stmt.is_frozen {
                for asn in stmt.assignments {
                    tgt = asn.target[0] if asn.target else None;
                    folded = (
                        self._ct_es_expr(asn.value.ct_value, asn.value)
                            if asn.value is not None
                            else None
                    );
                    if isinstance(tgt, uni.Name) and folded is not None {
                        body_stmts.append(
                            self.sync_loc(
                                es.PropertyDefinition(
                                    key=es.Identifier(name=tgt.sym_name),
                                    value=folded,
                                    `static=True
                                ),
                                jac_node=asn
                            )
                        );
                    } elif (
                        isinstance(tgt, uni.Name)
                        and asn.value is not None
                        and isinstance(asn.value.gen.es_ast, es.Expression)
                    ) {
                        body_stmts.append(
                            self.sync_loc(
                                es.MethodDefinition(
                                    key=es.Identifier(name=tgt.sym_name),
                                    kind='get',
                                    value=self.sync_loc(
                                        es.FunctionExpression(
                                            params=[],
                                            body=self.sync_loc(
                                                es.BlockStatement(
                                                    body=[
                                                        self.sync_loc(
                                                            es.ReturnStatement(
                                                                argument=cast(
                                                                    es.Expression,
                                                                    asn.value.gen.es_ast
                                                                )
                                                            ),
                                                            jac_node=asn
                                                        )
                                                    ]
                                                ),
                                                jac_node=asn
                                            )
                                        ),
                                        jac_node=asn
                                    )
                                ),
                                jac_node=asn
                            )
                        );
                    }
                }
                continue;
            }
            if (
                stmt.gen.es_ast
                and stmt.gen.es_ast
                and isinstance(
                    stmt.gen.es_ast, (es.MethodDefinition, es.PropertyDefinition)
                )
            ) {
                body_stmts.append(stmt.gen.es_ast);
            }
        }
    }

    is_local_osp_arch = (
        (here.name is not None)
        and (here.name.sym_name in self._osp_arch_set())
        and (here.arch_kind is not None)
    );
    is_shared_boundary_arch = (
        (here.name is not None) and (here.name.sym_name in self.shared_arch_names)
    );
    has_postinit = False;
    for _stmt in (ModuleFacts.unwrap_body(here) or []) {
        if (
            isinstance(_stmt, uni.Ability)
            and getattr(_stmt, 'sym_name', '') == '__post_init__'
        ) {
            has_postinit = True;
        }
    }
    if (
        (
            (here.arch_type.name == Tok.KW_OBJECT)
            or is_local_osp_arch
            or is_shared_boundary_arch
        )
        and (has_members or has_postinit)
    ) {
        constructor_stmts: list[es.Statement] = [];
        props_param = self.sync_loc(
            es.AssignmentPattern(
                left=self.sync_loc(es.Identifier(name='props'), jac_node=here),
                right=self.sync_loc(es.ObjectExpression(properties=[]), jac_node=here)
            ),
            jac_node=here
        );
        for arch_has in has_members {
            if arch_has.is_static {
                for var in arch_has.vars {
                    default_expr: es.Expression = cast(
                        es.Expression, var.value.gen.es_ast
                    )
                        if (var.value and var.value.gen.es_ast and var.value.gen.es_ast)
                        else self.sync_loc(es.Literal(value=None), jac_node=var);
                    static_prop = self.sync_loc(
                        es.PropertyDefinition(
                            key=self.sync_loc(
                                es.Identifier(name=var.name.sym_name), jac_node=var.name
                            ),
                            value=default_expr,
                            `static=True
                        ),
                        jac_node=var
                    );
                    body_stmts.append(static_prop);
                }
                continue;
            }
            for var in arch_has.vars {
                props_ident = self.sync_loc(es.Identifier(name='props'), jac_node=var);
                prop_ident = self.sync_loc(
                    es.Identifier(name=var.name.sym_name), jac_node=var.name
                );
                this_member = self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(es.ThisExpression(), jac_node=var),
                        property=prop_ident,
                        computed=False
                    ),
                    jac_node=var
                );
                props_access = self.sync_loc(
                    es.MemberExpression(
                        object=props_ident,
                        property=self.sync_loc(
                            es.Identifier(name=var.name.sym_name), jac_node=var.name
                        ),
                        computed=False
                    ),
                    jac_node=var
                );
                has_call = self.sync_loc(
                    es.CallExpression(
                        callee=self.sync_loc(
                            es.MemberExpression(
                                object=props_ident,
                                property=self.sync_loc(
                                    es.Identifier(name='hasOwnProperty'), jac_node=var
                                ),
                                computed=False
                            ),
                            jac_node=var
                        ),
                        arguments=[
                            self.sync_loc(
                                es.Literal(value=var.name.sym_name), jac_node=var.name
                            )
                        ]
                    ),
                    jac_node=var
                );
                default_val: es.Expression = cast(es.Expression, var.value.gen.es_ast)
                    if (var.value and var.value.gen.es_ast and var.value.gen.es_ast)
                    else self.sync_loc(es.Literal(value=None), jac_node=var);
                conditional = self.sync_loc(
                    es.ConditionalExpression(
                        `test=has_call, consequent=props_access, alternate=default_val
                    ),
                    jac_node=var
                );
                assignment = self.sync_loc(
                    es.AssignmentExpression(
                        operator='=', left=this_member, right=conditional
                    ),
                    jac_node=var
                );
                constructor_stmts.append(
                    self.sync_loc(
                        es.ExpressionStatement(expression=assignment), jac_node=var
                    )
                );
            }
        }
        for tp in (here.type_params or []) {
            if not tp.is_comptime {
                continue;
            }
            constructor_stmts.append(
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=self.sync_loc(
                            es.AssignmentExpression(
                                operator='=',
                                left=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.ThisExpression(), jac_node=tp
                                        ),
                                        property=es.Identifier(name=tp.name.value),
                                        computed=False
                                    ),
                                    jac_node=tp
                                ),
                                right=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.Identifier(name='props'), jac_node=tp
                                        ),
                                        property=es.Identifier(name=tp.name.value),
                                        computed=False
                                    ),
                                    jac_node=tp
                                )
                            ),
                            jac_node=tp
                        )
                    ),
                    jac_node=tp
                )
            );
        }
        if has_postinit {
            constructor_stmts.append(
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=self.sync_loc(
                            es.CallExpression(
                                callee=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.ThisExpression(), jac_node=here
                                        ),
                                        property=self.sync_loc(
                                            es.Identifier(name='__post_init__'),
                                            jac_node=here
                                        ),
                                        computed=False
                                    ),
                                    jac_node=here
                                ),
                                arguments=[]
                            ),
                            jac_node=here
                        )
                    ),
                    jac_node=here
                )
            );
        }
        if constructor_stmts {
            if here.base_classes {
                constructor_stmts.insert(
                    0,
                    self.sync_loc(
                        es.ExpressionStatement(
                            expression=self.sync_loc(
                                es.CallExpression(
                                    callee=es.Identifier(name='super'),
                                    arguments=[es.Identifier(name='props')]
                                ),
                                jac_node=here
                            )
                        ),
                        jac_node=here
                    )
                );
            }
            constructor_method = self.sync_loc(
                es.MethodDefinition(
                    key=self.sync_loc(es.Identifier(name='constructor'), jac_node=here),
                    value=self.sync_loc(
                        es.FunctionExpression(
                            id=None,
                            params=[props_param],
                            body=self.sync_loc(
                                es.BlockStatement(body=constructor_stmts), jac_node=here
                            )
                        ),
                        jac_node=here
                    ),
                    kind='constructor',
                    `static=False
                ),
                jac_node=here
            );
            body_stmts.insert(0, constructor_method);
        }
    }
    class_body = self.sync_loc(es.ClassBody(body=body_stmts), jac_node=here);
    super_class: (es.Expression | None) = None;
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if here.base_classes {
        base = here.base_classes[0];
        if base.gen.es_ast {
            super_class = cast(es.Expression, base.gen.es_ast);
            (base_ty_known, base_builtin) = _raised_exc_identity(base);
            if isinstance(super_class, es.Identifier) {
                if base_builtin is not None {
                    super_class = self._jac_exc_ref(base_builtin, base);
                } elif (
                    not base_ty_known
                    and JAC_TYPE_REGISTRY.is_exception(super_class.name)
                ) {
                    super_class = self._jac_exc_ref(super_class.name, base);
                }
            }
        }
    }
    class_id = self.sync_loc(
        es.Identifier(name=here.name.sym_name), jac_node=here.name
    );
    class_decl = self.sync_loc(
        es.ClassDeclaration(id=class_id, superClass=super_class, body=class_body),
        jac_node=here
    );
    here.gen.es_ast = class_decl;
}
