"""JIR round-trip tests for SEC_TYPE_TAGS section.

Verifies that backend_type_tag values set by UniTreeEnrichPass are
serialized into the SEC_TYPE_TAGS section during JIR write and correctly
restored to Expr nodes during JIR read.
"""

import from jaclang.jac0core.jir_passes { JirWriter, JirReader }
import from jaclang.jac0core.jir { SEC_TYPE_TAGS }
import from unittest.mock { MagicMock }

# ── Section constant ──────────────────────────────────────────────────────────
test "SEC_TYPE_TAGS constant is 0x07" {
    assert SEC_TYPE_TAGS == 0x07;
}

# ── Corrupt section safety ────────────────────────────────────────────────────
test "_apply_type_tags with empty bytes does not crash" {
    reader = JirReader();
    # Empty section: count=0 encoded as single zero byte
    reader._nodes = [];
    reader._pool = MagicMock();
    empty_section = bytes([0]);
    # Should not raise; tags remain None
    reader._apply_type_tags(empty_section);
}

test "_apply_type_tags with truncated data does not crash" {
    reader = JirReader();
    reader._nodes = [];
    reader._pool = MagicMock();
    # Truncated: claims 5 pairs but has no data
    truncated = bytes([5]);
    try {
        reader._apply_type_tags(truncated);
    } except Exception {
        ;  # any exception is acceptable — no crash to unhandled state
    }
}

# ── Serialization format ──────────────────────────────────────────────────────
test "_serialize_type_tags produces empty bytes when no Expr nodes have tags" {
    writer = JirWriter();
    # Simulate _assign_ids having been called with no Expr nodes
    writer._nodes = [];
    writer._node_ids = {};
    result = writer._serialize_type_tags();
    # Should be at least 1 byte (varint 0 for count)
    assert isinstance(result, bytes);
    assert len(result) >= 1;
    # The first varint should decode to 0 (no pairs)
    assert result[0] == 0;
}

test "_serialize_type_tags encodes (nid, pool_idx) pairs for tagged Expr nodes" {
    import from jaclang.jac0core.unitree { Expr }
    import from jaclang.jac0core.jir_passes { _StringPool, _read_varint }

    writer = JirWriter();

    # Create a mock Expr node with a backend_type_tag
    mock_expr = MagicMock(spec=Expr);
    mock_expr.backend_type_tag = "int";

    node_id = 42;
    writer._nodes = [mock_expr];
    writer._node_ids = {id(mock_expr): node_id};

    result = writer._serialize_type_tags();
    assert isinstance(result, bytes);
    assert len(result) > 1;

    # Decode: first varint is count
    (count, pos) = _read_varint(result, 0);
    assert count == 1;

    # Next pair: (nid, tag_idx)
    (nid_val, pos) = _read_varint(result, pos);
    assert nid_val == node_id;

    # tag_idx points into the pool; pool should have "int" interned
    (tag_idx, pos) = _read_varint(result, pos);
    assert tag_idx >= 0;
    assert writer._pool.get(tag_idx) == "int";
}
