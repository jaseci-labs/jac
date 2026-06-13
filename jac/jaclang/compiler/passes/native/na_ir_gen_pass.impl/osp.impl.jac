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

"""Deterministic 64-bit FNV-1a hash of an archetype name, masked to a
non-negative i64 (so it is never the -1 UNTYPED / generic-edge sentinel).
Computed identically in every module, so a shared OSP archetype gets the SAME
tag in the library that defines it and in any module that imports it (#6642)."""
impl NaIRGenPass._stable_osp_tag(name: str) -> int {
    _h = 14695981039346656037;
    for _c in name {
        _h = ((_h ^ ord(_c)) * 1099511628211) & 18446744073709551615;
    }
    return _h & 9223372036854775807;
}

"""Assign a stable int type-tag to every walker/node/edge archetype, but only
when the program actually participates in OSP: some walker/node/edge declares
an event ability (`can ... with T entry/exit`) OR the module's native code uses
an OSP construct (connect / spawn / visit / edge ref). Keying on usage rather
than walker presence keeps a graph-builder module that only WIRES nodes
(defining no walker) on the kernel path instead of E5090 (issue #6636), while a
module that merely declares archetypes it never wires/walks still skips the
kernel.

The tag itself is a GLOBALLY STABLE content hash of the archetype name (unique
within a program by symbol resolution), so a library and any module that imports
it independently compute the IDENTICAL tag regardless of what else either
defines -- the cross-module materialization #6642 needs, without recompiling
library code (which would collide at link, E5026) and without the fragility of
position-based numbering. `osp_tags[name]` is that stable tag, stored in the
instance `__type_tag` field, in adjacency edge tags, and in dispatch-slot
triggers. `osp_local_idx[name]` is the dense per-compile index into THIS
module's descriptor + is_a tables; the runtime callbacks translate a stable tag
to a local index through the `__ospHASH` table (see `_emit_osp_setup`)."""
impl NaIRGenPass._register_osp_tags(archetypes: list[uni.Archetype]) -> None {
    has_osp = False;
    for arch in archetypes {
        if arch.arch_kind is None {
            continue;
        }
        name = arch.name.value if arch.name else None;
        if name is not None {
            self.osp_arch_kind[name] = arch.arch_kind;
            self.arch_ast_map[name] = arch;
        }
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability)
                and isinstance(stmt.signature, uni.EventSignature) {
                    has_osp = True;
                }
            }
        }
    }
    # `osp_arch_kind` already carries any imported OSP archetypes registered by
    # `_register_imported_osp_archetypes`; if the module uses OSP at all, tag
    # the whole set with globally-stable hashes.
    if (not has_osp) and self.osp_arch_kind {
        has_osp = self._module_uses_osp(self.ir_in);
    }
    if not has_osp {
        return;
    }
    _by_tag: dict[int, str] = {};
    for name in sorted(self.osp_arch_kind.keys()) {
        if name in self.osp_tags {
            continue;
        }
        _tag = self._stable_osp_tag(name);
        if _tag in _by_tag {
            # Astronomically rare 64-bit hash collision between two distinct
            # archetype names -- fail loudly rather than silently mis-dispatch.
            self.emit(
                E5090,
                node_override=self.arch_ast_map.get(name),
                kind="archetype",
                name=f"{name} (OSP type-tag hash collides with '{_by_tag[_tag]}')"
            );
            continue;
        }
        _by_tag[_tag] = name;
        self.osp_tags[name] = _tag;
        self.osp_local_idx[name] = len(self.osp_local_idx);
    }
}

"""Register OSP archetypes IMPORTED from other native modules into
`osp_arch_kind` / `arch_ast_map` so their struct layout reserves the OSP header
fields (vtable + `__type_tag`) to MATCH the defining module, and so
`_register_osp_tags` gives them their globally-stable tag. Only when the
importing module actually uses OSP -- a module that merely constructs an
imported archetype (no spawn/connect/visit) keeps the plain layout and never
loads the kernel (issue #6642 Blocker 2). Must run before imported struct bodies
are filled (`_codegen_archetype` reads `osp_arch_kind` for the layout)."""
impl NaIRGenPass._register_imported_osp_archetypes(imported_mod: uni.Module) -> None {
    if not self._module_uses_osp(self.ir_in) {
        return;
    }
    for stmt in ModuleCodegenPass.iter_context_stmts(imported_mod) {
        if (
            isinstance(stmt, uni.ContextAwareNode)
            and stmt.code_context == CodeContext.CLIENT
        ) {
            continue;
        }
        if isinstance(stmt, uni.Archetype) and (stmt.arch_kind is not None) {
            _name = stmt.name.value if stmt.name else None;
            if (_name is not None) and (_name not in self.osp_arch_kind) {
                self.osp_arch_kind[_name] = stmt.arch_kind;
                self.arch_ast_map[_name] = stmt;
            }
        }
    }
}

"""True when the module's native code USES an OSP construct — an edge connect
(`++>`), a `spawn`, a `visit`, or an edge ref (`[-->]`) — anywhere in its
native-context statements. Distinct from declaring OSP archetypes: usage is
what requires the kernel + adjacency at runtime. Same work-stack sweep idiom
as `native_capability_violations`."""
impl NaIRGenPass._module_uses_osp(module: uni.Module) -> bool {
    for stmt in ModuleCodegenPass.iter_context_stmts(module, CodeContext.NATIVE) {
        work: list = [stmt];
        while work {
            nd = work.pop();
            if isinstance(nd, (uni.ConnectOp, uni.VisitStmt, uni.EdgeOpRef)) {
                return True;
            }
            if isinstance(nd, uni.BinaryExpr)
            and isinstance(nd.op, uni.Token)
            and (nd.op.name == Tok.KW_SPAWN) {
                return True;
            }
            for k in nd.kid {
                work.append(k);
            }
        }
    }
    return False;
}

"""Cross-module OSP E5090 help: when one of `names` resolves to an OSP
archetype imported from another native module that was NOT materialized into
this compile, return help text naming the defining module. Globally-stable hash
tags now materialize imported OSP archetypes in any configuration, so this is a
defensive fallback (e.g. an OSP archetype the consumer imports but its module
was not available as native source). None when no name matches, so callers fall
back to the generic E5090 (issue #6642)."""
impl NaIRGenPass._xmod_osp_help(names: list) -> (str | None) {
    for _n in names {
        if (
            (_n is not None)
            and (_n not in self.osp_tags)
            and (_n in self.imported_osp_archs)
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
    # An IMPORTED walker already carries its own `__ospthunk` in the library's
    # linked IR; the consumer needs a thunk wired into ITS descriptor table, so
    # emit a link-private copy under a unique internal name (calling the
    # library-linked ability body) rather than redefining the shared symbol,
    # which would collide at link (E5026). Issue #6642 Blocker 2.
    _thunk_name = f"{full}.__ospthunk";
    _imported = arch_name in self.imported_osp_archs;
    if _imported {
        _thunk_name = f"{_thunk_name}.x{self._osp_thunk_uid}";
        self._osp_thunk_uid += 1;
    }
    thunk = ir.Function(
        self.llvm_module, ir.FunctionType(jv, [jv, jv]), name=_thunk_name
    );
    if _imported {
        thunk.linkage = "internal";
    }
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

"""LOCAL indices an OSP archetype `is-a`: itself plus every OSP ancestor in its
MRO. These index the dense `__ospISA` subtype matrix, so they are local indices
(`osp_local_idx`), not the globally-stable hash tags."""
impl NaIRGenPass._osp_isa_bases(arch_name: str) -> list[int] {
    bases: list[int] = [];
    _self_idx = self.osp_local_idx.get(arch_name);
    if _self_idx is not None {
        bases.append(_self_idx);
    }
    for anc in self._mro_of(arch_name) {
        if (anc != arch_name) and (anc in self.osp_local_idx) {
            bases.append(self.osp_local_idx[anc]);
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
        trigs = stmt.event_trigger_type_names();
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

"""Emit `__osp_h2i(stable_tag) -> i64`: linear-scan `__ospHASH` for the local
table index whose entry equals `stable_tag`, returning it (or -1 if absent).
This is the seam that lets the globally-stable hash tags stored in instances /
edges / dispatch slots reach this module's dense, per-compile descriptor + is_a
tables, so cross-module dispatch agrees (issue #6642). `n` is small (the OSP
archetype count), so the scan is cheap and off the walk's hot path."""
impl NaIRGenPass._osp_emit_h2i_fn(
    hash_global: ir.GlobalVariable, n: int
) -> ir.Function {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    fn = ir.Function(self.llvm_module, ir.FunctionType(i64, [i64]), name="__osp_h2i");
    fn.linkage = "internal";
    fn.args[0].name = "tag";
    _saved = self._builder;
    _entry = fn.append_basic_block("entry");
    _loop = fn.append_basic_block("loop");
    _chk = fn.append_basic_block("chk");
    _found = fn.append_basic_block("found");
    _nf = fn.append_basic_block("nf");
    self._builder = ir.IRBuilder(_entry);
    self.builder.branch(_loop);
    self._builder = ir.IRBuilder(_loop);
    _i = self.builder.phi(i64, name="h2i.i");
    _i.add_incoming(ir.Constant(i64, 0), _entry);
    self.builder.cbranch(
        self.builder.icmp_unsigned(">=", _i, ir.Constant(i64, n), name="h2i.atend"),
        _nf,
        _chk
    );
    self._builder = ir.IRBuilder(_chk);
    _hv = self.builder.load(
        self.builder.gep(hash_global, [ir.Constant(i32, 0), _i], name="h2i.slot"),
        name="h2i.hv"
    );
    _i1 = self.builder.add(_i, ir.Constant(i64, 1), name="h2i.i1");
    _i.add_incoming(_i1, _chk);
    self.builder.cbranch(
        self.builder.icmp_unsigned("==", _hv, fn.args[0], name="h2i.eq"), _found, _loop
    );
    self._builder = ir.IRBuilder(_found);
    self.builder.ret(_i);
    self._builder = ir.IRBuilder(_nf);
    self.builder.ret(ir.Constant(i64, -1));
    self._builder = _saved;
    return fn;
}

"""Emit the four `OspRuntime` callbacks as native functions whose signatures
match the kernel's `OspRuntime` field types. Returns a dict of the emitted
ir.Functions keyed by field name. `isa_global` is the `[n*n x i8]` subtype
matrix over LOCAL indices; `is_a` / `node_desc` translate their stable-tag
arguments to local indices through `__osp_h2i`. node_desc reads
`self._osp_desc_global`."""
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
    # is_a(i64 t, i64 b) -> i1: translate stable tags t,b to local indices via
    # __osp_h2i, then lookup isa_global[ti*n + bi] != 0. Either tag unknown
    # (h2i -1) -> not is-a.
    _iaf = ir.Function(self.llvm_module, _fields["is_a"].pointee, name="__osp_is_a");
    _iaf.linkage = "internal";
    _ia_entry = _iaf.append_basic_block("entry");
    _ia_ok = _iaf.append_basic_block("ok");
    _ia_no = _iaf.append_basic_block("no");
    self._builder = ir.IRBuilder(_ia_entry);
    _ti = self.builder.call(self._osp_h2i_fn, [_iaf.args[0]], name="isa.ti");
    _bi = self.builder.call(self._osp_h2i_fn, [_iaf.args[1]], name="isa.bi");
    _ia_bad = self.builder.or_(
        self.builder.icmp_signed("<", _ti, ir.Constant(i64, 0), name="isa.tbad"),
        self.builder.icmp_signed("<", _bi, ir.Constant(i64, 0), name="isa.bbad"),
        name="isa.bad"
    );
    self.builder.cbranch(_ia_bad, _ia_no, _ia_ok);
    self._builder = ir.IRBuilder(_ia_ok);
    _ix = self.builder.add(
        self.builder.mul(_ti, ir.Constant(i64, n), name="isa.row"), _bi, name="isa.idx"
    );
    _v = self.builder.load(
        self.builder.gep(isa_global, [ir.Constant(i32, 0), _ix], name="isa.slot"),
        name="isa.v"
    );
    self.builder.ret(
        self.builder.icmp_unsigned("!=", _v, ir.Constant(i8, 0), name="isa.r")
    );
    self._builder = ir.IRBuilder(_ia_no);
    self.builder.ret(ir.Constant(ir.IntType(1), 0));
    out["is_a"] = _iaf;
    self._osp_is_a_fn = _iaf;
    # node_desc(i64 tag) -> NodeDesc*: translate stable tag to local index via
    # __osp_h2i, then load __ospDESC[idx]. Unknown tag -> null descriptor.
    _ndf = ir.Function(
        self.llvm_module, _fields["node_desc"].pointee, name="__osp_node_desc"
    );
    _ndf.linkage = "internal";
    _nd_entry = _ndf.append_basic_block("entry");
    _nd_ok = _ndf.append_basic_block("ok");
    _nd_no = _ndf.append_basic_block("no");
    _nd_ty = self.struct_types["NodeDesc"].as_pointer();
    self._builder = ir.IRBuilder(_nd_entry);
    _nd_idx = self.builder.call(self._osp_h2i_fn, [_ndf.args[0]], name="nd.idx");
    self.builder.cbranch(
        self.builder.icmp_signed("<", _nd_idx, ir.Constant(i64, 0), name="nd.bad"),
        _nd_no,
        _nd_ok
    );
    self._builder = ir.IRBuilder(_nd_ok);
    _dp = self.builder.load(
        self.builder.gep(
            self._osp_desc_global, [ir.Constant(i32, 0), _nd_idx], name="nd.slot"
        ),
        name="nd.i8"
    );
    self.builder.ret(self.builder.bitcast(_dp, _nd_ty, name="nd"));
    self._builder = ir.IRBuilder(_nd_no);
    self.builder.ret(ir.Constant(_nd_ty, None));
    out["node_desc"] = _ndf;
    # on_complete(WalkScope*, i1): deliver the walk's collected reports onto the
    # walker so `w.reports` reads them back -- mirrors cl/sv `scope.wlk.reports =
    # scope.reports`. The walker's `reports` field is at the uniform byte offset
    # 16 (vtable@0, __type_tag@1, reports@2). scope.reports is pinned immortal so
    # the scope teardown can't free the list now owned by the (immortal) walker.
    _ocf = ir.Function(
        self.llvm_module, _fields["on_complete"].pointee, name="__osp_on_complete"
    );
    _ocf.linkage = "internal";
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

"""Emit `__osp_filter_type(list, node_tag) -> list`: keep only the handles in
`list` whose instance type `is_a` `node_tag`, the lowering of a trailing node
filter on an edge ref (`[--> [?:Area]]`). Reads each handle's `__type_tag` at
the uniform byte offset 8 (vtable@0, tag@1) and calls the emitted `__osp_is_a`
(which translates the stable tags through `__ospHASH`). Returns a fresh `list`
(the input is left to its caller). `isa_global` is unused now that the shared
`is_a` callback owns the subtype lookup; kept for signature stability."""
impl NaIRGenPass._osp_emit_filter_fn(
    isa_global: ir.GlobalVariable, n: int
) -> (ir.Function | None) {
    self._emit_list_helpers("i64", ir.IntType(64));
    _h = self.list_helpers.get("i64");
    _li64 = self.list_types.get("i64");
    if (_h is None) or (_li64 is None) {
        return None;
    }
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    _lp = _li64.as_pointer();
    fn = ir.Function(
        self.llvm_module, ir.FunctionType(_lp, [_lp, i64]), name="__osp_filter_type"
    );
    fn.linkage = "internal";
    fn.args[0].name = "in";
    fn.args[1].name = "ntag";
    _saved = self._builder;
    _entry = fn.append_basic_block("entry");
    _loop = fn.append_basic_block("loop");
    _body = fn.append_basic_block("body");
    _keep = fn.append_basic_block("keep");
    _next = fn.append_basic_block("next");
    _done = fn.append_basic_block("done");
    self._builder = ir.IRBuilder(_entry);
    _out = self._rc_call_with_ctx(_h["new"], [], op="new", loc="", name="filt.out");
    _len = self.builder.call(_h["len"], [fn.args[0]], name="filt.len");
    self.builder.branch(_loop);
    self._builder = ir.IRBuilder(_loop);
    _i = self.builder.phi(i64, name="filt.i");
    _i.add_incoming(ir.Constant(i64, 0), _entry);
    self.builder.cbranch(
        self.builder.icmp_unsigned(">=", _i, _len, name="filt.atend"), _done, _body
    );
    self._builder = ir.IRBuilder(_body);
    _hv = self.builder.call(_h["get"], [fn.args[0], _i], name="filt.h");
    _p = self.builder.inttoptr(_hv, i8p, name="filt.p");
    _tag = self.builder.load(
        self.builder.bitcast(
            self.builder.gep(_p, [ir.Constant(i64, 8)], name="filt.tagp"),
            i64.as_pointer(),
            name="filt.tagp64"
        ),
        name="filt.tag"
    );
    _keepc = self.builder.call(self._osp_is_a_fn, [_tag, fn.args[1]], name="filt.isa")
        if (self._osp_is_a_fn is not None)
        else ir.Constant(ir.IntType(1), 0);
    self.builder.cbranch(_keepc, _keep, _next);
    self._builder = ir.IRBuilder(_keep);
    self._rc_call_with_ctx(_h["append"], [_out, _hv], op="append", loc="");
    self.builder.branch(_next);
    self._builder = ir.IRBuilder(_next);
    _i1 = self.builder.add(_i, ir.Constant(i64, 1), name="filt.i1");
    _i.add_incoming(_i1, _next);
    self.builder.branch(_loop);
    self._builder = ir.IRBuilder(_done);
    self.builder.ret(_out);
    self._builder = _saved;
    return fn;
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
    n = len(self.osp_local_idx);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = i8.as_pointer();
    # __ospDESC: [n x i8*] descriptor table (LOCAL-index keyed), set at setup.
    _desc_ty = ir.ArrayType(i8p, n);
    self._osp_desc_global = ir.GlobalVariable(
        self.llvm_module, _desc_ty, name="__ospDESC"
    );
    self._osp_desc_global.linkage = "internal";
    self._osp_desc_global.initializer = ir.Constant(_desc_ty, None);
    # __ospISA: [n*n x i8] subtype matrix over LOCAL indices, constant.
    _isa_vals: list = [];
    for _i in range(n * n) {
        _isa_vals.append(0);
    }
    for (_name, _li) in self.osp_local_idx.items() {
        for _b in self._osp_isa_bases(_name) {
            _isa_vals[_li * n + _b] = 1;
        }
    }
    _isa_ty = ir.ArrayType(i8, n * n);
    _isa_global = ir.GlobalVariable(self.llvm_module, _isa_ty, name="__ospISA");
    _isa_global.linkage = "internal";
    _isa_global.global_constant = True;
    _isa_global.initializer = ir.Constant(
        _isa_ty, [ir.Constant(i8, _v) for _v in _isa_vals]
    );
    # __ospHASH: [n x i64] LOCAL index -> globally-stable hash tag, constant.
    # The runtime callbacks scan this to translate a stable tag (stored in
    # instances / edges / slots) into this module's local table index, so
    # cross-module dispatch agrees even though tables are per-module (#6642).
    _hash_vals: list = [];
    for _i in range(n) {
        _hash_vals.append(0);
    }
    for (_name, _li) in self.osp_local_idx.items() {
        _hash_vals[_li] = self.osp_tags.get(_name, 0);
    }
    _hash_ty = ir.ArrayType(i64, n);
    _hash_global = ir.GlobalVariable(self.llvm_module, _hash_ty, name="__ospHASH");
    _hash_global.linkage = "internal";
    _hash_global.global_constant = True;
    _hash_global.initializer = ir.Constant(
        _hash_ty, [ir.Constant(i64, _v) for _v in _hash_vals]
    );
    # __ospRT: OspRuntime*, populated at setup time.
    _rt_ty = self.struct_types["OspRuntime"].as_pointer();
    self._osp_rt_global = ir.GlobalVariable(self.llvm_module, _rt_ty, name="__ospRT");
    self._osp_rt_global.linkage = "internal";
    self._osp_rt_global.initializer = ir.Constant(_rt_ty, None);
    # __osp_h2i(stable_tag) -> i64: scan __ospHASH for the local index, or -1.
    self._osp_h2i_fn = self._osp_emit_h2i_fn(_hash_global, n);
    _cbs = self._osp_emit_callbacks(_isa_global, n);
    # __osp_filter_type: node-type filter for `[--> [?:Area]]` edge refs.
    self._osp_filter_fn = self._osp_emit_filter_fn(_isa_global, n);
    # __osp_setup(): build descriptors + runtime.
    _setup = ir.Function(
        self.llvm_module, ir.FunctionType(ir.VoidType(), []), name="__osp_setup"
    );
    _setup.linkage = "internal";
    self._osp_setup_fn = _setup;
    _saved = self._builder;
    self._builder = ir.IRBuilder(_setup.append_basic_block("entry"));
    for (_name, _lidx) in self.osp_local_idx.items() {
        _sn = "WalkerDesc"
            if (self.osp_arch_kind.get(_name) == "walker")
            else "NodeDesc";
        # The descriptor's own type_tag carries the STABLE hash (its identity);
        # the __ospDESC slot is keyed by the LOCAL index.
        _desc = self._osp_build_descriptor(
            _sn,
            self.osp_tags.get(_name, 0),
            self._osp_collect_slots(_name, True),
            self._osp_collect_slots(_name, False)
        );
        if _desc is not None {
            self.builder.store(
                self.builder.bitcast(_desc, i8p, name="osp.desc.i8"),
                self.builder.gep(
                    self._osp_desc_global,
                    [ir.Constant(i32, 0), ir.Constant(i32, _lidx)],
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
    _ensure.linkage = "internal";
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
    # An operand or edge type that is an IMPORTED OSP archetype cannot lower
    # even when the kernel is registered locally: its constructor (in the
    # defining module's IR) stamps that module's tag numbering, so the local
    # is_a / descriptor tables would dispatch on mismatched tags. Fail loudly
    # with the import named instead of wiring a silently-wrong graph (#6636).
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
            E5090,
            node_override=nd,
            kind="binary operator",
            name="ConnectOp",
            help_text=_xhelp
        );
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
        # `a +>: Edge :+> b` names the edge type by a BARE Name (no `()`); it
        # constructs a DEFAULT edge instance, not a value expression. Route it
        # through instantiation so it is not codegen'd to None and the edge
        # silently dropped (issue #6642). The `Edge(args)` form is a FuncCall
        # and codegens normally.
        _etname: (str | None) = None;
        if isinstance(co.conn_type, uni.Name) {
            edge_obj = self._codegen_instantiation(co.conn_type);
            # A bare type Name is a type reference, not a constructor call, so
            # `_spawn_operand_name` (which reads the checked value type) does not
            # resolve it -- take the archetype name from the Name directly.
            _etname = self._get_name(co.conn_type);
        } else {
            edge_obj = self._codegen_expr(co.conn_type);
            _etname = self._spawn_operand_name(co.conn_type);
        }
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

"""Lower an edge reference to `osp_refs(origin, dir, edge_tag, edges_only)`,
returning a `list` of neighbor-node (or, with `edge`, edge) handles in the
kernel's list representation -- ready for `visit`, `len`, iteration, or `del`.

The `chain` is `[origin?, EdgeOpRef, FilterCompr?]` (issue #6642 Blocker 1):

  * origin -- a leading non-`EdgeOpRef` expression is the explicit origin
    (`[a -->]`, `[world --> [?:Area]]`); an omitted origin defaults to the
    walker's current location `here` (`[-->]`).
  * EdgeOpRef -- direction (IN/OUT/ANY) and an optional `:Edge:` type filter.
  * FilterCompr -- an optional trailing node-type filter (`[?:Area]`), applied
    to the neighbor handles by `__osp_filter_type` via the `is_a` table.

Multi-hop chains and value-compare filters (`[?:Area(x > 1)]`) are not lowered
yet and fail loudly with E5090 rather than silently traversing one step."""
impl NaIRGenPass._codegen_edge_ref_trailer(
    nd: uni.EdgeRefTrailer
) -> (ir.Value | None) {
    osp_refs_fn = self.func_symtab.get("osp_refs");
    if (osp_refs_fn is None) or (not nd.chain) {
        self.emit(E5090, node_override=nd, kind="expression", name="EdgeRefTrailer");
        return None;
    }
    i64 = ir.IntType(64);
    chain = nd.chain;
    # ── origin ──────────────────────────────────────────────────────────────
    _idx = 0;
    origin_val: (ir.Value | None) = None;
    if isinstance(chain[0], uni.EdgeOpRef) {
        _here = self.local_vars.get("here");
        if _here is None {
            self.emit(
                E5090, node_override=nd, kind="expression", name="EdgeRefTrailer"
            );
            return None;
        }
        origin_val = self.builder.load(_here, name="here");
    } else {
        origin_val = self._codegen_expr(chain[0]);
        _idx = 1;
    }
    # ── edge step ───────────────────────────────────────────────────────────
    if (origin_val is None)
    or (_idx >= len(chain))
    or (not isinstance(chain[_idx], uni.EdgeOpRef)) {
        self.emit(E5090, node_override=nd, kind="expression", name="EdgeRefTrailer");
        return None;
    }
    step = chain[_idx];
    _idx += 1;
    # ── optional trailing node-type filter ──────────────────────────────────
    _node_filter: (str | None) = None;
    if _idx < len(chain) {
        _f = chain[_idx];
        if isinstance(_f, uni.FilterCompr)
        and (_f.f_type is not None)
        and (not _f.compares) {
            _node_filter = self._get_name(_f.f_type);
            _idx += 1;
        }
    }
    # Anything left over (multi-hop, value-compare filter) is unsupported.
    if _idx != len(chain) {
        self.emit(E5090, node_override=nd, kind="expression", name="EdgeRefTrailer");
        return None;
    }
    # ── edge-type filter tag ────────────────────────────────────────────────
    _dir = int(step.edge_dir.value);
    _edge_tag = -1;
    _fcond = step.filter_cond;
    if (_fcond is not None) and (_fcond.f_type is not None) {
        _etname = self._get_name(_fcond.f_type);
        if _etname is not None {
            _edge_tag = self.osp_tags.get(_etname, -1);
            # An unknown edge type has no tag; lowering as -1 would silently
            # BROADEN the filter to match-any, so fail loudly.
            if _edge_tag < 0 {
                self.emit(
                    E5090,
                    node_override=nd,
                    kind="expression",
                    name="EdgeRefTrailer",
                    help_text=self._xmod_osp_help([_etname])
                );
                return None;
            }
        }
    }
    _edges_only = 1 if nd.edges_only else 0;
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
    # ── node-type filter ────────────────────────────────────────────────────
    if _node_filter is not None {
        _ntag = self.osp_tags.get(_node_filter, -1);
        if (_ntag < 0) or (self._osp_filter_fn is None) {
            self.emit(
                E5090,
                node_override=nd,
                kind="expression",
                name="EdgeRefTrailer",
                help_text=self._xmod_osp_help([_node_filter])
            );
            return None;
        }
        _unfiltered = _result;
        _result = self.builder.call(
            self._osp_filter_fn,
            [_unfiltered, ir.Constant(i64, _ntag)],
            name="osp.refs.filt"
        );
        # `__osp_filter_type` copied the surviving handles into a fresh list, so
        # the intermediate `osp_refs` result is now dead -- release it (its
        # elements are immortal graph handles, untouched by the list teardown).
        self._emit_rc_release_simple(_unfiltered, op="osp_refs_filtered", loc="");
    }
    return _result;
}

"""Resolve a `visit` target to the kernel's `list` representation. An edge-ref
target already yields that list; a LIST-valued target (a walker-field list or
an inline list literal — `visit self.targets` / `visit [a, b]`) passes through
whole so the kernel enqueues its ELEMENTS; only a bare single location is
wrapped via `osp_wrap1`. Wrapping a list as if it were one location made the
kernel read a garbage `__type_tag` off the list object itself and abort after
a clean compile (issue #6636). Every native list layout is {len, cap, data*}
with 8-byte elements, so a node-pointer list reinterprets as the kernel's
handle list via the caller's ordinary pointer coercion."""
impl NaIRGenPass._osp_visit_targets(target: uni.UniNode) -> (ir.Value | None) {
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
    # `visit` is a value-consumption seam: the kernel copies the (handle)
    # elements into scope.next, so an OWNED targets temp (an inline list
    # literal) is dead here and must be released. The elements themselves are
    # OSP instances pinned immortal at construction, so element release inside
    # the list teardown is a no-op on them.
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
