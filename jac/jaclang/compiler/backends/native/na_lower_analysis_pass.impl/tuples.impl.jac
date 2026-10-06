impl NativeLowering._tuple_slot_owns_sole_binder(nd: uni.Assignment) -> bool {
    target = nd.target[0];
    if not isinstance(target, uni.Name) or target.sym is None {
        return False;
    }
    for site in target.sym.defn {
        binder = site.parent;
        if not isinstance(binder, uni.Assignment)
            or binder.aug_op is not None
            or len(binder.target) != 1
            or binder.target[0] is not site {
            return False;
        }
    }
    return True;
}
