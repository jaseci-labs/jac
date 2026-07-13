"""Lift behavioral oracle: cc(original C) vs jac run(lifted Jac).

Idiomatic lift output (lists, comprehensions, …) sits outside jac2c's
emittable subset, so the lift→jac2c→cc round-trip cannot verify the
translations that need it most. This harness compares the original C under
the system compiler against the lifted Jac under the bytecode interpreter.

Two regimes, auto-derived from `LiftResult.quarantined_functions`:
  - MATCH  — entry not quarantined: Jac output must equal C output
  - TRAP   — entry quarantined: Jac must raise the quarantine stub; C still runs

Every subprocess carries a timeout so a STYLE-claimed hang cannot deadlock CI.
"""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.cfront.lift { lift_c_file }

glob FIXTURES: str = os.path.join(
         JAC_ROOT, "tests", "compiler", "c2jac", "fixtures"
     ),
     HANG: str = "__HANG__",
     DEFAULT_TIMEOUT: float = 10.0;


def cc -> (str | None) {
    return shutil.which("cc") or shutil.which("gcc") or shutil.which("clang");
}


def int_tuple_line(stdout: str, want: int) -> (str | None) {
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


def run_c(
    sources: list[str],
    include_dirs: list[str],
    driver: str,
    timeout: float = DEFAULT_TIMEOUT
) -> str {
    # Compile `sources` + `driver` with system cc; return the int-tuple line
    # or `HANG` if the binary exceeds `timeout`.
    #
    # Fixture TUs are compiled with `-Dmain=__c2jac_fixture_main` so a
    # fixture-defined `main` (hello.c) cannot collide with the driver's
    # entry point. The define is *not* applied to the driver itself.
    compiler = cc();
    assert compiler is not None;
    work = tempfile.mkdtemp();
    incs = [f"-I{d}" for d in include_dirs];
    objs: list = [];
    i = 0;
    for src_path in sources {
        with open(src_path) as f {
            body = f.read();
        }
        p = os.path.join(work, f"src{i}.c");
        with open(p, "w") as f {
            f.write(body);
        }
        obj_path = os.path.join(work, f"src{i}.o");
        compiled = subprocess.run(
            [
                compiler,
                "-std=c11",
                "-c",
                "-Dmain=__c2jac_fixture_main",
                *incs,
                p,
                "-o",
                obj_path
            ],
            capture_output=True,
            text=True
        );
        if compiled.returncode != 0 {
            raise RuntimeError(
                f"cc -c failed (rc={compiled.returncode}):\n{compiled.stderr}"
            );
        }
        objs.append(obj_path);
        i += 1;
    }
    drv = os.path.join(work, "driver.c");
    with open(drv, "w") as f {
        f.write(driver);
    }
    binp = os.path.join(work, "bin");
    linked = subprocess.run(
        [compiler, "-std=c11", *incs, *objs, drv, "-o", binp],
        capture_output=True,
        text=True
    );
    if linked.returncode != 0 {
        raise RuntimeError(
            f"cc link failed (rc={linked.returncode}):\n{linked.stderr}"
        );
    }
    try {
        proc = subprocess.run(
            [binp], capture_output=True, text=True, timeout=timeout
        );
    } except subprocess.TimeoutExpired {
        return HANG;
    }
    if proc.returncode != 0 {
        raise RuntimeError(
            f"C binary failed (rc={proc.returncode}):\n{proc.stderr}"
        );
    }
    line = int_tuple_line(proc.stdout, 1);
    if line is None {
        raise RuntimeError(f"no int line in C stdout:\n{proc.stdout}");
    }
    return line;
}


def lift_to_jac(c_path: str, include_dirs: list[str] | None = None) -> str {
    res = lift_c_file(c_path, include_dirs=include_dirs);
    assert not any(
        [d[0].startswith("E") for d in res.diags]
    ) , f"lift errors: {res.diags}";
    return res.module.unparse(requires_format=True);
}


def run_lifted(
    jac_src: str,
    entry_src: str,
    label: str = "",
    timeout: float = DEFAULT_TIMEOUT
) -> tuple[str, int, str, str] {
    # Returns (line_or_HANG_or_empty, returncode, stdout, stderr).
    # Hang → (HANG, -1, "", ""); success with int line → (line, 0, ...);
    # non-zero exit → ("", rc, stdout, stderr).
    work = tempfile.mkdtemp();
    path = os.path.join(work, "lifted.jac");
    with open(path, "w") as f {
        f.write(jac_src);
        f.write("\n\n");
        f.write(entry_src);
    }
    try {
        proc = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", path],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False
        );
    } except subprocess.TimeoutExpired {
        return (HANG, -1, "", "");
    }
    if proc.returncode != 0 {
        return ("", proc.returncode, proc.stdout, proc.stderr);
    }
    line = int_tuple_line(proc.stdout, 1);
    if line is None {
        return ("", 0, proc.stdout, proc.stderr);
    }
    return (line, 0, proc.stdout, proc.stderr);
}


def run_lifted_trap(
    jac_src: str,
    entry_src: str,
    label: str = "",
    timeout: float = DEFAULT_TIMEOUT
) -> bool {
    # True iff the lifted entry traps with the quarantine message (not hang,
    # not a clean return).
    (line, rc, out, err) = run_lifted(jac_src, entry_src, label, timeout=timeout);
    if line == HANG {
        return False;
    }
    if rc == 0 {
        return False;
    }
    return "quarantined function" in (out + err);
}


def assert_lift_matches_c(
    c_path: str,
    c_driver: str,
    jac_entry: str,
    include_dirs: list[str] | None = None,
    timeout: float = DEFAULT_TIMEOUT
) {
    # MATCH-only helper (minilib / arr_sum). Hang or trap fails the assertion.
    if cc() is None {
        return;
    }
    incs = include_dirs or [os.path.dirname(c_path)];
    c_out = run_c([c_path], incs, c_driver, timeout=timeout);
    assert c_out != HANG , f"{c_path}: C hung under timeout={timeout}";
    jac_src = lift_to_jac(c_path, include_dirs=include_dirs);
    (j_out, rc, out, err) = run_lifted(jac_src, jac_entry, c_path, timeout=timeout);
    assert j_out != HANG , f"{c_path}: lifted Jac hung under timeout={timeout}";
    assert rc == 0 , (
        f"{c_path}: lifted Jac failed (rc={rc}):\nstdout:\n{out}\nstderr:\n{err}"
    );
    assert j_out , f"{c_path}: no int line in jac stdout:\n{out}";
    assert c_out == j_out , f"oracle mismatch: cc={c_out!r} jac={j_out!r}";
}


def assert_lift_matches_c_or_traps(
    c_path: str,
    c_driver: str,
    jac_entry: str,
    entry_fn: str,
    include_dirs: list[str] | None = None,
    timeout: float = DEFAULT_TIMEOUT
) -> tuple[str, str] {
    # Auto-derive MATCH vs TRAP from whether `entry_fn` is quarantined.
    # Returns (status, detail) with status in {ok, mismatch, hang, wrong-regime}.
    if cc() is None {
        return ("ok", "skipped: no cc");
    }
    incs = include_dirs or [os.path.dirname(c_path)];
    try {
        res = lift_c_file(c_path, include_dirs=include_dirs);
    } except Exception as e {
        return ("mismatch", f"lift raised: {e}");
    }
    if any([d[0].startswith("E") for d in res.diags]) {
        return ("mismatch", f"lift errors: {res.diags}");
    }
    jac_src = res.module.unparse(requires_format=True);
    expect_trap = entry_fn in res.quarantined_functions;

    try {
        c_out = run_c([c_path], incs, c_driver, timeout=timeout);
    } except Exception as e {
        return ("mismatch", f"C side failed: {e}");
    }
    if c_out == HANG {
        return ("hang", f"C hung under timeout={timeout}");
    }

    if expect_trap {
        (line, rc, out, err) = run_lifted(
            jac_src, jac_entry, c_path, timeout=timeout
        );
        if line == HANG {
            return ("hang", f"expected TRAP for '{entry_fn}' but hung");
        }
        if rc == 0 {
            return (
                "wrong-regime",
                f"expected TRAP for quarantined '{entry_fn}' but returned {line!r}"
            );
        }
        if "quarantined function" not in (out + err) {
            return (
                "wrong-regime",
                f"expected quarantine trap for '{entry_fn}' "
                f"(rc={rc}):\nstdout:\n{out}\nstderr:\n{err}"
            );
        }
        return ("ok", "trap");
    }

    (j_out, rc, out, err) = run_lifted(jac_src, jac_entry, c_path, timeout=timeout);
    if j_out == HANG {
        return ("hang", f"expected MATCH for '{entry_fn}' but hung");
    }
    if rc != 0 {
        if "quarantined function" in (out + err) {
            return (
                "wrong-regime",
                f"expected MATCH for '{entry_fn}' but hit quarantine trap"
            );
        }
        return (
            "mismatch",
            f"lifted Jac failed (rc={rc}):\nstdout:\n{out}\nstderr:\n{err}"
        );
    }
    if not j_out {
        return ("mismatch", f"no int line in jac stdout:\n{out}");
    }
    if c_out != j_out {
        return ("mismatch", f"cc={c_out!r} jac={j_out!r}");
    }
    return ("ok", "match");
}
