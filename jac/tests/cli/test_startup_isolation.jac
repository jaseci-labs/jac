"""Import isolation checks for manifest-backed CLI fast paths.

Jac bootstrap (including jac0core.runtime) is accepted as the startup floor.
These tests assert that lightweight informational paths do not eagerly import
command implementations or optional feature packages.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from tests.support { JAC_ROOT }

# Heavy imports that manifest routing should avoid on fast paths.
glob _HEAVY_IMPORTS: set[str] = {
         "jaclang.compiler",
         "jaclang.cli.commands",
         "jaclang.runtimelib.client",
         "jaclang.scale",
         "jaclang.byllm",

     };


def _probe(argv: list[str], blocked: (set[str] | None) = None) -> tuple[int, str] {
    use_blocked = blocked if blocked is not None else _HEAVY_IMPORTS;
    blocked_repr = repr(sorted(use_blocked));
    argv_repr = repr(["jac"] + argv);
    script = f"""
import os, sys, runpy
sys.path.insert(0, {JAC_ROOT!r})
os.chdir({JAC_ROOT!r})
BLOCKED = set({blocked_repr})
real_import = __builtins__.__import__
def tracking_import(name, globals=None, locals=None, fromlist=(), level=0):
    for key in (name, name.split('.')[0]):
        if key in BLOCKED:
            raise ImportError(f"blocked: {{name}}")
    return real_import(name, globals, locals, fromlist, level)
__builtins__.__import__ = tracking_import
sys.argv = {argv_repr}
try:
    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
except SystemExit as exc:
    raise SystemExit(int(exc.code) if isinstance(exc.code, int) else 1)
""";
    proc = subprocess.run(
        [sys.executable, "-c", script], cwd=JAC_ROOT, capture_output=True, text=True,
    );
    return (proc.returncode, proc.stderr + proc.stdout);
}


def _probe_in_cwd(
    cwd: str, argv: list[str], blocked: (set[str] | None) = None
) -> tuple[int, str] {
    use_blocked = blocked if blocked is not None else _HEAVY_IMPORTS;
    blocked_repr = repr(sorted(use_blocked));
    argv_repr = repr(["jac"] + argv);
    script = f"""
import os, sys, runpy
sys.path.insert(0, {JAC_ROOT!r})
os.chdir({cwd!r})
BLOCKED = set({blocked_repr})
real_import = __builtins__.__import__
def tracking_import(name, globals=None, locals=None, fromlist=(), level=0):
    for key in (name, name.split('.')[0]):
        if key in BLOCKED:
            raise ImportError(f"blocked: {{name}}")
    return real_import(name, globals, locals, fromlist, level)
__builtins__.__import__ = tracking_import
sys.argv = {argv_repr}
try:
    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
except SystemExit as exc:
    raise SystemExit(int(exc.code) if isinstance(exc.code, int) else 1)
""";
    proc = subprocess.run(
        [sys.executable, "-c", script], cwd=cwd, capture_output=True, text=True,
    );
    return (proc.returncode, proc.stderr + proc.stdout);
}


test "version fast path avoids heavy imports" {
    (code, err) = _probe(["--version"]);
    assert code == 0 , err;
}

test "help fast path avoids heavy imports" {
    (code, err) = _probe(["--help"]);
    assert code == 0 , err;
}

test "bare invocation avoids heavy imports" {
    (code, err) = _probe([]);
    assert code == 0 , err;
}

test "unknown command avoids heavy imports" {
    (code, err) = _probe(["not-a-real-command"]);
    assert code == 2 , err;
}

test "hidden commands dispatch via manifest" {
    for argv in (["gen-jir-registry", "--help"], ["nacompile", "--help"]) {
        (code, err) = _probe(argv, blocked=set());
        assert code == 0 , f"jac {' '.join(argv)} failed: {err}";
    }
}

test "purge avoids heavy imports" {
    (code, err) = _probe(["purge", "--help"]);
    assert code == 0 , err;
}

test "command help isolates features" {
    for argv in (
        ["run", "--help"],
        ["check", "--help"],
        ["fmt", "--help"],
        ["code", "--help"],
        ["test", "--help"],
        ["build", "--help"],
        ["start", "--help"],
        ["setup", "--help"],
        ["scale", "--help"],
        ["model", "--help"],
        ["retheme", "--help"],

    ) {
        (code, err) = _probe(argv);
        assert code == 0 , (
            f"jac {' '.join(argv)} leaked heavy imports or failed:\n{err}"
        );
    }
}

test "command help preserves terminator" {
    (code, _) = _probe(["run", "--", "--help"], blocked=set());
    assert code != 0;
}

test "malformed jac.toml does not block global help" {
    with tempfile.TemporaryDirectory() as tmp {
        toml = Path(tmp) / "jac.toml";
        toml.write_text('[project\nname = "broken"\n', encoding="utf-8");
        for argv in (["--help"], ["--version"], []) {
            (code, err) = _probe_in_cwd(tmp, argv);
            assert code == 0 , f"jac {' '.join(argv) or '(bare)'} failed:\n{err}";
        }
    }
}

test "malformed jac.toml does not block command help" {
    with tempfile.TemporaryDirectory() as tmp {
        toml = Path(tmp) / "jac.toml";
        toml.write_text('[project\nname = "broken"\n', encoding="utf-8");
        for argv in (["build", "--help"], ["run", "--help"]) {
            (code, err) = _probe_in_cwd(tmp, argv);
            assert code == 0 , f"jac {' '.join(argv)} failed:\n{err}";
        }
    }
}
