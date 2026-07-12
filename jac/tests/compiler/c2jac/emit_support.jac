"""Shared differential-oracle scaffolding for the jac2c Emit leg of #7145.

Every emit-leg runtime test proves the same thing the same way: compile a
fixture (or an import graph) through `emit_translation_units`, link every C
translation unit with jacrt and a generated driver that prints each `run_*`
call as an int, then assert the linked binary agrees with the stock Jac
interpreter running the same top module. Both references derive their expected
output from one shared `calls` list, so nothing is hand-asserted.

This module owns that machinery so each test file only declares its fixtures,
its `run_*` calls, and its structural assertions. It exists alongside
`support.jac` (which owns the *cast* leg's fixture path and round-trip guard);
the two legs share `FIXTURES` but not their oracles.
"""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.compiler.passes.c.c_gen_pass { emit_translation_units }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     ),
     RUNTIME: str = os.path.join(
         JAC_ROOT, "jaclang", "compiler", "passes", "c", "runtime"
     );


def cc -> (str | None) {
    # The system C compiler, or None so the runtime legs cleanly skip.
    return shutil.which("cc") or shutil.which("gcc") or shutil.which("clang");
}


def emit_units(main_fixture: str) -> list {
    # Compile `main_fixture` and return every (path, c_src) translation unit its
    # import graph produces, via the shared-layout orchestrator both the CLI and
    # these tests consume.
    prog = JacProgram();
    main_path = os.path.join(FIXTURES, main_fixture);
    mod = prog.compile(file_path=main_path);
    assert not prog.errors_had , f"compile errors: {[str(e) for e in prog.errors_had]}";
    return emit_translation_units(main_path, mod, prog);
}


def unit_src(main_fixture: str, want_fixture: str) -> str {
    # The C source of the translation unit for `want_fixture` in main's graph.
    want_path = os.path.join(FIXTURES, want_fixture);
    for (path, src) in emit_units(main_fixture) {
        if path == want_path {
            return src;
        }
    }
    return "";
}


def int_tuple_line(stdout: str, want: int) -> (str | None) {
    # The last stdout line whose whitespace tokens are all ints and number
    # `want`, or None. Robust against interleaved dev-mode/setup banners on
    # either reference's stdout.
    for line in reversed(stdout.splitlines()) {
        toks = line.split();
        if len(toks) != want {
            continue;
        }
        ok = True;
        for t in toks {
            try {
                int(t);
            } except ValueError {
                ok = False;
            }
        }
        if ok {
            return line.strip();
        }
    }
    return None;
}


def _write_driver(work: str, calls: list, rc_live: bool = False) -> str {
    # A C `main` that prints every `run_*` call as one space-separated int line.
    # With `rc_live` it appends `jac_rc_live()` so balance tests can pin the
    # live-object count to zero after the calls run.
    externs = "".join([f"extern int {c}(void);\n" for c in calls]);
    headers = "#include <stdio.h>\n";
    fmts: list = ["%d" for _ in calls];
    argvs: list = [f"{c}()" for c in calls];
    if rc_live {
        headers += "#include \"jacrt.h\"\n";
        fmts.append("%lld");
        argvs.append("(long long)jac_rc_live()");
    }
    fmt = " ".join(fmts);
    argv = ", ".join(argvs);
    drv = os.path.join(work, "driver.c");
    with open(drv, "w") as f {
        f.write(
            headers + externs + "int main(void) {\n    printf(\"" + fmt + "\\n\", " + argv + ");\n" + "    return 0;\n}\n"
        );
    }
    return drv;
}


def link_and_run(units: list, calls: list, rc_live: bool = False) -> (str | None) {
    # Write every non-empty translation unit to its own .c, link them all with
    # jacrt + a generated driver, run the binary, and return its int-tuple line
    # (with `rc_live`, one extra trailing token: the post-run live-object count).
    # Caller must ensure `cc()` is available.
    work = tempfile.mkdtemp();
    cpaths: list = [];
    i = 0;
    for (_, src) in units {
        if not src.strip() {
            continue;
        }
        p = os.path.join(work, f"tu{i}.c");
        with open(p, "w") as f {
            f.write(src);
        }
        cpaths.append(p);
        i += 1;
    }
    drv = _write_driver(work, calls, rc_live);
    binp = os.path.join(work, "bin");
    rt = os.path.join(RUNTIME, "jacrt.c");
    compiler = cc();
    subprocess.run(
        [compiler, "-std=c11", "-I", RUNTIME] + cpaths + [rt, drv, "-o", binp],
        check=True
    );
    proc = subprocess.run([binp], capture_output=True, text=True, check=True);
    want = len(calls);
    if rc_live {
        want += 1;
    }
    return int_tuple_line(proc.stdout, want);
}


def interpreter_run(fixtures: list, main_fixture: str, calls: list) -> str {
    # Copy `fixtures` into a temp dir, append a synthesized entry to
    # `main_fixture` printing the same calls, run it through the stock Jac
    # interpreter (which resolves the imports natively), and return its
    # int-tuple line.
    work = tempfile.mkdtemp();
    for fx in fixtures {
        src = "";
        with open(os.path.join(FIXTURES, fx)) as f {
            src = f.read();
        }
        with open(os.path.join(work, fx), "w") as f {
            f.write(src);
        }
    }
    argv = ", ".join([f"{c}()" for c in calls]);
    entry = "\n\nwith entry {\n    print(" + argv + ");\n}\n";
    with open(os.path.join(work, main_fixture), "a") as f {
        f.write(entry);
    }
    proc = subprocess.run(
        [sys.executable, "-m", "jaclang", "run", os.path.join(work, main_fixture)],
        capture_output=True,
        text=True,
        check=True
    );
    line = int_tuple_line(proc.stdout, len(calls));
    assert line is not None , f"no int-tuple line in interpreter stdout:\n{proc.stdout}";
    return line;
}
