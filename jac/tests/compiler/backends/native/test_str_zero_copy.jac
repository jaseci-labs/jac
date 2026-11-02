"""Zero-copy gate of the fat-descriptor migration (#7870): a step-free
string slice is a view with no per-slice allocation -- root-retained
under managed modes, rootless and derivation-bounded (item 2's checker
rules) under the enforced headerless build. Behavior byte-identical
across modes."""

import os;
import re;
import subprocess;
import tempfile;
import from tests.support { TESTS_DIR, unit_symbol }
import from tests.support { jac_command }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "str_slice_views.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _probe_fn_ir(gc_mode: str, enforce: bool) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    text = str(ir.gen.llvm_ir);
    sym = re.escape(unit_symbol(ir, "probe"));
    m = re.search(r'define[^\n]*@"?' + sym + r'"?\([^\n]*\n(.*?)\n\}', text, re.DOTALL);
    assert m , "probe fn not found in IR";
    return m.group(1);
}

test "managed slices are allocation-free views" {
    body = _probe_fn_ir("rc", False);
    assert "s.view" in body , "no view construction in managed slice";
    assert "__rc_alloc" not in body , "managed slice still allocates";
}

test "enforced headerless slices are rootless allocation-free views" {
    body = _probe_fn_ir("none", True);
    assert "s.view" in body , "no view construction in enforced slice";
    assert "__jac_halloc" not in body , "enforced slice still allocates";
    assert "s.view.root" not in body , "headerless view carries a root store";
    assert "__jac_rc_retain" not in body , "enforced slice emits rc traffic";
}

test "slice-view output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"zc_{mode}");
            res = subprocess.run(
                jac_command("build", "--native", FIXTURE)
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            outs[mode] = ran.stdout;
        }
        assert outs["rc"].endswith("end\n") , outs["rc"];
        assert outs["none"] == outs["rc"] , f"{outs['none']} vs {outs['rc']}";
        assert outs["cycles"] == outs["rc"] , outs["cycles"];
    }
}

def _run_fixture(name: str, flags: list[str], tmp: str) -> subprocess.CompletedProcess {
    out_bin = os.path.join(tmp, name.replace(".jac", "") + "_" + "_".join(flags));
    res = subprocess.run(
        jac_command("build", "--native", os.path.join(os.path.dirname(FIXTURE), name))
            + flags
            + ["-o", out_bin],
        capture_output=True,
        text=True
    );
    assert res.returncode == 0 , f"{flags}: {res.stderr[-800:]}";
    return subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
}

test "suffix views stored in containers are strings of their own" {
    with tempfile.TemporaryDirectory() as tmp {
        for mode in ("rc", "cycles") {
            ran = _run_fixture("str_view_escape.jac", MODE_FLAGS[mode], tmp);
            assert ran.returncode == 0 , f"{mode}: exit {ran.returncode} {ran.stderr[-400:]}";
            lines = ran.stdout.strip().split("\n");
            assert lines[-1] == "end" , f"{mode}: {ran.stdout[-400:]}";
            interior = [
                line
                for line in lines
                if line.endswith(" False")
            ];
            assert not interior , f"{mode}: interior pointers stored: {interior}";
            assert len(
                [
                    line
                    for line in lines
                    if line.endswith(" True")
                ]
            )
                == 9 , lines;
        }
    }
}

test "suffix views handed to builtins, methods and containers are released" {
    with tempfile.TemporaryDirectory() as tmp {
        ran = _run_fixture("str_view_leaks.jac", ["--debug"], tmp);
        assert ran.returncode == 0 , f"exit {ran.returncode}: {ran.stderr[-400:]}";
        assert ran.stdout.split("\n")[0] == "3110" , ran.stdout[:200];
        assert "RC LIVE OBJECTS at exit" in ran.stdout , ran.stdout[-400:];
        leaks = [
            line
            for line in ran.stdout.split("\n")
            if "<- LEAK" in line
        ];
        assert not leaks , f"suffix views leaked: {leaks[:5]}";
    }
}

test "a view returned through a union, optional or any result is a string of its own" {
    expected = "abc\n['abc']\n200\n['abc', 'defg'] hijkl";
    with tempfile.TemporaryDirectory() as tmp {
        for (mode, flags) in MODE_FLAGS.items() {
            if mode == "none" {
                continue;
            }
            ran = _run_fixture("str_view_return.jac", flags, tmp);
            assert ran.returncode == 0 , f"{mode}: exit {ran.returncode}: {ran.stderr[-400:]}";
            assert ran.stdout.strip() == expected , f"{mode}: {ran.stdout!r}";
        }
    }
}
