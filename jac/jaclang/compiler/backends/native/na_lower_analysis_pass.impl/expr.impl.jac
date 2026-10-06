impl NativeLowering._is_root_walker_operand(nd: uni.UniNode) -> bool {
    typ = nd.type if isinstance(nd, uni.Expr) else None;
    return isinstance(typ, ClassType)
        and typ.is_instance()
        and typ.shared.class_name == "Walker";
}

impl NativeLowering._is_walker_arch(name: str) -> bool {
    _model = self.module.gen.native_osp_model;
    return (_model is not None) and (_model.arch_kind.get(name) == "walker");
}

impl NativeLowering._ct_type_param_owner(nd: uni.Name) -> (str | None) {
    sym = nd.sym;
    if sym is None {
        return None;
    }
    owner = sym.decl.name_of;
    if not (isinstance(owner, uni.TypeParam) and owner.is_comptime) {
        return None;
    }
    arch = owner.find_parent_of_type(uni.Archetype);
    return self._arch_key(arch) if arch is not None else None;
}
