impl NaIRGenPass._ensure_enum_lowered(t: any) -> bool {
    import from jaclang.compiler.passes.main.layout_pass {
        is_enum_class_type,
        enum_decl_of
    }
    if not is_enum_class_type(t) {
        return False;
    }
    _decl = enum_decl_of(t);
    if _decl is not None {
        self._codegen_enum(_decl);
    } else {
        _shared = t?.shared;
        _enm = _shared.class_name if _shared is not None else None;
        if _enm is not None {
            self._codegen_enum_layout(_enm, None);
        }
    }
    return True;
}

impl NaIRGenPass._codegen_enum(nd: uni.Enum) -> None {
    enum_name = (nd).name.value if (nd).name else "unknown_enum";
    _owner_mod = nd.find_parent_of_type(uni.Module) or self.ir_in;
    self._codegen_enum_layout(enum_name, _owner_mod);
}

impl NaIRGenPass._codegen_enum_layout(
    enum_name: str, owner: (uni.Module | None)
) -> None {
    if enum_name in self.enum_types {
        return;
    }

    import from jaclang.compiler.passes.main.layout_pass { get_layout_registry }
    candidates: list = [];
    if owner is not None {
        candidates.append(owner);
    }
    candidates.append(self.ir_in);
    for _fm in (self?._foreign_modules or []) {
        candidates.append(_fm);
    }
    lay = None;
    for _cand in candidates {
        lay = get_layout_registry(_cand, self.prog).get_enum_layout(enum_name);
        if lay is not None and lay.members {
            break;
        }
    }
    if lay is None or not lay.members {
        return;
    }
    self.enum_types[enum_name] = ir.IntType(64);
    self.has_native_code = True;

    i64 = ir.IntType(64);
    if lay.is_string_enum {
        entries: list = [];
        for m in lay.members {
            full_name = f"{enum_name}.{m.name}";
            self.enum_values[full_name] = ir.Constant(i64, m.ordinal);
            self.enum_member_ordinal[full_name] = m.ordinal;
            entries.append((m.name, m.str_value or "", m.ordinal));
        }
        self.enum_string_values[enum_name] = entries;
        self._build_enum_string_table(enum_name, entries);
    } else {
        name_entries: list = [];
        for m in lay.members {
            full_name = f"{enum_name}.{m.name}";
            self.enum_values[full_name] = ir.Constant(i64, m.int_value);
            self.enum_member_ordinal[full_name] = m.ordinal;
            name_entries.append((m.name, "", m.ordinal));
        }
        self._build_enum_string_table(enum_name, name_entries, with_values=False);
    }
}

impl NaIRGenPass._build_enum_string_table(
    enum_name: str, entries: list, with_values: bool = True
) -> None {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    value_ptrs: list = [];
    name_ptrs: list = [];
    for (mname, str_val, ordinal) in entries {
        if with_values {
            (val_struct_type, val_struct) = self._static_str_struct_const(
                (str_val + "\0").encode("utf8")
            );
            val_gv = ir.GlobalVariable(
                self.llvm_module,
                val_struct_type,
                name=f"__enum.{enum_name}.v.{ordinal}"
            );
            val_gv.linkage = "private";
            val_gv.global_constant = True;
            val_gv.initializer = val_struct;

            val_ptr = val_gv.gep(
                [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
            );
            value_ptrs.append(val_ptr);
        }

        (name_struct_type, name_struct) = self._static_str_struct_const(
            (mname + "\0").encode("utf8")
        );
        name_gv = ir.GlobalVariable(
            self.llvm_module, name_struct_type, name=f"__enum.{enum_name}.n.{ordinal}"
        );
        name_gv.linkage = "private";
        name_gv.global_constant = True;
        name_gv.initializer = name_struct;
        name_ptr = name_gv.gep(
            [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]
        );
        name_ptrs.append(name_ptr);
    }
    n = len(entries);
    arr_type = ir.ArrayType(i8p, n);

    if with_values {
        val_arr_gv = ir.GlobalVariable(
            self.llvm_module, arr_type, name=f"__enum_values.{enum_name}"
        );
        val_arr_gv.linkage = "private";
        val_arr_gv.global_constant = True;
        val_arr_gv.initializer = ir.Constant(arr_type, value_ptrs);
        self.enum_value_arrays[enum_name] = val_arr_gv;
    }

    name_arr_gv = ir.GlobalVariable(
        self.llvm_module, arr_type, name=f"__enum_names.{enum_name}"
    );
    name_arr_gv.linkage = "private";
    name_arr_gv.global_constant = True;
    name_arr_gv.initializer = ir.Constant(arr_type, name_ptrs);
    self.enum_name_arrays[enum_name] = name_arr_gv;
}

impl NaIRGenPass._codegen_enum_value_lookup(
    enum_name: str, ordinal_val: ir.Value, use_name: bool = False
) -> (ir.Value | None) {
    arr_global = (self.enum_name_arrays if use_name else self.enum_value_arrays).get(
        enum_name
    );
    if arr_global is None {
        return None;
    }
    i32 = ir.IntType(32);
    i8p = ir.IntType(8).as_pointer();

    idx = self.builder.trunc(ordinal_val, i32, name="enum.idx");

    ptr_ptr = self.builder.gep(
        arr_global, [ir.Constant(i32, 0), idx], name=f"enum.{enum_name}.ptr"
    );
    return self.builder.load(ptr_ptr, name=f"enum.{enum_name}.str");
}

impl NaIRGenPass._wrap_enum_str(raw: (ir.Value | None)) -> (ir.Value | None) {
    if raw is None or self.str_wrap_raw_fn is None {
        return raw;
    }
    return self.builder.call(self.str_wrap_raw_fn, [raw], name="enum.s.desc");
}

impl NaIRGenPass._class_enum_member_str(cls_name: str, member: str) -> (str | None) {
    _cache = self?._class_enum_str_cache;
    if _cache is None {
        _cache = {};
        self._class_enum_str_cache = _cache;
    }
    _key = f"{cls_name}.{member}";
    if _key in _cache {
        return _cache[_key];
    }
    _mods: list = [self.ir_in];
    for _fm in (self?._foreign_modules or []) {
        _mods.append(_fm);
    }
    _found: (str | None) = None;
    for _m in _mods {
        for _arch in _m.get_all_sub_nodes(uni.Archetype) {
            if (_arch.name.value if _arch.name else None) != cls_name {
                continue;
            }
            for _asgn in _arch.get_all_sub_nodes(uni.Assignment) {
                _tgt0 = _asgn.target[0]
                    if _asgn.target and len(_asgn.target) > 0
                    else None;
                if isinstance(_tgt0, uni.Name)
                    and _tgt0.value == member
                    and isinstance(_asgn.value, (uni.String, uni.MultiString)) {
                    _sv = _asgn.value.lit_value;
                    if isinstance(_sv, str) {
                        _found = _sv;
                    }
                }
            }
        }
        if _found is not None {
            break;
        }
    }
    _cache[_key] = _found;
    return _found;
}

impl NaIRGenPass._class_enum_member_int(cls_name: str, member: str) -> (int | None) {
    _cache = self?._class_enum_int_cache;
    if _cache is None {
        _cache = {};
        self._class_enum_int_cache = _cache;
    }
    _key = f"{cls_name}.{member}";
    if _key in _cache {
        return _cache[_key];
    }
    _mods: list = [self.ir_in];
    for _fm in (self?._foreign_modules or []) {
        _mods.append(_fm);
    }
    _found: (int | None) = None;
    for _m in _mods {
        for _arch in _m.get_all_sub_nodes(uni.Archetype) {
            if (_arch.name.value if _arch.name else None) != cls_name {
                continue;
            }
            for _asgn in _arch.get_all_sub_nodes(uni.Assignment) {
                _tgt0 = _asgn.target[0]
                    if _asgn.target and len(_asgn.target) > 0
                    else None;
                if not (isinstance(_tgt0, uni.Name) and _tgt0.value == member) {
                    continue;
                }
                _v = _asgn.value;
                if isinstance(_v, uni.Int) {
                    _found = int(_v.lit_value);
                } elif isinstance(_v, uni.BinaryExpr)
                    and isinstance(_v.left, uni.Int)
                    and isinstance(_v.right, uni.Int)
                    and _v.op.name == "LSHIFT" {
                    _found = int(_v.left.lit_value) << int(_v.right.lit_value);
                }
            }
        }
        if _found is not None {
            break;
        }
    }
    _cache[_key] = _found;
    return _found;
}
