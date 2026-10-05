"""Generate a module's platform constants from the target's C headers.

C extension modules publish system constants with `PyModule_AddIntMacro(m, X)`
and similar macros guarded by `#ifdef X`. Their values differ between C
libraries (errno, fcntl, resource, termios, socket), so the Jac port reads them
from a generated per-OS file instead of a hand-written table:

    jac run scripts/jacpython/gen_constants.jac errno
    jac run scripts/jacpython/gen_constants.jac errno --cc "zig cc -target aarch64-macos" --os darwin
    jac run scripts/jacpython/gen_constants.jac errno --check

The script collects the constant names from the module's C source in the
pinned archive, compiles them against the headers the module includes with
the target compiler and reads the folded values back from its assembly, then
writes jaclang/runtime/python/modules/<name>_constants.<os>.jac with one glob
per defined name and a CONSTANTS list in source order. The plain
<name>_constants.jac carries PLATFORM = "" and every name as 0, so a platform
without a generated table type-checks and the binding rejects it at import.
"""
import argparse;
import re;
import shlex;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from common { RUNTIME, archive_texts, format_jac, write_or_check }

glob OUTPUT: Path = RUNTIME / "modules",
     PATTERNS: list[str] = [
         r"\bADD_INT_MACRO\(\s*\w+\s*,\s*(\w+)\s*\)",
         r"\bADD_INT\(\s*\w+\s*,\s*(\w+)\s*\)",
         r"\bPyModule_AddIntMacro\(\s*\w+\s*,\s*(\w+)\s*\)",
         r"\bINS\(\s*(\w+)\s*\)",
         r"\badd_errcode\(\s*\"(\w+)\"",
         r"\bPyModule_AddIntConstant\(\s*\w+\s*,\s*\"(\w+)\"\s*,\s*\1\s*\)"
     ],
     # Parameter names of the macro definitions themselves.
     MACRO_PARAMETERS: set[str] = {"value", "macro", "c", "name"},
     # The C source each module's constants come from, and the system headers
     # that define them. Each include is guarded by __has_include, so one list
     # serves every platform.
     SOURCES: dict[str, tuple[str, list[str]]] = {
         "errno": ("Modules/errnomodule.c", ["errno.h"]),
         "fcntl": (
             "Modules/fcntlmodule.c",
             ["fcntl.h", "sys/ioctl.h", "sys/file.h", "linux/fs.h"]
         ),
         "resource": (
             "Modules/resource.c",
             ["sys/resource.h", "sys/time.h", "unistd.h"]
         ),
         "syslog": ("Modules/syslogmodule.c", ["syslog.h"]),
         "termios": (
             "Modules/termios.c",
             ["termios.h", "sys/ioctl.h", "sys/termios.h"]
         ),
         "select": (
             "Modules/selectmodule.c",
             ["sys/select.h", "poll.h", "sys/epoll.h", "sys/event.h", "sys/devpoll.h"]
         ),
         "mmap": ("Modules/mmapmodule.c", ["sys/mman.h", "unistd.h"]),
         "_socket": (
             "Modules/socketmodule.c",
             [
                 "sys/socket.h",
                 "netinet/in.h",
                 "netinet/tcp.h",
                 "netdb.h",
                 "sys/un.h",
                 "linux/netlink.h",
                 "linux/can.h",
                 "net/if.h",
                 "sys/ioctl.h"
             ]
         ),
         "_signal": ("Modules/signalmodule.c", ["signal.h", "sys/time.h"]),
         "posix": (
             "Modules/posixmodule.c",
             [
                 "unistd.h",
                 "fcntl.h",
                 "sys/stat.h",
                 "sys/wait.h",
                 "sys/mman.h",
                 "sched.h",
                 "sys/xattr.h",
                 "sys/random.h",
                 "linux/random.h",
                 "spawn.h",
                 "sys/statvfs.h"
             ]
         ),
         "_locale": (
             "Modules/_localemodule.c",
             ["locale.h", "langinfo.h", "libintl.h"]
         ),
         "time": ("Modules/timemodule.c", ["time.h", "sys/time.h"])
     },
     # Values the C module uses internally rather than publishing with a macro.
     EXTRA: dict[str, list[str]] = {"resource": ["RLIM_INFINITY", "RLIM_NLIMITS"]};

def names_in(source: str) -> list[str] {
    found: list[str] = [];
    for line in source.splitlines() {
        for pattern in PATTERNS {
            for hit in re.finditer(pattern, line) {
                name = hit.group(1);
                if name not in found and name not in MACRO_PARAMETERS {
                    found.append(name);
                }
            }
        }
    }
    return found;
}

def includes_for(module: str) -> list[str] {
    lines: list[str] = [];
    for header in SOURCES[module][1] {
        lines += [f"#if __has_include(<{header}>)", f"#include <{header}>", "#endif"];
    }
    return lines;
}

# Values as the target compiler folds them, read back from its assembly.
# Constants can be enumerators (glibc's RLIMIT_*) as well as macros, so the
# preprocessor alone is not enough; compiling to assembly needs no target
# execution, which keeps cross-compilers usable.
def extract(
    names: list[str], includes: list[str], compiler: list[str]
) -> dict[str, int] {
    lines = ["#define _GNU_SOURCE 1", "#define _DARWIN_C_SOURCE 1"] + includes;
    for name in names {
        lines += [
            f"#ifdef {name}",
            f"const long long __jac_const_{name} = (long long)({name});",
            "#endif"
        ];
    }
    with tempfile.TemporaryDirectory() as scratch {
        probe = Path(scratch) / "constants.c";
        probe.write_text("\n".join(lines) + "\n");
        result = subprocess.run(
            compiler + ["-S", "-O0", "-o", "-", str(probe)],
            capture_output=True,
            text=True
        );
    }
    if result.returncode != 0 {
        sys.exit(result.stderr);
    }
    values: dict[str, int] = {};
    current: str | None = None;
    for line in result.stdout.splitlines() {
        line = line.strip();
        label = re.match(r"^_?__jac_const_(\w+):", line);
        if label {
            current = label.group(1);
            continue;
        }
        if current is None {
            continue;
        }
        data = re.match(r"^\.(?:quad|xword|8byte|dword)\s+(-?\w+)", line);
        if data {
            value = int(data.group(1), 0);
            values[current] = value - (1 << 64) if value >= (1 << 63) else value;
            current = None;
        } elif re.match(r"^\.zero\s+8", line) {
            values[current] = 0;
            current = None;
        }
    }
    return values;
}

def render(
    module: str, target_os: str, names: list[str], values: dict[str, int]
) -> str {
    defined = [
        name
        for name in names
        if name in values
    ];
    lines = [
        f'"""{module} constants from the {target_os} C headers.',
        "",
        "Generated by scripts/jacpython/gen_constants.jac; do not edit.",
        '"""',
        "",
        f'glob PLATFORM: str = "{target_os}";'
    ];
    lines += [f"glob {name}: i64 = {values[name]};" for name in defined];
    lines += ["", "glob CONSTANTS: list[tuple[str, i64]] = ["];
    lines += [f'    ("{name}", {name}),' for name in defined];
    lines.append("];");
    return "\n".join(lines) + "\n";
}

# Every name any generated table of `stem` declares, in first-seen order.
def known_names(stem: str) -> list[str] {
    known: list[str] = [];
    for generated in sorted(OUTPUT.glob(f"{stem}_constants.*.jac")) {
        # jac fmt combines consecutive globs, so names also follow commas.
        for name in re.findall(
            r"^\s*(?:glob\s+)?(\w+): i64 =", generated.read_text(), re.M
        ) {
            if name not in known {
                known.append(name);
            }
        }
    }
    return known;
}

def render_stub(module: str, names: list[str]) -> str {
    lines = [
        f'"""{module} constants for a platform gen_constants.jac has not run for."""',
        "",
        'glob PLATFORM: str = "";'
    ];
    lines += [f"glob {name}: i64 = 0;" for name in names];
    lines += ["", "glob CONSTANTS: list[tuple[str, i64]] = [];"];
    return "\n".join(lines) + "\n";
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate platform constants for a JacPython module"
    );
    parser.add_argument("module");
    parser.add_argument("--cc", help="target C compiler command");
    parser.add_argument("--os", help="target OS name in the output file");
    parser.set_defaults(cc="cc", os=sys.platform);
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    if args.module not in SOURCES {
        sys.exit(f"No constant source recorded for {args.module}");
    }
    source_file = SOURCES[args.module][0];
    texts = archive_texts((source_file, ));
    if source_file not in texts {
        sys.exit(f"{source_file} is not in the pinned archive");
    }
    names = names_in(texts[source_file]);
    names += [
        n
        for n in EXTRA.get(args.module, [])
        if n not in names
    ];
    values = extract(names, includes_for(args.module), shlex.split(args.cc));
    stem = args.module.lstrip("_");
    command = f"scripts/jacpython/gen_constants.jac {args.module}";
    target = OUTPUT / f"{stem}_constants.{args.os}.jac";
    current = write_or_check(
        target,
        format_jac(render(args.module, args.os, names, values), target),
        args.check,
        command
    );
    if not args.check {
        print(f"{len(values)} of {len(names)} names defined");
    }
    stub = OUTPUT / f"{stem}_constants.jac";
    current = write_or_check(
        stub,
        format_jac(render_stub(args.module, known_names(stem)), stub),
        args.check,
        command
    )
        and current;
    if not current {
        sys.exit(1);
    }
}
