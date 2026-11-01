"""Code generation runs inside the native compiler kernel.

A compile request names the entry; the kernel reads the project itself, runs
the whole pipeline (analysis and the code generators) and returns one
`CompiledUnit` per module it compiled: the module's code object, interop,
client artifact, placement summary and cache sections. There is no other
compiler to fall back to: a module the kernel cannot compile is a
diagnostic."""
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { diagnostics_text, error_codes, kernel_compile_file }

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

"""Compile `entry_file` through the kernel, assert it compiled cleanly, and
return the entry's unit."""
def compiled_entry(entry_file: str) -> any {
    result = kernel_compile_file(entry_file, compile_options());
    assert result.ok() , diagnostics_text(result);
    unit = result.unit(entry_file);
    assert unit is not None , [u.path for u in result.units];
    assert unit.code is not None , "the kernel compiled the entry but returned no code";
    return unit;
}

"""Record every compile request the loaded kernel receives, with the paths of
the units it returned."""
def recorded_kernel_compiles(log: list[tuple[list[str], list[str]]]) -> any {
    import from unittest.mock { patch }
    import from jaclang.compiler.backends.native.kernel_resolve { load_kernel }
    kernel = load_kernel();
    real = kernel.compile;
    def counted(record: dict[str, any]) -> dict[str, any] {
        raw = real(record);
        log.append((list(record["paths"]), [unit["path"] for unit in raw["units"]]));
        return raw;
    }
    return patch.object(kernel, "compile", counted);
}

test "the kernel compiles a project's entry into its code and products" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        unit = compiled_entry(entry_file);
        names = set(unit.code.co_names);
        assert "go" in names and "Tally" in names and "Item" in names , sorted(names);
        assert unit.placement , "the entry's unit carries no placement summary";
        assert str(base / 'util.jac') in [os.path.realpath(p) for p in unit.jac_deps];
    }
}

test "an entry with type errors reports them and emits no unit" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'broken.jac');
        result = kernel_compile_file(entry_file, compile_options());
        assert not result.ok();
        assert result.errors;
        assert entry_file not in [os.path.realpath(u.path) for u in result.units];
    }
}

test "get_bytecode adopts a kernel compile and persists its unit" {
    import from jaclang.compiler.driver.jir { SEC_BYTECODE, read_section_bytes }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        program = JacProgram();
        code = program._get_compiler().get_bytecode(entry_file, program);
        assert code is not None , [str(e) for e in program.errors_had];
        written = sorted((base / '.jac' / 'cache').rglob('main.*.jir'));
        assert written , "the adopted unit was not persisted";
        assert read_section_bytes(written[0].read_bytes(), SEC_BYTECODE);
        names = set(code.co_names);
        assert "go" in names or "Tally" in names , sorted(names);
    }
}

"""A client component makes the ES pass register the framework runtime module
even though the source never imports it; the kernel resolves it itself and
emits the module's client artifact."""
test "a client module compiles in the kernel with its client artifact" {
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
        unit = compiled_entry(str(base / 'app.jac'));
        assert unit.client_js , "the fixture compiled no client code";
    }
}

"""A client module importing `@jac/runtime` makes the type evaluator read the
declaration file beside the virtual module."""
test "a client module importing a virtual Jac module compiles in the kernel" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'app.jac').write_text(
            'import from "@jac/runtime" { jacIsLoggedIn }\n\n'
                + 'def:pub app -> JsxElement {\n'
                + '    return <div>{"in" if jacIsLoggedIn() else "out"}</div>;\n}\n'
        );
        unit = compiled_entry(str(base / 'app.jac'));
        assert unit.client_js;
    }
}

"""The arch file weaves an import into each consumer it wires, attributed to
the arch file, so the kernel resolves the imports that woven text asks for
and not only the arch file's own imports."""
test "a module wired by the arch file compiles in the kernel" {
    import from tests.support { kernel_check_file }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'archwire.jac').write_text(
            'graph import {\n    edge CoreInternal: core.* --> core.*;\n}\n\n'
                + 'graph import core {\n    util ++> svc { Spark }\n}\n'
        );
        (base / 'core').mkdir();
        (base / 'core' / 'util.jac').write_text(
            'obj Spark {\n    has x: int = 0;\n}\n'
        );
        (base / 'core' / 'svc.jac').write_text(
            'def serve -> int {\n    return Spark(x=1).x;\n}\n'
        );
        compiled_entry(str(base / 'core' / 'svc.jac'));
        checked = kernel_check_file(str(base / 'archwire.jac'), compile_options());
        assert checked.ok() , diagnostics_text(checked);
    }
}

"""The kernel sees jaclang's own modules through their interfaces, which carry
no bodies, so placement must not read an import from one as free to pull into
client code: it stays on the server."""
test "a server-side comptime import beside client code stays on the server" {
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
        unit = compiled_entry(str(base / 'app.jac'));
        assert "get_field" not in unit.client_js , "a server import reached the client";
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
        compiled_entry(str(base / 'main.jac'));
    }
}

"""A typed package whose compiled extension ships only a `.pyi` stub
(`cryptography`'s `_rust` bindings do). The kernel reads the stub as it reads
a `.py` module's interface."""
test "an import of a third-party package whose module is only a stub compiles in the kernel" {
    import sys;
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        site = base / 'venv' / 'lib' / 'site-packages';
        pkg = site / 'stubbed_ext';
        pkg.mkdir(parents=True);
        (pkg / 'py.typed').write_text('');
        (pkg / '__init__.py').write_text('from stubbed_ext._native import ping\n');
        (pkg / '_native.pyi').write_text('def ping(x: int) -> int: ...\n');
        app = base / 'app';
        app.mkdir();
        (app / 'jac.toml').write_text(CONFIG);
        (app / 'main.jac').write_text(
            'import from stubbed_ext { ping }\n\n'
                + 'def call -> int {\n    return ping(1);\n}\n'
        );
        sys.path.insert(0, str(site));
        try {
            compiled_entry(str(app / 'main.jac'));
        } finally {
            sys.path.remove(str(site));
        }
    }
}

def write_application(base: Path) {
    (base / 'jac.toml').write_text(CONFIG);
    (base / 'util.jac').write_text(
        'def helper(x: int) -> int { return x + 1; }\n'
            + 'walker:pub Ping { can go with Root entry { report helper(1); } }\n'
    );
    (base / 'deep.jac').write_text('def:pub twice(x: int) -> int { return x * 2; }\n');
    (base / 'archwire.jac').write_text(
        'graph import {\n    edge Deep: deep --> main;\n'
            + '    edge SideInternal: side.* --> side.*;\n'
            + '    edge Util: util --> main;\n\n'
            + '    util ++> main { helper }\n    include deep ++> main;\n}\n\n'
            + 'graph import side {\n    tool ++> user { Wrench }\n}\n'
    );
    (base / 'side').mkdir();
    (base / 'side' / 'tool.jac').write_text(
        'obj Wrench {\n    has size: int = 0;\n}\n'
    );
    (base / 'side' / 'user.jac').write_text(
        'def turn -> int {\n    return Wrench(size=1).size;\n}\n'
    );
    (base / 'main.jac').write_text(
        'node Item { has label: str = ""; }\n'
            + 'def:pub go(n: int) -> int { return helper(n) + twice(n); }\n'
            + 'def quiet(n: int) -> int { return n; }\n'
            + 'with entry { print(go(3)); }\n'
    );
}

"""`jac run` and `serve` prepare an application: every project module's code
and the manifest of what it serves. One kernel compile emits a unit per
module, and the manifest is built from those units. The project's arch file
wires modules the entry never imports; they are no part of this
application."""
test "an application prepares from one kernel compile" {
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.runtime.prepared { forget }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_application(base);
        entry_file = str(base / 'main.jac');
        compiles: list[tuple[list[str], list[str]]] = [];
        try {
            with recorded_kernel_compiles(compiles) {
                prepared = prepare_application(entry_file, JacProgram(), str(base));
            }
        } finally {
            forget(entry_file);
        }
        assert len(compiles) == 1 , compiles;
        coded = sorted(os.path.relpath(path, str(base)) for path in prepared.code);
        assert coded == ["deep.jac", "main.jac", "util.jac"] , coded;
        surface = prepared.manifests[entry_file]["surface"];
        assert "go" in surface and "twice" in surface and "Ping" in surface , sorted(
            surface
        );
    }
}

"""A module that names a Jac builtin gets `from jaclang.runtime.builtin import`
in its code. The generator finds builtins by set membership, and in the
native kernel a set declared without an element type compares strings by
identity, so the import was dropped and the name failed at run time."""
test "a module using Jac builtins compiles in the kernel with their import" {
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
        unit = compiled_entry(str(base / 'main.jac'));
        names = set(unit.code.co_names);
        assert "printgraph" in names and "testraises" in names , sorted(names);
    }
}

"""An annex in an `impl/` folder resolves its imports from the folder of the
module it belongs to."""
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
        compiled_entry(str(base / 'ver.jac'));
    }
}

"""Generated Python that JacPython's compiler rejects in the kernel is a
compile error in the module (E5043), not an internal failure of the run."""
test "a kernel unit whose Python the compiler rejects reports E5043" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        entry_file = str(base / 'early_exit.jac');
        Path(entry_file).write_text(
            'with entry {\n    x = 1;\n    if x {\n        return;\n    }\n    print(x);\n}\n'
        );
        result = kernel_compile_file(entry_file, compile_options());
        rejected = [d.message for d in result.errors if d.code == "E5043"];
        assert rejected , diagnostics_text(result);
        assert "'return' outside function" in rejected[0] , rejected;
        program = JacProgram();
        assert program._get_compiler().get_bytecode(entry_file, program) is None;
        assert [
            e.msg
            for e in program.errors_had
            if e.code is not None and e.code.code == "E5043"
        ] == rejected;
    }
}

"""jaclang's own modules reach the kernel as interfaces. A field's default is
recorded on the interface's symbol, not on a syntax node: without it every
constructor call that relied on a default was reported as missing arguments
(E1050)."""
test "a jaclang record built from its field defaults compiles in the kernel" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'main.jac').write_text(
            'import from jaclang.compiler.driver.compile_options { CompileOptions }\n\n'
                + 'def make -> CompileOptions {\n'
                + '    return CompileOptions(skip_native_engine=True);\n}\n'
        );
        entry_file = str(base / 'main.jac');
        result = kernel_compile_file(entry_file, compile_options());
        assert "E1050" not in error_codes(result) , diagnostics_text(result);
        assert result.ok() , diagnostics_text(result);
    }
}

"""A graph expression makes the compiler add an import of the shared graph
runtime that the source never wrote."""
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
        compiled_entry(entry_file);
    }
}

"""An application with a client prepares through the kernel like any other:
one compile for the entry and its services, the entry's client manifest read
from its unit, and the client compiler fed from the artifacts those units
carry."""
test "an application with a client prepares through the kernel" {
    import from jaclang.compiler.driver.application { prepare_application }
    import from jaclang.runtime.prepared { forget }
    def compiles_for(base: Path, client: bool) -> list[tuple[list[str], list[str]]] {
        (base / 'jac.toml').write_text(CONFIG);
        (base / 'main.jac').write_text('def:pub home -> int { return 1; }\n');
        (base / 'svc.jac').write_text('def:pub ping -> int { return 2; }\n');
        compiles: list[tuple[list[str], list[str]]] = [];
        try {
            with recorded_kernel_compiles(compiles) {
                prepared = prepare_application(
                    str(base / 'main.jac'),
                    JacProgram(),
                    str(base),
                    [str(base / 'svc.jac')],
                    client
                );
            }
        } finally {
            forget(str(base / 'main.jac'));
        }
        assert len(prepared.applications) == 1 , prepared.applications;
        return compiles;
    }
    with TemporaryDirectory() as server_dir {
        with TemporaryDirectory() as client_dir {
            for (folder, client) in [(server_dir, False), (client_dir, True)] {
                compiles = compiles_for(Path(os.path.realpath(folder)), client);
                assert len(compiles) == 1 , compiles;
                asked = sorted(os.path.basename(path) for path in compiles[0][0]);
                assert asked == ["main.jac", "svc.jac"] , asked;
            }
        }
    }
}

"""A module outside the entry's project compiles in the same run: the kernel
resolves its imports as it reaches them, whichever project they sit in."""
test "a dependency outside the project compiles in the same kernel run" {
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
        compiles: list[tuple[list[str], list[str]]] = [];
        with patch.dict(os.environ, {"JACPATH": str(base / 'shared')}) {
            with recorded_kernel_compiles(compiles) {
                compiled_entry(entry_file);
            }
        }
        assert len(compiles) == 1 , compiles;
        emitted = [os.path.realpath(path) for path in compiles[0][1]];
        assert str(lib / 'util.jac') in emitted and str(lib / 'deep.jac') in emitted , (
            emitted
        );
    }
}

"""A module inside another copy of the compiler package (a test inside a
jaclang checkout, run by an installed jac) belongs to that copy's kernel. Its
imports resolve into that checkout, which this kernel would compile as a user
program; it refuses with E1408 instead."""
test "a module inside another copy of the compiler is refused with E1408" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        copy = base / 'jaclang';
        (copy / 'compiler').mkdir(parents=True);
        (copy / 'pkg').mkdir();
        (copy / 'tests').mkdir();
        (base / 'jac.toml').write_text(CONFIG);
        (copy / 'compiler' / 'kernel_api.jac').write_text('');
        (copy / 'pkg' / 'mod.jac').write_text(
            'def helper(x: int) -> int { return x; }\n'
        );
        (copy / 'tests' / 'entry.jac').write_text(
            'import from jaclang.pkg.mod { helper }\nwith entry { print(helper(1)); }\n'
        );
        entry_file = str(copy / 'tests' / 'entry.jac');
        result = kernel_compile_file(entry_file, compile_options());
        assert error_codes(result) == ["E1408"] , diagnostics_text(result);
        assert str(copy) in result.errors[0].message;
        assert not result.units , [u.path for u in result.units];
    }
}

"""One compile reaches every module the entry imports, and each unit goes to
its own module's cache. A unit therefore carries the MTIR its own module
produced and nothing else: a unit that also carried a sibling's entries put
them back under the sibling's file-stem key after the importer had re-keyed
them by import name, so one function was listed twice."""
test "each unit of a kernel compile carries only its own module's MTIR" {
    import from jaclang.compiler.driver.jir { SEC_MTIR }
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
        result = kernel_compile_file(str(base / 'main.jac'), compile_options());
        assert result.ok() , diagnostics_text(result);
        alpha = result.unit(str(pkg / 'module_alpha.jac'));
        beta = result.unit(str(pkg / 'module_beta.jac'));
        assert alpha is not None and beta is not None , [u.path for u in result.units];
        alpha_mtir = alpha.sections.get(SEC_MTIR, b"").decode("utf-8");
        beta_mtir = beta.sections.get(SEC_MTIR, b"").decode("utf-8");
        assert "module_alpha.process_data" in alpha_mtir , alpha_mtir;
        assert "module_beta" not in alpha_mtir , alpha_mtir;
        assert "module_beta.process_data" in beta_mtir , beta_mtir;
        assert "module_alpha" not in beta_mtir , beta_mtir;
    }
}

"""A package's `__init__.jac` is usually empty, and an empty module has no
source location to name it by. Its unit is named by the path the kernel
compiled, so the host files it under that module and does not compile the
package again when the import reaches it."""
test "an empty package init compiles in the run that reaches it" {
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
        result = kernel_compile_file(str(base / 'main.jac'), compile_options());
        assert result.ok() , diagnostics_text(result);
        named = sorted(os.path.relpath(u.path, str(base)) for u in result.units);
        assert named == ["main.jac", "pkg/__init__.jac", "pkg/util.jac"] , named;
        init_unit = result.unit(str(pkg / '__init__.jac'));
        assert init_unit is not None and init_unit.code is not None;
    }
}

"""A typed package under site-packages is Python the checker reads through
its interface; the module that imports the package compiles in the kernel
like any other."""
test "a typed third-party package reaches the kernel as interfaces" {
    import sys;
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
        sys.path.insert(0, str(site));
        try {
            compiled_entry(str(project / 'main.jac'));
        } finally {
            sys.path.remove(str(site));
        }
    }
}

"""The kernel's integers are 64 bits wide, and a Jac integer literal is not
bounded. A literal past that width is carried from its text to the compiled
constant as sign and magnitude bytes, never as a value, so the kernel
compiles such a module and emits the exact constant."""
test "an integer literal wider than 64 bits compiles in the kernel" {
    import from jaclang.compiler.backends.py.pyast_recipe { int_literal_magnitude }
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
        unit = compiled_entry(str(base / 'main.jac'));
        consts = set(
            c for c in unit.code.co_consts if isinstance(c, int) and not isinstance(c, bool)
        );
        assert {wide, 9223372036854775808, 0xFFFFFFFFFFFFFFFF} <= consts , sorted(consts);
    }
}
