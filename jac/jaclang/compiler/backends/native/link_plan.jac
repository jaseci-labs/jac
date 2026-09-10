import from jaclang.jac0core.cache_paths { atomic_write }
import ctypes;
import hashlib;
import json;
import os;
import sys;
import jaclang.compiler.backends.native.llvm.binding as llvm;
import type from jaclang.compiler.backends.native.llvm.binding {
    ExecutionEngine,
    ModuleRef,
    TargetMachine
}
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    NATIVE_LINK_MODE_BITCODE,
    NATIVE_LINK_MODE_OBJECTS,
    env_na_debug
}
import from jaclang.compiler.driver.native_iface {
    NativeIface,
    layout_digest as layout_digest_of,
    merge_class_layouts
}
import from jaclang.compiler.backends.native.link_glue {
    ENTRY_SYMBOL,
    GlueSpec,
    GlueUnit,
    REGION_DIED_HOOK,
    SHARED_INIT_SYMBOL,
    STR_NEW_SYMBOL,
    init_object_codegen,
    link_glue_ir
}
import from jaclang.compiler.backends.native.na_compile_pass {
    NATIVE_CODE_MODEL,
    NATIVE_RELOC_MODEL,
    optimize_unit
}
import from jaclang.compiler.backends.native.linker_common {
    clib_needed_libs,
    clib_symbol_lib_map,
    collect_floor_archives,
    load_musl_static,
    load_outline_atomics
}
import from jaclang.compiler.frontend.codeinfo {
    install_native_static_init,
    kernel_unit_path
}
import type from jaclang.compiler.driver.program { JacProgram }

glob PLAN_DIGEST_FORMAT: int = 2;

enum ArtifactKind {
    EXECUTABLE = "executable",
    SHARED = "shared",
    WASM = "wasm",
    JIT = "jit"
}

glob LIBC_SHARED_NAMES: tuple[str, ...] = ("libc.so.6", "libm.so.6");

class LinkPlanError(RuntimeError) {}

class SymbolCollision(LinkPlanError) {
    def init(self: SymbolCollision, symbol: str, first: str, second: str) {
        self.symbol = symbol;
        self.first = first;
        self.second = second;
        RuntimeError.__init__(
            self,
            f"symbol collision: '{symbol}' is defined in both {first} and {second}"
        );
    }
}

def check_pub_collisions(units: list[LinkUnit]) {
    owners: dict[str, str] = {};
    for u in units {
        for sym in u.iface.pub_symbols() {
            first = owners.get(sym);
            if first is not None and first != u.path {
                raise SymbolCollision(sym, first, u.path);
            }
            owners[sym] = u.path;
        }
    }
}

obj LinkUnit {
    has path: str,
        prefix: str,
        iface: NativeIface,
        digest: str,
        modkey: str = "",
        is_root: bool = False;
}

obj LinkInputs {
    has objects: list[bytes] = [],
        archive_members: list[bytes] = [],
        crt_objects: list[bytes] = [],
        needed_libs: list[str] = [],
        symbol_lib_map: dict[str, str] = {},
        export_symbols: list[str] = [],
        init_funcs: list[str] = [],
        static_musl: bool = False;

    def digest(plan_digest: str, kind: str, soname: str) -> str {
        """Hash a build action from code inputs and runtime contents.
        Code inputs may be bitcode before whole-program optimization.""";
        payload = {
            "plan": plan_digest,
            "kind": kind,
            "soname": soname,
            "objects": [hashlib.sha256(b).hexdigest() for b in self.objects],
            "archives": [hashlib.sha256(b).hexdigest() for b in self.archive_members],
            "crt": [hashlib.sha256(b).hexdigest() for b in self.crt_objects],
            "libraries": self.needed_libs,
            "symbols": self.symbol_lib_map,
            "exports": self.export_symbols,
            "initializers": self.init_funcs,
            "static_musl": self.static_musl
        };
        return hashlib.sha256(json.dumps(payload, sort_keys=True).encode()).hexdigest();
    }
}

obj LinkResult {
    has output_path: str,
        plan_digest: str,
        layout_digest: str,
        sha256: str,
        classes: dict = {},
        units: list[str] = [],
        reused: bool = False;
}

obj LinkPlan {
    has prog: JacProgram,
        options: CompileOptions,
        roots: list[str],
        units: list[LinkUnit],
        mode: str,
        triple: str;

    def unit(path: str) -> (LinkUnit | None) {
        real = os.path.realpath(path);
        for u in self.units {
            if u.path == real {
                return u;
            }
        }
        return None;
    }

    def root_unit -> LinkUnit {
        for u in self.units {
            if u.is_root {
                return u;
            }
        }
        raise LinkPlanError("link plan has no root_u unit");
    }

    def root_index -> int {
        for (i, u) in enumerate(self.units) {
            if u.is_root {
                return i;
            }
        }
        return -1;
    }

    def init_symbols -> list[str] {
        return [
            u.iface.init_symbol
            for u in self.units
            if u.iface.init_symbol
        ];
    }

    def plan_digest -> str {
        h = hashlib.sha256();
        h.update(f"plan-format={PLAN_DIGEST_FORMAT}".encode());
        h.update(self.mode.encode());
        h.update(self.triple.encode());
        h.update(self.options.codegen_identity().encode());
        import from jaclang.compiler.driver.jir { running_compiler_digest }
        h.update(running_compiler_digest().encode());
        for u in self.units {
            h.update(u.path.encode());
            h.update(u.modkey.encode());
            h.update(u.digest.encode());
        }
        return h.hexdigest();
    }

    def merged_layout -> dict {
        return merge_class_layouts([u.iface for u in self.units]);
    }

    def layout_digest -> str {
        return layout_digest_of(self.merged_layout());
    }

    def demoted_symbols -> list[str] {
        out: list[str] = [];
        for u in self.units {
            for name in u.iface.demoted {
                out.append(f"{os.path.basename(u.path)}:{name}");
            }
        }
        return sorted(out);
    }

    def clib_paths -> list[str] {
        out: list[str] = [];
        for u in self.units {
            for p in u.iface.clib_paths {
                if p not in out {
                    out.append(p);
                }
            }
        }
        return out;
    }

    def clib_symbol_lib -> dict[str, str] {
        out: dict[str, str] = {};
        for u in self.units {
            for (sym, lib) in u.iface.clib_symbol_lib.items() {
                out.setdefault(sym, lib);
            }
        }
        return out;
    }

    def pub_exports -> list[str] {
        out: list[str] = [];
        for u in self.units {
            for sym in u.iface.pub_symbols() {
                if sym not in out {
                    out.append(sym);
                }
            }
        }
        return out;
    }

    def has_unit(rel: str) -> bool {
        want = os.path.realpath(kernel_unit_path(rel));
        return any(u.path == want for u in self.units);
    }

    def glue_spec(kind: ArtifactKind, platform: str, static_musl: bool) -> GlueSpec {
        units: list[GlueUnit] = [];
        str_new_symbol = "";
        for unit in [self.root_unit()] + self.units {
            constructor = unit.iface.exports.get(STR_NEW_SYMBOL);
            if constructor is not None {
                str_new_symbol = constructor.symbol;
                break;
            }
        }
        hook_supplied = any(REGION_DIED_HOOK in u.iface.exports for u in self.units);
        for u in self.units {
            exports = u.iface.exports;
            probe = exports.get("__jac_rt_probe");
            units.append(
                GlueUnit(
                    prefix=u.prefix,
                    init_symbol=u.iface.init_symbol,
                    entry_symbol=u.iface.entry_symbol,
                    probe=probe.symbol if probe is not None else "",
                    retain="jac_retain" in exports,
                    release="jac_release" in exports,
                    str_new=str_new_symbol
                )
            );
        }
        is_elf = platform == "elf";
        return GlueSpec(
            units=units,
            root_index=self.root_index(),
            shared=(kind == ArtifactKind.SHARED),
            platform=platform if kind != ArtifactKind.JIT else "jit",
            static_musl=static_musl,
            triple=self.triple,
            clib_paths=self.clib_paths(),
            needs_atexit_shim=(
                is_elf and (kind == ArtifactKind.SHARED or not static_musl)
            ),
            needs_region_hook=not hook_supplied
        );
    }
}

def _platform_of(triple: str) -> str {
    tl = triple.lower();
    if ("windows" in tl) or ("msvc" in tl) or ("mingw" in tl) {
        return "pe";
    }
    if ("darwin" in tl) or ("apple" in tl) or ("macos" in tl) {
        return "macho";
    }
    if "wasm" in tl {
        return "wasm";
    }
    return "elf";
}

def build_link_plan(
    prog: JacProgram,
    roots: list[str],
    options: (CompileOptions | None) = None,
    mode: str = "",
    native_unit: bool = False
) -> LinkPlan {
    import from jaclang.compiler.driver.nativecache { NativeBuildSession }
    opts = options if options is not None else CompileOptions();
    if native_unit and not opts.native_unit {
        opts = opts.clone_for_native_import();
        opts.native_unit = True;
    }
    registry = prog.native_units();
    if registry.session is not None {
        return _build_link_plan(prog, roots, opts, mode, native_unit);
    }
    session = NativeBuildSession(registry=registry, options=opts);
    registry.session = session;
    import from jaclang.compiler.driver.compile_options {
        push_native_target,
        pop_native_target
    }
    target_token = push_native_target(opts.native_target or "");
    try {
        plan = _build_link_plan(prog, roots, opts, mode, native_unit);
        session.finish([unit.path for unit in plan.units]);
        return plan;
    } finally {
        registry.session = None;
        session.close();
        pop_native_target(target_token);
    }
}

def _build_link_plan(
    prog: JacProgram,
    roots: list[str],
    options: (CompileOptions | None) = None,
    mode: str = "",
    native_unit: bool = False
) -> LinkPlan {
    opts = options if options is not None else CompileOptions();
    if native_unit and not opts.native_unit {
        opts = opts.clone_for_native_import();
        opts.native_unit = True;
    }
    link_mode = mode or (opts.native_link_mode or NATIVE_LINK_MODE_OBJECTS);
    triple = opts.effective_triple();
    if _platform_of(triple) in ("pe", "wasm") {
        link_mode = NATIVE_LINK_MODE_BITCODE;
    }
    registry = prog.native_units();
    real_roots = [os.path.realpath(r) for r in roots];
    units: dict[str, LinkUnit] = {};
    edges: dict[str, list[str]] = {};
    virtual_sources: dict[str, str] = {};

    def walk_unit(path: str, stack: list[str]) -> None {
        if path in units {
            return;
        }
        if path in stack {
            return;
        }
        for dep in registry.known_native_deps(path, opts) {
            walk_unit(dep, stack + [path]);
        }
        errs_before = len(prog.errors_had);
        ent = registry.ensure(
            path, compile_on_miss=False, options=opts, check_deps=False
        );
        if ent is None and os.path.isfile(path) {
            ent = registry.compile_unit(path, opts);
        }
        if ent is None {
            why = [
                e.pretty_print().split("\n")[0] for e in prog.errors_had[errs_before:]
            ][:5];
            crashed = registry.failures.get(path);
            if crashed {
                why.append(crashed);
            }
            detail = ("; ".join(why)) if why else "no diagnostic was recorded";
            raise LinkPlanError(
                f"{path} is not a native unit for this codegen identity, or "
                f"failed to lower ({detail})"
            );
        }
        import from jaclang.compiler.driver.jir { module_cache_key }
        try {
            modkey = module_cache_key(path);
        } except OSError {
            """A root compiled from a string has no file; its interface
            digest is the only identity the plan can give it.""";
            modkey = ent.digest;
        }
        units[path] = LinkUnit(
            path=path,
            prefix=ent.iface.prefix,
            iface=ent.iface,
            digest=ent.digest,
            modkey=modkey,
            is_root=(path in real_roots)
        );
        deps = sorted(os.path.realpath(d) for d in ent.iface.deps);
        edges[path] = deps;
        for dep in deps {
            walk_unit(dep, stack + [path]);
        }
    }

    for root_u in real_roots {
        walk_unit(root_u, []);
    }

    import from jaclang.compiler.driver.dependency_graph { dependency_groups }
    import from jaclang.compiler.frontend.codeinfo { is_kernel_unit_path }
    seen: set[str] = set();
    ordered: list[LinkUnit] = [];
    while True {
        groups = dependency_groups(edges, real_roots);
        ordered = [];
        for group in groups {
            members = [units[p] for p in group];
            members.sort(
                key=lambda (u: LinkUnit) { (
                    0 if is_kernel_unit_path(u.path) else 1,
                    1 if u.is_root else 0,
                    u.path
                ); }
            );
            ordered.extend(members);
        }
        state = json.dumps(
            [
                [
                    u.path,
                    u.digest,
                    edges[u.path],
                    registry.recorded_native_deps(u.path, opts)
                ] for u in ordered
            ]
        );
        if state in seen {
            disagreements: list[str] = [];
            for u in ordered {
                recorded = dict(registry.recorded_native_deps(u.path, opts));
                for dep in edges[u.path] {
                    actual = units[dep].digest;
                    prior = recorded.get(dep, "");
                    if prior != actual {
                        disagreements.append(
                            f"{u.path} -> {dep}: {prior[:12] or 'missing'}, expected {actual[:12]}"
                        );
                    }
                }
            }
            raise LinkPlanError(
                "native interfaces did not converge: " + "; ".join(disagreements)
            );
        }
        seen.add(state);
        rebuilt = False;
        for u in ordered {
            recorded = dict(registry.recorded_native_deps(u.path, opts));
            stale = [
                dep
                for dep in edges[u.path]
                if not recorded.get(dep) or recorded[dep] != units[dep].digest
            ];
            if not stale {
                continue;
            }
            source_text = virtual_sources.get(u.path);
            if not os.path.isfile(u.path) {
                source_module = prog.find_module(u.path);
                if source_module is not None {
                    source_text = source_module.source.code;
                    virtual_sources[u.path] = source_text;
                }
            }
            if not os.path.isfile(u.path) and source_text is None {
                raise LinkPlanError(
                    f"{u.path} was compiled from a string and cannot be lowered "
                    f"again to settle its dependencies: {', '.join(stale)}"
                );
            }
            if env_na_debug() {
                sys.stderr.write(
                    f"[link plan] rebuilding {u.path}: {', '.join(stale)}\n"
                );
            }
            registry.forget(u.path);
            prog.invalidate_module(u.path);
            ent = (
                registry.compile_unit(u.path, opts, use_str=source_text)
                    if source_text is not None
                    else registry.compile_unit(u.path, opts)
            );
            if ent is None {
                raise LinkPlanError(
                    f"{u.path} failed to lower against its dependencies "
                    f"({registry.failures.get(u.path) or 'no diagnostic was recorded'})"
                );
            }
            u.iface = ent.iface;
            u.digest = ent.digest;
            u.prefix = ent.iface.prefix;
            new_deps = sorted(os.path.realpath(d) for d in ent.iface.deps);
            changed_edges = new_deps != edges[u.path];
            edges[u.path] = new_deps;
            for dep in new_deps {
                walk_unit(dep, []);
            }
            rebuilt = True;
            if changed_edges {
                """Recompute reachability and group order before compiling another
                consumer. A lowering can add or remove native dependencies.""";
                break;
            }
        }
        if not rebuilt {
            break;
        }
    }

    check_pub_collisions(ordered);
    import from jaclang.compiler.driver.na_coverage { na_coverage_replay }
    for unit in ordered {
        na_coverage_replay(unit.path, unit.iface.coverage or {"outcome": "native"});
    }
    return LinkPlan(
        prog=prog,
        options=opts,
        roots=real_roots,
        units=ordered,
        mode=link_mode,
        triple=triple
    );
}

def _target_machine(plan: LinkPlan, kind: ArtifactKind) -> TargetMachine {
    init_object_codegen();
    target_ovr = plan.options.native_target or "";
    target = (
        llvm.Target.from_triple(target_ovr)
            if target_ovr
            else llvm.Target.from_default_triple()
    );
    assert isinstance(target, llvm.Target);
    opt = 0 if plan.options.native_debug else 2;
    if kind == ArtifactKind.JIT {
        tm = target.create_target_machine(opt=opt, jit=True);
    } else {
        tm = target.create_target_machine(
            opt=opt, reloc=NATIVE_RELOC_MODEL, codemodel=NATIVE_CODE_MODEL
        );
    }
    assert isinstance(tm, llvm.TargetMachine);
    return tm;
}

def _glue_module(
    plan: LinkPlan, spec: GlueSpec, tm: (TargetMachine | None) = None
) -> tuple[ModuleRef, list[str]] {
    if tm is not None and not spec.data_layout {
        spec.data_layout = str(tm.target_data);
    }
    (ir_text, exports) = link_glue_ir(spec);
    mod = llvm.parse_assembly(ir_text);
    mod.verify();
    return (mod, exports);
}

def whole_program_module(
    plan: LinkPlan, spec: GlueSpec
) -> tuple[ModuleRef, list[str]] {
    registry = plan.prog.native_units();
    merged: (ModuleRef | None) = None;
    for u in plan.units {
        bc = registry.bitcode_for(u.path, plan.options);
        if bc is None {
            raise LinkPlanError(f"no bitcode for native unit {u.path}");
        }
        unit_mod = llvm.parse_bitcode(bc);
        assert isinstance(unit_mod, llvm.ModuleRef);
        if merged is None {
            merged = unit_mod;
        } else {
            merged.link_in(unit_mod);
        }
    }
    if merged is None {
        raise LinkPlanError("link plan holds no units");
    }
    (glue, exports) = _glue_module(plan, spec);
    merged.link_in(glue);
    merged.verify();
    return (merged, exports);
}

def unit_objects(
    plan: LinkPlan, spec: GlueSpec, tm: TargetMachine
) -> tuple[list[bytes], list[str]] {
    registry = plan.prog.native_units();
    objs: list[bytes] = [];
    ordered = plan.units;
    for u in ordered {
        object_bytes = registry.object_for(u.path, plan.options);
        if object_bytes is None {
            raise LinkPlanError(f"no object for native unit {u.path}");
        }
        objs.append(object_bytes);
    }
    (glue_mod, exports) = _glue_module(plan, spec, tm);
    dump_path = plan.options.dump_ir_path or "";
    if dump_path {
        """In objects mode the program is its units' objects plus the glue;
        the dump is the glue module after every unit's own text, which is
        what a reader of the finalized program expects to find.""";
        with open(dump_path, "w") as df {
            for u in ordered {
                bc = registry.bitcode_for(u.path, plan.options);
                if bc is not None {
                    df.write(str(llvm.parse_bitcode(bc)));
                    df.write("\n");
                }
            }
            df.write(str(glue_mod));
        }
    }
    glue_obj = tm.emit_object(glue_mod);
    assert isinstance(glue_obj, bytes);
    objs.append(glue_obj);
    return (objs, exports);
}

def optimize_whole_program(
    plan: LinkPlan, merged: ModuleRef, kind: ArtifactKind, tm: TargetMachine
) -> None {
    opt_level = 0 if plan.options.native_debug else int(plan.options.opt_level or 0);
    if opt_level <= 0 {
        return;
    }
    pto = llvm.create_pipeline_tuning_options(speed_level=opt_level);
    pb = llvm.create_pass_builder(tm, pto);
    assert isinstance(pb, llvm.PassBuilder);
    mpm = pb.getModulePassManager();
    assert isinstance(mpm, llvm.ModulePassManager);
    if kind == ArtifactKind.EXECUTABLE {
        mpm.add_internalize_pass();
    }
    mpm.run(merged, pb);
}

def plan_objects(
    plan: LinkPlan, spec: GlueSpec, kind: ArtifactKind, tm: TargetMachine
) -> tuple[list[bytes], list[str]] {
    if plan.mode == NATIVE_LINK_MODE_OBJECTS {
        return unit_objects(plan, spec, tm);
    }
    (merged, exports) = whole_program_module(plan, spec);
    optimize_whole_program(plan, merged, kind, tm);
    dump_path = plan.options.dump_ir_path or "";
    if dump_path {
        with open(dump_path, "w") as df {
            df.write(str(merged));
        }
    }
    object_bytes = tm.emit_object(merged);
    assert isinstance(object_bytes, bytes);
    return ([object_bytes], exports);
}

def units_source_key(paths: list[str], options: CompileOptions) -> str {
    import from jaclang.compiler.driver.jir {
        module_cache_key,
        running_compiler_digest
    }
    import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
    h = hashlib.sha256();
    h.update(running_compiler_digest().encode("utf-8"));
    h.update(options.codegen_identity().encode("utf-8"));
    h.update(options.effective_triple().encode("utf-8"));
    for path in sorted(os.path.realpath(p) for p in paths) {
        h.update(native_unit_identity(path).encode("utf-8"));
        try {
            h.update(module_cache_key(path).encode("utf-8"));
        } except OSError {
            h.update(b"missing");
        }
    }
    return h.hexdigest();
}

def sidecar_unit_paths(sidecar: dict) -> list[str] {
    """The units a sidecar names, found where this process's jaclang lives:
    a kernel built by the kit records its units by package identity, so the
    checkout that matches the kit's sources can accept it without the
    build's paths existing here.""";
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    units = sidecar.get("units");
    ids = sidecar.get("unit_ids");
    recorded = [str(u) for u in units] if isinstance(units, list) else [];
    if not isinstance(ids, list) or len(ids) != len(recorded) {
        return recorded;
    }
    pkg_parent = os.path.dirname(jaclang_pkg_root());
    out: list[str] = [];
    for (path, ident) in zip(recorded, ids) {
        ident_s = str(ident);
        local = (
            os.path.join(pkg_parent, ident_s)
                if ident_s.startswith("jaclang/")
                else path
        );
        out.append(local if os.path.isfile(local) else path);
    }
    return out;
}

def _write_sidecar(
    plan: LinkPlan,
    output_path: str,
    plan_digest: str,
    action_digest: str = "",
    artifact_sha256: str = ""
) -> tuple[dict, str] {
    classes = plan.merged_layout();
    ldigest = layout_digest_of(classes);
    import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
    unit_paths = [u.path for u in plan.units];
    sidecar = {
        "classes": classes,
        "plan_digest": plan_digest,
        "layout_digest": ldigest,
        "units": unit_paths,
        "unit_ids": [native_unit_identity(p) for p in unit_paths],
        "source_key": units_source_key(unit_paths, plan.options),
        "action_digest": action_digest,
        "artifact_sha256": artifact_sha256
    };
    atomic_write(
        output_path + ".layout.json",
        json.dumps(sidecar, sort_keys=True).encode("utf-8")
    );
    return (classes, ldigest);
}

def _sha256_of(path: str) -> str {
    h = hashlib.sha256();
    with open(path, "rb") as f {
        h.update(f.read());
    }
    return h.hexdigest();
}

def _reuse_artifact(
    plan: LinkPlan, output_path: str, action_digest: str
) -> (LinkResult | None) {
    import from jaclang.compiler.driver.jir { cache_mode }
    (rebuild, _) = cache_mode();
    if rebuild
        or plan.options.no_ir_cache
        or plan.options.native_debug
        or plan.options.dump_ir_path {
        return None;
    }
    try {
        with open(output_path + ".layout.json", encoding="utf-8") as f {
            sidecar = json.load(f);
        }
        if not isinstance(sidecar, dict)
            or sidecar.get("action_digest") != action_digest {
            return None;
        }
        classes = plan.merged_layout();
        if sidecar.get("classes") != classes {
            return None;
        }
        digest = _sha256_of(output_path);
        if sidecar.get("artifact_sha256") != digest {
            return None;
        }
        return LinkResult(
            output_path=output_path,
            plan_digest=plan.plan_digest(),
            layout_digest=layout_digest_of(classes),
            sha256=digest,
            classes=classes,
            units=[u.path for u in plan.units],
            reused=True
        );
    } except (OSError, ValueError, TypeError) {
        return None;
    }
}

def link_artifact(
    plan: LinkPlan,
    output_path: str,
    kind: ArtifactKind,
    log: any = None,
    app_imports: (set | None) = None
) -> LinkResult {
    if kind == ArtifactKind.SHARED {
        for unit in plan.units {
            if unit.iface.python_imports {
                raise LinkPlanError(
                    f"Cannot link shared native unit {unit.path}: Python imports "
                    f"require the JIT bridge ({', '.join(unit.iface.python_imports)})"
                );
            }
        }
    }
    if kind == ArtifactKind.WASM {
        return link_wasm(plan, output_path, app_imports);
    }
    platform = _platform_of(plan.triple);
    is_macos = platform == "macho";
    is_windows = platform == "pe";
    shared = kind == ArtifactKind.SHARED;

    clib_paths = plan.clib_paths();
    clib_symbol_lib = plan.clib_symbol_lib();
    (archive_members, floor_handled) = collect_floor_archives(
        clib_paths, clib_symbol_lib, plan.triple, is_macos
    );
    if log is not None and archive_members {
        log(f"  Static-linking {len(archive_members)} floor archive member(s).");
    }
    needed_libs: list[str] = [];
    if is_windows {
        needed_libs = ["msvcrt.dll"];
    } elif is_macos {
        needed_libs = ["/usr/lib/libSystem.B.dylib"];
    }
    lib_norm = clib_needed_libs(needed_libs, clib_paths, floor_handled);
    is_linux_exec = (not shared) and platform == "elf";
    """The runtime units declare their libc calls as C imports, and musl's
    libc.a satisfies every one of them: only a library beyond libc and libm
    keeps a Linux executable off the static path.""";
    libc_only = all(lib in LIBC_SHARED_NAMES for lib in needed_libs);
    static_musl = is_linux_exec and libc_only;
    if static_musl {
        needed_libs = [];
        lib_norm = {
            k: v
            for (k, v) in lib_norm.items()
            if v not in LIBC_SHARED_NAMES
        };
    }

    tm = _target_machine(plan, kind);
    spec = plan.glue_spec(kind, platform, static_musl);
    spec.data_layout = str(tm.target_data);
    (glue_ir, glue_exports) = link_glue_ir(spec);
    registry = plan.prog.native_units();
    code_inputs: list[bytes] = [];
    for unit in plan.units {
        product = (
            registry.bitcode_for(unit.path, plan.options)
                if plan.mode == NATIVE_LINK_MODE_BITCODE
                else registry.object_for(unit.path, plan.options)
        );
        if product is None {
            raise LinkPlanError(f"no {plan.mode} product for native unit {unit.path}");
        }
        code_inputs.append(product);
    }
    code_inputs.append(glue_ir.encode("utf-8"));
    inputs = LinkInputs(objects=code_inputs, archive_members=archive_members);
    if shared {
        inputs.init_funcs = [SHARED_INIT_SYMBOL];
        for sym in plan.pub_exports() + glue_exports {
            if sym not in inputs.export_symbols {
                inputs.export_symbols.append(sym);
            }
        }
        if not inputs.export_symbols {
            raise LinkPlanError(
                "nothing to export from a shared library: no `:pub` functions "
                "or globals in the plan; mark exports with `def:pub` / `glob:pub`"
            );
        }
    }
    if (shared or (is_linux_exec and not static_musl)) and platform == "elf" {
        for lib in ("libc.so.6", "libm.so.6") {
            if lib not in needed_libs {
                needed_libs.append(lib);
            }
        }
    }
    inputs.needed_libs = needed_libs;
    inputs.symbol_lib_map = clib_symbol_lib_map(
        clib_symbol_lib, floor_handled, lib_norm, shared, is_macos
    );
    inputs.static_musl = static_musl;

    runtime = load_musl_static(plan.triple) if static_musl else None;
    if static_musl {
        if runtime is None {
            raise LinkPlanError(
                "Static musl runtime not found. Expected a vendored musl "
                "libc.a under .pbs-build/<arch>/musl/lib (run `zig build "
                "vendor-musl`) or set JAC_NATIVE_MUSL_DIR."
            );
        }
        inputs.archive_members = inputs.archive_members + runtime.archives;
        inputs.crt_objects = runtime.crt_objects;
    }
    atomics = load_outline_atomics(plan.triple);
    if atomics is None and archive_members {
        import from jaclang.compiler.backends.native.linker_common {
            object_undefined_symbols
        }
        missing_atomics = sorted(
            {
                symbol for member in archive_members
                for symbol in object_undefined_symbols(member)
                if symbol.startswith("__aarch64_")
            }
        );
        if missing_atomics {
            raise LinkPlanError(
                "AArch64 compiler runtime archive not found for floor symbols: "
                    + ", ".join(missing_atomics)
                    + ". Run `zig build vendor-musl` for the target or set JAC_NATIVE_MUSL_DIR."
            );
        }
    }
    if atomics is not None {
        inputs.archive_members = inputs.archive_members + atomics.archives;
    }
    soname = os.path.basename(output_path);
    action_digest = inputs.digest(plan.plan_digest(), kind.value, soname);
    reused = _reuse_artifact(plan, output_path, action_digest);
    if reused is not None {
        plan.prog.native_units().note_link(True);
        return reused;
    }
    plan.prog.native_units().note_link(False);
    (objects, _) = plan_objects(plan, spec, kind, tm);
    inputs.objects = objects;
    inputs.archive_members = archive_members;
    if atomics is not None {
        inputs.archive_members = inputs.archive_members
            + atomics.select(objects + archive_members);
    }
    if runtime is not None {
        inputs.archive_members = inputs.archive_members
            + runtime.select(objects + inputs.archive_members);
        if log is not None {
            log(
                f"  Static-linking musl: {len(inputs.archive_members)
                    - len(archive_members)} libc member(s) + "
                f"{len(inputs.crt_objects)} crt object(s)."
            );
        }
    }
    if is_windows {
        import from jaclang.compiler.backends.native.pe_linker { PeLinker }
        ok = PeLinker.link(
            objects=inputs.objects,
            output_path=output_path,
            needed_libs=inputs.needed_libs,
            symbol_lib_map=inputs.symbol_lib_map,
            shared=shared,
            export_symbols=inputs.export_symbols,
            init_funcs=inputs.init_funcs,
            soname=soname
        );
    } elif is_macos {
        import from jaclang.compiler.backends.native.macho_linker { MachOLinker }
        ok = MachOLinker.link(
            objects=inputs.objects,
            output_path=output_path,
            needed_libs=inputs.needed_libs,
            symbol_lib_map=inputs.symbol_lib_map,
            shared=shared,
            export_symbols=inputs.export_symbols,
            init_funcs=inputs.init_funcs,
            soname=soname,
            archive_members=inputs.archive_members
        );
    } else {
        import from jaclang.compiler.backends.native.elf_linker { ElfLinker }
        ok = ElfLinker.link(
            objects=inputs.objects,
            output_path=output_path,
            needed_libs=inputs.needed_libs,
            crt_objects=inputs.crt_objects,
            shared=shared,
            export_symbols=inputs.export_symbols,
            init_funcs=inputs.init_funcs,
            soname=soname,
            archive_members=inputs.archive_members,
            static_link=static_musl
        );
    }
    if not ok {
        raise LinkPlanError(f"{platform} link failed: could not parse an object");
    }
    digest = plan.plan_digest();
    artifact_sha256 = _sha256_of(output_path);
    (classes, ldigest) = _write_sidecar(
        plan, output_path, digest, action_digest, artifact_sha256
    );
    return LinkResult(
        output_path=output_path,
        plan_digest=digest,
        layout_digest=ldigest,
        sha256=artifact_sha256,
        classes=classes,
        units=[u.path for u in plan.units]
    );
}

def expose_root_exports(plan: LinkPlan, merged: ModuleRef) -> list[str] {
    """A wasm host calls the entry module's functions by the names the
    source gives them: the root unit's module-level functions and globals
    take their bare names in the merged module, the way `:pub` symbols
    already do, and a name another symbol already holds stays qualified.""";
    exposed: list[str] = [];
    root_u = plan.root_unit();
    mod_any: any = merged;
    for name in sorted(root_u.iface.exports.keys()) {
        ex = root_u.iface.exports[name];
        if ex.is_pub or ex.kind not in ("function", "global") or "." in name {
            continue;
        }
        if ex.symbol == name {
            continue;
        }
        try {
            taken = (
                mod_any.get_function(name)
                    if ex.kind == "function"
                    else mod_any.get_global_variable(name)
            );
        } except Exception {
            taken = None;
        }
        if taken is not None {
            continue;
        }
        try {
            value = (
                mod_any.get_function(ex.symbol)
                    if ex.kind == "function"
                    else mod_any.get_global_variable(ex.symbol)
            );
        } except Exception {
            continue;
        }
        value.name = name;
        exposed.append(name);
    }
    return exposed;
}

def wasm_program_ir(plan: LinkPlan) -> str {
    spec = plan.glue_spec(ArtifactKind.WASM, "wasm", False);
    (merged, _exports) = whole_program_module(plan, spec);
    expose_root_exports(plan, merged);
    return str(merged);
}

def link_wasm(
    plan: LinkPlan, output_path: str, app_imports: (set | None) = None
) -> LinkResult {
    import from jaclang.compiler.backends.native.wasm_build { emit_wasm_from_ir }
    merged_ir = wasm_program_ir(plan);
    imports: set[str] = set(app_imports or set());
    imports.update(plan.clib_symbol_lib().keys());
    wasm_bytes = emit_wasm_from_ir(merged_ir, app_imports=imports);
    atomic_write(output_path, wasm_bytes, mode=0o644);
    digest = plan.plan_digest();
    (classes, ldigest) = _write_sidecar(plan, output_path, digest);
    return LinkResult(
        output_path=output_path,
        plan_digest=digest,
        layout_digest=ldigest,
        sha256=_sha256_of(output_path),
        classes=classes,
        units=[u.path for u in plan.units]
    );
}

def undefined_functions(mod: ModuleRef) -> list[str] {
    names: list[str] = [];
    mod_any: any = mod;
    for fn in mod_any.functions {
        if fn.is_declaration and not str(fn.name).startswith("llvm.") {
            names.append(str(fn.name));
        }
    }
    return sorted(names);
}

def load_jit_library(lib_path: str) -> ctypes.CDLL {
    import os;
    import sys;
    import ctypes.util;

    def is_darwin_abort_stub(cand: str) -> bool {
        if sys.platform != "darwin" {
            return False;
        }
        cand_base = os.path.basename(cand);
        if cand_base not in ("libcrypto.dylib", "libssl.dylib") {
            return False;
        }
        if os.path.isabs(cand) {
            return os.path.dirname(os.path.realpath(cand)) == "/usr/lib";
        }
        return True;
    }

    probe = lib_path;
    if probe.startswith("$ORIGIN/") {
        probe = probe[8:];
    } elif probe.startswith("@loader_path/") {
        probe = probe[13:];
    }
    base = os.path.basename(probe);

    for cand in [lib_path, probe, os.path.join(".", base)] {
        if cand and os.path.exists(cand) and not is_darwin_abort_stub(cand) {
            return ctypes.CDLL(os.path.abspath(cand));
        }
    }

    if not is_darwin_abort_stub(base) {
        try {
            return ctypes.CDLL(base);
        } except Exception {}
    }

    stem = base;
    if stem.startswith("lib") {
        stem = stem[3:];
    }
    for _ext in [".so", ".dylib", ".dll"] {
        _i = stem.find(_ext);
        if _i != -1 {
            stem = stem[:_i];
        }
    }
    found = ctypes.util.find_library(stem) or ctypes.util.find_library(probe);
    if found and not is_darwin_abort_stub(found) {
        return ctypes.CDLL(found);
    }
    raise LinkPlanError(f"C library not found for JIT: {lib_path}");
}

def jit_engine(plan: LinkPlan) -> ExecutionEngine {
    tm = _target_machine(plan, ArtifactKind.JIT);
    spec = plan.glue_spec(ArtifactKind.JIT, _platform_of(plan.triple), False);
    (merged, _exports) = whole_program_module(plan, spec);
    optimize_whole_program(plan, merged, ArtifactKind.JIT, tm);
    if env_na_debug() {
        sys.stderr.write(
            f"[jit] {len(plan.units)} unit(s), inits {plan.init_symbols()}, "
            f"undefined: {undefined_functions(merged)}\n"
        );
    }
    libraries: dict[str, ctypes.CDLL] = {};
    symbols: dict[str, int] = {};
    symbol_lib = plan.clib_symbol_lib();
    for symbol in undefined_functions(merged) {
        lib_path = symbol_lib.get(symbol);
        if lib_path is None {
            continue;
        }
        if lib_path not in libraries {
            libraries[lib_path] = load_jit_library(lib_path);
        }
        try {
            address = ctypes.cast(
                getattr(libraries[lib_path], symbol), ctypes.c_void_p
            ).value;
        } except AttributeError {
            raise LinkPlanError(f"C symbol '{symbol}' not found in '{lib_path}'");
        }
        if address is None {
            raise LinkPlanError(
                f"C symbol '{symbol}' has a null address in '{lib_path}'"
            );
        }
        symbols[symbol] = address;
    }
    engine = llvm.create_mcjit_compiler(merged, tm);
    assert isinstance(engine, llvm.ExecutionEngine);
    for (symbol, address) in symbols.items() {
        engine.add_global_mapping(merged.get_function(symbol), address);
    }
    install_native_static_init(engine, plan.init_symbols());
    engine_any: any = engine;
    engine_any._jac_libraries = libraries;
    engine_any._jac_unit_ifaces = [u.iface for u in plan.units];
    root_u = plan.root_unit();
    try {
        setattr(engine, "_jac_unit_path", root_u.path);
        setattr(engine, "_jac_native_iface", root_u.iface);
    } except Exception {}
    return engine;
}

def jit_engine_for_module(
    prog: JacProgram, module: any, options: CompileOptions
) -> (ExecutionEngine | None) {
    if not (module?.loc and module.loc.mod_path) {
        return None;
    }
    prog.native_units().record_module(module, options);
    plan = build_link_plan(
        prog, [module.loc.mod_path], options, mode=NATIVE_LINK_MODE_BITCODE
    );
    return jit_engine(plan);
}

def jit_engine_for_cached(
    prog: JacProgram, path: str, options: CompileOptions
) -> (ExecutionEngine | None) {
    plan = build_link_plan(prog, [path], options, mode=NATIVE_LINK_MODE_BITCODE);
    return jit_engine(plan);
}
