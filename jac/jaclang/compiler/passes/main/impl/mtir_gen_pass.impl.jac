import from collections.abc { Sequence }
import from pathlib { Path }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes { UniPass }
import from jaclang { JacRuntime as Jac }
import from jaclang.jac0core.mtp {
    ClassInfo,
    FieldInfo,
    FunctionInfo,
    MethodInfo,
    ParamInfo,
    mk_dict,
    mk_list,
    mk_tuple,
    type_to_str
}

impl MTIRGenPass.postinit -> None {
    super.postinit();
}

impl MTIRGenPass.transform(ir_in: uni.Module) -> uni.Module {
    for nd in UniPass.get_all_sub_nodes(ir_in, uni.Ability) {
        self._process_ability(nd);
    }
    for arch in self._collect_routing_archetypes(ir_in) {
        self._register_archetype_light(arch);
    }
    return ir_in;
}

impl MTIRGenPass._is_primitive_type(type_expr: uni.Expr | None) -> bool {
    if type_expr is None {
        return False;
    }
    if isinstance(type_expr, uni.Name) or isinstance(type_expr, uni.BuiltinType) {
        return type_expr.value in PRIMITIVE_TYPES;
    }
    return False;
}

impl MTIRGenPass._parse_type_expr(
    type_expr: uni.Expr | None, scope: uni.UniScopeNode
) -> ClassInfo | EnumInfo | str | tuple | None {
    if type_expr is None {
        return None;
    }
    if self._is_primitive_type(type_expr) {
        if isinstance(type_expr, uni.Name) {
            return type_expr.value;
        }
        return str(type_expr);
    }
    try {
        if type_expr?.unparse {
            text = type_expr.unparse();
        } else {
            text = str(type_expr);
        }
        if ('[' in text) and (']' in text) {
            base = text.split('[', 1)[0].strip();
            inner = text[(text.find('[') + 1):text.rfind(']')].strip();
            parts = [
                p.strip()
                for p in inner.split(',')
                if p.strip()
            ];
            resolved_parts: list[object] = [];
            for p in parts {
                try_sym = None;
                if isinstance(scope, uni.UniScopeNode) and scope?.lookup {
                    try {
                        try_sym = scope.lookup(p, deep=True);
                    } except Exception {
                        try_sym = None;
                    }
                }
                if try_sym {
                    nested = self._extract_class_info(try_sym);
                    resolved_parts.append(nested or p);
                } elif p in PRIMITIVE_TYPES {
                    resolved_parts.append(p);
                } else {
                    resolved_parts.append(p);
                }
            }
            if (base == 'list') and (len(resolved_parts) == 1) {
                return mk_list(resolved_parts[0]);
            }
            if (base == 'dict') and (len(resolved_parts) == 2) {
                return mk_dict(resolved_parts[0], resolved_parts[1]);
            }
            if (base == 'tuple') and (len(resolved_parts) >= 1) {
                return mk_tuple(*resolved_parts);
            }
            return tuple([base] + resolved_parts);
        }
    } except Exception {
        ;
    }
    sym = self._extract_type_symbol(type_expr, scope);
    if sym {
        if sym and sym.sym_type.value == 'enum' {
            enum_info = self._extract_enum_info(sym);
            return enum_info;
        } else {
            nested = self._extract_class_info(sym);
            if nested {
                return nested;
            }
            if isinstance(type_expr, uni.Name) {
                return type_expr.value;
            }
        }
    }
    return None;
}

impl MTIRGenPass._extract_type_symbol(
    type_expr: uni.Expr | None, scope: uni.UniScopeNode
) -> uni.Symbol | None {
    if (type_expr is None) or self._is_primitive_type(type_expr) {
        return None;
    }
    if isinstance(type_expr, uni.NameAtom) and type_expr.sym {
        return type_expr.sym;
    }
    if isinstance(type_expr, uni.Name) {
        return scope.lookup(type_expr.value, deep=True);
    }
    return None;
}

impl MTIRGenPass._extract_enum_info(symbol: uni.Symbol) -> EnumInfo {
    decl = symbol.decl;
    if not isinstance(decl.name_of, uni.Enum) {
        raise self.ice(f"Symbol {symbol} is not an Enum.");
    }
    enum_node = decl.name_of;
    members: list[FieldInfo] = [];

    if enum_node.body and isinstance(enum_node.body, Sequence) {
        for enum_stmt in enum_node.body {
            if isinstance(enum_stmt, uni.Assignment) and enum_stmt.is_enum_stmt {
                if enum_stmt.target and len(enum_stmt.target) > 0 {
                    target = enum_stmt.target[0];
                    if isinstance(target, uni.NameAtom)
                    or isinstance(target, uni.Name) {
                        member_name = target.value;

                        type_info = None;
                        if enum_stmt.value {
                            if isinstance(enum_stmt.value, uni.Int) {
                                type_info = "int";
                            } elif isinstance(enum_stmt.value, uni.String) {
                                type_info = "str";
                            } elif isinstance(enum_stmt.value, uni.MultiString) {
                                type_info = "str";
                            } elif isinstance(enum_stmt.value, uni.Float) {
                                type_info = "float";
                            } elif isinstance(enum_stmt.value, uni.Bool) {
                                type_info = "bool";
                            } else {
                                raise self.ice(
                                    f"Enum member '{member_name}' has invalid value type: {type(
                                        enum_stmt.value
                                    ).__name__}. "
                                    f"Only int, str, float, and bool literals are allowed."
                                );
                            }
                        }

                        semstr_val = None;
                        if target?.sym and target.sym {
                            semstr_val = target.sym.semstr;
                        }
                        field_info = FieldInfo(
                            name=member_name, semstr=semstr_val, type_info=type_info
                        );
                        members.append(field_info);
                    }
                }
            } elif isinstance(enum_stmt, uni.NameAtom) and enum_stmt.is_enum_stmt {
                member_name = enum_stmt.value;
                semstr_val = None;
                if enum_stmt?.sym and enum_stmt.sym {
                    semstr_val = enum_stmt.sym.semstr;
                }
                field_info = FieldInfo(
                    name=member_name, semstr=semstr_val, type_info=None
                );
                members.append(field_info);
            }
        }
    }
    return EnumInfo(
        name=enum_node.name.value,
        semstr=symbol.semstr or enum_node.doc.lit_value if enum_node.doc else None,
        members=members
    );
}

impl MTIRGenPass._extract_class_info(symbol: uni.Symbol) -> ClassInfo | None {
    if not self?._class_info_cache {
        self._class_info_cache = {};
    }
    cache_key = id(symbol);
    if cache_key in self._class_info_cache {
        return self._class_info_cache[cache_key];
    }
    decl = symbol.decl;
    if not isinstance(decl.name_of, uni.Archetype) {
        return None;
    }
    arch_node = decl.name_of;
    class_name = arch_node.name.value;
    placeholder = ClassInfo(
        name=class_name,
        semstr=symbol.semstr or arch_node.doc.lit_value if arch_node.doc else None,
        fields=[],
        base_classes=[],
        methods=[]
    );
    self._class_info_cache[cache_key] = placeholder;
    base_classes: list[ClassInfo] = [];
    if arch_node.base_classes {
        for base in arch_node.base_classes {
            try_sym = self._extract_type_symbol(base, arch_node);
            if try_sym {
                nested = self._extract_class_info(try_sym);
                if nested {
                    base_classes.append(nested);
                    continue;
                }
            }
            if isinstance(base, uni.Name) {
                base_name = base.value;
            } elif isinstance(base, uni.AtomTrailer) {
                base_name = base.unparse();
            } else {
                base_name = str(base);
            }
            base_classes.append(ClassInfo(name=base_name, semstr=None));
        }
    }
    fields: list[FieldInfo] = [];
    for var in arch_node.get_has_vars() {
        type_annotation = var.type_tag.tag if var.type_tag else None;
        parsed_type = self._parse_type_expr(type_annotation, arch_node);
        type_symbol_obj = self._extract_type_symbol(parsed_type, arch_node);
        semstr_val = type_symbol_obj.semstr if type_symbol_obj else var.sym.semstr;
        field_info = FieldInfo(
            name=var.name.value, semstr=semstr_val, type_info=parsed_type
        );
        fields.append(field_info);
    }
    methods: list[MethodInfo] = [];
    for method in arch_node.get_methods() {
        methods.append(self._extract_method_info(method));
    }
    placeholder.fields = fields;
    placeholder.base_classes = base_classes;
    placeholder.methods = methods;
    return placeholder;
}

impl MTIRGenPass._extract_function_info(nd: uni.Ability) -> FunctionInfo {
    function_name = nd.py_resolve_name();
    parameters: list[ParamInfo] = [];
    if nd.signature and isinstance(nd.signature, uni.FuncSignature) {
        all_params = nd.signature.get_parameters();
        for param in all_params {
            type_annotation = param.type_tag.tag if param.type_tag else None;
            parsed_type = self._parse_type_expr(type_annotation, nd);
            type_symbol_obj = self._extract_type_symbol(type_annotation, nd);
            semstr_val = None;
            if type_symbol_obj {
                semstr_val = type_symbol_obj.semstr;
            } elif param.name?.sym and param.name.sym {
                semstr_val = param.name.sym.semstr;
            }

            param_info = ParamInfo(
                name=param.name.value, semstr=semstr_val, type_info=parsed_type
            );
            parameters.append(param_info);
        }
    }
    return_type: str | ClassInfo | tuple | None = None;
    if nd.signature and isinstance(nd.signature, uni.FuncSignature) {
        return_type_annotation = nd.signature.return_type;
        parsed_return = self._parse_type_expr(return_type_annotation, nd);
        return_type = parsed_return;
    }
    tools: list[FunctionInfo] = [];
    if nd.is_genai_ability {
        by_expr = nd.body;
        tools = self._extract_tools_from_expr(by_expr, nd);
    }
    return FunctionInfo(
        name=function_name,
        semstr=nd.sym.semstr if nd?.sym and nd.sym else None,
        params=parameters,
        return_type=return_type,
        tools=tools
    );
}

impl MTIRGenPass._extract_method_info(
    nd: uni.Ability, by_call: bool = False
) -> MethodInfo {
    func_info = self._extract_function_info(nd=nd);
    parent_arch = nd.find_parent_of_type(uni.Archetype);
    parent_class_info = None;
    if parent_arch and parent_arch.name?.sym and parent_arch.name.sym and by_call {
        parent_class_info = self._extract_class_info(parent_arch.name.sym);
    } else {
        parent_class_info = parent_arch.name.sym;
    }
    return MethodInfo(
        name=func_info.name,
        semstr=func_info.semstr,
        params=func_info.params,
        return_type=func_info.return_type,
        parent_class=parent_class_info,
        tools=func_info.tools
    );
}

impl MTIRGenPass._get_scope_str(nd: uni.UniScopeNode) -> str {
    import from jaclang.jac0core.ext_registry { STEM_REKEY_SUFFIXES }

    if isinstance(nd, uni.Module) {
        mod_path = nd.loc.mod_path;
        if mod_path {
            path = Path(mod_path);

            stem = path.stem;

            for suf in STEM_REKEY_SUFFIXES {
                if stem.endswith(suf) {
                    stem = stem[:-len(suf)];
                    break;
                }
            }
            return stem;
        }

        return nd.scope_name;
    }
    self_name = nd.scope_name;
    if nd.parent_scope and isinstance(nd.parent_scope, uni.UniScopeNode) {
        parent_scope_str = self._get_scope_str(nd.parent_scope);
        return f"{parent_scope_str}.{self_name}";
    }
    return self_name;
}

impl MTIRGenPass._extract_tools_from_expr(
    expr: uni.Expr, scope: uni.UniScopeNode
) -> list[FunctionInfo] {
    tools: list[FunctionInfo] = [];

    params_to_check: list = [];

    if isinstance(expr, uni.FuncCall) and expr?.params {
        params_to_check = expr.params;
    } elif isinstance(expr, uni.AtomTrailer) {
        current = expr;
        while current {
            if isinstance(current.right, uni.FuncCall) and current.right?.params {
                params_to_check = current.right.params;
                break;
            }

            if isinstance(current.target, uni.AtomTrailer) {
                current = current.target;
            } else {
                break;
            }
        }
    }

    for param in params_to_check {
        if isinstance(param, uni.KWPair)
        and param?.key
        and param.key.value == 'tools' {
            if param.value?.values {
                for tool in param.value.values {
                    try {
                        tool_sym = None;
                        if isinstance(tool, uni.NameAtom) {
                            tool_sym = scope.lookup(tool.value, deep=True);
                        } elif isinstance(tool, uni.AtomTrailer)
                        and isinstance(tool.right, uni.NameAtom) {
                            tool_sym = scope.lookup(tool.right.value, deep=True);
                        } elif tool?.symbol_table {
                            tool_sym = tool.symbol_table;
                        }

                        if tool_sym {
                            tool_ability = tool_sym.decl.name_of
                                if tool_sym.decl
                                else None;
                            if tool_ability and isinstance(tool_ability, uni.Ability) {
                                if tool_ability.is_method {
                                    tool_info = self._extract_method_info(tool_ability);
                                } else {
                                    tool_info = self._extract_function_info(
                                        tool_ability
                                    );
                                }
                                tools.append(tool_info);
                            }
                        }
                    } except Exception {
                        ;
                    }
                }
            }
        }
    }
    return tools;
}

impl MTIRGenPass._process_ability(nd: uni.Ability) -> None {
    if not nd.is_genai_ability {
        return;
    }
    if nd.is_method {
        func_info = self._extract_method_info(nd=nd, by_call=True);
        if (
            isinstance(func_info.return_type, str)
            and func_info.parent_class
            and (func_info.return_type == func_info.parent_class.name)
        ) {
            func_info.return_type = func_info.parent_class;
            parent_name = func_info.parent_class.name
                if func_info.parent_class
                else None;
            ret_str = type_to_str(func_info.return_type);
        }
    } else {
        func_info = self._extract_function_info(nd=nd);
    }
    scope = self._get_scope_str(nd);
    Jac.add_mtir_to_map(scope, func_info);
}

impl MTIRGenPass._collect_routing_archetypes(ir_in: uni.Module) -> list[uni.Archetype] {
    scoped: dict = {};
    widen_all = False;
    saw_routing = False;
    for vs in UniPass.get_all_sub_nodes(ir_in, uni.VisitStmt) {
        tgt = vs.target;
        if not (
            isinstance(tgt, uni.BinaryExpr) and tgt?.op and (tgt.op.name == Tok.KW_BY)
        ) {
            continue;
        }
        saw_routing = True;
        scope_node = vs.find_parent_of_type(uni.Ability) or ir_in;
        walker_arch = vs.find_parent_of_type(uni.Archetype);
        if walker_arch is not None {
            scoped[id(walker_arch)] = walker_arch;
        }
        here_arch = self._archetype_from_event(vs.find_parent_of_type(uni.Ability));
        if here_arch is not None {
            scoped[id(here_arch)] = here_arch;
        }
        (cands, bare) = self._traversal_candidate_archetypes(tgt.left, scope_node);
        for c in cands {
            scoped[id(c)] = c;
        }
        if bare {
            widen_all = True;
        }
    }
    if not saw_routing {
        return [];
    }
    if widen_all {
        for arch in UniPass.get_all_sub_nodes(ir_in, uni.Archetype) {
            if arch.arch_kind in ('node', 'edge') {
                scoped[id(arch)] = arch;
            }
        }
    }
    return list(scoped.values());
}

impl MTIRGenPass._archetype_from_event(ab: uni.Ability | None) -> uni.Archetype | None {
    if ab is None {
        return None;
    }
    sig = ab.signature;
    if not (isinstance(sig, uni.EventSignature) and sig?.arch_tag_info) {
        return None;
    }
    return self._archetype_of_type_expr(sig.arch_tag_info, ab);
}

impl MTIRGenPass._archetype_of_type_expr(
    type_expr: uni.Expr, scope: uni.UniScopeNode
) -> uni.Archetype | None {
    sym = self._extract_type_symbol(type_expr, scope);
    if sym
    and sym?.decl
    and sym.decl?.name_of
    and isinstance(sym.decl.name_of, uni.Archetype) {
        return sym.decl.name_of;
    }
    return None;
}

impl MTIRGenPass._traversal_candidate_archetypes(
    expr: uni.Expr, scope: uni.UniScopeNode
) -> tuple {
    cands: list[uni.Archetype] = [];
    bare = False;
    if not isinstance(expr, uni.EdgeRefTrailer) {
        return ([], True);
    }
    for item in expr.chain {
        if isinstance(item, uni.FilterCompr) {
            if item?.f_type {
                node_arch = self._archetype_of_type_expr(item.f_type, scope);
                if node_arch is not None {
                    cands.append(node_arch);
                } else {
                    bare = True;
                }
            }
        } elif isinstance(item, uni.EdgeOpRef) {
            fc = item.filter_cond;
            if fc and fc?.f_type {
                edge_arch = self._archetype_of_type_expr(fc.f_type, scope);
                if edge_arch is not None {
                    cands.append(edge_arch);
                    found_ep = False;
                    for ep in [edge_arch.src_endpoint, edge_arch.tgt_endpoint] {
                        if ep is not None {
                            ep_arch = self._archetype_of_type_expr(ep, scope);
                            if ep_arch is not None {
                                cands.append(ep_arch);
                                found_ep = True;
                            }
                        }
                    }
                    if not found_ep {
                        bare = True;
                    }
                } else {
                    bare = True;
                }
            } else {
                bare = True;
            }
        }
    }
    return (cands, bare);
}

impl MTIRGenPass._register_archetype_light(nd: uni.Archetype) -> None {
    class_sym = nd.name?.sym;
    if not class_sym {
        return;
    }

    fields: list[FieldInfo] = [];
    for var in nd.get_has_vars() {
        fsem = var.sym.semstr if (var?.sym and var.sym) else None;
        fields.append(
            FieldInfo(name=var.name.value, semstr=fsem or None, type_info=None)
        );
    }
    methods: list[MethodInfo] = [];
    for method in nd.get_methods() {
        msem = method.sym.semstr if (method?.sym and method.sym) else None;
        methods.append(MethodInfo(name=method.py_resolve_name(), semstr=msem or None));
    }
    class_info = ClassInfo(
        name=nd.name.value,
        semstr=class_sym.semstr or (nd.doc.lit_value if nd?.doc else None),
        fields=fields,
        base_classes=[],
        methods=methods
    );
    Jac.add_mtir_to_map(self._get_scope_str(nd), class_info);
}
