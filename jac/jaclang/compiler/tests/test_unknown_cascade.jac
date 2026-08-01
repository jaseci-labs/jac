"""Checker regression: the Any/Unknown seams the linker modules lean on.

Pins the reconciled contract behind the #7626 C7 census entries for
wasm_linker (E1053) and macho_linker (E1055), without weakening the
strict-Unknown discipline the checker_prod_unknown_* fixtures enforce:

- Unpacking `tuple[Any, ...]` (e.g. `struct.unpack_from`) yields the element
  type, not a strict Unknown leaked from the ellipsis slot, and binary ops on
  those Any values take the silent early-out (no E1055 per op) while their
  results stay strict Unknown that unannotated locals absorb.
- Bare-`tuple` returns are an author-side inference gap: annotating them
  (`-> tuple[int, int]`) is the sanctioned remedy and checks clean.
- Augmented assignment validates the operator result, not the raw rhs, so
  `bytearray += bytes` passes while `int += 0.5` still errors.
- Genuinely mistyped ops on resolved types keep reporting.
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

test "unpack of tuple[Any, ...] adds without per-op overload errors" {
    src = "import struct;\n"
    "\n"
    "def slice_ends(raw: bytes) -> bytes {\n"
    "    (s_offset, s_size) = struct.unpack_from(\"<QQ\", raw, 0);\n"
    "    sec_data = raw[s_offset:s_offset + s_size];\n"
    "    return sec_data;\n"
    "}\n";
    errors = check_src(src);
    assert errors == [] , errors;
}

test "annotated tuple returns flow through int params and int slots" {
    src = "def rd(b: bytes, o: int) -> tuple[int, int] {\n"
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

test "control: ops on Any stay strict at typed seams" {
    src = "def probe -> int {\n"
    "    items: list = [1, 2, 3];\n"
    "    u = items.pop();\n"
    "    v = u + 1;\n"
    "    bad: int = v;\n"
    "    return bad;\n"
    "}\n";
    errors = check_src(src);
    assert any("E1001" in e or "Unknown" in e for e in errors) , errors;
}

test "control: resolved-type overload mismatch is still reported" {
    src = "def bad -> str {\n" "    return \"a\" + 1;\n" "}\n";
    errors = check_src(src);
    assert any(
        ("E1055" in e) or ("E1010" in e) or ("__add__" in e) for e in errors
    ) , errors;
}
