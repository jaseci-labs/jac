"""Code generation runs inside the native compiler kernel.

`jc_compile` takes the host's `KernelInputs` snapshot and runs the entry's
whole pipeline (analysis and the code generators) behind a kernel-side
`KernelHost`, returning one `UnitProducts` record per compiled module. The
record must equal what the host's own compile of the same module produces:
the same JCIR, interop, client artifact, placement summary and MTIR graph.
The in-process cases run the kernel's code under Python and need no kernel
lib; the native cases skip where no kernel with `jc_compile` is loaded."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.unit_products { UnitProducts, unit_products }
import from jaclang.compiler.frontend.host { active_host }
import from jaclang.compiler.frontend.kernel_analyze {
    ANALYSIS_BLOCKED,
    ANALYSIS_OK,
    AnalysisReport,
    CompileReport,
    run_kernel_compile
}
import from jaclang.project.kernel_snapshot {
    COMPILE_ENTRY,
    call_with_asker,
    kernel_snapshot
}

glob CONFIG: str = '[project]\nname="kernel-compile"\n';

"""An annexed Jac module, a local Python module, a node, a walker and an
endpoint-shaped function in the entry, and a second entry with a type
error."""
def write_project(base: Path) {
    (base / 'jac.toml').write_text(CONFIG);
    (base / 'util.jac').write_text(
        'import os;\ndef helper(x: int) -> int;\nobj Point { has x: int = 0; }\n'
    );
    (base / 'util.impl.jac').write_text(
        'impl helper(x: int) -> int { return x + len(os.sep); }\n'
    );
    (base / 'pyhelp.py').write_text('def twice(x: int) -> int:\n    return 2 * x\n');
    (base / 'main.jac').write_text(
        'import from util { helper, Point }\n'
            + 'import from pyhelp { twice }\n'
            + 'node Item { has label: str = ""; }\n'
            + 'walker Tally { has total: int = 0;\n'
            + '    can count with Item entry { self.total += len(here.label); }\n'
            + '}\n'
            + 'def:pub go(n: int) -> int { return helper(Point(x=n).x) + twice(n); }\n'
            + 'with entry { root ++> Item(label="ab"); print(go(3)); }\n'
    );
    (base / 'broken.jac').write_text(
        'import from util { helper }\nwith entry { x: str = helper(1); }\n'
    );
}

def compile_options -> CompileOptions {
    return CompileOptions(skip_native_engine=True);
}

"""What the host's own compile of `entry_file` produces, as the record a kernel
compile returns for it."""
def host_products(entry_file: str) -> UnitProducts {
    program = JacProgram();
    module = program.compile(entry_file, options=compile_options());
    assert not program.errors_had , [str(e) for e in program.errors_had];
    return unit_products(module, program);
}

"""Run the kernel's compile code under Python, the host answering what it asks."""
def compile_in_process(entry_file: str) -> CompileReport {
    session = kernel_snapshot(
        active_host(), JacProgram(), entry_file, compile_options()
    );
    return run_kernel_compile(session.text(), entry_file, None, session);
}

"""Run the native kernel's compile, the host answering what it asks."""
def compile_natively(kernel: any, entry_file: str) -> CompileReport {
    session = kernel_snapshot(
        active_host(), JacProgram(), entry_file, compile_options()
    );
    return CompileReport.from_json(
        call_with_asker(kernel, COMPILE_ENTRY, session, entry_file, None, False)
    );
}

def assert_same_products(kernel: UnitProducts, host: UnitProducts) {
    assert kernel.jcir == host.jcir , "the kernel's JCIR differs from the host's";
    assert kernel.interop == host.interop;
    assert kernel.client == host.client;
    assert kernel.placement == host.placement;
    assert kernel.mtir == host.mtir;
    assert sorted(kernel.ct_file_deps) == sorted(host.ct_file_deps);
}

test "the kernel's compile code run in process emits the host's products" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        expected = host_products(entry_file);
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None , [u.path for u in outcome.units];
        assert emitted.jcir , "the kernel compiled the entry but emitted no JCIR";
        assert_same_products(emitted, expected);
    }
}

test "a compile report survives its JSON crossing" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        outcome = compile_in_process(entry_file);
        crossed = CompileReport.from_json(outcome.to_json());
        emitted = outcome.unit(entry_file);
        restored = crossed.unit(entry_file);
        assert emitted is not None and restored is not None;
        assert_same_products(restored, emitted);
        assert crossed.analysis.to_json() == outcome.analysis.to_json();
    }
}

test "an entry with type errors reports them and emits no unit" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'broken.jac');
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_BLOCKED;
        assert outcome.analysis.errors;
        assert outcome.unit(entry_file) is None;
    }
}

def loaded_kernel -> any {
    import from jaclang.compiler.native_compiler { ensure_loaded }
    kernel = ensure_loaded();
    if kernel is None or not hasattr(kernel.lib, "jc_compile") {
        return None;
    }
    return kernel;
}

test "the native jc_compile emits the host's products" {
    kernel = loaded_kernel();
    if kernel is None {
        return;
    }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        expected = host_products(entry_file);
        outcome = compile_natively(kernel, entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
    }
}

test "get_bytecode adopts a kernel compile and keeps no host tree" {
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.jir { SEC_BYTECODE, read_section_bytes }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        program = JacProgram();
        with patch.dict(os.environ, {"JAC_KERNEL_COMPILE": "inprocess"}) {
            code = program._get_compiler().get_bytecode(entry_file, program);
        }
        assert code is not None;
        assert program.find_module(entry_file) is None , "the host compiled the entry";
        written = sorted((base / '.jac' / 'cache').rglob('main.*.jir'));
        assert written , "the adopted unit was not persisted";
        assert read_section_bytes(written[0].read_bytes(), SEC_BYTECODE);
        names = set(code.co_names);
        assert "go" in names or "Tally" in names , sorted(names);
    }
}

"""A client component makes the ES pass register the framework runtime module
even though the source never imports it, so the snapshot has to carry that
module's path; a kernel compile then emits the host's client artifact."""
test "a client module compiles in the kernel with the host's products" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'app.jac').write_text(
            'def:pub greet(name: str) -> str { return "hi " + name; }\n\n'
                + 'def:pub app -> JsxElement {\n'
                + '    has label: str = "";\n'
                + '    async can with entry { label = await greet("you"); }\n'
                + '    return <div>{label}</div>;\n}\n'
        );
        entry_file = str(base / 'app.jac');
        expected = host_products(entry_file);
        assert expected.client is not None , "the fixture compiled no client code";
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
    }
}

"""A client module importing `@jac/runtime` makes the type evaluator ask for
the declaration file beside the virtual module, so the snapshot has to answer
that question too; a kernel compile then misses nothing."""
test "a client module importing a virtual Jac module compiles in the kernel" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'app.jac').write_text(
            'import from "@jac/runtime" { jacIsLoggedIn }\n\n'
                + 'def:pub app -> JsxElement {\n'
                + '    return <div>{"in" if jacIsLoggedIn() else "out"}</div>;\n}\n'
        );
        entry_file = str(base / 'app.jac');
        expected = host_products(entry_file);
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
    }
}

"""The arch file weaves an import into each consumer it wires, attributed to
the arch file, so the snapshot has to learn the resolutions that woven text
asks for and not only the arch file's own imports."""
test "a module wired by the arch file compiles in the kernel" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'arch.jac').write_text(
            'impl import {\n    edge CoreInternal: core.* --> core.*;\n}\n\n'
                + 'impl import core {\n    util --> core.svc { Spark }\n}\n'
        );
        (base / 'core').mkdir();
        (base / 'core' / 'util.jac').write_text(
            'obj Spark {\n    has x: int = 0;\n}\n'
        );
        (base / 'core' / 'svc.jac').write_text(
            'def serve -> int {\n    return Spark(x=1).x;\n}\n'
        );
        entry_file = str(base / 'core' / 'svc.jac');
        expected = host_products(entry_file);
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
        arch_file = str(base / 'arch.jac');
        checked = compile_in_process(arch_file);
        assert checked.analysis.status == ANALYSIS_OK , checked.analysis.message;
        assert not checked.analysis.misses , checked.analysis.misses;
    }
}

"""The native kernel sees jaclang's own modules only through their interfaces,
which carry no bodies, so placement must not read an import from one as free
to pull into client code; the host, which sees the body, keeps it on the
server."""
test "a server-side comptime import beside client code stays on the server" {
    kernel = loaded_kernel();
    if kernel is None {
        return;
    }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(
            '[project]\nname="kernel-web"\nentry-point="app"\nkind="web-app"\n'
        );
        (base / 'app.jac').write_text(
            'import from jaclang.comptime { fields, get_field }\n\n'
                + 'def:pub app -> JsxElement {\n    return <div>hi</div>;\n}\n\n'
                + 'obj Item {\n    has name: str = "", qty: int = 0;\n}\n\n'
                + 'walker Copy {\n    can go with Root entry {\n'
                + '        src = Item(name="a", qty=1);\n'
                + '        out: dict[str, str] = {};\n'
                + '        comptime for f in fields(Item) {\n'
                + '            out[f.name] = str(get_field(src, f.name));\n'
                + '        }\n        report out;\n    }\n}\n'
        );
        entry_file = str(base / 'app.jac');
        expected = host_products(entry_file);
        outcome = compile_natively(kernel, entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.errors , [str(e) for e in outcome.analysis.errors];
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
    }
}

"""An import of `urllib.error` loads the empty `urllib/__init__.pyi`, which the
stub catalog has to carry like any other stub."""
test "an import of a stdlib package with an empty stub compiles in the kernel" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'main.jac').write_text(
            'import urllib.error;\n\n'
                + 'def fetch(name: str) -> str {\n'
                + '    try {\n        return name.strip();\n'
                + '    } except urllib.error.URLError {\n        return "";\n    }\n}\n'
        );
        entry_file = str(base / 'main.jac');
        expected = host_products(entry_file);
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
    }
}

def write_application(base: Path) {
    (base / 'jac.toml').write_text(CONFIG);
    (base / 'util.jac').write_text(
        'def helper(x: int) -> int { return x + 1; }\n'
            + 'walker:pub Ping { can go with Root entry { report helper(1); } }\n'
    );
    (base / 'deep.jac').write_text('def:pub twice(x: int) -> int { return x * 2; }\n');
    (base / 'arch.jac').write_text(
        'impl import {\n    edge SideInternal: side.* --> side.*;\n}\n\n'
            + 'impl import side {\n    tool --> side.user { Wrench }\n}\n'
    );
    (base / 'side').mkdir();
    (base / 'side' / 'tool.jac').write_text(
        'obj Wrench {\n    has size: int = 0;\n}\n'
    );
    (base / 'side' / 'user.jac').write_text(
        'def turn -> int {\n    return Wrench(size=1).size;\n}\n'
    );
    (base / 'main.jac').write_text(
        'import from util { helper }\ninclude deep;\n'
            + 'node Item { has label: str = ""; }\n'
            + 'def:pub go(n: int) -> int { return helper(n) + twice(n); }\n'
            + 'def quiet(n: int) -> int { return n; }\n'
            + 'with entry { print(go(3)); }\n'
    );
}

"""What a prepared application exposes, with its directory normalized away:
each manifest and the names every module's code binds."""
def prepared_view(base: Path, in_kernel: bool) -> dict[str, any] {
    import json;
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.application { prepare_application }
    import jaclang.project.kernel_compile as kernel_compile_mod;
    write_application(base);
    entry_file = str(base / 'main.jac');
    def host_only(program: JacProgram, path: str) -> tuple[bool, bool] {
        return (False, False);
    }
    def in_process(program: JacProgram, path: str) -> tuple[bool, bool] {
        return (not program.internal, True);
    }
    route = in_process if in_kernel else host_only;
    sessions: list[str] = [];
    compile_reported = kernel_compile_mod.kernel_compile_reported;
    def counted(*args: any, **kwargs: any) -> any {
        sessions.append(str(args[2]));
        return compile_reported(*args, **kwargs);
    }
    with patch.object(kernel_compile_mod, "kernel_route", route) {
        with patch.object(kernel_compile_mod, "kernel_compile_reported", counted) {
            prepared = prepare_application(entry_file, JacProgram(), str(base));
        }
    }
    prefix = str(base);
    return {
        "sessions": len(sessions),
        "manifests": json.loads(
            json.dumps(prepared.manifests, sort_keys=True, `default=str).replace(
                prefix, "<app>"
            )
        ),
        "code": {
            path.replace(prefix, "<app>"): sorted(code.co_names)
            for (path, code) in prepared.code.items()
        }
    };
}

"""`jac run` and `serve` prepare an application: every project module's code
and the manifest of what it serves. One kernel session emits a unit per
module, and the manifest is built from those units as it is from the host's
trees. The project's arch file wires modules the entry never imports; the
host's scan sees them, and they are no part of this application."""
test "an application prepares from one kernel session as it does on the host" {
    with TemporaryDirectory() as host_dir {
        with TemporaryDirectory() as kernel_dir {
            expected = prepared_view(Path(os.path.realpath(host_dir)), False);
            observed = prepared_view(Path(os.path.realpath(kernel_dir)), True);
            assert expected["sessions"] == 0 and observed["sessions"] == 1 , (
                expected["sessions"],
                observed["sessions"]
            );
            assert len(expected["code"]) == 3 , sorted(expected["code"]);
            assert observed["code"] == expected["code"];
            surface = expected["manifests"]["<app>/main.jac"]["surface"];
            assert "go" in surface and "twice" in surface and "Ping" in surface , sorted(
                surface
            );
            assert observed["manifests"] == expected["manifests"];
        }
    }
}

"""A module that names a Jac builtin gets `from jaclang.runtime.builtin import`
in its bytecode. The generator finds builtins by set membership, and in the
native kernel a set declared without an element type compares strings by
identity, so the import was dropped and the name failed at run time."""
test "a module using Jac builtins compiles in the kernel with their import" {
    kernel = loaded_kernel();
    if kernel is None {
        return;
    }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'main.jac').write_text(
            'def boom { raise RuntimeError("x"); }\n\n'
                + 'def probe -> str {\n'
                + '    with testraises(RuntimeError) as caught {\n        boom();\n    }\n'
                + '    return str(caught);\n}\n\n'
                + 'with entry { printgraph(root); }\n'
        );
        entry_file = str(base / 'main.jac');
        expected = host_products(entry_file);
        outcome = compile_natively(kernel, entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
    }
}

"""An annex in an `impl/` folder resolves its imports from the folder of the
module it belongs to, so the snapshot has to learn a jaclang import there as
well as beside the annex file."""
test "a jaclang import in an impl folder annex compiles in the kernel" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'ver.jac').write_text('def newer(a: str, b: str) -> bool;\n');
        (base / 'impl').mkdir();
        (base / 'impl' / 'ver.impl.jac').write_text(
            'import from jaclang.packages.semver { Version }\n\n'
                + 'impl newer(a: str, b: str) -> bool {\n'
                + '    return Version.parse(a) > Version.parse(b);\n}\n'
        );
        entry_file = str(base / 'ver.jac');
        expected = host_products(entry_file);
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
    }
}

"""A kernel compile can come back with no unit for the entry. If the kernel
reported errors, the module is compiled and failed, and the host must not
compile it again. Otherwise the kernel emitted nothing because the module is
not its to emit (one placed in the native codespace, whose code the host
generates) or has nothing to emit (an empty package `__init__`), and the
host compiles it."""
test "a kernel compile with no unit is final only when it reported errors" {
    import from unittest.mock { patch }
    import from jaclang.compiler.frontend.kernel_analyze {
        AnalysisDiag,
        AnalysisReport,
        ModuleReport
    }
    import jaclang.project.kernel_compile as kernel_compile_mod;
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        entry_file = str(base / 'test_smoke.jac');
        Path(entry_file).write_text('test "arithmetic" { assert 6 * 7 == 42; }\n');
        program = JacProgram();
        compiler = program._get_compiler();
        failed = [AnalysisDiag(code="E1001", message="x", path=entry_file, line=1)];
        for (placed_native, errors, expect_handled) in [
            (True, [], False),
            (False, [], False),
            (False, failed, True),
            (True, failed, False)
        ] {
            canned = CompileReport(
                analysis=AnalysisReport(
                    entry_path=entry_file,
                    modules=[ModuleReport(path=entry_file, native=placed_native)],
                    errors=list(errors)
                )
            );
            def answer(*args: any, **kwargs: any) -> CompileReport {
                return canned;
            }
            with patch.object(kernel_compile_mod, "host_kernel_compile", answer) {
                (handled, code) = compiler._adopt_kernel_compile(
                    entry_file, program, compile_options()
                );
            }
            assert handled == expect_handled , (placed_native, len(errors), handled);
            assert code is None;
        }
    }
}

"""A module placed in the native codespace resolves `import time` to the
module the native stdlib ships, which the snapshot does not carry: native
code is the host's to generate. A kernel compile that stops only for want
of answers about native stdlib modules hands the module to the host."""
test "a kernel compile that misses only native stdlib answers defers to the host" {
    import from jaclang.compiler.frontend.codeinfo { native_stdlib_root }
    import from jaclang.project.kernel_snapshot { native_stdlib_misses }
    stdlib_dir = native_stdlib_root();
    assert stdlib_dir , "this build has no native stdlib";
    inside = "project_facts: " + os.path.join(str(stdlib_dir), "time.jac");
    assert native_stdlib_misses([inside]);
    assert native_stdlib_misses(
        [inside, "compile_module: " + os.path.join(str(stdlib_dir), "os", "path.jac")]
    );
    assert not native_stdlib_misses([]);
    assert not native_stdlib_misses([inside, "resolve_module: 0 | sys | /tmp/x.jac"]);
    import from jaclang.compiler.frontend.kernel_analyze { ANALYSIS_CRASHED }
    import from jaclang.project.kernel_snapshot { host_deferred }
    assert host_deferred(
        AnalysisReport(
            status=ANALYSIS_CRASHED,
            message=": integer overflow (in TypeCheckPass at /tmp/x.jac:67:17)"
        )
    ) , "a literal past a native int is the host's to check";
    assert not host_deferred(
        AnalysisReport(status=ANALYSIS_CRASHED, message="KeyError: 'code'")
    );
    assert not host_deferred(AnalysisReport());
    third_party = "parse_python: /opt/py/lib/python3.14/site-packages/litellm/__init__.py";
    assert host_deferred(
        AnalysisReport(
            status=ANALYSIS_CRASHED, message="HostOnlyError", misses=[third_party]
        )
    ) , "third-party Python source is the host's to parse";
    assert host_deferred(AnalysisReport(misses=[inside, third_party]));
    assert not host_deferred(
        AnalysisReport(misses=["parse_python: /srv/app/local_helper.py"])
    );
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        entry_file = str(base / 'clock.jac');
        Path(entry_file).write_text('def tick -> int { return 1; }\n');
        missed = CompileReport(
            analysis=AnalysisReport(entry_path=entry_file, misses=[inside])
        );
        import from unittest.mock { patch }
        import jaclang.project.kernel_compile as kernel_compile_mod;
        def run_missed(*args: any, **kwargs: any) -> CompileReport {
            return missed;
        }
        with patch.object(kernel_compile_mod, "run_kernel_compile", run_missed) {
            deferred = kernel_compile_mod.kernel_compile(
                active_host(),
                JacProgram(),
                entry_file,
                compile_options(),
                in_process=True
            );
        }
        placed = deferred.analysis.module(entry_file);
        assert placed is not None and placed.native;
        assert not deferred.units;
    }
}

"""A sealed runtime serves jaclang's own modules as interfaces, so the
snapshot builds a module's interface from one that was already decoded. A
field's default is recorded on the symbol the catalog decoded, not on a
syntax node, and the writer has to carry it over: without it every
constructor call that relied on a default was reported as missing
arguments (E1050)."""
test "an interface rebuilt from a decoded interface keeps field defaults" {
    import from unittest.mock { patch }
    import jaclang;
    import jaclang.project.kernel_snapshot as snapshot_mod;
    import from jaclang.compiler.driver.compilation_context { program_for }
    import from jaclang.compiler.frontend.kernel_inputs { PythonInterface }
    import from jaclang.compiler.types.stubcat.writer { build_module_iface }
    options_file = os.path.realpath(
        os.path.join(
            os.path.dirname(str(jaclang.__file__)),
            "compiler",
            "driver",
            "compile_options.jac"
        )
    );
    built = snapshot_mod.python_interface;
    rebuilt: list[str] = [];
    def through_decoded(
        path: str, options: CompileOptions, scratch: (JacProgram | None) = None
    ) -> (PythonInterface | None) {
        iface = built(path, options, scratch);
        if iface is None or os.path.realpath(path) != options_file {
            return iface;
        }
        owner = program_for(options_file, scratch or JacProgram());
        registry = owner.iface_registry();
        cached = registry.ensure(options_file);
        assert cached is not None , "compile_options has no cached interface";
        with registry._compilation_scope() {
            decoded = registry._materialize(cached);
        }
        rebuilt.append(type(decoded).__name__);
        return PythonInterface(
            path=iface.path,
            pkg_dir=iface.pkg_dir,
            data=build_module_iface(decoded, owner.get_type_evaluator(), iface.pkg_dir)
        );
    }
    def uncached(path: str) -> (PythonInterface | None) {
        return None;
    }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'main.jac').write_text(
            'import from jaclang.compiler.driver.compile_options { CompileOptions }\n\n'
                + 'def make -> CompileOptions {\n'
                + '    return CompileOptions(skip_native_engine=True);\n}\n'
        );
        entry_file = str(base / 'main.jac');
        with patch.object(snapshot_mod, "python_interface", through_decoded) {
            with patch.object(snapshot_mod, "cached_interface", uncached) {
                outcome = compile_in_process(entry_file);
            }
        }
        assert rebuilt == ["CatModule"] , rebuilt;
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.errors , [
            e.message for e in outcome.analysis.errors
        ];
    }
}

"""A graph expression makes the compiler add an import of the shared graph
runtime that the source never wrote, so the snapshot has to learn that
import for any module with one."""
test "a module with a graph expression compiles in the kernel" {
    import jaclang;
    import shutil;
    fixture = os.path.join(
        os.path.dirname(str(jaclang.__file__)),
        "compiler",
        "tests",
        "fixtures",
        "osp_graph_fragment.jac"
    );
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        entry_file = str(base / 'osp_graph_fragment.jac');
        shutil.copyfile(fixture, entry_file);
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
    }
}

"""An application with client code or pages prepares on the host, with the
program's context. Its module compiles stay there too: the kernel, asked
for one module of such an application without that context, cannot build
the module's client product."""
test "an application being prepared on the host keeps its module compiles there" {
    import from unittest.mock { patch }
    import jaclang.project.kernel_compile as kernel_compile_mod;
    with TemporaryDirectory() as td {
        entry_file = str(Path(os.path.realpath(td)) / 'main.jac');
        with patch.dict(os.environ, {"JAC_KERNEL_COMPILE": "inprocess"}) {
            assert kernel_compile_mod.kernel_route(JacProgram(), entry_file)
                == (True, True);
            kernel_compile_mod.host_preparing(entry_file);
            try {
                assert kernel_compile_mod.kernel_route(JacProgram(), entry_file)
                    == (False, False);
            } finally {
                kernel_compile_mod.host_prepared();
            }
            assert kernel_compile_mod.kernel_route(JacProgram(), entry_file)
                == (True, True);
        }
    }
}

"""The kernel starts from the facts every session needs and asks the host for
the rest while it runs: an import's resolution, a path's project, a module's
interface. The answers arrive inside the one run, so nothing is compiled
twice and no question is guessed at up front."""
test "a kernel compile asks the host for what it lacks and runs once" {
    import jaclang.project.kernel_compile as kernel_compile_mod;
    import from unittest.mock { patch }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        seed = kernel_snapshot(
            active_host(), JacProgram(), entry_file, compile_options()
        ).inputs();
        assert not seed.imports , "the session's starting inputs resolved an import";
        asked: list[str] = [];
        take_session = kernel_compile_mod.kernel_snapshot;
        def listening(*args: any, **kwargs: any) -> any {
            session = take_session(*args, **kwargs);
            answer = session.ask;
            def recorded(method: str, key: str) -> str {
                asked.append(method);
                return answer(method, key);
            }
            session.ask = recorded;
            return session;
        }
        runs: list[str] = [];
        run_compile = kernel_compile_mod.run_kernel_compile;
        def counted(*args: any, **kwargs: any) -> any {
            runs.append(str(args[1]));
            return run_compile(*args, **kwargs);
        }
        with patch.object(kernel_compile_mod, "kernel_snapshot", listening) {
            with patch.object(kernel_compile_mod, "run_kernel_compile", counted) {
                outcome = kernel_compile_mod.kernel_compile(
                    active_host(),
                    JacProgram(),
                    entry_file,
                    compile_options(),
                    in_process=True
                );
            }
        }
        assert len(runs) == 1 , runs;
        assert "resolve_module" in asked , asked;
        assert "compile_module" in asked , asked;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, host_products(entry_file));
    }
}

"""An application with a client prepares on the host, and its service apps
are part of that application. Preparing each service through its own kernel
session paid a full snapshot per service for modules the host had already
compiled."""
test "the services of a client application prepare on the host with it" {
    import from unittest.mock { patch }
    import from jaclang.compiler.driver.application { prepare_application }
    import jaclang.project.kernel_compile as kernel_compile_mod;
    def in_process(program: JacProgram, path: str) -> tuple[bool, bool] {
        return (not program.internal, True);
    }
    def sessions_for(base: Path, client: bool) -> list[str] {
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'main.jac').write_text('def:pub home -> int { return 1; }\n');
        (base / 'svc.jac').write_text('def:pub ping -> int { return 2; }\n');
        sessions: list[str] = [];
        compile_reported = kernel_compile_mod.kernel_compile_reported;
        def counted(*args: any, **kwargs: any) -> any {
            sessions.append(str(args[2]));
            return compile_reported(*args, **kwargs);
        }
        route = kernel_compile_mod.kernel_route;
        def routed(program: JacProgram, path: str) -> tuple[bool, bool] {
            return in_process(program, path)
                if route(program, path)[0]
                else (False, False);
        }
        with patch.object(kernel_compile_mod, "kernel_route", routed) {
            with patch.object(kernel_compile_mod, "kernel_compile_reported", counted) {
                prepared = prepare_application(
                    str(base / 'main.jac'),
                    JacProgram(),
                    str(base),
                    [str(base / 'svc.jac')],
                    client
                );
            }
        }
        assert len(prepared.applications) == 1 , prepared.applications;
        return [os.path.basename(opened) for opened in sessions];
    }
    with TemporaryDirectory() as server_dir {
        with TemporaryDirectory() as client_dir {
            served = sessions_for(Path(os.path.realpath(server_dir)), False);
            assert sorted(served) == ["main.jac", "svc.jac"] , served;
            hosted = sessions_for(Path(os.path.realpath(client_dir)), True);
            assert not hosted , hosted;
        }
    }
}

"""A module outside the entry's project compiles in the same run: the kernel
asks about its imports as it reaches them, whichever project they sit in."""
test "a dependency outside the project compiles in the same kernel run" {
    import jaclang.project.kernel_compile as kernel_compile_mod;
    import from unittest.mock { patch }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        app = base / 'app';
        lib = base / 'shared' / 'lib';
        app.mkdir();
        lib.mkdir(parents=True);
        (app / 'jac.toml').write_text(CONFIG);
        (base / 'shared' / 'jac.toml').write_text('[project]\nname="shared"\n');
        (lib / 'deep.jac').write_text('def twice(x: int) -> int { return x * 2; }\n');
        (lib / 'util.jac').write_text(
            'import json;\nimport from lib.deep { twice }\n'
                + 'def helper(x: int) -> int { return twice(x) + len(json.dumps({})); }\n'
        );
        (app / 'main.jac').write_text(
            'import from lib.util { helper }\nnode Item { has label: str = ""; }\n'
                + 'with entry { root ++> Item(label="a"); print(helper(2)); }\n'
        );
        entry_file = str(app / 'main.jac');
        runs: list[str] = [];
        run_compile = kernel_compile_mod.run_kernel_compile;
        def counted(*args: any, **kwargs: any) -> any {
            runs.append(str(args[1]));
            return run_compile(*args, **kwargs);
        }
        with patch.dict(os.environ, {"JACPATH": str(base / 'shared')}) {
            expected = host_products(entry_file);
            with patch.object(kernel_compile_mod, "run_kernel_compile", counted) {
                outcome = kernel_compile_mod.kernel_compile(
                    active_host(),
                    JacProgram(),
                    entry_file,
                    compile_options(),
                    in_process=True
                );
            }
        }
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
        assert len(runs) == 1 , runs;
    }
}

"""A module that imports from another copy of the compiler package (a test
inside a jaclang checkout, run by an installed jac) is the host's. Its
imports resolve into that checkout, which to the running compiler is project
code: the kernel would compile a second compiler as a user program, where
the host reads only the signatures it needs."""
test "a module importing another copy of the compiler is handed to the host" {
    import jaclang.project.kernel_compile as kernel_compile_mod;
    import from unittest.mock { patch }
    import from jaclang.project.kernel_snapshot { in_other_compiler_tree }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        copy = base / 'jaclang';
        (copy / 'jac0core').mkdir(parents=True);
        (copy / 'pkg').mkdir();
        (copy / 'tests').mkdir();
        (base / 'jac.toml').write_text(CONFIG);
        (copy / 'pkg' / 'mod.jac').write_text(
            'def helper(x: int) -> int { return x; }\n'
        );
        (copy / 'tests' / 'entry.jac').write_text(
            'import from jaclang.pkg.mod { helper }\nwith entry { print(helper(1)); }\n'
        );
        entry_file = str(copy / 'tests' / 'entry.jac');
        assert in_other_compiler_tree(str(copy / 'pkg' / 'mod.jac'));
        assert not in_other_compiler_tree(str(base / 'jac.toml'));
        assert not in_other_compiler_tree(kernel_compile_mod.__file__);
        runs: list[str] = [];
        run_compile = kernel_compile_mod.run_kernel_compile;
        def counted(*args: any, **kwargs: any) -> any {
            runs.append(str(args[1]));
            return run_compile(*args, **kwargs);
        }
        with patch.object(kernel_compile_mod, "run_kernel_compile", counted) {
            outcome = kernel_compile_mod.kernel_compile(
                active_host(),
                JacProgram(),
                entry_file,
                compile_options(),
                in_process=True
            );
        }
        assert not runs , runs;
        assert not outcome.units;
        placed = outcome.analysis.module(entry_file);
        assert placed is not None and placed.native , outcome.analysis.modules;
    }
}

"""One session compiles every module the entry reaches, and each unit goes to
its own module's cache. A unit therefore carries the MTIR its own module
produced and nothing else: a unit that also carried a sibling's entries put
them back under the sibling's file-stem key after the importer had re-keyed
them by import name, so one function was listed twice."""
test "each unit of a kernel session carries only its own module's MTIR" {
    import jaclang.project.kernel_compile as kernel_compile_mod;
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        pkg = base / 'scope_dir';
        pkg.mkdir();
        for name in ('Alpha', 'Beta') {
            (pkg / f'module_{name.lower()}.jac').write_text(
                'import from jaclang.byllm.lib { MockLLM }\n'
                    + f'obj {name}Result {{ has value: str; }}\n'
                    + 'glob llm = MockLLM(model_name="mockllm", '
                    + 'config={"outputs": [], "verbose": False});\n'
                    + f'def process_data -> {name}Result by llm();\n'
            );
        }
        (base / 'main.jac').write_text(
            'import from scope_dir.module_alpha { process_data as alpha_process }\n'
                + 'import from scope_dir.module_beta { process_data as beta_process }\n'
        );
        entry_file = str(base / 'main.jac');
        outcome = kernel_compile_mod.kernel_compile(
            active_host(),
            JacProgram(),
            entry_file,
            compile_options(),
            in_process=True,
            emit_closure=True
        );
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        alpha = outcome.unit(str(pkg / 'module_alpha.jac'));
        beta = outcome.unit(str(pkg / 'module_beta.jac'));
        assert alpha is not None and beta is not None , [u.path for u in outcome.units];
        assert "module_alpha.process_data" in alpha.mtir , alpha.mtir;
        assert "module_beta" not in alpha.mtir , alpha.mtir;
        assert "module_beta.process_data" in beta.mtir , beta.mtir;
        assert "module_alpha" not in beta.mtir , beta.mtir;
    }
}

"""A package's `__init__.jac` is usually empty, and an empty module has no
source location to name it by. Its unit is named by the path the session
compiled, so the host files it under that module and does not compile the
package again when the import reaches it."""
test "an empty package init compiles in the session that reaches it" {
    import jaclang.project.kernel_compile as kernel_compile_mod;
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        pkg = base / 'pkg';
        pkg.mkdir();
        (pkg / '__init__.jac').write_text('');
        (pkg / 'util.jac').write_text('def twice(x: int) -> int { return x * 2; }\n');
        (base / 'main.jac').write_text(
            'import from pkg.util { twice }\nwith entry { print(twice(2)); }\n'
        );
        entry_file = str(base / 'main.jac');
        outcome = kernel_compile_mod.kernel_compile(
            active_host(),
            JacProgram(),
            entry_file,
            compile_options(),
            in_process=True,
            emit_closure=True
        );
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        named = sorted(os.path.relpath(u.path, str(base)) for u in outcome.units);
        assert named == ["main.jac", "pkg/__init__.jac", "pkg/util.jac"] , named;
        init_unit = outcome.unit(str(pkg / '__init__.jac'));
        assert init_unit is not None and init_unit.jcir;
    }
}

"""A module placed native is compiled by the host, where the native backend
runs, and whether a module ends up native is only known once it has been
analysed. A module whose last compile produced native code is therefore
handed to the host without a kernel session first: the kernel's analysis of
it would be thrown away and done again."""
test "a module that last compiled to native code skips the kernel session" {
    import jaclang.project.kernel_compile as kernel_compile_mod;
    import from unittest.mock { patch }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        assert not kernel_compile_mod.last_compiled_native(entry_file);
        sessions: list[str] = [];
        def counted(*args: any, **kwargs: any) -> any {
            sessions.append(str(args[2]));
            raise AssertionError("a kernel session ran");
        }
        def routed(program: JacProgram, path: str) -> tuple[bool, bool] {
            return (True, True);
        }
        def was_native(path: str) -> bool {
            return os.path.realpath(path) == entry_file;
        }
        with patch.object(kernel_compile_mod, "kernel_route", routed) {
            with patch.object(kernel_compile_mod, "kernel_compile_reported", counted) {
                with patch.object(
                    kernel_compile_mod, "last_compiled_native", was_native
                ) {
                    outcome = kernel_compile_mod.host_kernel_compile(
                        active_host(), JacProgram(), entry_file, compile_options()
                    );
                }
            }
        }
        assert not sessions , sessions;
        assert outcome is not None and not outcome.units;
        placed = outcome.analysis.module(entry_file);
        assert placed is not None and placed.native;
    }
}

"""A typed package under site-packages is Python the checker reads. The
kernel does not parse Python, so it asks the host for each such module's
interface as it reaches it; the module that imports the package compiles in
the kernel like any other instead of being handed to the host whole."""
test "a typed third-party package reaches the kernel as interfaces" {
    import sys;
    import jaclang.project.kernel_compile as kernel_compile_mod;
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        project = base / 'proj';
        site = base / 'site-packages';
        lib = site / 'typedkit';
        project.mkdir();
        lib.mkdir(parents=True);
        (project / 'jac.toml').write_text(CONFIG);
        (lib / 'py.typed').write_text('');
        (lib / '__init__.py').write_text('from typedkit.core import shout\n');
        (lib / 'core.py').write_text(
            'def shout(text: str) -> str:\n    return text.upper()\n'
        );
        (project / 'main.jac').write_text(
            'import typedkit;\nnode Item { has label: str = ""; }\n'
                + 'def loud(text: str) -> str { return typedkit.shout(text); }\n'
                + 'with entry { root ++> Item(label="a"); print(loud("a")); }\n'
        );
        entry_file = str(project / 'main.jac');
        sys.path.insert(0, str(site));
        try {
            expected = host_products(entry_file);
            outcome = kernel_compile_mod.kernel_compile(
                active_host(),
                JacProgram(),
                entry_file,
                compile_options(),
                in_process=True
            );
        } finally {
            sys.path.remove(str(site));
        }
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None , outcome.analysis.modules;
        assert_same_products(emitted, expected);
    }
}

"""The kernel's integers are 64 bits wide, and a Jac integer literal is not
bounded. A literal past that width is carried from its text to the compiled
constant as sign and magnitude bytes, never as a value, so the kernel
compiles such a module itself and emits the constant the host emits."""
test "an integer literal wider than 64 bits compiles in the kernel" {
    import from jaclang.compiler.backends.py.codegen_ir { int_literal_magnitude }
    assert int_literal_magnitude("0") == b"";
    assert int_literal_magnitude("255") == b"\xff";
    assert int_literal_magnitude("0x1_00") == b"\x00\x01";
    assert int_literal_magnitude("0b1000_0000") == b"\x80";
    assert int_literal_magnitude("0o777") == (511).to_bytes(2, "little");
    wide = 340282366920938463463374607431768211455;
    assert int_literal_magnitude(str(wide)) == wide.to_bytes(16, "little");
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'main.jac').write_text(
            'glob MASK: int = 0xFFFFFFFFFFFFFFFF,\n'
                + '     EDGE: int = 9223372036854775807,\n'
                + '     PAST: int = 9223372036854775808,\n'
                + '     BIG: int = 340282366920938463463374607431768211455;\n'
                + 'node Item { has label: str = ""; }\n'
                + 'def fold(x: int) -> int {\n'
                + '    return (x * 6364136223846793005 + 1442695040888963407) & MASK;\n'
                + '}\n'
                + 'with entry { root ++> Item(label="a"); print(fold(7), BIG > PAST); }\n'
        );
        entry_file = str(base / 'main.jac');
        expected = host_products(entry_file);
        outcome = compile_in_process(entry_file);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        emitted = outcome.unit(entry_file);
        assert emitted is not None , outcome.analysis.modules;
        assert_same_products(emitted, expected);
        kernel = loaded_kernel();
        if kernel is not None {
            native = compile_natively(kernel, entry_file);
            assert native.analysis.status == ANALYSIS_OK , native.analysis.message;
            from_kernel = native.unit(entry_file);
            assert from_kernel is not None , native.analysis.modules;
            assert_same_products(from_kernel, expected);
        }
    }
}
