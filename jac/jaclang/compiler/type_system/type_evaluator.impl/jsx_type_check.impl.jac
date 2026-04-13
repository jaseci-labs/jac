"""JSX prop type validation for the Jac type evaluator.

Validates that JSX element attributes match the expected types from:
1. User-defined component function signatures (uppercase tags like <Button>)
2. Intrinsic HTML element prop schemas (lowercase tags like <button>)
"""

# Mapping from intrinsic HTML tag names to their prop type class names in dom_types.pyi.
glob _INTRINSIC_TAG_MAP: dict[str, str] = {
         "button": "_ButtonIntrinsicProps",
         "input": "_InputIntrinsicProps",
         "form": "_FormIntrinsicProps",
         "a": "_AnchorIntrinsicProps",
         "img": "_ImgIntrinsicProps",
         "textarea": "_TextAreaIntrinsicProps",
         "select": "_SelectIntrinsicProps"
     };

"""Resolve a JsxElementName to the FunctionType of the component it references."""
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
    # Only resolve uppercase names (user components); lowercase = intrinsic HTML.
    if not component_name or not component_name[0].isupper() {
        return None;
    }
    # Try sym first (populated by sem_def_match_pass for some Name nodes).
    sym: uni.Symbol | None = None;
    if isinstance(first_part, uni.Name) and first_part.sym {
        sym = first_part.sym;
    }
    # Fallback: walk the scope chain to find the name.
    if sym is None {
        scope_node = name.find_parent_of_type(uni.UniScopeNode);
        if scope_node is not None and self.builtins_module is not None {
            sym = type_utils.lookup_symtab(
                scope_node, component_name, self.builtins_module
            );
        }
    }
    if sym is not None {
        sym_type = self.get_type_of_symbol(sym);
        if isinstance(sym_type, types.FunctionType) {
            return sym_type;
        }
    }
    return None;
}

"""Look up the intrinsic prop ClassType for a lowercase HTML tag name."""
impl TypeEvaluator._get_intrinsic_props_type(tag_name: str) -> types.ClassType | None {
    # For tags not in the map, fall back to common props.
    class_name = _INTRINSIC_TAG_MAP.get(tag_name, "_HtmlCommonProps");
    # Look up in the builtins scope (dom_types.pyi is merged there).
    if self.builtins_module is not None
    and class_name in self.builtins_module.names_in_scope {
        sym = self.builtins_module.names_in_scope[class_name];
        if sym is not None {
            sym_type = self.get_type_of_symbol(sym);
            if isinstance(sym_type, types.ClassType) {
                return sym_type;
            }
        }
    }
    return None;
}

"""Validate JSX element attributes against the component's parameter types
or intrinsic element prop types."""
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
    is_component = tag_name and tag_name[0].isupper();

    if is_component {
        self._validate_component_jsx_props(expr, tag_name);
    } else {
        self._validate_intrinsic_jsx_props(expr, tag_name);
    }
}

"""Validate props for a user-defined component (uppercase tag)."""
impl TypeEvaluator._validate_component_jsx_props(
    expr: uni.JsxElement, component_name: str
) -> None {
    func_type = self._resolve_jsx_component_type(expr.name);
    if not func_type or not func_type.parameters {
        return;
    }
    # Build a param lookup dict (skip self/cls).
    param_map: dict[str, types.Parameter] = {};
    for param in func_type.parameters {
        if not param.is_self and not param.is_cls {
            param_map[param.name] = param;
        }
    }
    matched_params: set[str] = set();

    for attr in expr.attributes {
        if isinstance(attr, uni.JsxNormalAttribute) {
            attr_name = attr.name.value
                if isinstance(attr.name, (uni.Name, uni.Token))
                else str(attr.name);
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
                # Skip check when attr type is Unknown/Any (unresolvable, not a type error).
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
            # Step 6: Validate spread props.
            spread_type = self.get_type_of_expression(attr.expr);
            if isinstance(spread_type, types.ClassType) {
                # Check if it's a dict type.
                if (
                    self.prefetch
                    and self.prefetch.dict_class
                    and spread_type.shared == self.prefetch.dict_class.shared
                ) {
                    # dict[str, X] spread — mark all params as potentially matched.
                    # We can't check individual keys at compile time for plain dicts,
                    # so we accept it and skip required-param checking for spread attrs.
                    for pname in param_map {
                        matched_params.add(pname);
                    }
                } else {
                    # Not a dict — emit error.
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
    # Check for missing required params (no default value).
    for (pname, p) in param_map.items() {
        if pname not in matched_params and p.default_value is None {
            self.emit_diag(E1102, expr, component=component_name, name=pname);
        }
    }
}

"""Validate props for an intrinsic HTML element (lowercase tag)."""
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
            # Look up the prop in the intrinsic props class.
            member = self._lookup_class_member(props_class, attr_name);
            if not member {
                # Unknown intrinsic props are allowed (data-*, aria-*, etc.)
                continue;
            }
            if attr.value is not None {
                member_type = self.get_type_of_symbol(member.symbol);
                member_type = self._convert_to_instance(member_type);
                attr_type = self.get_type_of_expression(
                    attr.value, expected_type=member_type
                );
                # Skip check when attr type is Unknown/Any (unresolvable, not a type error).
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
            # For intrinsic elements, spread is allowed with dict types.
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
