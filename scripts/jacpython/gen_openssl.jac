"""Generate the OpenSSL constants and error tables of the native _ssl and _hashlib.

The native _ssl and _hashlib read OpenSSL's macros (SSL_OP_ALL, NID_sha256,
SN_sha256, OPENSSL_VERSION_NUMBER, ...) and _ssl reads OpenSSL's error library
and reason mnemonics. Both come from generated files:

    jac run scripts/jacpython/gen_openssl.jac            # rewrite both files
    jac run scripts/jacpython/gen_openssl.jac --check    # fail on drift

The script configures the pinned OpenSSL of sources.json (the archive a
JacPython build downloads) to generate its public headers, then:

- jaclang/runtime/python/modules/openssl_constants.jac: every object-like
  OpenSSL macro the ports name (scripts/jacpython/openssl_facts.jac), as an i64 (an integer constant
  expression, folded by the compiler and read back from its assembly), a str
  (a string literal) or a bool (a feature macro such as OPENSSL_NO_SSL3, True
  when defined). A name the ports test with #ifdef / defined() that the
  headers leave undefined is declared 0 or False and listed in UNDEFINED.
- jaclang/runtime/python/modules/ssl_errors.jac: LIBRARY_CODES and
  ERROR_CODES, every error library of include/openssl/err.h.in and every
  reason of crypto/err/openssl.txt and openssl.ec, sorted by reason macro and
  code; an entry carries the values these headers define, or the source
  file's own numbers for a reason the headers leave undefined.
"""
import argparse;
import ast;
import json;
import hashlib;
import os;
import platform;
import re;
import shlex;
import subprocess;
import sys;
import tarfile;
import tempfile;
import textwrap;
import from pathlib { Path }
import from common { BOOTSTRAP, JAC, RUNTIME, format_jac, write_or_check }
import from openssl_facts { SOURCE_LINES }

glob CONSTANTS_OUTPUT: Path = RUNTIME / "modules/openssl_constants.jac",
     ERRORS_OUTPUT: Path = RUNTIME / "modules/ssl_errors.jac",
     COMMAND: str = "scripts/jacpython/gen_openssl.jac",
     # What the ports' C counterparts define before including OpenSSL.
     DEFINES: list[str] = ["OPENSSL_API_COMPAT 0x10101000L", "OPENSSL_NO_DEPRECATED 1"],
     # The OpenSSL headers the two modules include, in their order.
     HEADERS: list[str] = [
         "openssl/rsa.h",
         "openssl/crypto.h",
         "openssl/x509.h",
         "openssl/x509v3.h",
         "openssl/pem.h",
         "openssl/ssl.h",
         "openssl/err.h",
         "openssl/rand.h",
         "openssl/bio.h",
         "openssl/dh.h",
         "openssl/evp.h",
         "openssl/hmac.h",
         "openssl/objects.h"
     ],
     # Prefixes of the OpenSSL names read from the sources; other identifiers
     # (the C API, the modules' own macros) are not OpenSSL's.
     PREFIXES: str = r"(?:SSL|SSL2|SSL3|TLS1|TLS1_1|TLS1_2|TLS1_3|DTLS1|TLSEXT|X509|X509V3|NID|SN|LN|EVP|BIO|ERR|GEN|ASN1|V_ASN1|PEM|OPENSSL|XN|CRYPTO|MBSTRING|RSA|OBJ|LIBRESSL|EXFLAG|OSSL)_\w+",
     # Names inside static inline functions the ports re-express
     # (ERR_GET_LIB and ERR_GET_REASON), which no macro expansion reaches.
     EXTRA: list[str] = [
         "ERR_SYSTEM_FLAG",
         "ERR_SYSTEM_MASK",
         "ERR_LIB_OFFSET",
         "ERR_LIB_MASK",
         "ERR_REASON_MASK"
     ],
     # Struct field offsets the ports read in place, where the C code
     # dereferences an OpenSSL struct (GENERAL_NAME's type and union, an
     # ACCESS_DESCRIPTION, a DIST_POINT): name -> C expression.
     EXPRESSIONS: dict[str, str] = {
         "GENERAL_NAME_TYPE_OFFSET": "offsetof(GENERAL_NAME, type)",
         "GENERAL_NAME_D_OFFSET": "offsetof(GENERAL_NAME, d)",
         "ACCESS_DESCRIPTION_METHOD_OFFSET": "offsetof(ACCESS_DESCRIPTION, method)",
         "ACCESS_DESCRIPTION_LOCATION_OFFSET": "offsetof(ACCESS_DESCRIPTION, location)",
         "DIST_POINT_DISTPOINT_OFFSET": "offsetof(DIST_POINT, distpoint)",
         "DIST_POINT_NAME_NAME_OFFSET": "offsetof(DIST_POINT_NAME, name)"
     },
     # build.sh's Configure target for each JacPython platform.
     TARGETS: dict[str, str] = {
         "darwin-arm64": "darwin64-arm64-cc",
         "darwin-x86_64": "darwin64-x86_64-cc",
         "linux-x86_64": "linux-x86_64",
         "linux-aarch64": "linux-aarch64"
     };

# ------------------------------------------------------------ OpenSSL headers
# The pinned OpenSSL archive, from the source cache a JacPython build fills.
def openssl_archive -> Path {
    pinned = json.loads((BOOTSTRAP / "sources.json").read_text())["openssl"];
    path = JAC / ".python-build/sources" / f"{pinned['sha256']}.tar.gz";
    if not path.is_file() {
        sys.exit(
            f"Pinned OpenSSL archive not found: {path}; run a JacPython build once"
        );
    }
    if hashlib.sha256(path.read_bytes()).hexdigest() != pinned["sha256"] {
        sys.exit(f"{path} does not match the pinned SHA256");
    }
    return path;
}

def openssl_version -> str {
    pinned = json.loads((BOOTSTRAP / "sources.json").read_text())["openssl"];
    hit = re.search(r"openssl-([\d.]+)\.tar", pinned["url"]);
    if hit is None {
        sys.exit("sources.json's OpenSSL URL names no version");
    }
    return hit.group(1);
}

def configure_target -> str {
    machine = platform.machine().lower();
    arch = "arm64" if machine in ("arm64", "aarch64") else machine;
    if sys.platform.startswith("linux") and arch == "arm64" {
        arch = "aarch64";
    }
    key = f"{'darwin' if sys.platform == 'darwin' else 'linux'}-{arch}";
    if key not in TARGETS {
        sys.exit(f"No OpenSSL Configure target recorded for {key}");
    }
    return TARGETS[key];
}

# Configure the pinned OpenSSL in `scratch` as vendored.sh does and generate its
# public headers; returns the include directory.
def openssl_include(scratch: Path) -> Path {
    with tarfile.open(openssl_archive()) as bundle {
        bundle.extractall(scratch, filter="data");
    }
    tree = next(
        p
        for p in scratch.iterdir()
        if p.is_dir()
    );
    result = subprocess.run(
        [
            "perl",
            "Configure",
            configure_target(),
            "no-shared",
            "no-tests",
            "no-docs",
            "no-apps",
            "no-asm"
        ],
        cwd=tree,
        capture_output=True,
        text=True
    );
    if result.returncode != 0 {
        sys.exit(f"OpenSSL Configure failed:\n{result.stdout}{result.stderr}");
    }
    generated = [
        str(template.relative_to(tree)).removesuffix(".in")
        for template in sorted((tree / "include/openssl").glob("*.h.in"))
    ];
    result = subprocess.run(
        ["make"] + generated, cwd=tree, capture_output=True, text=True
    );
    if result.returncode != 0 {
        sys.exit(
            f"Generating the OpenSSL headers failed:\n{result.stdout}{result.stderr}"
        );
    }
    return tree / "include";
}

def prologue -> list[str] {
    return [f"#define {define}" for define in DEFINES]
        + ["#include <stddef.h>"]
        + [f"#include <{header}>" for header in HEADERS];
}

def run(compiler: list[str], arguments: list[str]) -> str {
    result = subprocess.run(compiler + arguments, capture_output=True, text=True);
    if result.returncode != 0 {
        sys.exit(result.stderr);
    }
    return result.stdout;
}

# -------------------------------------------------------------------- macros
# Object-like macros the headers define: name -> replacement text.
def header_macros(
    headers_dir: Path, compiler: list[str], scratch: Path
) -> tuple[dict[str, str], dict[str, str]] {
    probe = scratch / "macros.c";
    probe.write_text("\n".join(prologue()) + "\n");
    listing = run(compiler, ["-E", "-dM", f"-I{headers_dir}", str(probe)]);
    objects: dict[str, str] = {};
    functions: dict[str, str] = {};
    for line in listing.splitlines() {
        hit = re.match(r"#define (\w+)(\([^)]*\))?(?:\s+(.*))?$", line);
        if hit {
            target = functions if hit.group(2) else objects;
            target[hit.group(1)] = (hit.group(3) or "").strip();
        }
    }
    return (objects, functions);
}

# The OpenSSL names the ports use, and those they test in #if conditions.
# A function-like macro the ports call (SSL_set_tlsext_host_name) is ported
# as the call it expands to, so the names of its expansion, and of the
# function-like macros in it, are used too.
def source_names(functions: dict[str, str]) -> tuple[list[str], list[str]] {
    used: list[str] = [];
    tested: list[str] = [];
    expanded: set[str] = set();
    def expand(name: str) {
        if name in expanded or name not in functions {
            return;
        }
        expanded.add(name);
        for word in re.findall(r"\b[A-Za-z_]\w*\b", functions[name]) {
            if re.fullmatch(PREFIXES, word)
                and word not in functions
                and word not in used {
                used.append(word);
            }
            expand(word);
        }
    }
    for (conditional, names, words) in SOURCE_LINES {
        for name in names {
            if name not in used {
                used.append(name);
            }
            if conditional and name not in tested {
                tested.append(name);
            }
        }
        for word in words {
            expand(word);
        }
    }
    used += [
        name
        for name in EXTRA
        if name not in used
    ];
    return (used, tested);
}

# The string value of a macro whose expansion is string literals.
def string_value(expansion: str) -> str {
    parts = re.findall(r'"((?:[^"\\]|\\.)*)"', expansion);
    return "".join(ast.literal_eval(f'"{part}"') for part in parts);
}

# Values of integer macros as the compiler folds them, read back from its
# assembly (a probe needs no target execution). A name whose expansion is
# no integer constant expression is left out.
def integer_values(
    entries: list[tuple[str, str]],
    headers_dir: Path,
    compiler: list[str],
    scratch: Path
) -> dict[str, int] {
    remaining = list(entries);
    while True {
        lines = prologue();
        start = len(lines) + 1;
        lines += [
            f"const long long __jac_const_{name} = (long long)({expression});"
            for (name, expression) in remaining
        ];
        probe = scratch / "values.c";
        assembly = scratch / "values.s";
        probe.write_text("\n".join(lines) + "\n");
        result = subprocess.run(
            compiler
                + ["-S", "-O0", f"-I{headers_dir}", "-o", str(assembly), str(probe)],
            capture_output=True,
            text=True
        );
        if result.returncode == 0 {
            break;
        }
        failing = {
            int(line) - start
            for line in re.findall(
                rf"{re.escape(str(probe))}:(\d+):\d+: error", result.stderr
            )
        };
        kept = [
            item
            for (index, item) in enumerate(remaining)
            if index not in failing
        ];
        if len(kept) == len(remaining) {
            sys.exit(result.stderr);
        }
        remaining = kept;
    }
    values: dict[str, int] = {};
    current: str | None = None;
    for line in assembly.read_text().splitlines() {
        line = line.strip();
        label = re.match(r"^_?__jac_const_(\w+):", line);
        if label {
            current = label.group(1);
            continue;
        }
        if current is None {
            continue;
        }
        data = re.match(r"^\.(?:quad|xword|8byte|dword)\s+(-?\d\w*)(?:\s|$)", line);
        if data {
            value = int(data.group(1), 0);
            values[current] = value - (1 << 64) if value >= (1 << 63) else value;
            current = None;
        } elif re.match(r"^\.zero\s+8", line) {
            values[current] = 0;
            current = None;
        } elif re.match(r"^\.(?:quad|xword|8byte|dword)\s", line) {
            current = None;
        }
    }
    return values;
}

def render_constants(
    integers: dict[str, int],
    strings: dict[str, str],
    flags: dict[str, bool],
    undefined: list[str],
    order: list[str]
) -> str {
    version = openssl_version();
    lines = [
        f'"""OpenSSL {version} macros the native _ssl and _hashlib read.',
        "",
        f"Generated by {COMMAND} from the pinned OpenSSL headers, for the names",
        "scripts/jacpython/openssl_facts.jac records; do not edit. UNDEFINED",
        "lists the names the ports test that these headers do not define.",
        '"""',
        ""
    ];
    for name in order {
        if name in flags {
            lines.append(f"glob {name}: bool = {flags[name]};");
        } elif name in integers {
            lines.append(f"glob {name}: i64 = {integers[name]};");
        } elif name in strings {
            lines.append(f"glob {name}: str = {json.dumps(strings[name])};");
        } elif name in undefined {
            lines.append(f"glob {name}: i64 = 0;");
        }
    }
    lines.append("glob UNDEFINED: list[str] = [");
    lines.append(",\n".join(f'    "{name}"' for name in undefined));
    lines.append("];");
    return "\n".join(lines) + "\n";
}

# ------------------------------------------------------------- error tables
# The error libraries and reasons of the OpenSSL tree whose headers are in
# `headers_dir`: [(library, ERR_LIB_* code)] and [(mnemonic, library code,
# reason code)], each code as these headers define it.
def error_tables(
    headers_dir: Path, macros: dict[str, str], compiler: list[str], scratch: Path
) -> tuple[list[tuple[str, int]], list[tuple[str, int, int]]] {
    tree = headers_dir.parent;
    numbers: dict[str, int] = {};
    for line in (tree / "include/openssl/err.h.in").read_text().splitlines() {
        hit = re.search(r"#\s*define\W+(ERR_LIB_(\w+))\s+(\d+)", line);
        if hit and hit.group(1) not in ("ERR_LIB_OFFSET", "ERR_LIB_MASK") {
            numbers.setdefault(hit.group(2), int(hit.group(3)));
        }
    }
    reasons: list[tuple[str, str, str, int]] = [];
    for line in (tree / "crypto/err/openssl.txt").read_text().splitlines() {
        hit = re.match(r"^((\w+?)_R_(\w+)):(\d+):", line);
        if hit and "_F_" not in hit.group(1) {
            reasons.append(
                (hit.group(1), hit.group(2), hit.group(3), int(hit.group(4)))
            );
        }
    }
    for line in (tree / "crypto/err/openssl.ec").read_text().splitlines() {
        hit = re.match(r"^R\s+((\w+)_R_(\w+))\s+(\d+)", line);
        if hit {
            reasons.append(
                (hit.group(1), hit.group(2), hit.group(3), int(hit.group(4)))
            );
        }
    }
    # By reason macro, then code; equal keys keep their file order.
    reasons = [
        ordered[3]
        for ordered in sorted(
            (reason[0], reason[3], index, reason)
            for (index, reason) in enumerate(reasons)
        )
    ];
    probed = [f"ERR_LIB_{library}" for library in numbers]
        + [reason[0] for reason in reasons];
    values = integer_values(
        [
            (name, name)
            for name in probed
            if name in macros
        ],
        headers_dir,
        compiler,
        scratch
    );
    libraries = [
        (library, values[f"ERR_LIB_{library}"])
        for library in sorted(numbers)
        if f"ERR_LIB_{library}" in values
    ];
    errors = [
        (mnemonic, values[f"ERR_LIB_{library}"], values[macro])
            if macro in values
            else (mnemonic, numbers[library], code)
        for (macro, library, mnemonic, code) in reasons
    ];
    return (libraries, errors);
}

def render_errors(
    libraries: list[tuple[str, int]], errors: list[tuple[str, int, int]]
) -> str {
    version = openssl_version();
    lines = [
        f'"""The OpenSSL {version} error names of the native _ssl, from its',
        "include/openssl/err.h.in, crypto/err/openssl.txt and crypto/err/openssl.ec,",
        "with the codes its headers define.",
        "",
        "LIBRARY_CODES is (library name, ERR_LIB_* code);",
        "ERROR_CODES is (mnemonic, library, reason).",
        "",
        f"Generated by {COMMAND}; do not edit. See ../LICENSE.cpython.",
        '"""',
        "",
        "glob LIBRARY_CODES: list[tuple[str, i64]] = ["
    ];
    lines.append(",\n".join(f'    ("{name}", {code})' for (name, code) in libraries));
    lines += ["];", "", "glob ERROR_CODES: list[tuple[str, i64, i64]] = ["];
    lines.append(
        ",\n".join(
            f'    ("{name}", {library}, {reason})' for (name, library, reason) in errors
        )
    );
    lines.append("];");
    return "\n".join(lines) + "\n";
}

with entry:__main__ {
    parser = argparse.ArgumentParser(
        description="Generate the OpenSSL constants and error tables of _ssl and _hashlib"
    );
    parser.add_argument("--cc", help="C compiler command");
    parser.set_defaults(cc="cc");
    parser.add_argument("--check", action="store_true");
    args = parser.parse_args();
    compiler = shlex.split(args.cc);
    with tempfile.TemporaryDirectory() as directory {
        scratch = Path(directory);
        headers_dir = openssl_include(scratch / "openssl");
        (macros, functions) = header_macros(headers_dir, compiler, scratch);
        (used, tested) = source_names(functions);
        flags: dict[str, bool] = {};
        strings: dict[str, str] = {};
        numeric: list[str] = [];
        undefined: list[str] = [];
        # A name that is no macro may still be an integer constant (an
        # enumerator such as X509_LU_X509); it is probed with the macros, and
        # one that resolves to nothing is undefined.
        probed: list[str] = [];
        for name in used {
            if name not in macros {
                if name not in functions {
                    probed.append(name);
                }
                continue;
            }
            expansion = macros[name];
            # A macro of the expansion site (OPENSSL_LINE is __LINE__) has no
            # value of its own.
            if re.search(r"\b__(?:LINE|FILE)__\b", expansion) {
                continue;
            }
            if expansion == "" or name.startswith("OPENSSL_NO_") {
                flags[name] = True;
            } elif expansion.startswith('"') {
                strings[name] = string_value(expansion);
            } else {
                numeric.append(name);
            }
        }
        integers = integer_values(
            [(name, name) for name in numeric + probed] + list(EXPRESSIONS.items()),
            headers_dir,
            compiler,
            scratch
        );
        undefined += [
            name
            for name in used
            if name in tested and name not in macros and name not in integers
        ];
        # Feature macros the sources test but the headers leave undefined.
        for name in list(undefined) {
            if name.startswith("OPENSSL_NO_") {
                flags[name] = False;
            }
        }
        (libraries, errors) = error_tables(headers_dir, macros, compiler, scratch);
    }
    current = write_or_check(
        CONSTANTS_OUTPUT,
        format_jac(
            render_constants(
                integers, strings, flags, undefined, used + list(EXPRESSIONS)
            ),
            CONSTANTS_OUTPUT
        ),
        args.check,
        COMMAND
    );
    current = write_or_check(
        ERRORS_OUTPUT,
        format_jac(render_errors(libraries, errors), ERRORS_OUTPUT),
        args.check,
        COMMAND
    )
        and current;
    if not current {
        sys.exit(1);
    }
}
