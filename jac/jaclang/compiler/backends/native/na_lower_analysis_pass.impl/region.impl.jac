impl NativeLowering._register_region_handle_var(
    nd: uni.Assignment, var_name: str
) -> None {
    _tgt = nd.target[0]
        if (len(nd.target) == 1 and isinstance(nd.target[0], uni.Name))
        else None;
    if _tgt is None or _tgt.sym is None or not _tgt.sym.na_region_handle {
        return;
    }
    self.region_handle_vars.add(var_name);
    if isinstance(nd.value, uni.Name)
        and nd.value.sym is not None
        and nd.value.sym.na_region_handle
        and nd.value.sym_name != var_name {
        self.region_handle_vars.discard(nd.value.sym_name);
    }
}
