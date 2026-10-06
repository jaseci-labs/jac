impl NativeLowering._glob_native_use_exists(target: uni.UniNode) -> bool {
    sym = target.sym if isinstance(target, uni.NameAtom) else None;
    if sym is None {
        return True;
    }
    for use in sym.uses {
        _m = use.find_parent_of_type(uni.Module);
        if _m is None {
            continue;
        }
        if _m is self.module or _m.decided_codespace == 'native' {
            return True;
        }
    }
    return False;
}

impl NativeLowering._register_globals_decls(module: uni.Module) -> list[uni.GlobalVars] {
    return [
        stmt
        for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE)
        if isinstance(stmt, uni.GlobalVars)
    ];
}

impl NativeLowering._register_entry_globals_code(
    module: uni.Module
) -> list[uni.ModuleCode] {
    return [
        stmt
        for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE)
        if isinstance(stmt, uni.ModuleCode)
    ];
}

impl NativeLowering._register_entry_globals_name(target: uni.UniNode) -> (str | None) {
    if (
        not isinstance(target, uni.NameAtom)
        or target.sym is None
        or target.sym.storage != uni.SymbolStorage.MODULE_GLOBAL
    ) {
        return None;
    }
    return self._get_name(target);
}

impl NativeLowering._global_vars_erased(assign: uni.Assignment) -> bool {
    return ModuleFacts.is_erased_type_decl(assign);
}

impl NativeLowering._register_enums_decls(module: uni.Module) -> list[uni.Enum] {
    return [
        stmt
        for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE)
        if isinstance(stmt, uni.Enum)
    ];
}
