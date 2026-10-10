impl NaIRGenPass._quiet_glob_type(type_expr: (uni.UniNode | None)) -> (ir.Type | None) {
    if type_expr is None {
        return ir.IntType(64);
    }
    if isinstance(type_expr, uni.SubTag) and type_expr?.tag is not None {
        return self._quiet_glob_type(type_expr.tag);
    }
    _ptb = _node_sem_type(type_expr);
    if _ptb is None {
        return None;
    }
    try {
        return self._lower_type(_ptb);
    } except Exception {
        return None;
    }
}

impl NaIRGenPass._glob_native_use_exists(target: uni.UniNode) -> bool {
    sym = target.sym if isinstance(target, uni.NameAtom) else None;
    if sym is None {
        return True;
    }
    for use in sym.uses {
        _m = use.find_parent_of_type(uni.Module);
        if _m is None {
            continue;
        }
        if _m is self.module or _m.decided_codespace == 'native' {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._register_globals(module: uni.Module) -> None {
    for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.GlobalVars) {
            self._codegen_global_vars(stmt);
        }
    }
}

impl NaIRGenPass._register_entry_globals(module: uni.Module) -> None {
    import from jaclang.compiler.frontend.constant { SymbolStorage }
    candidates: dict[str, ir.Type] = {};
    dropped: set[str] = set();
    for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE) {
        if not isinstance(stmt, uni.ModuleCode) {
            continue;
        }
        for assign in stmt.get_all_sub_nodes(typ=uni.Assignment) {
            if assign.aug_op is not None {
                continue;
            }
            for target in assign.target {
                if (
                    not isinstance(target, uni.NameAtom)
                    or target.sym is None
                    or target.sym.storage != SymbolStorage.MODULE_GLOBAL
                ) {
                    continue;
                }
                var_name = self._get_name(target);
                if (
                    var_name is None
                    or var_name in self.global_vars
                    or var_name in dropped
                ) {
                    continue;
                }
                var_type: (ir.Type | None) = None;
                if isinstance(target, uni.Expr) {
                    try {
                        var_type = self._lower_type(target.type);
                    } except Exception {
                        var_type = None;
                    }
                }
                if var_type is None and assign.value is not None {
                    var_type = self._infer_global_init_type(assign.value);
                }
                if var_type is None or isinstance(var_type, ir.VoidType) {
                    dropped.add(var_name);
                    candidates.pop(var_name, None);
                    continue;
                }
                prev = candidates.get(var_name);
                if prev is not None and prev != var_type {
                    dropped.add(var_name);
                    candidates.pop(var_name, None);
                    continue;
                }
                candidates[var_name] = var_type;
            }
        }
    }
    import from jaclang.compiler.frontend.codeinfo { native_def_symbol }
    for (var_name, var_type) in candidates.items() {
        try {
            global_var = ir.GlobalVariable(
                self.llvm_module, var_type, name=native_def_symbol(var_name)
            );
        } except Exception as _dup_err {
            continue;
        }
        global_var.linkage = "internal";
        global_var.initializer = ir.Constant(var_type, None);
        self.global_vars[var_name] = global_var;
        self.global_var_types[var_name] = var_type;
        self._global_origins[var_name] = module.loc.mod_path
            if module?.loc
            else "(current module)";
        self.has_native_code = True;
    }
}

impl NaIRGenPass._codegen_global_vars(nd: uni.GlobalVars) -> None {
    for assign in nd.assignments {
        if ModuleFacts.is_erased_type_decl(assign) {
            continue;
        }
        targets = assign.target
            if isinstance(assign.target, (list, tuple))
            else [(assign.target)];
        for target in targets {
            var_name = self._get_name(target);
            if var_name is None {
                continue;
            }

            var_type: ir.Type = ir.IntType(64);
            _static_sname = self._static_struct_init_name(assign);
            if assign.type_tag is not None {
                if _static_sname is not None {
                    var_type = self._clib_c_type(_static_sname);
                } else {
                    _widened = self._widened_tuple_decl_type(assign.type_tag, assign.value);
                    if (
                        _widened is None
                        and self._quiet_glob_type(assign.type_tag) is None
                        and not self._glob_native_use_exists(target)
                    ) {
                        continue;
                    }
                    var_type = self._resolve_decl_type(assign.type_tag, assign.value);
                }
            } elif assign.value is not None {
                inferred = self._infer_global_init_type(assign.value);
                if inferred is not None {
                    var_type = inferred;
                }
            }

            _is_priv = bool(nd.access and nd.access.tag.name == Tok.KW_PRIV);
            _is_pub = bool(nd.access and nd.access.tag.name == Tok.KW_PUB);
            _symbol = self._symbol_for(var_name, None, _is_pub);
            try {
                global_var = ir.GlobalVariable(
                    self.llvm_module, var_type, name=_symbol
                );
            } except Exception as _dup_err {
                _cur_path = self.module.loc.mod_path
                    if self.module?.loc
                    else "(current module)";
                _origin = self._global_origins.get(var_name, "(imported module)");
                self.emit(
                    E5026, symbol=_symbol, existing_module=_origin, new_module=_cur_path
                );
                continue;
            }

            if _is_priv {
                global_var.linkage = "internal";
            } else {
                global_var.linkage = "";
                self._record_export(var_name, _symbol, "global", _is_pub);
            }

            if _is_pub and self.module?.gen and _symbol.isidentifier() {
                if _symbol not in self.module.gen._exported_symbols {
                    self.module.gen._exported_symbols.append(_symbol);
                }
            }

            const_init: (ir.Constant | None) = None;
            if _static_sname is not None {
                global_var.initializer = ir.Constant(var_type, None);
                _static_call = (
                    assign.value if isinstance(assign.value, uni.FuncCall) else None
                );
                if _static_call is not None {
                    self.static_struct_inits.append(
                        (var_name, _static_sname, _static_call)
                    );
                }
            } else {
                const_init = self._codegen_const_expr(assign.value, var_type)
                    if assign.value is not None
                    else None;
                if const_init is not None {
                    global_var.initializer = const_init;
                } else {
                    global_var.initializer = ir.Constant(var_type, None);
                }
            }
            self.global_vars[var_name] = global_var;
            self.global_var_types[var_name] = var_type;

            self._global_origins[var_name] = self.module.loc.mod_path
                if self.module?.loc
                else "(current module)";
            self.has_native_code = True;

            if (
                assign.value is not None
                and const_init is None
                and _static_sname is None
            ) {
                self._global_init_nodes.append((var_name, assign.value, var_type));
            }
        }
    }
}

impl NaIRGenPass._infer_global_init_type(value_node: uni.UniNode) -> (ir.Type | None) {
    if isinstance(value_node, uni.Expr) and value_node?.type is not None {
        lowered = self._lower_type(value_node.type);
        if lowered is not None {
            return lowered;
        }
    }

    if isinstance(value_node, uni.FuncCall) {
        call_name = self._arch_ref_key(value_node.target)
            or self._get_name(value_node.target);
        if call_name is not None and call_name in self.struct_types {
            return self.struct_types[call_name].as_pointer();
        }
    }

    if isinstance(value_node, uni.AtomTrailer) {
        target_name = self._arch_ref_key(value_node.target)
            or self._get_name(value_node.target);
        if target_name is not None and target_name in self.struct_types {
            return self.struct_types[target_name].as_pointer();
        }

        right_name = self._get_name(value_node.right);
        if target_name == "sys" and right_name == "argv" {
            i8p = ir.IntType(8).as_pointer();
            self._emit_list_helpers("ptr", i8p);
            list_type = self.list_types.get("ptr");
            if list_type is not None {
                return list_type.as_pointer();
            }
        }
    }
    return None;
}

impl NaIRGenPass._codegen_const_expr(
    nd: uni.UniNode, target_type: ir.Type
) -> (ir.Constant | None) {
    import from jaclang.compiler.frontend.const_fold { fold_const }
    if self?.jacval_type and target_type == self.jacval_type {
        return None;
    }
    if (
        isinstance(nd, uni.TupleVal)
        and not nd.values
        and isinstance(target_type, ir.PointerType)
        and isinstance(target_type.pointee, ir.LiteralStructType)
        and not target_type.pointee.elements
    ) {
        return ir.Constant(target_type, None);
    }
    cv = nd.ct_value if isinstance(nd, uni.Expr) else None;
    if cv is not None and not cv.is_deferred {
        if isinstance(cv, CtBool) {
            return ir.Constant(target_type, 1 if cv.value else 0);
        }
        if isinstance(cv, CtInt) and not cv.mag {
            return ir.Constant(target_type, cv.small);
        }
        if isinstance(cv, CtFloat) {
            return ir.Constant(target_type, cv.value);
        }
    }
    (ok, v) = fold_const(nd);
    if not ok {
        return None;
    }
    if isinstance(v, bool) {
        return ir.Constant(target_type, 1 if v else 0);
    }
    if isinstance(v, (int, float)) {
        return ir.Constant(target_type, v);
    }
    return None;
}

impl NaIRGenPass._register_enums(module: uni.Module) -> None {
    for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Enum) {
            self._codegen_enum(stmt, quiet=True);
        }
    }
}

impl NaIRGenPass._static_struct_name_of_call(nd: uni.UniNode) -> (str | None) {
    if not isinstance(nd, uni.FuncCall) {
        return None;
    }
    callee = self._arch_ref_key(nd.target);
    if callee is None or callee not in self.clib_struct_names {
        return None;
    }
    if callee not in self.struct_types
        or not self.struct_field_order.get(callee)
    {
        return None;
    }
    return callee;
}

impl NaIRGenPass._static_struct_init_name(assign: uni.Assignment) -> (str | None) {
    if assign.value is None or assign.type_tag is None {
        return None;
    }
    declared = self._static_struct_name_of_call(assign.value);
    if declared is None {
        return None;
    }
    tag_name = self._get_name(assign.type_tag.tag)
        if isinstance(assign.type_tag, uni.SubTag)
        else None;
    if tag_name != declared {
        return None;
    }
    return declared;
}

impl NaIRGenPass._build_static_struct_const(
    sname: str, call: uni.FuncCall, depth: int
) -> (ir.Constant | None) {
    if depth > 8 {
        return None;
    }
    stype = self.struct_types.get(sname);
    field_order = self.struct_field_order.get(sname) or [];
    if stype is None or not field_order {
        return None;
    }
    pos: list[uni.Expr] = [];
    kw: dict[str, uni.Expr] = {};
    for p in (call.params or []) {
        if isinstance(p, uni.KWPair) {
            k = self._get_name(p.key);
            if k is None {
                return None;
            }
            kw[k] = p.value;
        } else {
            pos.append(p);
        }
    }
    ctor_order = self.struct_constructor_order.get(sname) or field_order;
    if len(pos) > len(ctor_order) {
        return None;
    }
    given: dict[str, uni.Expr] = dict(kw);
    for (i, v) in enumerate(pos) {
        given[ctor_order[i]] = v;
    }
    consts: list[ir.Value] = [];
    for fname in field_order {
        ftype = self.struct_field_types.get(sname, {}).get(fname);
        if ftype is None {
            return None;
        }
        nd = given.get(fname);
        if nd is None {
            nd = self.struct_field_defaults.get(sname, {}).get(fname);
        }
        c = self._build_static_field_const(ftype, nd, depth + 1);
        if c is None {
            self.emit(
                E5092,
                kind="static struct member",
                name=f"{sname}.{fname}",
                help_text=(
                    "This member's value could not be lowered to a "
                    f"compile-time constant for the static struct initializer "
                    f"(field lowers to '{ftype}'; member AST node is "
                    f"{type(nd).__name__})."
                ),
            );
            return None;
        }
        consts.append(c);
    }
    return ir.Constant(stype, consts);
}

impl NaIRGenPass._build_static_field_const(
    ftype: ir.Type, nd: (uni.UniNode | None), depth: int
) -> (ir.Value | None) {
    if nd is None {
        return ir.Constant(ftype, None);
    }
    nm = self._get_name(nd);
    if nm == "None" {
        return ir.Constant(ftype, None);
    }
    if isinstance(nd, uni.AtomUnit) {
        # A parenthesized atom wraps the real constant expression.
        if isinstance(nd.value, uni.Expr) {
            return self._build_static_field_const(ftype, nd.value, depth);
        }
    }
    if isinstance(nd, (uni.String, uni.MultiString)) {
        lit = nd.lit_value;
        if isinstance(lit, str) {
            return self._static_c_string_global(lit, ftype);
        }
    }
    if isinstance(nd, uni.FuncCall) {
        # `ptr[T]()` / `ptr()` is the null-pointer constant; the generic form
        # parses as an AtomTrailer over the `ptr` name.
        ptr_tgt = nd.target;
        if isinstance(ptr_tgt, uni.AtomTrailer) {
            ptr_tgt = ptr_tgt.target;
        }
        callee_name = self._get_name(ptr_tgt);
        if (
            callee_name == "ptr"
            and (nd.params is None or not nd.params)
        ) {
            if isinstance(ftype, ir.PointerType) or ftype == ir.IntType(64) {
                return ir.Constant(ftype, None);
            }
            return None;
        }
        nested = self._static_struct_name_of_call(nd);
        if nested is not None and ftype == self.struct_types.get(nested) {
            return self._build_static_struct_const(nested, nd, depth);
        }
        return None;
    }
    cv = nd.ct_value if isinstance(nd, uni.Expr) else None;
    if cv is not None and not cv.is_deferred {
        if isinstance(cv, CtBool) {
            return ir.Constant(ftype, 1 if cv.value else 0);
        }
        if isinstance(cv, CtInt) and not cv.mag {
            if isinstance(ftype, ir.PointerType) {
                # `= 0` on a pointer/function-pointer field is NULL.
                if cv.small == 0 {
                    return ir.Constant(ftype, None);
                }
                return ir.Constant(ir.IntType(64), cv.small).inttoptr(ftype);
            }
            return ir.Constant(ftype, cv.small);
        }
        if isinstance(cv, CtFloat) {
            return ir.Constant(ftype, cv.value);
        }
    }
    import from jaclang.compiler.frontend.const_fold { fold_const }
    (ok, v) = fold_const(nd);
    if ok {
        if isinstance(v, bool) {
            return ir.Constant(ftype, 1 if v else 0);
        }
        if isinstance(v, int) and isinstance(ftype, ir.PointerType) {
            if v == 0 {
                return ir.Constant(ftype, None);
            }
            return ir.Constant(ir.IntType(64), v).inttoptr(ftype);
        }
        if isinstance(v, (int, float)) {
            return ir.Constant(ftype, v);
        }
    }
    if nm is not None {
        fn = self.func_symtab.get(nm);
        if fn is None {
            for _pub in (True, False) {
                _g = self.llvm_module.globals.get(self._symbol_for(nm, None, _pub));
                if isinstance(_g, ir.Function) {
                    fn = _g;
                    break;
                }
            }
        }
        if fn is not None {
            if isinstance(ftype, ir.PointerType)
                and isinstance(ftype.pointee, ir.FunctionType) {
                return fn.bitcast(ftype);
            }
            if ftype == ir.IntType(64) {
                return fn.ptrtoint(ir.IntType(64));
            }
            if ftype == ir.IntType(8).as_pointer() {
                return fn.bitcast(ftype);
            }
            return None;
        }
        gv = self.global_vars.get(nm);
        if gv is None {
            for _pub in (True, False) {
                _g = self.llvm_module.globals.get(self._symbol_for(nm, None, _pub));
                if isinstance(_g, ir.GlobalVariable) {
                    gv = _g;
                    break;
                }
            }
        }
        if gv is not None {
            if ftype == ir.IntType(64) {
                return gv.ptrtoint(ir.IntType(64));
            }
            if isinstance(ftype, ir.PointerType) {
                return gv.bitcast(ftype);
            }
            return None;
        }
        return None;
    }
    if isinstance(nd, uni.AtomTrailer) and nd.is_attr {
        a = self._get_name(nd.target);
        b = self._get_name(nd.right);
        if a is not None and b is not None {
            key = f"{a}.{b}";
            if key in self.enum_values {
                if isinstance(ftype, ir.IntType) {
                    ordinal = self.enum_member_ordinal.get(key, 0);
                    return ir.Constant(ftype, ordinal);
                }
            }
        }
    }
    return None;
}

impl NaIRGenPass._static_c_string_global(
    text: str, want: ir.Type
) -> (ir.Value | None) {
    data = (text + "\0").encode("utf8");
    key = f".cstr\x00{text}";
    g = self._interned_strs.get(key);
    if g is None {
        arr = ir.ArrayType(ir.IntType(8), len(data));
        g = ir.GlobalVariable(
            self.llvm_module, arr, name=f".cstr.{self._str_count}"
        );
        self._str_count = self._str_count + 1;
        g.linkage = "private";
        g.global_constant = True;
        g.initializer = ir.Constant(arr, bytearray(data));
        self._interned_strs[key] = g;
    }
    i8p = ir.IntType(8).as_pointer();
    if isinstance(want, ir.PointerType) {
        return g.bitcast(want);
    }
    if want == ir.IntType(64) {
        return g.bitcast(i8p).ptrtoint(ir.IntType(64));
    }
    return None;
}

impl NaIRGenPass._flush_static_struct_inits -> None {
    for (var_name, sname, call) in self.static_struct_inits {
        gv = self.global_vars.get(var_name);
        if gv is None {
            continue;
        }
        c = self._build_static_struct_const(sname, call, 0);
        if c is None {
            self.emit(
                E5092,
                kind="static struct initializer",
                name=var_name,
                help_text=(
                    f"Global '{var_name}' has C struct type '{sname}' and is "
                    "exposed to C linkers; every member must be a compile-time "
                    "constant (integer/float literal, string literal, None, "
                    "enum member, named function, or another static struct)."
                ),
            );
            continue;
        }
        gv.initializer = c;
    }
    self.static_struct_inits = [];
}
