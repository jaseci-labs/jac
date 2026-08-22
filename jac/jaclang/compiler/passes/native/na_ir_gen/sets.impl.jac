impl NaIRGenSets._emit_set_helpers(
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
        "add_ph": core["insert_ph"],
        "contains": core["contains"],
        "contains_ph": core["contains_ph"],
        "remove": core["remove"],
        "remove_ph": core["remove_ph"],
        "clear": core["clear"],
        "get": core["get_key"],
        "find": core["find"],
        "len": len_fn,
        "elem_type": elem_type,
        "elem_size": elem_size
    };
}

impl NaIRGenSets._codegen_set_val(nd: uni.SetVal) -> (ir.Value | None) {
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

    _first_spread = self._spread_operand(nd.values[0]);
    first_val: (ir.Value | None) = None;
    _first_src_info: (dict | None) = None;
    if _first_spread is not None {
        _first_src_info = self._container_src_info(
            self._str_norm(self._codegen_expr(_first_spread))
        );
        if _first_src_info is None {
            self.emit(
                E5092,
                node_override=nd.values[0],
                kind="expression",
                name="spread in a set display",
                help_text="A `*` spread is copied element by element out of a native list or set; this operand lowered to neither. Give it a lowerable list or set type, or write the elements out."
            );
            return None;
        }
    } else {
        first_val = self._str_norm(self._codegen_expr(nd.values[0]));
        if first_val is None {
            return None;
        }
    }

    elem_size = 0;
    if first_val is not None {
        elem_type = first_val.type;
    } elif _first_src_info["kind"] == "set" {
        elem_type = _first_src_info["helpers"]["elem_type"];
        elem_size = _first_src_info["helpers"]["elem_size"];
    } else {
        _spread_elem = self._spread_elem_storage(_first_src_info, _first_spread);
        if _spread_elem is None {
            self.emit(
                E5092,
                node_override=nd.values[0],
                kind="expression",
                name="leading spread into a set",
                help_text="A native list erases every pointer element into one byte-pointer slot, so the layout a set has to hash and compare by can only come from the spread operand's static type -- and this one has none. Annotate the source's element type, or seed the display with an element written out before the spread."
            );
            return None;
        }
        elem_type = _spread_elem;
    }
    elem_type_name = "i64";
    if isinstance(elem_type, ir.DoubleType) {
        elem_type_name = "f64";
    } elif isinstance(elem_type, ir.PointerType) {
        elem_type_name = "ptr";
        if isinstance(elem_type.pointee, ir.LiteralStructType) {
            elem_size = self._get_struct_size(elem_type.pointee);
            elem_type_name = self._tuple_spec_name(elem_type.pointee);
        } elif elem_size {
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

    if first_val is None {
        if self._reject_spread_slot_mismatch(
            nd.values[0],
            _first_src_info["helpers"]["elem_type"],
            helpers["elem_type"],
            "set element"
        ) {
            return None;
        }
        self._emit_spread_copy(
            _first_src_info["value"],
            _first_src_info["helpers"],
            set_val,
            helpers,
            "set",
            _sinit_loc
        );
    } else {
        first_val = self._nogc_elem_prep(nd.values[0], first_val);
        (_add_fn, _kh) = self._static_key_op(helpers, "add", nd.values[0]);
        _add_args = [set_val, first_val];
        if _kh is not None {
            _add_args.append(_kh);
        }
        self._rc_call_with_ctx(_add_fn, _add_args, op="set_init", loc=_sinit_loc);
    }

    for i in range(1, len(nd.values)) {
        _spread_op = self._spread_operand(nd.values[i]);
        if _spread_op is not None {
            _src_info = self._container_src_info(
                self._str_norm(self._codegen_expr(_spread_op))
            );
            if _src_info is None {
                self.emit(
                    E5092,
                    node_override=nd.values[i],
                    kind="expression",
                    name="spread in a set display",
                    help_text="A `*` spread is copied element by element out of a native list or set; this operand lowered to neither. Give it a lowerable list or set type, or write the elements out."
                );
                return None;
            }
            if self._reject_spread_slot_mismatch(
                nd.values[i],
                _src_info["helpers"]["elem_type"],
                helpers["elem_type"],
                "set element"
            ) {
                return None;
            }
            self._emit_spread_copy(
                _src_info["value"],
                _src_info["helpers"],
                set_val,
                helpers,
                "set",
                _sinit_loc
            );
            continue;
        }
        val = self._str_norm(self._codegen_expr(nd.values[i]));
        if val is None {
            self.emit(
                E5092,
                node_override=nd.values[i],
                kind="expression",
                name="set element",
                help_text="This element of the set display did not lower, so the set would have been built without it. Move the expression out of the display, or move the enclosing code to a @sv/Python context."
            );
            return None;
        }
        val = self._nogc_elem_prep(nd.values[i], val);
        if self._reject_ptr_into_raw_slot(nd, val, elem_type, "set element") {
            return set_val;
        }
        _orig_sv = val;
        val = self._coerce_type(val, elem_type);
        (_add_fn, _kh) = self._static_key_op(helpers, "add", nd.values[i]);
        _add_args = [set_val, val];
        if _kh is not None {
            _add_args.append(_kh);
        }
        self._rc_call_with_ctx(_add_fn, _add_args, op="set_init", loc=_sinit_loc);

        if isinstance(_orig_sv.type, ir.PointerType) and self._is_owned(_orig_sv) {
            self._emit_rc_release_simple(_orig_sv, op="set_init", loc=_sinit_loc);
        }
    }

    return set_val;
}
