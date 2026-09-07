import from jaclang.compiler.tools.unparse_pass { unparse_node }
import from jaclang.compiler.symbol_utils { return_type_is_jsx }

impl EsastGenPass._resolve_source_module(nd: uni.Import) -> (uni.Module | None) {
    import from jaclang.compiler.symbol_utils { resolve_import_source_module }
    return resolve_import_source_module(self.prog, nd);
}

impl EsastGenPass._record_sv_backend(nd: uni.Import) -> None {
    import from pathlib { Path }
    import from jaclang.compiler.driver.boundary_classify {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    if not nd.from_loc {
        return;
    }
    resolved_path = nd.from_loc.resolve_relative_path();
    if not resolved_path {
        return;
    }
    abs_path = str(Path(resolved_path).resolve());
    if abs_path.endswith(".jac") and Path(abs_path).exists() {
        if abs_path not in self.client_manifest.server_imports {
            self.client_manifest.server_imports.append(abs_path);
        }
        if import_crosses_apps(nd) {
            self.client_manifest.server_import_routes[abs_path] = {
                "app": import_provider_app(nd) or '',
                "route": import_provider_route(nd)
            };
        }
    }
}

impl EsastGenPass._is_service_bridge_import(nd: uni.Import) -> bool {
    import from jaclang.compiler.driver.boundary_classify {
        CrossAppKind,
        classify_cross_app_import
    }
    return (
        classify_cross_app_import(nd, self.ir_in.gen.interop_manifest)
        == CrossAppKind.SERVICE_BRIDGE
    );
}

impl EsastGenPass._sv_provider_options(nd: uni.Import) -> (es.Expression | None) {
    import from jaclang.compiler.driver.boundary_classify {
        import_crosses_apps,
        import_provider_app,
        import_provider_route
    }
    if not import_crosses_apps(nd) {
        return None;
    }
    provider_app = import_provider_app(nd) or '';
    provider_route = import_provider_route(nd);
    if not provider_app {
        return None;
    }
    props: list[es.Property | es.SpreadElement] = [];
    for (key, value) in [("app", provider_app), ("route", provider_route)] {
        props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Literal(value=key), jac_node=nd),
                    value=self.sync_loc(es.Literal(value=value), jac_node=nd),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=nd
            )
        );
    }
    return self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);
}

impl EsastGenPass._resolve_call_ability(nd: uni.FuncCall) -> (uni.Ability | None) {
    import from jaclang.compiler.symbol_utils { ability_of_symbol }

    if nd.callee_decl is not None {
        return nd.callee_decl;
    }
    if isinstance(nd.target, uni.Name) {
        ability_node = ability_of_symbol(nd.target.sym);
        if ability_node {
            return ability_node;
        }

        manifest = self.ir_in.gen.interop_manifest;
        binding = manifest.bindings.get(nd.target.sym_name) if manifest else None;
        if binding and isinstance(binding.ast_node, uni.Ability) {
            return binding.ast_node;
        }
        return None;
    }
    if isinstance(nd.target, uni.AtomTrailer)
        and isinstance(nd.target.right, uni.Name) {
        return ability_of_symbol(nd.target.right.sym);
    }
    return None;
}

impl EsastGenPass._return_type_route_role(rt: uni.Expr) -> (str | None) {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR
    ) {
        left_role = self._return_type_route_role(rt.left);
        return left_role or self._return_type_route_role(rt.right);
    }
    if isinstance(rt, uni.Name) {
        if rt.value == 'JsxPage' {
            return 'page';
        }
        if rt.value == 'JsxLayout' {
            return 'layout';
        }
    }
    return None;
}

impl EsastGenPass._component_pascal_name(nd: uni.Ability) -> (str | None) {
    if nd.code_context != CodeContext.CLIENT or nd.is_method {
        return None;
    }
    if not isinstance(nd.signature, uni.FuncSignature) {
        return None;
    }
    rt = nd.signature.return_type;
    if not return_type_is_jsx(rt) {
        return None;
    }
    name = nd.name_ref.sym_name;
    if not name or not ('a' <= name[0] and name[0] <= 'z') {
        return None;
    }
    pascal = name[0].upper() + name[1:];
    mod = nd.find_parent_of_type(uni.Module);
    if mod is not None and mod.lookup(pascal, deep=False) is not None {
        return None;
    }
    return pascal;
}

impl EsastGenPass._component_call_abi(ability_node: uni.Ability) -> str {
    cached_abi = ability_node.gen?.component_call_abi;
    if isinstance(cached_abi, str) and cached_abi {
        return cached_abi;
    }
    abi = 'direct';
    if isinstance(ability_node.signature, uni.FuncSignature) {
        sig = ability_node.signature;
        if sig.get_parameters() {
            rt = sig.return_type;

            if return_type_is_jsx(rt) {
                if (
                    ability_node.name_ref
                    and ability_node.name_ref.sym_name
                    and ability_node.name_ref.sym_name.startswith('__jac')
                ) {
                    abi = 'direct';
                } else {
                    all_pos_params = self._pos_params_from_ability(ability_node);
                    if (
                        len(all_pos_params) == 1
                        and all_pos_params[0].name.sym_name == 'props'
                    ) {
                        abi = 'props_passthrough';
                    } else {
                        abi = 'props_destructure';
                    }
                }
            }
        }
    }
    ability_node.gen.component_call_abi = abi;
    return abi;
}

impl EsastGenPass._build_props_spread_component_call(
    nd: uni.FuncCall,
    callee_expr: es.Expression,
    ability_node: uni.Ability,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)]
) -> es.Expression {
    param_names = self._param_names_from_ability(ability_node);
    packed_args = self.sync_loc(es.ArrayExpression(elements=args), jac_node=nd);
    packed_kwargs = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);
    args_id = self.sync_loc(es.Identifier(name='__jac_args'), jac_node=nd);
    kwargs_id = self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd);
    wrap_props: list[es.Property] = [];
    for (i, pname) in enumerate(param_names) {
        len_expr = self.sync_loc(
            es.MemberExpression(
                object=args_id, property=es.Identifier(name='length'), computed=False
            ),
            jac_node=nd
        );
        pos_exists = self.sync_loc(
            es.BinaryExpression(
                operator='>',
                left=len_expr,
                right=self.sync_loc(es.Literal(value=i), jac_node=nd)
            ),
            jac_node=nd
        );
        pos_value = self.sync_loc(
            es.MemberExpression(
                object=args_id,
                property=self.sync_loc(es.Literal(value=i), jac_node=nd),
                computed=True
            ),
            jac_node=nd
        );
        kw_value = self.sync_loc(
            es.MemberExpression(
                object=kwargs_id,
                property=self.sync_loc(es.Literal(value=pname), jac_node=nd),
                computed=True
            ),
            jac_node=nd
        );
        wrap_props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Identifier(name=pname), jac_node=nd),
                    value=self.sync_loc(
                        es.ConditionalExpression(
                            `test=pos_exists, consequent=pos_value, alternate=kw_value
                        ),
                        jac_node=nd
                    ),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=nd
            )
        );
    }
    inner_call = self.sync_loc(
        es.CallExpression(
            callee=callee_expr,
            arguments=[
                self.sync_loc(es.ObjectExpression(properties=wrap_props), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[args_id, kwargs_id],
                    body=inner_call,
                    expression=True,
                    async_=False
                ),
                jac_node=nd
            ),
            arguments=[packed_args, packed_kwargs]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._pos_params_from_ability(
    ability_node: uni.Ability
) -> list[uni.ParamVar] {
    sig = ability_node.signature;
    return (sig.posonly_params or []) + (sig.params or []);
}

impl EsastGenPass._param_names_from_ability(ability_node: uni.Ability) -> list[str] {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return [];
    }
    sig = ability_node.signature;
    names: list[str] = [];
    for p in self._pos_params_from_ability(ability_node) {
        names.append(p.name.sym_name);
    }
    for p in sig.kwonlyargs {
        names.append(p.name.sym_name);
    }
    return names;
}

impl EsastGenPass._param_type_map_from_ability(
    ability_node: uni.Ability
) -> dict[(str, str)] {
    type_map: dict[(str, str)] = {};
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return type_map;
    }
    sig = ability_node.signature;
    param_lists = [sig.posonly_params, sig.params or [], sig.kwonlyargs];
    for params in param_lists {
        for p in params {
            if (
                p.type_tag and p.type_tag.tag and isinstance(p.type_tag.tag, uni.Name)
            ) {
                type_map[p.name.sym_name] = p.type_tag.tag.value;
            }
        }
    }
    return type_map;
}

impl EsastGenPass._extract_return_type(
    ability_node: uni.Ability, func_name: str, manifest: any
) -> str {
    if manifest {
        for b in manifest.server_exports_to_client {
            if b.name == func_name {
                return b.ret_type;
            }
        }
    }
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return '';
    }
    rt = ability_node.signature.return_type;
    if rt is None {
        return '';
    }
    if isinstance(rt, uni.Name) {
        return rt.value;
    }
    if isinstance(rt, uni.AtomTrailer) and isinstance(rt.target, uni.Name) {
        base = rt.target.value;
        if rt.right and isinstance(rt.right, uni.Name) {
            return f"{base}[{rt.right.value}]";
        }
        return base;
    }
    return '';
}

impl EsastGenPass._wrap_return_with_boundary(
    call_expr: es.Expression,
    ret_type: str,
    boundary_types: dict[(str, any)],
    jac_node: uni.UniNode,
    pre_awaited: bool
) -> es.Expression {
    awaited_call = call_expr
        if pre_awaited
        else self.sync_loc(es.AwaitExpression(argument=call_expr), jac_node=jac_node);

    if (ret_type in boundary_types and boundary_types[ret_type].kind != "enum") {
        return self.sync_loc(
            es.CallExpression(
                callee=es.MemberExpression(
                    object=es.Identifier(name=ret_type),
                    property=es.Identifier(name='__from_wire'),
                    computed=False
                ),
                arguments=[awaited_call]
            ),
            jac_node=jac_node
        );
    }

    if ret_type.startswith("list[") and ret_type.endswith("]") {
        inner = ret_type[5:-1];
        if inner in boundary_types and boundary_types[inner].kind != "enum" {
            return self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=awaited_call,
                        property=es.Identifier(name='map'),
                        computed=False
                    ),
                    arguments=[
                        es.ArrowFunctionExpression(
                            params=[es.Identifier(name='x')],
                            body=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name=inner),
                                    property=es.Identifier(name='__from_wire'),
                                    computed=False
                                ),
                                arguments=[es.Identifier(name='x')]
                            ),
                            expression=True,
                            async_=False
                        )
                    ]
                ),
                jac_node=jac_node
            );
        }
    }

    if ret_type.startswith("dict[") and ret_type.endswith("]") {
        dict_params = ret_type[5:-1];
        comma_pos = dict_params.find(', ');
        if comma_pos >= 0 {
            val_type = dict_params[comma_pos + 2:].strip();
            if (
                val_type in boundary_types and boundary_types[val_type].kind != "enum"
            ) {
                entries_call = es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Object'),
                        property=es.Identifier(name='entries'),
                        computed=False
                    ),
                    arguments=[awaited_call]
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
                                            object=es.Identifier(name=val_type),
                                            property=es.Identifier(name='__from_wire'),
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
                return self.sync_loc(
                    es.CallExpression(
                        callee=es.MemberExpression(
                            object=es.Identifier(name='Object'),
                            property=es.Identifier(name='fromEntries'),
                            computed=False
                        ),
                        arguments=[map_call]
                    ),
                    jac_node=jac_node
                );
            }
        }
    }

    return call_expr;
}

impl EsastGenPass._wrap_to_wire_if_boundary(
    expr: es.Expression,
    type_name: str,
    boundary_types: dict[(str, any)],
    jac_node: uni.UniNode
) -> es.Expression {
    if (type_name in boundary_types and boundary_types[type_name].kind != "enum") {
        return self.sync_loc(
            es.CallExpression(
                callee=es.MemberExpression(
                    object=expr,
                    property=es.Identifier(name='__to_wire'),
                    computed=False
                ),
                arguments=[]
            ),
            jac_node=jac_node
        );
    }
    return expr;
}

impl EsastGenPass._resolve_call_arg_slots(
    nd: uni.FuncCall,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)],
    param_names: list[str],
    func_name: str,
    spread_read_source: (es.Expression | None)
) -> list[CallArgSlot] {
    by_name: dict[str, (es.Expression | es.SpreadElement)] = {};
    extras: list[CallArgSlot] = [];
    spread_sources: list[es.Expression] = [];
    seen_names: set[str] = set();
    for (i, arg) in enumerate(args) {
        if isinstance(arg, es.SpreadElement) {
            extras.append(CallArgSlot(name=None, value=arg));
            continue;
        }
        if i < len(param_names) {
            pname = param_names[i];
            seen_names.add(pname);
            by_name[pname] = arg;
        } else {
            extras.append(CallArgSlot(name=None, value=arg));
        }
    }
    for kw in props {
        if isinstance(kw, es.SpreadElement) {
            spread_sources.append(kw.argument);
            continue;
        }
        kw_key = kw.key;
        kw_name = '';
        if isinstance(kw_key, es.Identifier) {
            kw_name = kw_key.name;
        } elif isinstance(kw_key, es.Literal) {
            kw_name = str(kw_key.value);
        }
        if not kw_name {
            self.emit(
                E5099, node_override=nd, func=func_name, shape=type(kw_key).__name__
            );
            continue;
        }
        if kw_name in seen_names {
            self.emit(E5080, node_override=nd, name=kw_name, func=func_name);
        }
        seen_names.add(kw_name);
        by_name[kw_name] = kw.value;
    }
    resolved: list[CallArgSlot] = [];
    for pname in param_names {
        if pname in by_name {
            resolved.append(CallArgSlot(name=pname, value=by_name[pname]));
        } elif spread_sources {
            spread_source = spread_read_source;
            if spread_source is None {
                spread_source = spread_sources[0]
                    if len(spread_sources) == 1
                    else self.sync_loc(
                        es.ObjectExpression(
                            properties=[
                                self.sync_loc(
                                    es.SpreadElement(argument=src), jac_node=nd
                                ) for src in spread_sources
                            ]
                        ),
                        jac_node=nd
                    );
            }
            resolved.append(
                CallArgSlot(
                    name=pname,
                    value=self.sync_loc(
                        es.MemberExpression(
                            object=spread_source,
                            property=self.sync_loc(
                                es.Literal(value=pname), jac_node=nd
                            ),
                            computed=True
                        ),
                        jac_node=nd
                    )
                )
            );
        } else {
            resolved.append(CallArgSlot(name=pname, value=None));
        }
    }
    resolved.extend(extras);
    return resolved;
}

impl EsastGenPass._call_args_from_slots(
    slots: list[CallArgSlot]
) -> (list[(es.Expression | es.SpreadElement)] | None) {
    call_args: list[(es.Expression | es.SpreadElement)] = [];
    last_value_idx = -1;
    for (i, slot) in enumerate(slots) {
        if slot.value is not None {
            last_value_idx = i;
        }
    }
    if last_value_idx < 0 {
        return [];
    }
    for (i, slot) in enumerate(slots) {
        if i > last_value_idx {
            break;
        }
        if slot.value is None {
            call_args.append(es.Identifier(name='undefined'));
            continue;
        }
        if slot.name is None {
            call_args.append(slot.value);
            continue;
        }
        call_args.append(slot.value);
    }
    return call_args;
}

impl EsastGenPass._kwargs_spread_arg(
    props: list[(es.Property | es.SpreadElement)], nd: uni.FuncCall
) -> (es.Expression | None) {
    sources: list[es.Expression] = [];
    for prop in props {
        if isinstance(prop, es.SpreadElement) {
            sources.append(prop.argument);
        }
    }
    if not sources {
        return None;
    }
    if len(sources) == 1 {
        return sources[0];
    }
    return self.sync_loc(
        es.ObjectExpression(
            properties=[
                self.sync_loc(es.SpreadElement(argument=src), jac_node=nd)
                for src in sources
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._kwargs_spread_needs_temp(
    props: list[(es.Property | es.SpreadElement)]
) -> bool {
    sources: list[es.Expression] = [];
    for prop in props {
        if isinstance(prop, es.SpreadElement) {
            sources.append(prop.argument);
        }
    }
    if len(sources) > 1 {
        return True;
    }
    if len(sources) == 1 and not isinstance(sources[0], es.Identifier) {
        return True;
    }
    return False;
}

impl EsastGenPass._make_kwargs_spread_context(
    props: list[(es.Property | es.SpreadElement)], nd: uni.FuncCall
) -> tuple[((es.Expression | None), (es.Expression | None))] {
    spread_arg = self._kwargs_spread_arg(props, nd);
    if spread_arg is None {
        return (None, None);
    }
    if self._kwargs_spread_needs_temp(props) {
        return (
            spread_arg,
            self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd)
        );
    }
    return (spread_arg, None);
}

impl EsastGenPass._wrap_with_kwargs_temp(
    expr: es.Expression, spread_arg: es.Expression, nd: uni.FuncCall
) -> es.Expression {
    temp_id = self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd);
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[temp_id], body=expr, expression=True, async_=False
                ),
                jac_node=nd
            ),
            arguments=[spread_arg]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._try_lower_server_rpc_call(
    nd: uni.FuncCall,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)]
) -> (es.Expression | None) {
    if not (nd.in_client_context() and isinstance(nd.target, uni.Name)) {
        return None;
    }
    ability_node = self._resolve_call_ability(nd);
    if not ability_node {
        return None;
    }
    is_server_func = (
        ability_node.code_context != CodeContext.CLIENT
        and ability_node.code_context != CodeContext.NATIVE
        and not ability_node.in_client_context()
        and ability_node.access is not None
        and ability_node.access.tag.name == Tok.KW_PUB
    );
    if not is_server_func {
        return None;
    }
    func_name = nd.target.sym_name;
    self._warn_rpc_callable_params(ability_node, func_name, nd);

    param_names: list[str] = self._param_names_from_ability(ability_node);
    inline_param_type_map: dict[str, str] = self._param_type_map_from_ability(
        ability_node
    );
    inline_ret_type: str = self._extract_return_type(
        ability_node, func_name, self.ir_in.gen.interop_manifest
    );
    inline_boundary = self.ir_in.gen.interop_manifest.boundary_types
        if self.ir_in.gen.interop_manifest
        else {};
    (spread_arg, spread_read_source) = self._make_kwargs_spread_context(props, nd);
    use_kwargs_temp = spread_read_source is not None;
    slots = self._resolve_call_arg_slots(
        nd, args, props, param_names, func_name, spread_read_source
    );
    rpc_props: list[(es.Property | es.SpreadElement)] = [];
    for slot in slots {
        if slot.value is None {
            continue;
        }
        if slot.name is None {
            rpc_props.append(slot.value);
            continue;
        }
        named_value = self._wrap_to_wire_if_boundary(
            cast(es.Expression, slot.value),
            inline_param_type_map.get(slot.name, ''),
            inline_boundary,
            nd
        );
        rpc_props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Literal(value=slot.name), jac_node=nd),
                    value=named_value,
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=nd
            )
        );
    }
    args_obj: es.Expression = self.sync_loc(
        es.ObjectExpression(properties=rpc_props), jac_node=nd
    );
    if use_kwargs_temp and spread_arg is not None {
        args_obj = self._wrap_with_kwargs_temp(args_obj, spread_arg, nd);
    }

    result_expr: es.Expression = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__jacCallFunction'), jac_node=nd),
            arguments=[
                self.sync_loc(es.Literal(value=func_name), jac_node=nd),
                args_obj
            ]
        ),
        jac_node=nd
    );
    result_expr = self._wrap_return_with_boundary(
        result_expr, inline_ret_type, inline_boundary, nd, pre_awaited=False
    );
    self._inject_runtime_import('__jacCallFunction', nd);
    return result_expr;
}

impl EsastGenPass._warn_rpc_callable_params(
    ability_node: uni.Ability, func_name: str, at: uni.UniNode
) -> None {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return;
    }
    import re;
    import from jaclang.compiler.frontend.diagnostics { W6005 }
    _sig = ability_node.signature;
    for _plist in [_sig.posonly_params, _sig.params or [], _sig.kwonlyargs] {
        for _p in _plist {
            if (
                _p.type_tag is not None
                and _p.type_tag.tag is not None
                and re.search(r"\bCallable\b", unparse_node(_p.type_tag.tag))
            ) {
                self.emit(
                    W6005, node_override=at, func=func_name, param=_p.name.sym_name
                );
            }
        }
    }
}

impl EsastGenPass._forwarder_ret_label(ability_node: uni.Ability) -> str {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return '';
    }
    rt = ability_node.signature.return_type;
    if rt is None {
        return '';
    }
    label = unparse_node(rt).strip();
    return '' if label in ('', 'None') else label;
}

impl EsastGenPass._build_server_forwarder(
    ability_node: uni.Ability, func_name: str, jac_node: uni.UniNode
) -> es.FunctionDeclaration {
    self._warn_rpc_callable_params(ability_node, func_name, jac_node);
    boundary = self.ir_in.gen.interop_manifest.boundary_types
        if self.ir_in.gen.interop_manifest
        else {};
    param_types = self._param_type_map_from_ability(ability_node);
    ret_type = self._extract_return_type(
        ability_node, func_name, self.ir_in.gen.interop_manifest
    );
    params: list[es.Pattern] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for pname in self._param_names_from_ability(ability_node) {
        params.append(self.sync_loc(es.Identifier(name=pname), jac_node=jac_node));
        props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Literal(value=pname), jac_node=jac_node),
                    value=self._wrap_to_wire_if_boundary(
                        self.sync_loc(es.Identifier(name=pname), jac_node=jac_node),
                        param_types.get(pname, ''),
                        boundary,
                        jac_node
                    ),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=jac_node
            )
        );
    }
    call_expr: es.Expression = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.Identifier(name='__jacCallFunction'), jac_node=jac_node
            ),
            arguments=[
                self.sync_loc(es.Literal(value=func_name), jac_node=jac_node),
                self.sync_loc(es.ObjectExpression(properties=props), jac_node=jac_node)
            ]
        ),
        jac_node=jac_node
    );
    call_expr = self._wrap_return_with_boundary(
        call_expr, ret_type, boundary, jac_node, pre_awaited=False
    );
    self._inject_runtime_import('__jacCallFunction', jac_node);
    ret_label = self._forwarder_ret_label(ability_node);
    if ret_label {
        import from jaclang.compiler.frontend.diagnostics { W6009 }
        self.emit(W6009, node_override=jac_node, name=func_name, ret=ret_label);
    }
    return self.sync_loc(
        es.FunctionDeclaration(
            id=self.sync_loc(es.Identifier(name=func_name), jac_node=jac_node),
            params=params,
            body=self.sync_loc(
                es.BlockStatement(
                    body=[
                        self.sync_loc(
                            es.ReturnStatement(argument=call_expr), jac_node=jac_node
                        )
                    ]
                ),
                jac_node=jac_node
            ),
            async_=True
        ),
        jac_node=jac_node
    );
}

impl EsastGenPass._bind_client_value_refs(nd: uni.Module) -> list[es.Statement] {
    import from jaclang.compiler.symbol_utils {
        client_bridged_endpoint,
        client_value_ref_targets,
        element_display_name
    }
    forwarders: list[es.Statement] = [];
    bound: set[str] = set();
    for (ref_name, top) in client_value_ref_targets(nd, self.shared_arch_names) {
        if (isinstance(top, uni.Ability) and client_bridged_endpoint(nd, top)) {
            func_name = element_display_name(top);
            if func_name in bound {
                continue;
            }
            bound.add(func_name);
            forwarders.append(self._build_server_forwarder(top, func_name, ref_name));
            continue;
        }
        self._unbound_reported.add(ref_name.sym_name);
        self.emit(E5086, node_override=ref_name, name=ref_name.sym_name);
    }
    return forwarders;
}

impl EsastGenPass.exit_func_call with uni.FuncCall exit {
    place_op = self._lower_place_builtin(here);
    if place_op is not None {
        here.gen.es_ast = place_op;
        return;
    }
    if (
        (here.callee_decl is not None and here.callee_decl.is_comptime)
        or (isinstance(here.target, uni.Name) and self._ct_only_name(here.target))
    ) {
        folded = self._ct_es_expr(here.ct_value, here);
        if folded is not None {
            here.gen.es_ast = folded;
            return;
        }
    }
    args: list[(es.Expression | es.SpreadElement)] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for param in here.params {
        if isinstance(param, uni.KWPair) {
            value_expr = cast(
                es.Expression,
                param.value.gen.es_ast
                    if (param.value and param.value.gen.es_ast)
                    else self.sync_loc(es.Literal(value=None), jac_node=param)
            );

            if not param.key {
                props.append(
                    self.sync_loc(es.SpreadElement(argument=value_expr), jac_node=param)
                );
                continue;
            }
            key_expr = cast(
                es.Expression,
                self.sync_loc(
                    es.Identifier(name=param.key.sym_name), jac_node=param.key
                )
            );
            props.append(
                self.sync_loc(
                    es.Property(
                        key=key_expr,
                        value=value_expr,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    ),
                    jac_node=param
                )
            );
            continue;
        }
        if (isinstance(param, uni.UnaryExpr) and param.op.name == Tok.STAR_MUL.value) {
            spread_arg = cast(
                es.Expression,
                param.operand.gen.es_ast
                    if (param.operand and param.operand.gen.es_ast)
                    else self.sync_loc(es.Identifier(name='undefined'), jac_node=param)
            );
            args.append(
                self.sync_loc(es.SpreadElement(argument=spread_arg), jac_node=param)
            );
            continue;
        }
        if param.gen.es_ast {
            args.append(cast(es.Expression, param.gen.es_ast));
        }
    }

    for (ct_name, ct_expr) in (self._ct_ctor_slots(here.target) or []) {
        if ct_expr.gen.es_ast {
            props.append(
                self.sync_loc(
                    es.Property(
                        key=es.Identifier(name=ct_name),
                        value=cast(es.Expression, ct_expr.gen.es_ast),
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    ),
                    jac_node=ct_expr
                )
            );
        }
    }
    server_call = self._try_lower_server_rpc_call(here, args, props);
    if server_call is not None {
        here.gen.es_ast = server_call;
        return;
    }
    callee = here.target.gen.es_ast
        or self.sync_loc(es.Identifier(name='func'), jac_node=here.target);

    if (
        isinstance(callee, es.MemberExpression)
        and isinstance(callee.property, es.Identifier)
        and isinstance(here.target, uni.AtomTrailer)
    ) {
        import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }

        _obj_type = here.target.target?.type;
        _type_name = self._resolve_primitive_type_name(_obj_type);
        _method_name = callee.property.name;
        if _type_name {
            _emitter = self._primitive_emitters.get(_type_name);
            _emit_fn_name = "emit_" + _method_name;
            _emit_fn = getattr(_emitter, _emit_fn_name, None) if _emitter else None;
            if _emit_fn {
                _unparser = JSCodeGenerator();
                _ctx = self._primitives_es_mod.ESEmitCtx(unparser=_unparser);
                _target_str = _unparser.generate(callee.object);
                _args_strs: list[str] = [];
                for _a in args {
                    _args_strs.append(_unparser.generate(_a));
                }

                for _p in props {
                    if isinstance(_p, es.Property) and _p.value {
                        _args_strs.append(_unparser.generate(_p.value));
                    }
                }

                import inspect;
                _n_params = len(inspect.signature(_emit_fn).parameters);
                if _n_params == 2 {
                    _result = _emit_fn(_ctx, _args_strs);
                } else {
                    _result = _emit_fn(_ctx, _target_str, _args_strs);
                }
                if _result is not None and "_jac." in str(_result) {
                    self.needs_jac_runtime = True;
                }
                here.gen.es_ast = self.sync_loc(
                    es.RawCode(code=_result), jac_node=here
                );
                return;
            }
        }

        if self._poly_methods is not None and (_method_name in self._poly_methods) {
            _poly_args: list[(es.Expression | es.SpreadElement)] = [
                cast(es.Expression, callee.object),
                self.sync_loc(es.Literal(value=_method_name), jac_node=here)
            ];
            for _a in args {
                _poly_args.append(_a);
            }

            for _p in props {
                if isinstance(_p, es.Property) and _p.value {
                    _poly_args.append(cast(es.Expression, _p.value));
                }
            }
            _poly_callee = es.MemberExpression(
                object=es.MemberExpression(
                    object=es.Identifier(name='_jac'),
                    property=es.Identifier(name='poly'),
                    computed=False
                ),
                property=es.Identifier(name='call'),
                computed=False
            );
            self.needs_jac_runtime = True;
            here.gen.es_ast = self.sync_loc(
                es.CallExpression(
                    callee=cast(es.Expression, _poly_callee), arguments=_poly_args
                ),
                jac_node=here
            );
            return;
        }
    }

    self._ensure_emitters();

    _call_kind = here.call_kind;
    if _call_kind == "builtin" and isinstance(here.target, uni.Name) {
        import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }
        import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
        _builtin_name = here.target.sym_name;
        _emit_fn_name = "emit_" + _builtin_name;
        _emit_fn = getattr(self._builtin_emitter, _emit_fn_name, None);
        _sized_cast = _emit_fn is None and JAC_TYPE_REGISTRY.is_sized(_builtin_name);
        if _emit_fn or _sized_cast {
            _unparser = JSCodeGenerator();
            _arg_type_names: list[str] = [
                self._expr_type_name(_p)
                for _p in here.params
                if not isinstance(_p, uni.KWPair)
            ];
            _ctx = self._primitives_es_mod.ESEmitCtx(
                unparser=_unparser, arg_type_names=_arg_type_names
            );
            _args_strs: list[str] = [];
            for _a in args {
                _args_strs.append(_unparser.generate(_a));
            }

            for _p in props {
                if isinstance(_p, es.Property) and _p.value {
                    _args_strs.append(_unparser.generate(_p.value));
                }
            }

            _result = None;
            try {
                if _sized_cast {
                    _result = self._builtin_emitter.emit_sized_cast(
                        _builtin_name, _args_strs
                    );
                } else {
                    _result = _emit_fn(_ctx, _args_strs);
                }
            } except Exception as _emit_err {
                self.emit(
                    E5016, node_override=here, name=_builtin_name, error=str(_emit_err)
                );
                return;
            }

            if _result is not None {
                if "_jac." in str(_result) {
                    self.needs_jac_runtime = True;
                }
                here.gen.es_ast = self.sync_loc(
                    es.RawCode(code=_result), jac_node=here
                );
                return;
            }
        }
    }

    if isinstance(here.target, uni.BuiltinType)
        and isinstance(callee, es.MemberExpression) {
        self.needs_jac_runtime = True;
    }

    args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=here);
    callee_expr = cast(es.Expression, callee);
    call_args: list[(es.Expression | es.SpreadElement)] = args;
    (spread_arg, spread_read_source) = self._make_kwargs_spread_context(props, here);
    use_kwargs_temp = spread_read_source is not None;
    ability_node_resolved = self._resolve_call_ability(here);
    if props {
        if ability_node_resolved {
            ordered_args = self._call_args_from_slots(
                self._resolve_call_arg_slots(
                    here,
                    args,
                    props,
                    self._param_names_from_ability(ability_node_resolved),
                    here.target.sym_name
                        if isinstance(here.target, uni.Name)
                        else "func",
                    spread_read_source
                )
            );
            call_args = ordered_args if ordered_args is not None else [args_obj];
        } else {
            call_args = [args_obj];
        }
    }

    if (
        ability_node_resolved
        and self._component_call_abi(ability_node_resolved) == 'props_destructure'
    ) {
        result_expr: es.Expression;

        if any(isinstance(arg, es.SpreadElement) for arg in args) {
            result_expr = self._build_props_spread_component_call(
                here, callee_expr, ability_node_resolved, args, props
            );
        } else {
            wrap_props: list[es.Property] = [];
            param_names = self._param_names_from_ability(ability_node_resolved);
            for (i, arg) in enumerate(call_args) {
                if i < len(param_names) {
                    wrap_props.append(
                        self.sync_loc(
                            es.Property(
                                key=self.sync_loc(
                                    es.Identifier(name=param_names[i]), jac_node=here
                                ),
                                value=cast(es.Expression, arg),
                                kind='init',
                                method=False,
                                shorthand=False,
                                computed=False
                            ),
                            jac_node=here
                        )
                    );
                }
            }
            result_expr = self.sync_loc(
                es.CallExpression(
                    callee=callee_expr,
                    arguments=[
                        self.sync_loc(
                            es.ObjectExpression(properties=wrap_props), jac_node=here
                        )
                    ]
                ),
                jac_node=here
            );
            if use_kwargs_temp and spread_arg is not None {
                result_expr = self._wrap_with_kwargs_temp(
                    result_expr, spread_arg, here
                );
            }
        }
        here.gen.es_ast = result_expr;
        return;
    }

    _target_type = here.target?.type;
    if _target_type is not None {
        _emit_new = _target_type.is_instantiable_class()
            and not _target_type.shared.is_builtin_class;
    } else {
        _emit_new = _call_kind == "instantiation";
    }
    if _emit_new and isinstance(callee, es.Expression) {
        result_expr: es.Expression = self.sync_loc(
            es.NewExpression(callee=callee_expr, arguments=call_args), jac_node=here
        );
    } else {
        result_expr = self.sync_loc(
            es.CallExpression(callee=callee_expr, arguments=call_args), jac_node=here
        );
    }
    if use_kwargs_temp and spread_arg is not None {
        result_expr = self._wrap_with_kwargs_temp(result_expr, spread_arg, here);
    }
    here.gen.es_ast = result_expr;
}
