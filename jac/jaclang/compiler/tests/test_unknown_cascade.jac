"""Checker regression: Any/Unknown values must not cascade into E1053/E1055/E1001.

Pins the gradual-typing contract at the two seams the strict-Unknown discipline
leaks through (#7626 C7 census: wasm_linker E1053, macho_linker E1055):

- Unpacking `tuple[Any, ...]` (e.g. `struct.unpack_from`) yields `Any` elements,
  not strict Unknown, so arithmetic on them resolves silently.
- A binary op with an `Any` operand evaluates to `Any` (not strict Unknown), so
  the result stays usable as an argument and assignment source.
- A binary op with an Unknown operand propagates Unknown silently -- the operand
  site already carries the W1051 warning; a second E1055 on the op is noise.

A genuinely mistyped operation (`str + int` on resolved types) must still be
reported: the discipline stays strict where the types are actually known.
"""

import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }

def check_src(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="uc_src.jac",
        use_str=src,
        options=CompileOptions(type_check=True, no_cgen=True)
    );
    return [str(e) for e in prog.errors_had];
}

test "unpack of tuple[Any, ...] supports arithmetic and int seams" {
    src = "import struct;\n"
    "\n"
    "def takes_int(x: int) -> int {\n"
    "    return x + 1;\n"
    "}\n"
    "\n"
    "def slice_ends(raw: bytes) -> bytes {\n"
    "    (s_offset, s_size) = struct.unpack_from(\"<QQ\", raw, 0);\n"
    "    takes_int(s_offset + s_size);\n"
    "    return raw[s_offset:s_offset + s_size];\n"
    "}\n";
    errors = check_src(src);
    assert errors == [] , errors;
}

test "bare-tuple unpack arithmetic flows through int params and int slots" {
    src = "def rd(b: bytes, o: int) -> tuple {\n"
    "    return (b[o], o + 1);\n"
    "}\n"
    "\n"
    "def takes_int(x: int) -> int {\n"
    "    return x + 1;\n"
    "}\n"
    "\n"
    "def parse(b: bytes) -> int {\n"
    "    o = 8;\n"
    "    acc = 0;\n"
    "    while o < len(b) {\n"
    "        (size, o) = rd(b, o);\n"
    "        end = o + size;\n"
    "        acc = takes_int(end);\n"
    "        o = end;\n"
    "    }\n"
    "    return acc;\n"
    "}\n";
    errors = check_src(src);
    assert errors == [] , errors;
}

test "augmented assign checks the operator result, not the raw rhs" {
    src = "def build -> bytes {\n"
    "    out = bytearray(b\"seed\");\n"
    "    out += b\"more\";\n"
    "    return bytes(out);\n"
    "}\n";
    errors = check_src(src);
    assert errors == [] , errors;
}

test "control: augmented assign rejects a result the target cannot hold" {
    src = "def bump -> int {\n"
    "    x: int = 1;\n"
    "    x += 0.5;\n"
    "    return x;\n"
    "}\n";
    errors = check_src(src);
    assert any("E1001" in e or "float" in e for e in errors) , errors;
}

test "control: resolved-type overload mismatch is still reported" {
    src = "def bad -> str {\n"
    "    return \"a\" + 1;\n"
    "}\n";
    errors = check_src(src);
    assert any(
        ("E1055" in e) or ("E1010" in e) or ("__add__" in e) for e in errors
    ) , errors;
}
