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
         r"\bADD_INT_CONST\(\s*\w+\s*,\s*\"(\w+)\"\s*,\s*([A-Za-z_]\w*)\s*\)",
         r"\bPyModule_AddIntConstant\(\s*\w+\s*,\s*\"(\w+)\"\s*,\s*([A-Za-z_]\w*)\s*\)"
     ],
     # The macro each aliased published name reads.
     MACROS: dict[str, str] = {},
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
         # socketmodule.c and socketmodule.h include these; Bluetooth's
         # headers are not part of any supported target's C library.
         "_socket": (
             "Modules/socketmodule.c",
             [
                 "sys/types.h",
                 "sys/socket.h",
                 "netinet/in.h",
                 "netinet/tcp.h",
                 "netdb.h",
                 "arpa/inet.h",
                 "fcntl.h",
                 "sys/un.h",
                 "net/if.h",
                 "net/ethernet.h",
                 "sys/ioctl.h",
                 "linux/netlink.h",
                 "linux/qrtr.h",
                 "linux/tipc.h",
                 "linux/can.h",
                 "linux/can/raw.h",
                 "linux/can/bcm.h",
                 "linux/can/j1939.h",
                 "linux/vm_sockets.h",
                 "linux/netfilter_ipv4.h",
                 "linux/if_alg.h",
                 "netpacket/packet.h",
                 "sys/sys_domain.h",
                 "sys/kern_control.h",
                 "poll.h"
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
         "_posixsubprocess": ["SYS_getdents64"],
         "_socket": [
             "AF_NETLINK",
             "AF_QIPCRTR",
             "AF_VSOCK",
             "AF_RDS",
             "AF_PACKET",
             "AF_TIPC",
             "AF_CAN",
             "CAN_RAW",
             "CAN_BCM",
             "CAN_ISOTP",
             "CAN_J1939",
             "AF_ALG",
             "SOL_ALG",
             "ALG_SET_OP",
             "ALG_SET_IV",
             "ALG_SET_AEAD_ASSOCLEN",
             "PF_SYSTEM",
             "AF_SYSTEM",
             "SYSPROTO_CONTROL",
             "SOCK_CLOEXEC",
             "SOCK_NONBLOCK",
             "SO_PROTOCOL",
             "TIPC_ADDR_NAMESEQ",
             "TIPC_ADDR_NAME",
             "TIPC_ADDR_ID",
             "TIPC_CLUSTER_SCOPE",
             "PACKET_HOST",
             "SIOCGIFINDEX",
             "SIOCGIFNAME",
             "CTLIOCGINFO",
             "AF_SYS_CONTROL"
         ]
     },
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
         "_socket": [
             "FIONBIO",
             "POLLIN",
             "POLLOUT",
             "POLLERR",
             "IF_NAMESIZE",
             "INET_ADDRSTRLEN",
             "INET6_ADDRSTRLEN",
             "SIOCGIFINDEX",
             "SIOCGIFNAME",
             "CTLIOCGINFO",
             "AF_SYS_CONTROL"
         ]
     },
     # Aliases the C module defines itself when the headers have only one
     # spelling: {name: other}, emitted as `#define name other` when only
     # `other` is defined.
     ALIASES: dict[str, dict[str, str]] = {
         "termios": {"VSWTC": "VSWTCH", "VSWTCH": "VSWTC"}
     },
     # Names whose value is not fixed per OS, which the binding reads from the
     # target instead: CHAR_MAX follows the ABI's char signedness (unsigned on
     # Linux aarch64, signed on x86_64 and Apple arm64).
     EXCLUDED: dict[str, list[str]] = {"_locale": ["CHAR_MAX"]},
     # Macros the C module defines before its includes to expose constants.
     DEFINES: dict[str, list[str]] = {"_socket": ["__APPLE_USE_RFC_3542 1"]},
     # Conditions no supported target meets: the names published only
     # inside `#ifdef` / `#if defined()` blocks on them are left out, even
     # where a header happens to define the macro (Linux's AF_BLUETOOTH).
     UNSUPPORTED: dict[str, list[str]] = {
         "_socket": [
             "MS_WINDOWS",
             "MS_WINDOWS_DESKTOP",
             "USE_BLUETOOTH",
             "SIO_RCVALL",
             "HAVE_AF_HYPERV"
         ]
     },
     # Names the C module publishes under a condition other than their own
     # macro, grouped by that condition: enumerators a header's presence
     # guards (configure's HAVE_LINUX_CAN_BCM_H and the like).
     GUARDS: dict[str, dict[str, list[str]]] = {
         "_socket": {
             # socketmodule.h #undefs these families without their headers.
             "defined(AF_NETLINK) && __has_include(<linux/netlink.h>)": ["AF_NETLINK"],
             "defined(AF_QIPCRTR) && __has_include(<linux/qrtr.h>)": ["AF_QIPCRTR"],
             "defined(AF_CAN) && __has_include(<linux/can.h>)": ["AF_CAN"],
             "defined(PF_CAN) && __has_include(<linux/can.h>)": ["PF_CAN"],
             "defined(AF_VSOCK) && __has_include(<linux/vm_sockets.h>)": ["AF_VSOCK"],
             "__has_include(<linux/tipc.h>)": ["TIPC_CLUSTER_SCOPE", "TIPC_NODE_SCOPE"],
             "__has_include(<linux/can/raw.h>)": [
                 "CAN_RAW_FILTER",
                 "CAN_RAW_ERR_FILTER",
                 "CAN_RAW_LOOPBACK",
                 "CAN_RAW_RECV_OWN_MSGS",
                 "CAN_RAW_FD_FRAMES",
                 "CAN_RAW_JOIN_FILTERS"
             ],
             "__has_include(<linux/can/bcm.h>)": [
                 "CAN_BCM_TX_SETUP",
                 "CAN_BCM_TX_DELETE",
                 "CAN_BCM_TX_READ",
                 "CAN_BCM_TX_SEND",
                 "CAN_BCM_RX_SETUP",
                 "CAN_BCM_RX_DELETE",
                 "CAN_BCM_RX_READ",
                 "CAN_BCM_TX_STATUS",
                 "CAN_BCM_TX_EXPIRED",
                 "CAN_BCM_RX_STATUS",
                 "CAN_BCM_RX_TIMEOUT",
                 "CAN_BCM_RX_CHANGED"
             ],
             "__has_include(<linux/can/j1939.h>)": [
                 "SO_J1939_FILTER",
                 "SO_J1939_PROMISC",
                 "SO_J1939_SEND_PRIO",
                 "SO_J1939_ERRQUEUE",
                 "SCM_J1939_DEST_ADDR",
                 "SCM_J1939_DEST_NAME",
                 "SCM_J1939_PRIO",
                 "SCM_J1939_ERRQUEUE",
                 "J1939_NLA_PAD",
                 "J1939_NLA_BYTES_ACKED",
                 "J1939_EE_INFO_NONE",
                 "J1939_EE_INFO_TX_ABORT"
             ],
             "defined(IPPROTO_UDPLITE)": ["UDPLITE_SEND_CSCOV", "UDPLITE_RECV_CSCOV"]
         }
     },
     # Values the C module defines itself when the headers do not.
     DEFAULTS: dict[str, dict[str, str]] = {
         "_socket": {"UDPLITE_SEND_CSCOV": "10", "UDPLITE_RECV_CSCOV": "11"}
     };

# The #if condition each guarded name of `module` is read under.
def guards_for(module: str) -> dict[str, str] {
    guards: dict[str, str] = {};
    for (condition, guarded) in GUARDS.get(module, {}).items() {
        for name in guarded {
            guards[name] = condition;
        }
    }
    return guards;
}

# Whether the open `#if` blocks of `frames` (directive, condition, in #else)
# exclude their contents: a block on an unsupported macro, outside its
# #else, or the #else of an `#ifndef` on one.
def excluded_by(frames: list[tuple[str, str, bool]], unsupported: list[str]) -> bool {
    for (directive, condition, in_else) in frames {
        named = any(
            re.search(rf"\b{macro}\b", condition) is not None for macro in unsupported
        );
        if named and (in_else == (directive == "ifndef")) {
            return True;
        }
    }
    return False;
}

def names_in(source: str, unsupported: list[str]) -> list[str] {
    found: list[str] = [];
    # A commented-out entry (_locale's YESSTR and NOSTR) is not published.
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S);
    # A call continued after a comma is read as one line.
    source = re.sub(r",[ \t]*\n\s*(?!#)", ", ", source);
    frames: list[tuple[str, str, bool]] = [];
    for line in source.splitlines() {
        directive = re.match(r"\s*#\s*(ifdef|ifndef|if|elif|else|endif)\b(.*)", line);
        if directive {
            (kind, rest) = (directive.group(1), directive.group(2));
            if kind in ("ifdef", "ifndef", "if") {
                frames.append((kind, rest, False));
            } elif kind == "endif" and frames {
                frames.pop();
            } elif frames {
                # An #elif starts a new condition; an #else flips the last.
                top = frames.pop();
                frames.append(
                    ("if", rest, False) if kind == "elif" else (top[0], top[1], True)
                );
            }
            continue;
        }
        if unsupported and excluded_by(frames, unsupported) {
            continue;
        }
        for pattern in PATTERNS {
            for hit in re.finditer(pattern, line) {
                name = hit.group(1);
                if name not in found and name not in MACRO_PARAMETERS {
                    found.append(name);
                }
            }
        }
        for pattern in ALIAS_PATTERNS {
            for hit in re.finditer(pattern, line) {
                name = hit.group(1);
                if name not in found and hit.group(2) not in MACRO_PARAMETERS {
                    found.append(name);
                    if hit.group(2) != name {
                        MACROS[name] = hit.group(2);
                    }
                }
            }
        }
    }
    return found;
}

def includes_for(module: str) -> list[str] {
    lines = [f"#define {define}" for define in DEFINES.get(module, [])];
    for header in SOURCES[module][1] {
        lines += [f"#if __has_include(<{header}>)", f"#include <{header}>", "#endif"];
    }
    for (name, value) in DEFAULTS.get(module, {}).items() {
        lines += [f"#ifndef {name}", f"#define {name} {value}", "#endif"];
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
def extract(
    names: list[str],
    includes: list[str],
    compiler: list[str],
    guards: dict[str, str] = {}
) -> dict[str, int] {
    lines = ["#define _GNU_SOURCE 1", "#define _DARWIN_C_SOURCE 1"] + includes;
    for name in names {
        macro = MACROS.get(name, name);
        condition = guards.get(name, f"defined({macro})");
        lines += [
            f"#if {condition}",
            f"const long long __jac_const_{name} = (long long)({macro});",
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
    module: str, target_os: str, arch: str, names: list[str], values: dict[str, int]
) -> str {
    target = f"{target_os} {arch}" if arch else target_os;
    defined = [
        name
        for name in names
        if name in values
    ];
    missing = [
        name
        for name in dict.fromkeys(PORTABLE.get(module, []) + EXTRA.get(module, []))
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
    parser.add_argument(
        "--arch", help="target architecture, for a table only it defines this way"
    );
    parser.set_defaults(cc="cc", os=sys.platform, arch="");
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
        for n in names_in(texts[source_file], UNSUPPORTED.get(args.module, []))
        if n not in EXCLUDED.get(args.module, [])
    ];
    names += [
        n
        for n in EXTRA.get(args.module, [])
        if n not in names
    ];
    values = extract(
        names, includes_for(args.module), shlex.split(args.cc), guards_for(args.module)
    );
    stem = args.module.lstrip("_");
    command = f"scripts/jacpython/gen_constants.jac {args.module}";
    suffix = f"{args.os}.{args.arch}" if args.arch else args.os;
    target = OUTPUT / f"{stem}_constants.{suffix}.jac";
    current = write_or_check(
        target,
        format_jac(render(args.module, args.os, args.arch, names, values), target),
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
