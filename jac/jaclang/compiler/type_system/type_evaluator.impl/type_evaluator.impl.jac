"""Core function to get the type of the expression."""
impl TypeEvaluator._get_type_of_expression_core(
    expr: uni.Expr, expected_type: TypeBase | None = None
) -> TypeBase {
    match expr {
        case uni.CfgExpr():
            return self._get_type_of_expression_core(expr.expr, expected_type);

        # ----------------------------------------------------------------------
        # Prefetched types: These types may not have prefetched and we need to
        # check if they are available, if the're not, we're inside builtins or
        # typeshed module itself and in that case we can just return unknown type.
        # ----------------------------------------------------------------------
        case uni.String():
            if self.prefetch and self.prefetch.str_class {
                # Byte strings (b"...") -> bytes type, not str
                if isinstance(expr.lit_value, bytes) {
                    if self.prefetch.bytes_class {
                        return self._convert_to_instance(self.prefetch.bytes_class);
                    }
                    return types.UnknownType();
                }
                # Forward-reference resolution: when a string is used in a type
                # annotation context, resolve the string content as a type name.
                # This handles: -> 'Path', has x: 'SomeType', p: 'SomeType'
                # The String may be wrapped in MultiString, so check both levels.
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
                # String literal -> Literal["value"]
                str_class = self.prefetch.str_class;
                if isinstance(str_class, types.ClassType) {
                    literal_type = str_class.clone_with_literal(expr.lit_value);
                    return self._convert_to_instance(literal_type);
                }
                return self._convert_to_instance(str_class);
            }

        case uni.MultiString():
            if self.prefetch and self.prefetch.str_class {
                # Forward-reference resolution for single-string type annotations.
                # When 'Path' is used as a type annotation, the parser wraps
                # the String in a MultiString. Check if this is in a type context.
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
                    # Check if all parts are simple strings (no f-strings with interpolation)
                    all_literal = True;
                    combined_value = "";
                    for s in expr.strings {
                        if isinstance(s, uni.String) {
                            # Skip byte strings for literal tracking (lit_value is bytes)
                            if isinstance(s.lit_value, bytes) {
                                all_literal = False;
                                break;
                            }
                            combined_value += s.lit_value;
                        } elif isinstance(s, uni.FString) {
                            # Check if f-string has any formatted values
                            if not self._is_fstring_all_literal(s) {
                                all_literal = False;
                                break;
                            }
                            # F-string with only literal parts - can't get exact value
                            # but we know it's a literal string
                            all_literal = True;
                        }
                    }
                    if all_literal
                    and not any(isinstance(s, uni.FString) for s in expr.strings) {
                        # Pure string concatenation -> Literal["combined"]
                        literal_type = str_class.clone_with_literal(combined_value);
                        return self._convert_to_instance(literal_type);
                    } elif all_literal {
                        # Has f-strings but all literal -> LiteralString
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
                # Check if all parts are literal (no FormattedValue with non-literal exprs)
                if self._is_fstring_all_literal(expr) {
                    # F-string with only literal parts -> LiteralString
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
                if isinstance(list_inst, types.ClassType) and expr.values {
                    # Always infer element types bottom-up first.
                    elem_types: list[types.TypeBase] = [];
                    for _val in expr.values {
                        elem_type = self.get_type_of_expression(_val);
                        if not isinstance(elem_type, types.UnknownType)
                        and not self._type_in_list(elem_type, elem_types) {
                            elem_types.append(elem_type);
                        }
                    }
                    # Bidirectional: if expected_type is list[X], adopt X only
                    # when all inferred element types are assignable to X.
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
                            # Elements don't match expected — use inferred types
                            # so the caller can emit the real type mismatch error.
                            if len(elem_types) == 1 {
                                list_inst.private.type_args = [elem_types[0]];
                            } elif len(elem_types) > 1 {
                                list_inst.private.type_args = [
                                    types.UnionType(types=elem_types)
                                ];
                            }
                        }
                    } else {
                        # No expected type — use bottom-up inferred types
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
                if isinstance(dict_inst, types.ClassType) and expr.kv_pairs {
                    # Always infer key/value types bottom-up first.
                    key_types: list[types.TypeBase] = [];
                    val_types: list[types.TypeBase] = [];
                    for _kv in expr.kv_pairs {
                        if _kv.key {
                            kt = self.get_type_of_expression(_kv.key);
                            if not isinstance(kt, types.UnknownType)
                            and not self._type_in_list(kt, key_types) {
                                key_types.append(kt);
                            }
                        }
                        vt = self.get_type_of_expression(_kv.value);
                        if not isinstance(vt, types.UnknownType)
                        and not self._type_in_list(vt, val_types) {
                            val_types.append(vt);
                        }
                    }
                    # Bidirectional: adopt expected K,V only if all entries match
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
                    # Always infer element types bottom-up first.
                    elem_types_t: list[types.TypeBase] = [];
                    for _val in expr.values {
                        et = self.get_type_of_expression(_val);
                        if not isinstance(et, types.UnknownType) {
                            elem_types_t.append(et);
                        }
                    }
                    # Bidirectional: adopt expected type_args only if elements match
                    if (
                        isinstance(expected_type, types.ClassType)
                        and self.prefetch.tuple_class
                        and expected_type.shared == self.prefetch.tuple_class.shared
                        and expected_type.private
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
                if isinstance(set_inst, types.ClassType) and expr.values {
                    # Always infer element types bottom-up first.
                    set_elem_types: list[types.TypeBase] = [];
                    for _val in expr.values {
                        et = self.get_type_of_expression(_val);
                        if not isinstance(et, types.UnknownType)
                        and not self._type_in_list(et, set_elem_types) {
                            set_elem_types.append(et);
                        }
                    }
                    # Bidirectional: adopt expected element type if all elements match
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

        # Comprehension handlers (SetCompr/GenCompr before ListCompr since they inherit from it)
        case uni.SetCompr():
            if self.prefetch and self.prefetch.set_class {
                set_inst = self._convert_to_instance(self.prefetch.set_class);
                for compr in expr.compr {
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
                for compr in expr.compr {
                    self.get_type_of_expression(compr.collection);
                    if isinstance(compr.target, uni.Name) {
                        self.get_type_of_expression(compr.target);
                    }
                }
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
                for compr in expr.compr {
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
                elem_type = self.get_type_of_expression(expr.out_expr);
                if isinstance(list_inst, types.ClassType)
                and not isinstance(elem_type, types.UnknownType) {
                    list_inst.private.type_args = [elem_type];
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
            # Bidirectional inference: if expected_type is a FunctionType,
            # seed untyped lambda params from the expected callable signature.
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
            }
            if isinstance(expr.body, uni.Expr) {
                body_type = self.get_type_of_expression(expr.body);
                if isinstance(return_type, types.UnknownType) {
                    return_type = body_type;
                }
            } elif isinstance(return_type, types.UnknownType) {
                # Block-body lambda: infer return type from return statements,
                # defaulting to NoneType when no return-with-value is present.
                return_type = self._infer_lambda_block_return_type(expr.body);
            }
            return types.FunctionType(
                func_name="<lambda>", return_type=return_type, parameters=parameters,
            );

        case uni.JsxElement():
            if self.prefetch and self.prefetch.jsx_element_class {
                self._validate_jsx_props(expr, expected_type);
                return self._convert_to_instance(self.prefetch.jsx_element_class);
            }

        case uni.Bool():
            if self.prefetch and self.prefetch.bool_class {
                return self._convert_to_instance(self.prefetch.bool_class);
            }

        # ----------------------------------------------------------------------
        # End of prefetched types
        # ----------------------------------------------------------------------
        case uni.AtomTrailer():
            base_type = self.get_type_of_expression(expr.target);

            if isinstance(expr.target, uni.Name) and expr.target.sym {
                if narrowed := self.get_narrowed_type(expr.target.sym, expr) {
                    base_type = narrowed;
                }
            }

            if expr.is_attr {  # <expr>.member
                # Unknown base type: attribute access cannot be validated.
                if isinstance(base_type, types.UnknownType) {
                    assert isinstance(expr.right, uni.Name);
                    # Suppress cascading E1032 when the target is a chained
                    # expression (AtomTrailer/FuncCall) that already resolved to
                    # Unknown — the root cause was already reported upstream.
                    # Name targets are never suppressed: they represent the first
                    # attribute access on an Unknown variable and should be reported.
                    target_already_unknown = (
                        isinstance(expr.target.type, types.UnknownType)
                        and isinstance(expr.target, (uni.AtomTrailer, uni.FuncCall))
                    );
                    if not target_already_unknown {
                        self.emit_diag(E1032, expr.right, attr=expr.right.value);
                    }
                    return types.UnknownType();
                }
                # Dotted-path narrowing is now handled by CFG (get_narrowed_type_for_expr)
                # after member lookup below. Scope-based dotted narrowing removed because
                # it doesn't account for assignments inside branches.
                full_narrowed: TypeBase | None = None;
                # Member lookup on (narrowed) base type
                assert isinstance(expr.right, uni.Name);
                if isinstance(base_type, types.ModuleType) {
                    # getTypeOfMemberAccessWithBaseType()
                    if sym := type_utils.lookup_symtab(
                        base_type.symbol_table, expr.right.value, self.builtins_module
                    ) {
                        # Get the symbol's type first
                        sym_type = self.get_type_of_symbol(sym);
                        # Return prefetched special form type if both name and type match
                        if special_form := self._get_special_form_type(
                            sym.sym_name, sym_type
                        ) {
                            sym.add_use(expr.right);
                            expr.right.type = special_form;
                            return special_form;
                        }
                        # Check for function overloads in module-level functions
                        # (e.g., math.floor has multiple @overload signatures).
                        # This mirrors the overload collection done for Name expressions
                        # and is required for proper type checking of overloaded functions.
                        if isinstance(sym_type, types.FunctionType) {
                            overloaded_fns: list[types.FunctionType] = [sym_type];
                            # Look up all symbols with the same name to find overloads
                            all_syms = base_type.symbol_table.lookup_all(
                                expr.right.value, deep=False
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
                        # Not a special form, return the resolved type
                        sym.add_use(expr.right);
                        expr.right.type = sym_type;
                        return sym_type;
                    }
                    return types.UnknownType();
                } elif base_type.is_instantiable_class() {
                    assert isinstance(base_type, types.ClassType);
                    # Get the type to use for member lookup, handling type[T] subscripts.
                    # When base_type is type[T], lookup_type will be T instead of 'type'.
                    lookup_type = self._get_type_for_member_lookup(base_type);
                    if member := self._lookup_class_member(
                        lookup_type, expr.right.value
                    ) {
                        value = self._set_symbol_to_expr(expr.right, member.symbol);
                        # Handle direct enum member access (e.g., Color.RED)
                        if lookup_type.is_enum_class() {
                            member_name = expr.right.value;
                            # Return EnumMemberType for recognized enum members
                            if (
                                lookup_type.shared.enum_members
                                and member_name in lookup_type.shared.enum_members
                            ) {
                                member_info = lookup_type.shared.enum_members[
                                    member_name
                                ];
                                return types.EnumMemberType(
                                    enum_class=lookup_type,
                                    member_info=member_info,
                                    flags=types.TypeFlags.Instance
                                );
                            }
                            # For non-enum-member access (e.g., static methods),
                            # fall through to return the actual member type
                        }
                        return value;
                    }
                    # Suppress diagnostic for any-like types (Any, object, Unknown,
                    # TypeVar) and for types with unresolved TypeVars in type_args
                    # (which cause false positives on generic types like list[T].append).
                    if not self.is_any_type(lookup_type) {
                        _has_tvars = (
                            isinstance(lookup_type, types.ClassType)
                            and lookup_type.private is not None
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
                    # Attribute access on Any should return Any, not Unknown
                    if self.is_any_type(lookup_type)
                    and self.prefetch.any_class is not None {
                        return self.prefetch.any_class;
                    }
                    return types.UnknownType();
                } elif base_type.is_class_instance() {
                    assert isinstance(base_type, types.ClassType);
                    # Unwrap Final[T] to T for attribute access: Final is a write-once
                    # qualifier, not a distinct type; member lookup should go to T.
                    # TODO: Handle non-ClassType inner (e.g. Final[int | str]).
                    # TODO: Consider centralizing unwrap logic for all type qualifiers.
                    if (
                        self.prefetch.final_class
                        and base_type.shared == self.prefetch.final_class.shared
                        and base_type.private is not None
                        and base_type.private.type_args
                    ) {
                        inner = base_type.private.type_args[0];
                        if isinstance(inner, types.ClassType) {
                            base_type = inner;
                        }
                    }
                    # Handle .value/.name on enum instances — DynamicClassAttribute
                    # is not detected by the property check, so resolve these directly.
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
                            # If no explicit value type (not StrEnum/IntEnum),
                            # infer from members' common value type.
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
                    # Special handling for type[T]: when accessing members on an instance of type
                    # (i.e., a class object), we need to look up class-level members on T.
                    # For example: cls: type[Archetype] → cls._jac_entry_funcs_ should resolve
                    # to Archetype._jac_entry_funcs_, not type._jac_entry_funcs_.
                    if self._is_type_subscript(base_type) {
                        lookup_type = self._get_type_for_member_lookup(base_type);
                        if member := self._lookup_class_member(
                            lookup_type, expr.right.value
                        ) {
                            value = self._set_symbol_to_expr(expr.right, member.symbol);
                            return value;
                        }
                        # If not found in T, fall through to check type's instance members
                    }
                    if member := self._lookup_object_member(
                        base_type, expr.right.value
                    ) {
                        # For init method lookup: if the class is a data class and
                        # doesn't have an explicit init defined directly (not inherited),
                        # prefer the implicit dataclass init over inherited object.__init__.
                        # But only if the class or its ancestors have 'has' variables.
                        if (
                            expr.right.value in ('init', '__init__')
                            and base_type.is_data_class()
                        ) {
                            # Check if the class has explicit init in its own symbol table
                            has_explicit_init = (
                                'init' in base_type.shared.symbol_table.names_in_scope
                                or '__init__' in base_type.shared.symbol_table.names_in_scope
                            );
                            # Check if there are any 'has' vars in the class hierarchy
                            # (excluding object which has no has vars)
                            has_any_has_vars = any(
                                len(cls.shared.symbol_table.get_has_vars()) > 0
                                for cls in base_type.shared.mro
                                if cls.shared.class_name != "object"
                            );
                            # Only create implicit dataclass init if:
                            # 1. No explicit init in the class itself
                            # 2. There are 'has' vars somewhere in the hierarchy
                            if not has_explicit_init and has_any_has_vars {
                                implicit_init_type = self._create_dataclass_init_method(
                                    base_type
                                );
                                expr.right.type = implicit_init_type;
                                return implicit_init_type;
                            }
                        }
                        overloaded_ty: types.OverloadedType | None = None;
                        # Use get_type_of_member to properly specialize TypeVars (Pyright pattern)
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
                        # Check if this member is a property. If so, return the property's
                        # return type instead of the FunctionType.
                        # Uses centralized get_getter_type_from_property
                        if prop_return_type := self.get_getter_type_from_property(
                            member.symbol
                        ) {
                            # Resolve Self and TypeVars using the base class type
                            prop_return_type = self.specialize_member_type(
                                prop_return_type, base_type
                            );
                            member.symbol.add_use(expr.right);
                            expr.right.type = prop_return_type;
                            return expr.right.type;
                        }
                        # NOTE: If this atom trailer is called `<atom_trailer>()` we can resolve
                        # which overload is being called based on the arguments, and update the type
                        # based on the call, maybe for future.
                        #
                        # This symbol.add_use is what makes the jump to definition work.
                        #
                        # expr_type = self._set_symbol_to_expr(expr.right, member.symbol);
                        member.symbol.add_use(expr.right);
                        # Try CFG-based expression narrowing for dotted paths (e.g., bmw.speed)
                        if full_narrowed is None and overloaded_ty is None {
                            cfg_narrowed = self.get_narrowed_type_for_expr(
                                expr, member_ty, expr
                            );
                            if cfg_narrowed is not None {
                                full_narrowed = cfg_narrowed;
                            }
                        }
                        # Use narrowed type for hover/IDE if available, otherwise declared type
                        expr.right.type = full_narrowed or overloaded_ty or member_ty;
                        return expr.right.type;
                    }
                    # Fallback for implicit init method on data classes (classes with 'has' vars).
                    # When accessing .init on an instance and no explicit init is found,
                    # create an implicit init from the 'has' variables.
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
                    # Check for __getattr__ override before reporting error.
                    # When a class defines __getattr__, any attribute access that doesn't
                    # match an explicit member should return the __getattr__ return type.
                    # This follows Pyright's applyAttributeAccessOverride pattern.
                    if getattr_return := self._get_getattr_return_type(base_type) {
                        expr.right.type = getattr_return;
                        expr.right.is_getattr_resolved = True;
                        return getattr_return;
                    }
                    # Suppress diagnostic for any-like types (Any, object, Unknown,
                    # TypeVar) and for types with unresolved TypeVars in type_args.
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
                    # Attribute access on Any should return Any, not Unknown
                    if self.is_any_type(base_type)
                    and self.prefetch.any_class is not None {
                        return self.prefetch.any_class;
                    }
                    return types.UnknownType();
                } elif isinstance(base_type, types.EnumMemberType) {
                    # Handle member access on enum member instances (e.g., Color.RED.name, Color.RED.value)
                    member_name = expr.right.value;
                    enum_cls = base_type.enum_class;
                    # Access to .name or ._name_ returns string
                    if member_name in ('name', '_name_') {
                        return self._convert_to_instance(self.prefetch.str_class);
                    }
                    # Access to .value or ._value_ returns the member's value type
                    if member_name in ('value', '_value_') {
                        return self._convert_to_instance(base_type.get_value_type());
                    }
                    # Access to another enum member (e.g., Color.RED.BLUE)
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
                    # Unknown member access
                    return types.UnknownType();
                } elif isinstance(base_type, types.UnionType) and base_type.types {
                    # Handle member access on union types (e.g., (Mammal | Primate).name)
                    # Look up member on each type in the union
                    member_types: list[TypeBase] = [];
                    has_any_member = False;  # Track if Any/Unknown members exist
                    decl_for_ide: uni.NameAtom | None = None;  # First decl found, used for go-to-definition
                    for union_member in base_type.types {
                        # Any and Unknown types are compatible with all attribute access
                        if isinstance(
                            union_member, (types.AnyType, types.UnknownType)
                        ) {
                            member_types.append(union_member);
                            has_any_member = True;
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
                    # If member found on all union types, set symbol for IDE features
                    all_union_members_have_field = len(member_types) == len(
                        base_type.types
                    );
                    if all_union_members_have_field {
                        if decl_for_ide and decl_for_ide.sym {
                            decl_for_ide.sym.add_use(expr.right);
                        }
                        # Dedupe: (str, str) → str, (str, int) → str | int
                        unique_types = list({str(t): t for t in member_types}.values());
                        all_same_type = len(unique_types) == 1;
                        expr.right.type = unique_types[0]
                            if all_same_type
                            else types.UnionType(types=unique_types);
                        return expr.right.type;
                    }
                    # Member not found on all union variants - report error
                    missing_types: list[str] = [];
                    for union_member in base_type.types {
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
                    return types.UnknownType();
                } elif isinstance(base_type, types.TypeVarType) {
                    attr_name = expr.right.value;
                    # Constrained TypeVar - check all constraint types
                    if base_type.constraints {
                        found_member: Any = None;
                        for constraint_type in base_type.constraints {
                            if isinstance(constraint_type, types.ClassType) {
                                if member := self._lookup_object_member(
                                    constraint_type, attr_name
                                ) {
                                    if found_member is None {
                                        found_member = member;
                                    }
                                } else {
                                    # Attribute not found on this constraint type
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
                    # Bounded TypeVar - use bound type for attribute lookup
                    if base_type.bound {
                        bound_type = base_type.bound;
                        if isinstance(bound_type, types.ClassType) {
                            if member := self._lookup_object_member(
                                bound_type, attr_name
                            ) {
                                self._set_symbol_to_expr(expr.right, member.symbol);
                                return self.get_type_of_symbol(member.symbol);
                            }
                            # Attribute not found on bound type
                            self.emit_diag(
                                E1031, expr, attr=attr_name, type=str(bound_type)
                            );
                            return types.UnknownType();
                        } elif isinstance(bound_type, types.UnionType) {
                            # Check all union members have the attribute
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
                            # Return Unknown for now - could compute common type
                            return types.UnknownType();
                        }
                    }
                    # Unbounded TypeVar - only universal object attributes are allowed
                    # Pyright: treats unbounded TypeVars as "object*"
                    universal_attrs = {"__class__","__doc__","__dict__","__module__","__sizeof__","__str__","__repr__","__hash__","__eq__","__ne__","__init__","__new__"};
                    if attr_name in universal_attrs {
                        # Look up on object class
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
                    # Error: attribute not available on unbounded TypeVar
                    self.emit_diag(E1031, expr, attr=attr_name, type=base_type.name);
                    return types.UnknownType();
                } elif isinstance(
                    base_type, (types.FunctionType, types.OverloadedType)
                ) {
                    # All functions are instances of types.FunctionType at runtime.
                    # Delegate attribute lookup to the prefetched FunctionType class.
                    # TODO: Add is_method_type() check and use method_class for bound methods.
                    if self.prefetch and self.prefetch.function_class {
                        if member := self._lookup_object_member(
                            self.prefetch.function_class.clone_as_instance(),
                            expr.right.value
                        ) {
                            self._set_symbol_to_expr(expr.right, member.symbol);
                            return self.get_type_of_symbol(member.symbol);
                        }
                    }
                    # Attribute not found on FunctionType
                    self.emit_diag(
                        E1031, expr, attr=expr.right.value, type=str(base_type)
                    );
                    return types.UnknownType();
                }
            } elif expr.is_null_ok {
                # TODO:
                # <expr>?.member
            } elif isinstance(expr.right, uni.AssignCompr) {
                # base_type should be a sequence of [T].
                if not isinstance(base_type, types.ClassType) {
                    self.emit_diag(E1034, expr, type=str(base_type));
                    return base_type;
                }
                # TODO: Ensure the base_type is a Sequence[T], for now I'm only checking
                # if it's a generic of T.
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
                # Evaluate KW pair values.
                for assign in expr.right.assigns {
                    self.get_type_of_expression(assign.value);
                }
                return base_type;
            } elif isinstance(expr.right, uni.FilterCompr) {
                # Filter comprehension trailer: <expr>[?:Type] or <expr>[?:Type, field==val]
                # Evaluate the filter (resolves symbols in compares, computes list[FilterType]).
                filter_result = self.get_type_of_expression(expr.right);
                # If the filter inferred a concrete list type, use it.
                if not isinstance(filter_result, types.UnknownType) {
                    return filter_result;
                }
                # No type filter — return the base type unchanged (preserves list[Any] from edge traversal).
                return base_type;
            } else {  # <expr>[<expr>]
                # --- Handle Callable special form ---
                # Callable[[ArgTypes], ReturnType] creates a FunctionType, not a specialized class.
                # Similar to Pyright's handling in createSpecializedClassType() which checks
                # classType.priv.aliasName === 'Callable'.
                #
                # We check is_special_form("Callable") which looks at the alias_name stored
                # in the ClassType's private details. The alias_name is set when resolving
                # Name expressions that refer to typing module special forms.
                if (
                    isinstance(base_type, types.ClassType)
                    and base_type.is_special_form("Callable")
                )
                or (
                    isinstance(base_type, types.FunctionType)
                    and base_type.is_gradual_callable_form()
                ) {
                    # Extract type arguments for Callable[[ArgTypes], ReturnType]
                    type_args_expr: uni.Expr | None = None;
                    if isinstance(expr.right, uni.IndexSlice) and expr.right.slices {
                        type_args_expr = expr.right.slices[0].start;
                    }
                    return self._create_callable_type(type_args_expr, expr);
                }
                # --- Handle Union / Optional / ClassVar special forms ---
                # Union[A, B, C] creates a UnionType, Optional[T] creates Union[T, None].
                # ClassVar[T] unwraps to just T.
                # Similar to how Callable[...] creates a FunctionType above.
                # We detect these by checking that the base_type is a _SpecialForm.
                # Use class_name check instead of shared instance comparison for cache compatibility.
                if (
                    isinstance(base_type, types.ClassType)
                    and base_type.shared is not None
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
                                        self._convert_to_instance(
                                            self.get_type_of_expression(val)
                                        )
                                    );
                                }
                            } else {
                                union_args.append(
                                    self._convert_to_instance(
                                        self.get_type_of_expression(ua_vals)
                                    )
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
                    # --- Handle ClassVar special form ---
                    # ClassVar[T] is a marker indicating a class variable, not an instance variable.
                    # The actual type of the variable is T, so we unwrap and return T.
                    # Similar to Pyright's handling where ClassVar[T] unwraps to T.
                    # The outer check ensures base_type is a _SpecialForm from typing module.
                    if target_name == "ClassVar" {
                        if isinstance(expr.right, uni.IndexSlice)
                        and expr.right.slices {
                            inner_type_expr = expr.right.slices[0].start;
                            return self._convert_to_instance(
                                self.get_type_of_expression(inner_type_expr)
                            );
                        }
                        # Bare ClassVar without type arg - return Unknown
                        return types.UnknownType();
                    }
                }
                # Subscript on Any should return Any, not Unknown (check before generic
                # specialization to avoid Any's subscript returning Any[Unknown]).
                # Use narrow check: only actual Any, not TypeVars (which need error reporting).
                if (
                    isinstance(base_type, types.ClassType)
                    and self.prefetch.any_class is not None
                    and base_type.shared == self.prefetch.any_class.shared
                ) {
                    return self.prefetch.any_class;
                }
                # if <expr> is a class type, the atom trailer will be the type params.
                if isinstance(base_type, types.ClassType)
                and base_type.is_instantiable_class() {
                    # --- Handle other generic types ---
                    # Collect the type arguments and normalize to instances.
                    # Type args like `int` in `list[int]` represent element types
                    # (instances), not the class itself. Normalizing here ensures
                    # consistent comparison with type_args inferred from literals.
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
                # Case: <expr>[<expr>:<expr>] slice of the expression.
                if isinstance(expr.right, uni.IndexSlice) and expr.right.is_range {
                    # TODO: Validate the slice type arguments.
                    return self.get_type_of_expression(expr.target);
                }
                # TypeVar subscript handling
                if isinstance(base_type, types.TypeVarType) {
                    # Constrained TypeVar - check all constraint types
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
                        # Bounded TypeVar - use bound type for __getitem__ lookup
                        bound_type = base_type.bound;
                        if isinstance(bound_type, types.ClassType) {
                            result = self.get_type_of_magic_method_call(
                                bound_type, "__getitem__", [expr.right], expr
                            );
                            if result {
                                return result;
                            }
                            # Bound type is not subscriptable
                            self.emit_diag(E1040, expr, type=str(bound_type));
                            return types.UnknownType();
                        }
                    }
                    # Unbounded TypeVar - not subscriptable
                    self.emit_diag(E1040, expr, type=base_type.name);
                    return types.UnknownType();
                }
                # Regular <expr>[<expr>] case, we need to call __getitem__()
                # Extract the actual index expression from IndexSlice.
                # IndexSlice wraps the subscript value in slices[0].start,
                # and get_type_of_expression has no handler for IndexSlice
                # (it would return Unknown). Pass the inner expression instead.
                subscript_arg: uni.Expr = expr.right;
                if (
                    isinstance(expr.right, uni.IndexSlice)
                    and not expr.right.is_range
                    and expr.right.slices
                ) {
                    subscript_arg = expr.right.slices[0].start;
                }
                result = self.get_type_of_magic_method_call(
                    base_type, "__getitem__", [subscript_arg], expr
                );
                if result and not isinstance(result, types.UnknownType) {
                    return result;
                }
                # Fallback: if __getitem__ overload matching failed or returned
                # Unknown (e.g. due to SupportsIndex protocol not being
                # structurally matched), check if the type is a known container
                # with a predictable element type.
                # str[int] -> str, bytes[int] -> int.
                if isinstance(base_type, types.ClassType) {
                    if base_type.is_builtin("str") {
                        return base_type;  # str[n] returns str

                    }
                    if base_type.is_builtin("bytes") {
                        if self.prefetch and self.prefetch.int_class {
                            return self._convert_to_instance(self.prefetch.int_class);
                        }
                    }
                }
                return result or types.UnknownType();
            }

        case uni.AtomUnit():
            return self.get_type_of_expression(expr.value);

        case uni.FuncCall():
            return self.validate_call_args(expr);

        case uni.AwaitExpr():
            # Evaluate the awaited expression
            target_type = self.get_type_of_expression(expr.target);
            # TypeVar await handling
            if isinstance(target_type, types.TypeVarType) {
                # Constrained TypeVar - check all constraint types
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
                    # Bounded TypeVar - check if bound type has __await__
                    result = self.get_type_of_magic_method_call(
                        target_type.bound, "__await__", [], None
                    );
                    if result {
                        return result;
                    }
                    # Bound type is not awaitable
                    self.emit_diag(E1041, expr, type=str(target_type.bound));
                    return types.UnknownType();
                }
                # Unbounded TypeVar - not awaitable
                self.emit_diag(E1041, expr, type=target_type.name);
                return types.UnknownType();
            }
            # TODO: Proper awaitable unwrapping (Coroutine[T1, T2, T3] -> T3)
            return target_type;

        case uni.BinaryExpr():
            return operations.get_type_of_binary_operation(self, expr);

        case uni.CompareExpr():
            # Evaluate operands for side effects / error detection
            self.get_type_of_expression(expr.left);
            for right in expr.rights {
                self.get_type_of_expression(right);
            }
            # Comparisons always return bool
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
            # AND/OR return operand values, not bool: `x and y` → y if x truthy, else x.
            # Type is the union of all operand types (Python semantics).
            is_or = isinstance(expr.op, uni.Token) and expr.op.name == Tok.KW_OR;
            operand_types: list[TypeBase] = [];
            num_values = len(expr.values);
            for i in range(num_values) {
                op_type = self.get_type_of_expression(expr.values[i].expr);
                # Pyright-style OR result narrowing: for `x or y`, the result
                # type of non-last operands excludes always-falsy types (None)
                # because if the operand were falsy, OR short-circuits to the
                # next operand. So None can never be the result from x in `x or y`.
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
            if len(operand_types) == 1 {
                return operand_types[0];
            } elif len(operand_types) > 1 {
                return types.UnionType(types=operand_types);
            }
            return types.UnknownType();

        case uni.UnaryExpr():
            if isinstance(expr.op, uni.Token) {
                if expr.op.name == Tok.NOT {
                    # `not x` -> bool (only when operand is resolved)
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
                    # `-x`, `~x` -> type of operand
                    operand_type = self.get_type_of_expression(expr.operand);
                    op_name = "__neg__" if expr.op.name == Tok.MINUS else "__invert__";
                    # TypeVar unary operation handling
                    if isinstance(operand_type, types.TypeVarType) {
                        # Constrained TypeVar - check all constraint types
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
                            # Bounded TypeVar - use bound type for magic method lookup
                            result = self.get_type_of_magic_method_call(
                                operand_type.bound, op_name, [], None
                            );
                            if result {
                                return result;
                            }
                            # Bound type doesn't support this operator
                            self.emit_diag(
                                E1010, expr, op=op_name, type=str(operand_type.bound)
                            );
                            return types.UnknownType();
                        }
                        # Unbounded TypeVar
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
                    # Compute the MRO for the class.
                    # For each compare in the filter comprehension, set symbol to the right name.
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

                        left_type = self.get_type_of_expression(cmp.left);
                        right_type = self.get_type_of_expression(cmp.rights[0]);
                        # TODO: Check if those two types are comparable.
                        # if  not self.???(right_type, left_type) {
                        #     self.add_diagnostic(
                        #         cmp.right,
                        #         f'Type "{right_type}" is not comparable to type "{left_type}"',
                        #     );
                        # }
                    }
                    # Return list[FilterType] — the filter narrows elements to the given type.
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
                # Handle "here" and "visitor" special name ref.
                if expr.name in (Tok.KW_HERE, Tok.KW_VISITOR) {
                    if (method := self._get_enclosing_method(expr)) {
                        if isinstance(method.signature, uni.EventSignature) {
                            if arch := method.signature.arch_tag_info {
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

            # NOTE: For self's type pyright is getting the first parameter of a method and
            # the name can be anything not just self, however we don't have the first parameter
            # and self is a keyword, we need to do it in this way.
            if self._is_expr_self(expr) {
                return self._get_type_of_self(expr);
            }

            # Handle 'super' keyword - resolve to first parent class in MRO.
            if self._is_expr_super(expr) {
                return self._get_type_of_super(expr);
            }

            if scope := expr.find_parent_of_type(uni.UniScopeNode) {
                if symbol := type_utils.lookup_symtab(
                    scope, expr.value, self.builtins_module
                ) {
                    symbol = self.resolve_imported_symbols(symbol);
                    symbol.add_use(expr);
                    # Only set sym if not already set (preserves existing symbol info for declarations)
                    if expr.sym is None {
                        expr.sym = symbol;
                        # Link name_of to the declaration's AstSymbolNode for hover
                        if symbol.decl and symbol.decl.name_of {
                            expr.name_of = symbol.decl.name_of;
                        }
                    }
                    # Check for function overloads
                    symbol_type = self.get_type_of_symbol(symbol);
                    # Pyright: handleTypingStubTypeAnnotation / createSpecializedClassType
                    # When a Name refers to a special form (e.g., Callable, Self), check if
                    # the symbol's type is _SpecialForm and switch on the name.
                    # For Self, returns TypeVarType("Self") directly.
                    if special_form := self._get_special_form_type(
                        symbol.sym_name, symbol_type
                    ) {
                        # For TypeVarType (Self), return immediately
                        if isinstance(special_form, types.TypeVarType) {
                            return special_form;
                        }
                        symbol_type = special_form;
                    }
                    # Write-side short-circuit for LHS re-assignments.
                    if isinstance(expr, uni.Name) {
                        if lhs_type := self._get_type_of_lhs_assignment(expr) {
                            return self._convert_to_instance(lhs_type);
                        }
                    }
                    # Use CFG-based narrowing for flow-sensitive type.
                    # Narrowed types represent variable values, so ensure
                    # they are instance types (not instantiable class types).
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
                        # Find the scope where the symbol is defined to check for overloads
                        symbol_scope: uni.UniScopeNode | None = symbol.parent_tab;
                        if symbol_scope is None {
                            # If parent_tab is None, try to find the scope from the declaration
                            if symbol.decl
                            and symbol.decl.find_parent_of_type(uni.UniScopeNode) {
                                symbol_scope = symbol.decl.find_parent_of_type(
                                    uni.UniScopeNode
                                );
                            }
                        }
                        # Check if there are overloads in the symbol's scope
                        if symbol_scope {
                            all_syms = symbol_scope.lookup_all(expr.value, deep=False);
                            for overload_symbol in all_syms {
                                if overload_symbol == symbol {
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
            # Unwrap awaited expression type. The target (e.g., fetch_number())
            # already resolves to the coroutine's return type via FuncCall handling.
            return self.get_type_of_expression(expr.target);

        case uni.YieldExpr():
            # Yield expression evaluates to the type of the yielded value.
            if expr.expr is not None {
                return self.get_type_of_expression(expr.expr);
            }
            return types.UnknownType();

        case uni.EdgeRefTrailer():
            # Edge traversal: [node-->], [node<--], [node->:Edge:->], etc.
            # Returns list[NodeArchetype] (default) or list[EdgeArchetype] (edges_only).
            # Two syntax forms place FilterCompr differently:
            #   [root-->][?:Todo]  — FilterCompr is sibling in AtomTrailer (handled there)
            #   [-->[?:Todo]]      — FilterCompr is in EdgeRefTrailer.chain (handled here)
            if self.prefetch and self.prefetch.list_class {
                element_type: types.TypeBase = types.AnyType();
                for chain_item in expr.chain {
                    if isinstance(chain_item, uni.FilterCompr) and chain_item.f_type {
                        ft = self.get_type_of_expression(chain_item.f_type);
                        if isinstance(ft, types.ClassType) {
                            element_type = self._convert_to_instance(ft);
                        }
                    }
                }
                list_type = self.prefetch.list_class.clone_as_instance();
                list_type.private.type_args = [element_type];
                return list_type;
            }
            return types.UnknownType();

    }
    # TODO: More expressions.
    return types.UnknownType();
}

"""Return the declared type of the symbol."""
impl TypeEvaluator._get_type_of_symbol(symbol: uni.Symbol) -> TypeBase {
    node_ = symbol.decl.name_of;
    match node_ {
        case uni.Enum():
            return self.get_type_of_enum(node_);

        case uni.Archetype():
            return self.get_type_of_class(node_);

        case uni.TypeParam():
            # Jac-native generic type parameter: obj Box[T]
            # Return a TypeVarType matching the parameter name so that
            # FunctionType.specialize can substitute it with concrete type_args.
            # Mark as class type param so it can be distinguished from module-level TypeVars.
            return types.TypeVarType(name=node_.sym_name, is_class_type_param=True);

        case uni.Ability():
            return self.get_type_of_ability(node_);

        case uni.ParamVar():
            if node_.type_tag {
                annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                if node_.is_vararg {
                    # FIXME: *args are actually a tuple, not a list. But tuples are
                    # complicated to handle, so we'll use list for now. Will revisit this later.
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

        # This actually defined in the function getTypeForDeclaration();
        # Pyright has DeclarationType.Variable.
        case uni.Name():
            # ---- Handle pre-set type (e.g., from with statement alias) ----
            # If the type was already bound (e.g., by enter_with_stmt), return it.
            # Note: Scope narrowing is checked in get_type_of_expression before caching.
            if node_.type is not None {
                return node_.type;
            }
            # ---- Handle tuple/list unpacking targets ----
            # When a Name is inside a TupleVal/ListVal that is the target
            # of an Assignment, infer its type from the RHS tuple element.
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
                        if elem := self._extract_tuple_element_type(rhs_type, idx) {
                            return elem;
                        }
                    }
                }
                # ---- Handle tuple unpacking in for loops: for (a, b, c) in <expr> ----
                # Similar to Pyright's evaluateTypesForForStatement + assignTypeToTupleOrListNode
                elif isinstance(unpack_assignment, (uni.InForStmt, uni.InnerCompr)) {
                    collection_type = self.get_type_of_expression(
                        unpack_assignment.collection
                    );
                    # Get the iterator type from __iter__
                    iter_type = self.get_type_of_magic_method_call(
                        collection_type, "__iter__", [], unpack_assignment
                    );
                    elem_type: types.TypeBase | None = None;
                    if isinstance(iter_type, types.ClassType) {
                        # Get element type from __next__ - this gives the actual iteration element
                        # For enumerate[Item], __next__ returns tuple[int, Item]
                        next_type = self.get_type_of_magic_method_call(
                            iter_type, "__next__", [], unpack_assignment
                        );
                        if next_type and not isinstance(next_type, types.UnknownType) {
                            elem_type = self._convert_to_instance(next_type);
                        } elif iter_type.private
                        and iter_type.private.type_args
                        and len(iter_type.private.type_args) == 1 {
                            # Fallback: try to extract from type_args
                            elem_type = iter_type.private.type_args[0];
                            # If element type is a TypeVar, specialize it using collection's type_args
                            if isinstance(elem_type, types.TypeVarType)
                            and isinstance(collection_type, types.ClassType)
                            and collection_type.private.type_args {
                                specialized = iter_type.specialize_generics(
                                    collection_type.private.type_args
                                );
                                if len(specialized.private.type_args) == 1 {
                                    elem_type = specialized.private.type_args[0];
                                }
                            }
                        }
                    }
                    # Now extract the tuple element at the correct index
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

            # ---- Handle simple assignment: var = <expr> ----
            if isinstance(node_.parent, uni.Assignment) {
                if node_.parent.type_tag is not None {
                    annotation_type = self.get_type_of_expression(
                        node_.parent.type_tag.tag
                    );
                    # TypeAlias annotation: `X: TypeAlias = <type_expr>`
                    # The annotation marks this as a type alias — the actual
                    # type is defined by the RHS, not the annotation itself.
                    # Detect via symbol resolution: annotation_type for TypeAlias
                    # resolves to _SpecialForm, and we verify the tag name.
                    if (
                        self._is_type_alias_annotation(
                            annotation_type, node_.parent.type_tag.tag
                        )
                        and node_.parent.value is not None
                    ) {
                        return self._resolve_type_alias_rhs(node_.parent.value);
                    }
                    return self._convert_to_instance(annotation_type);
                } else {  # Assignment without a type annotation.
                    if node_.parent.value is not None {
                        return self.get_type_of_expression(node_.parent.value);
                    }
                }
            }

            # ---- Handle member assignment: obj.attr = <expr> ----
            # Pyright handles this in getDeclInfoForNameNode()
            if (
                isinstance(node_.parent, uni.AtomTrailer)
                and node_.parent.parent
                and isinstance(node_.parent.parent, uni.Assignment)
            ) {
                # Member assignment with a type annotation: obj.member: <type> = <expr>
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

            # ---- Handle walrus assignment: (x := <expr>) ----
            if (
                isinstance(node_.parent, uni.BinaryExpr)
                and isinstance(node_.parent.op, uni.Token)
                and node_.parent.op.name == "WALRUS_EQ"
                and node_.parent.left is node_
            ) {
                # The left side of walrus gets the type from the right side
                return self.get_type_of_expression(node_.parent.right);
            }

            # ---- Handle iteration variable: for <name> in <expr> ----
            # Handles both for-loops (InForStmt) and comprehensions (InnerCompr)
            if isinstance(node_.parent, (uni.InForStmt, uni.InnerCompr)) {
                collection_type = self.get_type_of_expression(node_.parent.collection);

                # Iterating over Any yields Any (any-like types allow all operations)
                if self.is_any_type(collection_type)
                and self.prefetch.any_class is not None {
                    node_.type = self.prefetch.any_class;
                    return self.prefetch.any_class;
                }

                # Special handling for NamedTuple iteration
                # Iterating over a NamedTuple yields its field values
                if isinstance(collection_type, types.ClassType)
                and collection_type.is_namedtuple() {
                    has_vars = collection_type.shared.symbol_table.get_has_vars();
                    if has_vars {
                        # Collect all field types
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
                        # If all fields have the same type, use that type
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
                            # Different types: return first type for now (TODO: union)
                            node_.type = field_types[0];
                            return field_types[0];
                        }
                    }
                }

                iter_type = self.get_type_of_magic_method_call(
                    collection_type, "__iter__", [], node_.parent,
                );
                if isinstance(iter_type, types.ClassType) {
                    # Get element type from __next__ method on the iterator.
                    # This handles enumerate, zip, etc. where __next__ returns
                    # complex types like tuple[int, _T].
                    next_type = self.get_type_of_magic_method_call(
                        iter_type, "__next__", [], node_.parent
                    );
                    if next_type and not isinstance(next_type, types.UnknownType) {
                        result_type = self._convert_to_instance(next_type);
                        node_.type = result_type;
                        return result_type;
                    }

                    # Fallback: try to extract from type_args if __next__ didn't work
                    if iter_type.private
                    and iter_type.private.type_args
                    and len(iter_type.private.type_args) == 1 {
                        elem_type = iter_type.private.type_args[0];
                        # If element type is already concrete (e.g. Iterator[int]
                        # from range.__iter__), use it directly.
                        if isinstance(elem_type, types.ClassType) {
                            result_type = elem_type.clone_as_instance();
                            node_.type = result_type;
                            return result_type;
                        }
                        # Element type is a TypeVar — specialize using the
                        # collection's type args (e.g. list[int] -> [int]).
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

            # ---- Handle except clause variable: except ValueError as e ----
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
    # TODO: Implement for functions, parameters, explicit type
    # annotations in assignment etc.
    return types.UnknownType();
}

"""
Assign a source function type to a destination callable type.

This handles Callable assignment compatibility following Python's typing rules:
- Callable[..., T] (gradual form) accepts any callable
- Parameter types are contravariant (dest params must be assignable to src params)
- Return types are covariant (src return must be assignable to dest return)
- Extra src params beyond dest count must have defaults (Pyright behavior)

Future work:
    - TypeVar handling for generic callables
    - ParamSpec support
"""
impl TypeEvaluator._assign_callable(
    src_func: types.FunctionType, dest_func: types.FunctionType
) -> bool {
    # If destination is gradual callable form (Callable[..., T]), any callable is compatible
    if dest_func.is_gradual_callable_form() {
        # Only need to check return type compatibility
        if dest_func.return_type and src_func.return_type {
            return self.assign_type(src_func.return_type, dest_func.return_type);
        }
        return True;
    }
    # If source is gradual callable form but dest is not, it's not assignable
    # (we can't guarantee the source accepts the required parameters)
    if src_func.is_gradual_callable_form() {
        return False;
    }
    # Get non-self/cls parameters for comparison
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
    # Count required dest parameters (those without default values)
    dest_required = len(
        [
            p
            for p in dest_params
            if p.default_value is None
        ]
    );
    # Source must have at least as many params as dest requires
    if len(src_params) < dest_required {
        return False;
    }
    # Check parameter compatibility (contravariant)
    for (i, dest_param) in enumerate(dest_params) {
        if i >= len(src_params) {
            # Dest has more params than src - extra dest params must have defaults
            if dest_param.default_value is None {
                return False;
            }
            continue;
        }

        src_param = src_params[i];

        # Skip type checking if either parameter has no type annotation
        if dest_param.param_type is None or src_param.param_type is None {
            continue;
        }

        # Contravariance: dest param type should be assignable to src param type
        if not self.assign_type(dest_param.param_type, src_param.param_type) {
            return False;
        }
    }
    # Check extra src params beyond dest count - they must have defaults
    # (Following Pyright: caller will only pass dest's param count, extras need defaults)
    if len(src_params) > len(dest_params) {
        for i in range(len(dest_params), len(src_params)) {
            src_param = src_params[i];
            if src_param.default_value is None {
                # Extra src param without default - incompatible
                return False;
            }
        }
    }
    # Check return type compatibility (covariant)
    if dest_func.return_type and src_func.return_type {
        if not self.assign_type(src_func.return_type, dest_func.return_type) {
            return False;
        }
    }
    return True;
}

"""Assign the source class type to the destination class type."""
impl TypeEvaluator._assign_class(
    src_type: types.ClassType, dest_type: types.ClassType
) -> bool {
    # If the type is Final[T], unwrap it to T.
    # TODO: We can actually check if the Final type is modified and
    # prevent that, but for now just unwrap it.
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
    # After unwrapping Final, if either type is no longer ClassType,
    # delegate to the general assign_type method.
    if not isinstance(unwrapped_src, types.ClassType)
    or not isinstance(unwrapped_dest, types.ClassType) {
        return self.assign_type(unwrapped_src, unwrapped_dest);
    }
    src_type = unwrapped_src;
    dest_type = unwrapped_dest;
    if src_type.shared == dest_type.shared {
        # Same class type, but check literal values if dest is a literal type
        if dest_type.is_literal_type() {
            # Destination expects a specific literal value
            if not src_type.is_literal_type() {
                # Source is not a literal - can't assign plain type to Literal
                return False;
            }
            # Both are literals - values must match
            return src_type.get_literal_value() == dest_type.get_literal_value();
        }
        # Check type arguments are compatible (e.g., list[int] vs list[str]).
        # Type args are normalized to instances at creation, but we defensively
        # normalize here too for type_args from external sources.
        if src_type.private.type_args and dest_type.private.type_args {
            if len(src_type.private.type_args) == len(dest_type.private.type_args) {
                for i in range(len(src_type.private.type_args)) {
                    src_arg = self._convert_to_instance(src_type.private.type_args[i]);
                    dest_arg = self._convert_to_instance(
                        dest_type.private.type_args[i]
                    );
                    if not self.assign_type(src_arg, dest_arg) {
                        return False;
                    }
                }
            }
        }
        return True;
    }
    # Check if src class is a subclass of dest class.
    if self.is_sub_class(dest_type, src_type) {
        # If dest has type_args, verify src supplies compatible args through MRO.
        if dest_type.private and dest_type.private.type_args {
            specialized = type_utils.specialize_for_base_class(src_type, dest_type);
            src_args = specialized.private.type_args if specialized.private else [];
            if src_args and len(src_args) == len(dest_type.private.type_args) {
                for i in range(len(src_args)) {
                    src_arg = self._convert_to_instance(src_args[i]);
                    dest_arg = self._convert_to_instance(
                        dest_type.private.type_args[i]
                    );
                    # Check variance: use TypeVar declaration if available
                    tp = dest_type.shared.type_params[i]
                        if (
                            dest_type.shared.type_params
                            and i < len(dest_type.shared.type_params)
                        )
                        else None;
                    if tp and tp.is_covariant {
                        # Covariant: src_arg must be subtype of dest_arg
                        if not self.assign_type(src_arg, dest_arg) {
                            return False;
                        }
                    } elif tp and tp.is_contravariant {
                        # Contravariant: dest_arg must be subtype of src_arg
                        if not self.assign_type(dest_arg, src_arg) {
                            return False;
                        }
                    } else {
                        # Invariant: must match both directions
                        if not self.assign_type(src_arg, dest_arg) {
                            return False;
                        }
                    }
                }
            }
        }
        return True;
    }
    # Integers can be used where floats are expected.
    if src_type.is_builtin("int") and dest_type.is_builtin("float") {
        return True;
    }
    # Check if dest_type is a protocol and src_type implements it.
    # Protocol detection: A class is a protocol if:
    # 1. It has the prefetched Protocol class as a base class (exact match)
    # 2. OR it has a BUILTIN base class named 'Protocol' or '_SpecialForm'
    # 3. OR it's from stdlib stubs with protocol naming convention (Supports*, _Supports*)
    # 4. OR its MRO contains a BUILTIN Protocol/_SpecialForm class
    is_protocol = False;
    # Check 1: Direct Protocol/_SpecialForm base class from builtins
    for base_cls in dest_type.shared.base_classes {
        if not isinstance(base_cls, types.ClassType) or base_cls.shared is None {
            continue;
        }
        # Exact match with prefetched Protocol class
        if base_cls.shared == self.prefetch.protocol_class.shared {
            is_protocol = True;
            break;
        }
        # Check for BUILTIN Protocol/_SpecialForm base class only
        if base_cls.shared.is_builtin_class
        and base_cls.shared.class_name in ('Protocol', '_SpecialForm') {
            is_protocol = True;
            break;
        }
    }
    # Check 2: Protocol naming convention for STDLIB classes only
    # Classes like _SupportsFloor, _SupportsTrunc, SupportsFloat from stdlib stubs.
    # User-defined classes with these names are NOT treated as protocols.
    # Uses is_from_stdlib_stub flag set when class was created (production-grade approach).
    if not is_protocol {
        class_name = dest_type.shared.class_name;
        if (dest_type.shared.is_from_stdlib_stub or dest_type.shared.is_builtin_class)
        and (class_name.startswith('Supports') or class_name.startswith('_Supports')) {
            is_protocol = True;
        }
    }
    # Check 3: Check MRO for Protocol/_SpecialForm from stdlib (handles inheritance)
    if not is_protocol {
        for mro_cls in dest_type.shared.mro {
            if isinstance(mro_cls, types.ClassType) and mro_cls.shared {
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
        # For synthetic types like LiteralString that share symbol_table with
        # their base class, also check if any MRO class implements the protocol.
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
    # Ensure MRO is computed (may be empty if loaded from JIR cache)
    if not sub_cls.shared.mro {
        type_utils.compute_mro_linearization(sub_cls);
    }
    for cls in sub_cls.shared.mro {
        if cls.shared == super_cls.shared {
            return True;
        }
    }
    return False;
}

"""Return the effective return type of a magic method call."""
impl TypeEvaluator.get_type_of_magic_method_call(
    obj_type: TypeBase,
    method_name: str,
    arg_nodes: list[uni.Expr],
    node_for_error: uni.Expr | None = None,
) -> TypeBase | None {
    # Handle union types by trying the method on each constituent type.
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
        # TODO: getTypeOfBoundMember() <-- Implement this if needed, for the simple case
        # we'll directly call member lookup.
        #
        # WE'RE DAVIATING FROM PYRIGHT FOR THIS METHOD HEAVILY HOWEVER THIS CAN BE RE-WRITTEN IF NEEDED.
        #
        assert isinstance(obj_type, types.ClassType);  # <-- To make typecheck happy.
        if member := self._lookup_class_member(obj_type, method_name) {
            member_ty = self.get_type_of_symbol(member.symbol);
            # This list contains all functions including the overloads.
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
                # Validate arguments for each overloaded function.
                # Prefer overloads with concrete (non-Unknown) return types
                # to avoid broken overloads (e.g. LiteralString) shadowing
                # correct ones (e.g. str.__add__(str) -> str).
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
                # If we reached here, none of the overloads matched.
                # Return None to allow fallback to reverse magic method (e.g., __radd__).
                return None;
            }
            # If we reached here, magic method is not a function.
            # 1. recursively check __call__() on the type, TODO
            # 2. if any or unknown, return getUnknownTypeForCallable() TODO
            # 3. return undefined.
            return None;
        }
    }
    return None;
}

"""Check if a type is Any or TypeVar (types that allow any operation)."""
impl TypeEvaluator.is_any_type(ty: TypeBase) -> bool {
    # Check for TypeVarType
    if isinstance(ty, types.TypeVarType) {
        return True;
    }
    # Check for Any or TypeVar class types
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

"""Check if a type is the TypeVar class itself (not a TypeVarType instance)."""
impl TypeEvaluator.is_typevar_class(ty: TypeBase) -> bool {
    return (
        self.prefetch
        and self.prefetch.type_var_class
        and isinstance(ty, types.ClassType)
        and ty.shared == self.prefetch.type_var_class.shared
    );
}

"""Check if a type is the ParamSpec class itself (not a TypeVarType instance)."""
impl TypeEvaluator.is_paramspec_class(ty: TypeBase) -> bool {
    return (
        self.prefetch
        and self.prefetch.param_spec_class
        and isinstance(ty, types.ClassType)
        and ty.shared == self.prefetch.param_spec_class.shared
    );
}

"""Check if a type is the TypeVarTuple class itself (not a TypeVarType instance)."""
impl TypeEvaluator.is_type_var_tuple_class(ty: TypeBase) -> bool {
    return (
        self.prefetch
        and self.prefetch.type_var_tuple_class
        and isinstance(ty, types.ClassType)
        and ty.shared == self.prefetch.type_var_tuple_class.shared
    );
}

"""Assign the source type to the destination type."""
impl TypeEvaluator.assign_type(src_type: TypeBase, dest_type: TypeBase) -> bool {
    if src_type == dest_type {
        return True;
    }
    # Unknown destination: the declared type couldn't be resolved (e.g.
    # recursive type alias _ClassInfo, unresolved stub). Accept any
    # source — this is not the caller's fault.
    if isinstance(dest_type, types.UnknownType) {
        return True;
    }
    # Any is compatible with everything in both directions (PEP 484).
    if isinstance(src_type, types.AnyType) or isinstance(dest_type, types.AnyType) {
        return True;
    }
    # Literal type assignability rules (similar to Pyright's literalValue handling)
    if self.prefetch
    and isinstance(src_type, types.ClassType)
    and isinstance(dest_type, types.ClassType) {
        # Case 1: Literal["x"] -> LiteralString
        if src_type.is_literal_type()
        and self.prefetch.str_class
        and self.prefetch.literal_string_class {
            if src_type.shared == self.prefetch.str_class.shared {
                if dest_type.shared == self.prefetch.literal_string_class.shared {
                    return True;
                }
            }
        }

        # Case 2: Literal["x"] -> str (and other base types like int, bool)
        if src_type.is_literal_type() and not dest_type.is_literal_type() {
            if src_type.shared == dest_type.shared {
                return True;  # Literal[value] is assignable to its base type

            }
        }

        # Case 3: Literal["x"] -> Literal["y"] (same base type)
        # Allow any literal to be assigned to another literal of the same base type.
        # This effectively widens both to the base type (e.g., str).
        if src_type.is_literal_type() and dest_type.is_literal_type() {
            if src_type.shared == dest_type.shared {
                return True;
            }
        }

        # Case 3b: str -> Literal["x"] (base type to literal)
        # Allow base type to be assigned to a literal variable.
        # This handles cases like: part = ""; part = part + ":" where
        # the result type (str) needs to be assigned back to a Literal variable.
        if not src_type.is_literal_type() and dest_type.is_literal_type() {
            if src_type.shared == dest_type.shared {
                return True;
            }
        }

        # Case 4: LiteralString -> any type that str is assignable to
        # LiteralString is a subtype of str, so if str is assignable to dest, so is LiteralString.
        if self.prefetch.literal_string_class and self.prefetch.str_class {
            if src_type.shared == self.prefetch.literal_string_class.shared {
                # Delegate to str for assignability check
                str_instance = self._convert_to_instance(self.prefetch.str_class);
                if self.assign_type(str_instance, dest_type) {
                    return True;
                }
            }
        }
    }
    # Strict checking for JsxElement type - prevent non-JSX assignment to JsxElement
    if self.prefetch and self.prefetch.jsx_element_class {
        if isinstance(dest_type, types.ClassType)
        and isinstance(src_type, types.ClassType) {
            if dest_type.shared == self.prefetch.jsx_element_class.shared {
                # Destination is JsxElement - only allow JsxElement as source
                if src_type.shared != self.prefetch.jsx_element_class.shared {
                    return False;
                }
            }
        }
    }
    # --- Callable/FunctionType assignment compatibility ---
    # Handle assignment of functions to Callable types and vice versa.
    #
    # Gradual callable (bare `Callable` / `Callable[..., Any]`) accepts any function.
    if (
        isinstance(dest_type, types.FunctionType)
        and dest_type.is_gradual_callable_form()
        and isinstance(src_type, types.FunctionType)
    ) {
        return True;
    }
    if isinstance(dest_type, types.FunctionType) {
        if isinstance(src_type, types.FunctionType) {
            return self._assign_callable(src_type, dest_type);
        }
        # OverloadedType can be assigned to Callable if any overload matches
        if isinstance(src_type, types.OverloadedType) and src_type.overloads {
            for overload in src_type.overloads {
                if self._assign_callable(overload, dest_type) {
                    return True;
                }
            }
            return False;
        }
        # Class with __call__ method can be assigned to Callable
        if isinstance(src_type, types.ClassType) and src_type.is_class_instance() {
            if call_member := self._lookup_object_member(src_type, "__call__") {
                call_type = self.get_type_of_symbol(call_member.symbol);
                if isinstance(call_type, types.FunctionType) {
                    return self._assign_callable(call_type, dest_type);
                }
            }
        }
    }
    # Source is FunctionType assigned to a different type
    if isinstance(src_type, types.FunctionType) {
        # Check if dest_type is a class with __call__ method (callable object)
        if isinstance(dest_type, types.ClassType) and dest_type.is_class_instance() {
            if call_member := self._lookup_object_member(dest_type, "__call__") {
                call_type = self.get_type_of_symbol(call_member.symbol);
                if isinstance(call_type, types.FunctionType) {
                    return self._assign_callable(src_type, call_type);
                }
            }
        }
    }
    # Everything is assignable to Any or TypeVar.
    if self.is_any_type(dest_type) or self.is_any_type(src_type) {
        return True;
    }
    # Everything is assignable to object (all classes derive from object).
    # This is separate from is_any_type() because object should NOT allow
    # arbitrary attribute access like Any does.
    if isinstance(dest_type, types.ClassType) and dest_type.is_builtin("object") {
        return True;
    }
    # If source is a union type and destination is NOT a union, check if ALL
    # constituent types of source are assignable to destination.
    # Example: Dog | Cat -> Animal (valid if both Dog and Cat are subclasses of Animal)
    if isinstance(src_type, types.UnionType)
    and not isinstance(dest_type, types.UnionType) {
        for src_member in src_type.types {
            src_member_inst = self._convert_to_instance(src_member);
            if not self.assign_type(src_member_inst, dest_type) {
                return False;
            }
        }
        return True;
    }
    # If destination is a union type, check if source is compatible with any of the
    # constituent types.
    if isinstance(dest_type, types.UnionType) {
        # TODO: pre mature optimization is the root of all evil.
        # If source is also union, we need to check if the source type args are subset of the dest type args.
        if isinstance(src_type, types.UnionType) {
            for src_type_arg in src_type.types {
                matched = False;
                src_type_inst = self._convert_to_instance(src_type_arg);
                for dest_type_arg in dest_type.types {
                    dest_type_inst = self._convert_to_instance(dest_type_arg);
                    if self.assign_type(src_type_inst, dest_type_inst) {
                        matched = True;
                        break;  # Break out of the inner loop.
                    }
                }
                # If we didn't find a match for this src_type_arg, return False.
                if not matched {
                    return False;
                }
            }
            # If we reached here, all src_type_args matched at least one dest_type_arg.
            return True;
        }
        for union_type in dest_type.types {
            new_dest_type = self._convert_to_instance(union_type);
            if self.assign_type(src_type, new_dest_type) {
                return True;
            }
        }
    }
    # Enum member assignment compatibility
    if isinstance(src_type, types.EnumMemberType) {
        # Enum member can assign to its enum class (Color.RED -> Color ) -> a: Color = Color.RED
        if isinstance(dest_type, types.ClassType) and dest_type.is_enum_class() {
            if src_type.enum_class.shared == dest_type.shared {
                return True;
            }
        }
        # Enum members of same enum can assign to each other (Color.RED -> Color.BLUE) -> a: Color.BLUE = Color.RED
        if isinstance(dest_type, types.EnumMemberType) {
            if src_type.enum_class.shared == dest_type.enum_class.shared {
                return True;
            }
        }
        # StrEnum/IntEnum members can assign to their value type (Tokens.NAME -> str)
        if isinstance(dest_type, types.ClassType)
        and isinstance(
            enum_val_type := src_type.enum_class.shared.enum_value_type, types.ClassType
        )
        and dest_type.shared == enum_val_type.shared {
            return True;
        }
    }
    # --- type[X] and bare `type` assignment compatibility ---
    # Handle parameterized type[X] (covariant) and bare type (accepts any class).
    if self.prefetch and self.prefetch.type_class {
        if isinstance(dest_type, types.ClassType)
        and isinstance(src_type, types.ClassType) {
            if dest_type.shared == self.prefetch.type_class.shared {
                if src_type.is_instantiable_class() {
                    # Parameterized type[X]: check covariance
                    if dest_type.private and dest_type.private.type_args {
                        target_inner = self._convert_to_instance(
                            dest_type.private.type_args[0]
                        );
                        src_inner = self._convert_to_instance(src_type);
                        return self.assign_type(src_inner, target_inner);
                    }
                    # Bare type (no type_args): accept any instantiable class
                    return True;
                }
            }
        }
    }
    # Enum classes implicitly satisfy common protocols (Sized, Iterable,
    # Container, Hashable) via EnumMeta. Since Jac's type system doesn't
    # model metaclasses, accept enum class types for these protocols.
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
    # --- Structural protocol matching for typing protocols ---
    # Protocols like SupportsIndex, SupportsInt, SupportsFloat, Sized, etc.
    # define a single required dunder method. If the source type has that
    # method, it satisfies the protocol structurally (PEP 544).
    if (
        isinstance(dest_type, types.ClassType)
        and isinstance(src_type, types.ClassType)
        and src_type.is_class_instance()
        and dest_type.is_class_instance()
        and dest_type.shared
    ) {
        _protocol_methods: dict[str, str] = {
            "SupportsIndex": "__index__",
            "SupportsInt": "__int__",
            "SupportsFloat": "__float__",
            "SupportsComplex": "__complex__",
            "SupportsBytes": "__bytes__",
            "SupportsAbs": "__abs__",
            "SupportsRound": "__round__",
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
        return self._assign_class(src_type, dest_type);
    }
    return False;
}

"""Return the effective type of the expression.

When expected_type is provided, it enables bidirectional type inference
(Pyright: getTypeOfExpression with expectedType). Container literals
use the expected type's type_args to produce a more precise result.
"""
impl TypeEvaluator.get_type_of_expression(
    node_: uni.Expr, expected_type: TypeBase | None = None
) -> TypeBase {
    # Guard against None node
    if node_ is None {
        return types.UnknownType();
    }
    # To support JS style IIFE, abilities should be treated as expressions.
    if isinstance(node_, uni.Ability) {
        return self.get_type_of_ability(node_);
    }
    # Use cached result if available, UNLESS expected_type is provided
    # for a container literal that could benefit from bidirectional inference.
    if node_.type is not None {
        if expected_type is None
        or not isinstance(
            node_, (uni.ListVal, uni.DictVal, uni.SetVal, uni.TupleVal)
        ) {
            return node_.type;
        }
    }
    result = self._get_type_of_expression_core(node_, expected_type);
    node_.type = result;
    return result;
}

"""Pop a symbol from the resolution stack."""
impl TypeEvaluator.pop_symbol_resolution(symbol: uni.Symbol) -> bool {
    popped_entry = self.symbol_resolution_stack.pop();
    assert popped_entry.symbol == symbol;
    return popped_entry.is_result_valid;
}

"""
Push a symbol onto the resolution stack.

Return False if recursion detected and in that case it won't push the symbol.
"""
impl TypeEvaluator.push_symbol_resolution(symbol: uni.Symbol) -> bool {
    idx = self.get_index_of_symbol_resolution(symbol);
    if idx is not None {
        # Mark all of the entries between these two as invalid.
        for i in range(idx, len(self.symbol_resolution_stack)) {
            entry_ = self.symbol_resolution_stack[i];
            entry_.is_result_valid = False;
        }
        return False;
    }
    self.symbol_resolution_stack.append(SymbolResolutionStackEntry(symbol=symbol));
    return True;
}

"""Get the index of a symbol in the resolution stack."""
impl TypeEvaluator.get_index_of_symbol_resolution(symbol: uni.Symbol) -> int | None {
    for (i, entry_) in enumerate(self.symbol_resolution_stack) {
        if entry_.symbol == symbol {
            return i;
        }
    }
    return None;
}

"""Return the prefetched types for the type evaluator."""
impl TypeEvaluator._prefetch_types{
    # Helper to fetch a type and assert it's a ClassType
    def as_class_type(t: types.TypeBase) -> types.ClassType | None {
        if isinstance(t, types.ClassType) {
            return t;
        }
        return None;
    }
    # Module-specific fetch helpers that return ClassType | None
    def get_types_class(type_name: str) -> types.ClassType | None {
        return as_class_type(self._get_type_from_module(self.types_module, type_name));
    }
    def get_typing_class(type_name: str) -> types.ClassType | None {
        return as_class_type(
            self._get_type_from_module(self.typing_module, type_name)
        );
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
    # TODO: Pyright first try load NoneType from typeshed and if it cannot
    # then it set to unknown type.
    self.prefetch.none_type_class = get_types_class("NoneType");
    self.prefetch.object_class = get_builtin_class("object");
    self.prefetch.type_class = get_builtin_class("type");
    self.prefetch.classmethod_class = get_builtin_class("classmethod");
    self.prefetch.union_type_class = get_types_class("UnionType");
    # self.prefetch.awaitable_class =
    self.prefetch.function_class = get_types_class("FunctionType");
    # self.prefetch.method_class =
    self.prefetch.tuple_class = get_builtin_class("tuple");
    self.prefetch.bool_class = get_builtin_class("bool");
    self.prefetch.int_class = get_builtin_class("int");
    self.prefetch.float_class = get_builtin_class("float");
    self.prefetch.str_class = get_builtin_class("str");
    self.prefetch.bytes_class = get_builtin_class("bytes");
    self.prefetch.dict_class = get_builtin_class("dict");
    self.prefetch.list_class = get_builtin_class("list");
    self.prefetch.set_class = get_builtin_class("set");
    self.prefetch.enum_class = get_enum_class("Enum");
    if self.prefetch.enum_class {
        self.prefetch.enum_class.shared.is_enum_class = True;
    }
    self.prefetch.protocol_class = get_typing_class("Protocol");
    self.prefetch.any_class = get_typing_class("Any");
    # Prefetch Callable and set alias_name. This single instance is reused
    # for all Callable references, avoiding repeated ClassType creation.
    # Similar to Pyright's classType.priv.aliasName pattern.
    self.prefetch.callable_class = get_typing_class("Callable");
    if self.prefetch.callable_class {
        self.prefetch.callable_class.private.alias_name = "Callable";
    }
    # Create LiteralString as a special type with str as base class (like Pyright)
    if self.prefetch.str_class {
        self.prefetch.literal_string_class = self._create_special_builtin_type(
            "LiteralString", self.prefetch.str_class
        );
    }
    # Prefetched Jaclang builtin types
    self.prefetch.root_class = get_jac_builtin_class("Root");
    if self.prefetch.root_class {
        self.prefetch.root_class.shared.is_root_class = True;
    }
    self.prefetch.final_class = get_jac_builtin_class("Final");
    self.prefetch.node_class = get_jac_builtin_class("Node");
    self.prefetch.walker_class = get_jac_builtin_class("Walker");
    self.prefetch.jsx_element_class = get_jac_builtin_class("JsxElement");
    self.prefetch.html_common_props_class = get_jac_builtin_class("_HtmlCommonProps");
    # Fixed-width numeric types
    self.prefetch.i8_class = get_jac_builtin_class("i8");
    self.prefetch.u8_class = get_jac_builtin_class("u8");
    self.prefetch.i16_class = get_jac_builtin_class("i16");
    self.prefetch.u16_class = get_jac_builtin_class("u16");
    self.prefetch.i32_class = get_jac_builtin_class("i32");
    self.prefetch.u32_class = get_jac_builtin_class("u32");
    self.prefetch.i64_class = get_jac_builtin_class("i64");
    self.prefetch.u64_class = get_jac_builtin_class("u64");
    self.prefetch.f32_class = get_jac_builtin_class("f32");
    self.prefetch.f64_class = get_jac_builtin_class("f64");
}

"""Load and return builtins stub module."""
impl TypeEvaluator._load_stub_module(path: str) -> uni.Module {
    if not os.path.exists(path) {
        raise FileNotFoundError(f"Stub file not found at {path}");
    }
    # Convert to absolute path so this function and _import_module_from_path share the same hub key.
    resolved_path = str(Path(path).resolve());
    # Route jaclang-internal stubs (typeshed, etc.) to the compiler's
    # internal hub so they don't pollute the user's program hub.
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

"""Initialize the type evaluator with prefetched types.

Implementation Note:
--------------------
Pyright is prefetching the builtins when an evaluation is requested
on a node and from that node it does lookup for the builtins scope
and does the prefetch once, however if we forgot to call prefetch
in some place then it will not be available in the evaluator, So we
are prefetching the builtins at the constructor level once.
"""
impl TypeEvaluator.postinit -> None {
    # Initialize path constants (use __file__ from impl location)
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
    self._ENUM_STUB_FILE_PATH = os.path.join(
        os.path.dirname(__file__), "../../vendor/typeshed/stdlib/enum.pyi"
    );
    # Initialize objects that need constructor calls
    self.prefetch = PrefetchedTypes();
    self._flow_pending_symbols = set();
    self._flow_pending_keys = set();
    # NOTE: The initialization order here is important.
    self.typing_module = self._load_stub_module(self._TYPING_STUB_FILE_PATH);
    self.types_module = self._load_stub_module(self._TYPES_STUB_FILE_PATH);
    self.enum_module = self._load_stub_module(self._ENUM_STUB_FILE_PATH);
    # These prefetch types are essential for the builtin types.
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
    # Merge jac_builtins into builtins. Override imported symbols from builtins.pyi
    # (e.g. Callable, Any, Protocol) with the jac_builtins.pyi versions so they
    # pass the lookup_symtab import filter (builtins.pyi marks them as internal
    # imports, but jac_builtins.pyi intentionally re-exports them for user code).
    for (name, sym) in self.jac_builtins_module.names_in_scope.items() {
        existing = self.builtins_module.names_in_scope.get(name);
        if existing is None or existing.imported {
            self.builtins_module.names_in_scope[name] = sym;
        }
    }
    # Merge DOM types (Event, ChangeEvent, HTMLElement, etc.) into builtins
    for (name, sym) in self.dom_types_module.names_in_scope.items() {
        existing = self.builtins_module.names_in_scope.get(name);
        if existing is None or existing.imported {
            self.builtins_module.names_in_scope[name] = sym;
        }
    }
    self._prefetch_types();
}
# Cache the type, pyright is doing invalidateTypeCacheIfCanceled()
# we're not doing that any time sooner.

# -------------------------------------------------------------------------
# Type narrowing support (CFG-based, flow-sensitive)
# Pyright-style implementation with affected_symbols optimization.
# -------------------------------------------------------------------------
"""Find the nearest enclosing CFG node (CfgExpr or CodeBlockStmt)."""
def _find_cfg_node_for(at_node: uni.UniNode) -> uni.UniCFGNode | None {
    cur: uni.UniNode | None = at_node;
    while cur is not None {
        if isinstance(cur, uni.UniCFGNode) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

"""Get the narrowed type of a symbol at the given AST node via CFG walk."""
impl TypeEvaluator.get_narrowed_type(
    symbol: uni.Symbol, at_node: uni.UniNode
) -> TypeBase | None {
    import from jaclang.compiler.type_system.type_evaluator { NarrowingTarget }
    sym_id = id(symbol);
    if sym_id in self._flow_pending_symbols {
        return None;
    }
    symbol_type = self.get_type_of_symbol(symbol);
    if not isinstance(
        symbol_type, (types.UnionType, types.ClassType, types.UnknownType)
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

"""Get the narrowed type of a dotted expression (e.g. obj.attr) via CFG walk."""
impl TypeEvaluator.get_narrowed_type_for_expr(
    expr: uni.Expr, declared_type: TypeBase, at_node: uni.UniNode
) -> TypeBase | None {
    import from jaclang.compiler.type_system.type_evaluator { NarrowingTarget }
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
        narrowing_target = NarrowingTarget(key=key, declared_type=declared_type);
        flow_node = _find_cfg_node_for(at_node);
        if flow_node is not None {
            return self._get_type_from_flow_node(narrowing_target, flow_node, set());
        }
        return None;
    } finally {
        self._flow_pending_keys.discard(key);
    }
}

"""Flow-sensitive type of a reference at the given flow node.

Backward walk over bb_in with an affected_symbols fast path: predecessors
that neither narrow nor assign the target are skipped without recursion.
"""
impl TypeEvaluator._get_type_from_flow_node(
    target: NarrowingTarget, flow_node: uni.UniCFGNode, visited: set
) -> TypeBase | None {
    import from jaclang.compiler.type_system.type_evaluator { NarrowingTarget }
    key = target.key;
    # Keyed by (flow_node, symbol) when a symbol is available so that
    # different scopes with the same name don't collide; otherwise keyed
    # by the reference string (expression-based narrowing).
    cache_key = (id(flow_node), id(target.symbol))
        if target.symbol is not None
        else (id(flow_node), key);
    if cache_key in self._flow_node_type_cache {
        return self._flow_node_type_cache[cache_key];
    }
    flow_node_id = id(flow_node);
    if flow_node_id in visited {
        # Cycle (loop back-edge): conservative None.
        return None;
    }
    # Cap recursion depth in pathological graphs.
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
    # Loop headers: skip back-edges from the loop body so pre-loop
    # narrowing survives the join.
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

        # Fast path: predecessor neither narrows nor assigns this key.
        # CfgExpr nodes are transparent wrappers for short-circuit
        # operands — they only track symbols relevant to their own
        # boolean expression, so a missing key does not mean the
        # variable is unnarrowed.  Walk through them to reach the
        # enclosing statement-level CFG node where the real narrowing
        # (e.g., an isinstance guard on an if-stmt) may reside.
        if key not in pred.affected_symbols and not isinstance(pred, uni.CfgExpr) {
            has_unnarrowed_pred = True;
            continue;
        }

        pred_narrowed = self._get_type_from_flow_node(target, pred, visited);

        # CfgExpr predecessor: expression-level short-circuit branch.
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

        # IfStmt predecessor (covers ElseIf). Skip when the successor is a
        # CfgExpr: that's a condition-entry edge, not a true/false branch.
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
        # TODO: ElseIf (elif) narrowing needs CFG fix - predecessor nodes don't match.
        # The CFG builds correct links but type checker sees different node instances.
        # This is a future PR task.

        # AssertStmt predecessor: a passed assert narrows along the true branch.
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

        # Assignment predecessor: barrier. An assignment whose target writes
        # the reference key kills any pre-assignment narrowing on this edge.
        # Flat targets try strict narrowing from the RHS type; destructuring
        # targets attempt element-type extraction against a concrete tuple
        # RHS (`(x, _) = (5, "ok")` narrows `x` to `int`); otherwise the edge
        # resets to the declared type. Either way, we never fall through.
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
            }
            if target_key_matched {
                narrowed_from_assignment: TypeBase | None = None;
                assigned_type: TypeBase | None = None;
                if flat_target_matched {
                    assigned_type = self.get_type_of_expression(pred.value);
                } elif destructure_path is not None and len(destructure_path) > 0 {
                    # Pull the element type out of a concrete tuple RHS.
                    assigned_type = self._extract_tuple_element_type_path(
                        self.get_type_of_expression(pred.value), destructure_path
                    );
                }
                if (
                    assigned_type is not None
                    and not isinstance(assigned_type, types.UnknownType)
                ) {
                    declared_type = target.declared_type;
                    if (
                        self.assign_type(assigned_type, declared_type)
                        and not self.assign_type(declared_type, assigned_type)
                    ) {
                        narrowed_from_assignment = assigned_type;
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

        # MatchStmt predecessor: narrow by the pattern of the enclosing case.
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

        # No narrowing from this predecessor; propagate its type.
        if pred_narrowed is not None {
            incoming_types.append(pred_narrowed);
        } else {
            has_unnarrowed_pred = True;
        }
    }
    # Filter out NeverType from incoming_types — NeverType indicates an
    # unreachable path (e.g., false branch when incoming was narrowed to the
    # exact type being excluded). These should not participate in the join.
    incoming_types = [
        t
        for t in incoming_types
        if not isinstance(t, types.NeverType)
    ];
    # Merge incoming types.
    result: TypeBase | None = None;
    if len(incoming_types) == 0 {
        result = None;
    } elif has_unnarrowed_pred {
        # Some predecessor has no narrowing -- widen to declared type.
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

"""Classify a CFG edge from an IfStmt predecessor to a successor as true/false."""
impl TypeEvaluator._classify_edge(pred: uni.IfStmt, succ: uni.UniCFGNode) -> str {
    # True branch: succ is the first statement in pred.body.
    if pred.body and succ is pred.body[0] {
        return "true";
    }
    # False branch: ElseIf (which IS a CodeBlockStmt/UniCFGNode).
    if isinstance(pred.else_body, uni.ElseIf) and succ is pred.else_body {
        return "false";
    }
    # False branch: ElseStmt (NOT a CFG node) -- edge goes to its body[0].
    if isinstance(pred.else_body, uni.ElseStmt) {
        if pred.else_body.body and succ is pred.else_body.body[0] {
            return "false";
        }
    }
    # False branch: no else_body (fall-through to next sibling).
    if pred.else_body is None and succ not in pred.body {
        return "false";
    }
    return "unconditional";
}


"""Get a string key for an expression to use in narrowing.

Handles simple names (x), attribute access chains (x.foo.bar), and walrus
expressions (x := expr). Returns None if not suitable for narrowing.
"""
impl TypeEvaluator.create_key_for_reference(expr: uni.Expr) -> str | None {
    # Unwrap parentheses: (expr) → expr
    if isinstance(expr, uni.AtomUnit) and expr.value {
        return self.create_key_for_reference(expr.value);
    }
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.AtomTrailer) and expr.is_attr {
        # Build path like "x.foo.bar"
        base_key = self.create_key_for_reference(expr.target);
        if base_key and isinstance(expr.right, uni.Name) {
            return f"{base_key}.{expr.right.value}";
        }
    }
    # Walrus operator: (x := expr) - use the target name as narrowing key
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

"""Find the symbol associated with a narrowing key from a condition expression.

Used to get the original type of a variable for inverse narrowing in else branches.
"""
impl TypeEvaluator._find_symbol_by_key(
    key: str, condition: uni.Expr
) -> uni.Symbol | None {
    # For isinstance(x, T), get the symbol from the first argument
    if isinstance(condition, uni.FuncCall) and condition.params {
        first_arg = condition.params[0];
        if isinstance(first_arg, uni.Name) and first_arg.sym {
            return first_arg.sym;
        }
    }
    return None;
}

"""Classify a leaf condition into its narrowing kind + key.

Only handles leaf conditions (isinstance, callable, None checks, truthiness,
literal comparisons). Structural wrappers (parens, NOT, AND, OR, walrus)
are the caller's responsibility.

Returns None if the condition is not a recognized narrowing pattern.
"""
impl TypeEvaluator.classify_condition(condition: uni.Expr) -> ConditionInfo | None {
    import from jaclang.jac0core.constant { Tokens as Tok }
    import from jaclang.compiler.type_system.type_evaluator {
        ConditionInfo,
        NarrowingKind
    }
    # 1. isinstance(x, T)
    if isinstance_info := self._extract_isinstance_info(condition) {
        (key, narrow_type) = isinstance_info;
        return ConditionInfo(
            kind=NarrowingKind.ISINSTANCE, key=key, narrow_type=narrow_type
        );
    }
    # 2. callable(x)
    if callable_key := self._extract_callable_info(condition) {
        return ConditionInfo(kind=NarrowingKind.CALLABLE, key=callable_key,);
    }
    # 3-4. x is None / x is not None
    if (
        isinstance(condition, uni.CompareExpr)
        and len(condition.ops) == 1
        and len(condition.rights) == 1
        and isinstance(condition.rights[0], uni.Null)
    ) {
        narrowing_key = self.create_key_for_reference(condition.left);
        if narrowing_key is not None {
            op_name = condition.ops[0].name;
            if op_name == Tok.KW_IS {
                return ConditionInfo(kind=NarrowingKind.NONE_IS, key=narrowing_key);
            } elif op_name == Tok.KW_ISN {
                return ConditionInfo(
                    kind=NarrowingKind.NONE_IS_NOT, key=narrowing_key
                );
            }
        }
    }
    # 5-6. x == literal / x != literal (non-None CompareExpr)
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
    # 7. Truthiness: if x / if x.attr
    if isinstance(condition, (uni.Name, uni.AtomTrailer)) {
        narrowing_key = self.create_key_for_reference(condition);
        if narrowing_key is not None {
            return ConditionInfo(kind=NarrowingKind.TRUTHINESS, key=narrowing_key);
        }
    }
    # 8. Walrus truthiness: if (x := expr)
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


"""Find a narrowing predicate for a specific symbol in a condition expression.

Supports the following patterns (Pyright-compatible):
- isinstance(x, T) / isinstance(x, (A, B, C))
- x is None / x is not None
- not <condition> (inverts inner predicate)
- <cond1> and <cond2> (returns first matching predicate)
- <cond1> or <cond2> (unions all positive isinstance predicates)
- (parenthesized_condition) (unwraps AtomUnit)
- if x: (truthiness - excludes None/falsy)
- x == literal / x != literal (literal equality)
"""
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
    # Pattern 0: Unwrap parenthesized expressions (AtomUnit)
    # Handles: (isinstance(x, T)), ((x is None)), etc.
    if isinstance(condition, uni.AtomUnit) and isinstance(condition.value, uni.Expr) {
        return self._find_predicate_for(target, condition.value);
    }
    # Pattern 1: NOT handling (UnaryExpr with NOT operator)
    # Handles: not isinstance(x, T), not (x is None), etc.
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
                is_inverted=not inner_pred.is_inverted
            );
        }
        return None;
    }
    # Patterns 2-3: Handle AND, OR via match statement
    if isinstance(condition, uni.BoolExpr) {
        match condition.op.name {
            # Pattern 2: Compound AND (BoolExpr with KW_AND)
            # Handles: isinstance(x, A) and isinstance(x, B)
            # For multiple isinstance checks on SAME symbol, return most specific type.
            # Example: isinstance(x, BaseNode) and isinstance(x, CFGNode) -> CFGNode
            case Tok.KW_AND:
                all_preds = [
                    p
                    for val in condition.values
                    if (p := self._find_predicate_for(target, val)) is not None
                ];
                if not all_preds {
                    return None;
                }
                # Find most specific non-inverted predicate.
                # Inverted predicates (not isinstance) are exclusions, handled separately.
                positive_preds = [
                    p
                    for p in all_preds
                    if not p.is_inverted
                ];
                if not positive_preds {
                    return all_preds[0];  # All inverted, return first

                }
                # Find most specific (subclass) among positive predicates.
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

            # Pattern 3: Compound OR (BoolExpr with KW_OR)
            # Two sub-patterns:
            #   a) isinstance(x, A) or isinstance(x, B) → narrows to A|B (positive)
            #   b) not x or not x.attr → inverted truthiness predicates
            # For (a), the true branch narrows to A|B. For (b), the false branch
            # (all operands falsy) means each inverted pred's inner condition is true.
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
                # Sub-pattern (a): all positive → union for true branch
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
                # Sub-pattern (b): has inverted predicates (e.g., `not x or not x.y`)
                # Return first matching predicate for this target. On the false branch,
                # _apply_narrowing inverts is_inverted (double negation → positive).
                for p in matched {
                    if p.key == key {
                        return p;
                    }
                }
                return matched[0];

        }
    }
    # Unified leaf classification — covers isinstance, callable, None is/is not,
    # literal eq/ne, truthiness, and walrus variants.
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
                    # For walrus (x := expr), check the assigned type for None
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

"""Apply a narrowing predicate to compute a narrowed type.

For positive narrowing (isinstance true branch), this method is inheritance-aware:
- If base type is `A | B | C` and we check `isinstance(x, T)`,
  the result includes all types that are subclasses of T.
- Example: `isinstance(x, int)` with `x: str | IndexSlice | int | None`
  narrows to `IndexSlice | int` (all int subclasses).
"""
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
    # Determine if this is positive (narrow to type) or negative (exclude type).
    is_positive: bool = (
        is_true_branch if not predicate.is_inverted else not is_true_branch
    );
    if is_positive {
        # Get the base type to filter
        base_type: TypeBase;
        if incoming is not None {
            base_type = incoming;
        } else {
            base_type = target.declared_type;
        }
        # Filter the base union to only include types that are subclasses
        # of the narrow_type (inheritance-aware isinstance narrowing).
        # Also handles non-ClassType identity matching (e.g., FunctionType
        # from callable() narrowing).
        filtered = self._filter_union_for_isinstance(base_type, predicate.narrow_type);
        if filtered is not None {
            return filtered;
        }
        # Fallback: return the narrow_type directly
        return predicate.narrow_type;
    } else {
        # Negative narrowing: exclude narrow_type from the base type.
        base_type: TypeBase;
        if incoming is not None {
            base_type = incoming;
        } else {
            base_type = target.declared_type;
        }
        result = self.exclude_type_from_union(base_type, predicate.narrow_type);
        # If exclusion didn't change the type (e.g., non-union or already narrowed),
        # return the base_type if it was provided as incoming (already narrowed upstream),
        # otherwise return None to indicate no narrowing.
        if result is base_type {
            # If incoming was provided, the type is already narrowed - return it.
            # If incoming was None, we got the declared type and couldn't narrow it.
            return incoming;
        }
        return result;
    }
}

"""Refine an isinstance narrowed type by filtering the variable's declared type.

When isinstance(x, list) narrows x: list[int] | str, using bare `list` loses
the generic params. Instead, filter the declared union to keep only members
that are instances of the isinstance class, preserving their type arguments.
Falls back to the raw isinstance type if no union filtering is possible
(e.g., the variable's type is not a union, or no members match).
"""
impl TypeEvaluator._refine_isinstance_type(
    narrowing_key: str, isinstance_type: types.TypeBase, condition: uni.Expr
) -> types.TypeBase {
    sym = self._find_symbol_by_key(narrowing_key, condition);
    if sym is not None {
        base_type = self.get_type_of_symbol(sym);
        filtered = self._filter_union_for_isinstance(base_type, isinstance_type);
        if filtered is not None {
            return filtered;
        }
    }
    return isinstance_type;
}

"""Filter a union type to only include types that pass isinstance(x, target_type).

Returns types from the union that are:
1. The same as target_type
2. Subclasses of target_type
3. Types where target_type is a subclass (for contravariant checks)
"""
impl TypeEvaluator._filter_union_for_isinstance(
    base_type: TypeBase, target_type: TypeBase
) -> TypeBase | None {
    # Collect matching types from the base union
    matching: list[TypeBase] = [];
    # Handle base_type being a union
    if isinstance(base_type, types.UnionType) and base_type.types {
        for t in base_type.types {
            if self._type_matches_isinstance(t, target_type) {
                matching.append(t);
            }
        }
    } else {
        # Single type
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

"""Check if a type matches an isinstance check against target_type.

Returns True if:
1. t is the same class as target_type
2. t is a subclass of target_type
"""
impl TypeEvaluator._type_matches_isinstance(
    t: TypeBase, target_type: TypeBase
) -> bool {
    # Handle target_type being a union (isinstance(x, (A, B)))
    if isinstance(target_type, types.UnionType) and target_type.types {
        for target_t in target_type.types {
            if self._type_matches_isinstance(t, target_t) {
                return True;
            }
        }
        return False;
    }
    # Both must be ClassTypes for subclass checking
    if isinstance(t, types.ClassType) and isinstance(target_type, types.ClassType) {
        # Same class?
        if t.shared is not None and target_type.shared is not None {
            if t.shared == target_type.shared {
                return True;
            }
        }
        # Is t a subclass of target_type?
        if self.is_sub_class(target_type, t) {
            return True;
        }
    }
    # Non-ClassType identity match (e.g., FunctionType from callable() narrowing)
    if t is target_type {
        return True;
    }
    return False;
}

"""Union multiple narrowed types at a join point."""
impl TypeEvaluator._union_narrowed_types(types_list: list) -> TypeBase {
    if len(types_list) == 0 {
        return types.NeverType();
    }
    if len(types_list) == 1 {
        return types_list[0];
    }
    # Flatten any UnionTypes.
    flat: list[TypeBase] = [];
    for t in types_list {
        if isinstance(t, types.UnionType) and t.types {
            flat.extend(t.types);
        } else {
            flat.append(t);
        }
    }
    # Deduplicate by ClassType.shared identity.
    unique: list[TypeBase] = [];
    seen_shared: set = set();
    for t in flat {
        if isinstance(t, types.ClassType) and t.shared is not None {
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

"""Exclude a type from a union, returning the remaining type(s).

Handles:
- Excluding ClassType members by shared identity
- Excluding non-ClassType members (FunctionType, etc.) by object identity
- Excluding a UnionType from another UnionType (excludes all types in the union)
"""
impl TypeEvaluator.exclude_type_from_union(
    original: TypeBase, to_exclude: TypeBase
) -> TypeBase {
    if isinstance(original, types.UnionType) and original.types {
        # Build sets of identifiers to exclude:
        # - ClassType: use shared ID (two ClassType instances with same shared are equal)
        # - Non-ClassType (FunctionType, etc.): use object ID (identity comparison)
        exclude_shareds: set = set();
        exclude_ids: set = set();
        to_exclude_list: list[TypeBase] = [];
        if isinstance(to_exclude, types.UnionType) and to_exclude.types {
            to_exclude_list = to_exclude.types;
        } else {
            to_exclude_list = [to_exclude];
        }
        for excl_t in to_exclude_list {
            if isinstance(excl_t, types.ClassType) and excl_t.shared is not None {
                exclude_shareds.add(id(excl_t.shared));
            } else {
                exclude_ids.add(id(excl_t));
            }
        }
        remaining: list[TypeBase] = [];
        for t in original.types {
            if isinstance(t, types.ClassType) and t.shared is not None {
                if id(t.shared) in exclude_shareds {
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
    # Non-union original: check if it exactly matches the exclusion type.
    # e.g., exclude NoneType from NoneType → NeverType (empty).
    # This is critical for CFG join-point reasoning: when the incoming type
    # is narrowed to NoneType and the false branch excludes None, the result
    # should be NeverType (unreachable path), not the original NoneType.
    if isinstance(original, types.ClassType)
    and isinstance(to_exclude, types.ClassType)
    and original.shared is not None
    and to_exclude.shared is not None
    and original.shared == to_exclude.shared {
        return types.NeverType();
    }
    # Non-ClassType exact match (e.g., FunctionType)
    if original is to_exclude {
        return types.NeverType();
    }
    return original;
}

"""Extract type from a match pattern for type narrowing.

Handles:
- MatchArch (class pattern): case MyClass() -> narrows to MyClass
- MatchOr (union pattern): case A() | B() -> narrows to A | B
- MatchAs (capture pattern): case _ as x: A() -> narrows to inner pattern type
- MatchWild (wildcard): case _ -> no narrowing (returns None)
"""
impl TypeEvaluator._get_type_from_match_pattern(
    pattern: uni.MatchPattern
) -> TypeBase | None {
    # MatchArch (class pattern): case MyClass() or case mod.MyClass()
    if isinstance(pattern, uni.MatchArch) {
        class_type = self.get_type_of_expression(pattern.name);
        return self._convert_to_instance(class_type);
    }
    # MatchOr (union pattern): case A() | B() | C()
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
    # MatchAs (capture with inner pattern): case x as MyClass()
    if isinstance(pattern, uni.MatchAs) and pattern.pattern {
        return self._get_type_from_match_pattern(pattern.pattern);
    }
    # MatchWild (wildcard): case _ -> no narrowing
    if isinstance(pattern, uni.MatchWild) {
        return None;
    }
    # Other patterns (MatchValue, MatchSingleton, etc.) - no type narrowing for now
    return None;
}

"""Check if a union type contains None.

Used for truthiness narrowing: `if x:` where `x: T | None` should narrow to `T`.
"""
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

"""Parse isinstance(x, T) or isinstance(x, (A,B)) → ("x", T|A|B) or None."""
impl TypeEvaluator._extract_isinstance_info(
    condition: uni.Expr
) -> tuple[str, types.TypeBase] | None {
    # Must be isinstance(expr, type) or isinstance(expr, (T1, T2))
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
    # First arg → narrowing key (e.g., "x" or "a.b.c")
    narrowing_key = self.create_key_for_reference(condition.params[0]);
    if narrowing_key is None {
        return None;
    }
    # Second arg → type(s) to narrow to
    type_arg = condition.params[1];
    # Tuple of types: isinstance(x, (A, B)) → A | B
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
    # Single type: isinstance(x, T)
    return (
        narrowing_key,
        self._convert_to_instance(self.get_type_of_expression(type_arg))
    );
}

"""Parse callable(x) → narrowing_key or None.

Detects calls to the builtin `callable()` with a single argument and
returns the narrowing key for that argument, or None if the condition
is not a callable() call.
"""
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

"""Check whether a type is callable (FunctionType or Callable annotation)."""
impl TypeEvaluator._is_callable_type(t: types.TypeBase) -> bool {
    if isinstance(t, types.FunctionType) {
        return True;
    }
    if isinstance(t, types.ClassType) {
        # Check if this is a Callable annotation (e.g., Callable[[int], str])
        if (
            self.prefetch
            and self.prefetch.callable_class
            and t.shared is not None
            and t.shared == self.prefetch.callable_class.shared
        ) {
            return True;
        }
        # Check for classes with __call__ method
        if t.shared is not None and t.shared.symbol_table is not None {
            if t.shared.symbol_table.lookup("__call__", deep=False) is not None {
                return True;
            }
        }
    }
    return False;
}

"""Filter a union type to only its callable members.

Given a union like `Callable[[int], str] | str | None`, returns
`Callable[[int], str]`. For non-union types, returns the type unchanged
if it is callable, or NeverType if not.
"""
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

"""Filter a union type to only its non-callable members.

Given a union like `Callable[[int], str] | str | None`, returns
`str | None`. For non-union types, returns the type unchanged if it
is not callable, or NeverType if it is callable.
"""
impl TypeEvaluator._filter_union_to_non_callables(
    union_type: types.TypeBase
) -> types.TypeBase {
    if isinstance(union_type, types.UnionType) and union_type.types {
        non_callables: list[types.TypeBase] = [
            t
            for t in union_type.types
            if not self._is_callable_type(t)
        ];
        if len(non_callables) == 0 {
            return types.NeverType();
        } elif len(non_callables) == 1 {
            return non_callables[0];
        } else {
            return types.UnionType(types=non_callables);
        }
    }
    if not self._is_callable_type(union_type) {
        return union_type;
    }
    return types.NeverType();
}

"""Check whether an annotation type represents typing.TypeAlias.

Uses symbol-based detection: TypeAlias is a _SpecialForm from the typing
module, so its resolved type shares the same ClassType.shared as other
special forms (e.g. Callable). We verify both the structural match and
the name to avoid false positives with other special forms.
"""
impl TypeEvaluator._is_type_alias_annotation(
    annotation_type: types.TypeBase, tag_expr: uni.Expr
) -> bool {
    if not self.prefetch or not self.prefetch.callable_class {
        return False;
    }
    # Structural check: TypeAlias is a _SpecialForm, same as Callable etc.
    is_special_form = (
        isinstance(annotation_type, types.ClassType)
        and annotation_type.shared is not None
        and annotation_type.shared == self.prefetch.callable_class.shared
    );
    # Name check: verify the tag is specifically "TypeAlias"
    if is_special_form and isinstance(tag_expr, uni.Name) {
        return tag_expr.value == "TypeAlias";
    }
    # Fallback for unresolved imports: annotation may be Unknown but
    # the name is still "TypeAlias" (e.g. from typing_extensions chain)
    if (
        isinstance(annotation_type, types.UnknownType)
        and isinstance(tag_expr, uni.Name)
    ) {
        return tag_expr.value == "TypeAlias";
    }
    return False;
}

"""Resolve the RHS of a TypeAlias assignment to a type.

Handles both expression RHS (e.g. `Foo | None`) and string forward
references (e.g. `'SomeType'`). For string RHS containing complex
type expressions that cannot be parsed, returns UnknownType.

For stub modules (.pyi), diagnostics emitted during RHS evaluation are
suppressed — stubs are trusted type definitions whose internal expressions
may reference types the Jac resolver cannot fully handle (e.g. cross-module
imports in builtins.pyi like `types.UnionType`).
"""
impl TypeEvaluator._resolve_type_alias_rhs(value: uni.Expr) -> types.TypeBase {
    # String RHS: complex type expression or simple forward reference.
    if isinstance(value, uni.String) and isinstance(value.lit_value, str) {
        # Try simple name lookup first (fast path)
        resolved = self._try_resolve_forward_ref(value);
        if resolved is not None {
            return resolved;
        }
        # Try parsing as a complex type expression (e.g. 'Callable[[A], B] | C')
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
    # Expression RHS: evaluate the type expression directly.
    # For stub modules, suppress diagnostics — stubs may contain
    # cross-module type references that can't be resolved in Jac.
    mod = value.find_parent_of_type(uni.Module);
    is_stub = mod is not None and mod.is_raised_from_py;
    if is_stub and self._pass is not None {
        pass_ref = self._pass;
        errors_before = len(pass_ref.errors_had);
        prog_errors_before = len(pass_ref.prog.errors_had);
        result = self.get_type_of_expression(value);
        # Roll back any diagnostics emitted during stub resolution
        del pass_ref.errors_had[errors_before:];
        del pass_ref.prog.errors_had[prog_errors_before:];
        return result;
    }
    return self.get_type_of_expression(value);
}

"""Parse a string type expression and resolve it to a type.

Handles complex type expressions like 'Callable[[A], B] | C | None'
by parsing the string using Python's ast module and recursively
resolving each component in the given scope.
"""
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

"""Resolve a single Python AST node to a Jac type.

Handles Name, Constant(None), BinOp(|), Subscript (Callable, generics),
and Attribute (module.Type). Recurses via explicit self-calls rather than
a nested closure to avoid bootstrap compiler limitations.
"""
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
    # Name: symbol lookup (e.g. 'Archetype', 'str')
    if isinstance(ast_node, _N) {
        sym = type_utils.lookup_symtab(scope, ast_node.id, self.builtins_module);
        if not sym {
            return None;
        }
        sym = self.resolve_imported_symbols(sym);
        return self.get_type_of_symbol(sym);
    }
    # Constant(None) → NoneType
    if isinstance(ast_node, _C) and ast_node.value is None {
        if self.prefetch and self.prefetch.none_type_class {
            return self.prefetch.none_type_class;
        }
        return None;
    }
    # BinOp with | → UnionType
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
    # Subscript → Callable or generic type
    if isinstance(ast_node, _SS) {
        base = self._resolve_py_ast_type_node(ast_node.value, scope);
        if base is None {
            return None;
        }
        # Callable[[ParamTypes], ReturnType]
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
        # Other generics: list[X], dict[K, V], etc.
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
    # Attribute → module.Type (e.g. types.UnionType)
    if isinstance(ast_node, _AT) {
        base = self._resolve_py_ast_type_node(ast_node.value, scope);
        if (
            base is not None
            and isinstance(base, types.ModuleType)
            and base.symbol_table is not None
        ) {
            member = base.symbol_table.lookup(ast_node.attr);
            if member {
                return self.get_type_of_symbol(member);
            }
        }
        return None;
    }
    return None;
}
