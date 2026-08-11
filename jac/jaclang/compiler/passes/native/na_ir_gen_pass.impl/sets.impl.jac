impl NaIRGenPass._emit_set_helpers(
    elem_type_name: str, elem_type: ir.Type, elem_size: int = 0
) -> None {
    if elem_type_name in self.set_helpers {
        return;
    }

    _struct_name = f"Set.{elem_type_name}";
    layout = self._container_layout_hash(elem_type, None);
    set_struct = self.llvm_module.context.get_identified_type(_struct_name);
    if not set_struct.elements {
        set_struct.set_body(*self._container_struct_fields(layout));
    }
    self.set_types[elem_type_name] = set_struct;
    self.container_layouts[_struct_name] = layout;
    set_ptr_type = set_struct.as_pointer();

    _rel_fn_decl_s = None;
    _rel_fn_name_s = f"__rc_release_set_{elem_type_name}";
    if not self._nogc_headerless() {
        _rel_fnty_s = ir.FunctionType(ir.VoidType(), [set_ptr_type]);
        try {
            _rel_fn_decl_s = self.llvm_module.get_global(_rel_fn_name_s);
        } except KeyError {
            _rel_fn_decl_s = ir.Function(
                self.llvm_module, _rel_fnty_s, name=_rel_fn_name_s
            );
            _rel_fn_decl_s.linkage = "private";
        }
    }

    new_fn = self._emit_container_new_fn(
        f"__set_new_{elem_type_name}", set_ptr_type, layout, dtor_fn=_rel_fn_decl_s
    );

    core = self._emit_hash_core_helpers(
        "set",
        elem_type_name,
        set_ptr_type,
        elem_type,
        None,
        elem_type_name,
        elem_size,
        layout
    );

    len_fn = self._emit_container_len_fn(f"__set_len_{elem_type_name}", set_ptr_type);

    if self._nogc_headerless() {
        self._emit_container_drop_fn(_struct_name);
    } else {
        release_fn = self._emit_container_release_fn(
            _rel_fn_name_s, set_ptr_type, layout
        );
        self.set_release_fns[elem_type_name] = release_fn;
    }

    self.set_helpers[elem_type_name] = {
        "new": new_fn,
        "add": core["insert"],
        "contains": core["contains"],
        "remove": core["remove"],
        "clear": core["clear"],
        "get": core["get_key"],
        "find": core["find"],
        "len": len_fn,
        "elem_type": elem_type,
        "elem_size": elem_size
    };
}

impl NaIRGenPass._codegen_set_val(nd: uni.SetVal) -> (ir.Value | None) {
    if not nd.values {
        _sk = self._set_spec_of(nd);
        _helpers = self.set_helpers.get(_sk) if _sk is not None else None;
        if _helpers is not None {
            return self.builder.call(_helpers["new"], [], name="set.empty");
        }
        return None;
    }

    _decl_args = nd.type.private.type_args
        if (isinstance(nd, uni.Expr) and nd.type is not None)
        else [];
    _decl_elem = self._elem_storage_llvm(_decl_args[0]) if _decl_args else None;
    if _decl_elem is not None
        and self?.jacval_type
        and _decl_elem == self.jacval_type {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="set of mixed element types",
            help_text="Native sets hash a single concrete element type; a set whose elements mix representations has no native storage. Use a homogeneous element type, or a list for mixed values."
        );
        return None;
    }

    first_val = self._str_norm(self._codegen_expr(nd.values[0]));
    if first_val is None {
        return None;
    }

    elem_type = first_val.type;
    elem_type_name = "i64";
    elem_size = 0;
    if isinstance(elem_type, ir.DoubleType) {
        elem_type_name = "f64";
    } elif isinstance(elem_type, ir.PointerType) {
        elem_type_name = "ptr";
        if isinstance(elem_type.pointee, ir.LiteralStructType) {
            elem_size = self._get_struct_size(elem_type.pointee);
            elem_type_name = f"tuple{elem_size}";
        }
    }

    self._emit_set_helpers(elem_type_name, elem_type, elem_size);
    helpers = self.set_helpers[elem_type_name];

    _set_new_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    set_val = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_set_new_loc, name="set.new"
    );
    self._nogc_stamp_elem_drops(set_val, self._nogc_type_arg_mangles(nd));
    _sinit_loc = f"{os.path.basename(self.ir_in.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";

    first_val = self._nogc_elem_prep(nd.values[0], first_val);
    self._rc_call_with_ctx(
        helpers["add"], [set_val, first_val], op="set_init", loc=_sinit_loc
    );

    for i in range(1, len(nd.values)) {
        val = self._str_norm(self._codegen_expr(nd.values[i]));
        if val is not None {
            val = self._nogc_elem_prep(nd.values[i], val);
            if self._reject_ptr_into_raw_slot(nd, val, elem_type, "set element") {
                return set_val;
            }
            _orig_sv = val;
            val = self._coerce_type(val, elem_type);
            self._rc_call_with_ctx(
                helpers["add"], [set_val, val], op="set_init", loc=_sinit_loc
            );

            if isinstance(_orig_sv.type, ir.PointerType) and self._is_owned(_orig_sv) {
                self._emit_rc_release_simple(_orig_sv, op="set_init", loc=_sinit_loc);
            }
        }
    }

    return set_val;
}
