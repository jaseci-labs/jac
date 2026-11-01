"""Zero-copy gate of the fat-descriptor migration (#7870): a step-free
string slice is a view with no per-slice allocation -- root-retained
under managed modes, rootless and derivation-bounded (item 2's checker
rules) under the enforced headerless build. Behavior byte-identical
across modes."""

import os;
import subprocess;
import tempfile;
import from tests.support { TESTS_DIR, KernelFixture, compile_mir }
import from tests.support { jac_command }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "str_slice_views.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

"""The MIR text of `name`'s function in a compiled fixture."""
def mir_function(fx: KernelFixture, name: str) -> str {
    head = f"fn @{fx.symbol(name)}(";
    for chunk in fx.mir().split("\n\n") {
        if chunk.startswith(head) {
            return chunk;
        }
    }
    raise AssertionError(f"no MIR function {name} in {fx.path}: demoted {fx.demoted()}");
}

"""The MIR of the fixture's `probe` under `gc_mode`."""
def _probe_fn_mir(gc_mode: str, enforce: bool) -> str {
    fx = compile_mir(
        FIXTURE,
        "",
        CompileOptions(
            aot_mode=True,
            force_codespace="native",
            na_gc_mode=gc_mode,
            nogc_enforce_all=enforce
        )
    );
    return mir_function(fx, "probe");
}

test "managed slices are allocation-free views" {
    body = _probe_fn_mir("rc", False);
    assert "str.make" in body , "no view construction in managed slice";
    for alloc in ("@__jac_rt_str_new", "@__jac_rt_str_concat", "@__jac_rt_alloc") {
        assert alloc not in body , f"managed slice still allocates through {alloc}";
    }
}

test "enforced headerless slices are allocation-free views" {
    body = _probe_fn_mir("none", True);
    assert "str.make" in body , "no view construction in enforced slice";
    for alloc in ("@__jac_rt_str_new", "@__jac_rt_str_concat", "@__jac_rt_alloc") {
        assert alloc not in body , f"enforced slice still allocates through {alloc}";
    }
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
