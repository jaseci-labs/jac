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
    CompileReport,
    run_kernel_compile
}
import from jaclang.project.kernel_snapshot {
    COMPILE_ENTRY,
    call_kernel,
    kernel_inputs_json
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

def kernel_json(entry_file: str) -> str {
    return kernel_inputs_json(
        active_host(), JacProgram(), entry_file, compile_options()
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
        outcome = run_kernel_compile(kernel_json(entry_file), entry_file, None);
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
        outcome = run_kernel_compile(kernel_json(entry_file), entry_file, None);
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
        outcome = run_kernel_compile(kernel_json(entry_file), entry_file, None);
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
        outcome = CompileReport.from_json(
            call_kernel(
                kernel, COMPILE_ENTRY, kernel_json(entry_file), entry_file, None
            )
        );
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
        outcome = run_kernel_compile(kernel_json(entry_file), entry_file, None);
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
        outcome = run_kernel_compile(kernel_json(entry_file), entry_file, None);
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
        outcome = run_kernel_compile(kernel_json(entry_file), entry_file, None);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
        arch_file = str(base / 'arch.jac');
        checked = run_kernel_compile(kernel_json(arch_file), arch_file, None);
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
        outcome = CompileReport.from_json(
            call_kernel(
                kernel, COMPILE_ENTRY, kernel_json(entry_file), entry_file, None
            )
        );
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
        outcome = run_kernel_compile(kernel_json(entry_file), entry_file, None);
        assert outcome.analysis.status == ANALYSIS_OK , outcome.analysis.message;
        assert not outcome.analysis.misses , outcome.analysis.misses;
        emitted = outcome.unit(entry_file);
        assert emitted is not None;
        assert_same_products(emitted, expected);
    }
}
