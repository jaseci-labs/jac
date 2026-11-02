"""Generate _PyRuntime, CPython's runtime state, as the C data of a Jac module.

Python/pylifecycle.c defines `_PyRuntimeState _PyRuntime =
_PyRuntimeState_INIT(_PyRuntime, _Py_Debug_Cookie)`: the static form of
every statically allocated object (the small ints, the _Py_ID/_Py_STR
strings, the one-byte bytes and strings, the empty singletons), the debug
offsets, the allocator tables and the main interpreter's initial state. Only
the C preprocessor builds that initializer from pycore_runtime_init.h. The
JacPython build runs this generator with the pinned build-time CPython before
the native stage: it compiles the initializer for the build's target against
the tree's own pyconfig.h and headers, reads the bytes and relocations of the
`_PyRuntime` the assembler would emit, and writes them as one Jac module
prepare_native.py lowers into jacpython.o, so the data is the same and no C
of JacPython's own reaches libpython:

- `_PyRuntime` as a `list[ptr]` of its words: data as the word's value, a
  relocation as the address it names (`addressof`, a function, a C string,
  or `addressof(_PyRuntime) + n` for the runtime's own fields);
- each string the initializer points at (the UTF-8 forms of the Latin-1
  one-character strings) as a C string literal.

The output is never checked in; it moves with the CPython pin, the target
and the C library headers, so every build writes it again.

    jac run scripts/jacpython/gen_runtime_image.jac --include <src> \
        --include <src/Include> --output <module.jac> -- zig cc -target T

build_jacpython.zig imports it and calls main() instead.
"""
import argparse;
import re;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }
import from common { pin }

glob COMMAND: str = "scripts/jacpython/gen_runtime_image.jac",
     PROBE: str = (
         '#include "Python.h"\n'
         + '#include "internal/pycore_pystate.h"\n'
         + '#include "internal/pycore_interp.h"\n'
         + '#include "internal/pycore_ceval.h"\n'
         + '#include "internal/pycore_initconfig.h"\n'
         + '#include "internal/pycore_runtime_init.h"\n'
         + "_PyRuntimeState _PyRuntime = _PyRuntimeState_INIT(_PyRuntime, _Py_Debug_Cookie);\n"
     ),
     # Data directives and their widths, across the ELF and Mach-O assemblers
     # of x86-64 and AArch64.
     WIDTHS: dict[str, int] = {
         ".byte": 1,
         ".short": 2,
         ".hword": 2,
         ".2byte": 2,
         ".long": 4,
         ".word": 4,
         ".4byte": 4,
         ".quad": 8,
         ".xword": 8,
         ".8byte": 8
     },
     WORD: int = 8;

# The probe compiled for the target: its assembly and its LLVM IR (which
# says which external symbols are functions).
def compile_probe(cc: list[str], includes: list[str]) -> tuple[str, str] {
    with tempfile.TemporaryDirectory() as scratch {
        source = Path(scratch) / "runtime_image.c";
        source.write_text("#define Py_BUILD_CORE 1\n" + PROBE);
        outputs: list[str] = [];
        for (flags, suffix) in [(["-S"], ".s"), (["-S", "-emit-llvm"], ".ll")] {
            out = Path(scratch) / ("runtime_image" + suffix);
            command = cc
                + flags
                + [
                    "-O1",
                    "-g0",
                    "-fno-asynchronous-unwind-tables",
                    "-Wno-deprecated-declarations"
                ]
                + [f"-I{directory}" for directory in includes]
                + ["-o", str(out), str(source)];
            done = subprocess.run(command, capture_output=True, text=True);
            if done.returncode != 0 {
                sys.exit(f"{COMMAND}: compiling the probe failed:\n{done.stderr}");
            }
            outputs.append(out.read_text());
        }
        return (outputs[0], outputs[1]);
    }
}

# An assembler line without its comment (`#`, `//` or `;` outside a string).
def strip_comment(line: str) -> str {
    in_string = False;
    escaped = False;
    for (i, ch) in enumerate(line) {
        if in_string {
            if escaped {
                escaped = False;
            } elif ch == "\\" {
                escaped = True;
            } elif ch == '"' {
                in_string = False;
            }
            continue;
        }
        if ch == '"' {
            in_string = True;
        } elif ch == "#" or ch == ";" or line[i:i + 2] == "//" {
            return line[:i];
        }
    }
    return line;
}

# The bytes of an assembler string literal (C escapes, octal for bytes).
def string_bytes(text: str) -> bytes {
    out = bytearray();
    i = 0;
    while i < len(text) {
        ch = text[i];
        if ch != "\\" {
            out += ch.encode("latin-1");
            i += 1;
            continue;
        }
        nxt = text[i + 1];
        if nxt in "01234567" {
            j = i + 1;
            while j < len(text) and j < i + 4 and text[j] in "01234567" {
                j += 1;
            }
            out.append(int(text[i + 1:j], 8));
            i = j;
            continue;
        }
        simple = {"n": 10, "t": 9, "r": 13, "b": 8, "f": 12, '"': 34, "\\": 92};
        if nxt in simple {
            out.append(simple[nxt]);
            i += 2;
            continue;
        }
        if nxt == "x" {
            j = i + 2;
            while j < len(text) and text[j] in "0123456789abcdefABCDEF" {
                j += 1;
            }
            out.append(int(text[i + 2:j], 16) & 255);
            i = j;
            continue;
        }
        out += nxt.encode("latin-1");
        i += 2;
    }
    return bytes(out);
}

# The quoted string arguments of an .ascii/.asciz directive.
def quoted_strings(operand: str) -> list[str] {
    return re.findall(r'"((?:\\.|[^"\\])*)"', operand);
}

# A data label's name as C spells it: Mach-O prefixes C names with `_`.
def c_name(symbol: str, macho: bool) -> str {
    return symbol[1:] if macho and symbol.startswith("_") else symbol;
}

obj Image {
    has data: bytearray,
        relocations: dict[int, tuple[str, int]],
        strings: dict[str, bytes];
}

# `_PyRuntime`'s bytes and relocations (offset -> (symbol, addend)), and the
# strings its relocations name, from the assembly.
def read_image(asm: str) -> Image {
    lines = [strip_comment(line).strip() for line in asm.splitlines()];
    macho = "__PyRuntime:" in lines;
    label = "__PyRuntime:" if macho else "_PyRuntime:";
    strings: dict[str, bytes] = {};
    current: str | None = None;
    for line in lines {
        if line.endswith(":") and " " not in line {
            current = line[:-1];
            continue;
        }
        if current is not None and re.match(r"^\.(ascii|asciz|string)\b", line) {
            directive = line.split()[0];
            body = b"".join(string_bytes(s) for s in quoted_strings(line));
            if directive != ".ascii" {
                body += b"\x00";
            }
            strings[current] = strings.get(current, b"") + body;
        } elif not line.startswith(".")
            or line.startswith((".section", ".text", ".data")) {
            current = None;
        }
    }
    start = lines.index(label) + 1;
    data = bytearray();
    relocations: dict[int, tuple[str, int]] = {};
    for line in lines[start:] {
        if not line {
            continue;
        }
        if line.endswith(":")
            or line.startswith(
                (
                    ".size",
                    ".section",
                    ".subsections_via_symbols",
                    ".text",
                    ".globl",
                    ".type"
                )
            ) {
            break;
        }
        parts = line.split(None, 1);
        directive = parts[0];
        operand = parts[1] if len(parts) > 1 else "";
        if directive in (".zero", ".space", ".skip") {
            values = [int(v.strip(), 0) for v in operand.split(",")];
            fill = values[1] if len(values) > 1 else 0;
            data += bytes([fill & 255]) * values[0];
        } elif directive in (".ascii", ".asciz", ".string") {
            for text in quoted_strings(operand) {
                data += string_bytes(text);
                if directive != ".ascii" {
                    data.append(0);
                }
            }
        } elif directive in WIDTHS {
            width = WIDTHS[directive];
            for item in operand.split(",") {
                item = item.strip();
                if re.fullmatch(r"-?(0x[0-9a-fA-F]+|\d+)", item) {
                    data += (int(item, 0) & ((1 << (8 * width)) - 1)).to_bytes(
                        width, "little"
                    );
                    continue;
                }
                hit = re.fullmatch(
                    r"\(?([A-Za-z_.$][\w.$]*)\)?\s*(?:([+-])\s*(\d+))?", item
                );
                if hit is None or width != WORD {
                    sys.exit(f"{COMMAND}: unsupported data operand `{line}`");
                }
                addend = int(hit.group(3) or "0") * (-1 if hit.group(2) == "-" else 1);
                relocations[len(data)] = (hit.group(1), addend);
                data += bytes(WORD);
            }
        } elif directive.startswith(".p2align") or directive == ".align" {
            continue;
        } else {
            sys.exit(f"{COMMAND}: unexpected directive in _PyRuntime: `{line}`");
        }
    }
    return Image(data=data, relocations=relocations, strings=strings);
}

# The C names the IR declares as functions.
def declared_functions(ir: str) -> set[str] {
    return set(re.findall(r"^declare [^@]*@\"?([\w.$]+)\"?\(", ir, re.M));
}

def jac_string(data: bytes) -> str | None {
    if not data.endswith(b"\x00") or b"\x00" in data[:-1] {
        return None;
    }
    try {
        text = data[:-1].decode("utf-8");
    } except UnicodeDecodeError {
        return None;
    }
    out: list[str] = [];
    for ch in text {
        code = ord(ch);
        if 32 <= code < 127 and ch not in ('"', "\\") {
            out.append(ch);
        } elif code < 0x10000 {
            out.append(f"\\u{code:04x}");
        } else {
            out.append(f"\\U{code:08x}");
        }
    }
    return 'ptr[u8]("' + "".join(out) + '")';
}

def image_module(image: Image, functions: set[str], expected_size: int | None) -> str {
    macho = any(name.startswith(("l_", "L_")) for name in image.strings)
        or any(sym.startswith("__Py") for (sym, _) in image.relocations.values());
    size = len(image.data);
    if size % WORD {
        sys.exit(f"{COMMAND}: _PyRuntime is {size} bytes, not whole words");
    }
    if expected_size is not None and size != expected_size {
        sys.exit(
            f"{COMMAND}: _PyRuntime is {size} bytes here but {expected_size} in the layouts"
        );
    }
    data_symbols: set[str] = set();
    function_symbols: set[str] = set();
    words: list[str] = [];
    for offset in range(0, size, WORD) {
        if offset in image.relocations {
            (symbol, addend) = image.relocations[offset];
            name = c_name(symbol, macho);
            if name == "_PyRuntime" {
                if addend % WORD {
                    sys.exit(f"{COMMAND}: _PyRuntime names its own byte {addend}");
                }
                words.append(f"ptr(addressof(_PyRuntime) + {addend // WORD})");
            } elif symbol in image.strings {
                text = jac_string(image.strings[symbol]);
                if text is None or addend != 0 {
                    sys.exit(
                        f"{COMMAND}: _PyRuntime names the string {symbol}+{addend}"
                    );
                }
                words.append(text);
            } elif name in functions {
                if addend != 0 {
                    sys.exit(f"{COMMAND}: _PyRuntime names {name}+{addend}");
                }
                function_symbols.add(name);
                words.append(f"ptr({name})");
            } else {
                data_symbols.add(name);
                words.append(
                    f"addressof({name})"
                        if addend == 0
                        else f"ptr(addressof({name}) + {addend})"
                );
            }
            continue;
        }
        value = int.from_bytes(image.data[offset:offset + WORD], "little");
        words.append("ptr(" + hex(value) + ")" if value else "ptr()");
    }
    lines = [
        '"""_PyRuntime, as Python/pylifecycle.c defines it for CPython '
            + pin()["version"]
            + ".",
        "",
        f"Generated by {COMMAND} at build time; never checked in.",
        'See jac/jaclang/runtime/python/LICENSE.cpython.\n"""',
        "",
        "import from c {"
    ];
    for name in sorted(function_symbols) {
        lines.append(f"    def {name} -> ptr;");
    }
    if data_symbols {
        lines.append(
            "    glob "
                + ",\n         ".join(f"{name}: u8" for name in sorted(data_symbols))
                + ";"
        );
    }
    lines.append("    glob _PyRuntime: list[ptr] = [");
    lines.append(",\n".join(f"             {word}" for word in words));
    lines.append("         ];");
    lines.append("}");
    return "\n".join(lines) + "\n";
}

# _PyRuntimeState_SIZE for the build's platform, from the checked-in
# layouts, when the generator can tell which platform that is.
def layout_size(platform: str | None) -> int | None {
    if not platform {
        return None;
    }
    runtime_dir = Path(__file__).resolve().parents[2] / "jac/jaclang/runtime/python";
    osname = {"linux": "linux", "macos": "darwin"}[platform.split("-")[0]];
    module = runtime_dir / f"layouts_platform.{osname}.{platform.split('-')[1]}.jac";
    hit = re.search(r"_PyRuntimeState_SIZE: Final\[i64\] = (\d+)", module.read_text());
    return int(hit.group(1)) if hit else None;
}

def main(argv: list[str]) {
    parser = argparse.ArgumentParser(
        prog=COMMAND, description="Write _PyRuntime as a Jac module."
    );
    parser.add_argument(
        "--include",
        action="append",
        dest="includes",
        help="a directory of the configured headers (pyconfig.h, Include)"
    );
    parser.add_argument("--output", required=True, help="the Jac module to write");
    parser.add_argument(
        "--platform", help="the build platform (linux-x86_64, ...), to check the size"
    );
    parser.add_argument(
        "cc",
        nargs=argparse.REMAINDER,
        help="the C compiler command for the build's target, after --"
    );
    parser.set_defaults(includes=[]);
    args = parser.parse_args(argv);
    cc = args.cc[1:] if args.cc[:1] == ["--"] else args.cc;
    if not cc {
        parser.error("the C compiler command follows --");
    }
    (asm, ir) = compile_probe(cc, args.includes);
    image = read_image(asm);
    text = image_module(image, declared_functions(ir), layout_size(args.platform));
    output = Path(args.output);
    output.parent.mkdir(parents=True, exist_ok=True);
    output.write_text(text);
    print(
        f"{COMMAND}: {len(image.data)} bytes, {len(image.relocations)} relocations -> {output}"
    );
}

with entry:__main__ {
    main(sys.argv[1:]);
}
