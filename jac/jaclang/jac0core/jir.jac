import hashlib;
import os;
import struct;
import sys;
import zlib;
import from pathlib { Path }

glob MAGIC = b"JIR\x00",
     FORMAT_VERSION: int = 16,
     HEADER_SIZE: int = 32,
     HEADER_FMT: str = "<4sHHIIIIII",
     EXTERNAL_REF: int = 0xFFFFFF,
     SECTIONS_MAGIC: any = b"JIRX",
     SEC_BYTECODE: int = 0x02,
     SEC_MTIR: int = 0x03,
     SEC_LLVM_IR: int = 0x04,
     SEC_INTEROP: int = 0x05,
     SEC_NATIVE_OBJ: int = 0x06,
     SEC_SYMINDEX: int = 0x07,
     SEC_MODKEY: int = 0x08,
     SEC_DEBUG_SRC: int = 0x09,
     SEC_INPUTS: int = 0x0A,
     SEC_TERMINATOR: int = 0xFF,
     INPUT_COMPILER: str = "compiler",
     INPUT_MAIN: str = "main",
     INPUT_IMPL: str = "impl",
     INPUT_TEST: str = "test",
     INPUT_VARIANTS: str = "variants",
     INPUT_STYLE: str = "style",
     INPUT_CONFIG: str = "config",
     BYTECODE_INPUT_KEYS: list[str] = [
         "compiler",
         "main",
         "impl",
         "variants",
         "config"
     ],
     FLAG_PRECOMPILED: int = 0x02,
     PRECOMPILE_SENTINEL: str = "__PKG_ROOT__",
     FLAG_BOOTSTRAP: int = 0x04;

obj JirHeader {
    has magic: any = b"JIR\x00",
        format_version: int = FORMAT_VERSION,
        python_version: int = 0,
        jaclang_version_hash: int = 0,
        source_content_hash: int = 0,
        node_count: int = 0,
        symbol_count: int = 0,
        string_pool_size: int = 0,
        flags: int = 0;

    def to_bytes -> bytes;
    def is_compatible -> bool;
}

glob _jaclang_pkg_version_cache: list[str] = [];

def _get_jaclang_pkg_version -> str {
    if _jaclang_pkg_version_cache {
        return _jaclang_pkg_version_cache[0];
    }
    import from importlib.metadata { version as pkg_version }
    try {
        _jaclang_pkg_version_cache.append(pkg_version('jaclang'));
    } except Exception {
        _jaclang_pkg_version_cache.append("0.0.0");
    }
    return _jaclang_pkg_version_cache[0];
}

def create_header(
    source_hash: int,
    node_count: int,
    symbol_count: int,
    string_pool_size: int,
    flags: int = 0
) -> JirHeader {
    jac_ver = _get_jaclang_pkg_version();
    return JirHeader(
        magic=MAGIC,
        format_version=FORMAT_VERSION,
        python_version=(sys.version_info.major << 8) | sys.version_info.minor,
        jaclang_version_hash=zlib.crc32(jac_ver.encode()) & 0xFFFFFFFF,
        source_content_hash=source_hash & 0xFFFFFFFF,
        node_count=node_count,
        symbol_count=symbol_count,
        string_pool_size=string_pool_size,
        flags=flags
    );
}

def parse_header(data: (bytes | memoryview)) -> (JirHeader | None) {
    if len(data) < HEADER_SIZE {
        return None;
    }
    try {
        (magic, fmt_ver, py_ver, jac_hash, src_hash, n_nodes, n_syms, sp_size, flags) = struct.unpack(
            HEADER_FMT, data[:HEADER_SIZE]
        );
    } except struct.error {
        return None;
    }
    if magic != MAGIC or fmt_ver != FORMAT_VERSION {
        return None;
    }
    return JirHeader(
        magic=magic,
        format_version=fmt_ver,
        python_version=py_ver,
        jaclang_version_hash=jac_hash,
        source_content_hash=src_hash,
        node_count=n_nodes,
        symbol_count=n_syms,
        string_pool_size=sp_size,
        flags=flags
    );
}

def get_jir_cache_dir -> Path {
    import from jaclang.jac0core.cache_paths { get_jir_cache_dir as _root }
    return _root();
}

def compute_content_sha256(file_path: str) -> str {
    h = hashlib.sha256();
    with open(file_path, 'rb') as f {
        while True {
            chunk = f.read(8192);
            if not chunk {
                break;
            }
            h.update(chunk);
        }
    }
    return h.hexdigest();
}

def _gather_related_paths(source_path: str) -> list[str] {
    import from jaclang.jac0core.bccache {
        discover_annex_files,
        discover_variant_files,
        discover_style_annex
    }
    src = Path(source_path).resolve();
    paths: set = set();
    paths |= set(discover_annex_files(str(src), '.impl.jac'));
    paths |= set(discover_annex_files(str(src), '.test.jac'));
    paths |= set(discover_variant_files(str(src)));
    style = discover_style_annex(str(src));
    if style is not None {
        paths.add(style);
    }
    return sorted(paths);
}

def _hash_related_paths(
    source_path: str, related_paths: list[str]
) -> list[tuple[str, str]] {
    base_dir = Path(source_path).resolve().parent;
    result: list[tuple[str, str]] = [];
    for p in related_paths {
        rel = os.path.relpath(p, str(base_dir)).replace(os.sep, '/');
        result.append((rel, compute_content_sha256(p)));
    }
    return result;
}

def _related_files(source_path: str) -> list[tuple[str, str]] {
    return _hash_related_paths(source_path, _gather_related_paths(source_path));
}

def _find_jac_toml_path(source_path: str) -> (str | None) {
    cur = Path(source_path).resolve().parent;
    for _ in range(32) {
        candidate = cur / "jac.toml";
        if candidate.is_file() {
            return str(candidate);
        }
        parent = cur.parent;
        if parent == cur {
            break;
        }
        cur = parent;
    }
    return None;
}

def _hash_sorted_paths(paths: list[str]) -> str {
    if not paths {
        return "";
    }
    h = hashlib.sha256();
    for p in sorted(paths) {
        h.update(compute_content_sha256(p).encode());
    }
    return h.hexdigest();
}

def _compiler_fingerprint -> str {
    h = hashlib.sha256();
    h.update(_get_jaclang_pkg_version().encode());
    h.update(struct.pack('<H', (sys.version_info.major << 8) | sys.version_info.minor));
    h.update(struct.pack('<H', FORMAT_VERSION));
    h.update(schema_digest().encode());
    return h.hexdigest();
}

def _config_fingerprint(source_path: str) -> str {
    codespace_mode = _module_codespace_mode(source_path);
    kind = _module_client_kind(source_path);
    toml = _find_jac_toml_path(source_path);
    if toml is not None {
        return f"{codespace_mode}:{kind}:{compute_content_sha256(toml)}";
    }
    return f"{codespace_mode}:{kind}";
}

def compute_input_fingerprints(source_path: str) -> dict[str, str] {
    import from jaclang.jac0core.bccache {
        discover_annex_files,
        discover_variant_files,
        discover_style_annex
    }
    src = str(Path(source_path).resolve());
    impl_paths = discover_annex_files(src, '.impl.jac');
    test_paths = discover_annex_files(src, '.test.jac');
    variant_paths = discover_variant_files(src);
    style_path = discover_style_annex(src);
    style_paths: list[str] = [];
    if style_path is not None {
        style_paths.append(style_path);
    }
    return {
        INPUT_COMPILER: _compiler_fingerprint(),
        INPUT_MAIN: compute_content_sha256(src),
        INPUT_IMPL: _hash_sorted_paths(impl_paths),
        INPUT_TEST: _hash_sorted_paths(test_paths),
        INPUT_VARIANTS: _hash_sorted_paths(variant_paths),
        INPUT_STYLE: _hash_sorted_paths(style_paths),
        INPUT_CONFIG: _config_fingerprint(source_path)
    };
}

def serialize_input_fingerprints(fingerprints: dict[str, str]) -> bytes {
    import json;
    return json.dumps(fingerprints, sort_keys=True).encode('utf-8');
}

def deserialize_input_fingerprints(data: bytes) -> (dict[str, str] | None) {
    import json;
    try {
        raw = json.loads(data.decode('utf-8'));
        if not isinstance(raw, dict) {
            return None;
        }
        out: dict[str, str] = {};
        for (k, v) in raw.items() {
            out[str(k)] = str(v);
        }
        return out;
    } except Exception {
        return None;
    }
}

def bytecode_fingerprint_digest(fingerprints: dict[str, str]) -> str {
    h = hashlib.sha256();
    for key in BYTECODE_INPUT_KEYS {
        h.update(fingerprints.get(key, "").encode());
    }
    return h.hexdigest();
}

def bytecode_inputs_match(stored: dict[str, str], current: dict[str, str]) -> bool {
    for key in BYTECODE_INPUT_KEYS {
        if stored.get(key) != current.get(key) {
            return False;
        }
    }
    return True;
}

def module_mtime_paths(source_path: str) -> list[str] {
    paths: list[str] = [str(Path(source_path).resolve())];
    paths.extend(_gather_related_paths(source_path));
    toml = _find_jac_toml_path(source_path);
    if toml is not None {
        paths.append(toml);
    }
    return paths;
}

def bytecode_mtime_paths(source_path: str) -> list[str] {
    import from jaclang.jac0core.bccache {
        discover_annex_files,
        discover_variant_files
    }
    src = str(Path(source_path).resolve());
    paths: list[str] = [src];
    paths.extend(discover_annex_files(src, '.impl.jac'));
    paths.extend(discover_variant_files(src));
    toml = _find_jac_toml_path(source_path);
    if toml is not None {
        paths.append(toml);
    }
    return paths;
}

def _cache_mtime_paths_fresh(source_path: str, cache_mtime: float) -> bool {
    for p in module_mtime_paths(source_path) {
        try {
            if cache_mtime <= os.path.getmtime(p) {
                return False;
            }
        } except OSError {
            return False;
        }
    }
    return True;
}

def _read_jir_sections(data: bytes) -> dict[int, bytes] {
    magic: any = SECTIONS_MAGIC;
    pos = data.find(magic, HEADER_SIZE);
    if pos < 0 {
        return {};
    }
    return read_sections(data, pos + len(magic));
}

def read_sec_inputs(data: bytes) -> (dict[str, str] | None) {
    try {
        inputs_bytes = _read_jir_sections(data).get(SEC_INPUTS);
        if inputs_bytes is None {
            return None;
        }
        return deserialize_input_fingerprints(inputs_bytes);
    } except Exception {
        return None;
    }
}

glob _client_kind_probe_depth: list[int] = [0],
     _client_kind_cache: dict[str, tuple[str, str | None, str]] = {},
     _NO_TOML_FP: str = "__no_toml__";

def _read_toml_content_hash(toml_path: str) -> (str | None) {
    try {
        return compute_content_sha256(toml_path);
    } except OSError {
        return None;
    }
}

def _current_toml_signature(source_path: str) -> tuple[str | None, str] {
    toml_path = _find_jac_toml_path(source_path);
    if toml_path is None {
        return (None, _NO_TOML_FP);
    }
    toml_fp = _read_toml_content_hash(toml_path);
    if toml_fp is None {
        return (None, _NO_TOML_FP);
    }
    return (toml_path, toml_fp);
}

def clear_module_client_kind_cache {
    _client_kind_cache.clear();
}

def _store_client_kind_cache(
    source_path: str, kind: str, toml_path: (str | None), toml_fp: str
) {
    _client_kind_cache[source_path] = (kind, toml_path, toml_fp);
}

def _module_codespace_mode(source_path: str) -> str {
    import from jaclang.jac0core.ext_registry { codespace_of }
    if codespace_of(source_path) is not None {
        return "explicit";
    }
    try {
        import from jaclang.jac0core.codeinfo { effective_default_codespace }
        return effective_default_codespace();
    } except Exception {
        return "server";
    }
}

def _module_client_kind(source_path: str) -> str {
    (current_toml, current_fp) = _current_toml_signature(source_path);
    entry = _client_kind_cache.get(source_path);
    if entry is not None {
        (kind, cached_toml, cached_fp) = entry;
        if cached_toml == current_toml and cached_fp == current_fp {
            return kind;
        }
        if current_toml is not None {
            import from jaclang.project.config { invalidate_config_for_root }
            invalidate_config_for_root(Path(current_toml).parent);
        }
    }
    if _client_kind_probe_depth[0] > 0 {
        return "web";
    }
    _client_kind_probe_depth[0] = 1;
    try {
        import from jaclang.project.client_kind { resolve_client_kind_context }
        (kind, _proj_root) = resolve_client_kind_context(source_path);
        _store_client_kind_cache(source_path, kind, current_toml, current_fp);
        return kind;
    } except Exception {
        return "web";
    } finally {
        _client_kind_probe_depth[0] = 0;
    }
}

glob _SCHEMA_DIGEST_CACHE: list = [];

def schema_digest -> str {
    if _SCHEMA_DIGEST_CACHE {
        return _SCHEMA_DIGEST_CACHE[0];
    }
    import from jaclang.jac0core.jir_registry { NODE_SPECS }
    h = hashlib.sha256();
    for spec in NODE_SPECS {
        h.update(str(getattr(spec, 'type_idx', -1)).encode());
        h.update(getattr(spec, 'class_name', '').encode());
        for fd in (getattr(spec, 'fields', ()) or ()) {
            h.update(getattr(fd, 'name', '').encode());
            h.update(str(getattr(fd, 'kind', -1)).encode());
        }
    }
    _SCHEMA_DIGEST_CACHE.append(h.hexdigest());
    return _SCHEMA_DIGEST_CACHE[0];
}

def compute_module_key(
    source_path: str, related: (list[tuple[str, str]] | None) = None
) -> str {
    if related is not None {
        jac_ver = _get_jaclang_pkg_version();
        h = hashlib.sha256();
        h.update(jac_ver.encode());
        h.update(
            struct.pack('<H', (sys.version_info.major << 8) | sys.version_info.minor)
        );
        h.update(struct.pack('<H', FORMAT_VERSION));
        h.update(schema_digest().encode());
        h.update(_module_client_kind(source_path).encode());
        h.update(_module_codespace_mode(source_path).encode());
        h.update(compute_content_sha256(source_path).encode());
        for (rel, digest) in related {
            h.update(rel.encode());
            h.update(digest.encode());
        }
        return h.hexdigest();
    }
    fingerprints = compute_input_fingerprints(source_path);
    return compute_module_key_from_fingerprints(fingerprints);
}

def compute_module_key_from_fingerprints(fingerprints: dict[str, str]) -> str {
    h = hashlib.sha256();
    for key in sorted(fingerprints.keys()) {
        h.update(key.encode());
        h.update(fingerprints[key].encode());
    }
    return h.hexdigest();
}

def module_cache_sections(
    module_key: str, fingerprints: dict[str, str]
) -> dict[int, bytes] {
    return {
        SEC_MODKEY: module_key.encode('utf-8'),
        SEC_INPUTS: serialize_input_fingerprints(fingerprints)
    };
}

def read_modkey(data: bytes) -> (str | None) {
    try {
        key_bytes = _read_jir_sections(data).get(SEC_MODKEY);
        return key_bytes.decode('utf-8') if key_bytes is not None else None;
    } except Exception {
        return None;
    }
}

def bytecode_cache_valid(
    data: bytes, source_path: str, current: (dict[str, str] | None) = None
) -> bool {
    stored_inputs = read_sec_inputs(data);
    if stored_inputs is not None {
        cur = current
            if current is not None
            else compute_input_fingerprints(source_path);
        return bytecode_inputs_match(stored_inputs, cur);
    }
    stored = read_modkey(data);
    if stored is None {
        return False;
    }
    key = compute_module_key(source_path);
    return stored == key;
}

def jir_matches_source(
    jir_data: bytes, source_path: str, module_key: (str | None) = None
) -> bool {
    if read_sec_inputs(jir_data) is not None {
        return bytecode_cache_valid(jir_data, source_path);
    }
    stored = read_modkey(jir_data);
    if stored is None {
        return False;
    }
    key = module_key if module_key is not None else compute_module_key(source_path);
    return stored == key;
}

def cache_mode -> tuple[bool, bool] {
    truthy: set = {'1', 'true', 'True', 'TRUE', 'yes', 'YES', 'on', 'ON'};
    rebuild = os.environ.get('JAC_REBUILD', '') in truthy;
    no_precompile = os.environ.get('JAC_NO_PRECOMPILE', '') in truthy;
    return (rebuild, no_precompile);
}

glob _jaclang_pkg_dir: str = str(Path(__file__).resolve().parent.parent);

def _get_module_cache_dir(source_path: str) -> Path {
    resolved = Path(source_path).resolve();
    resolved_str = str(resolved);

    if resolved_str.startswith(_jaclang_pkg_dir + os.sep) {
        return get_jir_cache_dir() / 'modules';
    }
    try {
        resolved.relative_to(sys.prefix);
        return get_jir_cache_dir() / 'modules';
    } except ValueError { }

    try {
        config_mod = __import__("jaclang.project.config", fromlist=["get_config"]);
        cfg = config_mod.get_config();
        if cfg is not None and cfg.is_valid() and cfg.project_root is not None {
            try {
                resolved.relative_to(cfg.project_root);
                return cfg.get_cache_dir();
            } except ValueError { }

            return get_jir_cache_dir() / 'modules';
        }
    } except Exception { }

    return resolved.parent / ".jac" / "cache";
}

def get_module_cache_path(source_path: str) -> Path {
    cache_dir = _get_module_cache_dir(source_path);
    source = Path(source_path).resolve();
    path_hash = hashlib.sha256(str(source).encode()).hexdigest()[:8];
    (major, minor) = (sys.version_info.major, sys.version_info.minor);
    return cache_dir / f"{source.stem}.{path_hash}.cpython-{major}{minor}.jir";
}

def get_native_cache_dir(source_path: str) -> Path {
    return _get_module_cache_dir(source_path) / "native";
}

def scrub_cache_dirs(root_dir: str) -> int {
    import glob as _glob;
    import shutil as _shutil;
    patterns = [
        os.path.join(root_dir, "**", ".jac", "cache"),
        os.path.join(root_dir, "**", ".jac_ir")
    ];
    removed = 0;
    seen: set[str] = set();
    for pattern in patterns {
        for cache_dir in _glob.glob(pattern, recursive=True) {
            if cache_dir in seen or not os.path.isdir(cache_dir) {
                continue;
            }
            seen.add(cache_dir);
            _shutil.rmtree(cache_dir, ignore_errors=True);
            removed += 1;
        }
    }
    return removed;
}

def write_sections(sections: (dict[int, bytes] | None)) -> bytes {
    if not sections {
        return bytes();
    }
    magic: any = SECTIONS_MAGIC;
    buf = bytearray(magic);
    for (sec_type, data) in sections.items() {
        buf.append(sec_type);
        buf.extend(struct.pack('<I', len(data)));
        buf.extend(data);
    }
    buf.append(SEC_TERMINATOR);
    buf.extend(bytes(4));
    return bytes(buf);
}

def read_sections(data: (bytes | memoryview), start_pos: int) -> dict[int, bytes] {
    result: dict[int, bytes] = {};
    pos = start_pos;
    try {
        while pos < len(data) {
            sec_type = data[pos];
            pos += 1;
            if sec_type == SEC_TERMINATOR {
                break;
            }
            if pos + 4 > len(data) {
                break;
            }
            (sec_len, ) = struct.unpack_from('<I', data, pos);
            pos += 4;
            if pos + sec_len > len(data) {
                break;
            }
            result[sec_type] = bytes(data[pos:pos + sec_len]);
            pos += sec_len;
        }
    } except Exception {
        ;
    }
    return result;
}

def read_bytecode_only(data: bytes) -> (bytes | None) {
    try {
        magic_bytes: any = SECTIONS_MAGIC;
        pos = data.find(magic_bytes, HEADER_SIZE);
        if pos < 0 {
            return None;
        }
        sections = read_sections(data, pos + len(magic_bytes));
        return sections.get(SEC_BYTECODE);
    } except Exception {
        return None;
    }
}

def write_precompiled_jir(
    bytecode: bytes,
    module_key: str = "",
    flags: int = 0,
    extra_sections: (dict[int, bytes] | None) = None,
    input_fingerprints: (dict[str, str] | None) = None
) -> bytes {
    try {
        jac_hash = zlib.crc32(_get_jaclang_pkg_version().encode()) & 0xFFFFFFFF;
    } except Exception {
        jac_hash = 0;
    }
    header = struct.pack(
        HEADER_FMT,
        MAGIC,
        FORMAT_VERSION,
        (sys.version_info.major << 8) | sys.version_info.minor,
        jac_hash,
        0,
        0,
        0,
        0,
        flags
    );
    empty_payload = zlib.compress(bytes(1), 1);
    sections: dict[int, bytes] = {SEC_BYTECODE: bytecode};
    if module_key {
        sections[SEC_MODKEY] = module_key.encode('utf-8');
    }
    if input_fingerprints is not None {
        sections[SEC_INPUTS] = serialize_input_fingerprints(input_fingerprints);
    }
    if extra_sections {
        sections.update(extra_sections);
    }
    section_bytes = write_sections(sections);
    return header + empty_payload + section_bytes;
}

def read_debug_source(data: bytes) -> (str | None) {
    try {
        magic_bytes: any = SECTIONS_MAGIC;
        pos = data.find(magic_bytes, HEADER_SIZE);
        if pos < 0 {
            return None;
        }
        sections = read_sections(data, pos + len(magic_bytes));
        src = sections.get(SEC_DEBUG_SRC);
        return zlib.decompress(src).decode('utf-8') if src is not None else None;
    } except Exception {
        return None;
    }
}

def is_module_cache_valid(
    source_path: str, cache_path: Path, fingerprints: (dict[str, str] | None) = None
) -> tuple[bool, (str | None)] {
    if not cache_path.exists() {
        return (False, None);
    }
    try {
        data: bytes = cache_path.read_bytes();
        header = parse_header(data[:HEADER_SIZE]);
        if header is None or not header.is_compatible() {
            return (False, None);
        }
        fps = fingerprints
            if fingerprints is not None
            else compute_input_fingerprints(source_path);
        modkey = compute_module_key_from_fingerprints(fps);
        bytecode_ok = bytecode_cache_valid(data, source_path, fps);
        return (bytecode_ok, modkey);
    } except OSError {
        return (False, None);
    }
}
