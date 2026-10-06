impl NativeLowering._compute_osp_model(archetypes: list[uni.Archetype]) -> None {
    for arch in archetypes {
        _n = self._arch_key(arch) if arch.name else None;
        if (_n is not None) and (arch.arch_kind is not None) {
            self.arch_ast_map[_n] = arch;
        }
    }
    import from jaclang.compiler.passes.osp_analysis { get_osp_model }
    _model = get_osp_model(
        self.module,
        archetypes=(list(archetypes) + list(self.arch_ast_map.values())),
        context=CodeContext.NATIVE,
        native_names=True
    );
    for (_name, _other) in _model.collisions {
        self.emit(
            E5092,
            node_override=self.arch_ast_map.get(_name),
            kind="archetype",
            name=f"{_name} (OSP type-tag hash collides with '{_other}')"
        );
    }
}

impl NativeLowering._osp_active -> bool {
    _model = self.module.gen.native_osp_model;
    if _model is None {
        return False;
    }
    if _model.has_event_ability() or _model.uses_construct {
        return True;
    }

    if self._osp_pins_refs() {
        for _name in _model.tags {
            _lay = self._arch_layout(_name);
            if _lay is not None and _lay.arch_type == "node" {
                return True;
            }
        }
    }
    return False;
}

impl NativeLowering._xmod_osp_help(names: list[str | None]) -> (str | None) {
    _model = self.module.gen.native_osp_model;
    _tags = _model.tags if (_model is not None) else {};
    for _n in names {
        if (
            (_n is not None) and (_n not in _tags) and (_n in self.imported_osp_archs)
        ) {
            (_kind, _mod) = self.imported_osp_archs[_n];
            return (
                f"the {_kind} archetype '{self._arch_display(
                    _n
                )}' is imported from native module "
                f"'{_mod}' but was not materialized into this native compile; "
                f"ensure '{_mod}' compiles as native source, or define the "
                f"archetype in this module."
            );
        }
    }
    return None;
}

impl NativeLowering._osp_disc_list_operand(expr: (uni.UniNode | None)) -> bool {
    if isinstance(expr, uni.EdgeRefTrailer) {
        return True;
    }
    if not isinstance(expr, uni.Expr) or expr?.type is None {
        return False;
    }
    try {
        import from jaclang.compiler.types.types { ClassType as _DiscClassType }
    } except ImportError {
        return False;
    }
    t = expr.type;
    if isinstance(t, _DiscClassType)
        and t?.shared
        and t.is_builtin()
        and t.shared.class_name in ("list", "tuple", "set", "frozenset") {
        return True;
    }
    return False;
}

impl NativeLowering._osp_pins_refs -> bool {
    return not self._nogc_headerless() and self._gc_mode() != "none";
}

impl NativeLowering._elem_arch_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr?.type is None {
        return None;
    }
    try {
        import from jaclang.compiler.types.types { ClassType as _ClassType }
    } except ImportError {
        return None;
    }
    t = expr.type;
    if not isinstance(t, _ClassType) or not t?.private {
        return None;
    }
    _args = t.private.type_args;
    if not _args {
        return None;
    }
    _elem = _args[0];
    if isinstance(_elem, _ClassType) and _elem?.shared {
        import from jaclang.compiler.passes.layout_pass { class_type_native_name }
        return class_type_native_name(_elem);
    }
    return None;
}
