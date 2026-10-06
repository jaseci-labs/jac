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

impl NativeLowering._disconnect_operand_shape(
    nd: uni.BinaryExpr, fcond: (uni.FilterCompr | None), etname: (str | None)
) -> tuple[bool, bool, list[uni.CompareExpr], (str | None)] {
    _left_is_list = self._osp_disc_list_operand(nd.left);
    _right_is_list = self._osp_disc_list_operand(nd.right);
    _disc_compares: list[uni.CompareExpr] = [];
    if (fcond is not None) and fcond.compares {
        _disc_compares = [
            _c
            for _c in fcond.compares
            if isinstance(_c, uni.CompareExpr)
        ];
    }
    if _disc_compares and (_left_is_list or _right_is_list) {
        return (
            _left_is_list,
            _right_is_list,
            _disc_compares,
            "a disconnect with both list operands and attribute "
            "predicates is not lowered natively; loop over the nodes and "
            "disconnect each pair."
        );
    }
    if _disc_compares and (etname is None) {
        return (
            _left_is_list,
            _right_is_list,
            _disc_compares,
            "edge attribute predicates need a named edge type "
            "(`del ->:E:field == value:->`) so the edge layout is known"
        );
    }
    return (_left_is_list, _right_is_list, _disc_compares, None);
}

impl NativeLowering._edge_ref_trailer_hop(
    chain: list[uni.Expr | uni.FilterCompr], idx: int
) -> tuple[(uni.Expr | uni.FilterCompr), (uni.FilterCompr | None), int, bool] {
    step = chain[idx];
    idx += 1;

    _step_filter: (uni.FilterCompr | None) = None;
    if idx < len(chain) {
        _f = chain[idx];
        if isinstance(_f, uni.FilterCompr) and (_f.f_type is not None) {
            _step_filter = _f;
            idx += 1;
        }
    }
    _is_last_hop = (idx >= len(chain)) or (not isinstance(chain[idx], uni.EdgeOpRef));
    return (step, _step_filter, idx, _is_last_hop);
}

impl NativeLowering._edge_ref_trailer_filter_tag(
    step_filter: uni.FilterCompr, tags: dict[str, int]
) -> tuple[(str | None), int] {
    _node_filter = self._arch_ref_key(step_filter.f_type)
        or self._get_name(step_filter.f_type);
    _ntag = tags.get(_node_filter, -1) if _node_filter is not None else -1;
    return (_node_filter, _ntag);
}

impl NativeLowering._chained_filter_arch(
    nd: uni.AtomTrailer, f: uni.FilterCompr
) -> (str | None) {
    _fname = (self._arch_ref_key(f.f_type) or self._get_name(f.f_type))
        if f.f_type is not None
        else None;
    if _fname is None and f.compares {
        _fname = self._elem_arch_name_of(nd.target);
    }
    if _fname is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="FilterCompr",
            help_text="This filter's element archetype is not statically known; put a type filter first (`[?:NodeType]`) so field predicates can resolve a layout, or filter with an explicit loop."
        );
        return None;
    }
    return _fname;
}

impl NativeLowering._chained_filter_type_tag(fname: str) -> int {
    _model = self.module.gen.native_osp_model;
    _tags = _model.tags if _model is not None else {};
    _ntag = _tags.get(fname, -1);
    return _ntag;
}

impl NativeLowering._osp_pred_pair_compares_ok(
    arch_name: str, compares: list[uni.CompareExpr], nd: uni.UniNode
) -> bool {
    _fields = self.struct_field_indices.get(arch_name);
    if _fields is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="FilterCompr",
            help_text=self._xmod_osp_help([arch_name])
        );
        return False;
    }
    for cmp in compares {
        _bad = (
            not isinstance(cmp.left, uni.Name)
            or (not cmp.rights)
            or (not cmp.ops)
            or len(cmp.ops) > 1
        );
        _lhs_name = cmp.left.value if isinstance(cmp.left, uni.Name) else None;
        if _bad or _lhs_name is None or _lhs_name not in _fields {
            _fld = _lhs_name or "<expr>";
            self.emit(
                E5092,
                node_override=cmp,
                kind="expression",
                name="FilterCompr",
                help_text=(
                    f"filter predicate on '{_fld}' does not resolve to a "
                    f"simple `field <op> value` compare over archetype "
                    f"'{arch_name}'"
                )
            );
            return False;
        }
    }
    return True;
}

impl NativeLowering._edge_ref_trailer_edge_compares(
    fcond: (uni.FilterCompr | None), etname: (str | None)
) -> tuple[list[any], (str | None)] {
    _ec_compares: list[any] = [];
    if (fcond is not None) and fcond.compares {
        _ec_compares = list(fcond.compares);
    }
    if _ec_compares and (etname is None) {
        return (
            _ec_compares,
            "edge attribute predicates need a named edge type "
            "(`->:E:field == value:->`) so the edge layout is known"
        );
    }
    return (_ec_compares, None);
}
