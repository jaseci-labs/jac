"""String slice views (#7870): a step-free string slice, the suffix views
stored in containers or handed to builtins, and views returned through a
union, optional or any result behave identically across memory modes and
release what they hold."""

import os;
import subprocess;
import tempfile;
import from tests.support { TESTS_DIR }
import from tests.support { jac_command }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "str_slice_views.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

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
