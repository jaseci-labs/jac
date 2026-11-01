"""Step-1 gate of the fat-descriptor string migration (#7870): raw libc
string calls on Jac strings must route through the string helper layer (the
`__jac_rt_str_*` runtime functions), so the descriptor flip changes helper
bodies instead of every call site. The decision step's MIR is the witness: a
fixture function never calls strlen/strdup/strcmp directly (`call.c`); the
helpers live in the runtime units, not in the fixture's MIR. The fixture must
also keep running identically across all three gc modes -- the sweep is a
pure refactor."""

import os;
import re;
import subprocess;
import tempfile;
import from tests.support { compile_mir, jac_command, TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "str_surface.jac"
     ),
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _violations(gc_mode: str, enforce: bool) -> list[str] {
    fx = compile_mir(
        FIXTURE,
        "",
        CompileOptions(
            force_codespace="native",
            aot_mode=True,
            na_gc_mode=gc_mode,
            nogc_enforce_all=enforce
        )
    );
    assert not fx.demoted() , str(fx.demoted());
    fpat = re.compile(r'^fn @"?([^\s(]+)');
    cpat = re.compile(r'call\.c @"?(strlen|strdup|strcmp)\b');
    cur = "";
    bad: list[str] = [];
    for ln in fx.mir().splitlines() {
        m = fpat.search(ln);
        if m {
            cur = m.group(1);
            continue;
        }
        if cpat.search(ln) {
            bad.append(f"{cur}: {ln.strip()}");
        }
    }
    return bad;
}

test "raw libc string calls stay inside the helper layer (enforced none)" {
    bad = _violations("none", True);
    assert not bad , f"{len(bad)} raw sites:\n" + "\n".join(bad[:25]);
}

test "raw libc string calls stay inside the helper layer (managed rc)" {
    bad = _violations("rc", False);
    assert not bad , f"{len(bad)} raw sites:\n" + "\n".join(bad[:25]);
}

test "string surface output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        outs: dict[str, str] = {};
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"strsurf_{mode}");
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
        assert outs["none"] == outs["rc"] , f"{outs['none']} vs {outs['rc']}";
        assert outs["rc"] == outs["cycles"] , f"{outs['rc']} vs {outs['cycles']}";
        assert outs["none"].startswith("strsurface:") , outs["none"];
    }
}
