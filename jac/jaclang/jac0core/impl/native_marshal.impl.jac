import ctypes;

impl NativeStructView.postinit -> None {
    self._native = self.ct_cls.from_address(self.addr);

    if (self.layout and hasattr(self.layout, "structs")) {
        sl = self.layout.structs.get(self.struct_name);
        if sl {
            for f in sl.fields {
                self._field_meta[f.name] = f;
            }
        }
    }
}

impl NativeStructView.__getattr__(name: str) -> any {
    native = self._native;
    try {
        raw = getattr(native, name);
    } except AttributeError {
        bridge = self.layout?._accessor_bridge if self.layout is not None else None;
        if bridge is not None {
            (hit, val) = bridge.read_through(self, name);
            if hit {
                return val;
            }
        }

        _py_cls = _ACCESSOR_CLASSES.get(self.struct_name);
        if _py_cls is not None {
            _desc = getattr(_py_cls, name, None);
            if isinstance(_desc, property) and _desc.fget is not None {
                return _desc.fget(self);
            }
        }
        raise AttributeError(f"'{self.struct_name}' has no field '{name}'");
    }
    return self._resolve(name, raw);
}

impl NativeStructView.__setattr__(name: str, value: any) -> None {
    if name in type(self).__dataclass_fields__ {
        object.__setattr__(self, name, value);
        return;
    }
    finfo = self._field_meta.get(name);
    if finfo is not None and getattr(finfo, "foreign", False) {
        self._py_overlay[name] = value;
        return;
    }
    if finfo is None {
        bridge = self.layout?._accessor_bridge if self.layout is not None else None;
        if bridge is not None and bridge.write_through(self, name, value) {
            return;
        }
        _py_cls = _ACCESSOR_CLASSES.get(self.struct_name);
        if _py_cls is not None {
            _desc = getattr(_py_cls, name, None);
            if isinstance(_desc, property) and _desc.fset is not None {
                _desc.fset(self, value);
                return;
            }
        }
        self._py_overlay[name] = value;
        return;
    }
    lt = finfo.llvm_type;
    if (
        not finfo.is_func_ptr and lt in ("i64", "i32", "i16", "i8", "i1", "f64", "f32")
    ) {
        out_val = value;
        if (finfo.enum_type and not isinstance(value, (int, float))) {
            emap = self.enum_maps.get(finfo.enum_type) or [];
            if value in emap {
                out_val = emap.index(value);
            }
        }
        setattr(self._native, name, out_val);
        return;
    }
    raise TypeError(
        f"cannot write field '{name}' of type '{lt}' through NativeStructView"
    );
}

impl NativeStructView.__eq__(other: any) -> any {
    if isinstance(other, NativeStructView) {
        return (self.addr == other.addr and self.struct_name == other.struct_name);
    }
    return NotImplemented;
}

impl NativeStructView.__hash__ -> int {
    return hash(("s", self.addr, self.struct_name));
}

impl NativeStructView._resolve(name: str, raw: any) -> any {
    finfo = self._field_meta.get(name);
    if finfo is None {
        return raw;
    }
    if getattr(finfo, "foreign", False) {
        return self._py_overlay.get(name);
    }
    lt = finfo.llvm_type;

    if finfo.is_func_ptr {
        if (raw is None or raw == 0) {
            return None;
        }
        fn_type = _build_cfunctype(finfo);
        return fn_type(raw);
    }

    if lt.startswith("opt.") {
        if (raw is None or int(raw.tag) == 0) {
            return None;
        }

        return marshal_value(
            raw.payload,
            lt[4:],
            self.ctypes_classes,
            self.enum_maps,
            {},
            finfo,
            None,
            self.layout,
            self._view_memo
        );
    }

    if lt == "i8*" {
        if (raw is None or not raw) {
            return "";
        }
        _hs = layout_str_header_stamped(self.layout);
        _a = int(raw);
        stamped = native_stamped_str_len(_a, _hs);
        if stamped is not None {
            if stamped <= 0 {
                return "";
            }
            return ctypes.string_at(_a, stamped).decode("utf-8", errors="replace");
        }
        if _hs {
            _rt = runtime_struct_name(_a, self.layout);
            _rt_ct = self.ctypes_classes.get(_rt) if _rt is not None else None;
            if _rt_ct is not None {
                return get_struct_view(
                    _a,
                    _rt_ct,
                    _rt,
                    self.layout,
                    self.ctypes_classes,
                    self.enum_maps,
                    view_memo=self._view_memo
                );
            }
        }
        return ctypes.string_at(_a).decode("utf-8", errors="replace");
    }

    if (lt in ("i64", "i32") and finfo.enum_type) {
        val = int(raw);
        emap = self.enum_maps.get(finfo.enum_type);
        if (emap and 0 <= val < len(emap) and emap[val] is not None) {
            return emap[val];
        }
        return val;
    }

    if (lt.startswith("Dict.") and lt.endswith("*")) {
        if (raw and raw != 0) {
            return _marshal_dict(
                int(raw), lt[5:-1], elem_keys=finfo.elem_keys, layout=self.layout
            );
        }
        return {};
    }

    if (lt.startswith("Set.") and lt.endswith("*")) {
        if (raw and raw != 0) {
            return _marshal_set(
                int(raw), lt[4:-1], elem_keys=finfo.elem_keys, layout=self.layout
            );
        }
        return set();
    }

    if (lt.endswith("*") and not lt.startswith("List.") and lt != "i8*") {
        sname = lt[:-1];
        if (raw and raw != 0) {
            ct_cls = self.ctypes_classes.get(sname);
            if ct_cls {
                return get_struct_view(
                    raw,
                    ct_cls,
                    sname,
                    self.layout,
                    self.ctypes_classes,
                    self.enum_maps,
                    view_memo=self._view_memo
                );
            }
        }
        return None;
    }

    if (lt.startswith("List.") and lt.endswith("*")) {
        if (raw and raw != 0) {
            elem_key = lt[5:-1];
            (struct_hint, elem_hint) = elem_hints_for(
                elem_key, finfo.elem_keys, self.ctypes_classes
            );
            return get_list_view(
                raw,
                elem_key,
                self.ctypes_classes,
                self.enum_maps,
                self.layout,
                struct_hint=struct_hint,
                elem_hint=elem_hint,
                view_memo=self._view_memo
            );
        }
        return NativeListView.empty();
    }
    return raw;
}

impl NativeStructView.__getitem__(key: str) -> any {
    return getattr(self, key);
}

impl NativeStructView.__contains__(key: str) -> bool {
    return key in self._field_meta;
}

impl NativeStructView.__repr__ -> str {
    return f"<NativeStructView {self.struct_name}>";
}

impl NativeAccessorBridge.runtime_class(struct_name: str, addr: int) -> str {
    sl = self.layout.structs.get(struct_name);
    if (sl is None or not sl.has_vtable or not addr) {
        return struct_name;
    }
    vt = ctypes.c_void_p.from_address(addr).value;
    if not vt {
        return struct_name;
    }
    nm = self._cls_names.get(vt);
    if nm is None {
        namep = ctypes.c_void_p.from_address(vt).value;
        nm = ctypes.string_at(namep).decode("utf-8", errors="replace") if namep else "";
        self._cls_names[vt] = nm;
    }
    return nm if nm in self.layout.structs else struct_name;
}

impl NativeAccessorBridge._accessor_symbol(
    view: NativeStructView, name: str, kind: str
) -> (str | None) {
    cls = view._acc_cls;
    if cls is None {
        cls = self.runtime_class(view.struct_name, view.addr);
        view._acc_cls = cls;
    }
    candidates = [cls] if cls == view.struct_name else [cls, view.struct_name];
    for cand in candidates {
        sl = self.layout.structs.get(cand);
        amap = sl?.accessors if sl is not None else None;
        entry = amap.get(name) if amap else None;
        sym = entry.get(kind) if entry else None;
        if sym is not None {
            return sym;
        }
    }
    return None;
}

impl NativeAccessorBridge._binding(symbol: str) -> any {
    cached = self._bound.get(symbol);
    if cached is not None {
        return cached or None;
    }
    ml = self.layout.methods.get(symbol);
    addr = self.engine.get_function_address(symbol) if ml is not None else 0;
    if (not addr or any(pt.startswith("opt.") for pt in ml.param_types)) {
        self._bound[symbol] = False;
        return None;
    }
    fn_type = ctypes.CFUNCTYPE(_c_ret_type(ml.ret_type), *_c_arg_types(ml.param_types));
    bound = (fn_type(addr), ml, );
    self._bound[symbol] = bound;
    return bound;
}

impl NativeAccessorBridge._str_new_fn -> any {
    if self._str_new is None {
        self._str_new = _resolve_str_new(self.engine) or False;
    }
    return self._str_new or None;
}

impl NativeAccessorBridge.read_through(view: NativeStructView, name: str) -> tuple {
    sym = self._accessor_symbol(view, name, "__get__");
    bound = self._binding(sym) if sym is not None else None;
    if bound is None {
        return (False, None);
    }
    (fn, ml) = bound;
    raw = fn(view.addr);
    return (
        True,
        marshal_value(
            raw,
            ml.ret_type,
            view.ctypes_classes,
            view.enum_maps,
            {},
            func_layout=ml,
            layout=self.layout,
            view_memo=view._view_memo
        ),

    );
}

impl NativeAccessorBridge.write_through(
    view: NativeStructView, name: str, value: any
) -> bool {
    sym = self._accessor_symbol(view, name, "__set__");
    bound = self._binding(sym) if sym is not None else None;
    if bound is None {
        return False;
    }
    (fn, ml) = bound;
    vt = ml.param_types[1] if len(ml.param_types) > 1 else "";
    c_args: list[any] = [view.addr];
    if vt in ("jacstr3", "jacstr2") and isinstance(value, (str, bytes)) {
        sp_fn = self._str_new_fn();
        if sp_fn is None {
            raise TypeError(
                f"cannot write field '{name}' of type '{vt}' through "
                "NativeStructView: the artifact exports no jac_str_new"
            );
        }
        _b = value.encode("utf-8") if isinstance(value, str) else value;
        _sp = sp_fn(_b, len(_b));
        if vt == "jacstr3" {
            c_args.extend([_sp, _sp, len(_b)]);
        } else {
            c_args.extend([_sp, len(_b)]);
        }
    } elif isinstance(value, NativeStructView) {
        c_args.append(value.addr);
    } elif isinstance(value, NativeListView) {
        c_args.append(value.list_ptr);
    } elif isinstance(value, (bool, int, float)) {
        c_args.append(value);
    } elif (value is None and vt.endswith("*")) {
        c_args.append(None);
    } else {
        converted = False;
        if vt in ("i64", "i32", "i16", "i8") {
            for emap in view.enum_maps.values() {
                if value in emap {
                    c_args.append(emap.index(value));
                    converted = True;
                    break;
                }
            }
        }
        if not converted {
            raise TypeError(
                f"cannot write field '{name}' of type '{vt}' through "
                "NativeStructView"
            );
        }
    }
    fn(*c_args);
    return True;
}

impl NativeListView.postinit -> None {
    if (self.list_ptr == 0) {
        self._count = 0;
        self._arr = None;
        self._ct_cls = None;
        self._struct_name = None;
        return;
    }
    nl = NativeList.from_address(self.list_ptr);
    self._count = nl.len if (nl.len > 0 and nl.data) else 0;

    self._struct_name = self.struct_hint;
    if (self.elem_key == "ptr" and self._struct_name) {
        self._ct_cls = self.ctypes_classes.get(self._struct_name);
    }

    if self._count > 0 {
        if self.elem_key == "i64" {
            self._arr = (ctypes.c_int64 * self._count).from_address(nl.data);
        } elif self.elem_key == "f64" {
            self._arr = (ctypes.c_double * self._count).from_address(nl.data);
        } elif self.elem_key == "jacval" {
            self._arr = (NativeJacVal * self._count).from_address(nl.data);
        } else {
            self._arr = (ctypes.c_void_p * self._count).from_address(nl.data);
        }
    }
}

impl NativeListView.__len__ -> int {
    return self._count;
}

impl NativeListView.__getitem__(index: any) -> any {
    if isinstance(index, slice) {
        return [self[i] for i in range(*index.indices(self._count))];
    }
    if index < 0 {
        index += self._count;
    }
    if (index < 0 or index >= self._count) {
        raise IndexError(f"list index {index} out of range");
    }
    raw = self._arr[index];
    if self.elem_key == "i64" {
        return int(raw);
    }
    if self.elem_key == "f64" {
        return float(raw);
    }
    if self.elem_key == "jacval" {
        return decode_jacval(
            int(raw.tag), int(raw.payload), layout_str_header_stamped(self.layout)
        );
    }

    if (self._ct_cls and raw and raw != 0) {
        return get_struct_view(
            raw,
            self._ct_cls,
            self._struct_name,
            self.layout,
            self.ctypes_classes,
            self.enum_maps,
            view_memo=self._view_memo
        );
    }

    if (self.elem_hint == "str" and self.elem_key == "ptr") {
        return decode_native_str(raw, layout_str_header_stamped(self.layout));
    }
    return raw;
}

impl NativeListView.__iter__ -> any {
    for i in range(len(self)) {
        yield self[i];
    }
}

impl NativeListView.__eq__(other: any) -> any {
    if isinstance(other, list) {
        return (len(self) == len(other) and all(a == b for (a, b) in zip(self, other)));
    }
    return NotImplemented;
}

impl NativeListView.__repr__ -> str {
    return f"<NativeListView len={len(self)}>";
}
