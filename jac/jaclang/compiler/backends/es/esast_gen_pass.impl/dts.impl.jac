impl EsastGenPass._emit_boundary_type_stubs(nd: uni.Module) -> list[es.Statement] {
    manifest = nd.gen.interop_manifest;
    if not manifest.boundary_types {
        return [];
    }
    stubs: list[es.Statement] = [];

    osp_class_map: dict[str, es.ClassDeclaration] = {};
    for item in self._merge_module_bodies(nd) {
        if (
            isinstance(item, uni.Archetype)
            and (item.name is not None)
            and isinstance(item.gen.es_ast, es.ClassDeclaration)
        ) {
            osp_class_map[item.name.sym_name] = item.gen.es_ast;
        }
    }
    for info in manifest.boundary_types.values() {
        type_name = self._boundary_type_name(info);
        boundary_types = manifest.boundary_types_for(info.type_scope);
        if info.kind == "enum" {
            enum_props: list[es.Property] = [];
            for (member_name, member_val) in info.enum_members {
                key = es.Identifier(name=member_name);
                val = es.Literal(
                    value=member_val if member_val is not None else member_name
                );
                enum_props.append(
                    es.Property(
                        key=key,
                        value=val,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            obj_expr = es.CallExpression(
                callee=es.MemberExpression(
                    object=es.Identifier(name='Object'),
                    property=es.Identifier(name='freeze'),
                    computed=False
                ),
                arguments=[es.ObjectExpression(properties=enum_props)]
            );
            decl = es.VariableDeclaration(
                declarations=[
                    es.VariableDeclarator(
                        id=es.Identifier(name=type_name), init=obj_expr
                    )
                ],
                kind='const'
            );
            stubs.append(decl);
        } else {
            field_names = [f[0] for f in info.fields];
            field_types = {f[0]: f[1] for f in info.fields};
            ctor_stmts: list[es.Statement] = [];
            for fname in field_names {
                fallback = self._es_json_literal(info.field_defaults[fname])
                    if fname in info.field_defaults
                    else es.Literal(value=None);
                assign = es.ExpressionStatement(
                    expression=es.AssignmentExpression(
                        operator='=',
                        left=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name=fname),
                            computed=False
                        ),
                        right=es.ConditionalExpression(
                            `test=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='Object'),
                                    property=es.Identifier(name='hasOwn'),
                                    computed=False
                                ),
                                arguments=[
                                    es.Identifier(name='props'),
                                    es.Literal(value=fname)
                                ]
                            ),
                            consequent=es.MemberExpression(
                                object=es.Identifier(name='props'),
                                property=es.Identifier(name=fname),
                                computed=False
                            ),
                            alternate=fallback
                        )
                    )
                );
                ctor_stmts.append(assign);
            }
            if info.kind == "node" {
                jac_id_assign = es.ExpressionStatement(
                    expression=es.AssignmentExpression(
                        operator='=',
                        left=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name='_jac_id'),
                            computed=False
                        ),
                        right=es.ConditionalExpression(
                            `test=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='Object'),
                                    property=es.Identifier(name='hasOwn'),
                                    computed=False
                                ),
                                arguments=[
                                    es.Identifier(name='props'),
                                    es.Literal(value='_jac_id')
                                ]
                            ),
                            consequent=es.MemberExpression(
                                object=es.Identifier(name='props'),
                                property=es.Identifier(name='_jac_id'),
                                computed=False
                            ),
                            alternate=es.Literal(value=None)
                        )
                    )
                );
                ctor_stmts.append(jac_id_assign);
            }
            ctor = es.FunctionExpression(
                id=None,
                params=[
                    es.AssignmentPattern(
                        left=es.Identifier(name='props'),
                        right=es.ObjectExpression(properties=[])
                    )
                ],
                body=es.BlockStatement(body=ctor_stmts),
                generator=False,
                async_=False
            );
            ctor_def = es.MethodDefinition(
                key=es.Identifier(name='constructor'),
                value=ctor,
                kind='constructor',
                `static=False,
                computed=False
            );
            from_wire_stmts: list[es.Statement] = [];
            from_wire_stmts.append(
                es.IfStatement(
                    `test=es.LogicalExpression(
                        operator='||',
                        left=es.BinaryExpression(
                            operator='===',
                            left=es.Identifier(name='d'),
                            right=es.Literal(value=None)
                        ),
                        right=es.BinaryExpression(
                            operator='===',
                            left=es.Identifier(name='d'),
                            right=es.Identifier(name='undefined')
                        )
                    ),
                    consequent=es.ReturnStatement(argument=es.Identifier(name='d')),
                    alternate=None
                )
            );
            nested_set = {
                t
                for t in info.nested_types
                if t in boundary_types and boundary_types[t].kind != "enum"
            };
            for fname in field_names {
                ftype = field_types[fname];

                inner_type = None;
                is_list = False;
                is_dict = False;
                if ftype in nested_set {
                    inner_type = ftype;
                } elif ftype.startswith("list[") and ftype.endswith("]") {
                    inner = ftype[5:-1];
                    if inner in nested_set {
                        inner_type = inner;
                        is_list = True;
                    }
                } elif ftype.startswith("dict[") and ftype.endswith("]") {
                    dict_params = ftype[5:-1];
                    comma_pos = dict_params.find(', ');
                    if comma_pos >= 0 {
                        val_type = dict_params[comma_pos + 2:].strip();
                        if val_type in nested_set {
                            inner_type = val_type;
                            is_dict = True;
                        }
                    }
                }
                if inner_type {
                    if is_dict {
                        entries_call = es.CallExpression(
                            callee=es.MemberExpression(
                                object=es.Identifier(name='Object'),
                                property=es.Identifier(name='entries'),
                                computed=False
                            ),
                            arguments=[
                                es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                )
                            ]
                        );
                        map_call = es.CallExpression(
                            callee=es.MemberExpression(
                                object=entries_call,
                                property=es.Identifier(name='map'),
                                computed=False
                            ),
                            arguments=[
                                es.ArrowFunctionExpression(
                                    params=[
                                        es.ArrayPattern(
                                            elements=[
                                                es.Identifier(name='k'),
                                                es.Identifier(name='v')
                                            ]
                                        )
                                    ],
                                    body=es.ArrayExpression(
                                        elements=[
                                            es.Identifier(name='k'),
                                            es.CallExpression(
                                                callee=es.MemberExpression(
                                                    object=es.Identifier(
                                                        name=self._boundary_type_name(
                                                            boundary_types[inner_type]
                                                        )
                                                    ),
                                                    property=es.Identifier(
                                                        name='__from_wire'
                                                    ),
                                                    computed=False
                                                ),
                                                arguments=[es.Identifier(name='v')]
                                            )
                                        ]
                                    ),
                                    expression=True,
                                    async_=False
                                )
                            ]
                        );
                        from_entries_call = es.CallExpression(
                            callee=es.MemberExpression(
                                object=es.Identifier(name='Object'),
                                property=es.Identifier(name='fromEntries'),
                                computed=False
                            ),
                            arguments=[map_call]
                        );
                        from_wire_stmts.append(
                            es.IfStatement(
                                `test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=from_entries_call
                                    )
                                ),
                                alternate=None
                            )
                        );
                    } elif is_list {
                        from_wire_stmts.append(
                            es.IfStatement(
                                `test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.MemberExpression(
                                                    object=es.Identifier(name='d'),
                                                    property=es.Identifier(name=fname),
                                                    computed=False
                                                ),
                                                property=es.Identifier(name='map'),
                                                computed=False
                                            ),
                                            arguments=[
                                                es.ArrowFunctionExpression(
                                                    params=[es.Identifier(name='x')],
                                                    body=es.CallExpression(
                                                        callee=es.MemberExpression(
                                                            object=es.Identifier(
                                                                name=self._boundary_type_name(
                                                                    boundary_types[
                                                                        inner_type
                                                                    ]
                                                                )
                                                            ),
                                                            property=es.Identifier(
                                                                name='__from_wire'
                                                            ),
                                                            computed=False
                                                        ),
                                                        arguments=[
                                                            es.Identifier(name='x')
                                                        ]
                                                    ),
                                                    expression=True,
                                                    async_=False
                                                )
                                            ]
                                        )
                                    )
                                ),
                                alternate=None
                            )
                        );
                    } else {
                        from_wire_stmts.append(
                            es.IfStatement(
                                `test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(
                                                    name=self._boundary_type_name(
                                                        boundary_types[inner_type]
                                                    )
                                                ),
                                                property=es.Identifier(
                                                    name='__from_wire'
                                                ),
                                                computed=False
                                            ),
                                            arguments=[
                                                es.MemberExpression(
                                                    object=es.Identifier(name='d'),
                                                    property=es.Identifier(name=fname),
                                                    computed=False
                                                )
                                            ]
                                        )
                                    )
                                ),
                                alternate=None
                            )
                        );
                    }
                }
            }
            from_wire_stmts.append(
                es.ReturnStatement(
                    argument=es.NewExpression(
                        callee=es.Identifier(name=type_name),
                        arguments=[es.Identifier(name='d')]
                    )
                )
            );
            from_wire_fn = es.FunctionExpression(
                id=None,
                params=[es.Identifier(name='d')],
                body=es.BlockStatement(body=from_wire_stmts),
                generator=False,
                async_=False
            );
            from_wire_def = es.MethodDefinition(
                key=es.Identifier(name='__from_wire'),
                value=from_wire_fn,
                kind='method',
                `static=True,
                computed=False
            );
            to_wire_props: list[es.Property] = [];
            to_wire_props.append(
                es.Property(
                    key=es.Literal(value='__type__'),
                    value=es.Literal(value=info.name),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                )
            );
            to_wire_props.append(
                es.Property(
                    key=es.Literal(value='_jac_type_id'),
                    value=es.Literal(value=info.type_id),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                )
            );
            for fname in field_names {
                ftype = field_types[fname];
                value_expr: es.Expression = es.MemberExpression(
                    object=es.ThisExpression(),
                    property=es.Identifier(name=fname),
                    computed=False
                );

                if ftype in nested_set {
                    value_expr = es.ConditionalExpression(
                        `test=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name=fname),
                            computed=False
                        ),
                        consequent=es.CallExpression(
                            callee=es.MemberExpression(
                                object=value_expr,
                                property=es.Identifier(name='__to_wire'),
                                computed=False
                            ),
                            arguments=[]
                        ),
                        alternate=es.Literal(value=None)
                    );
                } elif ftype.startswith("list[") and ftype.endswith("]") {
                    inner = ftype[5:-1];
                    if inner in nested_set {
                        value_expr = es.ConditionalExpression(
                            `test=es.MemberExpression(
                                object=es.ThisExpression(),
                                property=es.Identifier(name=fname),
                                computed=False
                            ),
                            consequent=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.MemberExpression(
                                        object=es.ThisExpression(),
                                        property=es.Identifier(name=fname),
                                        computed=False
                                    ),
                                    property=es.Identifier(name='map'),
                                    computed=False
                                ),
                                arguments=[
                                    es.ArrowFunctionExpression(
                                        params=[es.Identifier(name='x')],
                                        body=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name='x'),
                                                property=es.Identifier(
                                                    name='__to_wire'
                                                ),
                                                computed=False
                                            ),
                                            arguments=[]
                                        ),
                                        expression=True,
                                        async_=False
                                    )
                                ]
                            ),
                            alternate=es.ArrayExpression(elements=[])
                        );
                    }
                } elif ftype.startswith("dict[") and ftype.endswith("]") {
                    dict_params = ftype[5:-1];
                    comma_pos = dict_params.find(', ');
                    if comma_pos >= 0 {
                        val_type = dict_params[comma_pos + 2:].strip();
                        if val_type in nested_set {
                            this_field = es.MemberExpression(
                                object=es.ThisExpression(),
                                property=es.Identifier(name=fname),
                                computed=False
                            );
                            entries_call = es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='Object'),
                                    property=es.Identifier(name='entries'),
                                    computed=False
                                ),
                                arguments=[this_field]
                            );
                            map_call = es.CallExpression(
                                callee=es.MemberExpression(
                                    object=entries_call,
                                    property=es.Identifier(name='map'),
                                    computed=False
                                ),
                                arguments=[
                                    es.ArrowFunctionExpression(
                                        params=[
                                            es.ArrayPattern(
                                                elements=[
                                                    es.Identifier(name='k'),
                                                    es.Identifier(name='v')
                                                ]
                                            )
                                        ],
                                        body=es.ArrayExpression(
                                            elements=[
                                                es.Identifier(name='k'),
                                                es.CallExpression(
                                                    callee=es.MemberExpression(
                                                        object=es.Identifier(name='v'),
                                                        property=es.Identifier(
                                                            name='__to_wire'
                                                        ),
                                                        computed=False
                                                    ),
                                                    arguments=[]
                                                )
                                            ]
                                        ),
                                        expression=True,
                                        async_=False
                                    )
                                ]
                            );
                            value_expr = es.ConditionalExpression(
                                `test=es.MemberExpression(
                                    object=es.ThisExpression(),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.CallExpression(
                                    callee=es.MemberExpression(
                                        object=es.Identifier(name='Object'),
                                        property=es.Identifier(name='fromEntries'),
                                        computed=False
                                    ),
                                    arguments=[map_call]
                                ),
                                alternate=es.ObjectExpression(properties=[])
                            );
                        }
                    }
                }
                to_wire_props.append(
                    es.Property(
                        key=es.Literal(value=fname),
                        value=value_expr,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            if info.kind == "node" {
                to_wire_props.append(
                    es.Property(
                        key=es.Literal(value='_jac_id'),
                        value=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name='_jac_id'),
                            computed=False
                        ),
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            to_wire_fn = es.FunctionExpression(
                id=None,
                params=[],
                body=es.BlockStatement(
                    body=[
                        es.ReturnStatement(
                            argument=es.ObjectExpression(properties=to_wire_props)
                        )
                    ]
                ),
                generator=False,
                async_=False
            );
            to_wire_def = es.MethodDefinition(
                key=es.Identifier(name='__to_wire'),
                value=to_wire_fn,
                kind='method',
                `static=False,
                computed=False
            );
            osp_class = osp_class_map.get(info.name)
                if info.type_scope == nd.loc.mod_path
                else None;
            if osp_class is not None {
                if info.kind == "node" {
                    for member in osp_class.body.body {
                        if (
                            isinstance(member, es.MethodDefinition)
                            and (member.kind == "constructor")
                        ) {
                            member.value.body.body.append(
                                es.IfStatement(
                                    `test=es.CallExpression(
                                        callee=es.MemberExpression(
                                            object=es.Identifier(name='Object'),
                                            property=es.Identifier(name='hasOwn'),
                                            computed=False
                                        ),
                                        arguments=[
                                            es.Identifier(name='props'),
                                            es.Literal(value='_jac_id')
                                        ]
                                    ),
                                    consequent=es.ExpressionStatement(
                                        expression=es.AssignmentExpression(
                                            operator='=',
                                            left=es.MemberExpression(
                                                object=es.ThisExpression(),
                                                property=es.Identifier(name='_jac_id'),
                                                computed=False
                                            ),
                                            right=es.MemberExpression(
                                                object=es.Identifier(name='props'),
                                                property=es.Identifier(name='_jac_id'),
                                                computed=False
                                            )
                                        )
                                    ),
                                    alternate=None
                                )
                            );
                        }
                    }
                }
                osp_class.body.body.append(from_wire_def);
                osp_class.body.body.append(to_wire_def);
            } else {
                class_body = es.ClassBody(body=[ctor_def, from_wire_def, to_wire_def]);
                class_decl = es.ClassDeclaration(
                    id=es.Identifier(name=type_name), superClass=None, body=class_body
                );
                stubs.append(class_decl);
            }
        }
    }
    for (local_name, binding) in manifest.bindings.items() {
        if binding.kind != 'type' {
            continue;
        }
        info = manifest.boundary_types_for(binding.type_scope).get(binding.ret_type);
        if info is None {
            continue;
        }
        type_name = self._boundary_type_name(info);
        if local_name != type_name {
            stubs.append(
                es.VariableDeclaration(
                    declarations=[
                        es.VariableDeclarator(
                            id=es.Identifier(name=local_name),
                            init=es.Identifier(name=type_name)
                        )
                    ],
                    kind='const'
                )
            );
        }
    }
    return stubs;
}

impl EsastGenPass._boundary_type_name(info: BoundaryTypeInfo) -> str {
    manifest = self.ir_in.gen.interop_manifest;
    if info.type_scope == self.ir_in.loc.mod_path {
        return info.name;
    }
    matches = [
        t
        for t in manifest.boundary_types.values()
        if t.name == info.name
    ];
    binding = manifest.bindings.get(info.name);
    bound_type = manifest.boundary_types_for(binding.type_scope).get(binding.ret_type)
        if binding is not None and binding.kind == 'type'
        else None;
    if len(matches) == 1 and (binding is None or bound_type == info) {
        return info.name;
    }
    index = list(manifest.boundary_types).index(info.type_id);
    return f"__jac_boundary_{index}_{info.name}";
}
