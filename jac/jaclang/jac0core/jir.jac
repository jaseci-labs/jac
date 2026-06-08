"""Jac IR (.jir) binary serialization for the unified intermediate representation.

Provides fast, compact serialization of the unitree (AST + symbol table + CFG)
for caching type-checked modules. Each node is serialized as a single record
encoding all its overlay data (AST core, scope, CFG, symbol references).

File format:
  Header (32 bytes) -> String Pool -> Unified Node Stream -> Link Table -> Metadata

Cache locations (platform-aware):
  Linux:   ~/.cache/jac/jir/
  macOS:   ~/Library/Caches/jac/jir/
  Windows: %LOCALAPPDATA%/jac/cache/jir/
"""
import hashlib;
import os;
import struct;
import sys;
import zlib;
import from pathlib { Path }

# --- Constants ---
"""JIR file magic bytes."""
glob MAGIC = b"JIR\x00";

"""Current format version. Increment on breaking changes."""
glob FORMAT_VERSION: int = 13;

"""Header size in bytes."""
glob HEADER_SIZE: int = 32;

"""Header struct format (little-endian)."""
glob HEADER_FMT: str = "<4sHHIIIIII";

"""Sentinel node ID for external references (e.g. builtins parent_scope)."""
glob EXTERNAL_REF: int = 0xFFFFFF;

# --- Section constants (extended JIR format) ---
"""Magic bytes marking the start of optional TLV sections after the AST payload."""
glob SECTIONS_MAGIC: any = b"JIRX";

"""Section type: raw marshal.dumps(code_object) bytes."""
glob SEC_BYTECODE: int = 0x02;

"""Section type: pickle.dumps(mtir_map, HIGHEST_PROTOCOL) bytes."""
glob SEC_MTIR: int = 0x03;

"""Section type: zlib.compress(llvm_ir_str.encode()) bytes."""
glob SEC_LLVM_IR: int = 0x04;

"""Section type: json.dumps(interop_dict).encode() bytes."""
glob SEC_INTEROP: int = 0x05;

"""Section type: post-optimization LLVM bitcode bytes.

Stores the native module's bitcode after optimization passes have run.
This is faster to parse than text IR (SEC_LLVM_IR) and produces properly
optimized code on cache reload. Includes a platform header:
  [triple_len: 2 LE] [triple: UTF-8] [bitcode ...]
"""
glob SEC_NATIVE_OBJ: int = 0x06;

"""Section type: json.dumps(module_structural_index).encode() bytes.

A flat, parse-only structural index of one module -- its archetypes (with
fields, member signatures, base classes) and walker entry points -- with no
cross-module pointers. Lets `CodeIntelligence` serve `project_map` / structural
queries on a cold start without re-running the semantic pipeline. Self-keyed by
the source's content hash (the JIR header's `source_content_hash`), so it needs
no transitive-dependency tracking: a parse-only index depends only on its own
source and spliced annex files. See `jaclang.compiler.code_intel`.
"""
glob SEC_SYMINDEX: int = 0x07;

"""Section type: the module identity key (UTF-8 hex SHA-256).

The canonical "what inputs produced this artifact" value: a digest over the
jaclang/python/format versions plus the source and every related (impl, test,
variant, style) file. Computed by `compute_module_key` and stamped into every
cached JIR (module cache and precompiled bundle alike). A single
`jir_matches_source` key-compare validates both tiers — no external manifest,
no mtime laundering. See `jaclang.jac0core.compiler`.
"""
glob SEC_MODKEY: int = 0x08;

"""Section terminator byte."""
glob SEC_TERMINATOR: int = 0xFF;

"""Header flag: JIR was shipped as a precompiled bundle (no live AST required)."""
glob FLAG_PRECOMPILED: int = 0x02;

"""Sentinel co_filename embedded in precompiled bundles at build time.

Patched back to the install directory on load (the bundle is built in CI at a
different absolute path). Shared by the generator and the loader.
"""
glob PRECOMPILE_SENTINEL: str = "__PKG_ROOT__";

"""Header flag: JIR is a bootstrap-only artifact (no AST payload, bytecode only)."""
glob FLAG_BOOTSTRAP: int = 0x04;

# --- Varint (LEB128) ---
"""Encode an unsigned integer as LEB128 varint, appending to buf."""
def write_varint(buf: bytearray, value: int) {
    while value >= 0x80 {
        buf.append((value & 0x7F) | 0x80);
        value >>= 7;
    }
    buf.append(value & 0x7F);
}

"""Decode an unsigned LEB128 varint from data at pos. Returns (value, new_pos)."""
def read_varint(data: (bytes | memoryview), pos: int) -> tuple[int, int] {
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

# --- String Pool ---
"""Deduplicated string table for identifiers, paths, and token values.

Strings are assigned sequential indices. The pool is serialized as:
  count: varint, then for each string: [length: varint, UTF-8 bytes].
"""
class StringPool {
    def init(self: StringPool) -> None;
    def intern(self: StringPool, s: str) -> int;
    def get(self: StringPool, idx: int) -> str;
    def __len__(self: StringPool) -> int;
    def serialize(self: StringPool) -> bytes;
}

"""Deserialize a string pool from data at pos. Returns (pool, new_pos)."""
def deserialize_string_pool(
    data: (bytes | memoryview), pos: int
) -> tuple[StringPool, int] {
    pool = StringPool();
    (count, pos) = read_varint(data, pos);
    for _ in range(count) {
        (length, pos) = read_varint(data, pos);
        s = bytes(data[pos:pos + length]).decode('utf-8');
        pool.intern(s);
        pos += length;
    }
    return (pool, pos);
}

# --- Header ---
"""JIR file header (32 bytes fixed size)."""
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

"""Create a JirHeader for the current environment."""
def create_header(
    source_hash: int,
    node_count: int,
    symbol_count: int,
    string_pool_size: int,
    flags: int = 0
) -> JirHeader {
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }
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

"""Deserialize a JirHeader from bytes. Returns None if magic/version mismatch."""
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

# --- Cache Directory ---
"""Get the platform-appropriate global cache directory for JIR files."""
def get_jir_cache_dir -> Path {
    if sys.platform == 'win32' {
        base = Path(os.environ.get('LOCALAPPDATA', Path.home() / 'AppData' / 'Local'));
        return base / 'jac' / 'cache' / 'jir';
    } elif sys.platform == 'darwin' {
        return Path.home() / 'Library' / 'Caches' / 'jac' / 'jir';
    } else {
        xdg_cache = os.environ.get('XDG_CACHE_HOME');
        base = Path(xdg_cache) if xdg_cache else (Path.home() / '.cache');
        return base / 'jac' / 'jir';
    }
}

"""Compute CRC32 of file content for fast-reject validation."""
def compute_content_crc32(file_path: str) -> int {
    with open(file_path, 'rb') as f {
        return zlib.crc32(f.read()) & 0xFFFFFFFF;
    }
}

"""Compute SHA-256 hex digest of file content."""
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

"""Enumerate the related files that contribute to a module's identity.

Returns ``(rel_key, sha256)`` pairs for every impl/test/variant/style annex
of ``source_path``, sorted for determinism. ``rel_key`` is the path relative
to the source's directory (location-independent, so a bundle built in CI
matches the same module installed elsewhere).
"""
def _related_files(source_path: str) -> list[tuple[str, str]] {
    import from jaclang.jac0core.bccache {
        discover_annex_files,
        discover_variant_files,
        discover_style_annex
    }
    src = Path(source_path).resolve();
    base_dir = src.parent;
    paths: set = set();
    paths |= set(discover_annex_files(str(src), '.impl.jac'));
    paths |= set(discover_annex_files(str(src), '.test.jac'));
    paths |= set(discover_variant_files(str(src)));
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

"""Compute the canonical identity key for a module (hex SHA-256).

Folds the jaclang version, Python version, JIR FORMAT_VERSION, the source
content, and every related file (impl/test/variant/style) — the single source
of truth for "what inputs produced this artifact." Stamped into cached JIRs as
SEC_MODKEY and checked by `jir_matches_source`. Mirrors the bootstrap key
formula in `meta_importer.py` (kept as a separate pure-Python implementation
only because it runs before any .jac is compiled).
"""
def compute_module_key(source_path: str) -> str {
    import from importlib.metadata { version as pkg_version }
    try {
        jac_ver = pkg_version('jaclang');
    } except Exception {
        jac_ver = "0.0.0";
    }
    h = hashlib.sha256();
    h.update(jac_ver.encode());
    h.update(struct.pack('<H', (sys.version_info.major << 8) | sys.version_info.minor));
    h.update(struct.pack('<H', FORMAT_VERSION));
    h.update(compute_content_sha256(source_path).encode());
    for (rel, digest) in _related_files(source_path) {
        h.update(rel.encode());
        h.update(digest.encode());
    }
    return h.hexdigest();
}

"""Read the SEC_MODKEY section from a JIR blob, or None if absent."""
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

"""Validate a JIR blob against its source by comparing embedded module keys.

The single validator shared by the module cache (slow path) and the
precompiled bundle. Returns False when the JIR carries no key (legacy/stale).
"""
def jir_matches_source(jir_data: bytes, source_path: str) -> bool {
    stored = read_modkey(jir_data);
    if stored is None {
        return False;
    }
    return stored == compute_module_key(source_path);
}

"""Parse cache-control env vars. Returns (rebuild, no_precompile).

JAC_REBUILD=1      -> ignore all on-disk caches, force a fresh compile (still writes).
JAC_NO_PRECOMPILE=1 -> skip the shipped _precompiled/ bundle.
"""
def cache_mode -> tuple[bool, bool] {
    truthy: set = {'1', 'true', 'True', 'TRUE', 'yes', 'YES', 'on', 'ON'};
    rebuild = os.environ.get('JAC_REBUILD', '') in truthy;
    no_precompile = os.environ.get('JAC_NO_PRECOMPILE', '') in truthy;
    return (rebuild, no_precompile);
}

"""Get the cache path for a stub file."""
def get_stub_cache_path(stub_path: str, content_hash: str) -> Path {
    cache_dir = get_jir_cache_dir() / 'stubs';
    name = Path(stub_path).stem;
    (major, minor) = (sys.version_info.major, sys.version_info.minor);
    return cache_dir / f"{name}.{content_hash[:16]}.cpython-{major}{minor}.jir";
}

"""Get the cache directory for a module based on its origin.

1. Source inside sys.prefix or jaclang package (installed/editable) → global cache
2. Source inside active project root → project .jac/cache/
3. Otherwise (standalone user file) → .jac/cache/ next to source
"""
glob _jaclang_pkg_dir: str = str(Path(__file__).resolve().parent.parent);

def _get_module_cache_dir(source_path: str) -> Path {
    resolved = Path(source_path).resolve();
    resolved_str = str(resolved);
    # Installed or editable-installed packages always use global cache
    if resolved_str.startswith(_jaclang_pkg_dir + os.sep) {
        return get_jir_cache_dir() / 'modules';
    }
    try {
        resolved.relative_to(sys.prefix);
        return get_jir_cache_dir() / 'modules';
    } except ValueError { }
    # Check for active project context
    try {
        config_mod = __import__("jaclang.project.config", fromlist=["get_config"]);
        cfg = config_mod.get_config();
        if cfg is not None and cfg.is_valid() and cfg.project_root is not None {
            try {
                resolved.relative_to(cfg.project_root);
                return cfg.get_cache_dir();
            } except ValueError { }
            # Source is outside project — use global cache
            return get_jir_cache_dir() / 'modules';
        }
    } except Exception { }
    # No project context — use .jac/cache/ next to source
    return resolved.parent / ".jac" / "cache";
}

"""Get the cache path for a user module."""
def get_module_cache_path(source_path: str) -> Path {
    cache_dir = _get_module_cache_dir(source_path);
    source = Path(source_path).resolve();
    path_hash = hashlib.sha256(str(source).encode()).hexdigest()[:8];
    (major, minor) = (sys.version_info.major, sys.version_info.minor);
    return cache_dir / f"{source.stem}.{path_hash}.cpython-{major}{minor}.jir";
}

"""Serialize a dict of section_type -> bytes into a TLV blob.

Returns bytes: SECTIONS_MAGIC + for each section [type(1) + len(4LE) + data]
+ SEC_TERMINATOR + 0x00000000.
"""
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

"""Parse TLV sections from data starting at start_pos.

start_pos should point to the byte immediately after SECTIONS_MAGIC.
Returns dict mapping section_type -> bytes. Returns {} on any error.
"""
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

"""Fast path: find and return raw bytecode section bytes without deserializing AST.

Scans for SECTIONS_MAGIC after the header, then reads only SEC_BYTECODE.
Returns None if no bytecode section is present.
"""
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

"""Build a minimal JIR file containing only a bytecode section (no AST).

Used for precompiled bundles (FLAG_PRECOMPILED) and the laundered copies they
seed into the module cache. The AST payload is an empty zlib-compressed single
byte (varint 0x00 = empty string pool). When `module_key` is given it is
stamped as a SEC_MODKEY section so the artifact self-validates via
`jir_matches_source`.
"""
def write_precompiled_jir(
    bytecode: bytes, module_key: str = "", flags: int = 0
) -> bytes {
    import from importlib.metadata { version as pkg_version }
    try {
        jac_hash = zlib.crc32(pkg_version('jaclang').encode()) & 0xFFFFFFFF;
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
    section_bytes = write_sections(sections);
    return header + empty_payload + section_bytes;
}

"""Check whether a module's JIR cache is still valid (hybrid invalidation).

Fast path: the cache is valid if it exists, was written by a compatible
compiler version, and its mtime is strictly newer than the source and every
related file (impl, test, variant, style). This avoids hashing on the hot
path of clean incremental builds.

Slow path: when mtime is ambiguous (cache older-or-equal than some input —
e.g. after a git checkout, touch, or copy), fall back to the embedded
SEC_MODKEY key-compare via `jir_matches_source`. This is the same validator
the precompiled bundle uses, so a stale-but-fresh-mtime cache can no longer
serve old bytecode.
"""
def is_module_cache_valid(source_path: str, cache_path: Path) -> bool {
    import from jaclang.jac0core.bccache {
        discover_annex_files,
        discover_variant_files,
        discover_style_annex
    }
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
        # Fast path: mtime says "definitely fresh" against all inputs.
        related = (
            discover_annex_files(source_path, '.impl.jac') + discover_annex_files(
                source_path, '.test.jac'
            ) + discover_variant_files(source_path)
        );
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
        # Slow path: mtime ambiguous -> trust the embedded module key.
        return jir_matches_source(data, source_path);
    } except OSError {
        return False;
    }
}
