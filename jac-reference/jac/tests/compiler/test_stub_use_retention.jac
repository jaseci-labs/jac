"""Stub symbols must not anchor dead programs.

The type evaluator serves every stdlib stub from the process-wide stub
catalog, so a use-site recorded on a stub symbol would be a process-lifetime
reference into the using program's AST: one such edge keeps that program's
whole module graph -- inference results, and for native compiles the LLVM
artifacts hanging off `mod.gen` -- reachable forever. Long-lived `jac test`
fork workers and the full-sweep `jac check .` then grow monotonically until
the box dies (the CI "lost communication" failures).

These tests pin the two halves of the fix: `Symbol.add_use` refuses to record
use-sites on stub-owned symbols while still binding `nd.sym` (resolution and
codegen depend on that), and a program dropped on the floor -- the dominant
pattern in the pass tests -- becomes garbage-collectable.
"""

import gc;
import os;
import tempfile;
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURE_SRC: str = (
         "with entry {\n"
         + "    xs = [1, 2, 3];\n"
         + "    xs.append(4);\n"
         + "    n = len(xs);\n"
         + "    s = sorted(xs);\n"
         + "}\n"
     );

def _write_fixture -> str {
    (fd, path) = tempfile.mkstemp(suffix=".jac", prefix="stub_use_probe_");
    os.close(fd);
    with open(path, "w") as f {
        f.write(FIXTURE_SRC);
    }
    return path;
}

def _memoized_builtins_module -> (uni.Module | None) {
    import from jaclang.jac0core.stubcat_hook { active }
    catalog: any = active();
    if catalog is None {
        return None;
    }
    return catalog.module("builtins");
}

def _live_module_count -> int {
    count = 0;
    for o in gc.get_objects() {
        if isinstance(o, uni.Module) {
            count += 1;
        }
    }
    return count;
}

test "stub symbols record no use-sites from checked programs" {
    path = _write_fixture();
    try {
        prog: JacProgram | None = JacProgram();
        mod = prog.compile(path);
        assert mod is not None;
        prog = None;
        builtins_mod = _memoized_builtins_module();
        assert builtins_mod is not None , "the stub catalog should be open after a compile";
        for name in ("len", "sorted", "print") {
            sym = builtins_mod.names_in_scope.get(name);
            if sym is not None {
                assert len(sym.uses) == 0 , (
                    f"stub symbol '{name}' recorded {len(sym.uses)} use-site(s);"
                    + " each one pins a whole JacProgram for the process lifetime"
                );
            }
        }
    } finally {
        os.unlink(path);
    }
}

test "a dropped program is collectable, repeat compiles stay flat" {
    path = _write_fixture();
    try {
        baseline = -1;
        for i in range(3) {
            prog: JacProgram | None = JacProgram();
            prog.compile(path);
            prog = None;
            gc.collect();
            live = _live_module_count();
            if i == 0 {
                baseline = live;
            } else {
                assert live <= baseline , (
                    f"round {i}: {live} live Modules vs baseline {baseline};"
                    + " dead programs are being retained across compiles"
                );
            }
        }
    } finally {
        os.unlink(path);
    }
}

test "user-code symbols still record their uses" {
    path = _write_fixture();
    try {
        prog: JacProgram | None = JacProgram();
        mod = prog.compile(path);
        found = False;
        stack: list[uni.UniScopeNode] = [];
        stack.append(mod);
        while stack {
            scope = stack.pop();
            xs = scope.names_in_scope.get("xs");
            if xs is not None and len(xs.uses) > 0 {
                found = True;
                break;
            }
            for kid in scope.kid_scope {
                stack.append(kid);
            }
        }
        assert found , "no use-sites recorded for user symbol 'xs'";
        prog = None;
    } finally {
        os.unlink(path);
    }
}
