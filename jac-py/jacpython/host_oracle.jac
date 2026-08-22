# TEST-ONLY host compilation oracle (PLAN.md P0.2 / P0.3).
#
# Runs host CPython compile() + marshal.dumps to obtain expected PyCode bytes
# for differential tests. Product compilation (compile_source) MUST NOT import
# this module.
#
# Transitional bootstrap policy (retire at P4 exit / PLAN.md P0.13):
#   layer0_replay, layer2_unittest, layer3_import, pyc_first carry their own
#   host compile bridges until the native front end replaces them.
#   pyc_first.host_compile_marshal is a duplicate of this bridge (bootstrap
#   isolation); do not add new duplicates — use this module from test harnesses.
#
# Allowed importers: layer4_compile.jac plus bootstrap allowlist in
# jac-py/tools/p4_import_gate.py.

::py::
import shutil
import subprocess
import sys
from pathlib import Path


def _runner_python():
    for name in ("python3.14", "python3", "python"):
        found = shutil.which(name)
        if found:
            return found
    return sys.executable


def _bridge_path():
    roots = [Path.cwd()]
    walk = Path.cwd()
    for _ in range(6):
        if walk not in roots:
            roots.append(walk)
        if walk.parent == walk:
            break
        walk = walk.parent
    for root in roots:
        script = root / "jac-py" / "tools" / "host_compile_marshal_bridge.py"
        if script.is_file():
            return str(script)
    raise RuntimeError("host_compile_marshal_bridge.py not found")


_BRIDGE = _bridge_path()


def _host_compile_marshal_py(source, filename, mode, optimize=0):
    payload = source
    if isinstance(source, str):
        payload = source.encode("utf-8")
    proc = subprocess.run(
        [_runner_python(), _BRIDGE, filename, mode, str(optimize)],
        input=payload,
        capture_output=True,
        check=True,
    )
    return proc.stdout


def _host_c_tokenize_py(source):
    import _tokenize
    lines = [source + "\n", ""]
    def readline():
        if lines:
            return lines.pop(0)
        return ""
    out = []
    it = _tokenize.TokenizerIter(readline, extra_tokens=False)
    for info in it:
        typ, spell, start, end = info[0], info[1], info[2], info[3]
        out.append(
            {
                "type": typ,
                "spelling": spell,
                "lineno": start[0],
                "col_offset": start[1],
                "end_lineno": end[0],
                "end_col_offset": end[1],
            }
        )
    return out
::py::



def host_compile_marshal(
    source: str, filename: str, mode: str, optimize: int = 0
) -> list[int] {
    raw = _host_compile_marshal_py(source, filename, mode, optimize);
    return raw as list[int];
}

def host_c_tokenize(source: str) -> list[dict] {
    return _host_c_tokenize_py(source) as list[dict];
}
