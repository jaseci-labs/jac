import struct;
import sys;
import zlib;

import from jaclang.jac0core.jir_registry {
    FieldKind,
    IDX_TO_SPEC,
    NAME_TO_IDX,
    get_class_mapping
}
import type from jaclang.jac0core.unitree {
    Module,
    UniNode,
    UniScopeNode,
    UniCFGNode,
    NameAtom,
    Symbol,
    Source,
    Token
}

glob SENTINEL_NONE: int = 0xFFFFFE,
     EXTERNAL_REF: int = 0xFFFFFF;

def _write_varint(buf: bytearray, value: int) {
    while value >= 0x80 {
        buf.append((value & 0x7F) | 0x80);
        value >>= 7;
    }
    buf.append(value & 0x7F);
}

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

obj _StringPool {
    has _strings: list[str] postinit,
        _index: dict[str, int] postinit;

    def postinit {
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

obj JirWriter {
    has _pool: _StringPool postinit,
        _node_ids: dict[int, int] postinit,
        _nodes: list[object] postinit,
        _buf: bytearray postinit,
        _parent_scope_links: list[tuple[int, int]] postinit,
        _name_of_links: list[tuple[int, int]] postinit,
        _overload_entries: list[tuple[int, str, list[int]]] postinit,
        _inherited_scope_entries: list[tuple[int, int, bool, list[str]]] postinit;

    def postinit {
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

    # Returns True for top-level module children whose subtree is deferred into
    # its own JIR chunk (lazy tier): class (Archetype) and function (Ability)
    # declarations, which dominate a stub's node count.
    def _is_lazy_decl(node: UniNode) -> bool;
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

obj JirReader {
    has _skip_loc: bool = True,
        _source_path: str = "",
        _module_source: (Source | None) = None,
        _pool: (_StringPool | None) = None,
        hydrated_node_count: int = 0,
        _lazy: bool = False,
        _eager_loading: bool = False,
        _bodies: bytes = b"",
        _nodes: list[object] postinit,
        _chunk_meta: list postinit,
        _chunk_of: list postinit,
        _hydrated_chunks: set postinit,
        _link_buckets: dict postinit,
        _applied_links: set postinit,
        _class_map: (dict[str, type] | None) = None,
        _uni_types: (tuple[type, ...] | None) = None,
        _enum_cache: (dict[str, dict[str, object]] | None) = None;

    def postinit {
        self._nodes = [];
        self._chunk_meta = [];
        self._chunk_of = [];
        self._hydrated_chunks = set();
        self._link_buckets = {};
        self._applied_links = set();
    }

    # Materialize one lazy declaration chunk (idempotent): read its subtree into
    # the pre-allocated slots (reusing any cold-shell placeholders in place) and
    # apply the links bucketed to it.
    def hydrate_chunk(cidx: int) -> None;
    def _apply_one_link(kind: int, a: int, b: int) -> None;
    def _read_link_table_lazy(data: (bytes | memoryview), pos: int) -> int;

    def read_module(data: bytes) -> (Module | None);
    # v19 stub layout: eager tier (module shell + scopes + non-decl top-level) is
    # in the compressed payload; per-declaration subtrees ride in SEC_DECL_BODIES,
    # indexed by SEC_DECL_INDEX. Phase 1 hydrates every chunk immediately (global
    # id-order read => byte-for-byte semantic parity with the legacy layout).
    def _read_module_chunked(data: bytes, ir_node_count: int) -> (Module | None);
    def _ensure_module_source -> Source;
    def _fix_one_func_signature(sig: object) -> None;
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
