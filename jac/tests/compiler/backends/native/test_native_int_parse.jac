"""Native int() parses a string the way CPython does.

It was strtol: no `0b` or `0o` prefixes, no underscores, base 0 taking a
leading zero as octal, and clamping past 64 bits. The kernel's JCIR
generator lowers every int literal through `int(text, 0)`, so a program with
`0b00111100` failed to compile in the kernel ("invalid literal for int()").
It now goes through the formatting kernel's jac_int_parse.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native int() over strings matches CPython for every base form" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "int_parse.jac");
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[-1] == "114 1295 511 511" , out;
}
