"""Object-Spatial Programming kernel lowering for the native backend
(issue #6146, Phase 4).

Native lowers `spawn` / `visit` / `disengage` / `report` into the portable
`osp_kernel.jac` instead of reimplementing traversal in LLVM. This file emits
the per-program glue the kernel needs through its `OspRuntime` seam, mirroring
the cl/ECMAScript backend (PR #6332):

  * a stable integer type-tag per OSP archetype (walker / node / edge), stored
    in an `i64 __type_tag` field on every instance (`_register_osp_tags`);
  * a `(JacVal, JacVal) -> JacVal` dispatch thunk per ability that adapts the
    raw `(self*, here*)` ability to the kernel's generic `Slot.fn`
    (`_emit_osp_thunk`);
  * the runtime tables -- a subtype `is_a` relation, the per-archetype
    `WalkerDesc` / `NodeDesc` descriptors, and an `OspRuntime` with a NoopHost
    -- built once in `__osp_setup` (`_emit_osp_setup`).

The kernel functions (`osp_spawn`, `osp_visit`, ...) are link-merged into the
program's module by the native cross-module importer, so codegen calls them
directly.
"""

"""Cache of the native-context `osp_kernel` module AST (front-end compiled,
no codegen), so the kernel is parsed/type-checked once per process even when
many OSP programs are compiled. Holds at most one element."""
glob _NA_OSP_KERNEL_MOD: list = [];

"""Write the native OSP source (portable `osp_kernel.jac` + the native-only
`osp_graph.jac` edge adjacency) into one `.na.jac` copy at `dest`. Both compile
into a single native module so the kernel's walk and the graph's adjacency link
through one transitive-source path and share one glob-init. `osp_kernel.jac`
stays pristine on disk; the `.na.jac` copy is the native-context combination."""
def _write_native_osp_source(core_dir: str, dest: str) {
    import os;
    _kernel = os.path.join(core_dir, "osp_kernel.jac");
    _graph = os.path.join(core_dir, "osp_graph.jac");
    with open(_kernel, "r") as _kf {
        _ktext = _kf.read();
    }
    with open(_graph, "r") as _gf {
        _gtext = _gf.read();
    }
    with open(dest, "w") as _out {
        _out.write(_ktext + "\n\n" + _gtext);
    }
}

"""Load (and memoize) the portable OSP kernel as a NATIVE-context module.

`osp_kernel.jac` is the single OSP source of truth (#6146); like the cl backend
(`build_osp_kernel_js`), native compiles a `.na.jac` copy so the kernel's
module-level declarations land in native context, then registers its structs /
globals / functions into the consuming program's module and links its IR. The
front-end module AST is reusable across programs; returns None on failure (the
caller falls back to leaving `spawn` on the inline path)."""
def _load_native_osp_kernel_module -> (uni.Module | None) {
    if _NA_OSP_KERNEL_MOD {
        return _NA_OSP_KERNEL_MOD[0];
    }
    import os;
    import shutil;
    import tempfile;
    import jaclang;
    import from jaclang.jac0core.program { JacProgram }
    _core = os.path.join(os.path.dirname(jaclang.__file__), "jac0core");
    tmp_dir = tempfile.mkdtemp();
    na_copy = os.path.join(tmp_dir, "osp_kernel.na.jac");
    mod = None;
    try {
        _write_native_osp_source(_core, na_copy);
        prog = JacProgram();
        mod = prog.compile(na_copy, no_cgen=True, symtab_ir_only=True);
    } except Exception {
        mod = None;
    } finally {
        shutil.rmtree(tmp_dir, ignore_errors=True);
    }
    if mod is not None {
        _NA_OSP_KERNEL_MOD.append(mod);
    }
    return mod;
}

"""Register the OSP kernel's struct types, globals, and function declarations
into this program's module so `spawn` lowering can call `osp_spawn` and
`_emit_osp_setup` can build descriptors. The kernel's function *definitions* and
glob-init are linked in by NativeCompilePass. No-op when the program has no OSP
archetypes. Reuses the cross-module import walkers so layouts/decls are built by
the same machinery as an explicit `.na.jac` import."""
impl NaIRGenPass._register_osp_kernel_module -> None {
    if not self.osp_tags {
        return;
    }
    kernel_mod = _load_native_osp_kernel_module();
    if kernel_mod is None {
        return;
    }
    self._walk_imported_module_type_names(kernel_mod);
    self._walk_imported_module_types(kernel_mod);
    self._walk_imported_module_abilities(kernel_mod);
    self._osp_kernel_mod = kernel_mod;
    # Mark the kernel as a transitive native source so the program entry emits
    # `__jac_glob_init_osp_kernel()` (initializing the kernel's `_walk_stack`)
    # and NativeCompilePass knows to compile + link the kernel's IR. The source
    # string "osp_kernel" is the safe_name both sides agree on.
    _manifest = self.ir_in.gen.interop_manifest if (self.ir_in?.gen) else None;
    if (_manifest is not None)
    and ("osp_kernel" not in _manifest.native_transitive_sources) {
        _manifest.native_transitive_sources.append("osp_kernel");
    }
}

"""Assign a stable int type-tag to every walker/node/edge archetype, but only
when the program actually participates in OSP (some walker/node/edge declares an
event ability `can ... with T entry/exit`). Edges referenced only in
connects/refs still get a tag so dispatch over them is uniform. Tags index the
instance `__type_tag` field, the is_a table, and the descriptor table.
"""
impl NaIRGenPass._register_osp_tags(archetypes: list[uni.Archetype]) -> None {
    osp_arches: list[uni.Archetype] = [];
    has_osp = False;
    for arch in archetypes {
        kind = arch.arch_kind;
        if kind is None {
            continue;
        }
        osp_arches.append(arch);
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability)
                and isinstance(stmt.signature, uni.EventSignature) {
                    has_osp = True;
                }
            }
        }
    }
    if not has_osp {
        return;
    }
    for arch in osp_arches {
        name = arch.name.value if arch.name else None;
        if (name is not None) and (name not in self.osp_tags) {
            self.osp_arch_kind[name] = arch.arch_kind;
            self.osp_tags[name] = len(self.osp_tags);
        }
    }
}

"""Emit a `(JacVal, JacVal) -> JacVal` dispatch thunk for an OSP ability so it
can be stored in a kernel `Slot.fn`. The kernel invokes `slot.fn(a, b)` with two
boxed `any` handles; the thunk unboxes them to the ability's real parameter
pointer types, calls the ability, and returns a zeroed JacVal (the kernel
discards the result). The raw ability `f"{arch}.{name}"` must already be
forward-declared. Idempotent.
"""
impl NaIRGenPass._emit_osp_thunk(arch_name: str, method: uni.Ability) -> None {
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
    thunk = ir.Function(
        self.llvm_module, ir.FunctionType(jv, [jv, jv]), name=f"{full}.__ospthunk"
    );
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

"""Flatten an OSP ability trigger (`with <T> entry`) into archetype names.
None -> [] (untyped); a tuple/union -> each member; a plain type -> [name]."""
impl NaIRGenPass._osp_trigger_names(nd: (uni.UniNode | None)) -> list[str] {
    if nd is None {
        return [];
    }
    names: list[str] = [];
    if isinstance(nd, uni.TupleVal) {
        for member in nd.values {
            names.extend(self._osp_trigger_names(member));
        }
        return names;
    }
    head = self._get_name(nd);
    if head is not None {
        names.append(head);
    }
    return names;
}

# ───────────────────────────── descriptor / runtime setup ──────────────────
# `_emit_osp_setup` emits a `__osp_setup()` function (called from the program's
# glob-init) that builds the per-archetype `WalkerDesc`/`NodeDesc` descriptors
# and the `OspRuntime` the kernel dispatches through. Per-program data (tags,
# slot->thunk bindings, the subtype table) is materialized here; the kernel
# stays generic. Layouts (verified): Slot{i64 trig_tag, fn}, Walker/NodeDesc
# {i64 type_tag, List.ptr* entry, List.ptr* exit}, OspRuntime{tag_of,is_a,
# node_desc,on_complete fn-ptrs}.
"""rc_alloc a kernel struct by name and return the typed pointer (or None).
Descriptors/runtime are program-lifetime singletons: their refcount stays at 1
(never released), so they persist -- a deliberate, bounded one-time alloc."""
impl NaIRGenPass._osp_rc_new(struct_name: str) -> (ir.Value | None) {
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
    _raw = self._rc_call_with_ctx(
        self.rc_alloc_fn, [_sz], op="osp", loc="", name="osp.raw"
    );
    self._osp_make_immortal(_raw);
    return self.builder.bitcast(_raw, sptr, name=f"osp.{struct_name}");
}

"""Pin an rc_alloc'd block's refcount to the immortal sentinel so the kernel's
ordinary retain/release on a borrowed descriptor/runtime singleton can never
free it mid-walk (matches the cl/sv backends where descriptors are GC-rooted).
`ptr` is the user pointer (refcount lives at HDR_RC_OFF). See #6146."""
impl NaIRGenPass._osp_make_immortal(ptr: ir.Value) -> None {
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

"""Tags an OSP archetype `is-a`: itself plus every OSP ancestor in its MRO."""
impl NaIRGenPass._osp_isa_bases(arch_name: str) -> list[int] {
    bases: list[int] = [];
    _self_tag = self.osp_tags.get(arch_name);
    if _self_tag is not None {
        bases.append(_self_tag);
    }
    for anc in self.mro_order.get(arch_name, [arch_name]) {
        if (anc != arch_name) and (anc in self.osp_tags) {
            bases.append(self.osp_tags[anc]);
        }
    }
    return bases;
}

"""Collect (trig_tag, thunk) dispatch slots for an archetype's entry (or exit)
abilities. Untyped `with entry` -> trig_tag UNTYPED (-1); a typed/tuple trigger
-> one slot per matched type tag."""
impl NaIRGenPass._osp_collect_slots(arch_name: str, is_entry: bool) -> list {
    slots: list = [];
    arch = self.arch_ast_map.get(arch_name);
    if (not isinstance(arch, uni.Archetype)) or (arch.body is None) {
        return slots;
    }
    for stmt in arch.body {
        if (not isinstance(stmt, uni.Ability))
        or (not isinstance(stmt.signature, uni.EventSignature)) {
            continue;
        }
        ev = stmt.signature;
        if (ev.event.name == Tok.KW_ENTRY) != is_entry {
            continue;
        }
        mname = stmt.name_ref.sym_name if stmt.name_ref else None;
        thunk = self.osp_thunk_funcs.get(f"{arch_name}.{mname}")
            if mname is not None
            else None;
        if thunk is None {
            continue;
        }
        # Prefer the checker-resolved trigger types; fall back to flattening
        # the trigger AST when no resolution was recorded.
        trigs = self._event_trigger_type_names(stmt);
        if trigs is None {
            trigs = self._osp_trigger_names(ev.arch_tag_info)
                if ev.arch_tag_info is not None
                else [];
        }
        if not trigs {
            slots.append((-1, thunk));
        } else {
            for tname in trigs {
                slots.append((self.osp_tags.get(tname, -1), thunk));
            }
        }
    }
    return slots;
}

"""Build a `Slot{trig_tag, fn=thunk}` instance, returning its pointer."""
impl NaIRGenPass._osp_build_slot(
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

"""Build a `List.ptr` of Slot pointers from a list of (trig_tag, thunk)."""
impl NaIRGenPass._osp_build_slot_list(pairs: list) -> ir.Value {
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
    # Immortal AFTER appends (any growth realloc'd the data array first), so the
    # kernel's borrowed reads of wdesc/ndesc.entry never free this descriptor
    # list or its backing array mid-walk.
    self._osp_make_immortal(_lst);
    return _lst;
}

"""Build a `WalkerDesc`/`NodeDesc{type_tag, entry, exit}` instance."""
impl NaIRGenPass._osp_build_descriptor(
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

"""Emit the four `OspRuntime` callbacks as native functions whose signatures
match the kernel's `OspRuntime` field types. Returns a dict of the emitted
ir.Functions keyed by field name. `isa_global` is the `[n*n x i8]` subtype
table; node_desc reads `self._osp_desc_global`."""
impl NaIRGenPass._osp_emit_callbacks(isa_global: ir.GlobalVariable, n: int) -> dict {
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    _fields = self.struct_field_types.get("OspRuntime", {});
    _saved = self._builder;
    out: dict = {};
    # tag_of(JacVal h) -> i64: read the instance __type_tag at byte offset 8
    # (field 0 is the reserved vtable slot, field 1 is the i64 __type_tag).
    _tf = ir.Function(self.llvm_module, _fields["tag_of"].pointee, name="__osp_tag_of");
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
    # is_a(i64 t, i64 b) -> i1: lookup isa_global[t*n + b] != 0
    _iaf = ir.Function(self.llvm_module, _fields["is_a"].pointee, name="__osp_is_a");
    self._builder = ir.IRBuilder(_iaf.append_basic_block("entry"));
    _ix = self.builder.add(
        self.builder.mul(_iaf.args[0], ir.Constant(i64, n), name="isa.row"),
        _iaf.args[1],
        name="isa.idx"
    );
    _v = self.builder.load(
        self.builder.gep(isa_global, [ir.Constant(i32, 0), _ix], name="isa.slot"),
        name="isa.v"
    );
    self.builder.ret(
        self.builder.icmp_unsigned("!=", _v, ir.Constant(i8, 0), name="isa.r")
    );
    out["is_a"] = _iaf;
    # node_desc(i64 tag) -> NodeDesc*: load __ospDESC[tag], bitcast.
    _ndf = ir.Function(
        self.llvm_module, _fields["node_desc"].pointee, name="__osp_node_desc"
    );
    self._builder = ir.IRBuilder(_ndf.append_basic_block("entry"));
    _dp = self.builder.load(
        self.builder.gep(
            self._osp_desc_global, [ir.Constant(i32, 0), _ndf.args[0]], name="nd.slot"
        ),
        name="nd.i8"
    );
    self.builder.ret(
        self.builder.bitcast(_dp, self.struct_types["NodeDesc"].as_pointer(), name="nd")
    );
    out["node_desc"] = _ndf;
    # on_complete(WalkScope*, i1): deliver the walk's collected reports onto the
    # walker so `w.reports` reads them back -- mirrors cl/sv `scope.wlk.reports =
    # scope.reports`. The walker's `reports` field is at the uniform byte offset
    # 16 (vtable@0, __type_tag@1, reports@2). scope.reports is pinned immortal so
    # the scope teardown can't free the list now owned by the (immortal) walker.
    _ocf = ir.Function(
        self.llvm_module, _fields["on_complete"].pointee, name="__osp_on_complete"
    );
    self._builder = ir.IRBuilder(_ocf.append_basic_block("entry"));
    _ws_idx = self.struct_field_indices.get("WalkScope", {});
    _li64 = self.list_types.get("i64");
    if _li64 is not None {
        _scope = _ocf.args[0];
        # walker = unbox(scope.wlk): a boxed `any` handle -> instance pointer.
        _wlk_jv = self.builder.load(
            self.builder.gep(
                _scope,
                [ir.Constant(i32, 0), ir.Constant(i32, _ws_idx.get("wlk", 0))],
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
                [ir.Constant(i32, 0), ir.Constant(i32, _ws_idx.get("reports", 4))],
                name="oc.rep.p"
            ),
            name="oc.rep"
        );
        self._osp_make_immortal(_rep);
        self.builder.store(
            _rep,
            self.builder.bitcast(
                self.builder.gep(_wlk_i8, [ir.Constant(i64, 16)], name="oc.repslot.i8"),
                _li64.as_pointer().as_pointer(),
                name="oc.repslot"
            )
        );
    }
    self.builder.ret_void();
    out["on_complete"] = _ocf;
    self._builder = _saved;
    return out;
}

"""Emit `__osp_setup()` -- builds the subtype table, per-archetype descriptors,
and the `OspRuntime` singleton, all reachable from program globals. Called from
the program's glob-init. No-op for non-OSP programs."""
impl NaIRGenPass._emit_osp_setup -> None {
    if not self.osp_tags {
        return;
    }
    # Requires the kernel's descriptor structs to be registered (which only
    # happens when osp_kernel.jac compiles to native IR). When it does not --
    # e.g. blocked by an open native-codegen gap -- skip setup; `spawn` lowering
    # then falls back to the inline entry-dispatch stopgap. See the native-OSP
    # gaps issue.
    for _req in ["Slot", "WalkerDesc", "NodeDesc", "OspRuntime"] {
        if _req not in self.struct_types {
            return;
        }
    }
    n = len(self.osp_tags);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i8p = i8.as_pointer();
    # __ospDESC: [n x i8*] descriptor table, populated at setup time.
    _desc_ty = ir.ArrayType(i8p, n);
    self._osp_desc_global = ir.GlobalVariable(
        self.llvm_module, _desc_ty, name="__ospDESC"
    );
    self._osp_desc_global.linkage = "internal";
    self._osp_desc_global.initializer = ir.Constant(_desc_ty, None);
    # __ospISA: [n*n x i8] subtype table, constant.
    _isa_vals: list = [];
    for _i in range(n * n) {
        _isa_vals.append(0);
    }
    for (_name, _t) in self.osp_tags.items() {
        for _b in self._osp_isa_bases(_name) {
            _isa_vals[_t * n + _b] = 1;
        }
    }
    _isa_ty = ir.ArrayType(i8, n * n);
    _isa_global = ir.GlobalVariable(self.llvm_module, _isa_ty, name="__ospISA");
    _isa_global.linkage = "internal";
    _isa_global.global_constant = True;
    _isa_global.initializer = ir.Constant(
        _isa_ty, [ir.Constant(i8, _v) for _v in _isa_vals]
    );
    # __ospRT: OspRuntime*, populated at setup time.
    _rt_ty = self.struct_types["OspRuntime"].as_pointer();
    self._osp_rt_global = ir.GlobalVariable(self.llvm_module, _rt_ty, name="__ospRT");
    self._osp_rt_global.linkage = "internal";
    self._osp_rt_global.initializer = ir.Constant(_rt_ty, None);
    _cbs = self._osp_emit_callbacks(_isa_global, n);
    # __osp_setup(): build descriptors + runtime.
    _setup = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), []), name="__osp_setup"
    );
    self._osp_setup_fn = _setup;
    _saved = self._builder;
    self._builder = ir.IRBuilder(_setup.append_basic_block("entry"));
    for (_name, _tag) in self.osp_tags.items() {
        _sn = "WalkerDesc"
            if (self.osp_arch_kind.get(_name) == "walker")
            else "NodeDesc";
        _desc = self._osp_build_descriptor(
            _sn,
            _tag,
            self._osp_collect_slots(_name, True),
            self._osp_collect_slots(_name, False)
        );
        if _desc is not None {
            self.builder.store(
                self.builder.bitcast(_desc, i8p, name="osp.desc.i8"),
                self.builder.gep(
                    self._osp_desc_global,
                    [ir.Constant(i32, 0), ir.Constant(i32, _tag)],
                    name="osp.descslot"
                )
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
    # __osp_ensure_init(): idempotent guard that runs the kernel's glob-init
    # (initializes `_walk_stack`) then __osp_setup once. Spawn lowering calls it,
    # so OSP works whether the program is entered via `with entry` or a library
    # call (the test harness invokes functions directly).
    _inited = ir.GlobalVariable(self.llvm_module, i8, name="__osp_inited");
    _inited.linkage = "internal";
    _inited.initializer = ir.Constant(i8, 0);
    _kgi = self.func_symtab.get("__jac_glob_init_osp_kernel");
    if _kgi is None {
        _kgi = ir.Function(
            self.llvm_module,
            ir.FunctionType(ir.VoidType(), []),
            name="__jac_glob_init_osp_kernel"
        );
        self.func_symtab["__jac_glob_init_osp_kernel"] = _kgi;
    }
    _ensure = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), []), name="__osp_ensure_init"
    );
    self._osp_ensure_fn = _ensure;
    _e_entry = _ensure.append_basic_block("entry");
    _e_run = _ensure.append_basic_block("run");
    _e_done = _ensure.append_basic_block("done");
    _eb = ir.IRBuilder(_e_entry);
    _eb.cbranch(
        _eb.icmp_unsigned(
            "!=", _eb.load(_inited, name="osp.inited"), ir.Constant(i8, 0)
        ),
        _e_done,
        _e_run
    );
    _rb = ir.IRBuilder(_e_run);
    _rb.store(ir.Constant(i8, 1), _inited);
    _rb.call(_kgi, []);
    _rb.call(_setup, []);
    _rb.branch(_e_done);
    ir.IRBuilder(_e_done).ret_void();
    self._builder = _saved;
}

# ───────────────────────────── traversal lowering ──────────────────────────
# `visit` / `disengage` / `report` lower to the kernel's `osp_visit` /
# `osp_disengage` / `osp_report`; edge connect (`++>`) and refs (`[-->]`) lower
# to the native adjacency (`osp_conn` / `osp_refs`, osp_graph.jac). All four
# kernel/graph functions are link-merged into the program module and registered
# in `func_symtab`, so codegen calls them directly -- mirroring spawn (#6146).
"""rc_alloc a unique, immortal handle for an untyped `++>` edge. The adjacency
keys edges by handle; a generic edge carries no user fields, so an 8-byte block
is enough to give it identity. Immortal because the handle is stored raw (not
RC-tracked) in the graph arena."""
impl NaIRGenPass._osp_generic_edge -> (ir.Value | None) {
    if self.rc_alloc_fn is None {
        return None;
    }
    i64 = ir.IntType(64);
    _raw = self._rc_call_with_ctx(
        self.rc_alloc_fn, [ir.Constant(i64, 8)], op="osp", loc="", name="osp.gedge"
    );
    self._osp_make_immortal(_raw);
    return _raw;
}

"""Lower an edge connect `a ++> b` / `a +>: Edge() :+> b` to `osp_conn`.

Records the directed pair in the native adjacency keyed by `ptrtoint` handles.
IN edges swap operands; ANY edges are flagged undirected. A typed edge codegens
its constructor (and passes the edge archetype's tag for `[->:Edge:->]`
filtering); an untyped edge gets a fresh generic handle. Returns the target
operand value so the connect expression yields its right side (chaining)."""
impl NaIRGenPass._codegen_connect(nd: uni.BinaryExpr) -> (ir.Value | None) {
    co = nd.op;
    osp_conn_fn = self.func_symtab.get("osp_conn");
    if osp_conn_fn is None {
        self.emit(E5090, node_override=nd, kind="binary operator", name="ConnectOp");
        return None;
    }
    # A connect can be the program's first OSP op (before any spawn), so the
    # graph adjacency globals (`_e_src`, ...) must be initialized here -- the
    # kernel/graph glob-init runs lazily via __osp_ensure_init (idempotent).
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
        edge_obj = self._codegen_expr(co.conn_type);
        _etname = self._spawn_operand_name(co.conn_type);
        if _etname is not None {
            edge_tag = self.osp_tags.get(_etname, -1);
        }
    } else {
        edge_obj = self._osp_generic_edge();
    }
    if edge_obj is None {
        return tgt;
    }
    # The edge handle lives raw (ptrtoint) in the adjacency arena, not as an RC
    # reference, so pin the edge object immortal -- otherwise RC could free a
    # typed edge at end of statement while the graph still references it.
    self._osp_make_immortal(edge_obj);
    _argtys = osp_conn_fn.function_type.args;
    self.builder.call(
        osp_conn_fn,
        [
            self._coerce_type(src, _argtys[0]),
            self._coerce_type(tgt, _argtys[1]),
            self._coerce_type(edge_obj, _argtys[2]),
            self._coerce_type(ir.Constant(i64, undirected), _argtys[3]),
            self._coerce_type(ir.Constant(i64, edge_tag), _argtys[4])
        ]
    );
    return tgt;
}

"""Lower an edge reference `[-->]` / `[->:Edge:->]` to `osp_refs(here, dir,
edge_tag, edges_only)`, returning a `list` of neighbor (or edge) handles in the
kernel's list representation -- ready to hand to `osp_visit`. The origin of a
bare ref is the walker's current location `here`."""
impl NaIRGenPass._codegen_edge_ref_trailer(
    nd: uni.EdgeRefTrailer
) -> (ir.Value | None) {
    osp_refs_fn = self.func_symtab.get("osp_refs");
    # Only the single-step form (`[-->]` / `[->:Edge:->]`, one EdgeOpRef) is
    # lowered -- the same shape the cl backend handles. A multi-element chain
    # (multi-hop / trailing filter comprehension) must fail loudly rather than
    # silently traversing on just the first step.
    if (osp_refs_fn is None) or (len(nd.chain) != 1) {
        self.emit(E5090, node_override=nd, kind="expression", name="EdgeRefTrailer");
        return None;
    }
    step = nd.chain[0];
    _here = self.local_vars.get("here");
    if (not isinstance(step, uni.EdgeOpRef)) or (_here is None) {
        self.emit(E5090, node_override=nd, kind="expression", name="EdgeRefTrailer");
        return None;
    }
    i64 = ir.IntType(64);
    origin_ptr = self.builder.load(_here, name="here");
    _dir = int(step.edge_dir.value);
    _edge_tag = -1;
    _fcond = step.filter_cond;
    if (_fcond is not None) and (_fcond.f_type is not None) {
        _etname = self._get_name(_fcond.f_type);
        if _etname is not None {
            _edge_tag = self.osp_tags.get(_etname, -1);
        }
    }
    _edges_only = 1 if nd.edges_only else 0;
    _argtys = osp_refs_fn.function_type.args;
    return self.builder.call(
        osp_refs_fn,
        [
            self._coerce_type(origin_ptr, _argtys[0]),
            self._coerce_type(ir.Constant(i64, _dir), _argtys[1]),
            self._coerce_type(ir.Constant(i64, _edge_tag), _argtys[2]),
            self._coerce_type(ir.Constant(i64, _edges_only), _argtys[3])
        ],
        name="osp.refs"
    );
}

"""Resolve a `visit` target to the kernel's `list` representation. An edge-ref
target already yields that list; a bare location is wrapped via `osp_wrap1`."""
impl NaIRGenPass._osp_visit_targets(target: uni.UniNode) -> (ir.Value | None) {
    if isinstance(target, uni.EdgeRefTrailer) {
        return self._codegen_edge_ref_trailer(target);
    }
    _wrap = self.func_symtab.get("osp_wrap1");
    _val = self._codegen_expr(target);
    if (_val is None) or (_wrap is None) {
        return None;
    }
    _argtys = _wrap.function_type.args;
    return self.builder.call(
        _wrap, [self._coerce_type(_val, _argtys[0])], name="osp.wrap1"
    );
}

"""Lower `visit <targets> [else ...]` to `osp_visit(targets, insert_loc)`.
The kernel enqueues the (ignore-filtered) targets into the current walk scope's
`next` queue at `insert_loc` (default -1 = append) and returns whether anything
was enqueued; a `visit ... else { ... }` runs the else body when nothing was
(mirroring the py lowering `if not visit(...): else_body`)."""
impl NaIRGenPass._codegen_visit(nd: uni.VisitStmt) -> None {
    osp_visit_fn = self.func_symtab.get("osp_visit");
    if osp_visit_fn is None {
        self.emit(E5090, node_override=nd, kind="statement", name="VisitStmt");
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

"""Lower `disengage` to `osp_disengage()` -- flags the current walk scope so the
kernel halts the walk, then returns from the ability. The py lowering emits a
bare `return` after the call (statements after `disengage` never run), so native
must terminate too or side effects after `disengage` would diverge silently."""
impl NaIRGenPass._codegen_disengage(nd: uni.DisengageStmt) -> None {
    osp_disengage_fn = self.func_symtab.get("osp_disengage");
    if osp_disengage_fn is None {
        self.emit(E5090, node_override=nd, kind="statement", name="DisengageStmt");
        return;
    }
    self.builder.call(osp_disengage_fn, []);
    # disengage is walker-ability-only (event abilities return void); subsequent
    # statements in the block are skipped by the is_terminated check.
    if isinstance(self.builder.function.function_type.return_type, ir.VoidType) {
        self.builder.ret_void();
    }
}

"""Lower `report <expr>` to `osp_report(box(expr))` -- appends the boxed value
to the current walk scope's `reports`, delivered at the spawn boundary."""
impl NaIRGenPass._codegen_report(nd: uni.ReportStmt) -> None {
    osp_report_fn = self.func_symtab.get("osp_report");
    if osp_report_fn is None {
        self.emit(E5090, node_override=nd, kind="statement", name="ReportStmt");
        return;
    }
    _val = self._codegen_expr(nd.expr);
    if _val is None {
        return;
    }
    _argtys = osp_report_fn.function_type.args;
    self.builder.call(osp_report_fn, [self._coerce_type(_val, _argtys[0])]);
}
