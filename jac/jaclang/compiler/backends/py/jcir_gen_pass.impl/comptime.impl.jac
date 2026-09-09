impl JcirGenPass._ct_kind(v: any) -> str {
    if v is None or isinstance(v, (bool, int, float, str, bytes)) {
        return "scalar";
    }
    kind = type(v).__name__;
    if kind in ("CtEnumMember", "CtType", "CtFunc", "CtRecord") {
        return kind;
    }
    if isinstance(v, (list, tuple, set, frozenset, dict)) {
        return "container";
    }
    if isinstance(v, type) and v.__module__ == "builtins" {
        return "pytype";
    }
    return "";
}

impl JcirGenPass._ct_materializable(v: any) -> bool {
    kind = self._ct_kind(v);
    if not kind {
        return False;
    }
    if kind == "container" {
        items = v.values() if isinstance(v, dict) else v;
        for item in items {
            if not self._ct_materializable(item) {
                return False;
            }
        }
        if isinstance(v, dict) {
            for k in v.keys() {
                if not self._ct_materializable(k) {
                    return False;
                }
            }
        }
        return True;
    }
    if kind == "CtRecord" {
        for item in v.fields.values() {
            if not self._ct_materializable(item) {
                return False;
            }
        }
    }
    return True;
}

impl JcirGenPass._ct_concrete(nd: Expr) -> bool {
    cv = nd.ct_value;
    return cv is not None and not cv.is_deferred and self._ct_materializable(cv.v);
}

impl JcirGenPass._comptime_only_names -> set[str] {
    cached = self._ct_only_names;
    if cached is not None {
        return cached;
    }
    names: set[str] = set();
    for imp in self.ir_in.get_all_sub_nodes(Import) {
        if not imp.is_comptime {
            continue;
        }
        for item in imp.items {
            bound: (Name | None) = item.alias;
            if bound is None
                and isinstance(item, ModuleItem)
                and isinstance(item.name, Name) {
                bound = item.name;
            }
            if bound is None and isinstance(item, ModulePath) and item.path {
                last = item.path[-1];
                bound = last if isinstance(last, Name) else None;
            }
            if bound is not None {
                names.add(bound.sym_name);
            }
        }
    }
    for ab in self.ir_in.get_all_sub_nodes(Ability) {
        if ab.is_comptime and ab.name_ref is not None {
            names.add(ab.name_ref.sym_name);
        }
    }
    self._ct_only_names = names;
    return names;
}

impl JcirGenPass._is_comptime_only_name(nd: Name) -> bool {
    if nd.sym_name in self._comptime_only_names() {
        return True;
    }
    for sym in (nd.sym, ) {
        if sym is None {
            continue;
        }
        decl = sym.decl;
        imp = decl.find_parent_of_type(Import) if isinstance(decl, Name) else None;
        if imp is not None and imp.is_comptime {
            return True;
        }
        owner = decl.name_of;
        if isinstance(owner, Ability) and owner.is_comptime {
            return True;
        }
        par = decl.parent if isinstance(decl, Name) else None;
        if isinstance(par, Assignment) and isinstance(par.parent, GlobalVars) {
            home = par.find_parent_of_type(Module);
            if home is not None and home is not self.ir_in {
                hp = (home.loc.mod_path if home.loc else "").replace("\\", "/");
                if hp.endswith("jaclang/comptime.jac") {
                    return True;
                }
            }
        }
    }
    return False;
}

impl JcirGenPass._import_ref(module: str, name: str, jac_node: UniNode) -> CgNode {
    imported = self.call_node(
        self.name_load('__import__', jac_node),
        [self.const_of(module, jac_node)],
        [
            self.nod(
                'keyword',
                ['arg', 'value'],
                [
                    'fromlist',
                    self.nod(
                        'List',
                        ['elts', 'ctx'],
                        [[self.const_of(name, jac_node)], self.nod('Load', [], [])]
                    )
                ]
            )
        ],
        jac_node=jac_node
    );
    return self.nod(
        'Attribute',
        ['value', 'attr', 'ctx'],
        [imported, name, self.nod('Load', [], [])],
        jac_node=jac_node
    );
}

impl JcirGenPass._class_ref(module: str, name: str, jac_node: UniNode) -> CgNode {
    import from jaclang.compiler.frontend.codeinfo { module_dotted_name }
    if module == "builtins" or not module {
        return self.name_load(name, jac_node);
    }
    if module
        == module_dotted_name(
            self.ir_in.loc.mod_path if self.ir_in.loc else "", self.ir_in.name
        ) {
        return self.name_load(name, jac_node);
    }
    local_sym = self.ir_in.sym_tab.lookup(name, deep=False);
    if local_sym is not None {
        return self.name_load(name, jac_node);
    }
    return self._import_ref(module, name, jac_node);
}

impl JcirGenPass._ct_order_key(v: any) -> str {
    if v is None {
        return "0";
    }
    if isinstance(v, bool) {
        return "1" + ("1" if v else "0");
    }
    if isinstance(v, (int, float)) {
        return "2" + repr(v);
    }
    if isinstance(v, str) {
        return "3" + v;
    }
    if isinstance(v, bytes) {
        return "4" + v.hex();
    }
    if isinstance(v, frozenset) {
        return "5" + "\x00".join(sorted([self._ct_order_key(x) for x in v]));
    }
    if isinstance(v, tuple) {
        return "6" + "\x00".join([self._ct_order_key(x) for x in v]);
    }
    return "7"
        + self._ct_kind(v)
        + ":"
        + str(getattr(v, "enum_name", ""))
        + ":"
        + str(getattr(v, "member", ""))
        + ":"
        + str(
            getattr(v, "qualname", "")
                or getattr(v, "name", "")
                or getattr(v, "__name__", "")
        );
}

impl JcirGenPass._materialize(v: any, jac_node: UniNode) -> (CgNode | None) {
    import from jaclang.compiler.frontend.codeinfo { module_dotted_name }
    load = self.nod('Load', [], []);
    kind = self._ct_kind(v);
    if kind == "scalar" {
        return self.const_of(v, jac_node);
    }
    if kind == "pytype" {
        return self.name_load(v.__name__, jac_node);
    }
    if isinstance(v, (list, tuple)) {
        elts: list = [];
        for item in v {
            m = self._materialize(item, jac_node);
            if m is None {
                return None;
            }
            elts.append(m);
        }
        return self.nod(
            'List' if isinstance(v, list) else 'Tuple', ['elts', 'ctx'], [elts, load]
        );
    }
    if isinstance(v, (set, frozenset)) {
        elts2: list = [];
        for item in sorted(v, key=self._ct_order_key) {
            m = self._materialize(item, jac_node);
            if m is None {
                return None;
            }
            elts2.append(m);
        }
        ctor = 'frozenset' if isinstance(v, frozenset) else 'set';
        return self.call_node(
            self.name_load(ctor, jac_node),
            [self.nod('List', ['elts', 'ctx'], [elts2, load])],
            []
        );
    }
    if isinstance(v, dict) {
        keys: list = [];
        vals: list = [];
        for (k, item) in v.items() {
            mk = self._materialize(k, jac_node);
            mv = self._materialize(item, jac_node);
            if mk is None or mv is None {
                return None;
            }
            keys.append(mk);
            vals.append(mv);
        }
        return self.nod('Dict', ['keys', 'values'], [keys, vals]);
    }
    if kind == "CtEnumMember" {
        return self.nod(
            'Attribute',
            ['value', 'attr', 'ctx'],
            [self._class_ref(v.module, v.enum_name, jac_node), v.member, load],
            jac_node=jac_node
        );
    }
    if kind == "CtType" {
        cls_ref = self._class_ref(v.module, v.name, jac_node);
        ct_args = v?.ct_args or {};
        if not ct_args {
            return cls_ref;
        }
        ct_kws: list = [];
        for (ck, cvv) in ct_args.items() {
            mv = self._materialize(cvv, jac_node);
            if mv is None {
                return None;
            }
            ct_kws.append(self.nod('keyword', ['arg', 'value'], [ck, mv]));
        }
        return self.call_node(
            self._import_ref("jaclang.comptime", "specialize", jac_node),
            [cls_ref],
            ct_kws,
            jac_node=jac_node
        );
    }
    if kind == "CtFunc" {
        same_module = v.module
            == module_dotted_name(
                self.ir_in.loc.mod_path if self.ir_in.loc else "", self.ir_in.name
            );
        ct_only = v.ability is not None and v.ability.is_comptime;
        if same_module and not ct_only {
            parts = v.qualname.split(".");
            cur: CgNode = self.name_load(parts[0], jac_node);
            for part in parts[1:] {
                cur = self.nod(
                    'Attribute', ['value', 'attr', 'ctx'], [cur, part, load]
                );
            }
            return cur;
        }
        return self.call_node(
            self._import_ref("jaclang.comptime", "__ct_lazy", jac_node),
            [self.const_of(v.module, jac_node), self.const_of(v.qualname, jac_node)],
            [],
            jac_node=jac_node
        );
    }
    if kind == "CtRecord" {
        kws: list = [];
        for (k, item) in v.fields.items() {
            mv = self._materialize(item, jac_node);
            if mv is None {
                return None;
            }
            kws.append(self.nod('keyword', ['arg', 'value'], [k, mv]));
        }
        cls_ref = self._class_ref(v.module, v.class_name, jac_node);
        if self._record_bypasses_init(v) {
            return self.call_node(
                self._import_ref("jaclang.comptime", "record", jac_node),
                [cls_ref],
                kws,
                jac_node=jac_node
            );
        }
        return self.call_node(cls_ref, [], kws, jac_node=jac_node);
    }
    return None;
}

impl JcirGenPass._is_ct_type_param(nd: Name) -> bool {
    sym = nd.sym;
    if sym is None {
        return False;
    }
    owner = sym.decl.name_of;
    return isinstance(owner, TypeParam) and owner.is_comptime;
}

impl JcirGenPass._ct_param_decls(cls_expr: Expr) -> (list[TypeParam] | None) {
    t: any = cls_expr.type;
    shared: any = t?.shared;
    if shared is None or not shared?.ct_params {
        return None;
    }
    arch = shared.symbol_table;
    if not isinstance(arch, Archetype) {
        return None;
    }
    return `list(arch.type_params or []);
}

impl JcirGenPass._ct_ctor_slots(nd: AtomTrailer) -> (list[tuple] | None) {
    if nd.is_attr or not isinstance(nd.right, IndexSlice) or nd.right.is_range {
        return None;
    }
    tps = self._ct_param_decls(nd.target);
    if tps is None {
        return None;
    }
    s0 = nd.right.slices[0] if nd.right.slices else None;
    head = s0.start if s0 is not None else None;
    vals: list = `list(head.values)
        if isinstance(head, TupleVal)
        else ([head] if head else []);
    out: list[tuple] = [];
    for (i, tp) in enumerate(tps) {
        if tp.is_comptime and i < len(vals) {
            out.append((tp.name.value, vals[i], ));
        }
    }
    return out;
}

impl JcirGenPass._trailer_reaches_ct_class(nd: AtomTrailer) -> bool {
    cur: any = nd.target;
    while isinstance(cur, AtomTrailer) {
        if self._ct_ctor_slots(cur) is not None {
            return True;
        }
        cur = cur.target;
    }
    return False;
}

impl JcirGenPass._ct_param_fields(nd: Archetype) -> list[CgNode] {
    out: list[CgNode] = [];
    for tp in (nd.type_params or []) {
        if not tp.is_comptime {
            continue;
        }
        bnd = tp.bound;
        ann = self.val(bnd) if bnd is not None else self.name_load('object', tp);
        out.append(
            self.nod(
                'AnnAssign',
                ['target', 'annotation', 'value', 'simple'],
                [
                    self.nod(
                        'Name',
                        ['id', 'ctx'],
                        [tp.name.value, self.nod('Store', [], [])]
                    ),
                    ann,
                    self.call_node(
                        self._import_ref("jaclang.runtime.object_model", "field", tp),
                        [],
                        [
                            self.nod(
                                'keyword',
                                ['arg', 'value'],
                                ['kw_only', self.const_of(True)]
                            )
                        ]
                    ),
                    1
                ],
                jac_node=tp
            )
        );
    }
    return out;
}

impl JcirGenPass._record_bypasses_init(v: any) -> bool {
    ct = v?.class_type;
    shared = ct?.shared;
    if shared is None {
        return False;
    }
    for cls in (shared.mro or []) {
        arch = cls.shared.symbol_table;
        if not isinstance(arch, Archetype) {
            continue;
        }
        for m in arch.get_methods() {
            nm = m.name_ref.sym_name if m.name_ref else "";
            if nm in ("init", "__init__", "postinit", "__post_init__") {
                return True;
            }
        }
        for hv in arch.get_has_vars() {
            if hv.defer {
                return True;
            }
        }
    }
    return False;
}
