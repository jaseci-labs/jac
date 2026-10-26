"""The kernel is one artifact the router resolves: the sealed image's
kernel, then the checkout's, then the kit's in place, each accepted only
when it was built from the sources this process runs; otherwise the
bytecode compiler serves and the router says so. Resolving never builds;
`jac native build kernel` does."""

import io;
import json;
import hashlib;
import os;
import sys;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.artifacts.model { Probe, Source }
import jaclang.artifacts.router as router;
import from jaclang.compiler.backends.native.kernel_resolve {
    KernelArtifact,
    KernelLoadError,
    ResolvedKernel,
    _inspect,
    kernel_options,
    read_sidecar,
    resolve_kernel,
    source_tree_kernel_path
}
import jaclang.compiler.backends.native.kernel_resolve as resolver;
import from jaclang.compiler.backends.native.link_plan { LinkResult }
import from jaclang.compiler.native_compiler { ensure_loaded, reset_loaded }

def _never(*args: any, **kwargs: any) -> any {
    raise AssertionError("resolving a kernel must never build or probe here");
}

def _toolchain(ok: bool = True) -> any {
    import jaclang.compiler.driver.toolchain as toolchain;
    return patch.object(
        toolchain,
        "native_pipeline_available",
        return_value=(ok, "" if ok else "no LLVM shim here")
    );
}

"""Resolve the kernel afresh with the sealed image out of the way and return
what resolved and what the router printed."""
def _resolve_fresh(sealed: bool = False) -> tuple[(ResolvedKernel | None), str] {
    err = io.StringIO();
    router.forget();
    reset_loaded();
    try {
        with patch.object(router, "_omitted", return_value=frozenset()) {
            with patch.object(
                resolver,
                "_from_sealed_image",
                return_value=(
                    ResolvedKernel(lib_path="shipped", layout={}, source="sealed")
                        if sealed
                        else None
                )
            ) {
                with patch.object(
                    resolver, "read_sidecar", return_value={"classes": {}}
                ) {
                    with patch.object(sys, "stderr", err) {
                        found = resolve_kernel();
                    }
                }
            }
        }
    } finally {
        router.forget();
        reset_loaded();
    }
    return (found, err.getvalue());
}

def _sidecar_for(lib: str, unit: str, **overrides: any) -> dict[str, any] {
    import from jaclang.compiler.driver.jir {
        running_compiler_digest,
        unit_source_digest
    }
    import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
    options = kernel_options();
    ident = native_unit_identity(unit);
    record = {
        "classes": {},
        "artifact_sha256": hashlib.sha256(Path(lib).read_bytes()).hexdigest(),
        "plan_digest": "p",
        "layout_digest": "l",
        "units": [unit],
        "unit_ids": [ident],
        "compiler_digest": running_compiler_digest(),
        "codegen_identity": options.base_codegen_identity(),
        "triple": options.effective_triple(),
        "python": f"{sys.version_info.major}.{sys.version_info.minor}",
        "unit_sources": {ident: unit_source_digest(unit)},
        "unit_policy": {ident: 0}
    };
    record.update(overrides);
    return record;
}

test "a sealed image runs its own kernel and never consults the checkout" {
    with patch.object(KernelArtifact, "probe_checkout", side_effect=_never) {
        (found, said) = _resolve_fresh(sealed=True);
    }
    assert found is not None
        and found.lib_path == "shipped"
        and found.source == "sealed";
    assert said == "";
}

"""A sealed image and a kit carry only their own target's kernel, so a kernel
for another target never resolves to the host's."""
test "another target's kernel never resolves to the sealed or kit kernel" {
    import from jaclang.compiler.target_spec { RELEASE_TARGETS, host_target_spec }
    host = host_target_spec().osarch;
    other = [
        t.osarch
        for t in RELEASE_TARGETS
        if t.osarch != host
    ][0];
    name = f"kernel@{other}";
    shipped = ResolvedKernel(lib_path="shipped", layout={}, source="sealed");
    router.forget();
    try {
        with _toolchain(), patch.object(router, "_omitted", return_value=frozenset()), patch.object(
            resolver, "_from_sealed_image", return_value=shipped
        ), patch.object(resolver, "read_sidecar", return_value={"classes": {}}), patch.object(
            resolver, "_bundled_kernel", side_effect=_never
        ), patch.object(
            KernelArtifact, "probe_checkout", return_value=Probe.missing()
        ) {
            artifact = router.artifact_named(name);
            assert artifact.probe_sealed() is None;
            assert artifact.probe_kit().found is None;
            resolution = router.resolve(name);
        }
    } finally {
        router.forget();
    }
    assert resolution.found is None , f"{name} resolved to {resolution.found}";
}

test "only a build that asks through JAC_KIT_OMIT leaves the kernel out" {
    import from jaclang.artifacts.kit { pr_kit_omits }
    with patch.dict(os.environ, {"JAC_KIT_OMIT": "kernel"}) {
        assert pr_kit_omits("kernel");
        assert not pr_kit_omits("llvm-shim");
    }
    with patch.dict(os.environ, {"JAC_KIT_OMIT": ""}) {
        assert not pr_kit_omits("kernel") , "an empty request omits nothing";
    }
    pr_event = {
        "GITHUB_ACTIONS": "true",
        "GITHUB_EVENT_NAME": "pull_request",
        "GITHUB_EVENT_PATH": "/nonexistent/event.json"
    };
    with patch.dict(os.environ, pr_event) {
        os.environ.pop("JAC_KIT_OMIT", None);
        assert not pr_kit_omits("kernel") , (
            "a release run on a merged pull request's event still carries its kernel"
        );
    }
}

"""Resolve the kernel when the sealed image (`sealed`) or the kit (`not
sealed`) leaves it out; return the resolution and what the router printed."""
def _resolve_omitted(sealed: bool) -> tuple[any, str] {
    def omitted(sealed_image: bool) -> frozenset[str] {
        return frozenset({"kernel"}) if sealed_image == sealed else frozenset();
    }
    router.forget();
    err = io.StringIO();
    try {
        with patch.object(router, "_omitted", side_effect=omitted), patch.object(
            KernelArtifact, "probe_sealed", return_value=None
        ), patch.object(
            KernelArtifact, "probe_checkout", return_value=Probe.missing()
        ), patch.object(KernelArtifact, "probe_kit", side_effect=_never), patch.object(
            sys, "stderr", err
        ), _toolchain() {
            resolution = router.resolve("kernel");
        }
    } finally {
        router.forget();
    }
    return (resolution, err.getvalue());
}

test "an image that leaves the kernel out runs from bytecode quietly, sealed or rerouted" {
    for sealed in (True, False) {
        (resolution, said) = _resolve_omitted(sealed);
        assert resolution.found is None and resolution.quiet;
        assert said == "" , "an omitted kernel runs from bytecode by design";
    }
}

test "the catalog build never loads a kernel" {
    with router.building(["stubcat"]) {
        with patch.object(KernelArtifact, "probe_checkout", side_effect=_never) {
            (found, said) = _resolve_fresh();
        }
    }
    assert found is None and said == "";
}

test "a stale checkout runs from bytecode, says so once, and never builds" {
    import jaclang.compiler.backends.native.kernel_stage0 as stage0;
    drift = Probe.stale(
        [
            "jaclang/compiler/frontend/unitree.jac changed",
            "jaclang/compiler/driver/jir.jac changed"
        ]
    );
    with _toolchain() {
        with patch.object(KernelArtifact, "probe_checkout", return_value=drift) {
            with patch.object(
                KernelArtifact, "probe_kit", return_value=Probe.missing()
            ) {
                with patch.object(stage0, "link_kernel", side_effect=_never) {
                    (found, said) = _resolve_fresh();
                }
            }
        }
    }
    assert found is None;
    assert said.count("kernel runs on its floor") == 1 , said;
    assert "unitree.jac changed (and 1 more)" in said , said;
    assert "jac native build kernel" in said , said;
}

test "a checkout without a native toolchain says why it runs from bytecode" {
    with _toolchain(ok=False) {
        with patch.object(KernelArtifact, "probe_checkout", side_effect=_never) {
            (found, said) = _resolve_fresh();
        }
    }
    assert found is None;
    assert "no LLVM shim here" in said , said;
}

test "a current checkout kernel loads silently and reports where it came from" {
    mine = Probe.hit(
        Source.CHECKOUT, "/tree/libjac_compiler.so", {"classes": {}, "plan_digest": "p"}
    );
    with _toolchain() {
        with patch.object(KernelArtifact, "probe_checkout", return_value=mine) {
            with patch.object(KernelArtifact, "probe_kit", side_effect=_never) {
                (found, said) = _resolve_fresh();
            }
        }
    }
    assert found is not None
        and found.source == "checkout"
        and found.plan_digest == "p";
    assert said == "";
}

"""Route a compile to the current checkout kernel at `lib` and return how it
stopped and what it printed. A kernel that does not load must stop the
command: nothing compiles, on the kernel or on the bytecode compiler."""
def _route_to(lib: str, check: bool = False) -> tuple[(KernelLoadError | None), str] {
    import jaclang.project.kernel_compile as kernel_compile;
    import jaclang.project.kernel_check as kernel_check;
    import from jaclang.compiler.driver.program { JacProgram }
    err = io.StringIO();
    app = os.path.join(tempfile.gettempdir(), "app.jac");
    mine = Probe.hit(Source.CHECKOUT, lib, {"classes": {}, "plan_digest": "p"});
    stopped: (KernelLoadError | None) = None;
    router.forget();
    reset_loaded();
    try {
        with _toolchain() {
            with patch.object(router, "_omitted", return_value=frozenset()) {
                with patch.object(resolver, "_from_sealed_image", return_value=None) {
                    with patch.object(
                        KernelArtifact, "probe_checkout", return_value=mine
                    ) {
                        with patch.object(
                            kernel_compile,
                            "kernel_compile_in_process",
                            return_value=False
                        ) {
                            with patch.object(sys, "stderr", err) {
                                try {
                                    if check {
                                        kernel_check.kernel_check(
                                            JacProgram(), app, kernel_options()
                                        );
                                    } else {
                                        kernel_compile.kernel_route(JacProgram(), app);
                                    }
                                } except KernelLoadError as e {
                                    stopped = e;
                                }
                            }
                        }
                    }
                }
            }
        }
    } finally {
        router.forget();
        reset_loaded();
    }
    return (stopped, err.getvalue());
}

def _assert_refused(lib: str, routed: tuple[(KernelLoadError | None), str]) {
    (stopped, said) = routed;
    assert stopped is not None , f"the command went on without its kernel: {said}";
    told = str(stopped.code);
    assert told.startswith("jac: the native compiler kernel cannot be loaded") , told;
    assert f"kernel: {lib}" in told , told;
    assert "jac native build kernel --force" in told , told;
    assert "runs on its floor" not in said , said;
}

test "a current kernel that does not load stops the command and says why" {
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        lib = os.path.join(tmp, "libjac_compiler.so");
        Path(lib).write_bytes(b"not a shared library");
        routed = _route_to(lib);
        checked = _route_to(lib, check=True);
    }
    _assert_refused(lib, routed);
    _assert_refused(lib, checked);
    assert "error:  " in str(routed[0]?.code) , routed[0];
}

test "a current kernel without the kernel's exports stops the command" {
    import _ctypes;
    lib = _ctypes?.__file__;
    if not lib {
        return;
    }
    routed = _route_to(lib);
    _assert_refused(lib, routed);
    assert "jac_str_new" in str(routed[0]?.code) , routed[0];
}

test "the sidecar reader wants a classes map" {
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        lib = os.path.join(tmp, "libjac_compiler.so");
        Path(lib + ".layout.json").write_text(json.dumps({"plan_digest": "x"}));
        assert read_sidecar(lib) is None;
        Path(lib + ".layout.json").write_text(
            json.dumps({"classes": {}, "plan_digest": "x", "layout_digest": "y"})
        );
        found = read_sidecar(lib);
        assert found is not None and found["plan_digest"] == "x";
    }
}

test "the source-tree kernel lives beside the loader" {
    path = source_tree_kernel_path();
    assert os.path.basename(os.path.dirname(path)) == "compiler";
    assert "jac_compiler" in os.path.basename(path);
}

test "a kernel is accepted by its units' content and names what moved" {
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        unit = os.path.join(tmp, "unit.jac");
        Path(unit).write_text("def one -> int {\n    return 1;\n}\n");
        lib = os.path.join(tmp, "libjac_compiler.dylib");
        Path(lib).write_bytes(b"not a real kernel");
        sidecar = _sidecar_for(lib, unit);
        def write(record: dict[str, any]) {
            Path(lib + ".layout.json").write_text(json.dumps(record));
        }
        write(sidecar);
        (accepted, drift) = _inspect(lib);
        assert accepted is not None and drift == [] , drift;
        Path(unit).write_text("def one -> int {\n    return 2;\n}\n");
        (accepted, drift) = _inspect(lib);
        assert accepted is None;
        assert len(drift) == 1 and drift[0].endswith("unit.jac changed") , drift;
        Path(unit).write_text("def one -> int {\n    return 1;\n}\n");
        assert _inspect(lib)[0] is not None;
        for (field, value) in [
            ("compiler_digest", "another compiler"),
            ("codegen_identity", "gc=none"),
            ("triple", "wasm32-unknown-unknown"),
            ("python", "2.7"),
            ("unit_policy", {native_unit_ident(unit): 1})
        ] {
            write({** sidecar, field: value});
            (accepted, drift) = _inspect(lib);
            assert accepted is None and len(drift) == 1 , f"a different {field}: {drift}";
        }
        without = dict(sidecar);
        without.pop("unit_sources");
        write(without);
        assert _inspect(lib)[0] is None , "a record without unit sources is never accepted";
        write(sidecar);
        Path(lib).write_bytes(b"a library the sidecar never described");
        assert _inspect(lib)[0] is None , "the sidecar vouches for one library";
        os.remove(lib);
        assert _inspect(lib) == (None, ["not built"]);
    }
}

def native_unit_ident(path: str) -> str {
    import from jaclang.compiler.frontend.codeinfo { native_unit_identity }
    return native_unit_identity(path);
}

test "a kernel built elsewhere is accepted by its units' package identity" {
    import from jaclang.compiler.driver.jir { sidecar_unit_paths }
    import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }
    unit = os.path.join(jaclang_pkg_root(), "compiler", "driver", "jir.jac");
    ident = native_unit_ident(unit);
    assert ident.startswith("jaclang/") , ident;
    elsewhere = os.path.join(
        "/build", "stage", "site", "jaclang", "compiler", "driver", "jir.jac"
    );
    resolved = sidecar_unit_paths({"units": [elsewhere], "unit_ids": [ident]});
    assert resolved == [unit] , (
        "a unit recorded at the build's path is found where this jaclang lives"
    );
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        lib = os.path.join(tmp, "libjac_compiler.dylib");
        Path(lib).write_bytes(b"not a real kernel");
        sidecar = _sidecar_for(lib, unit, units=[elsewhere]);
        Path(lib + ".layout.json").write_text(json.dumps(sidecar));
        assert _inspect(lib)[0] is not None , (
            "acceptance compares package identity and content, not the build's paths"
        );
    }
}

obj Image {
    has record: dict[str, any],
        native: dict[str, any] = {};

    def native_artifact -> dict[str, any] {
        return self.record;
    }
}

test "the kit's kernel runs in place although the kit stripped it after its sidecar was written" {
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        unit = os.path.join(tmp, "unit.jac");
        Path(unit).write_text("def one -> int {\n    return 1;\n}\n");
        site = os.path.join(tmp, "site", "jaclang");
        os.makedirs(os.path.join(site, "compiler"));
        bundled = os.path.join(site, "compiler", "libjac_compiler.dylib");
        Path(bundled).write_bytes(b"the stripped kernel");
        stripped = hashlib.sha256(Path(bundled).read_bytes()).hexdigest();
        sidecar = _sidecar_for(
            bundled,
            unit,
            artifact_sha256=hashlib.sha256(b"the kernel before strip").hexdigest()
        );
        Path(bundled + ".layout.json").write_text(json.dumps(sidecar));
        shipped = Image(
            record={"path": "compiler/libjac_compiler.dylib", "sha256": stripped}
        );
        with patch("jaclang.artifacts.kit.kit_image", return_value=(site, shipped)) {
            probe = KernelArtifact().probe_kit();
        }
        found = probe.found;
        assert found is not None , probe.drift;
        assert found.source == Source.KIT and found.path == bundled , (
            "the kit's kernel is loaded where the kit keeps it"
        );
        assert sorted(os.listdir(os.path.join(site, "compiler")))
            == ["libjac_compiler.dylib", "libjac_compiler.dylib.layout.json"] , (
            "running the kit's kernel writes nothing"
        );
        forged = Image(
            record={
                "path": "compiler/libjac_compiler.dylib",
                "sha256": "not this library"
            }
        );
        with patch("jaclang.artifacts.kit.kit_image", return_value=(site, forged)) {
            assert KernelArtifact().probe_kit().found is None , (
                "a kit whose library disagrees with its own manifest is never run"
            );
        }
    }
}

test "application configuration does not change the compiler kernel" {
    import from jaclang.project.config { JacConfig }
    import from jaclang.project.compiler_host { ProjectHost, project_defaults_of }
    import from jaclang.compiler.driver.compile_options {
        push_native_target,
        pop_native_target
    }
    before = kernel_options().codegen_identity();
    cfg = JacConfig();
    cfg.memory.profile = "nogc";
    cfg.memory.enforce = ["*"];
    cfg.native.debug = True;
    cfg.native.opt = 0;
    cfg.native.target = "aarch64-unknown-linux-gnu";
    prev = push_native_target(cfg.native.target);
    try {
        with patch.object(
            ProjectHost, "project_defaults", return_value=project_defaults_of(cfg)
        ) {
            assert CompileOptions().codegen_identity() != before;
            opts = kernel_options();
            assert opts.codegen_identity() == before;
            assert opts.memory_profile == "managed";
            assert not opts.nogc_enforce_all;
            assert opts.dump_ir_path == "";
        }
    } finally {
        pop_native_target(prev);
    }
}

test "kernel unit identity is independent of the caller compilation context" {
    import from jaclang.compiler.driver.compilation_context { cache_scope }
    import from jaclang.compiler.driver.jir { unit_source_digest }
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "unit.jac";
        source.write_text("def answer -> int { return 42; }\n");
        with cache_scope(CompileOptions(target_app="build-context")) {
            built = unit_source_digest(str(source));
        }
        with cache_scope(CompileOptions(target_app="application-context")) {
            assert unit_source_digest(str(source)) == built;
        }
    }
}

test "a kernel build publishes its library and sidecar and sweeps its stage" {
    import jaclang.compiler.backends.native.kernel_stage0 as stage0;
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        lib = os.path.join(tmp, "libjac_compiler.so");
        def fake_link(destination: str, **kwargs: any) -> LinkResult {
            Path(destination).write_bytes(b"fresh kernel");
            Path(destination + ".layout.json").write_text(json.dumps({"classes": {}}));
            Path(destination + ".target.json").write_text(json.dumps({"units": []}));
            return LinkResult(
                output_path=destination, plan_digest="p", layout_digest="l", sha256="s"
            );
        }
        with patch.object(stage0, "link_kernel", side_effect=fake_link) {
            result = resolver.build_kernel(lib);
        }
        assert result.output_path == lib , "the result names the published kernel";
        assert Path(lib).read_bytes() == b"fresh kernel";
        assert read_sidecar(lib) is not None , "the published sidecar travels with the library";
        assert sorted(p.name for p in Path(tmp).iterdir())
            == [
                "libjac_compiler.so",
                "libjac_compiler.so.layout.json",
                "libjac_compiler.so.lock"
            ] , ("the stage file, its layout sidecar, and its target spec are swept");
    }
}

test "a failed kernel build publishes nothing and sweeps its stage" {
    import jaclang.compiler.backends.native.kernel_stage0 as stage0;
    with tempfile.TemporaryDirectory(prefix="jac-kernel-") as tmp {
        lib = os.path.join(tmp, "libjac_compiler.so");
        def dead_link(destination: str, **kwargs: any) {
            Path(destination).write_bytes(b"torn kernel");
            Path(destination + ".layout.json").write_text(json.dumps({"classes": {}}));
            Path(destination + ".target.json").write_text(json.dumps({"units": []}));
            raise RuntimeError("link died");
        }
        raised = False;
        with patch.object(stage0, "link_kernel", side_effect=dead_link) {
            try {
                resolver.build_kernel(lib);
            } except RuntimeError {
                raised = True;
            }
        }
        assert raised , "a failed build surfaces its error";
        assert list(Path(tmp).iterdir()) == [] , (
            "an interrupted build leaves no stage file, sidecar, or target spec behind"
        );
    }
}

def _check_job(request: dict[(str, any)]) -> any {
    import jaclang.project.kernel_check as kernel_check;
    import from jaclang.compiler.driver.program { JacProgram }
    kernel_check.kernel_check(
        JacProgram(),
        os.path.join(tempfile.gettempdir(), f"app_{request['path']}.jac"),
        kernel_options()
    );
}

test "a loaded kernel without jc_analyze stops a multi-file check once" {
    import types;
    import jaclang.compiler.native_compiler as native_compiler;
    import from jaclang.cli.workpool { WorkPool }
    lib = os.path.join(tempfile.gettempdir(), "libjac_compiler.so");
    kernel = types.SimpleNamespace(lib=object(), lib_path=lib);
    recorded: list[int] = [];
    pool = WorkPool(
        items=["a", "b", "c"],
        job=_check_job,
        on_record=lambda (idx: int, record: dict[(str, any)]) { recorded.append(idx); }
    );
    stopped: (KernelLoadError | None) = None;
    with patch.object(native_compiler, "ensure_loaded", return_value=kernel) {
        try {
            pool.run_inline();
        } except KernelLoadError as e {
            stopped = e;
        }
    }
    assert stopped is not None , "the check went on without its kernel's jc_analyze";
    told = str(stopped.code);
    assert told.startswith("jac: the native compiler kernel cannot analyze") , told;
    assert f"kernel: {lib}" in told and "has no jc_analyze" in told , told;
    assert "jac native build kernel --force" in told , told;
    assert recorded == [] , recorded;
}

"""A kernel plan whose entry unit demoted `jc_analyze`, through a chain of
two more units, and kept `jc_run` and `jc_reg_seal`."""
def _entry_plan(pkg_root: str) -> any {
    import from jaclang.compiler.backends.native.link_plan { LinkPlan, LinkUnit }
    import from jaclang.compiler.driver.native_iface { NativeExport, NativeIface }
    import from jaclang.compiler.driver.program { JacProgram }
    compiler_dir = os.path.join(pkg_root, "compiler");
    os.makedirs(compiler_dir, exist_ok=True);
    Path(compiler_dir, "jc_unit.jac").write_text(
        "def:pub jc_run(source: str) -> int { return 0; }\n"
            + "def:pub jc_analyze(inputs: str) -> int { return run_kernel_analysis(inputs); }\n"
            + "def helper -> int { return 1; }\n"
    );
    Path(compiler_dir, "jc_materialize.jac").write_text(
        "def:pub jc_reg_seal -> int { return 0; }\n"
    );
    def unit(
        rel: str, exports: list[str], demoted: list[str], deps: list[str]
    ) -> LinkUnit {
        path = os.path.realpath(os.path.join(pkg_root, rel));
        iface = NativeIface(
            module=rel,
            prefix=os.path.basename(rel).split(".")[0],
            exports={
                name: NativeExport(
                    name=name, symbol=name, kind="function", is_pub=True
                ) for name in exports
            },
            demoted=demoted,
            deps=[os.path.realpath(os.path.join(pkg_root, d)) for d in deps]
        );
        return LinkUnit(path=path, prefix=iface.prefix, iface=iface, digest=rel);
    }
    units = [
        unit(
            "compiler/jc_unit.jac",
            ["jc_run"],
            ["jc_analyze"],
            ["compiler/kernel_analyze.jac"]
        ),
        unit("compiler/jc_materialize.jac", ["jc_reg_seal"], [], []),
        unit(
            "compiler/kernel_analyze.jac",
            [],
            ["run_kernel_analysis"],
            ["compiler/unit_products.jac"]
        ),
        unit("compiler/unit_products.jac", [], ["jac_dependencies"], [])
    ];
    return LinkPlan(
        prog=JacProgram(),
        options=kernel_options(),
        roots=[units[0].path],
        units=units,
        mode="objects",
        triple="x86_64-unknown-linux-gnu"
    );
}

test "a kernel plan that demoted an entry point names it and the chain that demoted it" {
    import from jaclang.compiler.backends.native.kernel_stage0 {
        KernelEntryError,
        declared_entry_points,
        missing_kernel_entries,
        refuse_missing_entries
    }
    assert declared_entry_points(
        "def:pub jc_a(x: int) -> int { return x; }\ndef jc_b -> int { return 1; }\n"
            + "    def:pub nested -> int { return 2; }\ndef:pub jc_c -> int { return 3; }\n"
    )
        == ["jc_a", "jc_c"];
    with tempfile.TemporaryDirectory(prefix="jac-kernel-entries-") as tmp {
        pkg_root = os.path.join(tmp, "jaclang");
        plan = _entry_plan(pkg_root);
        reasons = {
            os.path.realpath(os.path.join(pkg_root, "compiler/jc_unit.jac")): {
                "jc_analyze": "jaclang/compiler/jc_unit.jac, line 2, col 52: Native lowering failed for function 'run_kernel_analysis'"
            },
            os.path.realpath(os.path.join(pkg_root, "compiler/kernel_analyze.jac")): {
                "run_kernel_analysis": "jaclang/compiler/kernel_analyze.jac, line 9, col 5: Native lowering failed for function 'jac_dependencies'"
            },
            os.path.realpath(os.path.join(pkg_root, "compiler/unit_products.jac")): {
                "jac_dependencies": "jaclang/compiler/unit_products.jac, line 4, col 26: Native lowering failed for method 'resolve_relative_path (on an `any` receiver)'"
            }
        };
        problems = missing_kernel_entries(
            plan,
            pkg_root,
            lambda (path: str) -> dict[str, str] { return reasons.get(path, {}); }
        );
        assert len(problems) == 1 , problems;
        told = problems[0];
        assert told.startswith(
            "jc_analyze is not exported; it was demoted to Python:"
        ) , told;
        steps = told.split("\n")[1:];
        assert len(steps) == 3 , told;
        assert "jc_analyze (jaclang/compiler/jc_unit.jac)" in steps[0] , told;
        assert "run_kernel_analysis (jaclang/compiler/kernel_analyze.jac)" in steps[1]
            and steps[1].strip().startswith("<- ") , told;
        assert "jac_dependencies (jaclang/compiler/unit_products.jac)" in steps[2]
            and "resolve_relative_path (on an `any` receiver)" in steps[2] , told;
        refused = "";
        with patch(
            "jaclang.compiler.backends.native.kernel_stage0.unit_issue_details",
            return_value=lambda (path: str) -> dict[str, str] { return reasons.get(
                path, {}
            ); }
        ) {
            try {
                refuse_missing_entries(plan, pkg_root);
            } except KernelEntryError as e {
                refused = str(e);
            }
        }
        assert refused.startswith(
            "the native compiler kernel would not export the entry points its loader calls:"
        ) , refused;
        assert "jc_analyze is not exported" in refused , refused;
    }
}
