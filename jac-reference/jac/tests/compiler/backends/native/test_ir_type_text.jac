"""A type's text reads back to the same type in a context."""
import from jaclang.compiler.backends.native.llvm { ir }

def _round_trip(text: str) -> str {
    return str(ir.Context().parse_type(text));
}

test "every type form reads back to its own text" {
    for text in [
        "i1",
        "i64",
        "half",
        "float",
        "double",
        "void",
        "ptr",
        "ptr addrspace(3)",
        "{}",
        "{i64, double}",
        "<{i8, i32}>",
        "[4 x i8]",
        "<2 x double>",
        "%\"a.b.Node\"",
        "{%\"a.b.Node\", [2 x {i8, ptr}]}",
        "i64 (i64, ptr)",
        "void ()",
        "i32 (ptr, ...)",
        "void (...)"
    ] {
        assert _round_trip(text) == text , text;
    }
}

test "a named struct reads as the context's struct of that name" {
    ctx = ir.Context();
    named = ctx.get_identified_type("pkg.Node");
    named.set_body(ir.IntType(64), ir.IntType(8).as_pointer());
    read = ctx.parse_type(str(named));
    assert read is named;
    leaf = ctx.parse_type("%\"pkg.Leaf\"");
    assert isinstance(leaf, ir.IdentifiedStructType) and leaf.is_opaque;
}

test "names with quotes and backslashes survive the round trip" {
    ctx = ir.Context();
    odd = ctx.get_identified_type("we\"ird\\name");
    assert ctx.parse_type(str(odd)) is odd;
}

test "text that is not a type is refused" {
    for text in ["", "i", "{i64", "[4 i8]", "%", "i64 junk"] {
        refused = False;
        try {
            ir.Context().parse_type(text);
        } except ValueError {
            refused = True;
        }
        assert refused , text;
    }
}
