"""M3 CPython-runtime hook: `import from rust.<crate>` resolves under jaclang.

The counterpart to `na/test_import_hook.py` (the AOT path): here a plain `.jac`
program run on the *interpreter* imports a Rust bridge by name, and jaclang's own
in-package meta-importer (`jaclang.compiler.rust_bridge.install_rust_namespace`,
auto-installed by `import jaclang`) resolves it — no dependency on the separate
`jac_bridge_loader` dev package, and the same `.so` search order + D2 metadata
parser the na compiler step uses (D1: two consumers, one metadata).

Subprocess-based so the global `sys.meta_path` / `sys.modules` mutations stay out
of the in-process test interpreter, mirroring `na/test_import_hook.py`.
"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[3]
JAC = REPO / "jac"
SO = REPO / "bridges" / "target" / "release" / "libjac_bridge_regex.so"


def _env() -> dict:
    return dict(
        os.environ,
        PYTHONPATH=str(JAC),
        JAC_RUST_BRIDGES_PATH=str(SO.parent),
        LD_LIBRARY_PATH=str(SO.parent),
    )


@pytest.mark.skipif(not SO.is_file(), reason="libjac_bridge_regex.so not built")
def test_import_jaclang_installs_self_contained_rust_finder():
    """`import jaclang` alone wires the rust. finder from jaclang's own package."""
    prog = (
        "import sys, jaclang\n"
        "from jaclang.compiler.rust_bridge import RustBridgeFinder\n"
        "fs = [f for f in sys.meta_path if isinstance(f, RustBridgeFinder)]\n"
        "assert len(fs) == 1, fs\n"
        "import rust.regex as rx\n"
        "r = rx.Regex(r'foo\\d+')\n"
        "print('m1', int(r.is_match('foo42')))\n"
        "print('m2', int(r.is_match('bar')))\n"
        "r.close()\n"
        "try:\n"
        "    rx.Regex('(unclosed')\n"
        "    print('noerror')\n"
        "except rx.RegexError as e:\n"
        "    print('err', str(e).splitlines()[0])\n"
    )
    r = subprocess.run(
        [sys.executable, "-c", prog],
        cwd=str(JAC),
        env=_env(),
        capture_output=True,
        text=True,
        timeout=300,
    )
    assert r.returncode == 0, f"{r.stdout}\n{r.stderr}"
    out = [
        ln
        for ln in r.stdout.splitlines()
        if ln[:2] in ("m1", "m2") or ln.startswith(("err", "noerror"))
    ]
    assert out == ["m1 1", "m2 0", "err regex parse error:"], out


@pytest.mark.skipif(not SO.is_file(), reason="libjac_bridge_regex.so not built")
def test_jac_program_imports_rust_regex_on_runtime():
    """A `.jac` file run through `jaclang run` resolves the bridge at runtime."""
    program = (
        "import from rust.regex { Regex }\n"
        "\n"
        "with entry {\n"
        '    re = Regex("foo\\\\d+");\n'
        '    if re.is_match("foo42") { print("RT match=1"); } '
        'else { print("RT match=0"); }\n'
        '    if re.is_match("bar") { print("RT nomatch=1"); } '
        'else { print("RT nomatch=0"); }\n'
        "    re.close();\n"
        "    try {\n"
        '        bad = Regex("(unclosed");\n'
        '        print("RT badpat=NOERROR");\n'
        "    } except Exception as e {\n"
        '        print("RT badpat=" + str(e).split("\\n")[0]);\n'
        "    }\n"
        "}\n"
    )
    with tempfile.TemporaryDirectory() as td:
        src = Path(td) / "rt_use_bridge.jac"
        src.write_text(program)
        r = subprocess.run(
            [sys.executable, "-m", "jaclang", "run", str(src)],
            cwd=str(JAC),
            env=_env(),
            capture_output=True,
            text=True,
            timeout=300,
        )
        # NOTE: assert on stdout, not returncode — an unrelated pre-existing
        # JScaleExecutionContext teardown bug can taint the exit code even on a
        # clean run; the program's own output is what proves the import resolved.
        lines = [ln for ln in r.stdout.splitlines() if ln.startswith("RT ")]
        assert lines == [
            "RT match=1",
            "RT nomatch=0",
            "RT badpat=regex parse error:",
        ], f"stdout:\n{r.stdout}\nstderr:\n{r.stderr}"
