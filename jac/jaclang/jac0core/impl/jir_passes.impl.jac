import struct;
import sys;
import zlib;

impl JirWriter._is_lazy_decl(node: UniNode) -> bool {
    import from jaclang.jac0core.unitree { Archetype, Ability }
    return isinstance(node, (Archetype, Ability));
}

impl JirWriter.write_module(
    module: Module, sections: (dict[int, bytes] | None) = None
) -> bytes {
    import from jaclang.jac0core.jir {
        HEADER_FMT, HEADER_SIZE, MAGIC, FORMAT_VERSION, write_sections,
        SEC_DECL_INDEX, SEC_DECL_BODIES, SEC_DECL_ENTRIES
    }
    import from importlib.metadata { version as pkg_version }

    self._assign_ids(module);
    node_total = len(self._nodes);

    # Partition top-level declarations into their own lazy chunks for stubs.
    # Every top-level child's subtree owns a contiguous id range (post-order
    # `_assign_ids`), so a chunk is just an [lo, hi] id span; the Module node is
    # the final id and always lands in the eager tier.
    chunked = module.stub_only;
    is_lazy_id = [False] * node_total;
    chunks: list[tuple[int, int, int]] = [];
    if chunked {
        prev = -1;
        for kid in module.kid {
            hi = self._node_ids[id(kid)];
            lo = prev + 1;
            prev = hi;
            if self._is_lazy_decl(kid) {
                name_id = self._pool.intern(getattr(kid, 'sym_name', '') or '');
                chunks.append((name_id, lo, hi));
                for i in range(lo, hi + 1) {
                    is_lazy_id[i] = True;
                }
            }
        }
    }

    # Eager node stream (everything not deferred), in ascending id order.
    ir_buf = bytearray();
    for i in range(node_total) {
        if not is_lazy_id[i] {
            self._write_node(ir_buf, self._nodes[i]);
        }
    }

    # Lazy declaration bodies, each an independently zlib-compressed subtree.
    bodies = bytearray();
    index_buf = bytearray();
    if chunked {
        _write_varint(index_buf, len(chunks));
        for (name_id, lo, hi) in chunks {
            cbuf = bytearray();
            for i in range(lo, hi + 1) {
                self._write_node(cbuf, self._nodes[i]);
            }
            comp = zlib.compress(bytes(cbuf), 6);
            offset = len(bodies);
            bodies.extend(comp);
            _write_varint(index_buf, name_id);
            _write_varint(index_buf, lo);
            _write_varint(index_buf, hi);
            _write_varint(index_buf, offset);
            _write_varint(index_buf, len(comp));
        }
    }

    # Links (parent_scope / name_of) are collected as a side effect of writing
    # nodes, so the global link table is finalized only now, after both the
    # eager stream and every chunk have been serialized.
    link_buf = bytearray();
    self._write_link_table(link_buf);

    pool_bytes = self._pool.serialize();

    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }

    source_hash = 0;
    if module?.source and module.source is not None {
        src_str = module.source.code;
        if src_str {
            source_hash = zlib.crc32(src_str.encode()) & 0xFFFFFFFF;
        }
    }

    sym_count = self._count_symbols(module);

    flags = 0;
    if module.stub_only {
        flags |= 1;
    }

    header = struct.pack(
        HEADER_FMT,
        MAGIC,
        FORMAT_VERSION,
        (sys.version_info.major << 8) | sys.version_info.minor,
        zlib.crc32(jac_ver.encode()) & 0xFFFFFFFF,
        source_hash,
        node_total,
        sym_count,
        len(pool_bytes),
        flags
    );

    # The eager payload (string pool + eager nodes + global link table) is a
    # single zlib stream; the reader ignores trailing bytes, so the JIRX
    # sections (which carry the decl index/bodies) follow it verbatim.
    payload = pool_bytes + bytes(ir_buf) + bytes(link_buf);
    compressed = zlib.compress(payload, 6);
    if sections is None {
        sections = {};
    }
    if chunked {
        sections[SEC_DECL_INDEX] = bytes(index_buf);
        sections[SEC_DECL_BODIES] = bytes(bodies);
        # Entry points: for each chunk, the node ids referenced from outside it
        # (its root, plus the module-scope symbol name atoms it contains) with
        # their class index, so the lazy reader can pre-create typed cold-shell
        # placeholders whose isinstance/type() are correct before hydration.
        id_chunk: dict[int, int] = {};
        entry_sets: list[set] = [];
        for (ci, (name_id, lo, hi)) in enumerate(chunks) {
            entry_sets.append({hi});
            for i in range(lo, hi + 1) {
                id_chunk[i] = ci;
            }
        }
        def _collect_entry(na: object) -> None {
            nid = self._node_ids.get(id(na));
            if nid is not None and nid in id_chunk {
                entry_sets[id_chunk[nid]].add(nid);
            }
        }
        for sym in module.names_in_scope.values() {
            for na in (list(sym.defn) + list(sym.uses)) {
                _collect_entry(na);
            }
        }
        for sym_list in module.names_in_scope_overload.values() {
            for sym in sym_list {
                for na in (list(sym.defn) + list(sym.uses)) {
                    _collect_entry(na);
                }
            }
        }
        entries_buf = bytearray();
        _write_varint(entries_buf, len(chunks));
        for ci in range(len(chunks)) {
            ids = sorted(entry_sets[ci]);
            _write_varint(entries_buf, len(ids));
            for gid in ids {
                cname = type(self._nodes[gid]).__name__;
                _write_varint(entries_buf, gid);
                _write_varint(entries_buf, NAME_TO_IDX.get(cname, 0));
            }
        }
        sections[SEC_DECL_ENTRIES] = bytes(entries_buf);
    }
    section_bytes = write_sections(sections);
    return header + compressed + section_bytes;
}

impl JirWriter._assign_ids(ir_node: UniNode) -> int {
    for kid in ir_node.kid {
        self._assign_ids(kid);
    }
    nid = len(self._nodes);
    self._node_ids[id(ir_node)] = nid;
    self._nodes.append(ir_node);
    return nid;
}

impl JirWriter._get_node_id(ir_node: (UniNode | None)) -> int {
    if ir_node is None {
        return SENTINEL_NONE;
    }
    nid = self._node_ids.get(id(ir_node));
    if nid is not None {
        return nid;
    }
    return EXTERNAL_REF;
}

impl JirWriter._write_node(buf: bytearray, ir_node: UniNode) -> None {
    import from jaclang.jac0core.unitree { UniScopeNode, UniCFGNode, NameAtom, Symbol }
    import from jaclang.jac0core.unitree { ContextAwareNode }
    import from jaclang.jac0core.constant { CodeContext }

    cls_name = type(ir_node).__name__;
    type_idx = NAME_TO_IDX.get(cls_name);
    if type_idx is None {
        raise ValueError(f"Unknown node type: {cls_name}");
    }

    spec = IDX_TO_SPEC[type_idx];

    is_scope = isinstance(ir_node, UniScopeNode);
    is_cfg = isinstance(ir_node, UniCFGNode);
    is_context_aware = isinstance(ir_node, ContextAwareNode);

    _write_varint(buf, type_idx);

    overlay_flags = 0;
    if is_scope {
        overlay_flags |= 1;
    }
    if is_cfg {
        overlay_flags |= 2;
    }
    if isinstance(ir_node, NameAtom) {
        overlay_flags |= 4;
    }
    if is_context_aware {
        overlay_flags |= 8;
    }
    buf.append(overlay_flags);

    _write_varint(buf, len(list(ir_node.kid)));
    for kid in ir_node.kid {
        _write_varint(buf, self._get_node_id(kid));
    }

    for field_desc in spec.fields {
        self._write_field(buf, ir_node, field_desc.name, field_desc.kind);
    }

    if is_scope {
        _write_varint(buf, self._pool.intern(ir_node.scope_name));

        parent_scope_id = self._get_node_id(ir_node.parent_scope);
        self._parent_scope_links.append((self._node_ids[id(ir_node)], parent_scope_id));

        _write_varint(buf, len(ir_node.names_in_scope));
        for (sym_name, sym) in ir_node.names_in_scope.items() {
            _write_varint(buf, self._pool.intern(sym_name));
            self._write_symbol(buf, sym);
        }

        overload_map = ir_node.names_in_scope_overload;
        non_empty = {
            k: v
            for (k, v) in overload_map.items()
            if v
        };
        _write_varint(buf, len(non_empty));
        for (sym_name, sym_list) in non_empty.items() {
            _write_varint(buf, self._pool.intern(sym_name));
            _write_varint(buf, len(sym_list));
            for sym in sym_list {
                self._write_symbol(buf, sym);
            }
        }

        inherited = getattr(ir_node, 'inherited_scope', []);
        _write_varint(buf, len(inherited));
        for inh in inherited {
            src_id = self._get_node_id(inh.base_symbol_table);
            _write_varint(buf, src_id);
            buf.append(1 if inh.load_all_symbols else 0);
            _write_varint(buf, len(inh.symbols));
            for s in inh.symbols {
                _write_varint(buf, self._pool.intern(s));
            }
        }
    }

    if is_cfg {
        bb_in = ir_node.bb_in;
        bb_out = ir_node.bb_out;
        affected = ir_node.affected_symbols;

        _write_varint(buf, len(bb_in));
        for bb_edge in bb_in {
            _write_varint(buf, self._get_node_id(bb_edge));
        }
        _write_varint(buf, len(bb_out));
        for bb_edge in bb_out {
            _write_varint(buf, self._get_node_id(bb_edge));
        }
        _write_varint(buf, len(affected));
        for s in affected {
            _write_varint(buf, self._pool.intern(s));
        }
    }

    if isinstance(ir_node, NameAtom) {
        sym = ir_node._sym;
        if sym is not None {
            buf.append(1);
            _write_varint(buf, len(sym.defn));
            for defn_item in sym.defn {
                _write_varint(buf, self._get_node_id(defn_item));
            }
        } else {
            buf.append(0);
        }

        name_of = ir_node.name_of;
        if name_of is not None and name_of is not ir_node {
            na_id = self._node_ids[id(ir_node)];
            self._name_of_links.append((na_id, self._get_node_id(name_of)));
        }

        sym_name = ir_node._sym_name;
        _write_varint(buf, self._pool.intern(sym_name));
        sym_cat = ir_node._sym_category;
        if sym_cat is not None and hasattr(sym_cat, 'value') {
            _write_varint(buf, self._pool.intern(str(sym_cat.value)));
        } else {
            _write_varint(buf, self._pool.intern(''));
        }
    }

    if is_context_aware {
        ctx = ir_node.code_context;
        if ctx == CodeContext.CLIENT {
            buf.append(1);
        } elif ctx == CodeContext.NATIVE {
            buf.append(2);
        } else {
            buf.append(0);
        }
    }
}

impl JirWriter._write_symbol(buf: bytearray, sym: Symbol) -> None {
    _write_varint(buf, len(sym.defn));
    for defn in sym.defn {
        _write_varint(buf, self._get_node_id(defn));
    }

    _write_varint(buf, len(sym.uses));
    for use in sym.uses {
        _write_varint(buf, self._get_node_id(use));
    }

    access_str = sym.access?.value or str(sym.access);
    _write_varint(buf, self._pool.intern(access_str));

    buf.append(1 if sym.imported else 0);

    try {
        buf.append(int(sym.ownership.value) & 0xFF);
    } except Exception {
        buf.append(0);
    }
    _fact_flags = 0;
    if getattr(sym, 'param_rebound', False) {
        _fact_flags |= 1;
    }
    if getattr(sym, 'na_escapes', False) {
        _fact_flags |= 2;
    }
    if getattr(sym, 'na_stack_ok', False) {
        _fact_flags |= 4;
    }
    buf.append(_fact_flags);
}

impl JirWriter._write_field(
    buf: bytearray, ir_node: UniNode, field_name: str, kind: int
) -> None {
    val = getattr(ir_node, field_name, None);

    if val is None and kind == FieldKind.INT {
        _TOKEN_ALIASES = {
            'line': 'line_no',
            'col_start': 'c_start',
            'col_end': 'c_end'
        };
        alias = _TOKEN_ALIASES.get(field_name);
        if alias is not None {
            val = getattr(ir_node, alias, None);
        }
    }

    if kind == FieldKind.STRING {
        s = val if val is not None else '';
        _write_varint(buf, self._pool.intern(str(s)));
    } elif kind == FieldKind.INT {
        _write_varint(buf, val if val is not None else 0);
    } elif kind == FieldKind.BOOL {
        buf.append(1 if val else 0);
    } elif kind == FieldKind.ENUM {
        if val is not None and hasattr(val, 'value') {
            enum_val = val.value;
            if isinstance(enum_val, str) {
                _write_varint(buf, self._pool.intern(enum_val));
            } else {
                _write_varint(buf, self._pool.intern(str(enum_val)));
            }
        } else {
            _write_varint(buf, self._pool.intern(str(val) if val is not None else ''));
        }
    } elif kind == FieldKind.NODE_REF {
        _write_varint(buf, self._get_node_id(val));
    } elif kind == FieldKind.NODE_LIST {
        if val is None {
            _write_varint(buf, 0);
        } elif isinstance(val, (list, tuple)) {
            items = list(val);
            _write_varint(buf, len(items));
            for item in items {
                _write_varint(buf, self._get_node_id(item));
            }
        } else {
            _write_varint(buf, 1);
            _write_varint(buf, self._get_node_id(val));
        }
    } elif kind == FieldKind.OPT_NODE_LIST {
        if val is None {
            buf.append(0);
        } else {
            buf.append(1);
            if isinstance(val, (list, tuple)) {
                items = list(val);
                _write_varint(buf, len(items));
                for item in items {
                    _write_varint(buf, self._get_node_id(item));
                }
            } else {
                _write_varint(buf, 1);
                _write_varint(buf, self._get_node_id(val));
            }
        }
    } elif kind == FieldKind.OPT_NODE_REF {
        if val is None {
            buf.append(0);
        } else {
            buf.append(1);
            _write_varint(buf, self._get_node_id(val));
        }
    } elif kind == FieldKind.OPT_STRING {
        if val is None {
            buf.append(0);
        } else {
            buf.append(1);
            _write_varint(buf, self._pool.intern(str(val)));
        }
    } elif kind == FieldKind.OPT_BOOL {
        if val is None {
            buf.append(2);
        } else {
            buf.append(1 if val else 0);
        }
    } elif kind == FieldKind.OPT_INT {
        if val is None {
            buf.append(0);
        } else {
            buf.append(1);
            _write_varint(buf, int(val));
        }
    }
}

impl JirWriter._write_link_table(buf: bytearray) -> None {
    _write_varint(buf, len(self._parent_scope_links));
    for (scope_id, parent_id) in self._parent_scope_links {
        _write_varint(buf, scope_id);
        _write_varint(buf, parent_id);
    }

    _write_varint(buf, len(self._name_of_links));
    for (na_id, name_of_id) in self._name_of_links {
        _write_varint(buf, na_id);
        _write_varint(buf, name_of_id);
    }
}

impl JirWriter._count_symbols(module: Module) -> int {
    import from jaclang.jac0core.unitree { UniScopeNode }
    count = 0;
    for ir_item in self._nodes {
        if isinstance(ir_item, UniScopeNode) {
            count += len(ir_item.names_in_scope);
        }
    }
    return count;
}

impl JirReader.read_module(data: bytes) -> (Module | None) {
    import from jaclang.jac0core.jir { HEADER_FMT, HEADER_SIZE, MAGIC, FORMAT_VERSION }
    try {
        import from importlib.metadata { version as _pkg_version }
        _current_jac_hash = zlib.crc32(_pkg_version('jaclang').encode()) & 0xFFFFFFFF;
    } except Exception {
        _current_jac_hash = 0;
    }

    if len(data) < HEADER_SIZE {
        return None;
    }

    try {
        (
            magic,
            fmt_ver,
            py_ver,
            jac_hash,
            src_hash,
            ir_node_count,
            sym_count,
            sp_size,
            flags
        ) = struct.unpack(HEADER_FMT, data[:HEADER_SIZE]);
    } except struct.error {
        return None;
    }

    if magic != MAGIC or fmt_ver != FORMAT_VERSION {
        return None;
    }

    if _current_jac_hash != 0 and jac_hash != _current_jac_hash {
        return None;
    }

    if flags & 1 {
        return self._read_module_chunked(data, ir_node_count);
    }

    try {
        payload_bytes = zlib.decompress(data[HEADER_SIZE:]);
    } except zlib.error {
        return None;
    }
    payload = memoryview(payload_bytes);
    pos = 0;

    (self._pool, pos) = _deserialize_string_pool(payload, pos);

    if not self._class_map {
        self._class_map = get_class_mapping();
        self._init_caches();
    }

    self._nodes = [None] * ir_node_count;
    for i in range(ir_node_count) {
        pos = self._read_node(payload, pos, i);
    }

    pos = self._read_link_table(payload, pos);

    if self._nodes {
        last_node = self._nodes[-1];
        import from jaclang.jac0core.unitree { Module as ModuleCls }
        if isinstance(last_node, ModuleCls) {
            if self._source_path {
                last_node.source = self._ensure_module_source();
            }
            return last_node;
        }
    }
    return None;
}

impl JirReader._read_module_chunked(data: bytes, ir_node_count: int) -> (Module | None) {
    import os;
    import from jaclang.jac0core.jir {
        HEADER_SIZE, SECTIONS_MAGIC, read_sections,
        SEC_DECL_INDEX, SEC_DECL_BODIES, SEC_DECL_ENTRIES
    }
    import from jaclang.jac0core.unitree { Module as ModuleCls }

    try {
        eager_payload_bytes = zlib.decompress(data[HEADER_SIZE:]);
    } except zlib.error {
        return None;
    }
    eager = memoryview(eager_payload_bytes);
    pos = 0;
    (self._pool, pos) = _deserialize_string_pool(eager, pos);

    if not self._class_map {
        self._class_map = get_class_mapping();
        self._init_caches();
    }

    # The decl index / bodies / entries trail the compressed eager payload as
    # JIRX sections; zlib.decompress above ignores them.
    magic: any = SECTIONS_MAGIC;
    sec_pos = data.find(magic, HEADER_SIZE);
    sections: dict[int, bytes] = {};
    if sec_pos >= 0 {
        sections = read_sections(data, sec_pos + len(magic));
    }
    index_bytes = sections.get(SEC_DECL_INDEX);
    bodies = sections.get(SEC_DECL_BODIES) or bytes();
    entries_bytes = sections.get(SEC_DECL_ENTRIES);

    # id -> owning chunk index, and per-chunk (lo, hi, offset, comp_len).
    chunk_of = [-1] * ir_node_count;
    chunk_ranges: list[tuple[int, int, int, int]] = [];
    if index_bytes is not None {
        ipos = 0;
        (count, ipos) = _read_varint(index_bytes, ipos);
        for _ in range(count) {
            (_name_id, ipos) = _read_varint(index_bytes, ipos);
            (lo, ipos) = _read_varint(index_bytes, ipos);
            (hi, ipos) = _read_varint(index_bytes, ipos);
            (off, ipos) = _read_varint(index_bytes, ipos);
            (clen, ipos) = _read_varint(index_bytes, ipos);
            cidx = len(chunk_ranges);
            chunk_ranges.append((lo, hi, off, clen));
            for gid in range(lo, hi + 1) {
                if gid < ir_node_count {
                    chunk_of[gid] = cidx;
                }
            }
        }
    }

    self._nodes = [None] * ir_node_count;
    self._bodies = bytes(bodies);
    self._chunk_meta = chunk_ranges;
    self._chunk_of = chunk_of;

    _truthy: set = {'0', 'false', 'False', 'no', 'off', ''};
    lazy_enabled = os.environ.get('JAC_LAZY_JIR', '1') not in _truthy;
    if entries_bytes is None or not lazy_enabled {
        # Full hydrate: read strictly in global id order so each child (lower
        # post-order id) is materialized before its parent -- byte-for-byte
        # parity with the legacy layout.
        chunk_bufs: dict[int, object] = {};
        chunk_pos: dict[int, int] = {};
        for gid in range(ir_node_count) {
            c = chunk_of[gid];
            if c < 0 {
                pos = self._read_node(eager, pos, gid);
            } else {
                if c not in chunk_bufs {
                    (lo, hi, off, clen) = chunk_ranges[c];
                    chunk_bufs[c] = memoryview(
                        zlib.decompress(bytes(bodies[off:off + clen]))
                    );
                    chunk_pos[c] = 0;
                }
                chunk_pos[c] = self._read_node(chunk_bufs[c], chunk_pos[c], gid);
            }
        }
        pos = self._read_link_table(eager, pos);
        last_node = self._nodes[-1] if self._nodes else None;
        if isinstance(last_node, ModuleCls) {
            if self._source_path {
                last_node.source = self._ensure_module_source();
            }
            return last_node;
        }
        return None;
    }

    # ---- Lazy path: eager tier only; decl bodies hydrate on demand. ----
    self._lazy = True;
    self._eager_loading = True;

    # Pre-create typed cold-shell placeholders for every externally-referenced
    # chunk node (root + module-symbol name atoms). Their class is stored in the
    # entry table so isinstance/type() are correct before hydration; any real
    # attribute access routes through UniNode.__getattr__ -> hydrate_chunk.
    (nchunks, epos) = _read_varint(entries_bytes, 0);
    for cidx in range(nchunks) {
        (n_entries, epos) = _read_varint(entries_bytes, epos);
        for _ in range(n_entries) {
            (gid, epos) = _read_varint(entries_bytes, epos);
            (class_idx, epos) = _read_varint(entries_bytes, epos);
            spec = IDX_TO_SPEC[class_idx];
            cls = self._class_map[spec.class_name];
            shell: any = cls.__new__(cls);
            # Only the control keys: every other attribute is missing, so any
            # real access routes through UniNode.__getattr__ and hydrates.
            shell.__dict__ = {
                '_jir_cold': True,
                '_jir_gid': gid,
                '_jir_chunk': cidx,
                '_jir_loader': self
            };
            self._nodes[gid] = shell;
        }
    }

    # Read the eager nodes (everything not owned by a chunk), in id order.
    for gid in range(ir_node_count) {
        if chunk_of[gid] < 0 {
            pos = self._read_node(eager, pos, gid);
        }
    }

    # The global link table follows the eager stream. Apply links whose ends are
    # already present (eager or cold shells); bucket the rest by owning chunk so
    # they are applied when that chunk hydrates.
    pos = self._read_link_table_lazy(eager, pos);

    self._eager_loading = False;

    last_node = self._nodes[-1] if self._nodes else None;
    if not isinstance(last_node, ModuleCls) {
        return None;
    }
    last_node.__dict__['_jir_loader'] = self;
    if self._source_path {
        last_node.source = self._ensure_module_source();
    }
    # Give the module a real loc (its last kid is a cold decl; this hydrates at
    # most that one chunk) so downstream range queries never hit a missing attr.
    try {
        last_node.loc = self._CodeLocInfo(*last_node.resolve_tok_range());
    } except Exception {
        ;
    }
    return last_node;
}

impl JirReader._read_link_table_lazy(data: (bytes | memoryview), pos: int) -> int {
    _N = len(self._nodes);
    def _owner(nid: int) -> int {
        if 0 <= nid and nid < _N {
            return self._chunk_of[nid];
        }
        return -1;
    }
    def _route(kind: int, a: int, b: int) -> None {
        # Links whose endpoints are both eager can be wired immediately. Any link
        # touching a chunk is bucketed and applied when that chunk hydrates --
        # never eagerly against a cold shell, whose dict is repopulated on
        # hydration (which would drop an eagerly-set field and the applied-guard
        # would then skip the re-apply).
        (ca, cb) = (_owner(a), _owner(b));
        if ca < 0 and cb < 0 {
            self._apply_one_link(kind, a, b);
            return;
        }
        if ca >= 0 {
            self._link_buckets.setdefault(ca, []).append((kind, a, b));
        }
        if cb >= 0 and cb != ca {
            self._link_buckets.setdefault(cb, []).append((kind, a, b));
        }
    }

    (count, pos) = _read_varint(data, pos);
    for _ in range(count) {
        (scope_id, pos) = _read_varint(data, pos);
        (parent_id, pos) = _read_varint(data, pos);
        _route(0, scope_id, parent_id);
    }
    (count, pos) = _read_varint(data, pos);
    for _ in range(count) {
        (na_id, pos) = _read_varint(data, pos);
        (name_of_id, pos) = _read_varint(data, pos);
        _route(1, na_id, name_of_id);
    }
    return pos;
}

impl JirReader._apply_one_link(kind: int, a: int, b: int) -> None {
    import from jaclang.jac0core.unitree { UniScopeNode, NameAtom, AstSymbolNode }
    key = (kind, a, b);
    if key in self._applied_links {
        return;
    }
    node_a = self._resolve_node(a);
    if node_a is None {
        return;
    }
    if kind == 0 {
        if not isinstance(node_a, UniScopeNode) {
            self._applied_links.add(key);
            return;
        }
        if b == EXTERNAL_REF {
            node_a.parent_scope = None;
            self._applied_links.add(key);
            return;
        }
        parent = self._resolve_node(b);
        if parent is not None and isinstance(parent, UniScopeNode) {
            node_a.parent_scope = parent;
            if node_a not in parent.kid_scope {
                parent.kid_scope.append(node_a);
            }
            self._applied_links.add(key);
        }
    } else {
        node_b = self._resolve_node(b);
        if node_b is None {
            return;
        }
        if isinstance(node_a, NameAtom) and isinstance(node_b, AstSymbolNode) {
            node_a.name_of = node_b;
        }
        self._applied_links.add(key);
    }
}

impl JirReader.hydrate_chunk(cidx: int) -> None {
    if cidx in self._hydrated_chunks {
        return;
    }
    self._hydrated_chunks.add(cidx);
    (lo, hi, off, clen) = self._chunk_meta[cidx];
    buf = memoryview(zlib.decompress(bytes(self._bodies[off:off + clen])));
    cpos = 0;
    for gid in range(lo, hi + 1) {
        cpos = self._read_node(buf, cpos, gid);
    }
    for (kind, a, b) in self._link_buckets.get(cidx, []) {
        self._apply_one_link(kind, a, b);
    }
}

impl JirReader._ensure_module_source -> Source {
    import from jaclang.jac0core.unitree { Source }
    if self._module_source is None {
        source_content = '';
        try {
            with open(self._source_path, 'r', encoding='utf-8') as f {
                source_content = f.read();
            }
        } except Exception {
            ;
        }
        self._module_source = Source(source_content, self._source_path);
    }
    return self._module_source;
}

impl JirReader._fix_one_func_signature(sig: object) -> None {
    import from jaclang.jac0core.unitree { FuncSignature, ParamVar, ParamKind }
    if not isinstance(sig, FuncSignature) {
        return;
    }
    for p in (sig.posonly_params or []) {
        if isinstance(p, ParamVar) {
            p.param_kind = ParamKind.POSONLY;
        }
    }
    for p in (sig.params or []) {
        if isinstance(p, ParamVar) {
            p.param_kind = ParamKind.NORMAL;
        }
    }
    if sig.varargs is not None and isinstance(sig.varargs, ParamVar) {
        sig.varargs.param_kind = ParamKind.VARARG;
    }
    for p in (sig.kwonlyargs or []) {
        if isinstance(p, ParamVar) {
            p.param_kind = ParamKind.KWONLY;
        }
    }
    if sig.kwargs is not None and isinstance(sig.kwargs, ParamVar) {
        sig.kwargs.param_kind = ParamKind.KWARG;
    }
}

impl JirReader._init_caches -> None {
    import from jaclang.jac0core.unitree {
        UniScopeNode,
        UniCFGNode,
        NameAtom,
        Expr,
        AstSymbolNode,
        AstSymbolStubNode,
        WalkerStmtOnlyNode,
        Source,
        ParamVar,
        ParamKind,
        FuncCall,
        FuncSignature,
        Token,
        Module,
        Import,
        ModulePath,
        ModuleItem,
        SpecialVarRef,
        ContextAwareNode,
        MultiString,
        FString,
        ListVal,
        SetVal,
        TupleVal,
        DictVal,
        ListCompr,
        DictCompr,
        IndexSlice,
        EdgeOpRef,
        FilterCompr,
        AssignCompr,
        JsxElement
    }
    import from jaclang.jac0core.constant {
        SymbolAccess,
        SymbolType,
        EdgeDir,
        CodeContext,
        ExprCtx,
        OwnershipKind
    }
    import from jaclang.jac0core.codeinfo { CodeLocInfo }

    self._CodeLocInfo = CodeLocInfo;
    self._Expr = Expr;
    self._AstSymbolNode = AstSymbolNode;
    self._AstSymbolStubNode = AstSymbolStubNode;
    self._WalkerStmtOnlyNode = WalkerStmtOnlyNode;
    self._Source = Source;
    self._ParamVar = ParamVar;
    self._FuncCall = FuncCall;
    self._ParamKind_NORMAL = ParamKind.NORMAL;
    self._FuncSignature = FuncSignature;
    self._Token = Token;
    self._Module = Module;
    self._Import = Import;
    self._ModulePath = ModulePath;
    self._ModuleItem = ModuleItem;
    self._SymbolType_UNKNOWN = SymbolType.UNKNOWN;
    self._ExprCtx_LOAD = ExprCtx.LOAD;
    self._SpecialVarRef = SpecialVarRef;
    self._ContextAwareNode = ContextAwareNode;
    self._CodeContext_SERVER = CodeContext.SERVER;

    self._uni_types = (UniScopeNode, UniCFGNode, NameAtom);

    self._stub_sym_types = {
        MultiString: SymbolType.STRING,
        FString: SymbolType.STRING,
        ListVal: SymbolType.SEQUENCE,
        SetVal: SymbolType.SEQUENCE,
        TupleVal: SymbolType.SEQUENCE,
        DictVal: SymbolType.SEQUENCE,
        ListCompr: SymbolType.SEQUENCE,
        DictCompr: SymbolType.SEQUENCE,
        IndexSlice: SymbolType.SEQUENCE,
        EdgeOpRef: SymbolType.SEQUENCE,
        FilterCompr: SymbolType.SEQUENCE,
        AssignCompr: SymbolType.SEQUENCE,
        JsxElement: SymbolType.OBJECT_ARCH
    };

    self._enum_cache = {};
    enum_mapping = {
        'sym_category': SymbolType,
        'sym_type': SymbolType,
        'access': SymbolAccess,
        'edge_dir': EdgeDir,
        'code_context': CodeContext,
        'ownership': OwnershipKind
    };
    for (fname, enum_cls) in enum_mapping.items() {
        cache: dict[str, object] = {};
        for member in enum_cls {
            cache[str(member.value)] = member;
            cache[member.name] = member;
        }
        self._enum_cache[fname] = cache;
    }
}

impl JirReader._resolve_node(node_id: int) -> (UniNode | None) {
    if node_id >= SENTINEL_NONE {
        return None;
    }
    if node_id < len(self._nodes) {
        return self._nodes[node_id];
    }
    return None;
}

impl JirReader._read_node(data: (bytes | memoryview), pos: int, idx: int) -> int {
    pool = self._pool;
    class_map = self._class_map;
    nodes = self._nodes;
    assert pool is not None and class_map is not None;

    _SN = SENTINEL_NONE;

    (type_idx, pos) = _read_varint(data, pos);
    spec = IDX_TO_SPEC[type_idx];

    overlay_flags = data[pos];
    pos += 1;

    (child_count, pos) = _read_varint(data, pos);
    child_ids: list[int] = [];
    for _ in range(child_count) {
        (cid, pos) = _read_varint(data, pos);
        child_ids.append(cid);
    }

    cls = class_map[spec.class_name];
    # Reuse a cold-shell placeholder in place so its object identity (already
    # referenced by module.kid, symbols and name_of) is preserved through
    # hydration; otherwise allocate a fresh node. Wiring set eagerly against the
    # shell (parent, `_sym`) is preserved -- only the `_jir_*` control keys are
    # dropped, and `parent` is restored after the generic reset below.
    reused_parent: any = None;
    existing = nodes[idx] if idx < len(nodes) else None;
    if existing is not None and existing.__dict__.get('_jir_cold') {
        ir_node: any = existing;
        nd = ir_node.__dict__;
        reused_parent = nd.get('parent');
        for _k in ('_jir_cold', '_jir_gid', '_jir_chunk', '_jir_loader', '_jir_hydrating') {
            nd.pop(_k, None);
        }
    } else {
        ir_node: any = cls.__new__(cls);
        nd = ir_node.__dict__;
    }

    enum_cache = self._enum_cache;
    pool_get = pool.get;
    for field_desc in spec.fields {
        kind = field_desc.kind;
        fname = field_desc.name;

        if kind == FieldKind.STRING {
            (si, pos) = _read_varint(data, pos);
            nd[fname] = pool_get(si);
        } elif kind == FieldKind.INT {
            (val, pos) = _read_varint(data, pos);
            nd[fname] = val;
        } elif kind == FieldKind.BOOL {
            nd[fname] = bool(data[pos]);
            pos += 1;
        } elif kind == FieldKind.ENUM {
            (si, pos) = _read_varint(data, pos);
            enum_str = pool_get(si);
            if enum_cache and fname in enum_cache {
                nd[fname] = enum_cache[fname].get(enum_str, enum_str);
            } else {
                nd[fname] = enum_str;
            }
        } elif kind == FieldKind.NODE_REF {
            (nid, pos) = _read_varint(data, pos);
            nd[fname] = nodes[nid] if nid < _SN else None;
        } elif kind == FieldKind.NODE_LIST {
            (count, pos) = _read_varint(data, pos);
            items = [];
            for _ in range(count) {
                (nid, pos) = _read_varint(data, pos);
                if nid < _SN {
                    n = nodes[nid];
                    if n is not None {
                        items.append(n);
                    }
                }
            }
            nd[fname] = items;
        } elif kind == FieldKind.OPT_NODE_LIST {
            flag = data[pos];
            pos += 1;
            if flag == 0 {
                nd[fname] = None;
            } else {
                (count, pos) = _read_varint(data, pos);
                items = [];
                for _ in range(count) {
                    (nid, pos) = _read_varint(data, pos);
                    if nid < _SN {
                        n = nodes[nid];
                        if n is not None {
                            items.append(n);
                        }
                    }
                }
                nd[fname] = items;
            }
        } elif kind == FieldKind.OPT_NODE_REF {
            flag = data[pos];
            pos += 1;
            if flag == 0 {
                nd[fname] = None;
            } else {
                (nid, pos) = _read_varint(data, pos);
                nd[fname] = nodes[nid] if nid < _SN else None;
            }
        } elif kind == FieldKind.OPT_STRING {
            flag = data[pos];
            pos += 1;
            if flag == 0 {
                nd[fname] = None;
            } else {
                (si, pos) = _read_varint(data, pos);
                nd[fname] = pool_get(si);
            }
        } elif kind == FieldKind.OPT_BOOL {
            flag = data[pos];
            pos += 1;
            nd[fname] = None if flag == 2 else bool(flag);
        } elif kind == FieldKind.OPT_INT {
            flag = data[pos];
            pos += 1;
            if flag == 0 {
                nd[fname] = None;
            } else {
                (val, pos) = _read_varint(data, pos);
                nd[fname] = val;
            }
        }
    }

    kids = [];
    for cid in child_ids {
        if cid < _SN {
            child = nodes[cid];
            if child is not None {
                kids.append(child);
                child.parent = ir_node;
            }
        }
    }
    nd['kid'] = kids;
    nd['parent'] = reused_parent;

    nd['_UniNode__sub_node_tab'] = None;
    nd['_in_mod_nodes'] = [];
    nd['_gen'] = None;

    uni_types = self._uni_types;
    assert uni_types is not None;
    (_UniScopeNode, _UniCFGNode, _NameAtom) = uni_types;

    if isinstance(ir_node, self._Expr) {
        nd.setdefault('_type_sym_tab', None);
        nd.setdefault('type', None);
        nd.setdefault('attached_tokens', None);
    }

    if isinstance(ir_node, _NameAtom) {
        nd.setdefault('name_of', ir_node);
        nd.setdefault('_sym', None);
        nd.setdefault('_sym_name', '');
        nd.setdefault('_sym_category', self._SymbolType_UNKNOWN);
        nd.setdefault('_expr_ctx', self._ExprCtx_LOAD);
    }

    if isinstance(ir_node, self._AstSymbolNode) {
        nd.setdefault('semstr', '');
        if 'name_spec' not in nd {
            name_spec = nd.get('name') or nd.get('name_ref');
            if name_spec is not None and isinstance(name_spec, _NameAtom) {
                nd['name_spec'] = name_spec;
            } else {
                for k in kids {
                    if isinstance(k, _NameAtom) {
                        nd['name_spec'] = k;
                        break;
                    }
                }
            }

            if 'name_spec' not in nd and isinstance(ir_node, _NameAtom) {
                nd['name_spec'] = ir_node;
            }
        }
    }

    if isinstance(ir_node, self._ParamVar) {
        nd.setdefault('param_kind', self._ParamKind_NORMAL);
    }

    if isinstance(ir_node, self._FuncCall) {
        nd.setdefault('call_kind', None);
        nd.setdefault('callee_decl', None);
    }

    if isinstance(ir_node, self._WalkerStmtOnlyNode) {
        nd.setdefault('from_walker', False);
    }

    if isinstance(ir_node, self._ContextAwareNode) {
        nd.setdefault('code_context', self._CodeContext_SERVER);
    }

    if isinstance(ir_node, self._SpecialVarRef) {
        nd['orig'] = ir_node;
        try {
            nd['value'] = ir_node.py_resolve_name();
            nd['_sym_name'] = nd['value'];
        } except Exception {
            nd['value'] = nd.get('value', '');
        }
    }

    if isinstance(ir_node, self._Token) {
        if 'line' in nd {
            nd['line_no'] = nd['line'];
        }
        if 'col_start' in nd {
            nd['c_start'] = nd['col_start'];
        }
        if 'col_end' in nd {
            nd['c_end'] = nd['col_end'];
        }
        if nd.get('orig_src') is None and self._source_path {
            nd['orig_src'] = self._ensure_module_source();
        }
    }

    if isinstance(ir_node, self._FuncSignature) {
        self._fix_one_func_signature(ir_node);
    }

    if isinstance(ir_node, self._Module) {
        nd.setdefault('src_terminals', None);
        nd.setdefault('is_raised_from_py', False);
        nd.setdefault('decided_codespace', '');
    }

    if isinstance(ir_node, self._Import) {
        nd.setdefault('hint', {});
    }

    if isinstance(ir_node, self._ModulePath) or isinstance(ir_node, self._ModuleItem) {
        nd.setdefault('abs_path', None);
    }

    if isinstance(ir_node, self._Source) {
        if 'value' in nd {
            import hashlib;
            nd.setdefault('hash', hashlib.md5(str(nd['value']).encode()).hexdigest());
        }
        nd.setdefault('file_path', nd.get('mod_path', ''));
        nd.setdefault('comments', []);
    }

    try {
        ir_node.loc = self._CodeLocInfo(*ir_node.resolve_tok_range());
    } except Exception {
        ;
    }

    if (isinstance(ir_node, self._AstSymbolStubNode) and nd.get('name_spec') is None) {
        sym_type = self._stub_sym_types.get(type(ir_node), self._SymbolType_UNKNOWN);
        try {
            ir_node._init_stub(sym_type);
        } except Exception {
            ;
        }
    }

    nodes[idx] = ir_node;
    self.hydrated_node_count += 1;

    import from jaclang.jac0core.unitree {
        UniScopeNode,
        UniCFGNode,
        NameAtom as NameAtomT
    }
    if overlay_flags & 1 and isinstance(ir_node, UniScopeNode) {
        pos = self._read_scope_overlay(data, pos, ir_node);
    }
    if overlay_flags & 2 and isinstance(ir_node, UniCFGNode) {
        pos = self._read_cfg_overlay(data, pos, ir_node);
    }
    if overlay_flags & 4 and isinstance(ir_node, NameAtomT) {
        pos = self._read_name_atom_overlay(data, pos, ir_node);
    }
    if overlay_flags & 8 {
        import from jaclang.jac0core.unitree { ContextAwareNode }
        import from jaclang.jac0core.constant { CodeContext }
        ctx_byte = data[pos];
        pos += 1;
        if isinstance(ir_node, ContextAwareNode) {
            if ctx_byte == 1 {
                ir_node.code_context = CodeContext.CLIENT;
            } elif ctx_byte == 2 {
                ir_node.code_context = CodeContext.NATIVE;
            }
        }
    }

    return pos;
}

impl JirReader._read_scope_overlay(
    data: (bytes | memoryview), pos: int, scope_node: UniScopeNode
) -> int {
    import from jaclang.jac0core.unitree { UniScopeNode, Symbol, InheritedSymbolTable }
    import from jaclang.jac0core.constant { SymbolAccess }

    assert self._pool is not None;

    (name_idx, pos) = _read_varint(data, pos);
    scope_node.scope_name = self._pool.get(name_idx);

    scope_node.parent_scope = None;
    scope_node.kid_scope = [];
    scope_node.names_in_scope = {};
    scope_node.names_in_scope_overload = {};
    scope_node.inherited_scope = [];

    (sym_count, pos) = _read_varint(data, pos);
    for _ in range(sym_count) {
        (sym_name_idx, pos) = _read_varint(data, pos);
        sym_name = self._pool.get(sym_name_idx);
        (sym, pos) = self._read_symbol(data, pos);
        if sym is not None {
            scope_node.names_in_scope[sym_name] = sym;
            sym.parent_tab = scope_node;
        }
    }

    (overload_count, pos) = _read_varint(data, pos);
    for _ in range(overload_count) {
        (sym_name_idx, pos) = _read_varint(data, pos);
        sym_name = self._pool.get(sym_name_idx);
        (list_count, pos) = _read_varint(data, pos);
        sym_list = [];
        for _ in range(list_count) {
            (sym, pos) = self._read_symbol(data, pos);
            if sym is not None {
                sym_list.append(sym);
            }
        }
        if sym_list {
            scope_node.names_in_scope_overload[sym_name] = sym_list;
        }
    }

    (inh_count, pos) = _read_varint(data, pos);
    for _ in range(inh_count) {
        (src_id, pos) = _read_varint(data, pos);
        load_all = bool(data[pos]);
        pos += 1;
        (sym_names_count, pos) = _read_varint(data, pos);
        sym_names = [];
        for _ in range(sym_names_count) {
            (sn_idx, pos) = _read_varint(data, pos);
            sym_names.append(self._pool.get(sn_idx));
        }
        src_scope = self._resolve_node(src_id);
        if src_scope is not None and isinstance(src_scope, UniScopeNode) {
            scope_node.inherited_scope.append(
                InheritedSymbolTable(
                    base_symbol_table=src_scope,
                    load_all_symbols=load_all,
                    symbols=sym_names
                )
            );
        }
    }

    return pos;
}

impl JirReader._read_symbol(data: (bytes | memoryview), pos: int) -> tuple {
    import from jaclang.jac0core.unitree { Symbol, NameAtom }
    import from jaclang.jac0core.constant { SymbolAccess }

    (defn_count, pos) = _read_varint(data, pos);
    defn_ids = [];
    for _ in range(defn_count) {
        (nid, pos) = _read_varint(data, pos);
        defn_ids.append(nid);
    }

    (uses_count, pos) = _read_varint(data, pos);
    uses_ids = [];
    for _ in range(uses_count) {
        (nid, pos) = _read_varint(data, pos);
        uses_ids.append(nid);
    }

    (access_idx, pos) = _read_varint(data, pos);
    assert self._pool is not None;
    access_str = self._pool.get(access_idx);
    try {
        access = SymbolAccess(access_str);
    } except (ValueError, KeyError) {
        access = SymbolAccess.PUBLIC;
    }

    imported = bool(data[pos]);
    pos += 1;

    import from jaclang.jac0core.constant { OwnershipKind }
    _own_raw = data[pos];
    pos += 1;
    try {
        _ownership = OwnershipKind(_own_raw);
    } except (ValueError, KeyError) {
        _ownership = OwnershipKind.NONE;
    }
    _fact_flags = data[pos];
    pos += 1;

    defn_nodes = [];
    for nid in defn_ids {
        n = self._resolve_node(nid);
        if n is not None {
            defn_nodes.append(n);
        }
    }

    if not defn_nodes {
        return (None, pos);
    }

    sym: any = getattr(Symbol, '__new__')(Symbol);
    sym.defn = defn_nodes;
    sym.uses = [];
    sym.imported = imported;
    sym.access = access;
    sym.parent_tab = None;
    sym.semstr = '';
    sym.ownership = _ownership;
    sym.param_rebound = bool(_fact_flags & 1);
    sym.na_escapes = bool(_fact_flags & 2);
    sym.na_stack_ok = bool(_fact_flags & 4);

    for d in defn_nodes {
        if isinstance(d, NameAtom) {
            d._sym = sym;
        }
    }

    for nid in uses_ids {
        n = self._resolve_node(nid);
        if n is not None {
            sym.uses.append(n);
            if isinstance(n, NameAtom) {
                n._sym = sym;
            }
        }
    }

    return (sym, pos);
}

impl JirReader._read_cfg_overlay(
    data: (bytes | memoryview), pos: int, cfg_node: UniCFGNode
) -> int {
    (bb_in_count, pos) = _read_varint(data, pos);
    bb_in_ids = [];
    for _ in range(bb_in_count) {
        (nid, pos) = _read_varint(data, pos);
        bb_in_ids.append(nid);
    }

    (bb_out_count, pos) = _read_varint(data, pos);
    bb_out_ids = [];
    for _ in range(bb_out_count) {
        (nid, pos) = _read_varint(data, pos);
        bb_out_ids.append(nid);
    }

    (aff_count, pos) = _read_varint(data, pos);
    affected = set();
    assert self._pool is not None;
    for _ in range(aff_count) {
        (s_idx, pos) = _read_varint(data, pos);
        affected.add(self._pool.get(s_idx));
    }

    cfg_node.bb_in = [
        n
        for n in (self._resolve_node(nid) for nid in bb_in_ids)
        if n is not None
    ];
    cfg_node.bb_out = [
        n
        for n in (self._resolve_node(nid) for nid in bb_out_ids)
        if n is not None
    ];
    cfg_node.affected_symbols = affected;

    return pos;
}

impl JirReader._read_name_atom_overlay(
    data: (bytes | memoryview), pos: int, na_node: NameAtom
) -> int {
    has_sym = data[pos];
    pos += 1;
    if has_sym {
        (defn_count, pos) = _read_varint(data, pos);
        for _ in range(defn_count) {
            (nid, pos) = _read_varint(data, pos);
        }
    }

    assert self._pool is not None;
    (sym_name_idx, pos) = _read_varint(data, pos);
    na_node._sym_name = self._pool.get(sym_name_idx);

    (sym_cat_idx, pos) = _read_varint(data, pos);
    sym_cat_str = self._pool.get(sym_cat_idx);
    if sym_cat_str {
        import from jaclang.jac0core.constant { SymbolType }
        try {
            na_node._sym_category = SymbolType(sym_cat_str);
        } except (ValueError, KeyError) {
            import from jaclang.jac0core.constant { SymbolType as ST2 }
            na_node._sym_category = ST2.UNKNOWN;
        }
    } else {
        import from jaclang.jac0core.constant { SymbolType as ST3 }
        na_node._sym_category = ST3.UNKNOWN;
    }

    return pos;
}

impl JirReader._read_link_table(data: (bytes | memoryview), pos: int) -> int {
    import from jaclang.jac0core.unitree { UniScopeNode, NameAtom, AstSymbolNode }

    nodes = self._nodes;

    (count, pos) = _read_varint(data, pos);
    for _ in range(count) {
        (scope_id, pos) = _read_varint(data, pos);
        (parent_id, pos) = _read_varint(data, pos);

        scope = self._resolve_node(scope_id);
        if scope is not None and isinstance(scope, UniScopeNode) {
            if parent_id == EXTERNAL_REF {
                scope.parent_scope = None;
            } else {
                parent = self._resolve_node(parent_id);
                if parent is not None and isinstance(parent, UniScopeNode) {
                    scope.parent_scope = parent;
                    if scope not in parent.kid_scope {
                        parent.kid_scope.append(scope);
                    }
                }
            }
        }
    }

    (count, pos) = _read_varint(data, pos);
    for _ in range(count) {
        (na_id, pos) = _read_varint(data, pos);
        (name_of_id, pos) = _read_varint(data, pos);

        na = self._resolve_node(na_id);
        if na is not None and isinstance(na, NameAtom) {
            name_of = self._resolve_node(name_of_id);
            if name_of is not None and isinstance(name_of, AstSymbolNode) {
                na.name_of = name_of;
            }
        }
    }

    return pos;
}
