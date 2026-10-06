impl NativeLowering._ctxmgr_callee(expr: (uni.UniNode | None)) -> (uni.Ability | None) {
    """The `@contextmanager` ability a `with` item calls, if it calls one.""";
    if not isinstance(expr, uni.FuncCall) {
        return None;
    }
    import from jaclang.compiler.erased_imports { contextmanager_ability }
    _callee = self._callee_ability_of(expr);
    return _callee if contextmanager_ability(_callee) else None;
}
