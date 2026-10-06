impl NativeLowering._copy_call_kind(nd: uni.FuncCall) -> (str | None) {
    if "copy" not in self._native_stdlib_modules {
        return None;
    }
    target = nd.target;
    if isinstance(target, uni.AtomTrailer) and target.is_attr {
        import from jaclang.compiler.symbol_utils { imported_module_name }
        if imported_module_name(target.target) != "copy" {
            return None;
        }
        name = self._get_name(target.right);
        return name if name in NATIVE_COPY_FUNCS else None;
    }
    if not isinstance(target, uni.Name) or target.sym is None {
        return None;
    }
    scope = target.sym.parent_tab;
    if isinstance(scope, uni.Module)
        and scope.stub_only
        and scope.name == "copy"
        and target.sym.name in NATIVE_COPY_FUNCS {
        return target.sym.name;
    }
    return None;
}

impl NativeLowering._emit_copy_refusal(nd: uni.UniNode, kind: str, why: str) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="copy call",
        name=f"copy.{kind} of {why}",
        help_text=(
            f"`copy.{kind}` lowers natively for scalars, strings, bytes, tuples, "
            "lists, dicts, sets and obj/class archetypes composed of them. Copy "
            f"the value explicitly, or call `copy.{kind}` from a @sv/Python context."
        )
    );
}

impl NativeLowering._copy_hint_name(hint: (TypeBase | None)) -> str {
    if isinstance(hint, ClassType) and hint._shared is not None {
        return hint.shared.class_name;
    }
    return "";
}

impl NativeLowering._copy_field_hints(arch: str) -> dict[str, (TypeBase | None)] {
    out: dict[str, (TypeBase | None)] = {};
    lay = self._arch_layout(arch);
    if lay is None {
        return out;
    }
    for finfo in lay.fields {
        var = finfo.decl_node;
        out[finfo.name] = var.type if isinstance(var, uni.HasVar) else None;
    }
    return out;
}

impl NativeLowering._copy_call_arg(
    kind: str, nd: uni.FuncCall
) -> (uni.Expr | uni.KWPair | None) {
    params: list[uni.Expr | uni.KWPair] = list(nd.params or []);
    if len(params) != 1 or isinstance(params[0], uni.KWPair) {
        self._emit_copy_refusal(
            nd, kind, "a call with other than one positional argument (a `memo` dict)"
        );
        return None;
    }
    if self._nogc_headerless() {
        self._emit_copy_refusal(
            nd,
            kind,
            "a module under the nogc memory profile, whose headerless objects carry no runtime class"
        );
        return None;
    }
    return params[0];
}
