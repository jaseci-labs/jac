"""Shared libtest runner: host CPython smoke + staged Jac differential.

Host path runs embedded Python snippets on the system interpreter (backward
compatible).  Jac differential path executes checked-in ``jac-py/Modules/*.jac``
via ``jac run`` when ``can_run_jac_differential`` passes.

Set ``JACPY_LIBTEST_JAC_DIFF=0`` to disable the staged-Jac differential leg.

The JacPython leg runs embedded Python snippets through ``layer_p2_libtest`` with
shim modules backed by ``jacpython/*.jac`` facades.  Set ``JACPY_LIBTEST_JACPYTHON=0`` to disable.
"""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }
import from tests.jacpy.libtest_snippets { LIBTEST_SNIPPETS, LibtestSnippet }


glob REPO_ROOT: str = os.path.dirname(JAC_ROOT),
     MODULES: str = os.path.join(REPO_ROOT, "jac-py", "Modules"),
     JACPYTHON_DIR: str = os.path.join(REPO_ROOT, "jac-py", "jacpython"),
     JAC_DIFF_ENV: str = "JACPY_LIBTEST_JAC_DIFF",
     JACPYTHON_ENV: str = "JACPY_LIBTEST_JACPYTHON",
     DEFAULT_TIMEOUT: float = 15.0,
     JAC_RUN_TIMEOUT: float = 120.0;


def jac_diff_enabled() -> bool {
    v = os.environ.get(JAC_DIFF_ENV, "1");
    return v not in ["0", "false", "False", ""];
}


def jacpython_enabled() -> bool {
    v = os.environ.get(JACPYTHON_ENV, "1");
    return v not in ["0", "false", "False", ""];
}


def jacpython_facade_path(stem: str) -> str {
    return os.path.join(JACPYTHON_DIR, f"{stem}.jac");
}


def can_run_jacpython_libtest(`case: LibtestSnippet) -> bool {
    if not jacpython_enabled() {
        return False;
    }
    if not `case.jacpython_capable {
        return False;
    }
    # JacPython leg imports ``jacpython/{stem}.jac`` facades (mirrors staged Modules).
    # Staged ``Modules/{stem}.jac`` is the lift oracle; runtime uses the facade.
    return os.path.isfile(jacpython_facade_path(`case.module_stem));
}


def staged_jac_path(stem: str) -> str {
    return os.path.join(MODULES, f"{stem}.jac");
}


def can_run_jac_differential(stem: str) -> bool {
    if not jac_diff_enabled() {
        return False;
    }
    return os.path.isfile(staged_jac_path(stem));
}


def host_python() -> str {
    for name in ["python3.14", "python3", "python"] {
        found = shutil.which(name);
        if found {
            return found;
        }
    }
    return sys.executable;
}


def run_host_snippet(
    code: str,
    expect_stdout: str = "ok",
    timeout: float = DEFAULT_TIMEOUT
) -> tuple[bool, str] {
    proc = subprocess.run(
        [host_python(), "-c", code],
        capture_output=True,
        text=True,
        timeout=timeout
    );
    stdout = (proc.stdout or "").strip();
    stderr = (proc.stderr or "").strip();
    if proc.returncode != 0 {
        return (False, stderr or stdout or f"exit {proc.returncode}");
    }
    if stdout != expect_stdout {
        return (
            False,
            f"expected stdout {expect_stdout!r}, got {stdout!r}"
        );
    }
    return (True, stdout);
}


def libtest_jac_expect_stdout(`case: LibtestSnippet) -> str {
    if `case.jac_expect_stdout {
        return `case.jac_expect_stdout;
    }
    return `case.expect_stdout;
}


def _jac_run_argv() -> list[str] {
    jac_env = os.environ.get("JAC");
    if jac_env and os.path.isfile(jac_env) {
        return [jac_env, "run"];
    }
    py = os.path.join(REPO_ROOT, ".venv", "bin", "python");
    if os.path.isfile(py) {
        return [py, "-m", "jaclang", "run"];
    }
    jac_bin = os.path.join(REPO_ROOT, ".venv", "bin", "jac");
    if os.path.isfile(jac_bin) {
        return [jac_bin, "run"];
    }
    return [sys.executable, "-m", "jaclang", "run"];
}


def _jac_run_env() -> dict[str, str] {
    env = dict(os.environ);
    jac_src = os.path.join(REPO_ROOT, "jac");
    existing = env.get("PYTHONPATH", "");
    if jac_src not in existing.split(os.pathsep) {
        env["PYTHONPATH"] = (
            jac_src if not existing else f"{jac_src}{os.pathsep}{existing}"
        );
    }
    return env;
}


def run_jac_staged(
    stem: str,
    entry_src: str,
    expect_stdout: str = "ok",
    preamble: str = "",
    timeout: float = JAC_RUN_TIMEOUT
) -> tuple[bool, str] {
    jac_path = staged_jac_path(stem);
    if not os.path.isfile(jac_path) {
        return (False, f"missing staged module {jac_path}");
    }
    with open(jac_path) as f {
        jac_src = f.read();
    }
    # lift_oracle.run_lifted / assert_staged_jac_matches_c: module + preamble + entry.
    tail = entry_src;
    if preamble {
        tail = preamble + entry_src;
    }
    work = tempfile.mkdtemp();
    path = os.path.join(work, "libtest_staged.jac");
    with open(path, "w") as f {
        f.write(jac_src);
        f.write("\n\n");
        f.write(tail);
    }
    try {
        proc = subprocess.run(
            [*_jac_run_argv(), path],
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
            cwd=REPO_ROOT,
            env=_jac_run_env()
        );
    } except subprocess.TimeoutExpired {
        return (False, "timeout");
    }
    if proc.returncode != 0 {
        detail = (proc.stderr or proc.stdout or "").strip();
        return (False, detail or f"exit {proc.returncode}");
    }
    stdout = (proc.stdout or "").strip();
    if stdout != expect_stdout {
        return (
            False,
            f"expected stdout {expect_stdout!r}, got {stdout!r}"
        );
    }
    return (True, stdout);
}


def run_libtest_host(`case: LibtestSnippet) -> tuple[bool, str] {
    return run_host_snippet(`case.code, `case.expect_stdout);
}


def run_libtest_jacpython(`case: LibtestSnippet) -> tuple[str, str] {
    # Returns (status, detail) with status in pass | fail | skip.
    if not can_run_jacpython_libtest(`case) {
        return (
            "skip",
            f"{`case.name} not jacpython-capable or disabled"
        );
    }
    bridge = os.path.join(REPO_ROOT, "jac-py", "tools", "p2_libtest_jacpython_bridge.py");
    py = os.path.join(REPO_ROOT, ".venv", "bin", "python");
    if not os.path.isfile(py) {
        py = sys.executable;
    }
    try {
        proc = subprocess.run(
            [py, bridge, `case.code, "--expect", libtest_jac_expect_stdout(`case)],
            capture_output=True,
            text=True,
            timeout=JAC_RUN_TIMEOUT,
            cwd=REPO_ROOT,
            env=_jac_run_env()
        );
    } except subprocess.TimeoutExpired {
        return ("fail", "timeout");
    }
    if proc.returncode != 0 {
        detail = (proc.stderr or proc.stdout or "").strip();
        return ("fail", detail or f"exit {proc.returncode}");
    }
    stdout = (proc.stdout or "").strip();
    return ("pass", stdout);
}


def run_libtest_jac_differential(`case: LibtestSnippet) -> tuple[str, str] {
    # Returns (status, detail) with status in pass | fail | skip.
    if not `case.jac_entry {
        return ("skip", "no jac differential entry");
    }
    if not can_run_jac_differential(`case.module_stem) {
        return (
            "skip",
            f"staged {`case.module_stem}.jac unavailable or differential disabled"
        );
    }
    (ok, detail) = run_jac_staged(
        `case.module_stem,
        `case.jac_entry,
        libtest_jac_expect_stdout(`case),
        preamble=`case.jac_preamble
    );
    if ok {
        return ("pass", detail);
    }
    return ("fail", detail);
}


def _snippet_by_name(name: str) -> LibtestSnippet | None {
    for snip in LIBTEST_SNIPPETS {
        if snip.name == name {
            return snip;
        }
    }
    return None;
}


def run_libtest_host_for_gate(gate_snippets: list[str]) -> dict {
    passed = 0;
    failed = 0;
    cases: list = [];
    for snip_name in gate_snippets {
        snip = _snippet_by_name(snip_name);
        assert snip is not None , f"missing libtest snippet {snip_name}";
        (ok, detail) = run_libtest_host(snip);
        cases.append(
            {
                "name": snip.name,
                "passed": ok,
                "detail": detail if not ok else "ok",
            }
        );
        if ok {
            passed += 1;
        } else {
            failed += 1;
        }
    }
    return {
        "passed": passed,
        "failed": failed,
        "total": passed + failed,
        "cases": cases,
    };
}


def run_libtest_jacpython_for_gate(gate_snippets: list[str]) -> dict {
    passed = 0;
    failed = 0;
    skipped = 0;
    cases: list = [];
    for snip_name in gate_snippets {
        snip = _snippet_by_name(snip_name);
        assert snip is not None , f"missing libtest snippet {snip_name}";
        (status, detail) = run_libtest_jacpython(snip);
        cases.append(
            {
                "name": snip.name,
                "status": status,
                "detail": detail,
            }
        );
        if status == "pass" {
            passed += 1;
        } elif status == "fail" {
            failed += 1;
        } else {
            skipped += 1;
        }
    }
    return {
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": passed + failed + skipped,
        "cases": cases,
    };
}


def run_libtest_jac_differential_for_gate(gate_snippets: list[str]) -> dict {
    passed = 0;
    failed = 0;
    skipped = 0;
    cases: list = [];
    for snip_name in gate_snippets {
        snip = _snippet_by_name(snip_name);
        assert snip is not None , f"missing libtest snippet {snip_name}";
        (status, detail) = run_libtest_jac_differential(snip);
        cases.append(
            {
                "name": snip.name,
                "status": status,
                "detail": detail,
            }
        );
        if status == "pass" {
            passed += 1;
        } elif status == "fail" {
            failed += 1;
        } else {
            skipped += 1;
        }
    }
    return {
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "total": passed + failed + skipped,
        "cases": cases,
    };
}
