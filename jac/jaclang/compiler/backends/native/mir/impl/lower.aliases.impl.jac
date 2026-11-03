impl MirLowering.getattr_member(call: uni.FuncCall) -> (tuple[uni.Module, str] | None) {
    if not isinstance(call.target, uni.Name) or call.target.value != "getattr" {
        return None;
    }
    sym = call.target.sym;
    decl_mod = sym.decl.find_parent_of_type(uni.Module)
        if sym is not None and sym.decl is not None
        else None;
    if decl_mod is not None and not decl_mod.loc.mod_path.endswith(".pyi") {
        return None;
    }
    args = list(call.params or []);
    if len(args) != 2
        or not isinstance(args[0], uni.Expr)
        or isinstance(args[0], uni.KWPair)
        or isinstance(args[1], uni.KWPair) {
        return None;
    }
    name = self.literal_text(args[1]);
    if not name or not isinstance(args[0].type, ModuleType) {
        return None;
    }
    unit = self.stdlib_module(args[0]);
    scope = args[0].type.symbol_table;
    if unit is None
        and isinstance(scope, uni.Module)
        and scope.loc.mod_path.endswith(".jac") {
        unit = scope;
    }
    if unit is None or not isinstance(self.module_member(unit, name), uni.Ability) {
        return None;
    }
    return (unit, name);
}

impl MirLowering.alias_scope(nd: uni.UniNode) -> (uni.UniNode | None) {
    current = nd.parent;
    while current is not None {
        if isinstance(
            current,
            (
                uni.IfStmt,
                uni.IfElseExpr,
                uni.WhileStmt,
                uni.ForeverStmt,
                uni.InForStmt,
                uni.IterForStmt,
                uni.MatchStmt,
                uni.SwitchStmt,
                uni.TryStmt
            )
        ) {
            return None;
        }
        if isinstance(
            current, (uni.WithStmt, uni.Ability, uni.ModuleCode, uni.Module)
        ) {
            return current;
        }
        current = current.parent;
    }
    return None;
}

impl MirLowering.getattr_alias(
    sym: (uni.Symbol | None)
) -> (tuple[uni.Module, str] | None) {
    if sym is None or len(sym.defn) != 1 or not sym.uses {
        return None;
    }
    assignment = sym.defn[0].find_parent_of_type(uni.Assignment);
    if assignment is None
        or assignment.aug_op is not None
        or len(assignment.target) != 1
        or not isinstance(assignment.target[0], uni.Name)
        or assignment.target[0].sym is not sym
        or not isinstance(assignment.value, uni.FuncCall) {
        return None;
    }
    member = self.getattr_member(assignment.value);
    owner = self.alias_scope(assignment);
    if member is None or owner is None {
        return None;
    }
    for use in sym.uses {
        call = use.find_parent_of_type(uni.FuncCall);
        if call is None
            or call.target is not use
            or self.alias_scope(call) is not owner
            or call.loc.first_line <= assignment.loc.first_line {
            return None;
        }
    }
    return member;
}

impl MirLowering.alias_call(nd: uni.FuncCall) -> (MirValue | None) {
    if not isinstance(nd.target, uni.Name) {
        return None;
    }
    found = self.getattr_alias(nd.target.sym);
    if found is None {
        return None;
    }
    (unit, name) = found;
    member = self.module_member(unit, name);
    if not isinstance(member, uni.Ability) {
        return None;
    }
    made = self.import_call(nd, member);
    if made is None {
        return None;
    }
    wanted = self.expr_type(nd);
    if made.type is wanted
        or wanted.kind == MirKind.NONE
        or made.type.kind == MirKind.NONE {
        return made;
    }
    return self.coerce(made, wanted, nd);
}
