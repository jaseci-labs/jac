"""One link plan for every native artifact.

The plan owns the walk from roots to artifact and knows nothing about the
kernel, mkpayload or the CLI: `jac nacompile`, `jac build --as native`, the
kernel resolver, `jac precompile --seal` and the in-process JIT are all
callers.

1. Resolve roots: an entry module for an executable, `jc_unit` for the
   kernel, every native unit of a package for a seal.
2. Walk the native edges each unit's interface records. For each unit the
   program's native unit registry serves a fresh interface, object and
   bitcode for the requested codegen identity, compiling on demand through
   `JacCompiler.compile`, so demotion, strictness and the seam report apply
   unchanged.
3. Check agreement: every unit's recorded dependency digests must equal the
   digests of the units in the plan. A mismatch is an error naming both.
4. Order initializers topologically and synthesize the glue object.
5. Collect floor archives, clib paths and needed libraries from the unit
   interfaces.
6. Link, in one of two modes: `objects` (the incremental default) links the
   units' relocatable objects; `bitcode` links every unit's bitcode into one
   LLVM module and runs the pass pipeline whole-program before a single
   codegen (the release lane, and what the JIT, PE and wasm targets use).
7. Record a plan digest beside the artifact and in the layout sidecar.
"""
import hashlib;
import json;
import os;
import sys;
import from dataclasses { field }
import jaclang.compiler.backends.native.llvm.binding as llvm;
import type from jaclang.compiler.backends.native.llvm.binding {
    ExecutionEngine,
    ModuleRef,
    TargetMachine
}
import from jaclang.compiler.driver.compile_options {
    CompileOptions,
    NATIVE_LINK_MODE_BITCODE,
    NATIVE_LINK_MODE_OBJECTS
}
import from jaclang.compiler.driver.native_iface {
    NativeIface,
    layout_digest,
    merge_class_layouts
}
import from jaclang.compiler.backends.native.link_glue {
    ENTRY_SYMBOL,
    GlueSpec,
    GlueUnit,
    SHARED_INIT_SYMBOL,
    init_object_codegen,
    link_glue_ir
}
import from jaclang.compiler.backends.native.na_compile_pass {
    NATIVE_CODE_MODEL,
    NATIVE_RELOC_MODEL,
    jit_load_clib,
    optimize_unit
}
import from jaclang.compiler.backends.native.linker_common {
    clib_needed_libs,
    clib_symbol_lib_map,
    collect_floor_archives,
    collect_musl_static
}
import from jaclang.compiler.frontend.codeinfo {
    OSP_GRAPH_REL,
    REGION_KERNEL_REL,
    install_native_static_init,
    kernel_unit_path
}
import type from jaclang.compiler.driver.program { JacProgram }

glob PLAN_DIGEST_FORMAT: int = 1;

enum ArtifactKind {
    EXECUTABLE = "executable",
    SHARED = "shared",
    WASM = "wasm",
    JIT = "jit"
}

class LinkPlanError(RuntimeError) {}

obj LinkUnit {
    has path: str,
        prefix: str,
        iface: NativeIface,
        digest: str,
        modkey: str = "",
        is_root: bool = False;
}

"""The link inputs a platform linker consumes."""
obj LinkInputs {
    has objects: list[bytes] = field(default_factory=`list),
        archive_members: list[bytes] = field(default_factory=`list),
        crt_objects: list[bytes] = field(default_factory=`list),
        needed_libs: list[str] = field(default_factory=`list),
        symbol_lib_map: dict[str, str] = field(default_factory=`dict),
        export_symbols: list[str] = field(default_factory=`list),
        init_funcs: list[str] = field(default_factory=`list),
        static_musl: bool = False;
}

obj LinkResult {
    has output_path: str,
        plan_digest: str,
        layout_digest: str,
        sha256: str,
        classes: dict = field(default_factory=`dict),
        units: list[str] = field(default_factory=`list);
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
        raise LinkPlanError("link plan has no root unit");
    }

    def root_index -> int {
        for (i, u) in enumerate(self.units) {
            if u.is_root {
                return i;
            }
        }
        return -1;
    }

    """Every unit's initializer, dependencies first."""
    def init_symbols -> list[str] {
        return [u.iface.init for u in self.units if u.iface.init];
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
        return layout_digest(self.merged_layout());
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

    """The `:pub` symbols of every unit: the C ABI the artifact promises."""
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
        for u in self.units {
            exports = u.iface.exports;
            probe = exports.get("__jac_rt_probe");
            units.append(
                GlueUnit(
                    prefix=u.prefix,
                    init=u.iface.init,
                    entry=u.iface.entry,
                    probe=probe.symbol if probe is not None else "",
                    retain="jac_retain" in exports,
                    release="jac_release" in exports,
                    str_new=True
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
            needs_atexit_shim=(is_elf and kind == ArtifactKind.SHARED),
            needs_region_hook=(
                self.has_unit(REGION_KERNEL_REL) and not self.has_unit(OSP_GRAPH_REL)
            )
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

"""Resolve `roots` and walk their native edges into a plan.

`native_unit` compiles kernel roots (the frontend scope) as native units in
the target program; ordinary roots inherit the caller's options.
"""
def build_link_plan(
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
    order: list[str] = [];

    def visit(path: str, stack: list[str]) -> None {
        if path in units {
            return;
        }
        if path in stack {
            return;
        }
        ent = registry.ensure(path, compile_on_miss=True, options=opts);
        if ent is None {
            raise LinkPlanError(
                f"{path} is not a native unit for this codegen identity, or "
                "failed to lower; see the diagnostics above"
            );
        }
        import from jaclang.compiler.driver.jir { module_cache_key }
        units[path] = LinkUnit(
            path=path,
            prefix=ent.iface.prefix,
            iface=ent.iface,
            digest=ent.digest,
            modkey=module_cache_key(path),
            is_root=(path in real_roots)
        );
        deps = sorted(os.path.realpath(d) for d in ent.iface.deps);
        edges[path] = deps;
        for dep in deps {
            visit(dep, stack + [path]);
        }
        order.append(path);
    }

    for root in real_roots {
        visit(root, []);
    }

    for (path, deps) in edges.items() {
        for (dep, recorded) in registry.recorded_native_deps(path) {
            dep_real = os.path.realpath(dep);
            live = units.get(dep_real);
            if live is None {
                continue;
            }
            if recorded and recorded != live.digest {
                raise LinkPlanError(
                    f"native interface disagreement: {path} was compiled against "
                    f"{dep_real} with digest {recorded[:12]}, but the plan holds "
                    f"digest {live.digest[:12]}; recompile {path}"
                );
            }
        }
    }

    ordered = [units[p] for p in order];
    ordered.sort(key=lambda (u: LinkUnit) { (1 if u.is_root else 0, ); });
    return LinkPlan(
        prog=prog, options=opts, roots=real_roots, units=ordered, mode=link_mode, triple=triple
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
    tm = target.create_target_machine(
        opt=opt,
        reloc=NATIVE_RELOC_MODEL,
        codemodel=NATIVE_CODE_MODEL,
        jit=(kind == ArtifactKind.JIT)
    );
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

"""Every unit's bitcode plus the glue, linked into one LLVM module."""
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

"""The relocatable objects of the plan in link order: the root first, its
dependencies, then the glue."""
def unit_objects(plan: LinkPlan, spec: GlueSpec, tm: TargetMachine) -> tuple[list[bytes], list[str]] {
    registry = plan.prog.native_units();
    objs: list[bytes] = [];
    root = plan.root_unit();
    ordered = [root] + [u for u in plan.units if u is not root];
    for u in ordered {
        obj = registry.object_for(u.path, plan.options);
        if obj is None {
            raise LinkPlanError(f"no object for native unit {u.path}");
        }
        objs.append(obj);
    }
    (glue_mod, exports) = _glue_module(plan, spec, tm);
    glue_obj = tm.emit_object(glue_mod);
    assert isinstance(glue_obj, bytes);
    objs.append(glue_obj);
    return (objs, exports);
}

"""The objects the platform linker receives, in the plan's mode."""
def plan_objects(
    plan: LinkPlan, spec: GlueSpec, kind: ArtifactKind, tm: TargetMachine
) -> tuple[list[bytes], list[str]] {
    if plan.mode == NATIVE_LINK_MODE_OBJECTS {
        return unit_objects(plan, spec, tm);
    }
    (merged, exports) = whole_program_module(plan, spec);
    opt_level = 0 if plan.options.native_debug else int(plan.options.opt_level or 0);
    if opt_level > 0 {
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
    dump_path = plan.options.dump_ir_path or "";
    if dump_path {
        with open(dump_path, "w") as df {
            df.write(str(merged));
        }
    }
    obj = tm.emit_object(merged);
    assert isinstance(obj, bytes);
    return ([obj], exports);
}

def _write_sidecar(plan: LinkPlan, output_path: str, plan_digest: str) -> tuple[dict, str] {
    classes = plan.merged_layout();
    ldigest = layout_digest(classes);
    sidecar = {
        "classes": classes,
        "plan_digest": plan_digest,
        "layout_digest": ldigest,
        "units": [u.path for u in plan.units]
    };
    with open(output_path + ".layout.json", "w", encoding="utf-8") as lf {
        lf.write(json.dumps(sidecar, sort_keys=True));
    }
    return (classes, ldigest);
}

def _sha256_of(path: str) -> str {
    h = hashlib.sha256();
    with open(path, "rb") as f {
        h.update(f.read());
    }
    return h.hexdigest();
}

"""Link the plan into an executable or shared library at `output_path`."""
def link_artifact(
    plan: LinkPlan,
    output_path: str,
    kind: ArtifactKind,
    log: any = None,
    app_imports: (set | None) = None
) -> LinkResult {
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
    static_musl = is_linux_exec and (len(needed_libs) == 0);

    tm = _target_machine(plan, kind);
    spec = plan.glue_spec(kind, platform, static_musl);
    (objects, glue_exports) = plan_objects(plan, spec, kind, tm);

    inputs = LinkInputs(objects=objects, archive_members=archive_members);
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

    soname = os.path.basename(output_path);
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
        if static_musl {
            musl = collect_musl_static(inputs.objects, plan.triple);
            if musl is None {
                raise LinkPlanError(
                    "Static musl runtime not found. Expected a vendored musl "
                    "libc.a under .pbs-build/<arch>/musl/lib (run `zig build "
                    "vendor-musl`) or set JAC_NATIVE_MUSL_DIR."
                );
            }
            (musl_members, crt_objects) = musl;
            inputs.archive_members = inputs.archive_members + musl_members;
            inputs.crt_objects = crt_objects;
            if log is not None {
                log(
                    f"  Static-linking musl: {len(musl_members)} libc member(s) + "
                    f"{len(crt_objects)} crt object(s)."
                );
            }
        }
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

"""Link the plan into a wasm module: whole-program bitcode, the vendored
libc folded at the IR level, one object into the wasm writer."""
def link_wasm(
    plan: LinkPlan, output_path: str, app_imports: (set | None) = None
) -> LinkResult {
    import from jaclang.compiler.backends.native.wasm_build { emit_wasm_from_ir }
    spec = plan.glue_spec(ArtifactKind.WASM, "wasm", False);
    (merged, _exports) = whole_program_module(plan, spec);
    imports: set[str] = set(app_imports or set());
    imports.update(plan.clib_symbol_lib().keys());
    wasm_bytes = emit_wasm_from_ir(str(merged), app_imports=imports);
    with open(output_path, "wb") as wf {
        wf.write(wasm_bytes);
    }
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

"""An in-process MCJIT engine over the plan: bitcode mode, one module.

The engine remembers its root unit's path and interface, so a caller can
map a Jac-level name to the unit's link symbol (`tests/support.jac`'s
`native_address` does; the interop stubs carry the symbol themselves).
"""
def jit_engine(plan: LinkPlan) -> ExecutionEngine {
    tm = _target_machine(plan, ArtifactKind.JIT);
    spec = plan.glue_spec(ArtifactKind.JIT, _platform_of(plan.triple), False);
    (merged, _exports) = whole_program_module(plan, spec);
    for lib_path in plan.clib_paths() {
        try {
            jit_load_clib(lib_path);
        } except Exception {}
    }
    engine = llvm.create_mcjit_compiler(merged, tm);
    assert isinstance(engine, llvm.ExecutionEngine);
    install_native_static_init(engine, plan.init_symbols());
    root = plan.root_unit();
    try {
        setattr(engine, "_jac_unit_path", root.path);
        setattr(engine, "_jac_native_iface", root.iface);
    } except Exception {}
    return engine;
}

"""The engine for `jac run` of a native module: the module is the root and
its closure comes from the registry."""
def jit_engine_for_module(
    prog: JacProgram, module: any, options: CompileOptions
) -> (ExecutionEngine | None) {
    if not (module?.loc and module.loc.mod_path) {
        return None;
    }
    if module.gen.native_iface is not None {
        prog.native_units().record(module.loc.mod_path, module.gen.native_iface, options);
    }
    plan = build_link_plan(prog, [module.loc.mod_path], options, mode=NATIVE_LINK_MODE_BITCODE);
    return jit_engine(plan);
}

"""The engine for a native module restored from its JIR: the same plan,
rooted at the cached entry."""
def jit_engine_for_cached(
    prog: JacProgram, path: str, options: CompileOptions
) -> (ExecutionEngine | None) {
    plan = build_link_plan(prog, [path], options, mode=NATIVE_LINK_MODE_BITCODE);
    return jit_engine(plan);
}
