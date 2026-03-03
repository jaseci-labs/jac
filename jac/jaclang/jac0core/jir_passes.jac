"""JIR (Jac IR) serialization: writer and reader for the unified IR.

The writer performs a post-order walk of the unitree, assigning each node
a sequential ID. Each node's constructor fields, scope overlay, CFG overlay,
and symbol bindings are serialized into a compact binary stream.

The reader reconstructs the tree by reading the node stream, rebuilding
kid/parent, scope chains, symbol tables, and CFG edges.
"""
import struct;
import sys;
import zlib;
import from typing { Any, TYPE_CHECKING }

import from jaclang.jac0core.jir_registry {
    FieldKind,
    IDX_TO_SPEC,
    NAME_TO_IDX,
    NodeSpec,
    get_class_mapping
}

with entry {
    if TYPE_CHECKING {
        import from jaclang.jac0core.unitree {
            Module,
            UniNode,
            UniScopeNode,
            UniCFGNode,
            NameAtom,
            Symbol,
            Source,
            Token
        }
    }
}

# --- Constants ---
"""Sentinel value for None node references."""
glob SENTINEL_NONE: int = 0xFFFFFE;

"""Sentinel for external references (builtins parent_scope)."""
glob EXTERNAL_REF: int = 0xFFFFFF;

# --- LEB128 varint (module-private, inlined for performance) ---
"""Encode an unsigned integer as LEB128 varint, appending to buf."""
def _write_varint(buf: bytearray, value: int) -> None {
    while value >= 0x80 {
        buf.append((value & 0x7F) | 0x80);
        value >>= 7;
    }
    buf.append(value & 0x7F);
}

"""Decode an unsigned LEB128 varint. Returns (value, new_pos)."""
def _read_varint(data: (bytes | memoryview), pos: int) -> tuple[int, int] {
    result = 0;
    shift = 0;
    byte = data[pos];
    while (byte & 0x80) != 0 {
        result |= (byte & 0x7F) << shift;
        shift += 7;
        pos += 1;
        byte = data[pos];
    }
    result |= (byte & 0x7F) << shift;
    pos += 1;
    return (result, pos);
}

# --- String Pool (private, used only by writer/reader) ---
"""Deduplicated string table for serialization."""
class _StringPool {
    def init(self: _StringPool) -> None {
        self._strings: list[str] = [];
        self._index: dict[str, int] = {};
    }

    def intern(self: _StringPool, s: str) -> int {
        idx = self._index.get(s);
        if idx is not None {
            return idx;
        }
        idx = len(self._strings);
        self._strings.append(s);
        self._index[s] = idx;
        return idx;
    }

    def get(self: _StringPool, idx: int) -> str {
        return self._strings[idx];
    }

    def __len__(self: _StringPool) -> int {
        return len(self._strings);
    }

    def serialize(self: _StringPool) -> bytes {
        buf = bytearray();
        _write_varint(buf, len(self._strings));
        for s in self._strings {
            encoded = s.encode('utf-8');
            _write_varint(buf, len(encoded));
            buf.extend(encoded);
        }
        return bytes(buf);
    }
}

"""Deserialize a string pool from data at pos. Returns (pool, new_pos)."""
def _deserialize_string_pool(
    data: (bytes | memoryview), pos: int
) -> tuple[_StringPool, int] {
    pool = _StringPool();
    (count, pos) = _read_varint(data, pos);
    for _ in range(count) {
        (length, pos) = _read_varint(data, pos);
        s = bytes(data[pos:pos + length]).decode('utf-8');
        pool.intern(s);
        pos += length;
    }
    return (pool, pos);
}

# =============================================================================
# JirWriter
# =============================================================================
"""Serialize a Module tree to JIR binary format."""
class JirWriter {
    """Initialize the writer with empty state."""
    def init(self: JirWriter) -> None;

    """Serialize a Module to JIR bytes.

    If sections is provided, TLV section data is appended after the compressed
    AST payload (bytecode, MTIR, LLVM IR, interop).
    """
    def write_module(
        self: JirWriter, module: Module, sections: (dict[int, bytes] | None) = None
    ) -> bytes;

    """Post-order walk, assigning sequential IDs to nodes."""
    def _assign_ids(self: JirWriter, ir_node: UniNode) -> int;

    """Get the ID for a node, or SENTINEL_NONE if None."""
    def _get_node_id(self: JirWriter, ir_node: (UniNode | None)) -> int;

    """Serialize a single node to the buffer."""
    def _write_node(self: JirWriter, buf: bytearray, ir_node: UniNode) -> None;

    """Serialize a Symbol inline."""
    def _write_symbol(self: JirWriter, buf: bytearray, sym: Symbol) -> None;

    """Serialize a single constructor field by kind."""
    def _write_field(
        self: JirWriter, buf: bytearray, ir_node: UniNode, field_name: str, kind: int
    ) -> None;

    """Serialize the link table."""
    def _write_link_table(self: JirWriter, buf: bytearray) -> None;

    """Count total symbols in the module."""
    def _count_symbols(self: JirWriter, module: Module) -> int;
}

# =============================================================================
# JirReader
# =============================================================================
"""Deserialize JIR binary back to a Module tree."""
class JirReader {
    """Initialize the reader."""
    def init(self: JirReader, skip_loc: bool = True, source_path: str = "") -> None;

    """Sections decoded from the trailing TLV block (populated by read_module)."""
    has bytecode_section: (bytes | None) = None,
        mtir_section: (bytes | None) = None,
        llvm_ir_section: (bytes | None) = None,
        interop_section: (bytes | None) = None;

    """Deserialize bytes into a Module tree. Returns None on failure."""
    def read_module(self: JirReader, data: bytes) -> (Module | None);

    """Scan data for trailing TLV sections after the compressed payload."""
    def _read_trailing_sections(self: JirReader, data: bytes) -> dict[int, bytes];

    """Create a Source node and set orig_src on all Token nodes."""
    def _wire_source(self: JirReader, module: Module) -> None;

    """Derive param_kind for ParamVar nodes from FuncSignature position."""
    def _fix_param_kinds(self: JirReader) -> None;

    """Pre-cache type checks and enum mappings for fast deserialization."""
    def _init_caches(self: JirReader) -> None;

    """Resolve a node ID to a node, handling sentinels."""
    def _resolve_node(self: JirReader, node_id: int) -> (UniNode | None);

    """Deserialize a single node. Returns new pos."""
    def _read_node(
        self: JirReader, data: (bytes | memoryview), pos: int, idx: int
    ) -> int;

    """Read scope overlay data into a UniScopeNode."""
    def _read_scope_overlay(
        self: JirReader, data: (bytes | memoryview), pos: int, scope_node: UniScopeNode
    ) -> int;

    """Read a Symbol from the stream. Returns (symbol_or_none, new_pos)."""
    def _read_symbol(self: JirReader, data: (bytes | memoryview), pos: int) -> tuple;

    """Read CFG overlay data into a UniCFGNode."""
    def _read_cfg_overlay(
        self: JirReader, data: (bytes | memoryview), pos: int, cfg_node: UniCFGNode
    ) -> int;

    """Read NameAtom overlay data."""
    def _read_name_atom_overlay(
        self: JirReader, data: (bytes | memoryview), pos: int, na_node: NameAtom
    ) -> int;

    """Read the link table and wire up deferred references."""
    def _read_link_table(self: JirReader, data: (bytes | memoryview), pos: int) -> int;
}
