impl NaIRGenPass._codegen_enum(nd: uni.Enum) -> None {
    enum_name = (nd).name.value if (nd).name else "unknown_enum";

    if enum_name in self.enum_types {
        return;
    }
    self.enum_types[enum_name] = ir.IntType(64);
    self.type_map[enum_name] = ir.IntType(64);
    self.has_native_code = True;
    if (nd).body is None {
        return;
    }

    members: list = [];
    for stmt in (nd).body {
        if isinstance(stmt, uni.Assignment) {
            targets = stmt.target
                if isinstance(stmt.target, (list, tuple))
                else [stmt.target];
            for target_expr in targets {
                member_name = self._get_name(target_expr);
                if member_name is not None {
                    members.append((member_name, stmt.value));
                }
            }
        }
    }

    is_string_enum = False;
    for (mname, vnode) in members {
        if vnode is not None
        and (isinstance(vnode, uni.String) or isinstance(vnode, uni.MultiString)) {
            is_string_enum = True;
            break;
        }
    }
    if is_string_enum {
        entries: list = [];
        i64 = ir.IntType(64);
        for (ordinal, (mname, vnode)) in enumerate(members) {
            str_val = "";
            if vnode is not None and isinstance(vnode, (uni.String, uni.MultiString)) {
                str_val = vnode.lit_value;
            }
            full_name = f"{enum_name}.{mname}";
            self.enum_values[full_name] = ir.Constant(i64, ordinal);
            self.enum_member_ordinal[full_name] = ordinal;
            entries.append((mname, str_val, ordinal));
        }
        self.enum_string_values[enum_name] = entries;
        self._build_enum_string_table(enum_name, entries);
    } else {
        i64 = ir.IntType(64);
        name_entries: list = [];
        for (ordinal, (mname, vnode)) in enumerate(members) {
            val = vnode.lit_value
                if (vnode is not None and isinstance(vnode, uni.Int))
                else 0;
            full_name = f"{enum_name}.{mname}";
            self.enum_values[full_name] = ir.Constant(i64, val);
            self.enum_member_ordinal[full_name] = ordinal;
            name_entries.append((mname, "", ordinal));
        }
        self._build_enum_string_table(enum_name, name_entries, with_values=False);
    }
}

impl NaIRGenPass._build_enum_string_table(
    enum_name: str, entries: list, with_values: bool = True
) -> None {
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    sentinel_val = ir.Constant(i64, 0x7FFFFFFFFFFFFFFF);
    zero_i64 = ir.Constant(i64, 0);
    value_ptrs: list = [];
    name_ptrs: list = [];
    for (mname, str_val, ordinal) in entries {
        if with_values {
            val_bytes = bytearray((str_val + "\0").encode("utf8"));
            val_arr_type = ir.ArrayType(i8, len(val_bytes));
            val_struct_type = ir.LiteralStructType([i64, i64, val_arr_type]);
            val_c_str = ir.Constant(val_arr_type, val_bytes);
            val_struct = ir.Constant(
                val_struct_type, [sentinel_val, zero_i64, val_c_str]
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

        name_bytes = bytearray((mname + "\0").encode("utf8"));
        name_arr_type = ir.ArrayType(i8, len(name_bytes));
        name_struct_type = ir.LiteralStructType([i64, i64, name_arr_type]);
        name_c_str = ir.Constant(name_arr_type, name_bytes);
        name_struct = ir.Constant(
            name_struct_type, [sentinel_val, zero_i64, name_c_str]
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
