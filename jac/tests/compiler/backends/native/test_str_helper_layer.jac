"""Step-1 gate of the fat-descriptor string migration (#7870): raw libc
string calls on Jac strings must route through the __jac_str_* helper
layer, so the descriptor flip changes helper bodies instead of every
call site. The scan allows raw strlen/strdup/strcmp only inside
__jac_str_* bodies and the RC machinery's type-tag compares (C strings,
not Jac strings). The fixture must also keep running identically across
all three gc modes -- the sweep is a pure refactor."""

import os;
import re;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
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
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    text = str(ir.gen.llvm_ir);
    dpat = re.compile(r'define[^@]*@"?([A-Za-z0-9_.$]+)"?');
    cpat = re.compile(r'call[^@]*@"?(strlen|strdup|strcmp)"?\(');
    cur = "";
    bad: list[str] = [];
    for ln in text.splitlines() {
        stripped = ln.strip();
        if stripped.startswith("declare") {
            continue;
        }
        if stripped.startswith("define") {
            m = dpat.search(stripped);
            cur = m.group(1) if m else "";
            continue;
        }
        if cpat.search(stripped)
            and not (cur.startswith("__jac_str_") or cur.startswith("__rc_")) {
            bad.append(f"{cur}: {stripped}");
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
                [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
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
