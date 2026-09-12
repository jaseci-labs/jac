"""Tests for the centralized Jac Type Registry."""

import from jaclang.compiler.analysis.types.type_registry {
    JAC_TYPE_REGISTRY,
    JacTypeEntry
}

def ent(name: str) -> JacTypeEntry {
    `entry = JAC_TYPE_REGISTRY.get(name);
    assert `entry is not None , name;
    return `entry;
}

# ── Primitive type names ──────────────────────────────────────
test "registry contains all 22 expected primitive types" {
    names = JAC_TYPE_REGISTRY.primitive_names();
    expected = {
        "int",
        "float",
        "bool",
        "complex",
        "str",
        "bytes",
        "list",
        "dict",
        "set",
        "frozenset",
        "tuple",
        "range",
        "i8",
        "u8",
        "i16",
        "u16",
        "i32",
        "u32",
        "i64",
        "u64",
        "f32",
        "f64"
    };
    assert names == expected;
}

# ── Typed entry access ───────────────────────────────────────
test "get returns JacTypeEntry for known types" {
    `entry = JAC_TYPE_REGISTRY.get("int");
    assert `entry is not None;
    assert isinstance(`entry, JacTypeEntry);
    assert `entry.name == "int";
    assert `entry.emitter_suffix == "IntEmitter";
    assert `entry.width == 64;
    assert `entry.signed;
    assert not `entry.is_float;
}

test "get returns None for unknown types" {
    assert JAC_TYPE_REGISTRY.get("nonexistent") is None;
}

# ── Emitter suffix mapping ───────────────────────────────────
test "emitter_items covers all primitive types" {
    items = JAC_TYPE_REGISTRY.emitter_items();
    names = {item[0] for item in items};
    assert names == JAC_TYPE_REGISTRY.primitive_names();
}

test "emitter suffixes follow naming convention" {
    entry_int = JAC_TYPE_REGISTRY.get("int");
    assert entry_int is not None;
    assert entry_int.emitter_suffix == "IntEmitter";
    entry_str = JAC_TYPE_REGISTRY.get("str");
    assert entry_str is not None;
    assert entry_str.emitter_suffix == "StrEmitter";
    entry_fs = JAC_TYPE_REGISTRY.get("frozenset");
    assert entry_fs is not None;
    assert entry_fs.emitter_suffix == "FrozensetEmitter";
    entry_bool = JAC_TYPE_REGISTRY.get("bool");
    assert entry_bool is not None;
    assert entry_bool.emitter_suffix == "BoolEmitter";
}

test "fixed-width types reuse IntEmitter and FloatEmitter" {
    for name in ["i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64"] {
        `entry = JAC_TYPE_REGISTRY.get(name);
        assert `entry is not None;
        assert `entry.emitter_suffix == "IntEmitter";
    }
    for name in ["f32", "f64"] {
        `entry = JAC_TYPE_REGISTRY.get(name);
        assert `entry is not None;
        assert `entry.emitter_suffix == "FloatEmitter";
    }
}

# ── Native scalar shape: (width, signed, is_float) ───────────
test "every scalar entry carries a structured native shape, not a spec string" {
    shapes = {
        "int": (64, True, False),
        "float": (64, False, True),
        "bool": (1, False, False),
        "i8": (8, True, False),
        "u8": (8, False, False),
        "i16": (16, True, False),
        "u16": (16, False, False),
        "i32": (32, True, False),
        "u32": (32, False, False),
        "i64": (64, True, False),
        "u64": (64, False, False),
        "f32": (32, False, True),
        "f64": (64, False, True)
    };
    for (name, shape) in shapes.items() {
        e = ent(name);
        assert (e.width, e.signed, e.is_float) == shape , name;
    }
    assert not hasattr(ent("int"), "na_type_spec");
}

test "byte size and alignment derive from the width" {
    assert ent("u8").size_bytes() == 1;
    assert ent("bool").size_bytes() == 1;
    assert ent("i16").size_bytes() == 2;
    assert ent("f32").size_bytes() == 4;
    assert ent("u64").size_bytes() == 8;
    assert ent("str").size_bytes() == 8;
    assert ent("f64").align() == 8;
    assert ent("list").width == 0;
}

test "types without a native scalar shape report width 0" {
    for name in ["complex", "list", "dict", "set", "tuple", "range", "bytes"] {
        assert ent(name).width == 0 , name;
    }
}

# ── Sized-type queries ───────────────────────────────────────
test "sized name queries enumerate exactly the ten fixed-width types" {
    assert JAC_TYPE_REGISTRY.sized_int_names()
        == ["i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64"];
    assert JAC_TYPE_REGISTRY.sized_float_names() == ["f32", "f64"];
    assert JAC_TYPE_REGISTRY.sized_scalar_names()
        == ["i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64", "f32", "f64"];
    assert JAC_TYPE_REGISTRY.is_sized("u8");
    assert not JAC_TYPE_REGISTRY.is_sized("int");
    assert not JAC_TYPE_REGISTRY.is_sized("bool");
}

test "range_of gives the inclusive bounds of each sized int" {
    assert JAC_TYPE_REGISTRY.range_of("i8") == (-128, 127);
    assert JAC_TYPE_REGISTRY.range_of("u8") == (0, 255);
    assert JAC_TYPE_REGISTRY.range_of("i16") == (-32768, 32767);
    assert JAC_TYPE_REGISTRY.range_of("u16") == (0, 65535);
    assert JAC_TYPE_REGISTRY.range_of("i32") == (-2147483648, 2147483647);
    assert JAC_TYPE_REGISTRY.range_of("u32") == (0, 4294967295);
    assert JAC_TYPE_REGISTRY.range_of("i64")
        == (-9223372036854775808, 9223372036854775807);
    assert JAC_TYPE_REGISTRY.range_of("u64") == (0, 18446744073709551615);
}

test "literal_fits checks a literal against a sized type" {
    assert JAC_TYPE_REGISTRY.literal_fits("u8", 255);
    assert not JAC_TYPE_REGISTRY.literal_fits("u8", 256);
    assert not JAC_TYPE_REGISTRY.literal_fits("u8", -1);
    assert JAC_TYPE_REGISTRY.literal_fits("i8", -128);
    assert not JAC_TYPE_REGISTRY.literal_fits("i8", -129);
    assert JAC_TYPE_REGISTRY.literal_fits("f64", 0.1);
    assert not JAC_TYPE_REGISTRY.literal_fits("u8", 1.5);
    assert JAC_TYPE_REGISTRY.literal_fits("f32", 0.1) , (
        "precision loss inside the range stays accepted"
    );
    assert JAC_TYPE_REGISTRY.literal_fits("f32", 3.4e38);
    assert not JAC_TYPE_REGISTRY.literal_fits("f32", 10 ** 40) , (
        "a literal past the largest finite f32 would arrive as inf"
    );
    assert not JAC_TYPE_REGISTRY.literal_fits("f32", 1e60);
    assert JAC_TYPE_REGISTRY.literal_fits("f64", 1e300);
    assert not JAC_TYPE_REGISTRY.literal_fits("f64", 10 ** 400);
}

test "widens_to is the value-preserving lattice" {
    W = JAC_TYPE_REGISTRY.widens_to;
    assert W("u8", "u8") and W("int", "int") and W("f32", "f32");
    assert W("i8", "i16") and W("i16", "i32") and W("i32", "i64") and W("i64", "int");
    assert W("i8", "int");
    assert W("u8", "u16") and W("u16", "u32") and W("u32", "u64");
    assert not W("u64", "int") , (
        "u64 -> int must be refused: `int` is a signed 64-bit machine type "
        "natively, so a u64 above 2^63 crosses as a negative there while the "
        "server keeps it positive"
    );
    assert W("u8", "i16") and W("u16", "i32") and W("u32", "i64");
    assert not W("u64", "i64") and not W("u8", "i8") and not W("i8", "u8");
    assert not W("i16", "i8") and not W("int", "u8");
    assert W("int", "i64") , "int and i64 are the same machine type";
    assert not W("i64", "i32") and not W("u64", "u32");
    assert W("i8", "f32") and W("u8", "f32") and W("i16", "f32") and W("u16", "f32");
    assert not W("i32", "f32") and not W("u32", "f32") and not W("i64", "f32");
    assert W("i32", "f64") and W("u32", "f64") and W("i16", "f64");
    assert W("i64", "f64") and W("u64", "f64") and W("int", "f64") , (
        "a 64-bit int widens into a 64-bit float the same way it widens into "
        "`float`; both lanes lose the same precision above 2^53"
    );
    assert W("f32", "f64") and W("f64", "float") and W("float", "f64");
    assert W("f32", "float");
    assert not W("f64", "f32") and not W("float", "f32");
    assert W("bool", "u8") and W("bool", "i64") and W("bool", "int");
    assert W("bool", "float") and W("bool", "f32");
    assert W("int", "float") and W("i8", "float") and W("u64", "float");
    assert not W("float", "int") and not W("f32", "i32") and not W("float", "i8");
    assert not W("str", "int") and not W("int", "str") and not W("list", "u8");
}

test "int and i64 are one type in the lattice, as are float and f64" {
    W = JAC_TYPE_REGISTRY.widens_to;
    names = JAC_TYPE_REGISTRY.sized_scalar_names() + ["int", "float", "bool"];
    drift: list[str] = [];
    for pair in [("int", "i64"), ("float", "f64")] {
        (alias, sized) = pair;
        for other in names {
            if other in pair {
                continue;
            }
            if W(other, alias) != W(other, sized) {
                drift.append(f"{other} -> {alias} vs {other} -> {sized}");
            }
            if W(alias, other) != W(sized, other) {
                drift.append(f"{alias} -> {other} vs {sized} -> {other}");
            }
        }
    }
    assert not drift , (
        "the lattice answers differently depending on how the same machine "
        f"type is spelled: {drift}"
    );
}

test "unify picks the wider lattice member or refuses" {
    U = JAC_TYPE_REGISTRY.unify;
    assert U("i8", "i8") == "i8";
    assert U("i8", "i64") == "i64" and U("i64", "i8") == "i64";
    assert U("u8", "i16") == "i16";
    assert U("i16", "f32") == "f32";
    assert U("u64", "int") is None and U("int", "u64") is None;
    assert U("f32", "float") == "float";
    assert U("bool", "u8") == "u8";
    assert U("i8", "u8") is None;
    assert U("u64", "i64") is None;
    assert U("i64", "f32") is None;
    assert U("i32", "u32") is None;
    assert U("str", "i8") is None;
}

# ── Single source of truth ───────────────────────────────────
test "the sized names, widths and signedness are defined in one table only" {
    import re;
    import from pathlib { Path }
    import jaclang;
    pkg = Path(jaclang.__file__).parent;
    # The lexer and parser own the keyword spellings; the jac0core scalar
    # table owns the types and the registry is built from it. Everything
    # else must query the registry (or, below the compiler, the table). The
    # runtime's `__all__` is an export manifest, not a type list: the parity
    # test pins it to the checker stub and the emitter registry.
    owners = {
        "runtime/scalars.jac",
        "runtime/builtin.jac",
        "compiler/ir/enums.jac",
        "compiler/frontend/parser/tokens.jac",
        "compiler/frontend/parser/parser.jac",
        "compiler/frontend/parser/impl/parser.impl.jac",
        "compiler/frontend/parser/seed_lexer.jac",
        "compiler/frontend/parser/jac_lexer.jac"
    };
    # The unsigned spellings above eight bits can only ever be a language-type
    # name: LLVM spells widths as iN, `list_types["u8"]` is the native
    # bytearray element key, and `"f32"`/`"f64"` double as LLVM layout
    # spellings in the interop manifest. Any second copy of the ten-name list
    # carries them, so probing these three is exact without exemptions.
    pat = re.compile('["\'](u16|u32|u64)["\']');
    offenders: list[str] = [];
    for path in sorted(pkg.rglob("*.jac")) {
        rel = path.relative_to(pkg).as_posix();
        if not path.is_file()
            or rel in owners
            or "/tests/" in ("/" + rel)
            or rel.startswith("cli/docs")
            or rel.startswith("cli/skills") {
            continue;
        }
        for (lineno, line) in enumerate(path.read_text().splitlines(), 1) {
            if pat.search(line) {
                offenders.append(f"{rel}:{lineno}: {line.strip()}");
            }
        }
    }
    assert offenders == [] , "\n".join(offenders);
}

# ── Builtin function names ───────────────────────────────────
test "builtin_names contains core builtins" {
    builtins = JAC_TYPE_REGISTRY.builtin_names();
    core = {
        "print",
        "len",
        "range",
        "int",
        "str",
        "float",
        "bool",
        "list",
        "dict",
        "set",
        "tuple",
        "isinstance",
        "type",
        "abs",
        "round",
        "min",
        "max",
        "sum"
    };
    assert core.issubset(builtins);
}

test "builtin_names contains type conversions" {
    builtins = JAC_TYPE_REGISTRY.builtin_names();
    conversions = {
        "str",
        "int",
        "float",
        "bool",
        "list",
        "dict",
        "set",
        "tuple",
        "frozenset",
        "bytes",
        "complex",
        "range",
        "slice",
        "bytearray"
    };
    assert conversions.issubset(builtins);
}

# ── Cross-consistency ────────────────────────────────────────
test "sized scalar names are a subset of primitive_names" {
    sized = set(JAC_TYPE_REGISTRY.sized_scalar_names());
    assert sized.issubset(JAC_TYPE_REGISTRY.primitive_names());
}
