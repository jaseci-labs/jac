"""Generate the OpenSSL constants and error tables of the native _ssl and _hashlib.

CPython's Modules/_ssl.c and Modules/_hashopenssl.c read OpenSSL's macros
(SSL_OP_ALL, NID_sha256, SN_sha256, OPENSSL_VERSION_NUMBER, ...) and _ssl.c
includes a generated error table, Modules/_ssl_data_<version>.h, chosen by
OPENSSL_VERSION_NUMBER. The Jac ports read both from generated files:

    jac run scripts/jacpython/gen_openssl.jac            # rewrite both files
    jac run scripts/jacpython/gen_openssl.jac --check    # fail on drift

The script configures the pinned OpenSSL of sources.json (the archive a
JacPython build downloads) to generate its public headers, then:

- jaclang/runtime/python/modules/openssl_constants.jac: every object-like
  OpenSSL macro the C sources name, as an i64 (an integer constant
  expression, folded by the compiler and read back from its assembly), a str
  (a string literal) or a bool (a feature macro such as OPENSSL_NO_SSL3, True
  when defined). A name the sources test with #ifdef / defined() that the
  headers leave undefined is declared 0 or False and listed in UNDEFINED.
- jaclang/runtime/python/modules/ssl_errors.jac: LIBRARY_CODES and
  ERROR_CODES, the library_codes and error_codes tables of the _ssl_data
  header _ssl.c's own #if selects for these headers, preprocessed so every
  entry carries the values these headers define (or the header's fallback).
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
import from common {
    BOOTSTRAP,
    JAC,
    RUNTIME,
    archive_texts,
    extract_tree,
    format_jac,
    pin,
    write_or_check
}

glob CONSTANTS_OUTPUT: Path = RUNTIME / "modules/openssl_constants.jac",
     ERRORS_OUTPUT: Path = RUNTIME / "modules/ssl_errors.jac",
     COMMAND: str = "scripts/jacpython/gen_openssl.jac",
     # The C sources whose OpenSSL names the ports need.
     SOURCES: list[str] = [
         "Modules/_ssl.c",
         "Modules/_ssl.h",
         "Modules/_ssl/cert.c",
         "Modules/_ssl/debughelpers.c",
         "Modules/_ssl/misc.c",
         "Modules/_hashopenssl.c"
     ],
     # What _ssl.c and _hashopenssl.c define before including OpenSSL.
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
    path = JAC / ".python-build/jacpython/sources" / f"{pinned['sha256']}.tar.gz";
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

# Configure the pinned OpenSSL in `scratch` as build.sh does and generate its
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

# The expansions of the sources' own macros that paste tokens
# (ADD_AD_CONSTANT(CLOSE_NOTIFY) is SSL_AD_CLOSE_NOTIFY, ADD_STATS(number, ...)
# calls SSL_CTX_sess_number), one line per call, so the pasted names are read
# like any other.
def pasted_calls(text: str) -> list[str] {
    joined = re.sub(r"\\\n", " ", text);
    expansions: list[str] = [];
    for definition in re.finditer(
        r"^\s*#\s*define\s+(\w+)\(([^)]*)\)(.*)$", joined, re.M
    ) {
        (name, parameters, body) = (
            definition.group(1),
            definition.group(2),
            definition.group(3)
        );
        if "##" not in body {
            continue;
        }
        names = [
            p.strip()
            for p in parameters.split(",")
            if p.strip()
        ];
        for call in re.finditer(rf"\b{name}\(([^()]*)\)", joined) {
            if call.start() >= definition.start() and call.start() < definition.end() {
                continue;
            }
            arguments = [a.strip() for a in call.group(1).split(",")];
            expansion = body;
            for (parameter, argument) in zip(names, arguments) {
                expansion = re.sub(
                    rf"(?<!#)#\s*{parameter}\b", '"' + argument + '"', expansion
                );
                expansion = re.sub(rf"\b{parameter}\b", argument, expansion);
            }
            expansions.append(re.sub(r"\s*##\s*", "", expansion));
        }
    }
    return expansions;
}

# The OpenSSL names the sources use, and those they test in #if conditions.
# A function-like macro the sources call (SSL_set_tlsext_host_name) is ported
# as the call it expands to, so the names of its expansion, and of the
# function-like macros in it, are used too.
def source_names(
    texts: dict[str, str], functions: dict[str, str]
) -> tuple[list[str], list[str]] {
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
    for source in SOURCES {
        text = re.sub(r"/\*.*?\*/|//[^\n]*", "", texts[source], flags=re.S);
        text += "\n" + "\n".join(pasted_calls(text));
        for line in text.splitlines() {
            conditional = re.match(r"\s*#\s*(?:if|ifdef|ifndef|elif)\b(.*)", line);
            for name in re.findall(rf"\b{PREFIXES}\b", line) {
                if name not in used {
                    used.append(name);
                }
                if conditional and name not in tested {
                    tested.append(name);
                }
            }
            for word in re.findall(r"\b[A-Za-z_]\w*\b", line) {
                expand(word);
            }
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
        f"Generated by {COMMAND} from the pinned OpenSSL headers and the",
        f"CPython {pin()['version']} sources that name them; do not edit. UNDEFINED",
        "lists the names the sources test that these headers do not define.",
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
# The library_codes and error_codes entries of the _ssl_data header _ssl.c
# selects, preprocessed against the OpenSSL headers.
def error_tables(
    texts: dict[str, str], headers_dir: Path, compiler: list[str], scratch: Path
) -> tuple[list[tuple[str, int]], list[tuple[str, int, int]], str] {
    source = texts["Modules/_ssl.c"];
    selection = re.search(
        r"^#if \(OPENSSL_VERSION_NUMBER.*?^#endif\n", source, re.M | re.S
    );
    structs = re.search(
        r"^struct py_ssl_error_code \{.*?^struct py_ssl_library_code \{.*?^\};\n",
        source,
        re.M | re.S
    );
    if selection is None or structs is None {
        sys.exit("Modules/_ssl.c no longer has the _ssl_data selection this reads");
    }
    modules = scratch / "Modules";
    modules.mkdir(exist_ok=True);
    for (path, text) in texts.items() {
        if path.startswith("Modules/_ssl_data") {
            (scratch / path).write_text(text);
        }
    }
    probe = modules / "tables.c";
    probe.write_text(
        "\n".join(prologue()) + "\n" + structs.group(0) + selection.group(0)
    );
    expanded = run(
        compiler, ["-E", "-P", f"-I{headers_dir}", f"-I{modules}", str(probe)]
    );
    libraries = re.search(r"library_codes\[\]\s*=\s*\{(.*?)\};", expanded, re.S);
    errors = re.search(r"error_codes\[\]\s*=\s*\{(.*?)\};", expanded, re.S);
    if libraries is None or errors is None {
        sys.exit("the preprocessed _ssl_data header has no library_codes/error_codes");
    }
    library_codes = [
        (name, evaluate(code))
        for (name, code) in re.findall(
            r'\{\s*"(\w+)"\s*,\s*([^{}]+?)\s*\}', libraries.group(1)
        )
    ];
    error_codes = [
        (name, evaluate(library), evaluate(reason))
        for (name, library, reason) in re.findall(
            r'\{\s*"(\w+)"\s*,\s*([^{},]+?)\s*,\s*([^{}]+?)\s*\}', errors.group(1)
        )
    ];
    return (
        library_codes,
        error_codes,
        selected_header(headers_dir, compiler, scratch, selection.group(0))
    );
}

# Which _ssl_data header the selection includes for these headers.
def selected_header(
    headers_dir: Path, compiler: list[str], scratch: Path, selection: str
) -> str {
    marked = re.sub(
        r'#include "(_ssl_data_\w+\.h)"',
        r'const char *__jac_selected = "\1";',
        selection
    );
    probe = scratch / "selected.c";
    probe.write_text("\n".join(prologue()) + "\n" + marked);
    expanded = run(compiler, ["-E", "-P", f"-I{headers_dir}", str(probe)]);
    hit = re.search(r'__jac_selected = "(_ssl_data_\w+\.h)"', expanded);
    if hit is None {
        sys.exit("no _ssl_data header is selected for these OpenSSL headers");
    }
    return hit.group(1);
}

# An integer constant expression of the preprocessed table: literals with C
# suffixes, casts to integer types, parentheses and | + << operators.
def evaluate(expression: str) -> int {
    text = re.sub(
        r"\(\s*(?:unsigned\s+)?(?:long\s+long|long|int|short|char)\s*\)", "", expression
    );
    text = re.sub(r"\b(0[xX][0-9a-fA-F]+|\d+)[uUlL]+\b", r"\1", text);
    if not re.fullmatch(r"[\s0-9a-fA-FxX()|+<>]*", text) {
        sys.exit(f"unexpected expression in the _ssl_data table: {expression}");
    }
    return int(eval(text, {"__builtins__": {}}, {}));
}

def render_errors(
    libraries: list[tuple[str, int]], errors: list[tuple[str, int, int]], header: str
) -> str {
    version = openssl_version();
    lines = [
        f'"""The OpenSSL error names of the native _ssl, from CPython {pin()[
            "version"
        ]}',
        f"Modules/{header}, as _ssl.c selects and preprocesses it against the",
        f"OpenSSL {version} headers.",
        "",
        "LIBRARY_CODES is library_codes, (library name, ERR_LIB_* code);",
        "ERROR_CODES is error_codes, (mnemonic, library, reason).",
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
    texts = archive_texts(tuple(SOURCES) + ("Modules/_ssl_data", ));
    for source in SOURCES {
        if source not in texts {
            sys.exit(f"{source} is not in the pinned archive");
        }
    }
    with tempfile.TemporaryDirectory() as directory {
        scratch = Path(directory);
        headers_dir = openssl_include(scratch / "openssl");
        (macros, functions) = header_macros(headers_dir, compiler, scratch);
        (used, tested) = source_names(texts, functions);
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
        (libraries, errors, header) = error_tables(
            texts, headers_dir, compiler, scratch
        );
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
        format_jac(render_errors(libraries, errors, header), ERRORS_OUTPUT),
        args.check,
        COMMAND
    )
        and current;
    if not current {
        sys.exit(1);
    }
}
