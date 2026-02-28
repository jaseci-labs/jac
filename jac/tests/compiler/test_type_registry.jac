"""Tests for the centralized Jac Type Registry."""

import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY, JacPrimitiveTypeEntry }

# ── Basic API ─────────────────────────────────────────────
test "registry contains all expected primitive types" {
    names = JAC_TYPE_REGISTRY.get_primitive_names();
    expected = {"int","float","bool","complex","str","bytes","list","dict","set","frozenset","tuple","range"};
    assert names == expected;
}

test "get returns entry for known types" {
    entry = JAC_TYPE_REGISTRY.get("int");
    assert entry is not None;
    assert entry.name == "int";
}

test "get returns None for unknown types" {
    assert JAC_TYPE_REGISTRY.get("nonexistent") is None;
}

test "has_method works for direct methods" {
    assert JAC_TYPE_REGISTRY.has_method("int", "bit_length");
    assert not JAC_TYPE_REGISTRY.has_method("int", "nonexistent");
}

test "has_method follows inheritance chain (bool -> int)" {
    assert JAC_TYPE_REGISTRY.has_method("bool", "bit_length");
}

# ── int entry ─────────────────────────────────────────────
test "int entry has correct methods" {
    entry = JAC_TYPE_REGISTRY.get("int");
    expected_methods = {"bit_length","bit_count","to_bytes","as_integer_ratio","conjugate","from_bytes"};
    assert set(entry.methods.keys()) == expected_methods;
}

test "int entry has correct operators" {
    entry = JAC_TYPE_REGISTRY.get("int");
    expected_ops = {"op_add","op_sub","op_mul","op_truediv","op_floordiv","op_mod","op_pow","op_and","op_or","op_xor","op_lshift","op_rshift","op_eq","op_ne","op_lt","op_gt","op_le","op_ge","op_neg","op_pos","op_invert"};
    assert set(entry.operators.keys()) == expected_ops;
}

test "int maps to i64 in NA backend" {
    entry = JAC_TYPE_REGISTRY.get("int");
    assert entry.backend_mappings.na_llvm_type_spec == "i64";
}

test "int emitter class is IntEmitter" {
    entry = JAC_TYPE_REGISTRY.get("int");
    assert entry.emitter_class_name == "IntEmitter";
}

# ── float entry ───────────────────────────────────────────
test "float entry has correct methods" {
    entry = JAC_TYPE_REGISTRY.get("float");
    expected_methods = {"is_integer","as_integer_ratio","conjugate","hex","fromhex"};
    assert set(entry.methods.keys()) == expected_methods;
}

test "float maps to f64 in NA backend" {
    entry = JAC_TYPE_REGISTRY.get("float");
    assert entry.backend_mappings.na_llvm_type_spec == "f64";
}

# ── str entry ─────────────────────────────────────────────
test "str entry has at least 40 methods" {
    entry = JAC_TYPE_REGISTRY.get("str");
    assert len(entry.methods) >= 40;
}

test "str entry has correct operators" {
    entry = JAC_TYPE_REGISTRY.get("str");
    expected_ops = {"op_add","op_mul","op_mod","op_eq","op_ne","op_lt","op_gt","op_le","op_ge","op_contains"};
    assert set(entry.operators.keys()) == expected_ops;
}

# ── bool entry ────────────────────────────────────────────
test "bool inherits from int" {
    entry = JAC_TYPE_REGISTRY.get("bool");
    assert entry.inherits_from == "int";
}

test "bool maps to i1 in NA backend" {
    entry = JAC_TYPE_REGISTRY.get("bool");
    assert entry.backend_mappings.na_llvm_type_spec == "i1";
}

# ── Collection entries ────────────────────────────────────
test "list entry has correct methods" {
    entry = JAC_TYPE_REGISTRY.get("list");
    expected_methods = {"append","extend","insert","remove","pop","clear","index","count","sort","reverse","copy"};
    assert set(entry.methods.keys()) == expected_methods;
}

test "dict entry has correct methods" {
    entry = JAC_TYPE_REGISTRY.get("dict");
    expected_methods = {"get","keys","values","items","pop","popitem","setdefault","update","clear","copy","fromkeys"};
    assert set(entry.methods.keys()) == expected_methods;
}

test "set entry has expected methods" {
    entry = JAC_TYPE_REGISTRY.get("set");
    assert "add" in entry.methods;
    assert "union" in entry.methods;
    assert "intersection" in entry.methods;
}

# ── NA type_map integration ───────────────────────────────
test "build_na_type_map produces correct LLVM type mappings" {
    try {
        import from llvmlite { ir }
        type_map = JAC_TYPE_REGISTRY.build_na_type_map(ir);
        assert "int" in type_map;
        assert "float" in type_map;
        assert "bool" in type_map;
        assert "str" in type_map;
        assert type_map["int"] == ir.IntType(64);
        assert type_map["float"] == ir.DoubleType();
        assert type_map["bool"] == ir.IntType(1);
        assert type_map["str"] == ir.IntType(8).as_pointer();
    } except ImportError {
    # llvmlite not available, skip
    }
}

# ── Emitter class suffix ──────────────────────────────────
test "get_emitter_class_suffix returns correct suffixes" {
    assert JAC_TYPE_REGISTRY.get_emitter_class_suffix("int") == "IntEmitter";
    assert JAC_TYPE_REGISTRY.get_emitter_class_suffix("str") == "StrEmitter";
    assert JAC_TYPE_REGISTRY.get_emitter_class_suffix("list") == "ListEmitter";
    assert JAC_TYPE_REGISTRY.get_emitter_class_suffix("bool") == "BoolEmitter";
}

# ── Builtin functions ─────────────────────────────────────
test "registry returns all builtin function names" {
    builtins = JAC_TYPE_REGISTRY.get_builtin_function_names();
    expected_subset = {"print","len","range","int","str","float","bool","list","dict","set","tuple","isinstance","type","abs","round","min","max","sum"};
    assert expected_subset.issubset(builtins);
}

# ── Codespace tags ────────────────────────────────────────
test "primitive types have correct codespace tags" {
    int_entry = JAC_TYPE_REGISTRY.get("int");
    assert int_entry.codespace_tags == {"server","client","native"};
    complex_entry = JAC_TYPE_REGISTRY.get("complex");
    assert "native" not in complex_entry.codespace_tags;
}

# ── Type names with emitters ──────────────────────────────
test "get_type_names_with_emitters includes all types" {
    names = JAC_TYPE_REGISTRY.get_type_names_with_emitters();
    assert names == JAC_TYPE_REGISTRY.get_primitive_names();
}
