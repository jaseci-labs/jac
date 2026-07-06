glob _JSX_RESERVED_ATTRS: set[str] = {"key", "ref"};


impl TypeEvaluator._is_mobui_module(nd: uni.UniNode) -> bool {
    mod_path = nd.loc.mod_path if nd.loc else "";
    if not mod_path {
        return False;
    }
    if mod_path not in self._mobui_module_cache {
        import from jaclang.project.client_kind { mobui_enforced_for }
        opts = self.program._compile_options;
        self._mobui_module_cache[mod_path] = mobui_enforced_for(
            mod_path, opts.project_kind, opts.project_root
        );
    }
    return self._mobui_module_cache[mod_path];
}

impl TypeEvaluator._resolve_jsx_component_type(
    name: uni.JsxElementName
) -> types.FunctionType | None {
    if not name.parts {
        return None;
    }
    first_part = name.parts[0];
    component_name = "";
    if isinstance(first_part, uni.Name) {
        component_name = first_part.value or "";
    } elif isinstance(first_part, uni.Token) {
        component_name = first_part.value or "";
    }
    if not component_name {
        return None;
    }

    if (not component_name[0].isupper() and not self._is_mobui_module(name)) {
        return None;
    }

    sym: uni.Symbol | None = None;
    if isinstance(first_part, uni.Name) and first_part.sym {
        sym = first_part.sym;
    }
    if sym is not None {
        sym_type = self.get_type_of_symbol(sym);
        if isinstance(sym_type, types.FunctionType) {
            return sym_type;
        }
    }
    return None;
}

impl TypeEvaluator._get_intrinsic_props_type(tag_name: str) -> types.ClassType | None {
    registry = self.prefetch.jsx_intrinsic_elements_class if self.prefetch else None;
    if registry is not None {
        member = self._lookup_class_member(registry, tag_name);
        if member is not None {
            member_type = self.get_type_of_symbol(member.symbol);
            if isinstance(member_type, types.ClassType) {
                return member_type;
            }
        }
    }

    if self.prefetch and self.prefetch.html_common_props_class {
        return self.prefetch.html_common_props_class;
    }
    return None;
}

impl TypeEvaluator._resolve_intrinsic_jsx_tag(part: uni.Name, tag_name: str) -> None {
    registry = self.prefetch.jsx_intrinsic_elements_class if self.prefetch else None;
    if registry is not None {
        member = self._lookup_class_member(registry, tag_name);
        if member is not None {
            if part.sym is None {
                part.sym = member.symbol;
            }
            return;
        }
    }

    if tag_name {
        self.emit_diag(W1050, part, tag=tag_name);
    }
}

impl TypeEvaluator._validate_jsx_props(
    expr: uni.JsxElement, expected_type: TypeBase | None = None
) -> None {
    if not expr.name or not expr.attributes {
        return;
    }
    first_part = expr.name.parts[0] if expr.name.parts else None;
    if not first_part {
        return;
    }
    tag_name = first_part.value
        if isinstance(first_part, (uni.Name, uni.Token))
        else "";
    if self._is_mobui_module(expr) {
        func_type = self._resolve_jsx_component_type(expr.name);
        if func_type is not None {
            self._validate_component_jsx_props(expr, tag_name, func_type=func_type);
        }
    } else {
        is_component = tag_name and tag_name[0].isupper();
        if is_component {
            self._validate_component_jsx_props(expr, tag_name);
        } else {
            self._validate_intrinsic_jsx_props(expr, tag_name);
        }
    }
}

impl TypeEvaluator._validate_component_jsx_props(
    expr: uni.JsxElement,
    component_name: str,
    func_type: types.FunctionType | None = None
) -> None {
    func_type = func_type or self._resolve_jsx_component_type(expr.name);
    if not func_type or not func_type.parameters {
        return;
    }

    param_map: dict[str, types.Parameter] = {};
    for param in func_type.parameters {
        if not param.is_self and not param.is_cls {
            param_map[param.name] = param;
        }
    }
    matched_params: set[str] = set();

    if len(param_map) == 1 and "props" in param_map {
        props_type = param_map["props"].param_type;

        is_any_class = (
            self.prefetch is not None
            and self.prefetch.any_class is not None
            and isinstance(props_type, types.ClassType)
            and props_type.shared == self.prefetch.any_class.shared
        );
        if (
            props_type is None
            or isinstance(props_type, (types.AnyType, types.UnknownType))
            or is_any_class
        ) {
            return;
        }
        if isinstance(props_type, types.ClassType) {
            for attr in expr.attributes {
                if not isinstance(attr, uni.JsxNormalAttribute) {
                    continue;
                }
                attr_name = attr.name.value
                    if isinstance(attr.name, (uni.Name, uni.Token))
                    else str(attr.name);
                if attr_name in _JSX_RESERVED_ATTRS {
                    continue;
                }
                member = self._lookup_class_member(props_type, attr_name);
                if not member {
                    self.emit_diag(
                        E1101, attr, component=component_name, name=attr_name
                    );
                    continue;
                }
                if attr.value is not None {
                    member_type = self._convert_to_instance(
                        self.get_type_of_symbol(member.symbol)
                    );
                    attr_type = self.get_type_of_expression(
                        attr.value, expected_type=member_type
                    );
                    if (
                        not isinstance(attr_type, (types.UnknownType, types.AnyType))
                        and not self.assign_type(attr_type, member_type)
                    ) {
                        self.emit_diag(
                            E1100,
                            attr,
                            actual=str(attr_type),
                            name=attr_name,
                            expected=str(member_type)
                        );
                    }
                }
            }
            return;
        }
        return;
    }

    for attr in expr.attributes {
        if isinstance(attr, uni.JsxNormalAttribute) {
            attr_name = attr.name.value
                if isinstance(attr.name, (uni.Name, uni.Token))
                else str(attr.name);
            if attr_name in _JSX_RESERVED_ATTRS {
                continue;
            }
            if attr_name not in param_map {
                self.emit_diag(E1101, attr, component=component_name, name=attr_name);
                continue;
            }
            matched_params.add(attr_name);
            matched_param = param_map[attr_name];
            if attr.value is not None and matched_param.param_type is not None {
                attr_type = self.get_type_of_expression(
                    attr.value, expected_type=matched_param.param_type
                );

                if (
                    not isinstance(attr_type, (types.UnknownType, types.AnyType))
                    and not self.assign_type(attr_type, matched_param.param_type)
                ) {
                    self.emit_diag(
                        E1100,
                        attr,
                        actual=str(attr_type),
                        name=attr_name,
                        expected=str(matched_param.param_type)
                    );
                }
            }
        } elif isinstance(attr, uni.JsxSpreadAttribute) {
            spread_type = self.get_type_of_expression(attr.expr);
            if isinstance(spread_type, types.ClassType) {
                if (
                    self.prefetch
                    and self.prefetch.dict_class
                    and spread_type.shared == self.prefetch.dict_class.shared
                ) {
                    for pname in param_map {
                        matched_params.add(pname);
                    }
                } else {
                    self.emit_diag(
                        E1104, attr, actual=str(spread_type), component=component_name
                    );
                }
            } elif not isinstance(spread_type, (types.AnyType, types.UnknownType)) {
                self.emit_diag(
                    E1104, attr, actual=str(spread_type), component=component_name
                );
            }
        }
    }

    for (pname, p) in param_map.items() {
        if pname not in matched_params and not p.is_optional {
            self.emit_diag(E1102, expr, component=component_name, name=pname);
        }
    }
}

impl TypeEvaluator._validate_intrinsic_jsx_props(
    expr: uni.JsxElement, tag_name: str
) -> None {
    props_class = self._get_intrinsic_props_type(tag_name);
    if not props_class {
        return;
    }
    for attr in expr.attributes {
        if isinstance(attr, uni.JsxNormalAttribute) {
            attr_name = attr.name.value
                if isinstance(attr.name, (uni.Name, uni.Token))
                else str(attr.name);

            member = self._lookup_class_member(props_class, attr_name);
            if not member {
                continue;
            }
            if attr.value is not None {
                member_type = self.get_type_of_symbol(member.symbol);
                member_type = self._convert_to_instance(member_type);
                attr_type = self.get_type_of_expression(
                    attr.value, expected_type=member_type
                );

                if (
                    not isinstance(attr_type, (types.UnknownType, types.AnyType))
                    and not self.assign_type(attr_type, member_type)
                ) {
                    self.emit_diag(
                        E1103,
                        attr,
                        actual=str(attr_type),
                        name=attr_name,
                        expected=str(member_type)
                    );
                }
            }
        } elif isinstance(attr, uni.JsxSpreadAttribute) {
            spread_type = self.get_type_of_expression(attr.expr);
            if (
                not isinstance(spread_type, (types.AnyType, types.UnknownType))
                and isinstance(spread_type, types.ClassType)
                and self.prefetch
                and self.prefetch.dict_class
                and spread_type.shared != self.prefetch.dict_class.shared
            ) {
                self.emit_diag(
                    E1104, attr, actual=str(spread_type), component=tag_name
                );
            }
        }
    }
}
