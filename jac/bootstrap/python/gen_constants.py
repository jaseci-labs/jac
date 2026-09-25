"""Generate a module's platform constants from the target's C headers.

C extension modules publish system constants with `PyModule_AddIntMacro(m, X)`
and similar macros guarded by `#ifdef X`. Their values differ between C
libraries (errno, fcntl, resource, termios, socket), so the Jac port reads them
from a generated per-OS file instead of a hand-written table:

    python3 jac/bootstrap/python/gen_constants.py errno
    python3 jac/bootstrap/python/gen_constants.py errno --cc "zig cc -target aarch64-macos"
    python3 jac/bootstrap/python/gen_constants.py errno --check

The script collects the constant names from the module's C source in the
pinned archive, preprocesses them against the headers the module includes
with the target compiler (`cc -E`), evaluates the resulting integer
expressions and writes jaclang/runtime/python/modules/<name>_constants.<os>.jac
with one glob per defined name and a CONSTANTS list in source order. There is
deliberately no OS-neutral file: a platform without a generated table fails to
resolve instead of reusing another platform's values.
"""
from __future__ import annotations

import argparse
import ast
import hashlib
import json
import operator
import re
import shlex
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from jac_format import format_jac  # noqa: E402

HERE = Path(__file__).resolve().parent
JAC = HERE.parents[1]
OUTPUT = JAC / "jaclang/runtime/python/modules"
PATTERNS = [
    r"\bADD_INT_MACRO\(\s*\w+\s*,\s*(\w+)\s*\)",
    r"\bADD_INT\(\s*\w+\s*,\s*(\w+)\s*\)",
    r"\bPyModule_AddIntMacro\(\s*\w+\s*,\s*(\w+)\s*\)",
    r"\bINS\(\s*(\w+)\s*\)",
    r"\badd_errcode\(\s*\"(\w+)\"",
    r"\bPyModule_AddIntConstant\(\s*\w+\s*,\s*\"(\w+)\"\s*,\s*\1\s*\)",
]
OPERATORS = {
    ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
    ast.FloorDiv: operator.floordiv, ast.LShift: operator.lshift,
    ast.RShift: operator.rshift, ast.BitOr: operator.or_, ast.BitAnd: operator.and_,
    ast.BitXor: operator.xor,
}


def pinned_source(module_file: str) -> str:
    pin = json.loads((HERE / "sources.json").read_text())["cpython"]
    archive = JAC / ".python-build/jacpython/sources" / f"{pin['sha256']}.tar.gz"
    if hashlib.sha256(archive.read_bytes()).hexdigest() != pin["sha256"]:
        sys.exit(f"{archive} does not match the pinned SHA256")
    with tarfile.open(archive) as bundle:
        for member in bundle.getmembers():
            if member.name.split("/", 1)[-1] == module_file:
                return bundle.extractfile(member).read().decode()
    sys.exit(f"{module_file} is not in the pinned archive")


# The C source each module's constants come from, and the system headers that
# define them. Each include is guarded by __has_include, so one list serves
# every platform.
SOURCES = {
    "errno": ("Modules/errnomodule.c", ["errno.h"]),
    "fcntl": ("Modules/fcntlmodule.c", ["fcntl.h", "sys/ioctl.h", "sys/file.h", "linux/fs.h"]),
    "resource": ("Modules/resource.c", ["sys/resource.h", "sys/time.h", "unistd.h"]),
    "syslog": ("Modules/syslogmodule.c", ["syslog.h"]),
    "termios": ("Modules/termios.c", ["termios.h", "sys/ioctl.h", "sys/termios.h"]),
    "select": ("Modules/selectmodule.c", ["sys/select.h", "poll.h", "sys/epoll.h", "sys/event.h", "sys/devpoll.h"]),
    "mmap": ("Modules/mmapmodule.c", ["sys/mman.h", "unistd.h"]),
    "_socket": ("Modules/socketmodule.c", ["sys/socket.h", "netinet/in.h", "netinet/tcp.h", "netdb.h", "sys/un.h", "linux/netlink.h", "linux/can.h", "net/if.h", "sys/ioctl.h"]),
    "_signal": ("Modules/signalmodule.c", ["signal.h", "sys/time.h"]),
    "posix": ("Modules/posixmodule.c", ["unistd.h", "fcntl.h", "sys/stat.h", "sys/wait.h", "sys/mman.h", "sched.h", "sys/xattr.h", "sys/random.h", "linux/random.h", "spawn.h", "sys/statvfs.h"]),
    "_locale": ("Modules/_localemodule.c", ["locale.h", "langinfo.h", "libintl.h"]),
    "time": ("Modules/timemodule.c", ["time.h", "sys/time.h"]),
}


# Values the C module uses internally rather than publishing with a macro.
EXTRA = {"resource": ["RLIM_INFINITY", "RLIM_NLIMITS"]}


def source_file(module: str) -> str:
    if module not in SOURCES:
        sys.exit(f"No constant source recorded for {module}")
    return SOURCES[module][0]


def names_in(source: str) -> list[str]:
    found: list[str] = []
    for line in source.splitlines():
        for pattern in PATTERNS:
            for match in re.finditer(pattern, line):
                # Skip the parameter names of the macro definitions themselves.
                if match.group(1) not in found and match.group(1) not in ("value", "macro", "c", "name"):
                    found.append(match.group(1))
    return found


def includes_for(module: str) -> list[str]:
    lines = []
    for header in SOURCES[module][1]:
        lines += [f"#if __has_include(<{header}>)", f"#include <{header}>", "#endif"]
    return lines


def evaluate(text: str) -> int | None:
    text = re.sub(r"\(\s*(?:unsigned\s+)?(?:int|long|long long|short|char|u?int\d+_t|size_t|mode_t|tcflag_t|speed_t|cc_t)\s*\)", "", text)
    text = re.sub(r"(?<=\d)(?:[uU]?[lL]{0,2}|[lL]{1,2}[uU])\b", "", text)
    text = re.sub(r"\b0([0-7]+)\b", r"0o\1", text)
    try:
        tree = ast.parse(text.strip(), mode="eval").body
    except SyntaxError:
        return None

    def walk(node):
        if isinstance(node, ast.Constant) and isinstance(node.value, int):
            return node.value
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.USub):
            return -walk(node.operand)
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, ast.Invert):
            return ~walk(node.operand)
        if isinstance(node, ast.BinOp) and type(node.op) in OPERATORS:
            return OPERATORS[type(node.op)](walk(node.left), walk(node.right))
        raise ValueError(ast.dump(node))

    try:
        return walk(tree)
    except (ValueError, TypeError):
        return None


def extract(names: list[str], includes: list[str], compiler: list[str]) -> dict[str, int]:
    """Values as the target compiler folds them, read back from its assembly.

    Constants can be enumerators (glibc's RLIMIT_*) as well as macros, so the
    preprocessor alone is not enough; compiling to assembly needs no target
    execution, which keeps cross-compilers usable.
    """
    lines = ["#define _GNU_SOURCE 1", "#define _DARWIN_C_SOURCE 1"] + includes
    for name in names:
        lines += [f"#ifdef {name}", f"const long long __jac_const_{name} = (long long)({name});", "#endif"]
    with tempfile.NamedTemporaryFile("w", suffix=".c", delete=False) as handle:
        handle.write("\n".join(lines) + "\n")
    result = subprocess.run(compiler + ["-S", "-O0", "-o", "-", handle.name], capture_output=True, text=True)
    Path(handle.name).unlink()
    if result.returncode != 0:
        sys.exit(result.stderr)
    values: dict[str, int] = {}
    current = None
    for line in result.stdout.splitlines():
        label = re.match(r"^_?__jac_const_(\w+):", line.strip())
        if label:
            current = label.group(1)
            continue
        data = re.match(r"^\.(?:quad|xword|8byte|dword)\s+(-?\w+)", line.strip())
        if current and data:
            values[current] = int(data.group(1), 0)
            values[current] -= (1 << 64) if values[current] >= (1 << 63) else 0
            current = None
        elif current and re.match(r"^\.zero\s+8", line.strip()):
            values[current] = 0
            current = None
    return values


def render(module: str, target_os: str, names: list[str], values: dict[str, int]) -> str:
    defined = [name for name in names if name in values]
    lines = [
        f'"""{module} constants from the {target_os} C headers.',
        "",
        "Generated by jac/bootstrap/python/gen_constants.py; do not edit.",
        '"""',
        "",
    ]
    lines.append(f'glob:pub PLATFORM: str = "{target_os}";')
    lines += [f"glob:pub {name}: i64 = {values[name]};" for name in defined]
    lines.append("")
    lines.append("glob:pub CONSTANTS: list[tuple[str, i64]] = [")
    lines += [f'    ("{name}", {name}),' for name in defined]
    lines.append("];")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate platform constants for a JacPython module")
    parser.add_argument("module")
    parser.add_argument("--cc", default="cc", help="target C compiler command")
    parser.add_argument("--os", default=sys.platform.replace("darwin", "darwin").replace("linux", "linux"))
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    source = pinned_source(source_file(args.module))
    names = names_in(source) + [n for n in EXTRA.get(args.module, []) if n not in names_in(source)]
    values = extract(names, includes_for(args.module), shlex.split(args.cc))
    target = OUTPUT / f"{args.module.lstrip('_')}_constants.{args.os}.jac"
    text = format_jac(render(args.module, args.os, names, values), target)
    if args.check:
        if not target.is_file() or target.read_text() != text:
            sys.exit(f"{target} is stale; rerun gen_constants.py {args.module}")
        print(f"{target.name} is current")
        return
    target.write_text(text)
    print(f"wrote {target} ({len(values)} of {len(names)} names defined)")
    # The plain module only exists so a platform without a generated table
    # resolves to something the binding can reject. It declares every name any
    # generated table has, as 0, so Jac code type-checks for every target.
    stub = OUTPUT / f"{args.module.lstrip('_')}_constants.jac"
    known: list[str] = []
    for generated in sorted(OUTPUT.glob(f"{args.module.lstrip('_')}_constants.*.jac")):
        # jac fmt combines consecutive globs, so names also follow commas.
        for name in re.findall(r"^\s*(?:glob:pub\s+)?(\w+): i64 =", generated.read_text(), re.M):
            if name not in known:
                known.append(name)
    stub_lines = [
        f'"""{args.module} constants for a platform gen_constants.py has not run for."""',
        "",
        'glob:pub PLATFORM: str = "";',
    ]
    stub_lines += [f"glob:pub {name}: i64 = 0;" for name in known]
    stub_lines += ["", "glob:pub CONSTANTS: list[tuple[str, i64]] = [];"]
    stub.write_text(format_jac("\n".join(stub_lines) + "\n", stub))


if __name__ == "__main__":
    main()
