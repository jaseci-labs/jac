"""An unparameterized container annotation takes its initializer's analysed type.

`glob NAMES: frozenset = frozenset({"a"})` names no element type, so the
initializer supplies one, for the module that defines the global and for a
module that imports it. An empty literal on the right of `or` takes its type
from the container on the left. A unit that cannot lower is lowered once per
build, however many of its importers ask for its interface.
"""

import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { TESTS_DIR, jac_command }
import from jaclang.compiler.backends.native.link_plan {
    LinkPlanError,
    build_link_plan
}
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.nativecache { NativeBuildSession }
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURE: str = os.path.join(
         TESTS_DIR,
         "compiler",
         "backends",
         "native",
         "fixtures",
         "untyped_containers",
         "main.jac"
     );

test "bare frozenset globals and an or-literal lower and read correctly" {
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", FIXTURE, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , comp.stderr[-1200:];
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , proc.stderr[-400:];
    assert proc.stdout.split()
        == ["True", "False", "True", "False", "False", "1", "0", "True", "False"] , proc.stdout;
}

test "a unit that cannot lower is lowered once for all its importers" {
    with tempfile.TemporaryDirectory() as directory {
        bad = Path(directory) / "bad.jac";
        bad.write_text(
            "glob BAD: frozenset = frozenset();\ndef reads -> int { return len(BAD); }\n"
        );
        prog = JacProgram();
        options = CompileOptions(force_codespace='native', skip_native_engine=True);
        registry = prog.native_units();
        session = NativeBuildSession(registry=registry, options=options);
        registry.session = session;
        try {
            assert registry.dep_iface(str(bad), options) is None;
            first = prog.analysis.cache_events.get("native_unit_analysis", 0);
            assert first == 1 , prog.analysis.cache_events;
            assert registry.dep_iface(str(bad), options) is None;
            assert prog.analysis.cache_events.get("native_unit_analysis", 0) == first;
        } finally {
            registry.session = None;
            session.close();
        }
    }
}

test "a read inside a ternary keeps the source of an earlier alias live" {
    with tempfile.TemporaryDirectory(dir=TESTS_DIR) as directory {
        main = Path(directory) / "alias_ternary.jac";
        main.write_text(
            """obj V { has n: int = 1; }
def keep(v: V, t: int) -> V { return V(n=v.n + t); }
def grow(v: V, t: int) -> V { return V(n=v.n + t * 10); }
def alias_then_rebind(start: int, t: int) -> int {
    value = V(n=start);
    prior = value;
    value = grow(value, t) if t == 3 else keep(value, t);
    return value.n + prior.n;
}
with entry {
    print(alias_then_rebind(1, 2));
    print(alias_then_rebind(1, 3));
}
"""
        );
        out_bin = str(Path(directory) / "probe.bin");
        comp = subprocess.run(
            jac_command("build", "--native", str(main), "-o", out_bin),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert comp.returncode == 0 , comp.stderr[-1200:];
        proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
        assert proc.returncode == 0 , proc.stderr[-400:];
        assert proc.stdout.split() == ["4", "32"] , proc.stdout;
    }
}
