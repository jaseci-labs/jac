impl NativeLowering._foreign_model -> dict[str, list[tuple[str, str | None]]] {
    import from jaclang.compiler.backends.native.foreign { collect_foreign_structs }
    universe = [self.module] + self._foreign_modules;
    if self._foreign_structs is None or self._foreign_model_nmods != len(universe) {
        self._foreign_structs = collect_foreign_structs(universe);
        self._foreign_model_nmods = len(universe);
    }
    return self._foreign_structs;
}

impl NativeLowering._foreign_fns -> dict[str, dict[str, any]] {
    import from jaclang.compiler.backends.native.foreign { collect_foreign_fns }
    universe = [self.module] + self._foreign_modules;
    if self._foreign_fn_decls is None or self._foreign_fns_nmods != len(universe) {
        self._foreign_fn_decls = collect_foreign_fns(universe);
        self._foreign_fns_nmods = len(universe);
    }
    return self._foreign_fn_decls;
}

impl NativeLowering._clib_struct_layout(
    name: str
) -> tuple[int, int, list[tuple[int, bool, int]]] {
    import from jaclang.compiler.backends.native.foreign { foreign_struct_layout }
    return foreign_struct_layout(self._foreign_model(), name);
}
