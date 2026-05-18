"""JIR round-trip tests.

Verifies that backend_type_tag values set by UniTreeEnrichPass are
serialized into the SEC_TYPE_TAGS section during JIR write and correctly
restored to Expr nodes during JIR read. Also verifies that AST invariants
required by downstream passes (e.g. name_spec on AstSymbolStubNode) survive
JIR deserialization.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.jir_passes { JirWriter, JirReader }
import from jaclang.jac0core.jir { SEC_TYPE_TAGS }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.unitree {
    MultiString,
    FString,
    ListVal,
    SetVal,
    DictVal,
    TupleVal,
    ListCompr,
    SetCompr,
    DictCompr,
    IndexSlice
}
import from unittest.mock { MagicMock }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     JIR_FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "fixtures");

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

# ── AstSymbolStubNode name_spec preservation ─────────────────────────────────
# Bug: JirReader._read_node did not fabricate name_spec for AstSymbolStubNode
# subclasses (MultiString, FString, ListVal, SetVal, DictVal, TupleVal,
# {List,Set,Dict,Filter,Assign}Compr, IndexSlice, EdgeOpRef, JsxElement).
#
# In the normal compile path, each stub class's postinit calls
# AstSymbolStubNode._init_stub() which fabricates a stub Name via
# Name.gen_stub_from_node and wires it as `self.name_spec`. JIR serialization
# does not persist this fabricated Name (the writer only emits declared
# fields), and the reader's existing name_spec fallbacks (checking 'name'/
# 'name_ref' fields and scanning kids for a NameAtom) all miss for these
# stub-symbol nodes because their declared field names don't match and their
# child trees don't contain a top-level NameAtom.
#
# Without the fix, DeclImplMatchPass._resolve_symbols_in_subtree (run by
# TypeEvaluator._reattach_impl_modules after a JIR cache hit) walks all
# AtomTrailer nodes, calls `chain[0].sym` on the head of each chain, and the
# `.sym` getter (`return self.name_spec.sym`) raises
#   AttributeError: 'MultiString' object has no attribute 'name_spec'
# whenever a literal sits at the head of an attribute chain (e.g. "x".upper()).
# This corrupts type checking of any cached module containing such patterns,
# which is why several files in the repo's .jacignore couldn't run `jac check`.
test "name_spec restored on AstSymbolStubNode after JIR round-trip" {
    fixture = os.path.join(JIR_FIXTURES, "jir_stub_name_spec.jac");
    program = JacProgram();
    mod = program.compile(fixture, no_cgen=True);
    assert mod is not None;

    stub_classes = (
        MultiString,
        FString,
        ListVal,
        SetVal,
        DictVal,
        TupleVal,
        ListCompr,
        SetCompr,
        DictCompr,
        IndexSlice
    );

    # Sanity check: postinit-driven fresh AST has name_spec on every stub node.
    fresh_counts: dict = {};
    for cls in stub_classes {
        nodes = mod.get_all_sub_nodes(cls);
        fresh_counts[cls.__name__] = len(nodes);
        assert len(nodes) > 0 , (
            f"Fixture should contain at least one {cls.__name__}; "
            f"adjust jir_stub_name_spec.jac"
        );
        for n in nodes {
            assert n.name_spec is not None , (
                f"Fresh {cls.__name__} has no name_spec — postinit chain "
                f"is broken (this is not a JIR bug, fixture or class is misdefined)"
            );
        }
    }

    # Round-trip the module through JIR.
    writer = JirWriter();
    data = writer.write_module(mod);
    reader = JirReader();
    restored = reader.read_module(data);
    assert restored is not None , "JIR round-trip returned None";

    # name_spec must survive deserialization for every stub-symbol node.
    for cls in stub_classes {
        nodes = restored.get_all_sub_nodes(cls);
        assert len(nodes) == fresh_counts[cls.__name__] , (
            f"JIR round-trip lost {cls.__name__} nodes: "
            f"fresh={fresh_counts[cls.__name__]} restored={len(nodes)}"
        );
        for n in nodes {
            assert n.name_spec is not None , (
                f"JIR deserializer dropped name_spec on {cls.__name__}. "
                f"JirReader._read_node must fabricate a stub Name for "
                f"AstSymbolStubNode subclasses the same way "
                f"AstSymbolStubNode._init_stub does — otherwise "
                f"DeclImplMatchPass._resolve_symbols_in_subtree crashes with "
                f"AttributeError on chain[0].sym after a JIR cache hit."
            );
            # `.sym` reads self.name_spec.sym — must not raise.
            _ = n.sym;
        }
    }
}
