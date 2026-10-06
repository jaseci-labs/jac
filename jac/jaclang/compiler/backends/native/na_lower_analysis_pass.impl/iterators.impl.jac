impl NativeLowering._resolve_method_owner(
    arch_name: str, method_name: str
) -> (str | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    owner = get_layout_registry(self.module, self.prog).resolve_method_owner(
        arch_name, method_name
    );
    if owner is not None {
        return owner;
    }
    _arch = self.arch_ast_map.get(arch_name);
    if isinstance(_arch, uni.Archetype) {
        _mod = _arch.find_parent_of_type(uni.Module);
        if _mod is not None and _mod is not self.module {
            return get_layout_registry(_mod, self.prog).resolve_method_owner(
                arch_name, method_name
            );
        }
    }
    return None;
}
