import from jaclang.compiler.c_interop {
    c_builtin_kind,
    c_type_arg,
    foreign_read_copies,
    foreign_struct_of_type,
    is_builtin_pin_call,
    is_pinned_type,
    is_ptr_type,
    is_ptr_view_type
}

impl NativeLowering._foreign_struct_name_of_type(t: any) -> (str | None) {
    arch = foreign_struct_of_type(t);
    if arch is None or arch.name is None {
        return None;
    }
    name = arch.name.value;
    return name if name in self.clib_struct_names else None;
}

impl NativeLowering._clib_ret_is_cptr(sig: uni.FuncSignature) -> bool {
    ret = sig.return_type;
    return ret is not None and is_ptr_type(self._c_decl_type_of(ret));
}

impl NativeLowering._c_decl_type_of(type_expr: uni.UniNode) -> any {
    t = type_expr?.type;
    if isinstance(t, ClassType) and not t.is_instance() {
        return t.clone_as_instance();
    }
    return t;
}

impl NativeLowering._c_scalar_llvm_shape(t: any) -> (tuple[bool, int] | None) {
    import from jaclang.compiler.types.types { ClassType as _CClassType }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if is_ptr_type(t) {
        return (False, 64);
    }
    if not isinstance(t, _CClassType) or t._shared is None or not t.is_builtin() {
        return None;
    }
    shape_entry = JAC_TYPE_REGISTRY.get(t.shared.class_name);
    if shape_entry is None
        or not shape_entry.is_int_kind()
        and not shape_entry.is_float_kind() {
        return None;
    }
    if t.shared.class_name == "bool" {
        return (False, 8);
    }
    if shape_entry.is_float_kind() {
        return (True, shape_entry.width);
    }
    return (False, shape_entry.width);
}

impl NativeLowering._c_scalar_is_bool(t: any) -> bool {
    return isinstance(t, ClassType) and t.shared.class_name == "bool";
}

impl NativeLowering._c_view_elem_of_index(
    nd: uni.AtomTrailer
) -> (tuple[uni.IndexSlice, any] | None) {
    if nd.is_attr
        or not isinstance(nd.right, uni.IndexSlice)
        or not is_ptr_view_type(nd.target?.type) {
        return None;
    }
    right = nd.right;
    if right.is_range or len(right.slices) != 1 or right.slices[0].start is None {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="PtrView access",
            name="slice",
            help_text="A PtrView is indexed one element at a time: `v[i]`."
        );
        return None;
    }
    elem = c_type_arg(nd.target.type);
    return (right, elem);
}

impl NativeLowering._c_interop_store_kind(target: uni.AtomTrailer) -> (str | None) {
    target_type = target.target?.type;
    if not target.is_attr and is_ptr_view_type(target_type) {
        return "view";
    } elif target.is_attr
        and is_pinned_type(target_type)
        and self._get_name(target.right) == "value" {
        return "pinned";
    }
    return None;
}

impl NativeLowering._c_interop_call_kind(
    nd: uni.FuncCall
) -> tuple[str, (uni.Expr | uni.KWPair | None), (uni.Expr | uni.KWPair | None)] {
    params: list[uni.Expr | uni.KWPair] = list(nd.params or []);
    callee_type = nd.target?.type;
    if is_builtin_pin_call(nd) {
        if len(params) != 1 or isinstance(params[0], uni.KWPair) {
            self.ctx.emit(E5092, node_override=nd, kind="call", name="pin(value)");
            return ("refused", None, None);
        }
        return ("pin", params[0], None);
    }
    if is_ptr_type(callee_type)
        and callee_type is not None
        and not callee_type.is_instance() {
        if not params {
            return ("ptr_zero", None, None);
        }
        if len(params) != 1 or isinstance(params[0], uni.KWPair) {
            self.ctx.emit(
                E5092, node_override=nd, kind="pointer cast", name="ptr(...)"
            );
            return ("refused", None, None);
        }
        return ("ptr_cast", params[0], None);
    }
    if isinstance(nd.target, uni.Name)
        and nd.target.value == "bool"
        and len(params) == 1
        and not isinstance(params[0], uni.KWPair)
        and is_ptr_type(params[0]?.type) {
        return ("ptr_bool", params[0], None);
    }
    if isinstance(nd.target, uni.Name)
        and nd.target.value == "len"
        and len(params) == 1
        and not isinstance(params[0], uni.KWPair)
        and is_ptr_view_type(params[0]?.type) {
        return ("view_len", params[0], None);
    }
    if not (isinstance(nd.target, uni.AtomTrailer) and nd.target.is_attr) {
        return ("none", None, None);
    }
    recv = nd.target.target;
    method = self._get_name(nd.target.right);
    if not is_ptr_type(recv?.type) {
        return ("none", None, None);
    }
    if method == "is_null" {
        return ("is_null", recv, None);
    }
    if method == "view" {
        if len(params) != 1 or isinstance(params[0], uni.KWPair) {
            self.ctx.emit(E5092, node_override=nd, kind="call", name="ptr.view(n)");
            return ("refused", None, None);
        }
        return ("view", recv, params[0]);
    }
    return ("none", None, None);
}

impl NativeLowering._clib_param_info_type(p: uni.ParamVar) -> tuple[any, bool, bool] {
    import from jaclang.compiler.frontend.constant { is_borrow_kind }
    ptype = p.type;
    optional = False;
    if isinstance(ptype, UnionType) {
        members = [
            m
            for m in (ptype.types or [])
            if not (
                isinstance(m, ClassType) and m.shared.class_name in ("NoneType", "None")
            )
        ];
        if len(members) == 1 and len(members) < len(ptype.types or []) {
            ptype = members[0];
            optional = True;
        }
    }
    borrowed = p.type_tag is not None and is_borrow_kind(p.type_tag.ownership);
    return (ptype, optional, borrowed);
}
