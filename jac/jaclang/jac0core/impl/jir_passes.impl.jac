"""Implementation of JIR writer and reader methods."""
import struct;
import sys;
import zlib;
import from typing { Any }

# =============================================================================
# JirWriter implementation
# =============================================================================
impl JirWriter.write_module(
    module: Module, sections: (dict[int, bytes] | None) = None
) -> bytes {
    import from jaclang.jac0core.jir { HEADER_FMT, HEADER_SIZE, MAGIC, FORMAT_VERSION }
    import from importlib.metadata { version as pkg_version }

    # Phase 1: Post-order walk to assign IDs
    self._assign_ids(module);

    # Phase 2: Serialize each node
    ir_buf = bytearray();
    for ir_item in self._nodes {
        self._write_node(ir_buf, ir_item);
    }

    # Phase 3: Serialize link table
    link_buf = bytearray();
    self._write_link_table(link_buf);

    # Phase 4: Build string pool
    pool_bytes = self._pool.serialize();

    # Phase 5: Assemble with header
    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }

    # Compute source hash
    source_hash = 0;
    if module?.source and module.source is not None {
        src_str = module.source.code;
        if src_str {
            source_hash = zlib.crc32(src_str.encode()) & 0xFFFFFFFF;
        }
    }

    sym_count = self._count_symbols(module);

    # Flags: bit 0 = is_stub
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
        len(self._nodes),
        sym_count,
        len(pool_bytes),
        flags
    );

    # Assemble: header (uncompressed) + zlib(pool + nodes + links) + optional sections
    import from jaclang.jac0core.jir { SEC_TYPE_TAGS, write_sections }
    payload = pool_bytes + bytes(ir_buf) + bytes(link_buf);
    compressed = zlib.compress(payload, 6);
    # Collect type tags from enriched Expr nodes and add as a section
    tag_bytes = self._serialize_type_tags();
    if sections is None {
        sections = {};
    }
    if tag_bytes {
        sections[SEC_TYPE_TAGS] = tag_bytes;
    }
    section_bytes = write_sections(sections);
    return header + compressed + section_bytes;
}

impl JirWriter._assign_ids(ir_node: UniNode) -> int {
    # Visit children first (post-order)
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

    # Write type index as varint
    _write_varint(buf, type_idx);

    # Write overlay flags as a single byte
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

    # Write child count and child IDs
    _write_varint(buf, len(list(ir_node.kid)));
    for kid in ir_node.kid {
        _write_varint(buf, self._get_node_id(kid));
    }

    # Write constructor fields per spec
    for field_desc in spec.fields {
        self._write_field(buf, ir_node, field_desc.name, field_desc.kind);
    }

    # Write scope overlay
    if is_scope {
        _write_varint(buf, self._pool.intern(ir_node.scope_name));

        # parent_scope -> link table (deferred)
        parent_scope_id = self._get_node_id(ir_node.parent_scope);
        self._parent_scope_links.append((self._node_ids[id(ir_node)], parent_scope_id));

        # names_in_scope: symbol entries
        _write_varint(buf, len(ir_node.names_in_scope));
        for (sym_name, sym) in ir_node.names_in_scope.items() {
            _write_varint(buf, self._pool.intern(sym_name));
            self._write_symbol(buf, sym);
        }

        # names_in_scope_overload
        overload_map = ir_node.names_in_scope_overload;
        non_empty = {
            k: v
            for (k, v) in overload_map.items()
            if v  # Preserve any overloads (was: len(v) > 1, which dropped single overloads)
        };
        _write_varint(buf, len(non_empty));
        for (sym_name, sym_list) in non_empty.items() {
            _write_varint(buf, self._pool.intern(sym_name));
            _write_varint(buf, len(sym_list));
            for sym in sym_list {
                self._write_symbol(buf, sym);
            }
        }

        # inherited_scope
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

    # Write CFG overlay
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

    # Write NameAtom overlay
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

        # name_of -> AstSymbolNode (deferred to link table)
        name_of = ir_node.name_of;
        if name_of is not None and name_of is not ir_node {
            na_id = self._node_ids[id(ir_node)];
            self._name_of_links.append((na_id, self._get_node_id(name_of)));
        }

        # _sym_name and _sym_category
        sym_name = ir_node._sym_name;
        _write_varint(buf, self._pool.intern(sym_name));
        sym_cat = ir_node._sym_category;
        if sym_cat is not None and hasattr(sym_cat, 'value') {
            _write_varint(buf, self._pool.intern(str(sym_cat.value)));
        } else {
            _write_varint(buf, self._pool.intern(''));
        }
    }

    # Write code_context overlay (postinit field, not in spec)
    if is_context_aware {
        ctx = ir_node.code_context;
        if ctx == CodeContext.CLIENT {
            buf.append(1);
        } elif ctx == CodeContext.NATIVE {
            buf.append(2);
        } else {
            buf.append(0);  # SERVER (default)
        }
    }
}

impl JirWriter._write_symbol(buf: bytearray, sym: Symbol) -> None {
    # defn nodes
    _write_varint(buf, len(sym.defn));
    for defn in sym.defn {
        _write_varint(buf, self._get_node_id(defn));
    }
    # uses nodes
    _write_varint(buf, len(sym.uses));
    for use in sym.uses {
        _write_varint(buf, self._get_node_id(use));
    }
    # access (string enum -> pool index)
    access_str = sym.access?.value or str(sym.access);
    _write_varint(buf, self._pool.intern(access_str));
    # imported flag
    buf.append(1 if sym.imported else 0);
}

impl JirWriter._write_field(
    buf: bytearray, ir_node: UniNode, field_name: str, kind: int
) -> None {
    val = getattr(ir_node, field_name, None);
    # Token stores line/col under aliased names; fall back when primary is None
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
            # Single node value (union types like Sequence[X] | Y)
            _write_varint(buf, 1);
            _write_varint(buf, self._get_node_id(val));
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
    # FieldKind.SKIP: do nothing
}

impl JirWriter._write_link_table(buf: bytearray) -> None {
    # parent_scope links
    _write_varint(buf, len(self._parent_scope_links));
    for (scope_id, parent_id) in self._parent_scope_links {
        _write_varint(buf, scope_id);
        _write_varint(buf, parent_id);
    }
    # name_of links (NameAtom -> AstSymbolNode forward refs)
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

"""Serialize backend_type_tag values from enriched Expr nodes into a compact section.

Format: varint(count) followed by count × [varint(node_id), varint(str_pool_idx)].
Only Expr nodes with non-None backend_type_tag are included. The string pool used
here is the same _pool that was built during _write_node, so tag strings are
interned alongside the rest of the IR strings.
"""
impl JirWriter._serialize_type_tags -> bytes {
    import from jaclang.jac0core.unitree { Expr }
    buf = bytearray();
    pairs: list[tuple[int, int]] = [];
    for ir_item in self._nodes {
        if isinstance(ir_item, Expr) and ir_item.backend_type_tag is not None {
            nid = self._node_ids.get(id(ir_item));
            if nid is not None {
                tag_idx = self._pool.intern(ir_item.backend_type_tag);
                pairs.append((nid, tag_idx));
            }
        }
    }
    _write_varint(buf, len(pairs));
    for (nid, tag_idx) in pairs {
        _write_varint(buf, nid);
        _write_varint(buf, tag_idx);
    }
    return bytes(buf);
}


# =============================================================================
# JirReader implementation
# =============================================================================
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

    # Parse header
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

    # Reject JIR files built with a different jaclang version (node layout may differ)
    if _current_jac_hash != 0 and jac_hash != _current_jac_hash {
        return None;
    }

    # Decompress payload
    try {
        payload_bytes = zlib.decompress(data[HEADER_SIZE:]);
    } except zlib.error {
        return None;
    }
    payload = memoryview(payload_bytes);
    pos = 0;

    # Read string pool
    (self._pool, pos) = _deserialize_string_pool(payload, pos);

    # Lazy-load class mapping and cache imports
    if not self._class_map {
        self._class_map = get_class_mapping();
        self._init_caches();
    }

    # Read node stream
    self._nodes = [None] * ir_node_count;
    for i in range(ir_node_count) {
        pos = self._read_node(payload, pos, i);
    }

    # Read link table
    pos = self._read_link_table(payload, pos);

    # The last node (post-order) is the root Module
    if self._nodes {
        last_node = self._nodes[-1];
        import from jaclang.jac0core.unitree { Module as ModuleCls }
        if isinstance(last_node, ModuleCls) {
            if self._source_path {
                self._wire_source(last_node);
            }
            self._fix_param_kinds();
            # Decode trailing TLV sections (bytecode, MTIR, LLVM IR, interop, type tags)
            import from jaclang.jac0core.jir {
                SEC_BYTECODE,
                SEC_MTIR,
                SEC_LLVM_IR,
                SEC_INTEROP,
                SEC_TYPE_TAGS
            }
            secs = self._read_trailing_sections(data);
            self.bytecode_section = secs.get(SEC_BYTECODE);
            self.mtir_section = secs.get(SEC_MTIR);
            self.llvm_ir_section = secs.get(SEC_LLVM_IR);
            self.interop_section = secs.get(SEC_INTEROP);
            self.type_tags_section = secs.get(SEC_TYPE_TAGS);
            if self.type_tags_section is not None {
                try {
                    self._apply_type_tags(self.type_tags_section);
                } except Exception {
                    pass;  # corrupt section — tags simply remain None
                }
            }
            return last_node;
        }
    }
    return None;
}

impl JirReader._read_trailing_sections(data: bytes) -> dict[int, bytes] {
    import from jaclang.jac0core.jir { HEADER_SIZE, SECTIONS_MAGIC, read_sections }
    try {
        magic_bytes: Any = SECTIONS_MAGIC;
        pos = data.find(magic_bytes, HEADER_SIZE);
        if pos < 0 {
            return {};
        }
        return read_sections(data, pos + len(magic_bytes));
    } except Exception {
        return {};
    }
}

impl JirReader._wire_source(module: Module) -> None {
    import from jaclang.jac0core.unitree { Source, Token }

    source_content = '';
    try {
        with open(self._source_path, 'r', encoding='utf-8') as f {
            source_content = f.read();
        }
    } except Exception {
        ;
    }

    src = Source(source_content, self._source_path);
    module.source = src;

    # Walk all nodes and set orig_src on Token instances
    stack = [module];
    visited: set[int] = set();
    while stack {
        cur = stack.pop();
        cur_id = id(cur);
        if cur_id in visited {
            continue;
        }
        visited.add(cur_id);
        if isinstance(cur, Token) {
            cur.orig_src = src;
        }
        stack.extend(cur.kid);
    }
}

impl JirReader._fix_param_kinds -> None {
    import from jaclang.jac0core.unitree { FuncSignature, ParamVar, ParamKind }

    for ir_item in self._nodes {
        if isinstance(ir_item, FuncSignature) {
            for p in (ir_item.posonly_params or []) {
                if isinstance(p, ParamVar) {
                    p.param_kind = ParamKind.POSONLY;
                }
            }
            for p in (ir_item.params or []) {
                if isinstance(p, ParamVar) {
                    p.param_kind = ParamKind.NORMAL;
                }
            }
            if ir_item.varargs is not None and isinstance(ir_item.varargs, ParamVar) {
                ir_item.varargs.param_kind = ParamKind.VARARG;
            }
            for p in (ir_item.kwonlyargs or []) {
                if isinstance(p, ParamVar) {
                    p.param_kind = ParamKind.KWONLY;
                }
            }
            if ir_item.kwargs is not None and isinstance(ir_item.kwargs, ParamVar) {
                ir_item.kwargs.param_kind = ParamKind.KWARG;
            }
        }
    }
}

impl JirReader._init_caches -> None {
    import from jaclang.jac0core.unitree {
        UniScopeNode,
        UniCFGNode,
        NameAtom,
        Expr,
        AstSymbolNode,
        WalkerStmtOnlyNode,
        Source,
        ParamVar,
        ParamKind,
        Token,
        Module,
        Import,
        ModulePath,
        ModuleItem,
        SpecialVarRef,
        ContextAwareNode
    }
    import from jaclang.jac0core.constant {
        SymbolAccess,
        SymbolType,
        EdgeDir,
        CodeContext
    }
    import from jaclang.jac0core.codeinfo { CodeLocInfo }
    import ast as ast3;

    self._CodeLocInfo = CodeLocInfo;
    self._Expr = Expr;
    self._AstSymbolNode = AstSymbolNode;
    self._WalkerStmtOnlyNode = WalkerStmtOnlyNode;
    self._Source = Source;
    self._ParamVar = ParamVar;
    self._ParamKind_NORMAL = ParamKind.NORMAL;
    self._Token = Token;
    self._Module = Module;
    self._Import = Import;
    self._ModulePath = ModulePath;
    self._ModuleItem = ModuleItem;
    self._SymbolType_UNKNOWN = SymbolType.UNKNOWN;
    self._ast3_Load = ast3.Load;
    self._SpecialVarRef = SpecialVarRef;
    self._ContextAwareNode = ContextAwareNode;
    self._CodeContext_SERVER = CodeContext.SERVER;

    self._uni_types = (UniScopeNode, UniCFGNode, NameAtom);

    # Build reverse lookup: enum_value_string -> enum_member
    self._enum_cache = {};
    enum_mapping = {
        'sym_category': SymbolType,
        'sym_type': SymbolType,
        'access': SymbolAccess,
        'edge_dir': EdgeDir,
        'code_context': CodeContext
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

    # Read type index
    (type_idx, pos) = _read_varint(data, pos);
    spec = IDX_TO_SPEC[type_idx];

    # Read overlay flags
    overlay_flags = data[pos];
    pos += 1;

    # Read children
    (child_count, pos) = _read_varint(data, pos);
    child_ids: list[int] = [];
    for _ in range(child_count) {
        (cid, pos) = _read_varint(data, pos);
        child_ids.append(cid);
    }

    # Construct ir_node via __new__ (skips init)
    cls = class_map[spec.class_name];
    ir_node: Any = cls.__new__(cls);
    nd = ir_node.__dict__;

    # Read fields and set directly on the ir_node
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
        # FieldKind.SKIP: do nothing
    }

    # Set kid/parent links
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
    nd['parent'] = None;

    # Initialize internal state from base class inits
    nd['_UniNode__sub_node_tab'] = None;
    nd['_in_mod_nodes'] = [];
    nd['_gen'] = None;

    uni_types = self._uni_types;
    assert uni_types is not None;
    (_UniScopeNode, _UniCFGNode, _NameAtom) = uni_types;

    # Expr.init: _type_sym_tab, type, attached_tokens
    if isinstance(ir_node, self._Expr) {
        nd.setdefault('_type_sym_tab', None);
        nd.setdefault('type', None);
        nd.setdefault('attached_tokens', None);
    }

    # NameAtom.init: name_of, _sym, _sym_name, _sym_category, _py_ctx_func
    if isinstance(ir_node, _NameAtom) {
        nd.setdefault('name_of', ir_node);
        nd.setdefault('_sym', None);
        nd.setdefault('_sym_name', '');
        nd.setdefault('_sym_category', self._SymbolType_UNKNOWN);
        nd.setdefault('_py_ctx_func', self._ast3_Load);
    }

    # AstSymbolNode.init: name_spec, semstr
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
            # Name/SpecialVarRef are NameAtom subclasses where name_spec == self
            if 'name_spec' not in nd and isinstance(ir_node, _NameAtom) {
                nd['name_spec'] = ir_node;
            }
        }
    }

    # ParamVar.init: param_kind
    if isinstance(ir_node, self._ParamVar) {
        nd.setdefault('param_kind', self._ParamKind_NORMAL);
    }

    # WalkerStmtOnlyNode.init: from_walker
    if isinstance(ir_node, self._WalkerStmtOnlyNode) {
        nd.setdefault('from_walker', False);
    }

    # ContextAwareNode.postinit: code_context (backward compat for old JIR
    # files without the overlay; new files read it from the bit-3 overlay)
    if isinstance(ir_node, self._ContextAwareNode) {
        nd.setdefault('code_context', self._CodeContext_SERVER);
    }

    # SpecialVarRef: token kind ('name') is deserialized directly from registry.
    # Point orig at self (py_resolve_name uses self.orig.name == self.name), then
    # derive value. No separate inner Name node exists in the kid list.
    if isinstance(ir_node, self._SpecialVarRef) {
        nd['orig'] = ir_node;
        try {
            nd['value'] = ir_node.py_resolve_name();
            nd['_sym_name'] = nd['value'];
        } except Exception {
            nd['value'] = nd.get('value', '');
        }
    }

    # Token.init aliases: line -> line_no, col_start -> c_start, col_end -> c_end
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
    }

    # Module.init: extra attributes
    if isinstance(ir_node, self._Module) {
        nd.setdefault('impl_mod', []);
        nd.setdefault('test_mod', []);
        nd.setdefault('variant_mod', []);
        nd.setdefault('src_terminals', None);
        nd.setdefault('is_raised_from_py', False);
    }

    # Import.init: hint
    if isinstance(ir_node, self._Import) {
        nd.setdefault('hint', {});
    }

    # ModulePath.init / ModuleItem.init: abs_path
    if isinstance(ir_node, self._ModulePath) or isinstance(ir_node, self._ModuleItem) {
        nd.setdefault('abs_path', None);
    }

    # Source.init: hash, file_path, comments
    if isinstance(ir_node, self._Source) {
        if 'value' in nd {
            import hashlib;
            nd.setdefault('hash', hashlib.md5(str(nd['value']).encode()).hexdigest());
        }
        nd.setdefault('file_path', nd.get('mod_path', ''));
        nd.setdefault('comments', []);
    }

    # Set loc
    try {
        ir_node.loc = self._CodeLocInfo(*ir_node.resolve_tok_range());
    } except Exception {
        ;
    }

    nodes[idx] = ir_node;

    # Read overlays (isinstance checks satisfy type checker; flags guarantee correctness)
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
            # 0 = SERVER, already the default from postinit
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

    # scope_name
    (name_idx, pos) = _read_varint(data, pos);
    scope_node.scope_name = self._pool.get(name_idx);

    # parent_scope is set via link table
    scope_node.parent_scope = None;
    scope_node.kid_scope = [];
    scope_node.names_in_scope = {};
    scope_node.names_in_scope_overload = {};
    scope_node.inherited_scope = [];

    # Read symbols
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

    # Read overloads
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

    # Read inherited scopes
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

    # defn nodes
    (defn_count, pos) = _read_varint(data, pos);
    defn_ids = [];
    for _ in range(defn_count) {
        (nid, pos) = _read_varint(data, pos);
        defn_ids.append(nid);
    }

    # uses nodes
    (uses_count, pos) = _read_varint(data, pos);
    uses_ids = [];
    for _ in range(uses_count) {
        (nid, pos) = _read_varint(data, pos);
        uses_ids.append(nid);
    }

    # access
    (access_idx, pos) = _read_varint(data, pos);
    assert self._pool is not None;
    access_str = self._pool.get(access_idx);
    try {
        access = SymbolAccess(access_str);
    } except (ValueError, KeyError) {
        access = SymbolAccess.PUBLIC;
    }

    # imported
    imported = bool(data[pos]);
    pos += 1;

    # Resolve defn nodes
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

    # Create Symbol with __new__ (skip init); getattr avoids type-checker arity check
    sym: Any = getattr(Symbol, '__new__')(Symbol);
    sym.defn = defn_nodes;
    sym.uses = [];
    sym.imported = imported;
    sym.access = access;
    sym.parent_tab = None;
    sym.semstr = '';

    # Wire up _sym on defn nodes
    for d in defn_nodes {
        if isinstance(d, NameAtom) {
            d._sym = sym;
        }
    }

    # Resolve uses
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
    # bb_in
    (bb_in_count, pos) = _read_varint(data, pos);
    bb_in_ids = [];
    for _ in range(bb_in_count) {
        (nid, pos) = _read_varint(data, pos);
        bb_in_ids.append(nid);
    }

    # bb_out
    (bb_out_count, pos) = _read_varint(data, pos);
    bb_out_ids = [];
    for _ in range(bb_out_count) {
        (nid, pos) = _read_varint(data, pos);
        bb_out_ids.append(nid);
    }

    # affected_symbols
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
    # has_sym
    has_sym = data[pos];
    pos += 1;
    if has_sym {
        (defn_count, pos) = _read_varint(data, pos);
        for _ in range(defn_count) {
            (nid, pos) = _read_varint(data, pos);
        }
        # Symbol is already wired up during scope overlay reading
    }

    # Read _sym_name and _sym_category
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

    # Ensure remaining defaults
    if not hasattr(na_node, 'name_of') {
        na_node.name_of = na_node;
    }
    if not hasattr(na_node, '_sym') {
        na_node._sym = None;
    }
    if not hasattr(na_node, '_py_ctx_func') {
        import ast as ast3;
        na_node._py_ctx_func = ast3.Load;
    }

    return pos;
}

impl JirReader._read_link_table(data: (bytes | memoryview), pos: int) -> int {
    import from jaclang.jac0core.unitree { UniScopeNode, NameAtom, AstSymbolNode }

    nodes = self._nodes;

    # parent_scope links
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

    # name_of links (NameAtom -> AstSymbolNode)
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

"""Apply backend_type_tag values from a serialized SEC_TYPE_TAGS section.

Reads varint-encoded (node_id, pool_idx) pairs and sets backend_type_tag on the
corresponding Expr nodes. The string pool used here is the same _pool that was
populated during read_module (deserialized before the node stream). Any invalid
node_id or pool_idx is silently skipped so a corrupt section cannot crash the reader.
"""
impl JirReader._apply_type_tags(data: bytes) -> None {
    import from jaclang.jac0core.unitree { Expr }
    if self._pool is None {
        return;
    }
    pool = self._pool;
    nodes = self._nodes;
    mv = memoryview(data);
    pos = 0;
    (count, pos) = _read_varint(mv, pos);
    for _ in range(count) {
        (nid, pos) = _read_varint(mv, pos);
        (tag_idx, pos) = _read_varint(mv, pos);
        if nid < len(nodes)
        and nodes[nid] is not None
        and isinstance(nodes[nid], Expr) {
            try {
                tag = pool.get(tag_idx);
                nodes[nid].backend_type_tag = tag;
            } except Exception {
                pass;
            }
        }
    }
}
