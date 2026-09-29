"""Generate a module's platform constants from the target's C headers.

C extension modules publish system constants with `PyModule_AddIntMacro(m, X)`
and similar macros guarded by `#ifdef X`. Their values differ between C
libraries (errno, fcntl, resource, termios, socket), so the Jac port reads them
from a generated per-OS file instead of a hand-written table:

    jac run scripts/jacpython/gen_constants.jac errno
    jac run scripts/jacpython/gen_constants.jac errno --cc "zig cc -target aarch64-macos" --os darwin
    jac run scripts/jacpython/gen_constants.jac errno --check
    jac run scripts/jacpython/gen_constants.jac mmap --cc "zig cc -target x86_64-linux-gnu" --os linux --arch x86_64

The script collects the constant names from the module's C source in the
pinned archive, compiles them against the headers the module includes with
the target compiler and reads the folded values back from its assembly, then
writes jaclang/runtime/python/modules/<name>_constants.<os>.jac with one glob
per defined name and a CONSTANTS list in source order; with --arch, for
constants one architecture of a system defines differently, the table is
<name>_constants.<os>.<arch>.jac. The plain
<name>_constants.jac carries PLATFORM = "" and every name as 0, so a platform
without a generated table type-checks and the binding rejects it at import.

With --pyconfig, the target build's configured pyconfig.h is part of the
probe: each constant is compiled under the preprocessor conditions that guard
it in the C source (`#if defined(HAVE_WAITID)`, `#ifdef HAVE_MEMFD_CREATE`),
and the table also carries FEATURES, the value of every configure HAVE_* macro
the source tests, for the Jac port's own conditionals. Tables of
`{"NAME", MACRO}` entries the module publishes as dicts (posix's
`sysconf_names`) come out as lists in source order. The feature values are
also written to bootstrap/python/features_check.c, which build.sh compiles
against every build's configuration, so a table that disagrees with its build
fails it.
"""
import argparse;
import re;
import shlex;
import subprocess;
import sys;
import tempfile;
import textwrap;
import from pathlib { Path }
import from common { RUNTIME, archive_texts, format_jac, write_or_check }

glob OUTPUT: Path = RUNTIME / "modules",
     PATTERNS: list[str] = [
         r"\bADD_INT_MACRO\(\s*\w+\s*,\s*(\w+)\s*\)",
         r"\bADD_INT\(\s*\w+\s*,\s*(\w+)\s*\)",
         r"\bPyModule_AddIntMacro\(\s*\w+\s*,\s*(\w+)\s*\)",
         r"\bINS\(\s*(\w+)\s*\)",
         r"\badd_errcode\(\s*\"(\w+)\"",
         r"\bPyModule_AddIntConstant\(\s*\w+\s*,\s*\"(\w+)\"\s*,\s*\1\s*\)",
         r"\bADD_INT\(\s*(\w+)\s*\)",
         # A static {"NAME", NAME} table (termios), possibly cast to long.
         r"\{\s*\"(\w+)\"\s*,\s*(?:\(long\)\s*)?\1\s*\}",
         r"\bLANGINFO\(\s*(\w+)\s*,"
     ],
     # Constants published under a name other than their macro's
     # (select's KQ_FILTER_READ is EVFILT_READ): (published, macro) groups.
     ALIAS_PATTERNS: list[str] = [
         r"\bADD_INT_CONST\(\s*\"(\w+)\"\s*,\s*([A-Za-z_]\w*)\s*\)",
         r"\bPyModule_AddIntConstant\(\s*\w+\s*,\s*\"(\w+)\"\s*,\s*([A-Za-z_]\w*)\s*\)"
     ],
     # The macro each aliased published name reads.
     MACROS: dict[str, str] = {},
     # The source condition guarding each published name.
     CONDITIONS: dict[str, str] = {},
     # The names the C source publishes (EXTRA ones excluded).
     PUBLISHED: set[str] = set(),
     # Parameter names of the macro definitions themselves.
     MACRO_PARAMETERS: set[str] = {"value", "macro", "c", "name", "VAL", "X"},
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
             ["termios.h", "sys/ioctl.h", "sys/termios.h", "unistd.h"]
         ),
         "_posixsubprocess": (
             "Modules/_posixsubprocess.c",
             ["unistd.h", "fcntl.h", "errno.h", "signal.h", "limits.h", "sys/syscall.h"]
         ),
         "select": (
             "Modules/selectmodule.c",
             [
                 "limits.h",
                 "sys/select.h",
                 "poll.h",
                 "sys/epoll.h",
                 "sys/event.h",
                 "sys/devpoll.h"
             ]
         ),
         "mmap": ("Modules/mmapmodule.c", ["sys/mman.h", "unistd.h", "fcntl.h"]),
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
         # posixmodule.c's own include order.
         "posix": (
             "Modules/posixmodule.c",
             [
                 "stdio.h",
                 "stdlib.h",
                 "unistd.h",
                 "sys/param.h",
                 "sys/time.h",
                 "sys/pidfd.h",
                 "sys/uio.h",
                 "sys/types.h",
                 "sys/sysmacros.h",
                 "sys/stat.h",
                 "sys/wait.h",
                 "linux/wait.h",
                 "signal.h",
                 "fcntl.h",
                 "grp.h",
                 "sysexits.h",
                 "sys/loadavg.h",
                 "sys/sendfile.h",
                 "copyfile.h",
                 "sched.h",
                 "linux/sched.h",
                 "sys/socket.h",
                 "dlfcn.h",
                 "linux/random.h",
                 "sys/syscall.h",
                 "spawn.h",
                 "utime.h",
                 "sys/times.h",
                 "sys/utsname.h",
                 "sys/mman.h",
                 "sys/memfd.h",
                 "linux/memfd.h",
                 "sys/eventfd.h",
                 "sys/timerfd.h",
                 "linux/limits.h",
                 "sys/xattr.h",
                 "sys/ioctl.h",
                 "termios.h",
                 "dirent.h",
                 "sys/resource.h",
                 "sys/statvfs.h",
                 "limits.h",
                 "errno.h"
             ]
         ),
         "_locale": (
             "Modules/_localemodule.c",
             ["locale.h", "langinfo.h", "libintl.h"]
         ),
         "time": ("Modules/timemodule.c", ["time.h", "sys/time.h"]),
         "_multiprocessing": (
             "Modules/_multiprocessing/semaphore.c",
             ["fcntl.h", "semaphore.h", "limits.h"]
         )
     },
     # Names a module's portable Jac code reads on every platform, declared as
     # 0 (and left out of CONSTANTS) where the headers do not define them.
     PORTABLE: dict[str, list[str]] = {
         "select": [
             "EPOLLIN",
             "EPOLLPRI",
             "EPOLLOUT",
             "EPOLL_CLOEXEC",
             "EPOLL_CTL_ADD",
             "EPOLL_CTL_MOD",
             "EPOLL_CTL_DEL",
             "KQ_FILTER_READ",
             "KQ_EV_ADD"
         ],
         "mmap": ["F_FULLFSYNC", "MREMAP_MAYMOVE"],
         "_posixsubprocess": ["SYS_getdents64"]
     },
     # Modules whose portable Jac code may read any constant the source
     # publishes: every name is declared on every platform (0 where the
     # headers lack it), and CONSTANTS still lists only the defined ones.
     ALL_PORTABLE: set[str] = {"posix"},
     # Values the C module uses internally rather than publishing with a macro.
     EXTRA: dict[str, list[str]] = {
         "resource": ["RLIM_INFINITY", "RLIM_NLIMITS"],
         "time": ["CLOCKS_PER_SEC", "TIMER_ABSTIME"],
         "select": ["FD_SETSIZE", "EPOLL_CTL_ADD", "EPOLL_CTL_MOD", "EPOLL_CTL_DEL"],
         "mmap": ["_SC_PAGESIZE", "MS_SYNC", "F_FULLFSYNC", "MREMAP_MAYMOVE"],
         "_posixsubprocess": [
             "O_RDONLY",
             "ENOENT",
             "ENOTDIR",
             "NGROUPS_MAX",
             "_SC_OPEN_MAX",
             "SIG_BLOCK",
             "SIG_SETMASK",
             "SIGKILL",
             "SIGSTOP",
             "SA_SIGINFO",
             "NSIG",
             "SYS_getdents64"
         ],
         "_multiprocessing": ["O_CREAT", "O_EXCL", "SEM_VALUE_MAX"],
         "posix": [
             "AT_FDCWD",
             "AT_SYMLINK_NOFOLLOW",
             "AT_SYMLINK_FOLLOW",
             "AT_REMOVEDIR",
             "AT_EACCESS",
             "UTIME_NOW",
             "UTIME_OMIT",
             "E2BIG",
             "EAGAIN",
             "EBADF",
             "ECHILD",
             "EINTR",
             "EINVAL",
             "ENODATA",
             "ENOATTR",
             "ENOENT",
             "ENOMEM",
             "ENOSYS",
             "ENOTDIR",
             "ENOTSUP",
             "ENOTTY",
             "EOPNOTSUPP",
             "EPERM",
             "ERANGE",
             "EXDEV",
             "NSIG",
             "DT_UNKNOWN",
             "DT_DIR",
             "DT_REG",
             "DT_LNK",
             "TIOCGWINSZ",
             "TIOCSCTTY",
             "NODEV",
             "MAXPATHLEN",
             "PATH_MAX",
             "L_ctermid",
             "_SC_CLK_TCK",
             "_SC_NPROCESSORS_ONLN",
             "_SC_NGROUPS_MAX",
             "_SC_OPEN_MAX",
             "O_CLOEXEC",
             "SEEK_SET",
             "SEEK_CUR",
             "SEEK_END",
             "POSIX_SPAWN_SETSIGMASK",
             "POSIX_SPAWN_SETSIGDEF",
             "POSIX_SPAWN_SETPGROUP",
             "POSIX_SPAWN_RESETIDS",
             "POSIX_SPAWN_SETSID",
             "POSIX_SPAWN_SETSID_NP",
             "POSIX_SPAWN_SETSCHEDPARAM",
             "POSIX_SPAWN_SETSCHEDULER",
             "XATTR_LIST_MAX",
             "XATTR_SIZE_MAX",
             "XATTR_NOFOLLOW",
             "SYS_getrandom",
             "SYS_pidfd_open",
             "CPU_SETSIZE",
             "COPYFILE_DATA",
             "COPYFILE_STAT",
             "COPYFILE_ACL",
             "COPYFILE_XATTR"
         ]
     },
     # Aliases the C module defines itself when the headers have only one
     # spelling: {name: other}, emitted as `#define name other` when only
     # `other` is defined.
     ALIASES: dict[str, dict[str, str]] = {
         "termios": {"VSWTC": "VSWTCH", "VSWTCH": "VSWTC"}
     },
     # Macros the C source derives itself before testing them, reproduced
     # after the includes of a --pyconfig probe.
     PRELUDES: dict[str, list[str]] = {
         "posix": [
             "#if defined(HAVE_SYS_XATTR_H) && defined(HAVE_LINUX_LIMITS_H) && !defined(__FreeBSD_kernel__) && !defined(__GNU__)",
             "#define USE_XATTRS",
             "#endif",
             "#if defined(HAVE_SYS_IOCTL_H) && defined(TIOCGWINSZ)",
             "#define TERMSIZE_USE_IOCTL",
             "#endif",
             "#ifdef HAVE_POSIX_SPAWN",
             "enum posix_spawn_file_actions_identifier {",
             "    POSIX_SPAWN_OPEN,",
             "    POSIX_SPAWN_CLOSE,",
             "    POSIX_SPAWN_DUP2",
             "#ifdef HAVE_POSIX_SPAWN_FILE_ACTIONS_ADDCLOSEFROM_NP",
             "    ,POSIX_SPAWN_CLOSEFROM",
             "#endif",
             "};",
             "#endif"
         ]
     },
     # `{"NAME", MACRO}` arrays published as dicts: (C array, Jac list) pairs.
     TABLES: dict[str, list[tuple[str, str]]] = {
         "posix": [
             ("posix_constants_pathconf", "PATHCONF_TABLE"),
             ("posix_constants_confstr", "CONFSTR_TABLE"),
             ("posix_constants_sysconf", "SYSCONF_TABLE")
         ]
     },
     # The Argument Clinic header whose PyMethodDef macros a module's method
     # table lists: with --pyconfig, the table's METHODS names the functions
     # the target compiles (each macro's guard holds), for the binding to keep.
     METHOD_SOURCES: dict[str, str] = {"posix": "Modules/clinic/posixmodule.c.h"},
     FEATURE_CHECK: Path = RUNTIME.parents[2] / "bootstrap" / "python" / "features_check.c",
     # The predefined macros that select a table's target in features_check.c.
     TARGET_MACROS: dict[str, str] = {
         "darwin": "defined(__APPLE__)",
         "linux": "defined(__linux__)",
         "x86_64": "defined(__x86_64__)",
         "aarch64": "defined(__aarch64__)"
     },
     # Names whose value is not fixed per OS, which the binding reads from the
     # target instead: CHAR_MAX follows the ABI's char signedness (unsigned on
     # Linux aarch64, signed on x86_64 and Apple arm64).
     EXCLUDED: dict[str, list[str]] = {"_locale": ["CHAR_MAX"]};

# A comment reduced to its line breaks, so line numbers survive.
def blank_comment(hit: re.Match[str]) -> str {
    return "\n" * hit.group(0).count("\n");
}

def without_comments(source: str) -> str {
    return re.sub(r"/\*.*?\*/", blank_comment, source, flags=re.S);
}

# The condition of one #if/#elif/#else frame: the earlier branches failed and
# this one holds.
def frame_condition(frame: tuple[list[str], str]) -> str {
    (prior, current) = frame;
    return " && ".join([f"!{earlier}" for earlier in prior] + [current]);
}

# The preprocessor condition each line of `source` is compiled under, as one C
# expression ("1" outside any conditional).
def line_conditions(source: str) -> list[str] {
    conditions: list[str] = [];
    stack: list[tuple[list[str], str]] = [];
    pending = "";
    for line in without_comments(source).splitlines() {
        conditions.append(
            " && ".join([f"({frame_condition(frame)})" for frame in stack]) or "1"
        );
        if line.rstrip().endswith("\\") {
            pending += line.rstrip()[:-1] + " ";
            continue;
        }
        text = pending + line;
        pending = "";
        directive = re.match(
            r"\s*#\s*(ifdef|ifndef|if|elif|else|endif)\b(.*)", text
        );
        if not directive {
            continue;
        }
        (kind, rest) = (directive.group(1), re.sub(r"//.*", "", directive.group(2)).strip());
        if kind == "ifdef" {
            stack.append(([], f"defined({rest})"));
        } elif kind == "ifndef" {
            stack.append(([], f"!defined({rest})"));
        } elif kind == "if" {
            stack.append(([], f"({rest})"));
        } elif kind in ("elif", "else") and stack {
            (prior, current) = stack[-1];
            stack[-1] = (prior + [current], f"({rest})" if kind == "elif" else "1");
        } elif kind == "endif" and stack {
            stack.pop();
        }
    }
    return conditions;
}

def names_in(source: str) -> list[str] {
    found: list[str] = [];
    # A commented-out entry (_locale's YESSTR and NOSTR) is not published.
    source = without_comments(source);
    conditions = line_conditions(source);
    for (number, line) in enumerate(source.splitlines()) {
        for pattern in PATTERNS {
            for hit in re.finditer(pattern, line) {
                name = hit.group(1);
                if name not in found and name not in MACRO_PARAMETERS {
                    found.append(name);
                    CONDITIONS[name] = conditions[number];
                }
            }
        }
        for pattern in ALIAS_PATTERNS {
            for hit in re.finditer(pattern, line) {
                name = hit.group(1);
                if name not in found and hit.group(2) not in MACRO_PARAMETERS {
                    found.append(name);
                    CONDITIONS[name] = conditions[number];
                    if hit.group(2) != name {
                        MACROS[name] = hit.group(2);
                    }
                }
            }
        }
    }
    return found;
}

# The `{"NAME", MACRO}` entries of each of the module's TABLES, with the
# condition guarding each entry: {Jac list: [(published, macro, condition)]}.
def tables_in(module: str, source: str) -> dict[str, list[tuple[str, str, str]]] {
    source = without_comments(source);
    conditions = line_conditions(source);
    lines = source.splitlines();
    tables: dict[str, list[tuple[str, str, str]]] = {};
    for (array, name) in TABLES.get(module, []) {
        entries: list[tuple[str, str, str]] = [];
        inside = False;
        for (number, line) in enumerate(lines) {
            if not inside {
                inside = re.search(r"\b" + array + r"\s*\[\s*\]\s*=", line) is not None;
                continue;
            }
            if line.strip().startswith("};") {
                break;
            }
            for hit in re.finditer(r"\{\s*\"(\w+)\"\s*,\s*(\w+)\s*\}", line) {
                entries.append((hit.group(1), hit.group(2), conditions[number]));
            }
        }
        if not entries {
            sys.exit(f"{module}: no constant entries in {array}");
        }
        tables[name] = entries;
    }
    return tables;
}

# The functions a clinic header defines PyMethodDef macros for, with the
# condition guarding each definition: [(Python name, condition)].
def methods_in(source: str) -> list[tuple[str, str]] {
    source = without_comments(source);
    conditions = line_conditions(source);
    lines = source.splitlines();
    methods: list[tuple[str, str]] = [];
    for (number, line) in enumerate(lines) {
        if not re.match(r"\s*#\s*define\s+\w+_METHODDEF\s*\\\s*$", line) {
            continue;
        }
        hit = re.search(r"\{\s*\"(\w+)\"", lines[number + 1]);
        if hit {
            methods.append((hit.group(1), conditions[number]));
        }
    }
    return methods;
}

# pyconfig.h's HAVE_* macros: {name: value}, 0 for the ones it leaves undefined.
def pyconfig_features(path: Path) -> dict[str, int] {
    features: dict[str, int] = {};
    for line in path.read_text().splitlines() {
        defined = re.match(r"#define (HAVE_\w+)\s+(\d+)\s*$", line);
        if defined {
            features[defined.group(1)] = int(defined.group(2));
            continue;
        }
        undefined = re.match(r"/\* #undef (HAVE_\w+) \*/", line);
        if undefined {
            features[undefined.group(1)] = 0;
        }
    }
    return features;
}

def includes_for(module: str) -> list[str] {
    lines: list[str] = [];
    for header in SOURCES[module][1] {
        lines += [f"#if __has_include(<{header}>)", f"#include <{header}>", "#endif"];
    }
    for (name, other) in ALIASES.get(module, {}).items() {
        lines += [
            f"#if defined({other}) && !defined({name})",
            f"#define {name} {other}",
            "#endif"
        ];
    }
    return lines;
}

# Values as the target compiler folds them, read back from its assembly.
# Constants can be enumerators (glibc's RLIMIT_*) as well as macros, so the
# preprocessor alone is not enough; compiling to assembly needs no target
# execution, which keeps cross-compilers usable.
# Each probe is (key, macro, condition): the value of `macro` where
# `condition` holds. `prelude` is the target's pyconfig.h include, which goes
# ahead of the defines and includes, then the module's own macros, which
# follow them.
def extract(
    probes: list[tuple[str, str, str]],
    includes: list[str],
    compiler: list[str],
    prelude: list[str]
) -> dict[str, int] {
    lines = prelude[:1] + [
        "#ifndef _GNU_SOURCE",
        "#define _GNU_SOURCE 1",
        "#endif",
        "#ifndef _DARWIN_C_SOURCE",
        "#define _DARWIN_C_SOURCE 1",
        "#endif"
    ] + includes + prelude[1:];
    for (key, macro, condition) in probes {
        lines += [
            f"#if {condition}",
            f"const long long __jac_const_{key} = (long long)({macro});",
            "#endif"
        ];
    }
    # The assembly goes to a file: `zig cc` treats `-o -` as a file named "-".
    with tempfile.TemporaryDirectory() as scratch {
        probe = Path(scratch) / "constants.c";
        assembly = Path(scratch) / "constants.s";
        probe.write_text("\n".join(lines) + "\n");
        result = subprocess.run(
            compiler + ["-S", "-O0", "-o", str(assembly), str(probe)],
            capture_output=True,
            text=True
        );
        if result.returncode != 0 {
            sys.exit(result.stderr);
        }
        listing = assembly.read_text();
    }
    values: dict[str, int] = {};
    current: str | None = None;
    for line in listing.splitlines() {
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
    module: str,
    target_os: str,
    arch: str,
    names: list[str],
    values: dict[str, int],
    tables: dict[str, list[tuple[str, int]]],
    features: list[tuple[str, int]]
) -> str {
    target = f"{target_os} {arch}" if arch else target_os;
    defined = [
        name
        for name in names
        if name in values
    ];
    portable = names if module in ALL_PORTABLE else PORTABLE.get(module, []);
    missing = [
        name
        for name in dict.fromkeys(portable + EXTRA.get(module, []))
        if name not in values
    ];
    lines = [
        f'"""{module} constants from the {target} C headers.',
        "",
        "Generated by scripts/jacpython/gen_constants.jac; do not edit."
    ];
    if missing {
        lines += [
            "",
            "Not defined by these headers, and so 0 for the module's portable code",
            "and left out of CONSTANTS:"
        ];
        lines += textwrap.wrap(", ".join(missing) + ".", 76);
    }
    lines += ['"""', "", f'glob PLATFORM: str = "{target_os}";'];
    lines += [f"glob {name}: i64 = {values[name]};" for name in defined];
    lines += [f"glob {name}: i64 = 0;" for name in missing];
    lines += ["", "glob CONSTANTS: list[tuple[str, i64]] = ["];
    # An ALL_PORTABLE module's table publishes only what its source does;
    # other modules' bindings leave their EXTRA names out themselves.
    internal = set(EXTRA.get(module, [])) - PUBLISHED if module in ALL_PORTABLE else set();
    lines += [
        f'    ("{name}", {name}),'
        for name in defined
        if name not in internal
    ];
    lines.append("];");
    for (table, entries) in tables.items() {
        lines += ["", f"glob {table}: list[tuple[str, i64]] = ["];
        lines += [f'    ("{name}", {value}),' for (name, value) in entries];
        lines.append("];");
    }
    if features {
        lines += ["", "# The configure feature macros the C source tests."];
        lines += [f"glob {name}: i64 = {value};" for (name, value) in features];
        lines += ["", "glob FEATURES: list[tuple[str, i64]] = ["];
        lines += [f'    ("{name}", {name}),' for (name, value) in features];
        lines.append("];");
    }
    return "\n".join(lines) + "\n";
}

# The list tables (other than CONSTANTS) any generated table of `stem` has.
def known_tables(stem: str) -> list[str] {
    known: list[str] = [];
    for generated in sorted(OUTPUT.glob(f"{stem}_constants.*.jac")) {
        for name in re.findall(
            r"^\s*(?:glob\s+)?(\w+): list\[tuple\[str, i64\]\] =",
            generated.read_text(),
            re.M
        ) {
            if name != "CONSTANTS" and name not in known {
                known.append(name);
            }
        }
    }
    return known;
}

# features_check.c: every generated table's FEATURES, asserted against the
# configured pyconfig.h of the build that compiles it.
def render_feature_check -> str {
    lines = [
        "/* The configure feature values native Jac modules were generated with.",
        " *",
        " * Generated by scripts/jacpython/gen_constants.jac from the FEATURES of",
        " * each jaclang/runtime/python/modules/<name>_constants.<os>[.<arch>].jac;",
        " * do not edit. build.sh compiles it against every JacPython build's",
        " * pyconfig.h, so a table that disagrees with its build fails the build.",
        " */",
        "#include \"pyconfig.h\"",
        ""
    ];
    for generated in sorted(OUTPUT.glob("*_constants.*.jac")) {
        text = generated.read_text();
        marker = re.search(r"^\s*(?:glob\s+)?FEATURES: list", text, re.M);
        if marker is None {
            continue;
        }
        parts = generated.name[:-len(".jac")].split(".")[1:];
        values = {
            name: int(value)
            for (name, value) in re.findall(r"(HAVE_\w+): i64 = (-?\d+)", text)
        };
        section = text[marker.start():];
        selector = " && ".join([TARGET_MACROS[part] for part in parts]);
        lines += [f"#if {selector}"];
        for name in re.findall(r"\(\"(HAVE_\w+)\"", section) {
            lines += [
                f"#if {name} != {values[name]}",
                f"#error \"{name} is not {values[name]} as {generated.name} records\"",
                "#endif"
            ];
        }
        lines += ["#endif", ""];
    }
    return "\n".join(lines);
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

def render_stub(module: str, names: list[str], tables: list[str]) -> str {
    lines = [
        f'"""{module} constants for a platform gen_constants.jac has not run for."""',
        "",
        'glob PLATFORM: str = "";'
    ];
    lines += [f"glob {name}: i64 = 0;" for name in names];
    lines += ["", "glob CONSTANTS: list[tuple[str, i64]] = [];"];
    lines += [f"glob {table}: list[tuple[str, i64]] = [];" for table in tables];
    return "\n".join(lines) + "\n";
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate platform constants for a JacPython module"
    );
    parser.add_argument("module");
    parser.add_argument("--cc", help="target C compiler command");
    parser.add_argument("--os", help="target OS name in the output file");
    parser.add_argument(
        "--arch", help="target architecture, for a table only it defines this way"
    );
    parser.add_argument(
        "--pyconfig",
        help="the target build's configured pyconfig.h: probe under the source's conditions and record its features"
    );
    parser.set_defaults(cc="cc", os=sys.platform, arch="", pyconfig="");
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
    names = [
        n
        for n in names_in(texts[source_file])
        if n not in EXCLUDED.get(args.module, [])
    ];
    PUBLISHED.update(names);
    names += [
        n
        for n in EXTRA.get(args.module, [])
        if n not in names
    ];
    prelude: list[str] = [];
    features: list[tuple[str, int]] = [];
    probes = [
        (name, MACROS.get(name, name), f"defined({MACROS.get(name, name)})")
        for name in names
    ];
    source_tables = tables_in(args.module, texts[source_file]);
    if args.pyconfig {
        configured = Path(args.pyconfig).resolve();
        prelude = [f'#include "{configured}"'] + PRELUDES.get(args.module, []);
        # The source's own guards decide, so an enumerator the source
        # publishes unguarded (P_PID in macOS's idtype_t) is kept.
        probes = [
            (
                name,
                MACROS.get(name, name),
                CONDITIONS[name]
                    if name in CONDITIONS
                    else f"defined({MACROS.get(name, name)})"
            )
            for name in names
        ];
        known = pyconfig_features(configured);
        features = [
            (name, known[name])
            for name in sorted(set(re.findall(r"\bHAVE_\w+", texts[source_file])))
            if name in known
        ];
    }
    for (table, entries) in source_tables.items() {
        for (index, item) in enumerate(entries) {
            probes.append(
                (
                    f"{table}__{index}",
                    item[1],
                    item[2] if args.pyconfig else f"defined({item[1]})"
                )
            );
        }
    }
    method_table: list[tuple[str, str]] = [];
    if args.pyconfig and args.module in METHOD_SOURCES {
        header = METHOD_SOURCES[args.module];
        method_table = methods_in(archive_texts((header, ))[header]);
        for (index, method) in enumerate(method_table) {
            probes.append((f"METHODS__{index}", "1", method[1]));
        }
    }
    values = extract(probes, includes_for(args.module), shlex.split(args.cc), prelude);
    tables: dict[str, list[tuple[str, int]]] = {};
    if method_table {
        tables["METHODS"] = [
            (method_table[index][0], 1)
            for index in range(len(method_table))
            if f"METHODS__{index}" in values
        ];
    }
    for (table, entries) in source_tables.items() {
        tables[table] = [];
        for (index, item) in enumerate(entries) {
            if f"{table}__{index}" in values {
                tables[table].append((item[0], values[f"{table}__{index}"]));
            }
        }
    }
    stem = args.module.lstrip("_");
    command = f"scripts/jacpython/gen_constants.jac {args.module}";
    suffix = f"{args.os}.{args.arch}" if args.arch else args.os;
    target = OUTPUT / f"{stem}_constants.{suffix}.jac";
    current = write_or_check(
        target,
        format_jac(
            render(args.module, args.os, args.arch, names, values, tables, features),
            target
        ),
        args.check,
        command
    );
    if not args.check {
        print(
            f"{len([name for name in names if name in values])} of {len(names)} names defined"
        );
    }
    stub = OUTPUT / f"{stem}_constants.jac";
    current = write_or_check(
        stub,
        format_jac(
            render_stub(args.module, known_names(stem), known_tables(stem)), stub
        ),
        args.check,
        command
    )
        and current;
    if features {
        current = write_or_check(
            FEATURE_CHECK, render_feature_check(), args.check, command
        )
            and current;
    }
    if not current {
        sys.exit(1);
    }
}
