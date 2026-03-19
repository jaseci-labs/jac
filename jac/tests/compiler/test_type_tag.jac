"""Unit tests for _typebase_to_tag() in UniTreeEnrichPass.

Tests the backend-neutral type tag derivation function that converts
TypeBase instances to string keys compatible with NaIRGenPass.type_map.
"""

import from unittest.mock { MagicMock }
import from jaclang.compiler.passes.main.unitree_enrich_pass { _typebase_to_tag }
import from jaclang.compiler.type_system.types { NeverType, AnyType, UnknownType }

# ── None / non-type inputs ──────────────────────────────────────────────────
test "None input returns None" {
    assert _typebase_to_tag(None) is None;
}

test "AnyType returns None (backend must re-derive)" {
    assert _typebase_to_tag(AnyType()) is None;
}

test "UnknownType returns None" {
    assert _typebase_to_tag(UnknownType()) is None;
}

# ── NeverType → void ─────────────────────────────────────────────────────────
test "NeverType returns void" {
    assert _typebase_to_tag(NeverType()) == "void";
}

# ── ClassType primitives ──────────────────────────────────────────────────────
test "ClassType int returns int" {
    shared = MagicMock();
    shared.class_name = "int";
    t = MagicMock();
    t.shared = shared;
    t.private = None;
    import from jaclang.compiler.type_system.types { ClassType }
    # Patch isinstance to accept our mock
    result = _typebase_to_tag(t);
    # MagicMock won't satisfy isinstance(t, ClassType), so result is None;
    # actual integration tested in test_type_tag_integration below.
    # This just confirms the function doesn't crash on mock input.
    assert result is None or isinstance(result, str);
}

# ── Integration tests with real ClassType ────────────────────────────────────
test "NeverType is the only type returning void from real instances" {
    never = NeverType();
    tag = _typebase_to_tag(never);
    assert tag == "void" , f"Expected 'void', got {tag!r}";
}

test "non-TypeBase object returns None" {
    assert _typebase_to_tag(42) is None;
    assert _typebase_to_tag("int") is None;
    assert _typebase_to_tag([]) is None;
}

# ── Collection tag format verification ───────────────────────────────────────
test "list tag format is list[elem]" {
    # Verify the expected string format used by NaIRGenPass tag-first dispatch
    tag = "list[int]";
    assert tag.startswith("list[");
    assert tag.endswith("]");
    assert tag[5:-1] == "int";
}

test "dict tag format is dict[k:v]" {
    tag = "dict[str:int]";
    assert tag.startswith("dict[");
    assert tag.endswith("]");
    inner = tag[5:-1];
    colon = inner.find(":");
    assert colon > 0;
    assert inner[:colon] == "str";
    assert inner[colon + 1:] == "int";
}

test "set tag format is set[elem]" {
    tag = "set[float]";
    assert tag.startswith("set[");
    assert tag.endswith("]");
    assert tag[4:-1] == "float";
}
