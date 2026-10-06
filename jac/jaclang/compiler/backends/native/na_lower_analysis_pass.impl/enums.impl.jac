impl NativeLowering._enum_methods(nd: uni.Enum) -> list[uni.Ability] {
    methods: list[uni.Ability] = [];
    for stmt in ModuleFacts.unwrap_body(nd) or [] {
        if isinstance(stmt, uni.Ability) {
            methods.append(stmt);
        } elif isinstance(stmt, uni.ModuleCode) {
            for member in stmt.body {
                if isinstance(member, uni.Ability) {
                    methods.append(member);
                }
            }
        }
    }
    return methods;
}

impl NativeLowering._enum_is_string_valued(enum_name: str) -> bool {
    return enum_name in self.enum_string_values;
}

impl NativeLowering._enum_ctor_layout(enum_name: str) -> (EnumLayout | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    candidates: list[uni.Module] = [];
    _arch = self.arch_ast_map.get(enum_name);
    if _arch is not None {
        _own = _arch.find_parent_of_type(uni.Module);
        if _own is not None {
            candidates.append(_own);
        }
    }
    candidates.append(self.module);
    for _fm in (self._foreign_modules or []) {
        candidates.append(_fm);
    }
    for _cand in candidates {
        lay = get_layout_registry(_cand, self.prog).get_enum_layout(enum_name);
        if lay is not None and lay.members {
            return lay;
        }
    }
    return None;
}

impl NativeLowering._enum_ctor_target(nd: uni.FuncCall) -> (str | None) {
    _key = self._type_key_of(nd.target);
    if _key is None {
        return None;
    }
    _key = _key.replace(" ", "");
    if not _key.startswith("type[") or not _key.endswith("]") {
        return None;
    }
    _name = _key[5:-1];
    if not _name or not _name.isidentifier() {
        return None;
    }
    return _name if self._enum_ctor_layout(_name) is not None else None;
}

impl NativeLowering._emit_enum_ctor_refusal(
    nd: uni.FuncCall, enum_name: str, why: str
) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="enum constructor",
        name=enum_name,
        help_text=(
            f"Invoking '{enum_name}' as a constructor is a value-to-member "
            f"lookup: the emitter checks the value against the declared "
            f"member table and raises ValueError when it misses. {why} Read "
            f"the member off the class, or move this call to a @sv/Python "
            f"context."
        )
    );
}
