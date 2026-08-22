import hashlib;
import os;
import struct;
import sys;
import zlib;
import from pathlib { Path }

glob MAGIC = b"JIR\x00",
     FORMAT_VERSION: int = 20,
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
     SEC_PLACEMENT: int = 0x0A,
     SEC_ENVKEY: int = 0x0B,
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

def create_header(
    source_hash: int,
    node_count: int,
    symbol_count: int,
    string_pool_size: int,
    flags: int = 0
) -> JirHeader {
    return JirHeader(
        magic=MAGIC,
        format_version=FORMAT_VERSION,
        python_version=(sys.version_info.major << 8) | sys.version_info.minor,
        jaclang_version_hash=zlib.crc32(jaclang_version().encode()) & 0xFFFFFFFF,
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

def _related_files(source_path: str) -> list[tuple[str, str]] {
    import from jaclang.jac0core.bccache { discover_annex_files, discover_style_annex }
    src = Path(source_path).resolve();
    base_dir = src.parent;
    paths: set = set();
    paths |= set(discover_annex_files(str(src), '.impl.jac'));
    paths |= set(discover_annex_files(str(src), '.test.jac'));
    style = discover_style_annex(str(src));
    if style is not None {
        paths.add(style);
    }
    result: list[tuple[str, str]] = [];
    for p in sorted(paths) {
        rel = os.path.relpath(p, str(base_dir)).replace(os.sep, '/');
        result.append((rel, compute_content_sha256(p)));
    }
    return result;
}

glob _client_kind_probe: dict = {"active": False};

def is_compiler_source_path(source_path: str) -> bool {
    try {
        resolved = str(Path(source_path).resolve());
    } except OSError {
        return False;
    }
    return resolved.startswith(_jaclang_pkg_dir + os.sep);
}

def _module_codespace_mode(source_path: str) -> str {
    if is_compiler_source_path(source_path) {
        return "internal";
    }
    try {
        import from jaclang.jac0core.codeinfo { effective_default_codespace }
        return effective_default_codespace();
    } except Exception {
        return "server";
    }
}

def _module_client_kind(source_path: str) -> str {
    if _client_kind_probe["active"] {
        return "web";
    }
    _client_kind_probe["active"] = True;
    try {
        import from jaclang.project.client_kind { resolve_client_kind_context }
        (kind, _) = resolve_client_kind_context(source_path);
        return kind;
    } except Exception {
        return "web";
    } finally {
        _client_kind_probe["active"] = False;
    }
}

glob COMPILER_DIGEST_ROOTS: tuple = (
         "jac0.py",
         "jac0core",
         "compiler",
         "utils/precompile_bytecode.jac"
     ),
     COMPILER_DIGEST_SUFFIXES: tuple = (".jac", ".py"),
     COMPILER_DIGEST_SKIP_DIRS: tuple = ("tests", "test", "__pycache__"),
     COMPILER_DIGEST_SKIP: tuple = ("compiler/native_materialize.jac", );

def compiler_source_files(pkg_dir: str) -> list[str] {
    base = str(Path(pkg_dir));
    rels: list[str] = [];
    for `entry in COMPILER_DIGEST_ROOTS {
        target = os.path.join(base, `entry.replace("/", os.sep));
        if os.path.isfile(target) {
            rels.append(`entry);
            continue;
        }
        if not os.path.isdir(target) {
            continue;
        }
        for (walk_dir, dirs, files) in os.walk(target) {
            dirs[:] = [
                d
                for d in dirs
                if not d.startswith(".") and d not in COMPILER_DIGEST_SKIP_DIRS
            ];
            for name in files {
                if not name.endswith(COMPILER_DIGEST_SUFFIXES) or ".test." in name {
                    continue;
                }
                rel = os.path.relpath(os.path.join(walk_dir, name), base).replace(
                    os.sep, "/"
                );
                if rel in COMPILER_DIGEST_SKIP {
                    continue;
                }
                rels.append(rel);
            }
        }
    }
    return sorted(rels);
}

def compiler_source_digest(pkg_dir: str) -> str {
    base = str(Path(pkg_dir));
    rels = compiler_source_files(base);
    h = hashlib.sha256();
    for rel in rels {
        h.update(rel.encode());
        h.update(
            compute_content_sha256(
                os.path.join(base, rel.replace("/", os.sep))
            ).encode()
        );
    }
    return f"{len(rels)}:{h.hexdigest()}";
}

glob _COMPILER_DIGEST_CACHE: list = [];

def running_compiler_digest -> str {
    if not _COMPILER_DIGEST_CACHE {
        _COMPILER_DIGEST_CACHE.append(compiler_source_digest(_jaclang_pkg_dir));
    }
    return _COMPILER_DIGEST_CACHE[0];
}

glob _JAC_VERSION_CACHE: list = [];

def jaclang_version -> str {
    if not _JAC_VERSION_CACHE {
        import from importlib.metadata { version as pkg_version }
        try {
            _JAC_VERSION_CACHE.append(pkg_version('jaclang'));
        } except Exception {
            _JAC_VERSION_CACHE.append("0.0.0");
        }
    }
    return _JAC_VERSION_CACHE[0];
}

def _toolchain_env_fingerprint -> str {
    h = hashlib.sha256();
    h.update(jaclang_version().encode());
    h.update(struct.pack('<H', (sys.version_info.major << 8) | sys.version_info.minor));
    h.update(struct.pack('<H', FORMAT_VERSION));
    return h.hexdigest();
}

def _project_env_fingerprint(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_module_client_kind(source_path).encode());
    h.update(_module_codespace_mode(source_path).encode());
    import from jaclang.jac0core.placement_pins { pins_digest, config_kind_space }
    h.update(pins_digest(source_path).encode());
    h.update(config_kind_space(source_path).encode());
    import from jaclang.jac0core.service_cut { cut_digest }
    h.update(cut_digest(source_path).encode());
    import from jaclang.jac0core.compile_options { effective_codegen_fingerprint }
    h.update(effective_codegen_fingerprint().encode());
    return h.hexdigest();
}

def _full_env_fingerprint(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_toolchain_env_fingerprint().encode());
    h.update(_project_env_fingerprint(source_path).encode());
    return h.hexdigest();
}

def module_env_fingerprint(source_path: str) -> str {
    h = hashlib.sha256();
    if source_path.endswith('.pyi') {
        h.update(_toolchain_env_fingerprint().encode());
    } else {
        h.update(_full_env_fingerprint(source_path).encode());
    }
    h.update(running_compiler_digest().encode());
    return h.hexdigest();
}

def compute_module_key(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_full_env_fingerprint(source_path).encode());
    h.update(compute_content_sha256(source_path).encode());
    for (rel, digest) in _related_files(source_path) {
        h.update(rel.encode());
        h.update(digest.encode());
    }
    return h.hexdigest();
}

def _read_key_section(data: bytes, sec_type: int) -> (str | None) {
    try {
        magic: any = SECTIONS_MAGIC;
        pos = data.find(magic, HEADER_SIZE);
        if pos < 0 {
            return None;
        }
        sections = read_sections(data, pos + len(magic));
        key_bytes = sections.get(sec_type);
        return key_bytes.decode('utf-8') if key_bytes is not None else None;
    } except Exception {
        return None;
    }
}

def read_modkey(data: bytes) -> (str | None) {
    return _read_key_section(data, SEC_MODKEY);
}

def read_envkey(data: bytes) -> (str | None) {
    return _read_key_section(data, SEC_ENVKEY);
}

def compute_stub_module_key(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_toolchain_env_fingerprint().encode());
    h.update(compute_content_sha256(source_path).encode());
    return h.hexdigest();
}

def module_cache_key(source_path: str) -> str {
    if source_path.endswith('.pyi') {
        return compute_stub_module_key(source_path);
    }
    return compute_module_key(source_path);
}

def module_jir_key_sections(source_path: str) -> dict[int, bytes] {
    return {
        SEC_MODKEY: module_cache_key(source_path).encode('utf-8'),
        SEC_ENVKEY: module_env_fingerprint(source_path).encode('utf-8')
    };
}

def jir_env_matches(jir_data: bytes, source_path: str) -> bool {
    stored = read_envkey(jir_data);
    if stored is None {
        return False;
    }
    return stored == module_env_fingerprint(source_path);
}

def jir_matches_source(jir_data: bytes, source_path: str) -> bool {
    stored = read_modkey(jir_data);
    if stored is None {
        return False;
    }
    return stored == module_cache_key(source_path);
}

def compute_precompile_module_key(source_path: str, compiler_digest: str = "") -> str {
    h = hashlib.sha256();
    h.update(module_cache_key(source_path).encode());
    h.update(b"|compiler=");
    h.update((compiler_digest or running_compiler_digest()).encode());
    return h.hexdigest();
}

def precompiled_jir_matches_source(
    jir_data: bytes, source_path: str, compiler_digest: str = ""
) -> bool {
    stored = read_modkey(jir_data);
    if stored is None {
        return False;
    }
    return stored == compute_precompile_module_key(source_path, compiler_digest);
}

def jir_cacheable_source_path(source_path: str) -> bool {
    return source_path.endswith('.pyi')
        or (source_path.endswith('.jac') and not source_path.endswith('.na.jac'));
}

def cache_mode -> tuple[bool, bool] {
    truthy: set = {'1', 'true', 'True', 'TRUE', 'yes', 'YES', 'on', 'ON'};
    rebuild = os.environ.get('JAC_REBUILD', '') in truthy;
    no_precompile = os.environ.get('JAC_NO_PRECOMPILE', '') in truthy;
    return (rebuild, no_precompile);
}

glob _jaclang_pkg_dir: str = str(Path(str(__file__)).resolve().parent.parent);

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
        for cache_dir in _glob.`glob(pattern, recursive=True) {
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
    jac_hash = zlib.crc32(jaclang_version().encode()) & 0xFFFFFFFF;
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

def is_module_cache_valid(source_path: str, cache_path: Path) -> bool {
    import from jaclang.jac0core.bccache { discover_annex_files, discover_style_annex }
    if not cache_path.exists() {
        return False;
    }
    try {
        data: bytes = cache_path.read_bytes();
        header = parse_header(data[:HEADER_SIZE]);
        if header is None or not header.is_compatible() {
            return False;
        }
        if not jir_env_matches(data, source_path) {
            return False;
        }
        cache_mtime = os.path.getmtime(cache_path);

        related = discover_annex_files(source_path, '.impl.jac')
            + discover_annex_files(source_path, '.test.jac');
        style = discover_style_annex(source_path);
        if style is not None {
            related.append(style);
        }
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

        return jir_matches_source(data, source_path);
    } except OSError {
        return False;
    }
}


def write_module_cache(
    source_path: str, bytecode: bytes, extra_sections: (dict[int, bytes] | None) = None
) -> bool {
    resolved_path = str(Path(source_path).resolve());
    if not jir_cacheable_source_path(resolved_path) {
        return False;
    }
    try {
        cache_path = get_module_cache_path(resolved_path);
        if is_module_cache_valid(resolved_path, cache_path) {
            return False;
        }
        cache_path.parent.mkdir(parents=True, exist_ok=True);
        sections: dict[int, bytes] = module_jir_key_sections(resolved_path);
        if extra_sections is not None {
            for (k, v) in extra_sections.items() {
                sections[k] = v;
            }
        }
        jir_bytes = write_precompiled_jir(bytecode, "", 0, sections);
        tmp_path = cache_path.with_suffix(f'.{os.getpid()}.tmp');
        try {
            tmp_path.write_bytes(jir_bytes);
            tmp_path.rename(cache_path);
        } finally {
            tmp_path.unlink(missing_ok=True);
        }
        return True;
    } except Exception {
        return False;
    }
}
