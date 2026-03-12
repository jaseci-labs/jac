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
glob SENTINEL_NONE: int = 0xFFFFFE,
     EXTERNAL_REF: int = 0xFFFFFF;

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
obj _StringPool {
    has _strings: list[str] by postinit,
        _index: dict[str, int] by postinit;

    def postinit -> None {
        self._strings = [];
        self._index = {};
    }

    def intern(s: str) -> int {
        idx = self._index.get(s);
        if idx is not None {
            return idx;
        }
        idx = len(self._strings);
        self._strings.append(s);
        self._index[s] = idx;
        return idx;
    }

    def get(idx: int) -> str {
        return self._strings[idx];
    }

    def __len__ -> int {
        return len(self._strings);
    }

    def serialize -> bytes {
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
obj JirWriter {
    has _pool: _StringPool by postinit,
        _node_ids: dict[int, int] by postinit,
        _nodes: list[object] by postinit,
        _buf: bytearray by postinit,
        _parent_scope_links: list[tuple[int, int]] by postinit,
        _name_of_links: list[tuple[int, int]] by postinit,
        _overload_entries: list[tuple[int, str, list[int]]] by postinit,
        _inherited_scope_entries: list[tuple[int, int, bool, list[str]]] by postinit;

    def postinit -> None {
        self._pool = _StringPool();
        self._node_ids = {};
        self._nodes = [];
        self._buf = bytearray();
        self._parent_scope_links = [];
        self._name_of_links = [];
        self._overload_entries = [];
        self._inherited_scope_entries = [];
    }

    def write_module(
        module: Module, sections: (dict[int, bytes] | None) = None
    ) -> bytes;

    def _assign_ids(ir_node: UniNode) -> int;
    def _get_node_id(ir_node: (UniNode | None)) -> int;
    def _write_node(buf: bytearray, ir_node: UniNode) -> None;
    def _write_symbol(buf: bytearray, sym: Symbol) -> None;
    def _write_field(
        buf: bytearray, ir_node: UniNode, field_name: str, kind: int
    ) -> None;

    def _write_link_table(buf: bytearray) -> None;
    def _count_symbols(module: Module) -> int;
}

# =============================================================================
# JirReader
# =============================================================================
"""Deserialize JIR binary back to a Module tree."""
obj JirReader {
    has _skip_loc: bool = True,
        _source_path: str = "",
        _pool: (_StringPool | None) = None,
        _nodes: list[object] by postinit,
        _class_map: (dict[str, type] | None) = None,
        _uni_types: (tuple[type, ...] | None) = None,
        _enum_cache: (dict[str, dict[str, object]] | None) = None,
        bytecode_section: (bytes | None) = None,
        mtir_section: (bytes | None) = None,
        llvm_ir_section: (bytes | None) = None,
        interop_section: (bytes | None) = None;

    def postinit -> None {
        self._nodes = [];
    }

    def read_module(data: bytes) -> (Module | None);
    def _read_trailing_sections(data: bytes) -> dict[int, bytes];
    def _wire_source(module: Module) -> None;
    def _fix_param_kinds -> None;
    def _init_caches -> None;
    def _resolve_node(node_id: int) -> (UniNode | None);
    def _read_node(data: (bytes | memoryview), pos: int, idx: int) -> int;
    def _read_scope_overlay(
        data: (bytes | memoryview), pos: int, scope_node: UniScopeNode
    ) -> int;

    def _read_symbol(data: (bytes | memoryview), pos: int) -> tuple;
    def _read_cfg_overlay(
        data: (bytes | memoryview), pos: int, cfg_node: UniCFGNode
    ) -> int;

    def _read_name_atom_overlay(
        data: (bytes | memoryview), pos: int, na_node: NameAtom
    ) -> int;

    def _read_link_table(data: (bytes | memoryview), pos: int) -> int;
}
