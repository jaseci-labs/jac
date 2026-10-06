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
