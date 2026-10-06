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
