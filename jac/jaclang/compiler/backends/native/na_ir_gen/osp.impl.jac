"""The OSP runtime is two ordinary native units, `runtime/osp_kernel.jac` and
`runtime/osp_graph.jac`. A module that spawns, connects or reports pulls
them in exactly as it would any imported native module: their types and
abilities are declared from the AST, their symbols are named under their
own unit prefixes, and a dependency edge to each joins the module's native
interface so the link plan brings their objects along."""
impl NaIRGenOsp._register_osp_kernel_module -> None {
    if not self._osp_active() {
        return;
    }
    import from jaclang.compiler.frontend.codeinfo {
        OSP_GRAPH_REL,
        OSP_KERNEL_REL,
        kernel_unit_path
    }
    kernel_mod = self._load_native_unit_module(kernel_unit_path(OSP_KERNEL_REL));
    graph_mod = self._load_native_unit_module(kernel_unit_path(OSP_GRAPH_REL));
    if kernel_mod is None or graph_mod is None {
        return;
    }
    for unit in (kernel_mod, graph_mod) {
        unit.gen.nogc_enforced = getattr(self.ir_in.gen, "nogc_enforced", False);
        self._walk_imported_module_type_names(unit);
    }
    for unit in (kernel_mod, graph_mod) {
        self._register_imported_hierarchy(unit);
    }
    for unit in (kernel_mod, graph_mod) {
        self._walk_imported_module_types(unit);
    }
    for unit in (kernel_mod, graph_mod) {
        self._walk_imported_module_abilities(unit, with_fn_verdicts=False);
        if unit?.loc and unit.loc.mod_path {
            self._note_native_dep(unit.loc.mod_path);
        }
    }
    self._osp_kernel_mod = kernel_mod;
    self._osp_graph_mod = graph_mod;
}

"""The initializers of the OSP units, declared under their own names."""
impl NaIRGenOsp._osp_kernel_init_fns -> list[ir.Function] {
    import from jaclang.compiler.frontend.codeinfo { native_glob_init_name }
    out: list[ir.Function] = [];
    for unit in (self._osp_kernel_mod, self._osp_graph_mod) {
        if unit is None or not (unit?.loc and unit.loc.mod_path) {
            continue;
        }
        name = native_glob_init_name(unit.loc.mod_path);
        fn = self.func_symtab.get(name);
        if fn is None {
            fn = ir.Function(self.llvm_module, ir.FunctionType(ir.VoidType(), []), name=name);
            self.func_symtab[name] = fn;
        }
        out.append(fn);
    }
    return out;
}

impl NaIRGenOsp._compute_osp_model(archetypes: list[uni.Archetype]) -> None {
    for arch in archetypes {
        _n = arch.name.value if arch.name else None;
        if (_n is not None) and (arch.arch_kind is not None) {
            self.arch_ast_map[_n] = arch;
        }
    }
    import from jaclang.runtime.osp_model { get_osp_model }
    _model = get_osp_model(
        self.ir_in,
        archetypes=(list(archetypes) + list(self.arch_ast_map.values())),
        context=CodeContext.NATIVE
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

impl NaIRGenOsp._osp_active -> bool {
    _model = self.ir_in.gen.osp_model;
    return (_model is not None)
        and (_model.has_event_ability() or _model.uses_construct);
}

impl NaIRGenOsp._xmod_osp_help(names: list) -> (str | None) {
    _model = self.ir_in.gen.osp_model;
    _tags = _model.tags if (_model is not None) else {};
    for _n in names {
        if (
            (_n is not None) and (_n not in _tags) and (_n in self.imported_osp_archs)
        ) {
            (_kind, _mod) = self.imported_osp_archs[_n];
            return (
                f"the {_kind} archetype '{_n}' is imported from native module "
                f"'{_mod}' but was not materialized into this native compile; "
                f"ensure '{_mod}' compiles as native source, or define the "
                f"archetype in this module."
            );
        }
    }
    return None;
}

impl NaIRGenOsp._emit_osp_thunk(arch_name: str, method: uni.Ability) -> None {
    mname = method.name_ref.sym_name if method.name_ref else None;
    if mname is None {
        return;
    }
    full = f"{arch_name}.{mname}";
    if full in self.osp_thunk_funcs {
        return;
    }
    fn = self.method_funcs.get(full);
    if fn is None {
        return;
    }
    jv = self.jacval_type;

    # Every thunk is this module's own glue around a method it calls, so it
    # is internal to the unit; the unit prefix keeps the name unique in a
    # whole-program link where two units thunk the same method.
    _thunk_name = self._symbol_for(f"{full}.__ospthunk");
    _imported = arch_name in self.imported_osp_archs;
    if _imported {
        _thunk_name = f"{_thunk_name}.x{self._osp_thunk_uid}";
        self._osp_thunk_uid += 1;
    }
    thunk = ir.Function(
        self.llvm_module, ir.FunctionType(jv, [jv, jv]), name=_thunk_name
    );
    thunk.linkage = "internal";
    thunk.args[0].name = "a";
    thunk.args[1].name = "b";
    _saved = self._builder;
    self._builder = ir.IRBuilder(thunk.append_basic_block("entry"));
    _fn_args = fn.function_type.args;
    _call_args: list[ir.Value] = [];
    if len(_fn_args) >= 1 {
        _call_args.append(self._coerce_type(thunk.args[0], _fn_args[0]));
    }
    if len(_fn_args) >= 2 {
        _call_args.append(self._coerce_type(thunk.args[1], _fn_args[1]));
    }
    self.builder.call(fn, _call_args);
    self.builder.ret(ir.Constant(jv, None));
    self._builder = _saved;
    self.osp_thunk_funcs[full] = thunk;
}

impl NaIRGenOsp._osp_rc_new(struct_name: str) -> (ir.Value | None) {
    st = self.struct_types.get(struct_name);
    if st is None {
        return None;
    }
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    sptr = st.as_pointer();
    _null = ir.Constant(sptr, None);
    _sz = self.builder.ptrtoint(
        self.builder.gep(_null, [ir.Constant(i32, 1)], name="osp.sz.gep"),
        i64,
        name="osp.sz"
    );
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    _alloc_fn = self.rc_alloc_fn;
    assert _alloc_fn is not None , "rc helpers are emitted before osp allocation";
    _raw = self._rc_call_with_ctx(_alloc_fn, [_sz], op="osp", loc="", name="osp.raw");
    self._osp_make_immortal(_raw);
    struct_ptr = self.builder.bitcast(_raw, sptr, name=f"osp.{struct_name}");

    _ftypes = self.struct_field_types.get(struct_name, {});
    for (_fname, _fidx) in self.struct_field_indices.get(struct_name, {}).items() {
        _ftype = _ftypes.get(_fname);
        if _ftype is None {
            continue;
        }
        self.builder.store(
            ir.Constant(_ftype, None),
            self.builder.gep(
                struct_ptr,
                [ir.Constant(i32, 0), ir.Constant(i32, _fidx)],
                name=f"osp.zero.{_fname}"
            )
        );
    }
    return struct_ptr;
}

impl NaIRGenOsp._osp_make_immortal(ptr: ir.Value) -> None {
    if self._nogc_headerless() {
        return;
    }
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    _raw = self.builder.bitcast(ptr, i8p, name="osp.imm.i8");
    _rc_slot = self.builder.gep(
        _raw, [ir.Constant(i64, HDR_RC_OFF)], name="osp.imm.rc.slot"
    );
    self.builder.store(
        ir.Constant(i64, RC_SENTINEL),
        self.builder.bitcast(_rc_slot, i64.as_pointer(), name="osp.imm.rc.p")
    );
}

impl NaIRGenOsp._osp_collect_slots(arch_name: str, is_entry: bool) -> list {
    slots: list = [];
    _model = self.ir_in.gen.osp_model;
    if _model is None {
        return slots;
    }
    _src = _model.entry_slots(arch_name) if is_entry else _model.exit_slots(arch_name);
    for _slot in _src {
        thunk = self.osp_thunk_funcs.get(f"{arch_name}.{_slot.ability}");
        if thunk is None {
            continue;
        }
        for _tag in _model.trigger_tags(_slot) {
            slots.append((_tag, thunk));
        }
    }
    return slots;
}

impl NaIRGenOsp._osp_build_slot(
    trig_tag: int, thunk: ir.Function
) -> (ir.Value | None) {
    slot = self._osp_rc_new("Slot");
    if slot is None {
        return None;
    }
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    _idx = self.struct_field_indices.get("Slot", {});
    self.builder.store(
        ir.Constant(i64, trig_tag),
        self.builder.gep(
            slot,
            [ir.Constant(i32, 0), ir.Constant(i32, _idx.get("trig_tag", 0))],
            name="slot.trig"
        )
    );
    _fn_ty = self.struct_field_types.get("Slot", {}).get("fn");
    _fn_val = self._coerce_type(thunk, _fn_ty) if _fn_ty is not None else thunk;
    self.builder.store(
        _fn_val,
        self.builder.gep(
            slot,
            [ir.Constant(i32, 0), ir.Constant(i32, _idx.get("fn", 1))],
            name="slot.fn"
        )
    );
    return slot;
}

impl NaIRGenOsp._osp_build_slot_list(pairs: list) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    _h = self.list_helpers.get("ptr");
    _lst = self._rc_call_with_ctx(_h["new"], [], op="new", loc="", name="osp.slots");
    for _pair in pairs {
        _slot = self._osp_build_slot(_pair[0], _pair[1]);
        if _slot is not None {
            _e = self.builder.bitcast(_slot, i8p, name="osp.slot.i8");
            self._rc_call_with_ctx(_h["append"], [_lst, _e], op="append", loc="");
        }
    }

    self._osp_make_immortal(_lst);
    return _lst;
}

impl NaIRGenOsp._osp_build_descriptor(
    struct_name: str, type_tag: int, entry_slots: list, exit_slots: list
) -> (ir.Value | None) {
    desc = self._osp_rc_new(struct_name);
    if desc is None {
        return None;
    }
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    _idx = self.struct_field_indices.get(struct_name, {});
    self.builder.store(
        ir.Constant(i64, type_tag),
        self.builder.gep(
            desc,
            [ir.Constant(i32, 0), ir.Constant(i32, _idx.get("type_tag", 0))],
            name="desc.tag"
        )
    );
    self.builder.store(
        self._osp_build_slot_list(entry_slots),
        self.builder.gep(
            desc,
            [ir.Constant(i32, 0), ir.Constant(i32, _idx.get("entry", 1))],
            name="desc.entry"
        )
    );
    self.builder.store(
        self._osp_build_slot_list(exit_slots),
        self.builder.gep(
            desc,
            [ir.Constant(i32, 0), ir.Constant(i32, _idx.get("exit", 2))],
            name="desc.exit"
        )
    );
    return desc;
}

impl NaIRGenOsp._osp_emit_callbacks -> dict {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    _fields = self.struct_field_types.get("OspRuntime", {});
    _saved = self._builder;
    out: dict = {};

    _tf = self._define_function("__osp_tag_of", _fields["tag_of"].pointee);
    _tf.linkage = "internal";
    self._builder = ir.IRBuilder(_tf.append_basic_block("entry"));
    _pl = self.builder.extract_value(_tf.args[0], 1, name="h.payload");
    _hp = self.builder.inttoptr(_pl, i8p, name="h.ptr");
    _tp = self.builder.bitcast(
        self.builder.gep(_hp, [ir.Constant(i64, 8)], name="h.tagp"),
        i64.as_pointer(),
        name="h.tagp64"
    );
    self.builder.ret(self.builder.load(_tp, name="h.tag"));
    out["tag_of"] = _tf;

    out["is_a"] = self.func_symtab.get("osp_is_a");
    out["node_desc"] = self.func_symtab.get("osp_node_desc");

    _ocf = ir.Function(
        self.llvm_module, _fields["on_complete"].pointee, name="__osp_on_complete"
    );
    _ocf.linkage = "internal";
    self._builder = ir.IRBuilder(_ocf.append_basic_block("entry"));
    _ws_idx = self.struct_field_indices.get("WalkScope", {});
    if _ws_idx {
        _deliver = _ocf.append_basic_block("deliver");
        _oc_done = _ocf.append_basic_block("done");
        _scope = _ocf.args[0];

        _nested = self.builder.load(
            self.builder.gep(
                _scope,
                [ir.Constant(i32, 0), ir.Constant(i32, _ws_idx["nested"])],
                name="oc.nested.p"
            ),
            name="oc.nested"
        );
        self.builder.cbranch(
            self.builder.icmp_unsigned(
                "!=", _nested, ir.Constant(_nested.type, 0), name="oc.isnested"
            ),
            _oc_done,
            _deliver
        );
        self._builder = ir.IRBuilder(_deliver);

        _wlk_jv = self.builder.load(
            self.builder.gep(
                _scope,
                [ir.Constant(i32, 0), ir.Constant(i32, _ws_idx["wlk"])],
                name="oc.wlk.p"
            ),
            name="oc.wlk.jv"
        );
        _wlk_i8 = self.builder.inttoptr(
            self.builder.extract_value(_wlk_jv, 1, name="oc.wlk.payload"),
            i8p,
            name="oc.wlk.i8"
        );
        _rep = self.builder.load(
            self.builder.gep(
                _scope,
                [ir.Constant(i32, 0), ir.Constant(i32, _ws_idx["reports"])],
                name="oc.rep.p"
            ),
            name="oc.rep"
        );
        self._osp_make_immortal(_rep);
        self.builder.store(
            _rep,
            self.builder.bitcast(
                self.builder.gep(_wlk_i8, [ir.Constant(i64, 16)], name="oc.repslot.i8"),
                _rep.type.as_pointer(),
                name="oc.repslot"
            )
        );
        self.builder.branch(_oc_done);
        self._builder = ir.IRBuilder(_oc_done);
    }
    self.builder.ret_void();
    out["on_complete"] = _ocf;
    self._builder = _saved;
    return out;
}

impl NaIRGenOsp._emit_osp_setup -> None {
    _model = self.ir_in.gen.osp_model;
    if (_model is None) or (not self._osp_active()) {
        return;
    }

    for _req in ["Slot", "WalkerDesc", "NodeDesc", "OspRuntime"] {
        if _req not in self.struct_types {
            return;
        }
    }
    for _rfn in [
        "osp_is_a",
        "osp_node_desc",
        "osp_register_type",
        "osp_register_desc"
    ] {
        if _rfn not in self.func_symtab {
            return;
        }
    }
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();

    _rt_ty = self.struct_types["OspRuntime"].as_pointer();
    self._osp_rt_global = ir.GlobalVariable(self.llvm_module, _rt_ty, name="__ospRT");
    self._osp_rt_global.linkage = "internal";
    self._osp_rt_global.initializer = ir.Constant(_rt_ty, None);

    _cbs = self._osp_emit_callbacks();

    _setup = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), []), name="__osp_setup"
    );
    _setup.linkage = "internal";
    self._osp_setup_fn = _setup;
    _saved = self._builder;
    self._builder = ir.IRBuilder(_setup.append_basic_block("entry"));
    _reg_ty_fn = self.func_symtab.get("osp_register_type");
    _reg_desc_fn = self.func_symtab.get("osp_register_desc");
    self._emit_list_helpers("i64", i64);
    _lh = self.list_helpers.get("i64");
    for _name in _model.order {
        _tag = _model.tags.get(_name, 0);
        if (_reg_ty_fn is not None) and (_lh is not None) {
            _bases = self._rc_call_with_ctx(
                _lh["new"], [], op="new", loc="", name="osp.bases"
            );
            for _anc in _model.isa.get(_name, []) {
                if (_anc != _name) and (_anc in _model.tags) {
                    self._rc_call_with_ctx(
                        _lh["append"],
                        [_bases, ir.Constant(i64, _model.tags[_anc])],
                        op="append",
                        loc=""
                    );
                }
            }
            _rt_args = _reg_ty_fn.function_type.args;
            self.builder.call(
                _reg_ty_fn,
                [
                    self._coerce_type(ir.Constant(i64, _tag), _rt_args[0]),
                    self._coerce_type(_bases, _rt_args[1])
                ]
            );
            self._emit_rc_release_simple(_bases, op="osp_reg_type", loc="");
        }
        _sn = "WalkerDesc" if (_model.arch_kind.get(_name) == "walker") else "NodeDesc";

        _desc = self._osp_build_descriptor(
            _sn,
            _tag,
            self._osp_collect_slots(_name, True),
            self._osp_collect_slots(_name, False)
        );
        if (_desc is not None) and (_reg_desc_fn is not None) {
            _rd_args = _reg_desc_fn.function_type.args;
            self.builder.call(
                _reg_desc_fn,
                [
                    self._coerce_type(ir.Constant(i64, _tag), _rd_args[0]),
                    self._coerce_type(_desc, _rd_args[1])
                ]
            );
        }
    }
    _rt = self._osp_rc_new("OspRuntime");
    if _rt is not None {
        _rf = self.struct_field_types.get("OspRuntime", {});
        _ridx = self.struct_field_indices.get("OspRuntime", {});
        for _fname in ["tag_of", "is_a", "node_desc", "on_complete"] {
            _cb = self._coerce_type(_cbs[_fname], _rf[_fname]);
            self.builder.store(
                _cb,
                self.builder.gep(
                    _rt,
                    [ir.Constant(i32, 0), ir.Constant(i32, _ridx.get(_fname, 0))],
                    name=f"rt.{_fname}"
                )
            );
        }
        self.builder.store(_rt, self._osp_rt_global);
    }
    self.builder.ret_void();

    _inited = ir.GlobalVariable(self.llvm_module, i8, name="__osp_inited");
    _inited.linkage = "internal";
    _inited.initializer = ir.Constant(i8, 0);
    _kernel_inits = self._osp_kernel_init_fns();
    _ensure = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), []), name="__osp_ensure_init"
    );
    _ensure.linkage = "internal";
    self._osp_ensure_fn = _ensure;

    _died_fn = self.func_symtab.get("osp_region_died");
    if (_died_fn is not None) and ("__jac_region_died_hook" not in self.extern_funcs) {
        _hook = ir.Function(
            self.llvm_module,
            ir.FunctionType(ir.VoidType(), [i64]),
            name="__jac_region_died_hook"
        );
        _hook.linkage = "linkonce_odr";
        _hook.args[0].name = "rgn";
        _hb = ir.IRBuilder(_hook.append_basic_block("entry"));
        _hb.call(_ensure, []);
        _died_argty = _died_fn.function_type.args[0];
        _died_arg: ir.Value = _hook.args[0];
        if _died_argty != i64 {
            _died_arg = _hb.bitcast(_hook.args[0], _died_argty, name="rgn.died.arg");
        }
        _hb.call(_died_fn, [_died_arg]);
        _hb.ret_void();
        self.extern_funcs["__jac_region_died_hook"] = _hook;
    }
    _e_entry = _ensure.append_basic_block("entry");
    _e_srun = _ensure.append_basic_block("setup_run");
    _e_done = _ensure.append_basic_block("done");

    # Every unit initializer guards itself, so the OSP units' initializers
    # are simply called through; the guard below covers only this module's
    # own runtime-table setup.
    _chk_b = ir.IRBuilder(_e_entry);
    for _kgi in _kernel_inits {
        _chk_b.call(_kgi, []);
    }
    _chk_b.cbranch(
        _chk_b.icmp_unsigned(
            "!=", _chk_b.load(_inited, name="osp.inited"), ir.Constant(i8, 0)
        ),
        _e_done,
        _e_srun
    );
    _rb = ir.IRBuilder(_e_srun);
    _rb.store(ir.Constant(i8, 1), _inited);
    _rb.call(_setup, []);
    _rb.branch(_e_done);
    ir.IRBuilder(_e_done).ret_void();
    self._builder = _saved;
}

impl NaIRGenOsp._osp_generic_edge -> (ir.Value | None) {
    if self.rc_alloc_fn is None {
        return None;
    }
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    func = self.builder.function;
    heap_bb = func.append_basic_block(name="gedge.heap");
    rgn_bb = func.append_basic_block(name="gedge.region");
    merge_bb = func.append_basic_block(name="gedge.merge");
    _cur = self._region_current();
    self.builder.cbranch(
        self.builder.icmp_unsigned(
            "==", _cur, ir.Constant(i8p, None), name="gedge.nocur"
        ),
        heap_bb,
        rgn_bb
    );
    self.builder.position_at_end(heap_bb);
    _raw = self._rc_call_with_ctx(
        self.rc_alloc_fn, [ir.Constant(i64, 8)], op="osp", loc="", name="osp.gedge"
    );
    self._osp_make_immortal(_raw);
    _raw = self._region_ptr(_raw, name="osp.gedge.i8");
    heap_end = self.builder.block;
    self.builder.branch(merge_bb);
    self.builder.position_at_end(rgn_bb);
    _rgn = self._region_alloc_object(_cur, ir.Constant(i64, 8), None);
    rgn_end = self.builder.block;
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
    _edge = self.builder.phi(i8p, name="osp.gedge.obj");
    _edge.add_incoming(_raw, heap_end);
    _edge.add_incoming(_rgn, rgn_end);
    return _edge;
}

impl NaIRGenOsp._codegen_connect(nd: uni.BinaryExpr) -> (ir.Value | None) {
    co = nd.op;
    if not isinstance(co, uni.ConnectOp) {
        return None;
    }
    osp_conn_fn = self.func_symtab.get("osp_conn");

    _xnames: list = [
        self._spawn_operand_name(nd.left),
        self._spawn_operand_name(nd.right),

    ];
    if co.conn_type is not None {
        _xnames.append(self._spawn_operand_name(co.conn_type));
    }
    _xhelp = self._xmod_osp_help(_xnames);
    if (osp_conn_fn is None) or (_xhelp is not None) {
        self.emit(
            E5092,
            node_override=nd,
            kind="binary operator",
            name="ConnectOp",
            help_text=_xhelp
        );
        return None;
    }

    if self._osp_ensure_fn is not None {
        self.builder.call(self._osp_ensure_fn, []);
    }
    left = self._codegen_expr(nd.left);
    right = self._codegen_expr(nd.right);
    if (left is None) or (right is None) {
        return None;
    }
    i64 = ir.IntType(64);
    dir_val = int(co.edge_dir.value);
    undirected = 1 if dir_val == 3 else 0;
    if dir_val == 1 {
        (src, tgt) = (right, left);
    } else {
        (src, tgt) = (left, right);
    }
    edge_tag = -1;
    edge_obj: (ir.Value | None) = None;
    if co.conn_type is not None {
        _etname: (str | None) = None;
        if isinstance(co.conn_type, uni.Name) {
            edge_obj = self._codegen_instantiation(co.conn_type);

            _etname = self._get_name(co.conn_type);
        } else {
            edge_obj = self._codegen_expr(co.conn_type);
            _etname = self._spawn_operand_name(co.conn_type);
        }
        if _etname is not None {
            _ce_model = self.ir_in.gen.osp_model;
            edge_tag = _ce_model.tags.get(_etname, -1)
                if (_ce_model is not None)
                else -1;
        }
    } else {
        edge_obj = self._osp_generic_edge();
    }
    if edge_obj is None {
        return tgt;
    }

    self._osp_make_immortal(edge_obj);
    _argtys = osp_conn_fn.function_type.args;
    _src_i64 = self._coerce_type(src, _argtys[0]);
    _tgt_i64 = self._coerce_type(tgt, _argtys[1]);
    _rgn_of_fn = self._region_kernel_fn("__jac_region_of");
    _rgn_src: ir.Value = self.builder.call(
        _rgn_of_fn, [self._coerce_type(_src_i64, i64)], name="conn.rgn.src"
    );
    _rgn_tgt: ir.Value = self.builder.call(
        _rgn_of_fn, [self._coerce_type(_tgt_i64, i64)], name="conn.rgn.tgt"
    );
    self.builder.call(
        osp_conn_fn,
        [
            _src_i64,
            _tgt_i64,
            self._coerce_type(edge_obj, _argtys[2]),
            self._coerce_type(ir.Constant(i64, undirected), _argtys[3]),
            self._coerce_type(ir.Constant(i64, edge_tag), _argtys[4]),
            self._coerce_type(_rgn_src, _argtys[5]),
            self._coerce_type(_rgn_tgt, _argtys[6])
        ]
    );
    return tgt;
}

impl NaIRGenOsp._osp_disc_list_operand(expr: (uni.UniNode | None)) -> bool {
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

impl NaIRGenOsp._codegen_disconnect(nd: uni.BinaryExpr) -> (ir.Value | None) {
    dop = nd.op;
    if not isinstance(dop, uni.DisconnectOp) {
        return None;
    }
    disc_fn = self.func_symtab.get("osp_disconn_between");
    _fcond = dop.edge_spec.filter_cond;
    _xnames: list = [
        self._spawn_operand_name(nd.left),
        self._spawn_operand_name(nd.right),

    ];
    _etname: (str | None) = None;
    if (_fcond is not None) and (_fcond.f_type is not None) {
        _etname = self._get_name(_fcond.f_type);
        _xnames.append(_etname);
    }
    _xhelp = self._xmod_osp_help(_xnames);
    if (disc_fn is None) or (_xhelp is not None) {
        self.emit(
            E5092,
            node_override=nd,
            kind="binary operator",
            name="DisconnectOp",
            help_text=_xhelp
        );
        return None;
    }
    _left_is_list = self._osp_disc_list_operand(nd.left);
    _right_is_list = self._osp_disc_list_operand(nd.right);
    _disc_compares: list = [];
    if (_fcond is not None) and _fcond.compares {
        _disc_compares = [
            _c
            for _c in _fcond.compares
            if isinstance(_c, uni.CompareExpr)
        ];
    }
    if _disc_compares and (_left_is_list or _right_is_list) {
        self.emit(
            E5092,
            node_override=nd,
            kind="binary operator",
            name="DisconnectOp",
            help_text="a disconnect with both list operands and attribute "
            "predicates is not lowered natively; loop over the nodes and "
            "disconnect each pair."
        );
        return None;
    }
    if _disc_compares and (_etname is None) {
        self.emit(
            E5092,
            node_override=nd,
            kind="binary operator",
            name="DisconnectOp",
            help_text="edge attribute predicates need a named edge type "
            "(`del ->:E:field == value:->`) so the edge layout is known"
        );
        return None;
    }
    i64 = ir.IntType(64);
    edge_tag = -1;
    if (_fcond is not None) and (_fcond.f_type is not None) {
        _dc_model = self.ir_in.gen.osp_model;
        _dc_tags = _dc_model.tags if (_dc_model is not None) else {};
        edge_tag = _dc_tags.get(_etname, -1) if (_etname is not None) else -1;
        if edge_tag < 0 {
            self.emit(
                E5092,
                node_override=nd,
                kind="binary operator",
                name="DisconnectOp",
                help_text=self._xmod_osp_help([_etname])
            );
            return None;
        }
    }
    if self._osp_ensure_fn is not None {
        self.builder.call(self._osp_ensure_fn, []);
    }
    left = self._codegen_expr(nd.left);
    right = self._codegen_expr(nd.right);
    if (left is None) or (right is None) {
        return None;
    }
    _dir = int(dop.edge_spec.edge_dir.value);
    _res: (ir.Value | None) = None;
    if _disc_compares {
        _pfn = self.func_symtab.get("osp_disconn_between_pred");
        _ppair = self._osp_pred_pair(_etname or "", _disc_compares, nd);
        if (_pfn is None) or (_ppair is None) {
            self.emit(
                E5092, node_override=nd, kind="binary operator", name="DisconnectOp"
            );
            return None;
        }
        _pargs = _pfn.function_type.args;
        _res = self.builder.call(
            _pfn,
            [
                self._coerce_type(left, _pargs[0]),
                self._coerce_type(right, _pargs[1]),
                self._coerce_type(ir.Constant(i64, _dir), _pargs[2]),
                self._coerce_type(ir.Constant(i64, edge_tag), _pargs[3]),
                self._coerce_type(_ppair, _pargs[4])
            ],
            name="osp.disc.pred"
        );
    } elif _left_is_list or _right_is_list {
        _mfn = self.func_symtab.get("osp_disconn_between_many");
        _wrap_fn = self.func_symtab.get("osp_wrap1");
        if (_mfn is None) or (_wrap_fn is None) {
            self.emit(
                E5092, node_override=nd, kind="binary operator", name="DisconnectOp"
            );
            return None;
        }
        _wargty = _wrap_fn.function_type.args[0];
        _srcs = left
            if _left_is_list
            else self.builder.call(
                _wrap_fn, [self._coerce_type(left, _wargty)], name="osp.disc.src1"
            );
        _tgts = right
            if _right_is_list
            else self.builder.call(
                _wrap_fn, [self._coerce_type(right, _wargty)], name="osp.disc.tgt1"
            );
        _margs = _mfn.function_type.args;
        _res = self.builder.call(
            _mfn,
            [
                self._coerce_type(_srcs, _margs[0]),
                self._coerce_type(_tgts, _margs[1]),
                self._coerce_type(ir.Constant(i64, _dir), _margs[2]),
                self._coerce_type(ir.Constant(i64, edge_tag), _margs[3])
            ],
            name="osp.disc.many"
        );
        if _srcs is not left {
            self._emit_rc_release_simple(_srcs, op="osp_disc_many", loc="");
        }
        if _tgts is not right {
            self._emit_rc_release_simple(_tgts, op="osp_disc_many", loc="");
        }
    } else {
        _argtys = disc_fn.function_type.args;
        _res = self.builder.call(
            disc_fn,
            [
                self._coerce_type(left, _argtys[0]),
                self._coerce_type(right, _argtys[1]),
                self._coerce_type(ir.Constant(i64, _dir), _argtys[2]),
                self._coerce_type(ir.Constant(i64, edge_tag), _argtys[3])
            ],
            name="osp.disc"
        );
    }
    return self.builder.icmp_signed(
        "!=", _res, ir.Constant(_res.type, 0), name="osp.disc.bool"
    );
}

impl NaIRGenOsp._codegen_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> (ir.Value | None) {
    osp_refs_fn = self.func_symtab.get("osp_refs");
    if (osp_refs_fn is None) or (not nd.chain) {
        self.emit(E5092, node_override=nd, kind="expression", name="EdgeRefTrailer");
        return None;
    }
    i64 = ir.IntType(64);
    chain = nd.chain;

    _idx = 0;
    origin_val: (ir.Value | None) = None;
    if isinstance(chain[0], uni.EdgeOpRef) {
        _here = self.local_vars.get("here");
        if _here is None {
            self.emit(
                E5092, node_override=nd, kind="expression", name="EdgeRefTrailer"
            );
            return None;
        }
        origin_val = self.builder.load(_here, name="here");
    } else {
        origin_val = self._codegen_expr(chain[0]);
        _idx = 1;
    }

    if (origin_val is None)
        or (_idx >= len(chain))
        or (not isinstance(chain[_idx], uni.EdgeOpRef)) {
        self.emit(E5092, node_override=nd, kind="expression", name="EdgeRefTrailer");
        return None;
    }

    _er_model = self.ir_in.gen.osp_model;
    _er_tags = _er_model.tags if (_er_model is not None) else {};
    _many_fn = self.func_symtab.get("osp_refs_many");
    _cur: (ir.Value | None) = None;
    while (_idx < len(chain)) and isinstance(chain[_idx], uni.EdgeOpRef) {
        step = chain[_idx];
        _idx += 1;

        _step_filter: (uni.FilterCompr | None) = None;
        if _idx < len(chain) {
            _f = chain[_idx];
            if isinstance(_f, uni.FilterCompr) and (_f.f_type is not None) {
                _step_filter = _f;
                _idx += 1;
            }
        }
        _is_last_hop = (_idx >= len(chain))
            or (not isinstance(chain[_idx], uni.EdgeOpRef));

        _dir = int(step.edge_dir.value);
        _edge_tag = -1;
        _etname: (str | None) = None;
        _fcond = step.filter_cond;
        if (_fcond is not None) and (_fcond.f_type is not None) {
            _etname = self._get_name(_fcond.f_type);
            if _etname is not None {
                _edge_tag = _er_tags.get(_etname, -1);

                if _edge_tag < 0 {
                    self.emit(
                        E5092,
                        node_override=nd,
                        kind="expression",
                        name="EdgeRefTrailer",
                        help_text=self._xmod_osp_help([_etname])
                    );
                    return None;
                }
            }
        }
        _ec_compares: list = [];
        if (_fcond is not None) and _fcond.compares {
            _ec_compares = list(_fcond.compares);
        }
        if _ec_compares and (_etname is None) {
            self.emit(
                E5092,
                node_override=nd,
                kind="expression",
                name="EdgeRefTrailer",
                help_text="edge attribute predicates need a named edge type "
                "(`->:E:field == value:->`) so the edge layout is known"
            );
            return None;
        }
        _edges_only = 1 if (nd.edges_only and _is_last_hop) else 0;
        if _ec_compares {
            _wrap_fn = self.func_symtab.get("osp_wrap1");
            _eph_fn = self.func_symtab.get("osp_refs_edge_pred");
            _pred_pair = self._osp_pred_pair(_etname or "", _ec_compares, nd);
            if (_eph_fn is None) or (_pred_pair is None) {
                self.emit(
                    E5092, node_override=nd, kind="expression", name="EdgeRefTrailer"
                );
                return None;
            }
            if _cur is not None {
                _origins = _cur;
            } elif _wrap_fn is not None {
                _origins = self.builder.call(
                    _wrap_fn,
                    [self._coerce_type(origin_val, _wrap_fn.function_type.args[0])],
                    name="osp.eph.org1"
                );
            } else {
                self.emit(
                    E5092, node_override=nd, kind="expression", name="EdgeRefTrailer"
                );
                return None;
            }
            _eargs = _eph_fn.function_type.args;
            _result = self.builder.call(
                _eph_fn,
                [
                    self._coerce_type(_origins, _eargs[0]),
                    self._coerce_type(ir.Constant(i64, _dir), _eargs[1]),
                    self._coerce_type(ir.Constant(i64, _edge_tag), _eargs[2]),
                    self._coerce_type(ir.Constant(i64, _edges_only), _eargs[3]),
                    self._coerce_type(_pred_pair, _eargs[4])
                ],
                name="osp.refs.epred"
            );
            self._mark_owned(_result);
            self._emit_rc_release_simple(_origins, op="osp_refs_hop", loc="");
        } elif _cur is None {
            _argtys = osp_refs_fn.function_type.args;
            _result = self.builder.call(
                osp_refs_fn,
                [
                    self._coerce_type(origin_val, _argtys[0]),
                    self._coerce_type(ir.Constant(i64, _dir), _argtys[1]),
                    self._coerce_type(ir.Constant(i64, _edge_tag), _argtys[2]),
                    self._coerce_type(ir.Constant(i64, _edges_only), _argtys[3])
                ],
                name="osp.refs"
            );
            self._mark_owned(_result);
        } else {
            if _many_fn is None {
                self.emit(
                    E5092, node_override=nd, kind="expression", name="EdgeRefTrailer"
                );
                return None;
            }
            _margtys = _many_fn.function_type.args;
            _result = self.builder.call(
                _many_fn,
                [
                    self._coerce_type(_cur, _margtys[0]),
                    self._coerce_type(ir.Constant(i64, _dir), _margtys[1]),
                    self._coerce_type(ir.Constant(i64, _edge_tag), _margtys[2]),
                    self._coerce_type(ir.Constant(i64, _edges_only), _margtys[3])
                ],
                name="osp.refs.many"
            );
            self._mark_owned(_result);
            self._emit_rc_release_simple(_cur, op="osp_refs_hop", loc="");
        }
        if _step_filter is not None {
            _filter_fn = self.func_symtab.get("osp_filter");
            _node_filter = self._get_name(_step_filter.f_type);
            _ntag = _er_tags.get(_node_filter, -1) if _node_filter is not None else -1;
            _tpair = self._osp_type_pair(_ntag) if _ntag >= 0 else None;
            if (_ntag < 0) or (_tpair is None) or (_filter_fn is None) {
                self.emit(
                    E5092,
                    node_override=nd,
                    kind="expression",
                    name="EdgeRefTrailer",
                    help_text=self._xmod_osp_help([_node_filter])
                );
                return None;
            }
            _fargs = _filter_fn.function_type.args;
            _unfiltered = _result;
            _result = self.builder.call(
                _filter_fn,
                [
                    self._coerce_type(_unfiltered, _fargs[0]),
                    self._coerce_type(_tpair, _fargs[1])
                ],
                name="osp.refs.filt"
            );
            self._mark_owned(_result);

            self._emit_rc_release_simple(_unfiltered, op="osp_refs_filtered", loc="");
            if _step_filter.compares {
                _ppair = self._osp_pred_pair(
                    _node_filter or "",
                    [
                        _c
                        for _c in _step_filter.compares
                        if isinstance(_c, uni.CompareExpr)
                    ],
                    nd
                );
                if _ppair is None {
                    return None;
                }
                _prefiltered = _result;
                _result = self.builder.call(
                    _filter_fn,
                    [
                        self._coerce_type(_prefiltered, _fargs[0]),
                        self._coerce_type(_ppair, _fargs[1])
                    ],
                    name="osp.refs.pred"
                );
                self._mark_owned(_result);
                self._emit_rc_release_simple(_prefiltered, op="osp_refs_pred", loc="");
            }
        }
        _cur = _result;
    }

    if (_cur is None) or (_idx != len(chain)) {
        self.emit(E5092, node_override=nd, kind="expression", name="EdgeRefTrailer");
        return None;
    }
    return _cur;
}

impl NaIRGenOsp._codegen_chained_filter(nd: uni.AtomTrailer) -> (ir.Value | None) {
    i64 = ir.IntType(64);
    _f = nd.right;
    if not isinstance(_f, uni.FilterCompr) {
        return None;
    }
    _fname = self._get_name(_f.f_type) if _f.f_type is not None else None;
    if _fname is None and _f.compares {
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
    target_val = self._codegen_expr(nd.target);
    if target_val is None {
        return None;
    }
    _result = target_val;
    _filter_fn = self.func_symtab.get("osp_filter");
    if _f.f_type is not None {
        _model = self.ir_in.gen.osp_model;
        _tags = _model.tags if _model is not None else {};
        _ntag = _tags.get(_fname, -1);
        _tpair = self._osp_type_pair(_ntag) if _ntag >= 0 else None;
        if _ntag < 0 or _tpair is None or _filter_fn is None {
            self.emit(
                E5092,
                node_override=nd,
                kind="expression",
                name="FilterCompr",
                help_text=self._xmod_osp_help([_fname])
            );
            return None;
        }
        _fargs = _filter_fn.function_type.args;
        _result = self.builder.call(
            _filter_fn,
            [
                self._coerce_type(target_val, _fargs[0]),
                self._coerce_type(_tpair, _fargs[1])
            ],
            name="osp.chain.filt"
        );
        if isinstance(target_val.type, ir.PointerType) and self._is_owned(target_val) {
            self._emit_rc_release_simple(target_val, op="chain_filter", loc="");
        }
    }
    if _f.compares {
        _ppair = self._osp_pred_pair(
            _fname or "",
            [
                _c
                for _c in _f.compares
                if isinstance(_c, uni.CompareExpr)
            ],
            nd
        );
        if (_ppair is None) or (_filter_fn is None) {
            if _filter_fn is None {
                self.emit(
                    E5092, node_override=nd, kind="expression", name="FilterCompr"
                );
            }
            return None;
        }
        _fargs2 = _filter_fn.function_type.args;
        _pred = self.builder.call(
            _filter_fn,
            [
                self._coerce_type(_result, _fargs2[0]),
                self._coerce_type(_ppair, _fargs2[1])
            ],
            name="osp.chain.pred"
        );
        if _result is target_val {
            if isinstance(target_val.type, ir.PointerType)
                and self._is_owned(target_val) {
                self._emit_rc_release_simple(target_val, op="chain_filter", loc="");
            }
        } else {
            self._emit_rc_release_simple(_result, op="chain_filter_pred", loc="");
        }
        _result = _pred;
    }
    self._mark_owned(_result);
    return _result;
}

impl NaIRGenOsp._elem_arch_name_of(expr: (uni.UniNode | None)) -> (str | None) {
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
        return _elem.shared.class_name;
    }
    return None;
}

impl NaIRGenOsp._osp_pred_pair(
    arch_name: str, compares: list[uni.CompareExpr], nd: uni.UniNode
) -> (ir.Value | None) {
    _fields = self.struct_field_indices.get(arch_name);
    if _fields is None {
        self.emit(
            E5092,
            node_override=nd,
            kind="expression",
            name="FilterCompr",
            help_text=self._xmod_osp_help([arch_name])
        );
        return None;
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
            return None;
        }
    }
    _rhs_vals: list = [];
    for cmp in compares {
        _rv = self._codegen_expr(cmp.rights[0]);
        if _rv is None {
            return None;
        }
        _rhs_vals.append(_rv);
    }
    i1t = ir.IntType(1);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    _env_ty = ir.LiteralStructType([_v.type for _v in _rhs_vals]);
    _env = self.builder.alloca(_env_ty, name="predp.env");
    for (_ci, _v) in enumerate(_rhs_vals) {
        self.builder.store(
            _v,
            self.builder.gep(
                _env, [ir.Constant(i32, 0), ir.Constant(i32, _ci)], name="predp.envslot"
            )
        );
    }
    self._osp_thunk_uid += 1;
    _tf = ir.Function(
        self.llvm_module,
        ir.FunctionType(i1t, [i64, i8p]),
        name=f"__osp_pred.x{self._osp_thunk_uid}"
    );
    _tf.linkage = "internal";
    _saved = self._builder;
    self._builder = ir.IRBuilder(_tf.append_basic_block("entry"));
    _envp = self.builder.bitcast(_tf.args[1], _env_ty.as_pointer(), name="predp.envp");
    _keepc: ir.Value = ir.Constant(i1t, 1);
    _ok = True;
    for (_ci, cmp) in enumerate(compares) {
        if not isinstance(cmp.left, uni.Name) {
            _ok = False;
            break;
        }
        _rv = self.builder.load(
            self.builder.gep(
                _envp, [ir.Constant(i32, 0), ir.Constant(i32, _ci)], name="predp.rvp"
            ),
            name="predp.rv"
        );
        _fval = self._codegen_field_access(
            _tf.args[0], cmp.left.value, arch_name, cmp.left
        );
        if _fval is None {
            _ok = False;
            break;
        }
        _op = cmp.ops[0].name if isinstance(cmp.ops[0], uni.Token) else str(cmp.ops[0]);
        _cres = self._codegen_compare_link(
            _op, _fval, _rv, cmp.left, cmp.rights[0], release_operands=False
        );
        if _cres is None {
            _ok = False;
            break;
        }
        if _cres.type != i1t {
            _cres = self.builder.icmp_signed(
                "!=", _cres, ir.Constant(_cres.type, 0), name="predp.tob"
            );
        }
        _keepc = self.builder.and_(_keepc, _cres, name="predp.and");
    }
    self.builder.ret(_keepc if _ok else ir.Constant(i1t, 0));
    self._builder = _saved;
    if not _ok {
        self.emit(E5092, node_override=nd, kind="expression", name="FilterCompr");
        return None;
    }
    _pair_ty = ir.LiteralStructType([i64, i8p]);
    _pair = self.builder.alloca(_pair_ty, name="predp.pair");
    self.builder.store(
        self.builder.ptrtoint(_tf, i64, name="predp.fni"),
        self.builder.gep(
            _pair, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="predp.fnslot"
        )
    );
    self.builder.store(
        self.builder.bitcast(_env, i8p, name="predp.env8"),
        self.builder.gep(
            _pair, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="predp.envslot2"
        )
    );
    return _pair;
}

impl NaIRGenOsp._osp_type_pair(ntag: int) -> (ir.Value | None) {
    _isa_fn = self.func_symtab.get("osp_is_a");
    if _isa_fn is None {
        return None;
    }
    i1t = ir.IntType(1);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    self._osp_thunk_uid += 1;
    _tf = ir.Function(
        self.llvm_module,
        ir.FunctionType(i1t, [i64, i8p]),
        name=f"__osp_typepred.x{self._osp_thunk_uid}"
    );
    _tf.linkage = "internal";
    _saved = self._builder;
    self._builder = ir.IRBuilder(_tf.append_basic_block("entry"));
    _p = self.builder.inttoptr(_tf.args[0], i8p, name="typep.p");
    _tag = self.builder.load(
        self.builder.bitcast(
            self.builder.gep(_p, [ir.Constant(i64, 8)], name="typep.tagp"),
            i64.as_pointer(),
            name="typep.tagp64"
        ),
        name="typep.tag"
    );
    _iargs = _isa_fn.function_type.args;
    _r = self.builder.call(
        _isa_fn,
        [
            self._coerce_type(_tag, _iargs[0]),
            self._coerce_type(ir.Constant(i64, ntag), _iargs[1])
        ],
        name="typep.isa"
    );
    self.builder.ret(
        self.builder.icmp_unsigned("!=", _r, ir.Constant(_r.type, 0), name="typep.r")
    );
    self._builder = _saved;
    _pair_ty = ir.LiteralStructType([i64, i8p]);
    _pair = self.builder.alloca(_pair_ty, name="typep.pair");
    self.builder.store(
        self.builder.ptrtoint(_tf, i64, name="typep.fni"),
        self.builder.gep(
            _pair, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="typep.fnslot"
        )
    );
    self.builder.store(
        ir.Constant(i8p, None),
        self.builder.gep(
            _pair, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="typep.envslot"
        )
    );
    return _pair;
}

impl NaIRGenOsp._osp_visit_targets(target: uni.UniNode) -> (ir.Value | None) {
    if isinstance(target, uni.EdgeRefTrailer) {
        return self._codegen_edge_ref_trailer(target);
    }
    _wrap = self.func_symtab.get("osp_wrap1");
    _val = self._codegen_expr(target);
    if (_val is None) or (_wrap is None) {
        return None;
    }
    for _lt in self.list_types.values() {
        if _val.type == _lt.as_pointer() {
            return _val;
        }
    }
    _argtys = _wrap.function_type.args;
    _wrapped = self.builder.call(
        _wrap, [self._coerce_type(_val, _argtys[0])], name="osp.wrap1"
    );
    return self._mark_owned(_wrapped);
}

impl NaIRGenOsp._codegen_visit(nd: uni.VisitStmt) -> None {
    osp_visit_fn = self.func_symtab.get("osp_visit");
    if osp_visit_fn is None {
        self.emit(E5092, node_override=nd, kind="statement", name="VisitStmt");
        return;
    }
    _targets = self._osp_visit_targets(nd.target);
    if _targets is None {
        return;
    }
    i64 = ir.IntType(64);
    _insert: ir.Value = ir.Constant(i64, -1);
    if nd.insert_loc is not None {
        _il = self._codegen_expr(nd.insert_loc);
        if _il is not None {
            _insert = self._coerce_type(_il, i64);
        }
    }
    _argtys = osp_visit_fn.function_type.args;
    _did = self.builder.call(
        osp_visit_fn,
        [
            self._coerce_type(_targets, _argtys[0]),
            self._coerce_type(_insert, _argtys[1])
        ],
        name="visit.did"
    );

    if isinstance(_targets.type, ir.PointerType) and self._is_owned(_targets) {
        self._emit_rc_release_simple(
            _targets, op="visit_targets", loc=getattr(_targets, 'jac_loc', '')
        );
    }
    if nd.else_body is None {
        return;
    }
    func = self.builder.function;
    else_bb = func.append_basic_block(name="visit.else");
    merge_bb = func.append_basic_block(name="visit.end");
    self.builder.cbranch(self._to_bool(_did), merge_bb, else_bb);
    self.builder.position_at_end(else_bb);
    if isinstance(nd.else_body, uni.ElseIf) {
        self._codegen_if(nd.else_body);
    } elif isinstance(nd.else_body, uni.ElseStmt) {
        if isinstance(nd.else_body.body, (list, tuple)) {
            self._codegen_body(nd.else_body.body);
        }
    }
    if not self.builder.block.is_terminated {
        self.builder.branch(merge_bb);
    }
    self.builder.position_at_end(merge_bb);
}

impl NaIRGenOsp._codegen_disengage(nd: uni.DisengageStmt) -> None {
    osp_disengage_fn = self.func_symtab.get("osp_disengage");
    if osp_disengage_fn is None {
        self.emit(E5092, node_override=nd, kind="statement", name="DisengageStmt");
        return;
    }
    self.builder.call(osp_disengage_fn, []);

    if isinstance(self.builder.function.function_type.return_type, ir.VoidType) {
        self.builder.ret_void();
    }
}

impl NaIRGenOsp._codegen_report(nd: uni.ReportStmt) -> None {
    osp_report_fn = self.func_symtab.get("osp_report");
    if osp_report_fn is None {
        self.emit(E5092, node_override=nd, kind="statement", name="ReportStmt");
        return;
    }
    _val = self._codegen_expr(nd.expr);
    if _val is None {
        return;
    }
    _argtys = osp_report_fn.function_type.args;
    self.builder.call(osp_report_fn, [self._coerce_type(_val, _argtys[0])]);
}
