"""A dependency's native scan is a fact about its files, kept on disk.

Judging whether a module can be native walks its import closure, and each
dependency in it was parsed again by every new process to look for native
blockers: a one-file rebuild of a large program parsed every module it
reaches. The scan's answer is stored under the JIR cache, keyed by the
compiler, the module's environment and the content of each file the scan
reads, so an unchanged dependency is not parsed again and any edit to it is.
"""
import os;
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.compiler.frontend.parser.frontend as frontend_mod;
import from jaclang.compiler.placement.placement_solver {
    _native_dep_scan,
    native_scan_memo_clear
}

glob LIB = "def bump(x: int) -> int {\n    return x + 1;\n}\n",
     USE = "import from lib { bump }\n\ndef twice(x: int) -> int;\n",
     USE_IMPL = "impl twice(x: int) -> int {\n    return bump(bump(x));\n}\n";

def write_closure(directory: str) -> str {
    for (name, text) in [
        ("lib.jac", LIB),
        ("use.jac", USE),
        ("use.impl.jac", USE_IMPL)
    ] {
        with open(os.path.join(directory, name), "w") as handle {
            handle.write(text);
        }
    }
    return os.path.join(directory, "use.jac");
}

def refuse_parse(*args: any, **kwargs: any) -> any {
    raise AssertionError("an unchanged file was parsed again");
}

test "an unchanged dependency's scan is read from disk without parsing it" {
    with TemporaryDirectory() as directory {
        use = write_closure(os.path.realpath(directory));
        first = _native_dep_scan(use);
        assert first is not None;
        assert first[0] == "" , first;
        assert [os.path.basename(d) for d in first[1]] == ["lib.jac"] , first;
        native_scan_memo_clear();
        with patch.object(frontend_mod, "parse", refuse_parse) {
            again = _native_dep_scan(use);
        }
        assert again == first , (again, first);
    }
}

test "an edit to the scanned module is scanned again" {
    with TemporaryDirectory() as directory {
        use = write_closure(os.path.realpath(directory));
        assert _native_dep_scan(use)[0] == "";
        native_scan_memo_clear();
        with open(use, "a") as handle {
            handle.write("\nasync def later -> int {\n    return 1;\n}\n");
        }
        assert _native_dep_scan(use)[0] == "async ability";
    }
}

test "an edit to an annex of the scanned module is scanned again" {
    with TemporaryDirectory() as directory {
        use = write_closure(os.path.realpath(directory));
        assert _native_dep_scan(use)[0] == "";
        native_scan_memo_clear();
        with open(os.path.join(os.path.dirname(use), "use.impl.jac"), "w") as handle {
            handle.write(
                "impl twice(x: int) -> int {\n    here = root;\n    return x;\n}\n"
            );
        }
        assert _native_dep_scan(use)[0] == "root access (persistent graph)";
    }
}
