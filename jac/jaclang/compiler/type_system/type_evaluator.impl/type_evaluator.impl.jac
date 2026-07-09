impl TypeEvaluator._walk_compr_clauses(comprs: list[uni.InnerCompr]) -> None {
    for compr in comprs {
        self.get_type_of_expression(compr.collection);
        if isinstance(compr.target, uni.Name) {
            self.get_type_of_expression(compr.target);
        }
        if compr.conditional {
            for cond in compr.conditional {
                self.get_type_of_expression(cond);
            }
        }
    }
}

impl TypeEvaluator._null_ok_attr_type(expr: uni.AtomTrailer) -> TypeBase {
    none_type = self.prefetch.none_type_class;
    if none_type is not None {
        expr.right.type = self._convert_to_instance(none_type);
        return expr.right.type;
    }
    return types.UnknownType();
}

impl TypeEvaluator._get_type_of_expression_core(
    expr: uni.Expr, expected_type: TypeBase | None = None
) -> TypeBase {
    if isinstance(expr, uni.BuiltinType) and expr.value == "any" {
        if expr.sym is None and self.typing_module is not None {
            if symbol := type_utils.lookup_symtab(
                self.typing_module, "Any", self.typing_module
            ) {
                symbol.add_use(expr);
                expr.sym = symbol;
                if symbol.decl and symbol.decl.name_of {
                    expr.name_of = symbol.decl.name_of;
                }
            }
        }
        if self.prefetch and self.prefetch.any_class is not None {
            return self.prefetch.any_class;
        }
        return types.AnyType();
    }
    match expr {
        case uni.CfgExpr():
            return self._get_type_of_expression_core(expr.expr, expected_type);

        case uni.String():
            if self.prefetch and self.prefetch.str_class {
                if isinstance(expr.lit_value, bytes) {
                    if self.prefetch.bytes_class {
                        return self._convert_to_instance(self.prefetch.bytes_class);
                    }
                    return types.UnknownType();
                }

                if isinstance(expr.lit_value, str) {
                    ann_parent = expr.parent
                        if not isinstance(expr.parent, uni.MultiString)
                        else expr.parent.parent;
                    if isinstance(ann_parent, (uni.SubTag, uni.FuncSignature)) {
                        resolved = self._try_resolve_forward_ref(expr);
                        if resolved is not None {
                            return resolved;
                        }
                    }
                }

                str_class = self.prefetch.str_class;
                if isinstance(str_class, types.ClassType) {
                    literal_type = str_class.clone_with_literal(expr.lit_value);
                    return self._convert_to_instance(literal_type);
                }
                return self._convert_to_instance(str_class);
            }

        case uni.MultiString():
            if self.prefetch and self.prefetch.str_class {
                for s in expr.strings {
                    if isinstance(s, uni.String) and isinstance(s.lit_value, bytes) {
                        if self.prefetch.bytes_class {
                            return self._convert_to_instance(self.prefetch.bytes_class);
                        }
                        return types.UnknownType();
                    }
                }

                if (
                    isinstance(expr.parent, (uni.SubTag, uni.FuncSignature))
                    and len(expr.strings) == 1
                    and isinstance(expr.strings[0], uni.String)
                    and isinstance(expr.strings[0].lit_value, str)
                ) {
                    resolved = self._try_resolve_forward_ref(expr.strings[0]);
                    if resolved is not None {
                        return resolved;
                    }
                }
                str_class = self.prefetch.str_class;
                if isinstance(str_class, types.ClassType) {
                    all_literal = True;
                    combined_value = "";
                    for s in expr.strings {
                        if isinstance(s, uni.String) {
                            if isinstance(s.lit_value, bytes) {
                                all_literal = False;
                                break;
                            }
                            combined_value += s.lit_value;
                        } elif isinstance(s, uni.FString) {
                            if not self._is_fstring_all_literal(s) {
                                all_literal = False;
                                break;
                            }
                            all_literal = True;
                        }
                    }
                    if all_literal
                    and not any(isinstance(s, uni.FString) for s in expr.strings) {
                        literal_type = str_class.clone_with_literal(combined_value);
                        return self._convert_to_instance(literal_type);
                    } elif all_literal {
                        if self.prefetch.literal_string_class {
                            return self._convert_to_instance(
                                self.prefetch.literal_string_class
                            );
                        }
                    }
                }
                return self._convert_to_instance(str_class);
            }

        case uni.FString():
            if self.prefetch and self.prefetch.str_class {
                if self._is_fstring_all_literal(expr) {
                    if self.prefetch.literal_string_class {
                        return self._convert_to_instance(
                            self.prefetch.literal_string_class
                        );
                    }
                }
                return self._convert_to_instance(self.prefetch.str_class);
            }

        case uni.Int():
            if self.prefetch {
                return self._convert_to_instance(self.get_type_of_int(expr));
            }

        case uni.Float():
            if self.prefetch {
                return self._convert_to_instance(self.get_type_of_float(expr));
            }

        case uni.Null():
            if self.prefetch and self.prefetch.none_type_class {
                return self._convert_to_instance(self.prefetch.none_type_class);
            }

        case uni.ListVal():
            if self.prefetch and self.prefetch.list_class {
                list_inst = self._convert_to_instance(self.prefetch.list_class);
                if isinstance(list_inst, types.ClassType) and not expr.values {
                    expected_elem = self._get_expected_element_type(
                        expected_type, self.prefetch.list_class
                    );
                    if expected_elem is not None {
                        list_inst.private.type_args = [expected_elem];
                    }
                }
                if isinstance(list_inst, types.ClassType) and expr.values {
                    elem_types: list[types.TypeBase] = [];
                    for _val in expr.values {
                        elem_type = self.get_type_of_expression(_val);
                        if not isinstance(elem_type, types.UnknownType)
                        and not self._type_in_list(elem_type, elem_types) {
                            elem_types.append(elem_type);
                        }
                    }

                    expected_elem = self._get_expected_element_type(
                        expected_type, self.prefetch.list_class
                    );
                    if expected_elem is not None and elem_types {
                        all_compatible = True;
                        for et in elem_types {
                            if not self.assign_type(et, expected_elem) {
                                all_compatible = False;
                                break;
                            }
                        }
                        if all_compatible {
                            list_inst.private.type_args = [expected_elem];
                        } else {
                            if len(elem_types) == 1 {
                                list_inst.private.type_args = [elem_types[0]];
                            } elif len(elem_types) > 1 {
                                list_inst.private.type_args = [
                                    types.UnionType(types=elem_types)
                                ];
                            }
                        }
                    } else {
                        if len(elem_types) == 1 {
                            list_inst.private.type_args = [elem_types[0]];
                        } elif len(elem_types) > 1 {
                            list_inst.private.type_args = [
                                types.UnionType(types=elem_types)
                            ];
                        }
                    }
                }
                return list_inst;
            }

        case uni.DictVal():
            if self.prefetch and self.prefetch.dict_class {
                dict_inst = self._convert_to_instance(self.prefetch.dict_class);
                if isinstance(dict_inst, types.ClassType) and not expr.kv_pairs {
                    expected_kv_e = self._get_expected_kv_types(
                        expected_type, self.prefetch.dict_class
                    );
                    if expected_kv_e is not None {
                        dict_inst.private.type_args = list(expected_kv_e);
                    }
                }
                if isinstance(dict_inst, types.ClassType) and expr.kv_pairs {
                    key_types: list[types.TypeBase] = [];
                    val_types: list[types.TypeBase] = [];
                    for _kv in expr.kv_pairs {
                        if _kv.key {
                            kt = self.get_type_of_expression(_kv.key);
                            if not isinstance(kt, types.UnknownType)
                            and not self._type_in_list(kt, key_types) {
                                key_types.append(kt);
                            }
                            vt = self.get_type_of_expression(_kv.value);
                            if not isinstance(vt, types.UnknownType)
                            and not self._type_in_list(vt, val_types) {
                                val_types.append(vt);
                            }
                        } else {
                            st = self.get_type_of_expression(_kv.value);
                            if (
                                isinstance(st, types.ClassType)
                                and st.is_builtin("dict")
                                and st.private.type_args
                                and len(st.private.type_args) >= 2
                            ) {
                                skt = st.private.type_args[0];
                                if not isinstance(skt, types.UnknownType)
                                and not self._type_in_list(skt, key_types) {
                                    key_types.append(skt);
                                }
                                svt = st.private.type_args[1];
                                if not isinstance(svt, types.UnknownType)
                                and not self._type_in_list(svt, val_types) {
                                    val_types.append(svt);
                                }
                            }
                        }
                    }

                    expected_kv = self._get_expected_kv_types(
                        expected_type, self.prefetch.dict_class
                    );
                    if expected_kv is not None and (key_types or val_types) {
                        all_ok = True;
                        for kt in key_types {
                            if not self.assign_type(kt, expected_kv[0]) {
                                all_ok = False;
                                break;
                            }
                        }
                        if all_ok {
                            for vt in val_types {
                                if not self.assign_type(vt, expected_kv[1]) {
                                    all_ok = False;
                                    break;
                                }
                            }
                        }
                        if all_ok {
                            dict_inst.private.type_args = list(expected_kv);
                        } elif key_types or val_types {
                            k_arg = key_types[0]
                                if len(key_types) == 1
                                else types.UnionType(types=key_types)
                                    if key_types
                                    else types.UnknownType();
                            v_arg = val_types[0]
                                if len(val_types) == 1
                                else types.UnionType(types=val_types)
                                    if val_types
                                    else types.UnknownType();
                            dict_inst.private.type_args = [k_arg, v_arg];
                        }
                    } elif key_types or val_types {
                        k_arg = key_types[0]
                            if len(key_types) == 1
                            else types.UnionType(types=key_types)
                                if key_types
                                else types.UnknownType();
                        v_arg = val_types[0]
                            if len(val_types) == 1
                            else types.UnionType(types=val_types)
                                if val_types
                                else types.UnknownType();
                        dict_inst.private.type_args = [k_arg, v_arg];
                    }
                }
                return dict_inst;
            }

        case uni.TupleVal():
            if self.prefetch and self.prefetch.tuple_class {
                tuple_inst = self._convert_to_instance(self.prefetch.tuple_class);
                if isinstance(tuple_inst, types.ClassType) and expr.values {
                    elem_types_t: list[types.TypeBase] = [];
                    for _val in expr.values {
                        et = self.get_type_of_expression(
                            _val.value if isinstance(_val, uni.KWPair) else _val
                        );
                        if not isinstance(et, types.UnknownType) {
                            elem_types_t.append(et);
                        }
                    }

                    if (
                        isinstance(expected_type, types.ClassType)
                        and self.prefetch.tuple_class
                        and expected_type.shared == self.prefetch.tuple_class.shared
                        and expected_type.private.type_args
                        and elem_types_t
                    ) {
                        all_ok = True;
                        exp_args = expected_type.private.type_args;
                        for (i, et) in enumerate(elem_types_t) {
                            exp_elem = exp_args[i]
                                if i < len(exp_args)
                                else exp_args[-1];
                            if not self.assign_type(
                                et, self._convert_to_instance(exp_elem)
                            ) {
                                all_ok = False;
                                break;
                            }
                        }
                        if all_ok {
                            tuple_inst.private.type_args = expected_type.private.type_args;
                        } else {
                            tuple_inst.private.type_args = elem_types_t;
                        }
                    } elif elem_types_t {
                        tuple_inst.private.type_args = elem_types_t;
                    }
                }
                return tuple_inst;
            }

        case uni.SetVal():
            if self.prefetch and self.prefetch.set_class {
                set_inst = self._convert_to_instance(self.prefetch.set_class);
                if isinstance(set_inst, types.ClassType) and not expr.values {
                    expected_elem_se = self._get_expected_element_type(
                        expected_type, self.prefetch.set_class
                    );
                    if expected_elem_se is not None {
                        set_inst.private.type_args = [expected_elem_se];
                    }
                }
                if isinstance(set_inst, types.ClassType) and expr.values {
                    set_elem_types: list[types.TypeBase] = [];
                    for _val in expr.values {
                        et = self.get_type_of_expression(_val);
                        if not isinstance(et, types.UnknownType)
                        and not self._type_in_list(et, set_elem_types) {
                            set_elem_types.append(et);
                        }
                    }

                    expected_elem_s = self._get_expected_element_type(
                        expected_type, self.prefetch.set_class
                    );
                    if expected_elem_s is not None and set_elem_types {
                        all_ok = True;
                        for et in set_elem_types {
                            if not self.assign_type(et, expected_elem_s) {
                                all_ok = False;
                                break;
                            }
                        }
                        if all_ok {
                            set_inst.private.type_args = [expected_elem_s];
                        } else {
                            if len(set_elem_types) == 1 {
                                set_inst.private.type_args = [set_elem_types[0]];
                            } elif len(set_elem_types) > 1 {
                                set_inst.private.type_args = [
                                    types.UnionType(types=set_elem_types)
                                ];
                            }
                        }
                    } else {
                        if len(set_elem_types) == 1 {
                            set_inst.private.type_args = [set_elem_types[0]];
                        } elif len(set_elem_types) > 1 {
                            set_inst.private.type_args = [
                                types.UnionType(types=set_elem_types)
                            ];
                        }
                    }
                }
                return set_inst;
            }

        case uni.SetCompr():
            if self.prefetch and self.prefetch.set_class {
                set_inst = self._convert_to_instance(self.prefetch.set_class);
                self._walk_compr_clauses(expr.compr);
                elem_type = self.get_type_of_expression(expr.out_expr);
                if isinstance(set_inst, types.ClassType)
                and not isinstance(elem_type, types.UnknownType) {
                    set_inst.private.type_args = [elem_type];
                }
                return set_inst;
            }

        case uni.GenCompr():
            if self.prefetch and self.prefetch.list_class {
                list_inst = self._convert_to_instance(self.prefetch.list_class);
                self._walk_compr_clauses(expr.compr);
                elem_type = self.get_type_of_expression(expr.out_expr);
                if isinstance(list_inst, types.ClassType)
                and not isinstance(elem_type, types.UnknownType) {
                    list_inst.private.type_args = [elem_type];
                }
                return list_inst;
            }

        case uni.ListCompr():
            if self.prefetch and self.prefetch.list_class {
                list_inst = self._convert_to_instance(self.prefetch.list_class);
                self._walk_compr_clauses(expr.compr);

                expected_elem_lc = self._get_expected_element_type(
                    expected_type, self.prefetch.list_class
                );
                elem_type = self.get_type_of_expression(
                    expr.out_expr, expected_elem_lc
                );
                if isinstance(list_inst, types.ClassType) {
                    if expected_elem_lc is not None
                    and (
                        isinstance(elem_type, types.UnknownType)
                        or self.assign_type(elem_type, expected_elem_lc)
                    ) {
                        list_inst.private.type_args = [expected_elem_lc];
                    } elif not isinstance(elem_type, types.UnknownType) {
                        list_inst.private.type_args = [elem_type];
                    }
                }
                return list_inst;
            }

        case uni.DictCompr():
            if self.prefetch and self.prefetch.dict_class {
                dict_inst = self._convert_to_instance(self.prefetch.dict_class);
                for compr in expr.compr {
                    self.get_type_of_expression(compr.collection);
                    if isinstance(compr.target, uni.Name) {
                        self.get_type_of_expression(compr.target);
                    } elif isinstance(compr.target, (uni.TupleVal, uni.ListVal)) {
                        for v in compr.target.values {
                            if isinstance(v, uni.Name) {
                                self.get_type_of_expression(v);
                            }
                        }
                    }
                    if compr.conditional {
                        for cond in compr.conditional {
                            self.get_type_of_expression(cond);
                        }
                    }
                }
                if isinstance(expr.kv_pair, uni.KVPair) {
                    key_type = self.get_type_of_expression(expr.kv_pair.key);
                    val_type = self.get_type_of_expression(expr.kv_pair.value);
                    if isinstance(dict_inst, types.ClassType)
                    and not isinstance(key_type, types.UnknownType)
                    and not isinstance(val_type, types.UnknownType) {
                        dict_inst.private.type_args = [key_type, val_type];
                    }
                }
                return dict_inst;
            }

        case uni.LambdaExpr():
            return_type: TypeBase = types.UnknownType();
            parameters: list[types.Parameter] = [];
            has_unresolved_param = False;

            expected_func: types.FunctionType | None = None;
            if (
                isinstance(expected_type, types.FunctionType)
                and expected_type.parameters
            ) {
                expected_func = expected_type;
            }
            if isinstance(expr.signature, uni.FuncSignature) {
                if isinstance(expr.signature.return_type, uni.Expr) {
                    return_type = self._convert_to_instance(
                        self.get_type_of_expression(expr.signature.return_type)
                    );
                }
                sig_params = expr.signature.get_parameters();
                seeded_param = False;
                for (idx, param) in enumerate(sig_params) {
                    param_type: TypeBase | None = None;
                    if param.type_tag {
                        param_type = self._convert_to_instance(
                            self.get_type_of_expression(param.type_tag.tag)
                        );
                    } elif (
                        expected_func
                        and expected_func.parameters
                        and idx < len(expected_func.parameters)
                    ) {
                        param_type = expected_func.parameters[idx].param_type;
                        if param_type is not None {
                            param.name.type = param_type;
                            param.type = param_type;
                            seeded_param = True;
                        }
                    }
                    if param_type is None {
                        has_unresolved_param = True;
                    }
                    parameters.append(
                        types.Parameter(
                            name=param.name.value,
                            category=types.ParameterCategory.Positional,
                            param_type=param_type,
                            default_value=param.value,
                        )
                    );
                }

                if seeded_param and isinstance(expr.body, uni.Expr) {
                    self._invalidate_expr_type_cache(expr.body);
                }
            }

            if has_unresolved_param {
                return types.FunctionType(
                    func_name="<lambda>",
                    return_type=types.UnknownType(),
                    parameters=parameters,
                );
            }
            if isinstance(expr.body, uni.Expr) {
                body_type = self.get_type_of_expression(expr.body);
                if isinstance(return_type, types.UnknownType) {
                    return_type = body_type;
                }
            } elif isinstance(return_type, types.UnknownType) {
                return_type = self._infer_lambda_block_return_type(expr.body);
            }
            return types.FunctionType(
                func_name="<lambda>", return_type=return_type, parameters=parameters,
            );

        case uni.JsxElement():
            if self.prefetch and self.prefetch.jsx_element_class {
                if expr.name and expr.name.parts {
                    for part in expr.name.parts {
                        if isinstance(part, uni.Name) {
                            tag_val = part.value or "";
                            is_mobui = self._is_mobui_module(part);
                            if tag_val and (tag_val[0].isupper() or is_mobui) {
                                self.get_type_of_expression(part);
                            } elif tag_val {
                                self._resolve_intrinsic_jsx_tag(part, tag_val);
                            }
                        }
                    }
                }
                self._validate_jsx_props(expr, expected_type);
                return self._convert_to_instance(self.prefetch.jsx_element_class);
            }

        case uni.Bool():
            if self.prefetch and self.prefetch.bool_class {
                return self._convert_to_instance(self.prefetch.bool_class);
            }

        case uni.IndexSlice():
            if expr.is_range {
                if self.prefetch and self.prefetch.slice_class {
                    return self._convert_to_instance(self.prefetch.slice_class);
                }
                return types.UnknownType();
            }
            if expr.slices and expr.slices[0].start is not None {
                return self.get_type_of_expression(expr.slices[0].start);
            }
            return types.UnknownType();

        case uni.AtomTrailer():
            base_type = self.get_type_of_expression(expr.target);

            if isinstance(expr.target, uni.Name) and expr.target.sym {
                if narrowed := self.get_narrowed_type(expr.target.sym, expr) {
                    base_type = narrowed;
                }
            } elif not isinstance(expr.target, uni.Name)
            and isinstance(base_type, (types.UnionType, types.ClassType)) {
                if narrowed := self.get_narrowed_type_for_expr(
                    expr.target, base_type, expr
                ) {
                    base_type = narrowed;
                }
            }

            if expr.is_attr {
                if isinstance(base_type, types.UnknownType) {
                    assert isinstance(expr.right, uni.Name);

                    if base_type.is_diagnosed {
                        return types.UnknownType(is_diagnosed=True);
                    }
                    target_already_unknown = (
                        isinstance(expr.target.type, types.UnknownType)
                        and isinstance(expr.target, (uni.AtomTrailer, uni.FuncCall))
                    );
                    if not target_already_unknown {
                        self.emit_diag(E1032, expr.right, attr=expr.right.value);
                    }
                    return types.UnknownType();
                }

                full_narrowed: TypeBase | None = None;

                assert isinstance(expr.right, uni.Name);
                if isinstance(base_type, types.AnyType) and base_type.is_foreign {
                    expr.right.type = types.AnyType(is_foreign=True);
                    return expr.right.type;
                }
                if isinstance(base_type, types.ModuleType) {
                    if base_type.is_external {
                        expr.right.type = types.AnyType(is_foreign=True);
                        return expr.right.type;
                    }

                    member_sym = type_utils.lookup_symtab(
                        base_type.symbol_table, expr.right.value, self.builtins_module
                    );
                    if (
                        member_sym is None
                        and isinstance(base_type.symbol_table, uni.Module)
                    ) {
                        member_sym = self._resolve_star_import_symbol(
                            base_type.symbol_table, expr.right.value
                        );
                    }
                    if member_sym is not None {
                        sym = member_sym;
                        sym_type = self.get_type_of_symbol(sym);

                        if special_form := self._get_special_form_type(
                            sym.sym_name, sym_type
                        ) {
                            sym.add_use(expr.right);
                            expr.right.type = special_form;
                            return special_form;
                        }

                        if isinstance(sym_type, types.FunctionType) {
                            overloaded_fns: list[types.FunctionType] = [sym_type];

                            overload_scope = base_type.symbol_table;
                            if sym.parent_tab is not None {
                                overload_scope = sym.parent_tab;
                            }
                            all_syms = type_utils.collect_member_syms(
                                overload_scope, expr.right.value
                            );
                            for overload_symbol in all_syms {
                                if overload_symbol == sym {
                                    continue;
                                }
                                overload_type = self.get_type_of_symbol(
                                    overload_symbol
                                );
                                if isinstance(overload_type, types.FunctionType) {
                                    overloaded_fns.append(overload_type);
                                }
                            }
                            if len(overloaded_fns) > 1 {
                                overloaded_ty = types.OverloadedType(
                                    overloads=overloaded_fns
                                );
                                sym.add_use(expr.right);
                                expr.right.type = overloaded_ty;
                                return overloaded_ty;
                            }
                        }

                        sym.add_use(expr.right);
                        expr.right.type = sym_type;
                        return sym_type;
                    }
                    return types.UnknownType();
                } elif base_type.is_instantiable_class() {
                    assert isinstance(base_type, types.ClassType);
                    lookup_type = self._get_type_for_member_lookup(base_type);
                    if member := self._lookup_class_member(
                        lookup_type, expr.right.value
                    ) {
                        if lookup_type.is_enum_class() {
                            member_name = expr.right.value;
                            if (
                                lookup_type.shared.enum_members
                                and member_name in lookup_type.shared.enum_members
                            ) {
                                self._set_symbol_to_expr(expr.right, member.symbol);
                                member_info = lookup_type.shared.enum_members[
                                    member_name
                                ];
                                return types.EnumMemberType(
                                    enum_class=lookup_type,
                                    member_info=member_info,
                                    flags=types.TypeFlags.Instance
                                );
                            }
                        }

                        overloaded_ty: types.OverloadedType | None = None;
                        member_ty = self.get_type_of_member(member, lookup_type);
                        if isinstance(member_ty, types.FunctionType) {
                            overloaded_fns: list[types.FunctionType] = [member_ty];
                            for overload in member.overloads {
                                overload_ty = self.specialize_member_type(
                                    self.get_type_of_symbol(overload), lookup_type
                                );
                                if isinstance(overload_ty, types.FunctionType) {
                                    overloaded_fns.append(overload_ty);
                                }
                            }
                            if len(overloaded_fns) > 1 {
                                overloaded_ty = types.OverloadedType(
                                    overloads=overloaded_fns
                                );
                            }
                        }
                        member.symbol.add_use(expr.right);
                        expr.right.type = overloaded_ty or member_ty;
                        return expr.right.type;
                    }
                    if expr.is_null_ok {
                        return self._null_ok_attr_type(expr);
                    }
                    if not self.is_any_type(lookup_type) {
                        _has_tvars = (
                            isinstance(lookup_type, types.ClassType)
                            and lookup_type.private.type_args is not None
                            and any(
                                isinstance(a, types.TypeVarType)
                                for a in lookup_type.private.type_args
                            )
                        );
                        if not _has_tvars {
                            self.emit_diag(
                                E1030,
                                expr.right,
                                base_type=str(lookup_type),
                                attr=expr.right.value
                            );
                        }
                    }
                    if self.is_any_type(lookup_type)
                    and self.prefetch.any_class is not None {
                        return self.prefetch.any_class;
                    }
                    return types.UnknownType();
                } elif base_type.is_class_instance() {
                    assert isinstance(base_type, types.ClassType);
                    if (
                        self.prefetch.final_class
                        and base_type.shared == self.prefetch.final_class.shared
                        and base_type.private.type_args
                    ) {
                        inner = base_type.private.type_args[0];
                        if isinstance(inner, types.ClassType) {
                            base_type = inner;
                        }
                    }
                    if base_type.is_enum_class() {
                        attr_name = expr.right.value;
                        if attr_name in ('name', '_name_') {
                            expr.right.type = self._convert_to_instance(
                                self.prefetch.str_class
                            );
                            return expr.right.type;
                        }
                        if attr_name in ('value', '_value_') {
                            val_type = base_type.shared.enum_value_type;

                            if val_type is None and base_type.shared.enum_members {
                                member_types = [
                                    m.value_type
                                    for m in base_type.shared.enum_members.values()
                                    if m.value_type is not None
                                ];
                                if member_types
                                and all(
                                    isinstance(t, types.ClassType)
                                    and isinstance(member_types[0], types.ClassType)
                                    and t.shared == member_types[0].shared
                                    for t in member_types
                                ) {
                                    val_type = member_types[0];
                                }
                            }
                            if val_type is not None {
                                expr.right.type = self._convert_to_instance(val_type);
                            } else {
                                expr.right.type = types.AnyType();
                            }
                            return expr.right.type;
                        }
                    }
                    if self._is_type_subscript(base_type) {
                        lookup_type = self._get_type_for_member_lookup(base_type);
                        if member := self._lookup_class_member(
                            lookup_type, expr.right.value
                        ) {
                            value = self._set_symbol_to_expr(expr.right, member.symbol);
                            return value;
                        }
                    }
                    if member := self._lookup_object_member(
                        base_type, expr.right.value
                    ) {
                        if (
                            expr.right.value in ('init', '__init__')
                            and base_type.is_data_class()
                        ) {
                            has_explicit_init = (
                                'init' in base_type.shared.symbol_table.names_in_scope
                                or '__init__' in base_type.shared.symbol_table.names_in_scope
                            );

                            has_any_has_vars = any(
                                len(cls.shared.symbol_table.get_has_vars()) > 0
                                for cls in base_type.shared.mro
                                if cls.shared.class_name != "object"
                            );

                            if not has_explicit_init and has_any_has_vars {
                                implicit_init_type = self._create_dataclass_init_method(
                                    base_type
                                );
                                expr.right.type = implicit_init_type;
                                return implicit_init_type;
                            }
                        }
                        overloaded_ty: types.OverloadedType | None = None;

                        member_ty = self.get_type_of_member(member, base_type);

                        if isinstance(member_ty, types.FunctionType) {
                            overloaded_fns: list[types.FunctionType] = [member_ty];
                            for overload in member.overloads {
                                overload_ty = self.specialize_member_type(
                                    self.get_type_of_symbol(overload), base_type
                                );
                                if isinstance(overload_ty, types.FunctionType) {
                                    overloaded_fns.append(overload_ty);
                                }
                            }
                            if len(overloaded_fns) > 1 {
                                overloaded_ty = types.OverloadedType(
                                    overloads=overloaded_fns
                                );
                            }
                        }

                        if prop_return_type := self.get_getter_type_from_property(
                            member.symbol
                        ) {
                            prop_return_type = self.specialize_member_type(
                                prop_return_type, base_type
                            );
                            member.symbol.add_use(expr.right);

                            cfg_narrowed = self.get_narrowed_type_for_expr(
                                expr, prop_return_type, expr
                            );
                            expr.right.type = cfg_narrowed or prop_return_type;
                            return expr.right.type;
                        }

                        member.symbol.add_use(expr.right);

                        if full_narrowed is None and overloaded_ty is None {
                            cfg_narrowed = self.get_narrowed_type_for_expr(
                                expr, member_ty, expr
                            );
                            if cfg_narrowed is not None {
                                full_narrowed = cfg_narrowed;
                            }
                        }

                        expr.right.type = full_narrowed or overloaded_ty or member_ty;
                        return expr.right.type;
                    }
                    if (
                        expr.right.value in ('init', '__init__')
                        and base_type.is_data_class()
                    ) {
                        implicit_init_type = self._create_dataclass_init_method(
                            base_type
                        );
                        expr.right.type = implicit_init_type;
                        return implicit_init_type;
                    }
                    if base_type.is_typeddict() {
                        if expr.right.value in ("get", "pop", "setdefault") {
                            synth = self._synthesize_typeddict_method(
                                base_type, expr.right.value
                            );
                            if synth is not None {
                                expr.right.type = synth;
                                return synth;
                            }
                        }
                        td_dict = self._typeddict_as_dict(base_type);
                        if (
                            td_dict is not None
                            and (
                                td_member := self._lookup_object_member(
                                    td_dict, expr.right.value
                                )
                            )
                        ) {
                            td_member_ty = self.get_type_of_member(td_member, td_dict);
                            expr.right.type = td_member_ty;
                            return td_member_ty;
                        }
                    }
                    if getattr_return := self._get_getattr_return_type(base_type) {
                        expr.right.type = getattr_return;
                        expr.right.is_getattr_resolved = True;
                        return getattr_return;
                    }
                    if expr.is_null_ok {
                        return self._null_ok_attr_type(expr);
                    }
                    if not self.is_any_type(base_type) {
                        _has_tvars = (
                            isinstance(base_type, types.ClassType)
                            and base_type.private.type_args is not None
                            and any(
                                isinstance(a, types.TypeVarType)
                                for a in base_type.private.type_args
                            )
                        );
                        if not _has_tvars {
                            self.emit_diag(
                                E1030,
                                expr.right,
                                base_type=str(base_type),
                                attr=expr.right.value
                            );
                        }
                    }
                    if self.is_any_type(base_type)
                    and self.prefetch.any_class is not None {
                        return self.prefetch.any_class;
                    }
                    return types.UnknownType();
                } elif isinstance(base_type, types.EnumMemberType) {
                    member_name = expr.right.value;
                    enum_cls = base_type.enum_class;
                    if member_name in ('name', '_name_') {
                        return self._convert_to_instance(self.prefetch.str_class);
                    }
                    if member_name in ('value', '_value_') {
                        return self._convert_to_instance(base_type.get_value_type());
                    }
                    if (
                        enum_cls.shared.enum_members
                        and member_name in enum_cls.shared.enum_members
                    ) {
                        return types.EnumMemberType(
                            enum_class=enum_cls,
                            member_info=enum_cls.shared.enum_members[member_name],
                            flags=types.TypeFlags.Instance
                        );
                    }
                    return types.UnknownType();
                } elif isinstance(base_type, types.UnionType) and base_type.types {
                    member_types: list[TypeBase] = [];
                    decl_for_ide: uni.NameAtom | None = None;
                    for union_member in base_type.types {
                        if self.is_explicit_any(union_member)
                        or isinstance(union_member, types.UnknownType) {
                            member_types.append(union_member);
                            continue;
                        }
                        if isinstance(union_member, types.ClassType)
                        and union_member.is_class_instance() {
                            if member := self._lookup_object_member(
                                union_member, expr.right.value
                            ) {
                                if prop_ret := self.get_getter_type_from_property(
                                    member.symbol
                                ) {
                                    member_types.append(prop_ret);
                                } else {
                                    member_types.append(
                                        self.get_type_of_symbol(member.symbol)
                                    );
                                }
                                if decl_for_ide is None {
                                    decl_for_ide = member.symbol.decl;
                                }
                            }
                        }
                    }
                    all_union_members_have_field = len(member_types) == len(
                        base_type.types
                    );
                    if all_union_members_have_field {
                        if decl_for_ide and decl_for_ide.sym {
                            decl_for_ide.sym.add_use(expr.right);
                        }

                        unique_types = list({str(t): t for t in member_types}.values());
                        all_same_type = len(unique_types) == 1;
                        expr.right.type = unique_types[0]
                            if all_same_type
                            else types.UnionType(types=unique_types);
                        return expr.right.type;
                    }
                    if expr.is_null_ok {
                        return self._null_ok_attr_type(expr);
                    }
                    missing_types: list[str] = [];
                    for union_member in base_type.types {
                        if self.is_explicit_any(union_member) {
                            continue;
                        }
                        if isinstance(union_member, types.ClassType)
                        and union_member.is_class_instance() {
                            if not self._lookup_object_member(
                                union_member, expr.right.value
                            ) {
                                missing_types.append(str(union_member));
                            }
                        }
                    }
                    self.emit_diag(
                        E1099,
                        expr.right,
                        attr=expr.right.value,
                        type=str(base_type),
                        missing=", ".join(missing_types)
                    );
                    if member_types {
                        if decl_for_ide and decl_for_ide.sym {
                            decl_for_ide.sym.add_use(expr.right);
                        }
                        unique_types = list({str(t): t for t in member_types}.values());
                        all_same_type = len(unique_types) == 1;
                        expr.right.type = unique_types[0]
                            if all_same_type
                            else types.UnionType(types=unique_types);
                        return expr.right.type;
                    }
                    return types.UnknownType();
                } elif isinstance(base_type, types.TypeVarType) {
                    attr_name = expr.right.value;
                    if base_type.is_param_spec and attr_name in ("args", "kwargs") {
                        return types.AnyType();
                    }
                    if base_type.constraints {
                        found_member: any = None;
                        for constraint_type in base_type.constraints {
                            if isinstance(constraint_type, types.ClassType) {
                                if member := self._lookup_object_member(
                                    constraint_type, attr_name
                                ) {
                                    if found_member is None {
                                        found_member = member;
                                    }
                                } else {
                                    self.emit_diag(
                                        E1031,
                                        expr,
                                        attr=attr_name,
                                        type=str(constraint_type)
                                    );
                                }
                            }
                        }
                        if found_member {
                            self._set_symbol_to_expr(expr.right, found_member.symbol);
                            return self.get_type_of_symbol(found_member.symbol);
                        }
                        return types.UnknownType();
                    }
                    if base_type.bound {
                        bound_type = base_type.bound;
                        if isinstance(bound_type, types.ClassType) {
                            if member := self._lookup_object_member(
                                bound_type, attr_name
                            ) {
                                self._set_symbol_to_expr(expr.right, member.symbol);
                                return self.get_type_of_symbol(member.symbol);
                            }

                            self.emit_diag(
                                E1031, expr, attr=attr_name, type=str(bound_type)
                            );
                            return types.UnknownType();
                        } elif isinstance(bound_type, types.UnionType) {
                            for member_type in bound_type.types {
                                if isinstance(member_type, types.ClassType) {
                                    if not self._lookup_object_member(
                                        member_type, attr_name
                                    ) {
                                        self.emit_diag(
                                            E1031,
                                            expr,
                                            attr=attr_name,
                                            type=str(member_type)
                                        );
                                    }
                                }
                            }
                            return types.UnknownType();
                        }
                    }
                    universal_attrs = {
                        "__class__",
                        "__doc__",
                        "__dict__",
                        "__module__",
                        "__sizeof__",
                        "__str__",
                        "__repr__",
                        "__hash__",
                        "__eq__",
                        "__ne__",
                        "__init__",
                        "__new__"
                    };
                    if attr_name in universal_attrs {
                        if self.prefetch.object_class {
                            if member := self._lookup_object_member(
                                self.prefetch.object_class.clone_as_instance(),
                                attr_name
                            ) {
                                self._set_symbol_to_expr(expr.right, member.symbol);
                                return self.get_type_of_symbol(member.symbol);
                            }
                        }
                        return types.UnknownType();
                    }
                    self.emit_diag(E1031, expr, attr=attr_name, type=base_type.name);
                    return types.UnknownType();
                } elif isinstance(
                    base_type, (types.FunctionType, types.OverloadedType)
                ) {
                    import from jaclang.compiler.type_system.type_utils {
                        PropertyWriteKind
                    }
                    if expr.right.value in ("setter", "getter", "deleter")
                    and isinstance(expr.target, uni.Name)
                    and (expr.target.sym is not None)
                    and self._classify_property_symbol(expr.target.sym) != PropertyWriteKind.NOT_PROPERTY {
                        return base_type;
                    }
                    if self.prefetch and self.prefetch.function_class {
                        if member := self._lookup_object_member(
                            self.prefetch.function_class.clone_as_instance(),
                            expr.right.value
                        ) {
                            self._set_symbol_to_expr(expr.right, member.symbol);
                            return self.get_type_of_symbol(member.symbol);
                        }
                    }
                    self.emit_diag(
                        E1031, expr, attr=expr.right.value, type=str(base_type)
                    );
                    return types.UnknownType();
                }
            } elif expr.is_null_ok {
                return self._null_ok_attr_type(expr);
            } elif isinstance(expr.right, uni.AssignCompr) {
                if not isinstance(base_type, types.ClassType) {
                    self.emit_diag(E1034, expr, type=str(base_type));
                    return base_type;
                }
                if len(base_type.private.type_args) == 1 {
                    sequence_of = self._convert_to_instance(
                        base_type.private.type_args[0]
                    );
                    for assign in expr.right.assigns {
                        if assign.key is not None {
                            if member := self._lookup_object_member(
                                sequence_of, assign.key.sym_name
                            ) {
                                self._set_symbol_to_expr(assign.key, member.symbol);
                            } else {
                                self.emit_diag(
                                    E1033,
                                    assign.key,
                                    member=assign.key.sym_name,
                                    type=str(sequence_of)
                                );
                            }
                            dest_type = self.get_type_of_expression(assign.key);
                            src_type = self.get_type_of_expression(assign.value);
                            if not self.assign_type(src_type, dest_type) {
                                self.emit_diag(
                                    E1035,
                                    assign.value,
                                    src=str(src_type),
                                    dest=str(dest_type)
                                );
                            }
                        }
                    }
                }
                for assign in expr.right.assigns {
                    self.get_type_of_expression(assign.value);
                }
                return base_type;
            } elif isinstance(expr.right, uni.FilterCompr) {
                filter_result = self.get_type_of_expression(expr.right);
                if not isinstance(filter_result, types.UnknownType) {
                    return filter_result;
                }
                return base_type;
            } else {
                if (
                    isinstance(base_type, types.ClassType)
                    and base_type.is_special_form("Callable")
                )
                or (
                    isinstance(base_type, types.FunctionType)
                    and base_type.is_gradual_callable_form()
                ) {
                    type_args_expr: uni.Expr | None = None;
                    if isinstance(expr.right, uni.IndexSlice) and expr.right.slices {
                        type_args_expr = expr.right.slices[0].start;
                    }
                    return self._create_callable_type(type_args_expr, expr);
                }
                if (
                    isinstance(base_type, types.ClassType)
                    and base_type.shared.is_builtin_class
                    and base_type.shared.class_name == "_SpecialForm"
                ) {
                    target_name: str | None = None;
                    if isinstance(expr.target, uni.Name) and expr.target.sym {
                        target_name = expr.target.sym.sym_name;
                    } elif (
                        isinstance(expr.target, uni.AtomTrailer)
                        and expr.target.is_attr
                        and isinstance(expr.target.right, uni.Name)
                    ) {
                        target_name = expr.target.right.value;
                    }
                    if target_name == "Union" or target_name == "Optional" {
                        union_args: list[types.TypeBase] = [];
                        if isinstance(expr.right, uni.IndexSlice)
                        and expr.right.slices {
                            ua_vals = expr.right.slices[0].start;
                            if isinstance(ua_vals, uni.TupleVal) {
                                for val in ua_vals.values {
                                    union_args.append(
                                        self._type_from_union_annotation_arg(val)
                                    );
                                }
                            } else {
                                union_args.append(
                                    self._type_from_union_annotation_arg(ua_vals)
                                );
                            }
                        }
                        if target_name == "Optional"
                        and self.prefetch.none_type_class {
                            union_args.append(
                                self._convert_to_instance(self.prefetch.none_type_class)
                            );
                        }
                        if len(union_args) == 1 {
                            return union_args[0];
                        }
                        if len(union_args) > 1 {
                            return types.UnionType(types=union_args);
                        }
                    }

                    if target_name == "ClassVar" {
                        if isinstance(expr.right, uni.IndexSlice)
                        and expr.right.slices {
                            inner_type_expr = expr.right.slices[0].start;
                            return self._convert_to_instance(
                                self.get_type_of_expression(inner_type_expr)
                            );
                        }

                        return types.UnknownType();
                    }

                    if target_name == "Literal" {
                        lit_types: list[types.TypeBase] = [];
                        if isinstance(expr.right, uni.IndexSlice)
                        and expr.right.slices {
                            lit_vals = expr.right.slices[0].start;
                            val_exprs = lit_vals.values
                                if isinstance(lit_vals, uni.TupleVal)
                                else [lit_vals];
                            for val in val_exprs {
                                if lt := self._literal_type_from_expr(val) {
                                    lit_types.append(lt);
                                }
                            }
                        }
                        if len(lit_types) == 1 {
                            return lit_types[0];
                        }
                        if len(lit_types) > 1 {
                            return types.UnionType(types=lit_types);
                        }
                        return types.UnknownType();
                    }
                }
                if (
                    isinstance(base_type, types.ClassType)
                    and self.prefetch.any_class is not None
                    and base_type.shared == self.prefetch.any_class.shared
                ) {
                    return self.prefetch.any_class;
                }
                if isinstance(base_type, types.ClassType)
                and base_type.is_instantiable_class() {
                    type_args: list[types.TypeBase] = [];
                    if isinstance(expr.right, uni.IndexSlice) and expr.right.slices {
                        type_args_vals = expr.right.slices[0].start;
                        if isinstance(type_args_vals, uni.TupleVal) {
                            for val in type_args_vals.values {
                                type_arg_type = self._convert_to_instance(
                                    self.get_type_of_expression(val)
                                );
                                type_args.append(type_arg_type);
                            }
                        } else {
                            type_arg_type = self._convert_to_instance(
                                self.get_type_of_expression(type_args_vals)
                            );
                            type_args.append(type_arg_type);
                        }
                    }
                    return base_type.specialize_generics(type_args);
                }
                if isinstance(expr.right, uni.IndexSlice) and expr.right.is_range {
                    return self.get_type_of_expression(expr.target);
                }
                if isinstance(base_type, types.TypeVarType) {
                    if base_type.constraints {
                        any_subscriptable = False;
                        for constraint_type in base_type.constraints {
                            if isinstance(constraint_type, types.ClassType) {
                                result = self.get_type_of_magic_method_call(
                                    constraint_type, "__getitem__", [expr.right], None
                                );
                                if result {
                                    any_subscriptable = True;
                                } else {
                                    self.emit_diag(
                                        E1040, expr, type=str(constraint_type)
                                    );
                                }
                            }
                        }
                        return types.UnknownType();
                    }
                    if base_type.bound {
                        bound_type = base_type.bound;
                        if isinstance(bound_type, types.ClassType) {
                            result = self.get_type_of_magic_method_call(
                                bound_type, "__getitem__", [expr.right], expr
                            );
                            if result {
                                return result;
                            }

                            self.emit_diag(E1040, expr, type=str(bound_type));
                            return types.UnknownType();
                        }
                    }

                    self.emit_diag(E1040, expr, type=base_type.name);
                    return types.UnknownType();
                }
                subscript_arg: uni.Expr = expr.right;
                if (
                    isinstance(expr.right, uni.IndexSlice)
                    and not expr.right.is_range
                    and expr.right.slices
                ) {
                    subscript_arg = expr.right.slices[0].start;
                }
                if (
                    isinstance(base_type, types.ClassType)
                    and base_type.is_class_instance()
                    and base_type.is_typeddict()
                ) {
                    td_result = self._get_typeddict_indexed_type(
                        base_type, subscript_arg, expr
                    );
                    if td_result is not None {
                        return td_result;
                    }
                }
                if tuple_elem := self._tuple_literal_index_type(
                    base_type, subscript_arg
                ) {
                    return tuple_elem;
                }
                result = self.get_type_of_magic_method_call(
                    base_type, "__getitem__", [subscript_arg], expr
                );
                if result and not isinstance(result, types.UnknownType) {
                    return result;
                }
                if isinstance(base_type, types.ClassType) {
                    if base_type.is_builtin("str") {
                        return base_type;
                    }
                    if base_type.is_builtin("bytes") {
                        if self.prefetch and self.prefetch.int_class {
                            return self._convert_to_instance(self.prefetch.int_class);
                        }
                    }
                }
                if (
                    self._in_native_context()
                    and isinstance(base_type, types.ClassType)
                    and base_type.is_class_instance()
                    and not base_type.is_builtin()
                ) {
                    idx_type = self.get_type_of_expression(subscript_arg);
                    if isinstance(idx_type, types.ClassType)
                    and idx_type.is_builtin("int") {
                        return base_type;
                    }
                }
                return result or types.UnknownType();
            }

        case uni.AtomUnit():
            return self.get_type_of_expression(expr.value);

        case uni.FuncCall():
            return self.validate_call_args(expr);

        case uni.AwaitExpr():
            target_type = self.get_type_of_expression(expr.target);

            if isinstance(target_type, types.TypeVarType) {
                if target_type.constraints {
                    for constraint_type in target_type.constraints {
                        if isinstance(constraint_type, types.ClassType) {
                            result = self.get_type_of_magic_method_call(
                                constraint_type, "__await__", [], None
                            );
                            if not result {
                                self.emit_diag(E1041, expr, type=str(constraint_type));
                            }
                        }
                    }
                    return types.UnknownType();
                }
                if target_type.bound
                and isinstance(target_type.bound, types.ClassType) {
                    result = self.get_type_of_magic_method_call(
                        target_type.bound, "__await__", [], None
                    );
                    if result {
                        return result;
                    }

                    self.emit_diag(E1041, expr, type=str(target_type.bound));
                    return types.UnknownType();
                }

                self.emit_diag(E1041, expr, type=target_type.name);
                return types.UnknownType();
            }

            return self._unwrap_awaitable_type(target_type, expr);

        case uni.CastExpr():
            self.get_type_of_expression(expr.value);
            return self._convert_to_instance(
                self.get_type_of_expression(expr.cast_type)
            );

        case uni.BinaryExpr():
            return operations.get_type_of_binary_operation(self, expr);

        case uni.CompareExpr():
            operand_types: list[types.TypeBase] = [
                self.get_type_of_expression(expr.left)
            ];
            for right in expr.rights {
                operand_types.append(self.get_type_of_expression(right));
            }
            for i in range(len(expr.ops)) {
                op = expr.ops[i];
                left_type = operand_types[i];
                right_type = operand_types[i + 1];

                if (
                    isinstance(left_type, types.UnknownType)
                    or isinstance(right_type, types.UnknownType)
                    or left_type.is_any_type()
                    or right_type.is_any_type()
                ) {
                    continue;
                }

                if op.name in (Tok.KW_IS, Tok.KW_ISN) {
                    continue;
                }

                if op.name in (Tok.KW_IN, Tok.KW_NIN) {
                    is_enum = (
                        isinstance(right_type, types.ClassType)
                        and right_type.is_enum_class()
                    );
                    if not is_enum {
                        result = self.get_type_of_magic_method_call(
                            right_type, "__contains__", [expr.rights[i]], None
                        );
                        if result is None {
                            self.emit_diag(
                                E1111, expr, op=op.value, type=str(right_type)
                            );
                        }
                    }
                    continue;
                }

                if op.name in operations.BINARY_OPERATOR_MAP {
                    (magic, rmagic) = operations.BINARY_OPERATOR_MAP[op.name];
                    result = self.get_type_of_magic_method_call(
                        left_type, magic, [expr.rights[i]], None
                    );
                    if result is None {
                        result = self.get_type_of_magic_method_call(
                            right_type,
                            rmagic,
                            [expr.left if i == 0 else expr.rights[i - 1]],
                            None
                        );
                    }
                    if result is None {
                        self.emit_diag(
                            E1110,
                            expr,
                            op=op.value,
                            left=str(left_type),
                            right=str(right_type)
                        );
                    }
                }
            }

            if self.prefetch and self.prefetch.bool_class {
                return self._convert_to_instance(self.prefetch.bool_class);
            }
            return types.UnknownType();

        case uni.IfElseExpr():
            self.get_type_of_expression(expr.condition.expr);
            true_type = self.get_type_of_expression(expr.value.expr);
            false_type = self.get_type_of_expression(expr.else_value.expr);

            unique_types: list[types.TypeBase] = [];
            for branch_type in [true_type, false_type] {
                self._collect_unique_types(branch_type, unique_types);
            }
            if len(unique_types) == 1 {
                return unique_types[0];
            }
            if len(unique_types) > 1 {
                return types.UnionType(types=unique_types);
            }
            return true_type;

        case uni.BoolExpr():
            is_and = isinstance(expr.op, uni.Token) and expr.op.name == Tok.KW_AND;
            is_or = isinstance(expr.op, uni.Token) and expr.op.name == Tok.KW_OR;
            operand_types: list[TypeBase] = [];
            num_values = len(expr.values);

            and_override_keys: list[int] = [];
            for i in range(num_values) {
                op_type = self.get_type_of_expression(expr.values[i].expr);

                if is_and and i < num_values - 1 {
                    import from jaclang.compiler.type_system.type_evaluator {
                        NarrowingKind,
                        NarrowingPredicate,
                        NarrowingTarget
                    }
                    operand_expr = expr.values[i].expr;
                    cond_info = self.classify_condition(operand_expr);
                    if cond_info is not None
                    and cond_info.kind == NarrowingKind.ISINSTANCE
                    and cond_info.narrow_type is not None {
                        narrowed_sym = self._find_symbol_by_key(
                            cond_info.key, operand_expr
                        );
                        if narrowed_sym is not None {
                            sym_type = self.get_type_of_symbol(narrowed_sym);
                            predicate = NarrowingPredicate(
                                key=cond_info.key, narrow_type=cond_info.narrow_type
                            );
                            target = NarrowingTarget(
                                key=cond_info.key,
                                declared_type=sym_type,
                                symbol=narrowed_sym
                            );
                            narrowed = self._apply_narrowing(
                                predicate, sym_type, True, target
                            );
                            if narrowed is not None {
                                sym_id = id(narrowed_sym);
                                self._and_narrowing_overrides[sym_id] = narrowed;
                                and_override_keys.append(sym_id);
                            }
                        }
                    }
                }

                if is_or and i < num_values - 1 {
                    none_type = self._convert_to_instance(
                        self.prefetch.none_type_class
                    );
                    if none_type is not None {
                        op_type = self.exclude_type_from_union(op_type, none_type);
                    }
                }
                self._collect_unique_types(op_type, operand_types);
            }

            for key in and_override_keys {
                self._and_narrowing_overrides.pop(key, None);
            }
            if len(operand_types) == 1 {
                return operand_types[0];
            } elif len(operand_types) > 1 {
                return types.UnionType(types=operand_types);
            }
            return types.UnknownType();

        case uni.UnaryExpr():
            if isinstance(expr.op, uni.Token) {
                if expr.op.name == Tok.NOT {
                    operand_type = self.get_type_of_expression(expr.operand);
                    if (
                        not isinstance(operand_type, types.UnknownType)
                        and self.prefetch
                        and self.prefetch.bool_class
                    ) {
                        return self._convert_to_instance(self.prefetch.bool_class);
                    }
                    return operand_type;
                }
                if expr.op.name in (Tok.MINUS, Tok.BW_NOT) {
                    operand_type = self.get_type_of_expression(expr.operand);
                    op_name = "__neg__" if expr.op.name == Tok.MINUS else "__invert__";

                    if isinstance(operand_type, types.TypeVarType) {
                        if operand_type.constraints {
                            for constraint_type in operand_type.constraints {
                                if isinstance(constraint_type, types.ClassType) {
                                    result = self.get_type_of_magic_method_call(
                                        constraint_type, op_name, [], None
                                    );
                                    if not result {
                                        self.emit_diag(
                                            E1010,
                                            expr,
                                            op=op_name,
                                            type=str(constraint_type)
                                        );
                                    }
                                }
                            }
                            return types.UnknownType();
                        }
                        if operand_type.bound
                        and isinstance(operand_type.bound, types.ClassType) {
                            result = self.get_type_of_magic_method_call(
                                operand_type.bound, op_name, [], None
                            );
                            if result {
                                return result;
                            }

                            self.emit_diag(
                                E1010, expr, op=op_name, type=str(operand_type.bound)
                            );
                            return types.UnknownType();
                        }

                        self.emit_diag(E1010, expr, op=op_name, type=operand_type.name);
                        return types.UnknownType();
                    }
                    return operand_type;
                }
            }

        case uni.FilterCompr():
            if expr.f_type {
                filter_type = self.get_type_of_expression(expr.f_type);
                if isinstance(filter_type, types.ClassType) {
                    for cmp in expr.compares {
                        if isinstance(cmp.left, uni.Name)
                        and (sym := filter_type.lookup_member_symbol(cmp.left.value)) {
                            self._set_symbol_to_expr(cmp.left, sym);
                        } else {
                            self.emit_diag(
                                E1033,
                                cmp.left,
                                member=cmp.left.value,
                                type=str(filter_type)
                            );
                        }

                        self.get_type_of_expression(cmp);
                    }

                    if self.prefetch and self.prefetch.list_class {
                        list_type = self.prefetch.list_class.clone_as_instance();
                        filter_inst = self._convert_to_instance(filter_type);
                        list_type.private.type_args = [filter_inst];
                        return list_type;
                    }
                }
            }

        case uni.Name() | uni.SpecialVarRef():
            if isinstance(expr, uni.SpecialVarRef) {
                if expr.name == Tok.KW_ROOT {
                    return self._get_type_of_root(expr);
                }

                if expr.name in (Tok.KW_HERE, Tok.KW_VISITOR) {
                    if (method := self._get_enclosing_method(expr)) {
                        if isinstance(method.signature, uni.EventSignature) {
                            if arch := method.signature.arch_tag_info {
                                if isinstance(arch, uni.TupleVal) {
                                    member_insts: list[types.TypeBase] = [];
                                    for member in (arch.values or []) {
                                        member_insts.append(
                                            self._convert_to_instance(
                                                self.get_type_of_expression(member)
                                            )
                                        );
                                    }
                                    if len(member_insts) == 1 {
                                        return member_insts[0];
                                    }
                                    if member_insts {
                                        return types.UnionType(types=member_insts);
                                    }
                                }
                                type_arch_cls = self.get_type_of_expression(arch);
                                type_arch_inst = self._convert_to_instance(
                                    type_arch_cls
                                );
                                if isinstance(type_arch_cls, types.ClassType) {
                                    self._set_symbol_to_expr(
                                        expr, type_arch_inst.get_class_symbol()
                                    );
                                }
                                return type_arch_inst;
                            } else {
                                cls_: uni.Archetype | None = self._get_enclosing_class(
                                    expr
                                );
                                if cls_ {
                                    if cls_.sym_category == uni.SymbolType.WALKER_ARCH {
                                        self._set_symbol_to_expr(
                                            expr,
                                            self.prefetch.node_class.get_class_symbol(),
                                        );
                                    } elif cls_.sym_category == uni.SymbolType.NODE_ARCH {
                                        self._set_symbol_to_expr(
                                            expr,
                                            self.prefetch.walker_class.get_class_symbol(),
                                        );
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if self._is_expr_self(expr) {
                return self._get_type_of_self(expr);
            }

            if self._is_expr_super(expr) {
                return self._get_type_of_super(expr);
            }

            if scope := self._resolution_scope_for(expr) {
                symbol = type_utils.lookup_symtab(
                    scope, expr.value, self.builtins_module
                );

                if self._in_native_context()
                and (symbol is None or symbol.parent_tab is self.builtins_module) {
                    na_sym = self.na_builtins_module.names_in_scope.get(expr.value);
                    if na_sym is not None {
                        symbol = na_sym;
                    }
                }

                if symbol is None or symbol.parent_tab is self.builtins_module {
                    js_sym = self.js_globals_module.names_in_scope.get(expr.value);
                    if js_sym is not None and expr.in_client_context() {
                        symbol = js_sym;
                    }
                }
                if symbol {
                    symbol = self.resolve_imported_symbols(symbol);
                    symbol.add_use(expr);

                    if expr.sym is None {
                        expr.sym = symbol;

                        if symbol.decl and symbol.decl.name_of {
                            expr.name_of = symbol.decl.name_of;
                        }
                    }

                    symbol_type = self.get_type_of_symbol(symbol);

                    if special_form := self._get_special_form_type(
                        symbol.sym_name, symbol_type
                    ) {
                        if isinstance(special_form, types.TypeVarType) {
                            return special_form;
                        }
                        symbol_type = special_form;
                    }

                    if isinstance(expr, uni.Name) {
                        if lhs_type := self._get_type_of_lhs_assignment(expr) {
                            return self._convert_to_instance(lhs_type);
                        }
                    }

                    if narrowed := self.get_narrowed_type(symbol, expr) {
                        if isinstance(narrowed, types.UnionType) {
                            symbol_type = types.UnionType(
                                types=[
                                    self._convert_to_instance(t) for t in narrowed.types
                                ]
                            );
                        } else {
                            symbol_type = self._convert_to_instance(narrowed);
                        }
                    }
                    if isinstance(symbol_type, types.FunctionType) {
                        overloaded_ty: types.OverloadedType | None = None;
                        overloaded_fns: list[types.FunctionType] = [symbol_type];

                        def_sym = self.resolve_to_definition_symbol(symbol);
                        symbol_scope: uni.UniScopeNode | None = def_sym.parent_tab;
                        if symbol_scope is None and def_sym.decl {
                            symbol_scope = def_sym.decl.find_parent_of_type(
                                uni.UniScopeNode
                            );
                        }
                        if symbol_scope {
                            all_syms = type_utils.collect_member_syms(
                                symbol_scope, def_sym.sym_name
                            );
                            for overload_symbol in all_syms {
                                if overload_symbol == def_sym {
                                    continue;
                                }
                                overload_type = self.get_type_of_symbol(
                                    overload_symbol
                                );
                                if isinstance(overload_type, types.FunctionType) {
                                    overloaded_fns.append(overload_type);
                                }
                            }
                        }
                        if len(overloaded_fns) > 1 {
                            overloaded_ty = types.OverloadedType(
                                overloads=overloaded_fns
                            );
                        }
                        return overloaded_ty or symbol_type;
                    }
                    return symbol_type;
                }
            }

        case uni.AwaitExpr():
            return self.get_type_of_expression(expr.target);

        case uni.YieldExpr():
            if expr.expr is not None {
                return self.get_type_of_expression(expr.expr);
            }
            return types.UnknownType();

        case uni.EdgeRefTrailer():
            if self.prefetch and self.prefetch.list_class {
                element_type: types.TypeBase = types.AnyType();
                for chain_item in expr.chain {
                    if isinstance(chain_item, uni.FilterCompr) and chain_item.f_type {
                        ft = self.get_type_of_expression(chain_item.f_type);
                        if isinstance(ft, types.ClassType) {
                            element_type = self._convert_to_instance(ft);
                        }
                    } elif (
                        isinstance(chain_item, uni.EdgeOpRef)
                        and expr.edges_only
                        and chain_item.filter_cond is not None
                        and chain_item.filter_cond.f_type is not None
                    ) {
                        ft = self.get_type_of_expression(chain_item.filter_cond.f_type);
                        if isinstance(ft, types.ClassType) and ft.is_edge_type() {
                            element_type = self._convert_to_instance(ft);
                        }
                    } elif (
                        isinstance(chain_item, uni.EdgeOpRef)
                        and not expr.edges_only
                        and chain_item.filter_cond is not None
                        and chain_item.filter_cond.f_type is not None
                    ) {
                        ft = self.get_type_of_expression(chain_item.filter_cond.f_type);
                        if isinstance(ft, types.ClassType) and ft.is_edge_type() {
                            ep = self._edge_endpoint_type(ft, chain_item.edge_dir);
                            if ep is not None {
                                element_type = self._convert_to_instance(ep);
                            }
                        }
                    }
                }
                list_type = self.prefetch.list_class.clone_as_instance();
                list_type.private.type_args = [element_type];
                return list_type;
            }
            return types.UnknownType();

    }

    return types.UnknownType();
}

impl TypeEvaluator._widen_literal_for_declaration(ty: TypeBase) -> TypeBase {
    if isinstance(ty, types.ClassType) {
        if ty.is_literal_type() {
            return ty.clone_with_literal(None);
        }
        if ty.private.type_args {
            widened_args = [
                self._widen_literal_for_declaration(arg) for arg in ty.private.type_args
            ];
            changed = any(
                new_arg is not old_arg
                for (new_arg, old_arg) in zip(widened_args, ty.private.type_args)
            );
            if changed {
                return ty.specialize_generics(widened_args);
            }
        }
        return ty;
    }
    if isinstance(ty, types.UnionType) and ty.types is not None {
        widened = [self._widen_literal_for_declaration(member) for member in ty.types];
        return types.UnionType(types=widened);
    }
    return ty;
}

impl TypeEvaluator._get_type_of_symbol(symbol: uni.Symbol) -> TypeBase {
    node_ = symbol.decl.name_of;
    match node_ {
        case uni.Enum():
            return self.get_type_of_enum(node_);

        case uni.Archetype():
            return self.get_type_of_class(node_);

        case uni.TypeParam():
            return types.TypeVarType(name=node_.sym_name, is_class_type_param=True);

        case uni.TypeAlias():
            if node_.value is not None {
                return self._resolve_type_alias_rhs(node_.value);
            }
            return types.UnknownType();

        case uni.Ability():
            return self.get_type_of_ability(node_);

        case uni.ParamVar():
            if node_.type_tag {
                annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                if node_.is_vararg {
                    param_type = self.prefetch.list_class.clone_as_instance();
                    param_type.private.type_args = [annotation_type];
                    return param_type;
                } elif node_.is_kwargs {
                    param_type = self.prefetch.dict_class.clone_as_instance();
                    param_type.private.type_args = [
                        self.prefetch.str_class,
                        annotation_type
                    ];
                    return param_type;
                }
                return self._convert_to_instance(annotation_type);
            }

            if node_.name.type is not None {
                return node_.name.type;
            }

        case uni.Name():
            if node_.type is not None {
                return node_.type;
            }

            if enum_member_type := self._get_enum_member_type_for_decl(node_) {
                return enum_member_type;
            }

            if isinstance(node_.parent, (uni.TupleVal, uni.ListVal)) {
                unpack_container = node_.parent;
                unpack_assignment = unpack_container.parent;
                if (
                    isinstance(unpack_assignment, uni.Assignment)
                    and unpack_assignment.value is not None
                ) {
                    idx = -1;
                    for (vi, v) in enumerate(unpack_container.values) {
                        if v is node_ {
                            idx = vi;
                            break;
                        }
                    }
                    if idx >= 0 {
                        rhs_type = self.get_type_of_expression(unpack_assignment.value);
                        extracted = self._extract_tuple_element_type(rhs_type, idx);
                        if (
                            extracted is not None
                            and not isinstance(extracted, types.UnknownType)
                        ) {
                            return extracted;
                        }

                        if elem := self._get_iterable_element_type(
                            rhs_type, unpack_assignment.value
                        ) {
                            return elem;
                        }
                        if extracted is not None {
                            return extracted;
                        }
                    }
                } elif isinstance(unpack_assignment, (uni.InForStmt, uni.InnerCompr)) {
                    collection_type = self.get_type_of_expression(
                        unpack_assignment.collection
                    );
                    elem_type = self._get_iterable_element_type(
                        collection_type, unpack_assignment
                    );
                    if elem_type is not None {
                        idx = -1;
                        for (vi, v) in enumerate(unpack_container.values) {
                            if v is node_ {
                                idx = vi;
                                break;
                            }
                        }
                        if idx >= 0 {
                            if elem := self._extract_tuple_element_type(
                                elem_type, idx
                            ) {
                                return elem;
                            }
                        }
                    }
                }
            }

            if isinstance(node_.parent, uni.Assignment) {
                if node_.parent.type_tag is not None {
                    annotation_type = self.get_type_of_expression(
                        node_.parent.type_tag.tag
                    );

                    if (
                        self._is_type_alias_annotation(
                            annotation_type, node_.parent.type_tag.tag
                        )
                        and node_.parent.value is not None
                    ) {
                        return self._resolve_type_alias_rhs(node_.parent.value);
                    }
                    return self._convert_to_instance(annotation_type);
                } else {
                    if node_.parent.value is not None {
                        return self._widen_literal_for_declaration(
                            self.get_type_of_expression(node_.parent.value)
                        );
                    }
                }
            }

            if (
                isinstance(node_.parent, uni.AtomTrailer)
                and node_.parent.parent
                and isinstance(node_.parent.parent, uni.Assignment)
            ) {
                if node_.parent.parent.type_tag is not None {
                    annotation_type = self.get_type_of_expression(
                        node_.parent.parent.type_tag.tag
                    );
                    return self._convert_to_instance(annotation_type);
                } else {
                    if node_.parent.parent.value is not None {
                        return self.get_type_of_expression(node_.parent.parent.value);
                    }
                }
            }

            if (
                isinstance(node_.parent, uni.BinaryExpr)
                and isinstance(node_.parent.op, uni.Token)
                and node_.parent.op.name == "WALRUS_EQ"
                and node_.parent.left is node_
            ) {
                return self.get_type_of_expression(node_.parent.right);
            }

            if isinstance(node_.parent, (uni.InForStmt, uni.InnerCompr)) {
                collection_type = self.get_type_of_expression(node_.parent.collection);

                if self.is_any_type(collection_type)
                and self.prefetch.any_class is not None {
                    node_.type = self.prefetch.any_class;
                    return self.prefetch.any_class;
                }

                if isinstance(collection_type, types.ClassType)
                and collection_type.is_instantiable_class()
                and collection_type.is_enum_class() {
                    instance_type = collection_type.clone_as_instance();
                    node_.type = instance_type;
                    return instance_type;
                }

                if isinstance(collection_type, types.ClassType)
                and collection_type.is_namedtuple() {
                    has_vars = collection_type.shared.symbol_table.get_has_vars();
                    if has_vars {
                        field_types: list[types.TypeBase] = [];
                        for field in has_vars {
                            if field.type_tag {
                                field_type = self.get_type_of_expression(
                                    field.type_tag.tag
                                );
                                field_types.append(
                                    self._convert_to_instance(field_type)
                                );
                            }
                        }

                        if field_types {
                            first_type = field_types[0];
                            all_same = all(
                                isinstance(ft, types.ClassType)
                                and isinstance(first_type, types.ClassType)
                                and ft.shared == first_type.shared for ft in field_types
                            );
                            if all_same {
                                node_.type = first_type;
                                return first_type;
                            }

                            node_.type = field_types[0];
                            return field_types[0];
                        }
                    }
                }

                iter_type = self.get_type_of_magic_method_call(
                    collection_type, "__iter__", [], node_.parent,
                );
                if isinstance(iter_type, types.ClassType) {
                    next_type = self.get_type_of_magic_method_call(
                        iter_type, "__next__", [], node_.parent
                    );
                    if next_type and not isinstance(next_type, types.UnknownType) {
                        result_type = self._convert_to_instance(next_type);
                        node_.type = result_type;
                        return result_type;
                    }

                    if iter_type.private
                    and iter_type.private.type_args
                    and len(iter_type.private.type_args) == 1 {
                        elem_type = iter_type.private.type_args[0];

                        if isinstance(elem_type, types.ClassType) {
                            result_type = elem_type.clone_as_instance();
                            node_.type = result_type;
                            return result_type;
                        }

                        if isinstance(collection_type, types.ClassType)
                        and collection_type.private.type_args {
                            specialized = iter_type.specialize_generics(
                                collection_type.private.type_args
                            );
                            if len(specialized.private.type_args) == 1 {
                                iterable_type = specialized.private.type_args[0];
                                if isinstance(iterable_type, types.ClassType) {
                                    result_type = iterable_type.clone_as_instance();
                                    node_.type = result_type;
                                    return result_type;
                                }
                            }
                        }
                    }
                }
                return types.UnknownType();
            }

            if isinstance(node_.parent, uni.Except) and node_.parent.ex_type {
                ex_type = self.get_type_of_expression(node_.parent.ex_type);
                return self._convert_to_instance(ex_type);
            }

            if isinstance(node_.parent, uni.ModulePath) {
                return self.get_type_of_module(node_.parent);
            }
            if isinstance(node_.parent, uni.ModuleItem) {
                return self.get_type_of_module_item(node_.parent);
            }

        case uni.HasVar():
            if node_.type_tag is not None {
                annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                return self._convert_to_instance(annotation_type);
            } else {
                if node_.value is not None {
                    return self.get_type_of_expression(node_.value);
                }
            }

    }

    return types.UnknownType();
}

impl TypeEvaluator._get_enum_member_type_for_decl(
    node_: uni.Name
) -> (types.EnumMemberType | None) {
    assignment = node_.parent;
    if not isinstance(assignment, uni.Assignment) or not assignment.is_enum_stmt {
        return None;
    }

    if node_ not in assignment.target {
        return None;
    }
    container = assignment.parent;
    enum_node: uni.Enum | None = None;
    if isinstance(container, uni.Enum) {
        enum_node = container;
    } elif isinstance(container, uni.ImplDef)
    and isinstance(container.decl_link, uni.Enum) {
        enum_node = container.decl_link;
    }
    if enum_node is None {
        return None;
    }
    enum_type = self.get_type_of_enum(enum_node);
    member_info = enum_type.shared.enum_members.get(node_.sym_name)
        if enum_type.shared.enum_members
        else None;
    if member_info is None {
        return None;
    }
    return types.EnumMemberType(enum_class=enum_type, member_info=member_info);
}

impl TypeEvaluator._assign_callable(
    src_func: types.FunctionType, dest_func: types.FunctionType, strict: bool = False
) -> bool {
    if dest_func.is_gradual_callable_form() {
        if dest_func.return_type and src_func.return_type {
            return self.assign_type(
                src_func.return_type, dest_func.return_type, strict
            );
        }
        return True;
    }

    if src_func.is_gradual_callable_form() {
        return False;
    }

    src_params = [
        p
        for p in (src_func.parameters or [])
        if not p.is_self and not p.is_cls
    ];
    dest_params = [
        p
        for p in (dest_func.parameters or [])
        if not p.is_self and not p.is_cls
    ];

    overlap = min(len(src_params), len(dest_params));
    for i in range(overlap) {
        dest_param = dest_params[i];
        src_param = src_params[i];

        if dest_param.param_type is None or src_param.param_type is None {
            continue;
        }

        if not self.assign_type(dest_param.param_type, src_param.param_type, strict) {
            return False;
        }
    }

    if len(src_params) > len(dest_params) {
        for i in range(len(dest_params), len(src_params)) {
            src_param = src_params[i];
            if not src_param.is_optional {
                return False;
            }
        }
    }

    if dest_func.return_type and src_func.return_type {
        src_ret = self._convert_to_instance(src_func.return_type);
        dest_ret = self._convert_to_instance(dest_func.return_type);
        if not self.assign_type(src_ret, dest_ret, strict) {
            return False;
        }
    }
    return True;
}

impl TypeEvaluator._assign_class(
    src_type: types.ClassType, dest_type: types.ClassType, strict: bool = False
) -> bool {
    unwrapped_dest: types.TypeBase = dest_type;
    unwrapped_src: types.TypeBase = src_type;
    if dest_type.shared == self.prefetch.final_class.shared {
        if len(dest_type.private.type_args) > 0 {
            unwrapped_dest = dest_type.private.type_args[0];
        }
    }
    if src_type.shared == self.prefetch.final_class.shared {
        if len(src_type.private.type_args) > 0 {
            unwrapped_src = src_type.private.type_args[0];
        }
    }

    if not isinstance(unwrapped_src, types.ClassType)
    or not isinstance(unwrapped_dest, types.ClassType) {
        return self.assign_type(unwrapped_src, unwrapped_dest, strict);
    }
    src_type = unwrapped_src;
    dest_type = unwrapped_dest;
    if src_type.shared.same_class(dest_type.shared) {
        if dest_type.is_literal_type() {
            if not src_type.is_literal_type() {
                return False;
            }

            return src_type.get_literal_value() == dest_type.get_literal_value();
        }

        if src_type.private.type_args and dest_type.private.type_args {
            if len(src_type.private.type_args) == len(dest_type.private.type_args) {
                for i in range(len(src_type.private.type_args)) {
                    src_arg = self._convert_to_instance(src_type.private.type_args[i]);
                    dest_arg = self._convert_to_instance(
                        dest_type.private.type_args[i]
                    );
                    if not self.assign_type(src_arg, dest_arg, strict) {
                        return False;
                    }
                }
            }
        }
        return True;
    }

    if self.is_sub_class(dest_type, src_type) {
        if dest_type.private.type_args {
            specialized = type_utils.specialize_for_base_class(src_type, dest_type);
            src_args = specialized.private.type_args;
            if src_args and len(src_args) == len(dest_type.private.type_args) {
                for i in range(len(src_args)) {
                    src_arg = self._convert_to_instance(src_args[i]);
                    dest_arg = self._convert_to_instance(
                        dest_type.private.type_args[i]
                    );

                    tp = dest_type.shared.type_params[i]
                        if (
                            dest_type.shared.type_params
                            and i < len(dest_type.shared.type_params)
                        )
                        else None;
                    if tp and tp.is_covariant {
                        if not self.assign_type(src_arg, dest_arg, strict) {
                            return False;
                        }
                    } elif tp and tp.is_contravariant {
                        if not self.assign_type(dest_arg, src_arg, strict) {
                            return False;
                        }
                    } else {
                        if not self.assign_type(src_arg, dest_arg, strict) {
                            return False;
                        }
                    }
                }
            }
        }
        return True;
    }

    if src_type.is_builtin("int") and dest_type.is_builtin("float") {
        return True;
    }

    if src_type.is_builtin() and dest_type.is_builtin() {
        import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY, NumericKind }
        src_kind = JAC_TYPE_REGISTRY.numeric_kind_of(src_type.shared.class_name);
        dest_kind = JAC_TYPE_REGISTRY.numeric_kind_of(dest_type.shared.class_name);
        if src_kind != NumericKind.NotNumeric and dest_kind != NumericKind.NotNumeric {
            if src_kind == dest_kind {
                return True;
            }
            if src_kind == NumericKind.IntKind and dest_kind == NumericKind.FloatKind {
                return True;
            }
        }
    }

    is_protocol = False;

    for base_cls in dest_type.shared.base_classes {
        if not isinstance(base_cls, types.ClassType) or base_cls._shared is None {
            continue;
        }

        if base_cls.shared == self.prefetch.protocol_class.shared {
            is_protocol = True;
            break;
        }

        if base_cls.shared.is_builtin_class
        and base_cls.shared.class_name in ('Protocol', '_SpecialForm') {
            is_protocol = True;
            break;
        }
    }

    if not is_protocol {
        class_name = dest_type.shared.class_name;
        if (dest_type.shared.is_from_stdlib_stub or dest_type.shared.is_builtin_class)
        and (class_name.startswith('Supports') or class_name.startswith('_Supports')) {
            is_protocol = True;
        }
    }

    if not is_protocol {
        for mro_cls in dest_type.shared.mro {
            if isinstance(mro_cls, types.ClassType) {
                if (
                    mro_cls.shared.is_builtin_class
                    or mro_cls.shared.is_from_stdlib_stub
                )
                and mro_cls.shared.class_name in ('Protocol', '_SpecialForm') {
                    is_protocol = True;
                    break;
                }
            }
        }
    }

    if is_protocol {
        if type_utils.class_implements_protocol(src_type, dest_type, self) {
            return True;
        }

        for mro_cls in src_type.shared.mro {
            if mro_cls.shared != src_type.shared {
                if type_utils.class_implements_protocol(mro_cls, dest_type, self) {
                    return True;
                }
            }
        }
    }
    return False;
}

impl TypeEvaluator.is_sub_class(
    super_cls: types.ClassType, sub_cls: types.ClassType
) -> bool {
    if not sub_cls.shared.mro {
        type_utils.compute_mro_linearization(sub_cls);
    }
    for cls in sub_cls.shared.mro {
        if cls.shared.same_class(super_cls.shared) {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator.get_type_of_magic_method_call(
    obj_type: TypeBase,
    method_name: str,
    arg_nodes: list[uni.Expr],
    node_for_error: uni.Expr | None = None,
) -> TypeBase | None {
    if isinstance(obj_type, types.UnionType) {
        result_types: list[types.TypeBase] = [];
        for member_type in obj_type.types {
            result = self.get_type_of_magic_method_call(
                member_type, method_name, arg_nodes, node_for_error
            );
            if result is not None and not self._type_in_list(result, result_types) {
                result_types.append(result);
            }
        }
        if len(result_types) == 1 {
            return result_types[0];
        } elif len(result_types) > 1 {
            return types.UnionType(types=result_types);
        }
        return None;
    }
    if obj_type.category == types.TypeCategory.Class {
        assert isinstance(obj_type, types.ClassType);
        if member := self._lookup_class_member(obj_type, method_name) {
            member_ty = self.get_type_of_symbol(member.symbol);

            overloaded_fns: list[types.FunctionType] = [];
            if isinstance(member_ty, types.FunctionType) {
                member_ty = member_ty.specialize(obj_type);
                overloaded_fns.append(member_ty);
                for overload in member.overloads {
                    overload_member_ty = self.get_type_of_symbol(overload);
                    if isinstance(overload_member_ty, types.FunctionType) {
                        overload_member_ty = overload_member_ty.specialize(obj_type);
                        overloaded_fns.append(overload_member_ty);
                    }
                }

                _fallback_result: TypeBase | None = None;
                for fn in overloaded_fns {
                    arg_param_match = self.match_args_to_params(
                        arg_nodes, node_for_error, fn, checking_overload=True
                    );
                    if not arg_param_match.argument_errors {
                        if self.validate_arg_types(
                            arg_param_match, checking_overload=True
                        ) {
                            if not isinstance(fn.return_type, types.UnknownType) {
                                return fn.return_type or types.UnknownType();
                            }
                            if _fallback_result is None {
                                _fallback_result = fn.return_type;
                            }
                        }
                    }
                }
                if _fallback_result is not None {
                    return _fallback_result;
                }

                return None;
            }

            return None;
        }
    }
    return None;
}

impl TypeEvaluator.slice_assignment_is_valid(
    target: uni.Expr, value_node: uni.Expr
) -> bool {
    if not (
        isinstance(target, uni.AtomTrailer)
        and not target.is_attr
        and isinstance(target.right, uni.IndexSlice)
        and target.right.is_range
    ) {
        return False;
    }
    base_type = self.get_type_of_expression(target.target);
    if isinstance(base_type, types.ClassType) and not base_type.is_class_instance() {
        return False;
    }
    return self.get_type_of_magic_method_call(
        base_type, "__setitem__", [target.right, value_node], None
    ) is not None;
}

impl TypeEvaluator.is_any_type(ty: TypeBase) -> bool {
    if isinstance(ty, types.TypeVarType) {
        return True;
    }

    if isinstance(ty, types.ClassType) {
        if (self.prefetch.any_class and ty.shared == self.prefetch.any_class.shared) {
            return True;
        }
        if (
            self.prefetch.type_var_class
            and ty.shared == self.prefetch.type_var_class.shared
        ) {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator.is_explicit_any(ty: TypeBase) -> bool {
    if isinstance(ty, types.AnyType) {
        return True;
    }
    if isinstance(ty, types.ClassType) {
        if self.prefetch
        and self.prefetch.any_class
        and ty.shared == self.prefetch.any_class.shared {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator.is_none_type(ty: TypeBase) -> bool {
    if not self.prefetch or not self.prefetch.none_type_class {
        return False;
    }
    return (
        isinstance(ty, types.ClassType)
        and ty.shared == self.prefetch.none_type_class.shared
    );
}

impl TypeEvaluator._is_strict_site(nd: uni.UniNode) -> bool {
    mod = nd.find_parent_of_type(uni.Module);
    if mod is None {
        return False;
    }
    cached = self._strict_site_cache.get(id(mod));
    if cached is not None {
        return cached;
    }
    result = not mod.is_raised_from_py;
    self._strict_site_cache[id(mod)] = result;
    return result;
}

impl TypeEvaluator._in_native_context -> bool {
    import from jaclang.jac0core.ext_registry { is_native_module }
    if self._pass is None {
        return False;
    }
    cur = self._pass?.cur_node;
    if cur is None or not isinstance(cur, uni.UniNode) {
        return False;
    }

    if cur.in_native_context() {
        return True;
    }
    mod = cur.find_parent_of_type(uni.Module);
    if mod is None or mod.loc is None {
        return False;
    }
    return is_native_module(mod.loc.mod_path);
}

impl TypeEvaluator._is_typing_special_form(ty: TypeBase, name: str) -> bool {
    return (
        isinstance(ty, types.ClassType)
        and ty.shared is not None
        and ty.shared.class_name == name
        and ty.shared.is_from_stdlib_stub
    );
}

impl TypeEvaluator.is_typevar_class(ty: TypeBase) -> bool {
    if (
        self.prefetch
        and self.prefetch.type_var_class
        and isinstance(ty, types.ClassType)
        and ty.shared == self.prefetch.type_var_class.shared
    ) {
        return True;
    }
    return self._is_typing_special_form(ty, "TypeVar");
}

impl TypeEvaluator.is_paramspec_class(ty: TypeBase) -> bool {
    if (
        self.prefetch
        and self.prefetch.param_spec_class
        and isinstance(ty, types.ClassType)
        and ty.shared == self.prefetch.param_spec_class.shared
    ) {
        return True;
    }
    return self._is_typing_special_form(ty, "ParamSpec");
}

impl TypeEvaluator.is_type_var_tuple_class(ty: TypeBase) -> bool {
    if (
        self.prefetch
        and self.prefetch.type_var_tuple_class
        and isinstance(ty, types.ClassType)
        and ty.shared == self.prefetch.type_var_tuple_class.shared
    ) {
        return True;
    }
    return self._is_typing_special_form(ty, "TypeVarTuple");
}

impl TypeEvaluator.assign_type(
    src_type: TypeBase, dest_type: TypeBase, strict: bool = False
) -> bool {
    if src_type == dest_type {
        return True;
    }

    if isinstance(dest_type, types.UnknownType) {
        return True;
    }

    if isinstance(src_type, types.UnknownType) and src_type.is_diagnosed {
        return True;
    }

    if isinstance(src_type, types.NeverType) {
        return True;
    }

    if self.is_explicit_any(dest_type) {
        return True;
    }

    if isinstance(dest_type, types.ClassType) and dest_type.is_builtin("object") {
        return True;
    }

    if self.is_explicit_any(src_type) {
        if not strict {
            return True;
        }
        if isinstance(dest_type, types.TypeVarType) {
            return True;
        }

        if self._in_native_context() {
            return True;
        }
        if isinstance(src_type, types.AnyType) and src_type.is_foreign {
            return True;
        }
        return False;
    }

    if self.prefetch
    and isinstance(src_type, types.ClassType)
    and isinstance(dest_type, types.ClassType) {
        if src_type.is_literal_type()
        and self.prefetch.str_class
        and self.prefetch.literal_string_class {
            if src_type.shared == self.prefetch.str_class.shared {
                if dest_type.shared == self.prefetch.literal_string_class.shared {
                    return True;
                }
            }
        }

        if src_type.is_literal_type() and not dest_type.is_literal_type() {
            if src_type.shared == dest_type.shared {
                return True;
            }
        }

        if src_type.is_literal_type() and dest_type.is_literal_type() {
            if src_type.shared == dest_type.shared {
                return src_type.get_literal_value() == dest_type.get_literal_value();
            }
        }

        if not src_type.is_literal_type() and dest_type.is_literal_type() {
            if src_type.shared == dest_type.shared {
                return True;
            }
        }

        if self.prefetch.literal_string_class and self.prefetch.str_class {
            if (
                src_type.shared == self.prefetch.literal_string_class.shared
                and dest_type.shared != self.prefetch.literal_string_class.shared
            ) {
                str_instance = self._convert_to_instance(self.prefetch.str_class);
                if self.assign_type(str_instance, dest_type, strict) {
                    return True;
                }
            }
        }
    }

    if self.prefetch and self.prefetch.jsx_element_class {
        if isinstance(dest_type, types.ClassType)
        and isinstance(src_type, types.ClassType) {
            if dest_type.shared == self.prefetch.jsx_element_class.shared {
                if src_type.shared != self.prefetch.jsx_element_class.shared {
                    return False;
                }
            }
        }
    }

    if (
        isinstance(dest_type, types.FunctionType)
        and dest_type.is_gradual_callable_form()
        and isinstance(src_type, types.FunctionType)
    ) {
        return True;
    }
    if isinstance(dest_type, types.FunctionType) {
        if isinstance(src_type, types.FunctionType) {
            return self._assign_callable(src_type, dest_type, strict);
        }

        if isinstance(src_type, types.OverloadedType) and src_type.overloads {
            for overload in src_type.overloads {
                if self._assign_callable(overload, dest_type, strict) {
                    return True;
                }
            }
            return False;
        }

        if isinstance(src_type, types.ClassType) and src_type.is_class_instance() {
            if call_member := self._lookup_object_member(src_type, "__call__") {
                call_type = self.get_type_of_symbol(call_member.symbol);
                if isinstance(call_type, types.FunctionType) {
                    return self._assign_callable(call_type, dest_type, strict);
                }
            }
        }

        if isinstance(src_type, types.ClassType)
        and src_type.is_class_instance()
        and src_type.is_builtin("int")
        and self._in_native_context() {
            return True;
        }
    }

    if isinstance(src_type, types.FunctionType) {
        if isinstance(dest_type, types.ClassType) and dest_type.is_class_instance() {
            if call_member := self._lookup_object_member(dest_type, "__call__") {
                call_type = self.get_type_of_symbol(call_member.symbol);
                if isinstance(call_type, types.FunctionType) {
                    return self._assign_callable(src_type, call_type, strict);
                }
            }
        }

        if isinstance(dest_type, types.ClassType)
        and dest_type.is_builtin("int")
        and self._in_native_context() {
            return True;
        }
    }

    if isinstance(src_type, types.ClassType)
    and isinstance(dest_type, types.ClassType)
    and src_type.is_class_instance()
    and dest_type.is_class_instance()
    and self._in_native_context() {
        src_is_ptr = (
            src_type.is_builtin("int")
            or src_type.is_builtin("str")
            or not src_type.is_builtin()
        );
        dest_is_ptr = (
            dest_type.is_builtin("int")
            or dest_type.is_builtin("str")
            or not dest_type.is_builtin()
        );
        if src_is_ptr
        and dest_is_ptr
        and (
            src_type.is_builtin("int")
            or src_type.is_builtin("str")
            or dest_type.is_builtin("int")
            or dest_type.is_builtin("str")
        ) {
            return True;
        }
    }

    if self.is_any_type(dest_type) or self.is_any_type(src_type) {
        return True;
    }

    if isinstance(dest_type, types.ClassType) and dest_type.is_builtin("object") {
        return True;
    }

    if isinstance(src_type, types.UnionType)
    and not isinstance(dest_type, types.UnionType) {
        for src_member in src_type.types {
            src_member_inst = self._convert_to_instance(src_member);
            if not self.assign_type(src_member_inst, dest_type, strict) {
                return False;
            }
        }
        return True;
    }

    if isinstance(dest_type, types.UnionType) {
        if isinstance(src_type, types.UnionType) {
            for src_type_arg in src_type.types {
                matched = False;
                src_type_inst = self._convert_to_instance(src_type_arg);
                for dest_type_arg in dest_type.types {
                    dest_type_inst = self._convert_to_instance(dest_type_arg);
                    if self.assign_type(src_type_inst, dest_type_inst, strict) {
                        matched = True;
                        break;
                    }
                }

                if not matched {
                    return False;
                }
            }

            return True;
        }
        for union_type in dest_type.types {
            new_dest_type = self._convert_to_instance(union_type);
            if self.assign_type(src_type, new_dest_type, strict) {
                return True;
            }
        }
    }

    if isinstance(src_type, types.EnumMemberType) {
        if isinstance(dest_type, types.ClassType) and dest_type.is_enum_class() {
            if src_type.enum_class.shared == dest_type.shared {
                return True;
            }
        }

        if isinstance(dest_type, types.EnumMemberType) {
            if src_type.enum_class.shared == dest_type.enum_class.shared {
                return True;
            }
        }

        if isinstance(dest_type, types.ClassType)
        and isinstance(
            enum_val_type := src_type.enum_class.shared.enum_value_type, types.ClassType
        )
        and dest_type.shared == enum_val_type.shared {
            return True;
        }
    }

    if self.prefetch and self.prefetch.type_class {
        if isinstance(dest_type, types.ClassType)
        and isinstance(src_type, types.ClassType) {
            if dest_type.shared == self.prefetch.type_class.shared {
                if src_type.is_instantiable_class() {
                    if dest_type.private.type_args {
                        target_inner = self._convert_to_instance(
                            dest_type.private.type_args[0]
                        );
                        src_inner = self._convert_to_instance(src_type);
                        return self.assign_type(src_inner, target_inner, strict);
                    }

                    return True;
                }
            }
        }
    }

    if (
        isinstance(src_type, types.ClassType)
        and src_type.is_enum_class()
        and src_type.is_instantiable()
        and isinstance(dest_type, types.ClassType)
        and dest_type.is_builtin()
        and dest_type.shared.class_name in (
            "Sized",
            "Iterable",
            "Container",
            "Reversible",
            "Hashable"
        )
    ) {
        return True;
    }

    if (
        isinstance(dest_type, types.ClassType)
        and isinstance(src_type, types.ClassType)
        and src_type.is_class_instance()
        and dest_type.is_class_instance()
    ) {
        _protocol_methods: dict[str, str] = {
            "SupportsIndex": "__index__",
            "SupportsInt": "__int__",
            "SupportsFloat": "__float__",
            "SupportsComplex": "__complex__",
            "SupportsBytes": "__bytes__",
            "SupportsAbs": "__abs__",
            "SupportsRound": "__round__",
            "_SupportsRound1": "__round__",
            "_SupportsRound2": "__round__",
            "Sized": "__len__",
            "Hashable": "__hash__",
            "Iterable": "__iter__",
            "Iterator": "__next__",
            "Reversible": "__reversed__",
            "Container": "__contains__",

        };
        required_method = _protocol_methods.get(dest_type.shared.class_name);
        if required_method {
            if self._lookup_object_member(src_type, required_method) {
                return True;
            }
        }
    }
    if dest_type.is_class_instance() and src_type.is_class_instance() {
        assert isinstance(dest_type, types.ClassType);
        assert isinstance(src_type, types.ClassType);
        return self._assign_class(src_type, dest_type, strict);
    }
    return False;
}

impl TypeEvaluator.get_type_of_expression(
    node_: uni.Expr, expected_type: TypeBase | None = None
) -> TypeBase {
    if node_ is None {
        return types.UnknownType();
    }

    if isinstance(node_, uni.Ability) {
        return self.get_type_of_ability(node_);
    }

    if node_.type is not None {
        if expected_type is None
        or not isinstance(
            node_,
            (
                uni.ListVal,
                uni.DictVal,
                uni.SetVal,
                uni.TupleVal,
                uni.ListCompr,
                uni.LambdaExpr,

            )
        ) {
            if isinstance(node_.type, (types.UnionType, types.ClassType)) {
                if narrowed := self.get_narrowed_type_for_expr(
                    node_, node_.type, node_
                ) {
                    return narrowed;
                }
            }
            return node_.type;
        }
    }
    result = self._get_type_of_expression_core(node_, expected_type);
    if isinstance(result, types.UnknownType) {
        mod = node_.find_parent_of_type(uni.Module);
        if mod is None or not mod.is_raised_from_py {
            self.emit_diag(W1051, node_);
        }
    }
    node_.type = result;

    if isinstance(result, (types.UnionType, types.ClassType)) {
        if narrowed := self.get_narrowed_type_for_expr(node_, result, node_) {
            return narrowed;
        }
    }
    return result;
}

impl TypeEvaluator.pop_symbol_resolution(symbol: uni.Symbol) -> bool {
    popped_entry = self.symbol_resolution_stack.pop();
    assert popped_entry.symbol == symbol;
    return popped_entry.is_result_valid;
}

impl TypeEvaluator.push_symbol_resolution(symbol: uni.Symbol) -> bool {
    idx = self.get_index_of_symbol_resolution(symbol);
    if idx is not None {
        for i in range(idx, len(self.symbol_resolution_stack)) {
            entry_ = self.symbol_resolution_stack[i];
            entry_.is_result_valid = False;
        }
        return False;
    }
    self.symbol_resolution_stack.append(SymbolResolutionStackEntry(symbol=symbol));
    return True;
}

impl TypeEvaluator.get_index_of_symbol_resolution(symbol: uni.Symbol) -> int | None {
    for (i, entry_) in enumerate(self.symbol_resolution_stack) {
        if entry_.symbol == symbol {
            return i;
        }
    }
    return None;
}

impl TypeEvaluator._make_coroutine_type(inner: TypeBase) -> TypeBase {
    if self.prefetch.coroutine_class is None {
        return inner;
    }
    if type_utils.is_generator_family_type(inner) {
        return inner;
    }
    coro = self.prefetch.coroutine_class.clone_as_instance();
    coro.private.type_args = [types.AnyType(), types.AnyType(), inner];
    return coro;
}

impl TypeEvaluator._is_awaitable_type(t: TypeBase) -> bool {
    if not isinstance(t, types.ClassType) {
        return False;
    }
    if t.is_builtin(["Coroutine", "Awaitable"]) {
        return True;
    }
    return self.get_type_of_magic_method_call(t, "__await__", [], None) is not None;
}

impl TypeEvaluator._unwrap_awaitable_type(t: TypeBase, node_: uni.UniNode) -> TypeBase {
    if not isinstance(t, types.ClassType) {
        return t;
    }
    if t.is_builtin("Coroutine") {
        if t.private.type_args and len(t.private.type_args) >= 3 {
            return t.private.type_args[2];
        }
        return t;
    }
    if t.is_builtin("Awaitable") {
        if t.private.type_args and len(t.private.type_args) >= 1 {
            return t.private.type_args[0];
        }
        return t;
    }

    await_ret = self.get_type_of_magic_method_call(t, "__await__", [], node_);
    if await_ret is not None {
        gen_ret = type_utils.get_declared_generator_return_type(
            self._convert_to_instance(await_ret)
        );
        if gen_ret is not None {
            return gen_ret;
        }
    }
    return t;
}

impl TypeEvaluator._is_sv_async_call(expr: uni.FuncCall) -> bool {
    tgt = expr.target;
    if not isinstance(tgt, uni.Name) or tgt.sym is None {
        return False;
    }
    mod = expr.find_parent_of_type(uni.Module);
    if mod is None {
        return False;
    }
    mod_key = id(mod);
    syms = self._sv_async_syms_cache.get(mod_key);
    if syms is None {
        syms = set();
        for imp in mod.get_all_sub_nodes(uni.Import) {
            tok = imp._source_context_token();
            if tok is None or tok.name != Tok.KW_SERVER {
                continue;
            }

            if not imp.in_client_context() {
                continue;
            }
            for item in imp.items {
                if (
                    isinstance(item, uni.ModuleItem)
                    and isinstance(item.name, uni.Name)
                    and item.name.sym is not None
                    and item.name.sym.sym_type == SymbolType.ABILITY
                ) {
                    syms.add(id(item.name.sym));
                }
            }
        }
        self._sv_async_syms_cache[mod_key] = syms;
    }
    return id(tgt.sym) in syms;
}

impl TypeEvaluator._prefetch_types{
    def as_class_type(t: types.TypeBase) -> types.ClassType | None {
        if isinstance(t, types.ClassType) {
            return t;
        }
        return None;
    }

    def get_types_class(type_name: str) -> types.ClassType | None {
        return as_class_type(self._get_type_from_module(self.types_module, type_name));
    }
    def get_typing_class(type_name: str) -> types.ClassType | None {
        return as_class_type(self._get_type_from_module(self.typing_module, type_name));
    }
    def get_builtin_class(type_name: str) -> types.ClassType | None {
        return as_class_type(
            self._get_type_from_module(self.builtins_module, type_name)
        );
    }
    def get_enum_class(type_name: str) -> types.ClassType | None {
        return as_class_type(self._get_type_from_module(self.enum_module, type_name));
    }
    def get_jac_builtin_class(type_name: str) -> types.ClassType | None {
        return as_class_type(
            self._get_type_from_module(self.jac_builtins_module, type_name)
        );
    }

    self.prefetch.none_type_class = get_types_class("NoneType");
    self.prefetch.object_class = get_builtin_class("object");
    self.prefetch.type_class = get_builtin_class("type");
    self.prefetch.classmethod_class = get_builtin_class("classmethod");

    self.prefetch.coroutine_class = get_typing_class("Coroutine");
    self.prefetch.function_class = get_types_class("FunctionType");

    self.prefetch.tuple_class = get_builtin_class("tuple");
    self.prefetch.bool_class = get_builtin_class("bool");
    self.prefetch.int_class = get_builtin_class("int");
    self.prefetch.float_class = get_builtin_class("float");
    self.prefetch.str_class = get_builtin_class("str");
    self.prefetch.bytes_class = get_builtin_class("bytes");
    self.prefetch.dict_class = get_builtin_class("dict");
    self.prefetch.list_class = get_builtin_class("list");
    self.prefetch.slice_class = get_builtin_class("slice");
    self.prefetch.set_class = get_builtin_class("set");
    self.prefetch.enum_class = get_enum_class("Enum");
    if self.prefetch.enum_class {
        self.prefetch.enum_class.shared.is_enum_class = True;
    }
    self.prefetch.protocol_class = get_typing_class("Protocol");
    self.prefetch.any_class = get_typing_class("Any");

    self.prefetch.callable_class = get_typing_class("Callable");
    if self.prefetch.callable_class {
        self.prefetch.callable_class.private.alias_name = "Callable";
    }

    if self.prefetch.str_class {
        self.prefetch.literal_string_class = self._create_special_builtin_type(
            "LiteralString", self.prefetch.str_class
        );
    }

    self.prefetch.root_class = get_jac_builtin_class("Root");
    if self.prefetch.root_class {
        self.prefetch.root_class.shared.is_root_class = True;
    }
    self.prefetch.final_class = get_jac_builtin_class("Final");
    self.prefetch.node_class = get_jac_builtin_class("Node");
    self.prefetch.walker_class = get_jac_builtin_class("Walker");
    self.prefetch.path_class = get_jac_builtin_class("OPath");
    self.prefetch.jsx_element_class = get_jac_builtin_class("JsxElement");
    self.prefetch.html_common_props_class = get_jac_builtin_class("_HtmlCommonProps");
    self.prefetch.jsx_intrinsic_elements_class = get_jac_builtin_class(
        "_JsxIntrinsicElements"
    );
}

impl TypeEvaluator._load_stub_module(path: str) -> uni.Module {
    if not os.path.exists(path) {
        raise FileNotFoundError(f"Stub file not found at {path}");
    }

    resolved_path = str(Path(path).resolve());

    compiler = self.program._get_compiler();
    target_hub = compiler._resolve_program(resolved_path, self.program).mod.hub;
    if resolved_path in self.program.mod.hub {
        return self.program.mod.hub[resolved_path];
    }
    if resolved_path in target_hub {
        return target_hub[resolved_path];
    }
    file_content = read_file_with_encoding(path);
    uni_source = uni.Source(file_content, path);
    mod = PyastBuildPass(
        ir_in=uni.PythonModuleAst(py_ast.parse(file_content), orig_src=uni_source,),
        prog=self.program,
    ).ir_out;
    SymTabBuildPass(ir_in=mod, prog=self.program);
    target_hub[resolved_path] = mod;
    return mod;
}

impl TypeEvaluator.postinit -> None {
    self._BUILTINS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/builtins.pyi"
    );
    self._TYPING_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/typing.pyi"
    );
    self._TYPES_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/types.pyi"
    );
    self._JAC_BUILTINS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "jac_builtins.pyi"
    );
    self._DOM_TYPES_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "dom_types.pyi"
    );
    self._NA_BUILTINS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "na_builtins.pyi"
    );
    self._JS_GLOBALS_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "js_globals.pyi"
    );
    self._TYPING_AMBIENT_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "typing_ambient.pyi"
    );
    self._ENUM_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/enum.pyi"
    );

    self.prefetch = PrefetchedTypes();
    self._flow_pending_symbols = set();
    self._flow_pending_keys = set();

    self.typing_module = self._load_stub_module(self._TYPING_STUB_FILE_PATH);
    self.types_module = self._load_stub_module(self._TYPES_STUB_FILE_PATH);
    self.enum_module = self._load_stub_module(self._ENUM_STUB_FILE_PATH);

    self.prefetch.type_var_class = self._get_type_from_module(
        self.typing_module, "TypeVar"
    );
    self.prefetch.param_spec_class = self._get_type_from_module(
        self.typing_module, "ParamSpec"
    );
    self.prefetch.type_var_tuple_class = self._get_type_from_module(
        self.typing_module, "TypeVarTuple"
    );
    self.builtins_module = self._load_stub_module(self._BUILTINS_STUB_FILE_PATH);
    self.jac_builtins_module = self._load_stub_module(
        self._JAC_BUILTINS_STUB_FILE_PATH
    );
    self.dom_types_module = self._load_stub_module(self._DOM_TYPES_STUB_FILE_PATH);

    self.na_builtins_module = self._load_stub_module(self._NA_BUILTINS_STUB_FILE_PATH);

    self.js_globals_module = self._load_stub_module(self._JS_GLOBALS_STUB_FILE_PATH);

    def read_dunder_all(path: str) -> (set[str] | None) {
        try {
            py_tree = py_ast.parse(read_file_with_encoding(path));
            for node in py_tree.body {
                if (
                    isinstance(node, py_ast.Assign)
                    and len(node.targets) == 1
                    and isinstance(node.targets[0], py_ast.Name)
                    and node.targets[0].id == "__all__"
                    and isinstance(node.value, (py_ast.List, py_ast.Tuple))
                ) {
                    result: set[str] = set();
                    for elt in node.value.elts {
                        if (
                            isinstance(elt, py_ast.Constant)
                            and isinstance(elt.value, str)
                        ) {
                            result.add(elt.value);
                        }
                    }
                    return result;
                }
            }
        } except Exception {
            return None;
        }
        return None;
    }
    jac_allowed = read_dunder_all(self._JAC_BUILTINS_STUB_FILE_PATH);

    for (name, sym) in self.jac_builtins_module.names_in_scope.items() {
        if jac_allowed is not None and name not in jac_allowed {
            continue;
        }
        existing = self.builtins_module.names_in_scope.get(name);
        if existing is None or existing.imported {
            self.builtins_module.names_in_scope[name] = sym;
        }
    }

    for (name, sym) in self.dom_types_module.names_in_scope.items() {
        existing = self.builtins_module.names_in_scope.get(name);
        if existing is None or existing.imported {
            self.builtins_module.names_in_scope[name] = sym;
        }
    }

    def read_ambient_imports_by_module(path: str) -> dict[str, set[str]] {
        out: dict[str, set[str]] = {};
        try {
            allowed = read_dunder_all(path);
            if allowed is None {
                return out;
            }
            py_tree = py_ast.parse(read_file_with_encoding(path));
            for node in py_tree.body {
                if (isinstance(node, py_ast.ImportFrom) and node.module is not None) {
                    public = {
                        (alias.asname or alias.name) for alias in node.names
                    } & allowed;
                    if public {
                        out[node.module] = out.get(node.module, set()) | public;
                    }
                }
            }
        } except Exception {
            return {};
        }
        return out;
    }
    raw_groups = read_ambient_imports_by_module(self._TYPING_AMBIENT_STUB_FILE_PATH);
    typing_ambient_flat: set[str] = set();
    for names in raw_groups.values() {
        typing_ambient_flat = typing_ambient_flat | names;
    }

    self.ambient_typing_names_by_module = raw_groups;
    self.ambient_typing_names_by_module["typing"] = typing_ambient_flat;
    for typing_name in typing_ambient_flat {
        typing_sym = self.typing_module.names_in_scope.get(typing_name);
        if typing_sym is None {
            continue;
        }
        existing_typing = self.builtins_module.names_in_scope.get(typing_name);
        if existing_typing is None or existing_typing.imported {
            self.builtins_module.names_in_scope[typing_name] = typing_sym;
        }
    }
    self._prefetch_types();
}

def _find_cfg_node_for(at_node: uni.UniNode) -> uni.UniCFGNode | None {
    cur: uni.UniNode | None = at_node;
    while cur is not None {
        if isinstance(cur, uni.UniCFGNode) and not isinstance(cur, uni.InnerCompr) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl TypeEvaluator.get_narrowed_type(
    symbol: uni.Symbol, at_node: uni.UniNode
) -> TypeBase | None {
    import from jaclang.compiler.type_system.type_evaluator { NarrowingTarget }
    sym_id = id(symbol);

    if sym_id in self._and_narrowing_overrides {
        return self._and_narrowing_overrides[sym_id];
    }
    if sym_id in self._flow_pending_symbols {
        return None;
    }
    symbol_type = self.get_type_of_symbol(symbol);
    if not isinstance(
        symbol_type,
        (types.UnionType, types.ClassType, types.UnknownType, types.AnyType)
    ) {
        return None;
    }
    self._flow_pending_symbols.add(sym_id);
    try {
        narrowing_target = NarrowingTarget(
            key=symbol.sym_name, declared_type=symbol_type, symbol=symbol
        );
        flow_node = _find_cfg_node_for(at_node);
        if flow_node is not None {
            return self._get_type_from_flow_node(narrowing_target, flow_node, set());
        }
        return None;
    } finally {
        self._flow_pending_symbols.discard(sym_id);
    }
}

impl TypeEvaluator.get_narrowed_type_for_expr(
    expr: uni.Expr, declared_type: TypeBase, at_node: uni.UniNode
) -> TypeBase | None {
    import from jaclang.compiler.type_system.type_evaluator { NarrowingTarget }
    import from jaclang.compiler.symbol_utils { reference_key_deps }
    if not isinstance(declared_type, (types.UnionType, types.ClassType)) {
        return None;
    }
    key = self.create_key_for_reference(expr);
    if key is None {
        return None;
    }
    if key in self._flow_pending_keys {
        return None;
    }
    self._flow_pending_keys.add(key);
    try {
        narrowing_target = NarrowingTarget(
            key=key,
            declared_type=declared_type,
            deps=frozenset(reference_key_deps(expr)),
        );
        flow_node = _find_cfg_node_for(at_node);
        if flow_node is not None {
            return self._get_type_from_flow_node(narrowing_target, flow_node, set());
        }
        return None;
    } finally {
        self._flow_pending_keys.discard(key);
    }
}

impl TypeEvaluator._get_type_from_flow_node(
    target: NarrowingTarget, flow_node: uni.UniCFGNode, visited: set
) -> TypeBase | None {
    import from jaclang.compiler.type_system.type_evaluator { NarrowingTarget }
    key = target.key;

    cache_key = (id(flow_node), id(target.symbol))
        if target.symbol is not None
        else (id(flow_node), key);
    if cache_key in self._flow_node_type_cache {
        return self._flow_node_type_cache[cache_key];
    }
    flow_node_id = id(flow_node);
    if flow_node_id in visited {
        return None;
    }

    if len(visited) > 64 {
        self._flow_node_type_cache[cache_key] = None;
        return None;
    }
    visited.add(flow_node_id);
    if not flow_node.bb_in {
        self._flow_node_type_cache[cache_key] = None;
        visited.discard(flow_node_id);
        return None;
    }

    is_loop_header: bool = isinstance(
        flow_node, (uni.InForStmt, uni.IterForStmt, uni.WhileStmt)
    );
    incoming_types: list[TypeBase] = [];
    has_unnarrowed_pred: bool = False;
    for pred in flow_node.bb_in {
        if pred is flow_node {
            has_unnarrowed_pred = True;
            continue;
        }

        if isinstance(pred, uni.CfgExpr) and not pred.bb_in {
            continue;
        }
        if is_loop_header {
            ancestor: uni.UniNode | None = None;
            if isinstance(flow_node, uni.InForStmt) {
                ancestor = pred.find_parent_of_type(uni.InForStmt);
            } elif isinstance(flow_node, uni.IterForStmt) {
                ancestor = pred.find_parent_of_type(uni.IterForStmt);
            } else {
                ancestor = pred.find_parent_of_type(uni.WhileStmt);
            }
            if ancestor is flow_node {
                continue;
            }
        }

        if key not in pred.affected_symbols and not isinstance(pred, uni.CfgExpr) {
            has_unnarrowed_pred = True;
            continue;
        }

        pred_narrowed = self._get_type_from_flow_node(target, pred, visited);

        if isinstance(pred, uni.CfgExpr) {
            predicate = self._find_predicate_for(target, pred.expr);
            if predicate is not None {
                is_true_edge = flow_node is pred.sc_true_target;
                is_false_edge = flow_node is pred.sc_false_target;
                if is_true_edge or is_false_edge {
                    narrowed = self._apply_narrowing(
                        predicate, pred_narrowed, is_true_edge, target
                    );
                    if narrowed is not None {
                        incoming_types.append(narrowed);
                    } elif pred_narrowed is not None {
                        incoming_types.append(pred_narrowed);
                    } else {
                        has_unnarrowed_pred = True;
                    }
                    continue;
                }
            }
        }

        if isinstance(pred, uni.IfStmt) and not isinstance(flow_node, uni.CfgExpr) {
            predicate = self._find_predicate_for(target, pred.condition);
            if predicate is not None {
                edge_kind = self._classify_edge(pred, flow_node);
                if edge_kind == "true" {
                    narrowed = self._apply_narrowing(
                        predicate, pred_narrowed, True, target
                    );
                    if narrowed is not None {
                        incoming_types.append(narrowed);
                    } else {
                        has_unnarrowed_pred = True;
                    }
                    continue;
                } elif edge_kind == "false" {
                    narrowed = self._apply_narrowing(
                        predicate, pred_narrowed, False, target
                    );
                    if narrowed is not None {
                        incoming_types.append(narrowed);
                    } else {
                        has_unnarrowed_pred = True;
                    }
                    continue;
                }
            }
        }

        if isinstance(pred, uni.WhileStmt) and not isinstance(flow_node, uni.CfgExpr) {
            predicate = self._find_predicate_for(target, pred.condition);
            if predicate is not None and pred.body and flow_node is pred.body[0] {
                narrowed = self._apply_narrowing(
                    predicate, pred_narrowed, True, target
                );
                if narrowed is not None {
                    incoming_types.append(narrowed);
                } else {
                    has_unnarrowed_pred = True;
                }
                continue;
            }
        }

        if isinstance(pred, uni.AssertStmt) {
            predicate = self._find_predicate_for(target, pred.condition);
            if predicate is not None {
                narrowed = self._apply_narrowing(
                    predicate, pred_narrowed, True, target
                );
                if narrowed is not None {
                    incoming_types.append(narrowed);
                } else {
                    has_unnarrowed_pred = True;
                }
                continue;
            }
        }

        if isinstance(pred, uni.Assignment) and pred.value {
            import from jaclang.compiler.symbol_utils {
                collect_assignment_target_keys,
                find_destructure_index_path,
            }
            target_key_matched = False;
            flat_target_matched = False;
            destructure_path: list[int] | None = None;
            for t in pred.target {
                written_keys = collect_assignment_target_keys(t);
                if key in written_keys {
                    target_key_matched = True;
                    if (
                        (isinstance(t, uni.Name) and t.value == key)
                        or (
                            isinstance(t, uni.AtomTrailer)
                            and t.is_attr
                            and self.create_key_for_reference(t) == key
                        )
                    ) {
                        flat_target_matched = True;
                    } else {
                        destructure_path = find_destructure_index_path(t, key);
                    }
                    break;
                }

                if target.deps and (target.deps & written_keys) {
                    target_key_matched = True;
                    break;
                }
            }
            if target_key_matched {
                narrowed_from_assignment: TypeBase | None = None;
                assigned_type: TypeBase | None = None;
                if flat_target_matched {
                    assigned_type = self.get_type_of_expression(pred.value);
                } elif destructure_path is not None and len(destructure_path) > 0 {
                    assigned_type = self._extract_tuple_element_type_path(
                        self.get_type_of_expression(pred.value), destructure_path
                    );
                }
                if (
                    assigned_type is not None
                    and not isinstance(assigned_type, types.UnknownType)
                ) {
                    declared_type = target.declared_type;

                    if self.is_none_type(declared_type) {
                        narrowed_from_assignment = assigned_type;
                    } elif (
                        self.assign_type(assigned_type, declared_type)
                        and not self.assign_type(declared_type, assigned_type)
                    ) {
                        narrowed_from_assignment = assigned_type;
                    } elif (
                        flat_target_matched
                        and self.is_explicit_any(assigned_type)
                        and self._union_contains_none(declared_type)
                    ) {
                        none_cls = self.prefetch.none_type_class;
                        if none_cls is not None {
                            narrowed_from_assignment = self.exclude_type_from_union(
                                declared_type, self._convert_to_instance(none_cls)
                            );
                        }
                    }
                }
                if narrowed_from_assignment is not None {
                    incoming_types.append(narrowed_from_assignment);
                } else {
                    has_unnarrowed_pred = True;
                }
                continue;
            }
        }

        if isinstance(pred, uni.MatchStmt) {
            match_key = self.create_key_for_reference(pred.target);
            if match_key is not None and match_key == key {
                match_case: uni.MatchCase | None;
                if isinstance(flow_node, uni.MatchCase) {
                    match_case = flow_node;
                } else {
                    match_case = flow_node.find_parent_of_type(uni.MatchCase);
                }
                if match_case is not None and match_case.pattern {
                    pattern_type = self._get_type_from_match_pattern(
                        match_case.pattern
                    );
                    if pattern_type is not None {
                        incoming_types.append(pattern_type);
                        continue;
                    }
                }
            }
        }

        if pred_narrowed is not None {
            incoming_types.append(pred_narrowed);
        } else {
            has_unnarrowed_pred = True;
        }
    }

    incoming_types = [
        t
        for t in incoming_types
        if not isinstance(t, types.NeverType)
    ];

    result: TypeBase | None = None;
    if len(incoming_types) == 0 {
        result = None;
    } elif has_unnarrowed_pred {
        result = None;
    } elif len(incoming_types) == 1 {
        result = incoming_types[0];
    } else {
        result = self._union_narrowed_types(incoming_types);
    }
    self._flow_node_type_cache[cache_key] = result;
    visited.discard(flow_node_id);
    return result;
}

impl TypeEvaluator._classify_edge(pred: uni.IfStmt, succ: uni.UniCFGNode) -> str {
    if pred.body and succ is pred.body[0] {
        return "true";
    }

    if isinstance(pred.else_body, uni.ElseIf) and succ is pred.else_body {
        return "false";
    }
    if isinstance(pred.else_body, uni.ElseStmt)
    and pred.else_body.body
    and succ is pred.else_body.body[0] {
        return "false";
    }

    cur: uni.UniNode | None = succ;
    while cur is not None and cur is not pred {
        if pred.else_body is not None and cur is pred.else_body {
            return "false";
        }
        cur = cur.parent;
    }
    if cur is pred {
        return "true";
    }

    body_empty = not pred.body;
    else_empty = isinstance(pred.else_body, uni.ElseStmt) and not pred.else_body.body;
    has_else_branch = pred.else_body is not None;
    if body_empty and (else_empty or not has_else_branch) {
        return "unconditional";
    }
    if body_empty {
        return "true";
    }
    if else_empty or not has_else_branch {
        return "false";
    }
    return "unconditional";
}


impl TypeEvaluator.create_key_for_reference(expr: uni.Expr) -> str | None {
    if isinstance(expr, uni.AtomUnit) and expr.value {
        return self.create_key_for_reference(expr.value);
    }
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.AtomTrailer) and expr.is_attr {
        base_key = self.create_key_for_reference(expr.target);
        if base_key and isinstance(expr.right, uni.Name) {
            return f"{base_key}.{expr.right.value}";
        }
    }
    if isinstance(expr, uni.AtomTrailer) and not expr.is_attr {
        base_key = self.create_key_for_reference(expr.target);
        if base_key and isinstance(expr.right, uni.IndexSlice) {
            suffix = int_subscript_suffix(expr.right);
            if suffix {
                return f"{base_key}{suffix}";
            }
        }
    }

    if (
        isinstance(expr, uni.BinaryExpr)
        and isinstance(expr.op, uni.Token)
        and expr.op.name == "WALRUS_EQ"
        and isinstance(expr.left, uni.Name)
    ) {
        return expr.left.value;
    }
    return None;
}

impl TypeEvaluator._find_symbol_by_key(
    key: str, condition: uni.Expr
) -> uni.Symbol | None {
    if isinstance(condition, uni.FuncCall) and condition.params {
        first_arg = condition.params[0];
        if isinstance(first_arg, uni.Name) and first_arg.sym {
            return first_arg.sym;
        }
    }
    return None;
}

impl TypeEvaluator.classify_condition(condition: uni.Expr) -> ConditionInfo | None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    import from jaclang.compiler.type_system.type_evaluator {
        ConditionInfo,
        NarrowingKind
    }

    if isinstance_info := self._extract_isinstance_info(condition) {
        (key, narrow_type) = isinstance_info;
        return ConditionInfo(
            kind=NarrowingKind.ISINSTANCE, key=key, narrow_type=narrow_type
        );
    }

    if callable_key := self._extract_callable_info(condition) {
        return ConditionInfo(kind=NarrowingKind.CALLABLE, key=callable_key,);
    }

    if hasattr_info := self._extract_hasattr_info(condition) {
        (h_key, h_attr) = hasattr_info;
        return ConditionInfo(kind=NarrowingKind.HASATTR, key=h_key, attr_name=h_attr);
    }

    if (
        isinstance(condition, uni.CompareExpr)
        and len(condition.ops) == 1
        and len(condition.rights) == 1
        and isinstance(condition.rights[0], uni.Null)
    ) {
        narrowing_key = self.create_key_for_reference(condition.left);
        if narrowing_key is not None {
            op_name = condition.ops[0].name;
            if op_name == Tok.KW_IS or op_name == Tok.EE {
                return ConditionInfo(kind=NarrowingKind.NONE_IS, key=narrowing_key);
            } elif op_name == Tok.KW_ISN or op_name == Tok.NE {
                return ConditionInfo(kind=NarrowingKind.NONE_IS_NOT, key=narrowing_key);
            }
        }
    }

    if (
        isinstance(condition, uni.CompareExpr)
        and len(condition.ops) == 1
        and len(condition.rights) == 1
    ) {
        left_key = self.create_key_for_reference(condition.left);
        right_expr = condition.rights[0];
        if left_key is not None
        and isinstance(right_expr, (uni.String, uni.Int, uni.Float, uni.Bool)) {
            literal_type = self.get_type_of_expression(right_expr);
            op_name = condition.ops[0].name;
            if op_name == Tok.EE {
                return ConditionInfo(
                    kind=NarrowingKind.LITERAL_EQ,
                    key=left_key,
                    narrow_type=literal_type
                );
            } elif op_name == Tok.NE {
                return ConditionInfo(
                    kind=NarrowingKind.LITERAL_NE,
                    key=left_key,
                    narrow_type=literal_type
                );
            }
        }
    }

    if isinstance(condition, (uni.Name, uni.AtomTrailer)) {
        narrowing_key = self.create_key_for_reference(condition);
        if narrowing_key is not None {
            return ConditionInfo(kind=NarrowingKind.TRUTHINESS, key=narrowing_key);
        }
    }

    if (
        isinstance(condition, uni.BinaryExpr)
        and isinstance(condition.op, uni.Token)
        and condition.op.name == "WALRUS_EQ"
        and isinstance(condition.left, uni.Name)
    ) {
        return ConditionInfo(kind=NarrowingKind.TRUTHINESS, key=condition.left.value,);
    }
    return None;
}


impl TypeEvaluator._find_predicate_for(
    target: NarrowingTarget, condition: uni.Expr
) -> NarrowingPredicate | None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    import from jaclang.compiler.type_system.type_evaluator {
        NarrowingKind,
        NarrowingPredicate,
        NarrowingTarget
    }
    key = target.key;
    if isinstance(condition, uni.CfgExpr) {
        return self._find_predicate_for(target, condition.expr);
    }

    if isinstance(condition, uni.AtomUnit) and isinstance(condition.value, uni.Expr) {
        return self._find_predicate_for(target, condition.value);
    }

    if (
        isinstance(condition, uni.UnaryExpr)
        and isinstance(condition.op, uni.Token)
        and condition.op.name == Tok.NOT
    ) {
        inner_pred = self._find_predicate_for(target, condition.operand);
        if inner_pred is not None {
            return NarrowingPredicate(
                key=inner_pred.key,
                narrow_type=inner_pred.narrow_type,
                is_inverted=not inner_pred.is_inverted,
                attr_name=inner_pred.attr_name
            );
        }
        return None;
    }

    if isinstance(condition, uni.BoolExpr) {
        match condition.op.name {
            case Tok.KW_AND:
                all_preds = [
                    p
                    for val in condition.values
                    if (p := self._find_predicate_for(target, val)) is not None
                ];
                if not all_preds {
                    return None;
                }

                positive_preds = [
                    p
                    for p in all_preds
                    if not p.is_inverted
                ];
                if not positive_preds {
                    return all_preds[0];
                }

                most_specific = positive_preds[0];
                for pred in positive_preds[1:] {
                    if (
                        isinstance(pred.narrow_type, types.ClassType)
                        and isinstance(most_specific.narrow_type, types.ClassType)
                        and self.is_sub_class(
                            most_specific.narrow_type, pred.narrow_type
                        )
                    ) {
                        most_specific = pred;
                    }
                }
                return most_specific;

            case Tok.KW_OR:
                all_preds = [
                    self._find_predicate_for(target, val) for val in condition.values
                ];
                matched = [
                    p
                    for p in all_preds
                    if p is not None
                ];
                if not matched {
                    return None;
                }

                positive = [
                    p
                    for p in matched
                    if not p.is_inverted
                ];
                if len(positive) == len(matched) {
                    narrowed_types: list[types.TypeBase] = [
                        p.narrow_type for p in positive
                    ];
                    if len(narrowed_types) == 1 {
                        union_type = narrowed_types[0];
                    } else {
                        union_type = types.UnionType(types=narrowed_types);
                    }
                    return NarrowingPredicate(
                        key=key, narrow_type=union_type, is_inverted=False
                    );
                }

                for p in matched {
                    if p.key == key {
                        return p;
                    }
                }
                return matched[0];

        }
    }

    info = self.classify_condition(condition);
    if info is not None and info.key == key {
        match info.kind {
            case NarrowingKind.ISINSTANCE:
                return NarrowingPredicate(
                    key=key, narrow_type=info.narrow_type, is_inverted=False
                );

            case NarrowingKind.CALLABLE:
                expr_type = self.get_type_of_expression(condition.params[0]);
                callable_type = self._filter_union_to_callables(expr_type);
                if not isinstance(callable_type, types.NeverType) {
                    return NarrowingPredicate(
                        key=key, narrow_type=callable_type, is_inverted=False
                    );
                }

            case NarrowingKind.HASATTR:
                return NarrowingPredicate(
                    key=key,
                    narrow_type=target.declared_type,
                    is_inverted=False,
                    attr_name=info.attr_name
                );

            case NarrowingKind.NONE_IS:
                if self.prefetch and self.prefetch.none_type_class {
                    none_inst = self._convert_to_instance(
                        self.prefetch.none_type_class
                    );
                    return NarrowingPredicate(
                        key=key, narrow_type=none_inst, is_inverted=False
                    );
                }

            case NarrowingKind.NONE_IS_NOT:
                if self.prefetch and self.prefetch.none_type_class {
                    none_inst = self._convert_to_instance(
                        self.prefetch.none_type_class
                    );
                    return NarrowingPredicate(
                        key=key, narrow_type=none_inst, is_inverted=True
                    );
                }

            case NarrowingKind.LITERAL_EQ:
                return NarrowingPredicate(
                    key=key, narrow_type=info.narrow_type, is_inverted=False
                );

            case NarrowingKind.LITERAL_NE:
                return NarrowingPredicate(
                    key=key, narrow_type=info.narrow_type, is_inverted=True
                );

            case NarrowingKind.TRUTHINESS:
                if self.prefetch and self.prefetch.none_type_class {
                    if (
                        isinstance(condition, uni.BinaryExpr)
                        and isinstance(condition.op, uni.Token)
                        and condition.op.name == "WALRUS_EQ"
                    ) {
                        check_type = self.get_type_of_expression(condition.right);
                    } else {
                        check_type = target.declared_type;
                    }
                    if self._union_contains_none(check_type) {
                        none_inst = self._convert_to_instance(
                            self.prefetch.none_type_class
                        );
                        return NarrowingPredicate(
                            key=key, narrow_type=none_inst, is_inverted=True
                        );
                    }
                }

        }
    }
    return None;
}

impl TypeEvaluator._apply_narrowing(
    predicate: NarrowingPredicate,
    incoming: TypeBase | None,
    is_true_branch: bool,
    target: NarrowingTarget
) -> TypeBase | None {
    import from jaclang.compiler.type_system.type_evaluator {
        NarrowingPredicate,
        NarrowingTarget
    }

    is_positive: bool = (
        is_true_branch if not predicate.is_inverted else not is_true_branch
    );

    if predicate.attr_name is not None {
        base_type: TypeBase = (
            incoming if incoming is not None else target.declared_type
        );
        return self._filter_union_for_hasattr(
            base_type, predicate.attr_name, is_positive
        );
    }
    if is_positive {
        base_type: TypeBase;
        if incoming is not None {
            base_type = incoming;
        } else {
            base_type = target.declared_type;
        }

        filtered = self._filter_union_for_isinstance(base_type, predicate.narrow_type);
        if filtered is not None {
            return filtered;
        }

        return predicate.narrow_type;
    } else {
        base_type: TypeBase;
        if incoming is not None {
            base_type = incoming;
        } else {
            base_type = target.declared_type;
        }
        result = self.exclude_type_from_union(base_type, predicate.narrow_type);
        if result is base_type {
            return incoming;
        }
        return result;
    }
}

impl TypeEvaluator._filter_union_for_isinstance(
    base_type: TypeBase, target_type: TypeBase
) -> TypeBase | None {
    matching: list[TypeBase] = [];

    if isinstance(base_type, types.UnionType) and base_type.types {
        for t in base_type.types {
            if self._type_matches_isinstance(t, target_type) {
                matching.append(t);
            }
        }
    } else {
        if self._type_matches_isinstance(base_type, target_type) {
            matching.append(base_type);
        }
    }
    if len(matching) == 0 {
        return None;
    } elif len(matching) == 1 {
        return matching[0];
    } else {
        return types.UnionType(types=matching);
    }
}

impl TypeEvaluator._type_matches_isinstance(
    t: TypeBase, target_type: TypeBase
) -> bool {
    if isinstance(target_type, types.UnionType) and target_type.types {
        for target_t in target_type.types {
            if self._type_matches_isinstance(t, target_t) {
                return True;
            }
        }
        return False;
    }

    if isinstance(t, types.ClassType) and isinstance(target_type, types.ClassType) {
        if t.shared == target_type.shared {
            return True;
        }

        if self.is_sub_class(target_type, t) {
            return True;
        }
    }

    if t is target_type {
        return True;
    }
    return False;
}

impl TypeEvaluator._type_has_attribute(t: TypeBase, attr_name: str) -> bool {
    if not isinstance(t, types.ClassType) {
        return False;
    }
    if self._lookup_class_member(t, attr_name) is not None {
        return True;
    }
    if self._get_getattr_return_type(t) is not None {
        return True;
    }
    return False;
}

impl TypeEvaluator._filter_union_for_hasattr(
    base_type: TypeBase, attr_name: str, keep_with_attr: bool
) -> TypeBase | None {
    matching: list[TypeBase] = [];
    if isinstance(base_type, types.UnionType) and base_type.types {
        for t in base_type.types {
            if self._type_has_attribute(t, attr_name) == keep_with_attr {
                matching.append(t);
            }
        }
    } else {
        if self._type_has_attribute(base_type, attr_name) == keep_with_attr {
            matching.append(base_type);
        }
    }
    if len(matching) == 0 {
        return None;
    } elif len(matching) == 1 {
        return matching[0];
    } else {
        return types.UnionType(types=matching);
    }
}

impl TypeEvaluator._union_narrowed_types(types_list: list) -> TypeBase {
    if len(types_list) == 0 {
        return types.NeverType();
    }
    if len(types_list) == 1 {
        return types_list[0];
    }

    flat: list[TypeBase] = [];
    for t in types_list {
        if isinstance(t, types.UnionType) and t.types {
            flat.extend(t.types);
        } else {
            flat.append(t);
        }
    }

    unique: list[TypeBase] = [];
    seen_shared: set = set();
    for t in flat {
        if isinstance(t, types.ClassType) {
            shared_id = id(t.shared);
            if shared_id not in seen_shared {
                seen_shared.add(shared_id);
                unique.append(t);
            }
        } else {
            unique.append(t);
        }
    }
    if len(unique) == 1 {
        return unique[0];
    }
    return types.UnionType(types=unique);
}

impl TypeEvaluator.exclude_type_from_union(
    original: TypeBase, to_exclude: TypeBase
) -> TypeBase {
    if isinstance(original, types.UnionType) and original.types {
        exclude_shareds: set = set();
        exclude_ids: set = set();
        to_exclude_list: list[TypeBase] = [];
        if isinstance(to_exclude, types.UnionType) and to_exclude.types {
            to_exclude_list = to_exclude.types;
        } else {
            to_exclude_list = [to_exclude];
        }
        for excl_t in to_exclude_list {
            if isinstance(excl_t, types.ClassType) {
                exclude_shareds.add(excl_t.shared.canonical_key() or id(excl_t.shared));
            } else {
                exclude_ids.add(id(excl_t));
            }
        }
        remaining: list[TypeBase] = [];
        for t in original.types {
            if isinstance(t, types.ClassType) {
                if (t.shared.canonical_key() or id(t.shared)) in exclude_shareds {
                    continue;
                }
            } elif id(t) in exclude_ids {
                continue;
            }
            remaining.append(t);
        }
        if len(remaining) == 0 {
            return types.NeverType();
        } elif len(remaining) == 1 {
            return remaining[0];
        } else {
            return types.UnionType(types=remaining);
        }
    }

    if isinstance(original, types.ClassType)
    and isinstance(to_exclude, types.ClassType)
    and original.shared.same_class(to_exclude.shared) {
        return types.NeverType();
    }

    if original is to_exclude {
        return types.NeverType();
    }
    return original;
}

impl TypeEvaluator._get_type_from_match_pattern(
    pattern: uni.MatchPattern
) -> TypeBase | None {
    if isinstance(pattern, uni.MatchArch) {
        class_type = self.get_type_of_expression(pattern.name);
        return self._convert_to_instance(class_type);
    }

    if isinstance(pattern, uni.MatchOr) and pattern.patterns {
        pattern_types: list[TypeBase] = [];
        for sub_pattern in pattern.patterns {
            sub_type = self._get_type_from_match_pattern(sub_pattern);
            if sub_type is not None {
                pattern_types.append(sub_type);
            }
        }
        if len(pattern_types) == 0 {
            return None;
        } elif len(pattern_types) == 1 {
            return pattern_types[0];
        } else {
            return types.UnionType(types=pattern_types);
        }
    }

    if isinstance(pattern, uni.MatchAs) and pattern.pattern {
        return self._get_type_from_match_pattern(pattern.pattern);
    }

    if isinstance(pattern, uni.MatchWild) {
        return None;
    }

    return None;
}

impl TypeEvaluator._union_contains_none(union_type: TypeBase) -> bool {
    if not isinstance(union_type, types.UnionType) or not union_type.types {
        return False;
    }
    if not self.prefetch or not self.prefetch.none_type_class {
        return False;
    }
    none_shared = self.prefetch.none_type_class.shared;
    for t in union_type.types {
        if isinstance(t, types.ClassType) and t.shared == none_shared {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator._extract_isinstance_info(
    condition: uni.Expr
) -> tuple[str, types.TypeBase] | None {
    if not isinstance(condition, uni.FuncCall) {
        return None;
    }
    if not isinstance(condition.target, uni.Name)
    or condition.target.value != "isinstance" {
        return None;
    }
    if not condition.params or len(condition.params) != 2 {
        return None;
    }

    narrowing_key = self.create_key_for_reference(condition.params[0]);
    if narrowing_key is None {
        return None;
    }

    type_arg = condition.params[1];

    if isinstance(type_arg, uni.TupleVal) {
        type_list: list[types.TypeBase] = [];
        for t_expr in type_arg.values {
            type_list.append(
                self._convert_to_instance(self.get_type_of_expression(t_expr))
            );
        }
        if not type_list {
            return None;
        }
        narrowed = type_list[0]
            if len(type_list) == 1
            else types.UnionType(types=type_list);
        return (narrowing_key, narrowed);
    }

    return (
        narrowing_key,
        self._convert_to_instance(self.get_type_of_expression(type_arg))
    );
}

impl TypeEvaluator._extract_callable_info(condition: uni.Expr) -> str | None {
    if not isinstance(condition, uni.FuncCall) {
        return None;
    }
    if not isinstance(condition.target, uni.Name)
    or condition.target.value != "callable" {
        return None;
    }
    if not condition.params or len(condition.params) != 1 {
        return None;
    }
    return self.create_key_for_reference(condition.params[0]);
}

impl TypeEvaluator._extract_hasattr_info(
    condition: uni.Expr
) -> tuple[str, str] | None {
    if not isinstance(condition, uni.FuncCall) {
        return None;
    }
    if not isinstance(condition.target, uni.Name)
    or condition.target.value != "hasattr" {
        return None;
    }
    if not condition.params or len(condition.params) != 2 {
        return None;
    }
    narrowing_key = self.create_key_for_reference(condition.params[0]);
    if narrowing_key is None {
        return None;
    }

    attr_arg = condition.params[1];
    if (
        isinstance(attr_arg, uni.MultiString)
        and len(attr_arg.strings) == 1
        and isinstance(attr_arg.strings[0], uni.String)
    ) {
        str_node = attr_arg.strings[0];
    } elif isinstance(attr_arg, uni.String) {
        str_node = attr_arg;
    } else {
        return None;
    }
    attr_name = str_node.lit_value;
    if not isinstance(attr_name, str) {
        return None;
    }
    return (narrowing_key, attr_name);
}

impl TypeEvaluator._is_callable_type(t: types.TypeBase) -> bool {
    if isinstance(t, types.FunctionType) {
        return True;
    }
    if isinstance(t, types.ClassType) {
        if (
            self.prefetch
            and self.prefetch.callable_class
            and t.shared == self.prefetch.callable_class.shared
        ) {
            return True;
        }

        if t.shared.symbol_table is not None {
            if t.shared.symbol_table.lookup("__call__", deep=False) is not None {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._filter_union_to_callables(
    union_type: types.TypeBase
) -> types.TypeBase {
    if isinstance(union_type, types.UnionType) and union_type.types {
        callables: list[types.TypeBase] = [
            t
            for t in union_type.types
            if self._is_callable_type(t)
        ];
        if len(callables) == 0 {
            return types.NeverType();
        } elif len(callables) == 1 {
            return callables[0];
        } else {
            return types.UnionType(types=callables);
        }
    }
    if self._is_callable_type(union_type) {
        return union_type;
    }
    return types.NeverType();
}

impl TypeEvaluator._is_type_alias_annotation(
    annotation_type: types.TypeBase, tag_expr: uni.Expr
) -> bool {
    if not self.prefetch or not self.prefetch.callable_class {
        return False;
    }

    is_special_form = (
        isinstance(annotation_type, types.ClassType)
        and annotation_type.shared == self.prefetch.callable_class.shared
    );

    if is_special_form and isinstance(tag_expr, uni.Name) {
        return tag_expr.value == "TypeAlias";
    }

    if (
        isinstance(annotation_type, types.UnknownType)
        and isinstance(tag_expr, uni.Name)
    ) {
        return tag_expr.value == "TypeAlias";
    }
    return False;
}

impl TypeEvaluator._resolve_type_alias_rhs(value: uni.Expr) -> types.TypeBase {
    if isinstance(value, uni.String) and isinstance(value.lit_value, str) {
        resolved = self._try_resolve_forward_ref(value);
        if resolved is not None {
            return resolved;
        }

        scope = value.find_parent_of_type(uni.UniScopeNode);
        if scope {
            parsed = self._resolve_string_type_expr(value.lit_value, scope);
            if parsed is not None {
                return parsed;
            }
        }
        return types.UnknownType();
    }
    if (
        isinstance(value, uni.MultiString)
        and value.strings
        and isinstance(value.strings[0], uni.String)
        and isinstance(value.strings[0].lit_value, str)
    ) {
        resolved = self._try_resolve_forward_ref(value.strings[0]);
        if resolved is not None {
            return resolved;
        }
        scope = value.find_parent_of_type(uni.UniScopeNode);
        if scope {
            parsed = self._resolve_string_type_expr(value.strings[0].lit_value, scope);
            if parsed is not None {
                return parsed;
            }
        }
        return types.UnknownType();
    }

    mod = value.find_parent_of_type(uni.Module);
    is_stub = mod is not None and mod.is_raised_from_py;
    if is_stub and self._pass is not None {
        pass_ref = self._pass;
        errors_before = len(pass_ref.errors_had);
        prog_errors_before = len(pass_ref.prog.errors_had);
        result = self.get_type_of_expression(value);

        del pass_ref.errors_had[errors_before:];
        del pass_ref.prog.errors_had[prog_errors_before:];
        return result;
    }
    return self.get_type_of_expression(value);
}

impl TypeEvaluator._resolve_string_type_expr(
    type_str: str, scope: uni.UniScopeNode
) -> types.TypeBase | None {
    import from ast { parse as _parse }
    try {
        tree = _parse(type_str, mode='eval');
    } except Exception {
        return None;
    }
    try {
        return self._resolve_py_ast_type_node(tree.body, scope);
    } except Exception {
        return None;
    }
}

impl TypeEvaluator._resolve_py_ast_type_node(
    ast_node: object, scope: uni.UniScopeNode
) -> types.TypeBase | None {
    import from ast { Name as _N }
    import from ast { Constant as _C }
    import from ast { BinOp as _BO }
    import from ast { BitOr as _BOR }
    import from ast { Subscript as _SS }
    import from ast { Tuple as _TU }
    import from ast { List as _LI }
    import from ast { Attribute as _AT }

    if isinstance(ast_node, _N) {
        sym = type_utils.lookup_symtab(scope, ast_node.id, self.builtins_module);
        if not sym {
            return None;
        }
        sym = self.resolve_imported_symbols(sym);
        return self.get_type_of_symbol(sym);
    }

    if isinstance(ast_node, _C) and ast_node.value is None {
        if self.prefetch and self.prefetch.none_type_class {
            return self.prefetch.none_type_class;
        }
        return None;
    }

    if isinstance(ast_node, _BO) and isinstance(ast_node.op, _BOR) {
        left = self._resolve_py_ast_type_node(ast_node.left, scope);
        right = self._resolve_py_ast_type_node(ast_node.right, scope);
        if left is None or right is None {
            return None;
        }
        left_types = left.types if isinstance(left, types.UnionType) else [left];
        right_types = right.types if isinstance(right, types.UnionType) else [right];
        return types.UnionType(types=left_types + right_types);
    }

    if isinstance(ast_node, _SS) {
        base = self._resolve_py_ast_type_node(ast_node.value, scope);
        if base is None {
            return None;
        }

        if isinstance(ast_node.value, _N) and ast_node.value.id == "Callable" {
            if isinstance(ast_node.slice, _TU) and len(ast_node.slice.elts) == 2 {
                params_ast = ast_node.slice.elts[0];
                ret_ast = ast_node.slice.elts[1];
                param_types: list[types.TypeBase] = [];
                if isinstance(params_ast, _LI) {
                    for p in params_ast.elts {
                        pt = self._resolve_py_ast_type_node(p, scope);
                        if pt is None {
                            return None;
                        }
                        param_types.append(self._convert_to_instance(pt));
                    }
                }
                ret_type = self._resolve_py_ast_type_node(ret_ast, scope);
                if ret_type is None {
                    return None;
                }
                return types.create_callable_type(
                    param_types, self._convert_to_instance(ret_type)
                );
            }
        }

        type_args: list[types.TypeBase] = [];
        slice_ast = ast_node.slice;
        if isinstance(slice_ast, _TU) {
            for elt in slice_ast.elts {
                arg = self._resolve_py_ast_type_node(elt, scope);
                if arg is None {
                    return None;
                }
                type_args.append(arg);
            }
        } else {
            arg = self._resolve_py_ast_type_node(slice_ast, scope);
            if arg is None {
                return None;
            }
            type_args.append(arg);
        }
        if isinstance(base, types.ClassType) {
            result = base.clone_as_instance();
            result.private.type_args = type_args;
            return result;
        }
        return base;
    }

    if isinstance(ast_node, _AT) {
        base = self._resolve_py_ast_type_node(ast_node.value, scope);
        if (
            base is not None
            and isinstance(base, types.ModuleType)
            and base.symbol_table is not None
        ) {
            member = base.symbol_table.lookup(ast_node.attr);
            if member is None
            and (
                inner := type_utils.collect_member_syms(
                    base.symbol_table, ast_node.attr
                )
            ) {
                member = inner[0];
            }
            if member {
                return self.get_type_of_symbol(member);
            }
        }
        return None;
    }
    return None;
}
