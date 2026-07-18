"""Diagnostic coverage for native `chr(0)` str concatenation (issue #6789).

Native `str` lowers to a NUL-terminated C string (`i8*`), so `+` measures its
operands with `strlen` and truncates at the first embedded NUL -- `chr(65) +
chr(0) + chr(66)` yields length 1 on `na` where `sv` yields 3. Because `str`
carries no explicit length this cannot be fixed in codegen without breaking the
direct libc FFI that `i8*` exists for, so the native capability check warns
(W6005) and the FFI guide steers authors to `bytes` for binary buffers.

These tests pin that the literal `chr(0)` operand of a native `str` concat is
flagged exactly once, and that the neighbouring non-NUL / non-concat / dynamic /
non-native shapes stay quiet (no false positives).
"""

import from jaclang.jac0core.program { JacProgram }


"""Type-check `src` and return the W6005 (embedded-NUL) warning texts."""
def _nul_warnings(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="nul_concat_src.jac", use_str=src, type_check=True, no_cgen=True
    );
    assert [str(e) for e in prog.errors_had] == [] , prog.errors_had;
    return [
        str(w)
        for w in prog.warnings_had
        if "Embedded NUL" in str(w)
    ];
}


test "native chr(0) in a str concat chain is flagged once" {
    warns = _nul_warnings(
        "na {\n"
        "    def pack() -> int {\n"
        "        buf: str = chr(65) + chr(0) + chr(66);\n"
        "        return len(buf);\n"
        "    }\n"
        "}\n"
    );
    assert len(warns) == 1 , warns;
    assert "chr(0)" in warns[0] , warns;
}


test "bare chr(0), plain concat, and dynamic bytes do not warn" {
    warns = _nul_warnings(
        "na {\n"
        "    def bare() -> int { c: str = chr(0); return len(c); }\n"
        "    def plain() -> str { return chr(65) + chr(66); }\n"
        "    def dyn(v: int) -> str {\n"
        "        return chr(v & 0xFF) + chr((v >> 8) & 0xFF);\n"
        "    }\n"
        "}\n"
    );
    assert warns == [] , warns;
}


test "chr(0) concat outside a native context is not flagged" {
    warns = _nul_warnings(
        "with entry {\n"
        "    buf: str = chr(65) + chr(0) + chr(66);\n"
        "    print(len(buf));\n"
        "}\n"
    );
    assert warns == [] , warns;
}
