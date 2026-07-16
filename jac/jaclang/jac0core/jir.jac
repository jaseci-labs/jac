import hashlib;
import os;
import struct;
import sys;
import zlib;
import from pathlib { Path }

glob MAGIC = b"JIR\x00",
     FORMAT_VERSION: int = 15,
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
     SEC_TERMINATOR: int = 0xFF,
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

glob _jaclang_pkg_version: (str | None) = None;

def _get_jaclang_pkg_version -> str {
    global _jaclang_pkg_version;
    if _jaclang_pkg_version is not None {
        return _jaclang_pkg_version;
    }
    import from importlib.metadata { version as pkg_version }
    try {
        _jaclang_pkg_version = pkg_version('jaclang');
    } except Exception {
        _jaclang_pkg_version = "0.0.0";
    }
    return _jaclang_pkg_version;
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

glob _client_kind_probe_active: bool = False,
     _client_kind_cache: dict[str, tuple[str, str, str]] = {};

def _read_toml_fingerprint(proj_root: str) -> (str | None) {
    try {
        return compute_content_sha256(os.path.join(proj_root, "jac.toml"));
    } except OSError {
        return None;
    }
}

def _evict_project_from_kind_cache(proj_root: str) {
    stale: list[str] = [];
    for (src_path, (_kind, _root, _fp)) in _client_kind_cache.items() {
        if _root == proj_root {
            stale.append(src_path);
        }
    }
    for s in stale {
        _client_kind_cache.pop(s, None);
    }
}

def clear_module_client_kind_cache {
    _client_kind_cache.clear();
}

def _module_client_kind(source_path: str) -> str {
    global _client_kind_probe_active;
    entry = _client_kind_cache.get(source_path);
    if entry is not None {
        (kind, proj_root, cached_fp) = entry;
        current_fp = _read_toml_fingerprint(proj_root);
        if current_fp is not None and current_fp == cached_fp {
            return kind;
        }
        import from jaclang.project.config { invalidate_config_for_root }
        invalidate_config_for_root(proj_root);
        _evict_project_from_kind_cache(proj_root);
    }
    if _client_kind_probe_active {
        return "web";
    }
    _client_kind_probe_active = True;
    try {
        import from jaclang.project.client_kind { resolve_client_kind_context }
        (kind, proj_root) = resolve_client_kind_context(source_path);
        toml_fp = _read_toml_fingerprint(proj_root) if proj_root is not None else None;
        if toml_fp is not None {
            _client_kind_cache[source_path] = (kind, proj_root, toml_fp);
        }
        return kind;
    } except Exception {
        return "web";
    } finally {
        _client_kind_probe_active = False;
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
    jac_ver = _get_jaclang_pkg_version();
    h = hashlib.sha256();
    h.update(jac_ver.encode());
    h.update(struct.pack('<H', (sys.version_info.major << 8) | sys.version_info.minor));
    h.update(struct.pack('<H', FORMAT_VERSION));
    h.update(schema_digest().encode());
    h.update(_module_client_kind(source_path).encode());
    h.update(compute_content_sha256(source_path).encode());
    related_files = related if related is not None else _related_files(source_path);
    for (rel, digest) in related_files {
        h.update(rel.encode());
        h.update(digest.encode());
    }
    return h.hexdigest();
}

def read_modkey(data: bytes) -> (str | None) {
    try {
        magic: any = SECTIONS_MAGIC;
        pos = data.find(magic, HEADER_SIZE);
        if pos < 0 {
            return None;
        }
        sections = read_sections(data, pos + len(magic));
        key_bytes = sections.get(SEC_MODKEY);
        return key_bytes.decode('utf-8') if key_bytes is not None else None;
    } except Exception {
        return None;
    }
}

def jir_matches_source(
    jir_data: bytes, source_path: str, module_key: (str | None) = None
) -> bool {
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
    extra_sections: (dict[int, bytes] | None) = None
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
    source_path: str,
    cache_path: Path,
    module_key: (str | None) = None,
    key_out: (list[str] | None) = None
) -> bool {
    if not cache_path.exists() {
        return False;
    }
    try {
        data: bytes = cache_path.read_bytes();
        header = parse_header(data[:HEADER_SIZE]);
        if header is None or not header.is_compatible() {
            return False;
        }
        cache_mtime = os.path.getmtime(cache_path);
        related = _gather_related_paths(source_path);
        fresh = cache_mtime > os.path.getmtime(source_path);
        if fresh {
            for f in related {
                try {
                    if cache_mtime <= os.path.getmtime(f) {
                        fresh = False;
                        break;
                    }
                } except OSError {
                    fresh = False;
                    break;
                }
            }
        }
        if fresh {
            return True;
        }

        key = module_key;
        if key is None {
            key = compute_module_key(
                source_path, related=_hash_related_paths(source_path, related)
            );
            if key_out is not None {
                key_out.append(key);
            }
        }
        return jir_matches_source(data, source_path, key);
    } except OSError {
        return False;
    }
}
