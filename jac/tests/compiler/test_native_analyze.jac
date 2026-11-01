"""ModuleAnalysis runs inside the native compiler kernel.

`jac check` asks the kernel's check entry: the kernel reads the project
itself (configuration, annexes, Python modules, stdlib stubs), runs the
entry's analysis natively and returns every diagnostic as a record. The host
adopts those records as its alerts."""
import gc;
import os;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.support { diagnostics_text, error_codes, kernel_check_file }

glob CONFIG: str = '[project]\nname="kernel-demo"\n[apps.web]\nkind="web-app"\nentry-point="main"\n';

"""An annexed Jac module, a local Python module, stdlib imports, a shared
node, and two type errors in the entry (one only visible through the Python
module's signature)."""
def write_project(base: Path) {
    (base / 'jac.toml').write_text(CONFIG);
    (base / 'util.jac').write_text(
        'import os;\ndef helper(x: int) -> int;\nobj Point { has x: int = 0; }\n'
    );
    (base / 'util.impl.jac').write_text(
        'impl helper(x: int) -> int { return x + len(os.sep); }\n'
    );
    (base / 'pyhelp.py').write_text(
        'import json\n\ndef twice(x: int) -> int:\n    return 2 * x\n'
    );
    (base / 'shared.jac').write_text('node Item { has label: str = ""; }\n');
    (base / 'main.jac').write_text(
        'import from util { helper, Point }\n'
            + 'import from pyhelp { twice }\n'
            + 'import from shared { Item }\n'
            + 'import json;\n'
            + 'def go -> int {\n'
            + '    p = Point(x=1);\n'
            + '    return helper(p.x) + twice(2) + len(json.dumps({}));\n'
            + '}\n'
            + 'with entry { x: str = go(); y: int = twice("a"); root ++> Item(label="a"); }\n'
    );
    (base / 'clean.jac').write_text(
        'import from util { helper }\n'
            + 'def total(xs: list[int]) -> int {\n'
            + '    acc = 0;\n'
            + '    for x in xs { acc += helper(x); }\n'
            + '    return acc;\n'
            + '}\n'
            + 'with entry { print(total([1, 2, 3])); }\n'
    );
}

def check_options -> CompileOptions {
    return CompileOptions(
        no_cgen=True, native_parity=True, iface_ok=True, strict_dependencies=True
    );
}

"""Every error's code, file (relative to `base`) and line."""
def error_rows(result: any, base: str) -> list[tuple[str, str, int]] {
    return sorted(
        (d.code, os.path.relpath(os.path.realpath(d.span.path), base), d.span.line)
        for d in result.errors
    );
}

def rss_kb -> (int | None) {
    try {
        with open("/proc/self/status", encoding="utf-8") as f {
            for line in f {
                if line.startswith("VmRSS:") {
                    return int(line.split()[1]);
                }
            }
        }
    } except OSError {
        return None;
    }
    return None;
}

test "the kernel's check reports the entry's type errors across modules" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        result = kernel_check_file(str(base / 'main.jac'), check_options());
        rows = error_rows(result, str(base));
        assert ("E1001", "main.jac", 9) in rows , diagnostics_text(result);
        assert ("E1053", "main.jac", 9) in rows , diagnostics_text(result);
        assert str(base / 'util.jac') in [os.path.realpath(p) for p in result.reached];
        clean = kernel_check_file(str(base / 'clean.jac'), check_options());
        assert clean.ok() , diagnostics_text(clean);
        assert not clean.errors;
    }
}

test "repeated kernel checks do not grow memory without bound" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        entry_file = str(base / 'main.jac');
        def run_once {
            result = kernel_check_file(entry_file, check_options());
            assert "E1001" in error_codes(result) , diagnostics_text(result);
        }
        for _ in range(3) {
            run_once();
        }
        gc.collect();
        start = rss_kb();
        rounds = 20;
        for _ in range(rounds) {
            run_once();
        }
        gc.collect();
        end = rss_kb();
        if start is None or end is None {
            return;
        }
        growth_mb = (end - start) / 1024.0;
        assert growth_mb < 256.0 , (
            f"{rounds} kernel checks grew RSS by {growth_mb:.1f} MB"
        );
    }
}

test "jac check adopts the kernel's diagnostics as the program's alerts" {
    import from jaclang.project.kernel_check { kernel_check }
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        write_project(base);
        program = JacProgram();
        result = kernel_check(program, str(base / 'main.jac'), check_options());
        assert len(result.errors) >= 2 , diagnostics_text(result);
        assert [a.code.code for a in program.errors_had] == error_codes(result);
        assert [a.code.code for a in program.warnings_had]
            == [d.code for d in result.warnings];
        for (alert, diag) in zip(program.errors_had, result.errors) {
            assert alert.msg == diag.message;
            assert alert.loc.mod_path == diag.span.path;
            assert alert.loc.first_line == diag.span.line;
        }
    }
}

"""A typed Python package outside the project whose class reaches Mapping
through a base in another of its modules; the project passes an instance to a
Mapping parameter."""
def write_mapping_project(base: Path) -> tuple[str, str] {
    project = base / 'proj';
    lib = base / 'extlib' / 'mapkit';
    project.mkdir();
    lib.mkdir(parents=True);
    (project / 'jac.toml').write_text('[project]\nname="mapping-demo"\n');
    (lib / 'py.typed').write_text('');
    (lib / '__init__.py').write_text(
        'from mapkit.api import load\nfrom mapkit.doc import Doc\n'
    );
    (lib / 'base.py').write_text(
        'from collections.abc import Mapping, Iterator\n\n'
            + 'class BaseTable(Mapping[str, int]):\n'
            + '    def __getitem__(self, key: str) -> int:\n        return 0\n\n'
            + '    def __iter__(self) -> Iterator[str]:\n        return iter([])\n\n'
            + '    def __len__(self) -> int:\n        return 0\n'
    );
    (lib / 'doc.py').write_text(
        'from mapkit.base import BaseTable\n\nclass Doc(BaseTable):\n    pass\n'
    );
    (lib / 'api.py').write_text(
        'from mapkit.doc import Doc\n\ndef load(text: str) -> Doc:\n    return Doc()\n'
    );
    (project / 'main.jac').write_text(
        'import mapkit;\n'
            + 'def size(data: Mapping[str, int]) -> int {\n'
            + '    return len(data);\n'
            + '}\n'
            + 'with entry { print(size(mapkit.load("x"))); }\n'
    );
    return (str(project / 'main.jac'), str(base / 'extlib'));
}

test "a Python base class in another module of an imported package reaches the kernel" {
    with TemporaryDirectory() as td {
        base = Path(os.path.realpath(td));
        (entry_file, lib_root) = write_mapping_project(base);
        sys.path.insert(0, lib_root);
        try {
            result = kernel_check_file(entry_file, check_options());
            assert not result.errors , diagnostics_text(result);
        } finally {
            sys.path.remove(lib_root);
        }
    }
}
