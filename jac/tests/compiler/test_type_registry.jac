"""Tests for the centralized Jac Type Registry."""

import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY, JacTypeEntry }

# ── Primitive type names ──────────────────────────────────────
test "registry contains all 12 expected primitive types" {
    names = JAC_TYPE_REGISTRY.primitive_names();
    expected = {"int","float","bool","complex","str","bytes","list","dict","set","frozenset","tuple","range"};
    assert names == expected;
}

# ── Typed entry access ───────────────────────────────────────
test "get returns JacTypeEntry for known types" {
    entry = JAC_TYPE_REGISTRY.get("int");
    assert entry is not None;
    assert isinstance(entry, JacTypeEntry);
    assert entry.name == "int";
    assert entry.emitter_suffix == "IntEmitter";
    assert entry.na_type_spec == "i64";
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
    assert entry_int.emitter_suffix == "IntEmitter";
    entry_str = JAC_TYPE_REGISTRY.get("str");
    assert entry_str.emitter_suffix == "StrEmitter";
    entry_fs = JAC_TYPE_REGISTRY.get("frozenset");
    assert entry_fs.emitter_suffix == "FrozensetEmitter";
    entry_bool = JAC_TYPE_REGISTRY.get("bool");
    assert entry_bool.emitter_suffix == "BoolEmitter";
}

# ── NA type specs ────────────────────────────────────────────
test "na_type_entries returns only types with LLVM representations" {
    entries = JAC_TYPE_REGISTRY.na_type_entries();
    assert len(entries) == 4;
    entry_map = {e[0]: e[1] for e in entries};
    assert entry_map["int"] == "i64";
    assert entry_map["float"] == "f64";
    assert entry_map["bool"] == "i1";
    assert entry_map["str"] == "i8*";
}

test "types without LLVM representation are excluded from na_type_entries" {
    entry_map = {e[0]: e[1] for e in JAC_TYPE_REGISTRY.na_type_entries()};
    assert "complex" not in entry_map;
    assert "list" not in entry_map;
    assert "dict" not in entry_map;
}

# ── Builtin function names ───────────────────────────────────
test "builtin_names contains core builtins" {
    builtins = JAC_TYPE_REGISTRY.builtin_names();
    core = {"print","len","range","int","str","float","bool","list","dict","set","tuple","isinstance","type","abs","round","min","max","sum"};
    assert core.issubset(builtins);
}

test "builtin_names contains type conversions" {
    builtins = JAC_TYPE_REGISTRY.builtin_names();
    conversions = {"str","int","float","bool","list","dict","set","tuple","frozenset","bytes","complex","range","slice","bytearray"};
    assert conversions.issubset(builtins);
}

# ── Cross-consistency ────────────────────────────────────────
test "na_type_entries names are subset of primitive_names" {
    na_names = {e[0] for e in JAC_TYPE_REGISTRY.na_type_entries()};
    assert na_names.issubset(JAC_TYPE_REGISTRY.primitive_names());
}
