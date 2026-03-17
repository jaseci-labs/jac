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
import from typing { Any }

# --- Constants ---
"""JIR file magic bytes."""
glob MAGIC = b"JIR\x00";

"""Current format version. Increment on breaking changes."""
glob FORMAT_VERSION: int = 8;

"""Header size in bytes."""
glob HEADER_SIZE: int = 32;

"""Header struct format (little-endian)."""
glob HEADER_FMT: str = "<4sHHIIIIII";

"""Sentinel node ID for external references (e.g. builtins parent_scope)."""
glob EXTERNAL_REF: int = 0xFFFFFF;

# --- Section constants (extended JIR format) ---
"""Magic bytes marking the start of optional TLV sections after the AST payload."""
glob SECTIONS_MAGIC: Any = b"JIRX";

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

"""Section terminator byte."""
glob SEC_TERMINATOR: int = 0xFF;

"""Header flag: JIR was shipped as a precompiled bundle (no live AST required)."""
glob FLAG_PRECOMPILED: int = 0x02;

"""Header flag: JIR is a bootstrap-only artifact (no AST payload, bytecode only)."""
glob FLAG_BOOTSTRAP: int = 0x04;

# --- Varint (LEB128) ---
"""Encode an unsigned integer as LEB128 varint, appending to buf."""
def write_varint(buf: bytearray, value: int) -> None {
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
    has magic: Any = b"JIR\x00",
        format_version: int = FORMAT_VERSION,
        python_version: int = 0,
        jaclang_version_hash: int = 0,
        source_content_hash: int = 0,
        node_count: int = 0,
        symbol_count: int = 0,
        string_pool_size: int = 0,
        flags: int = 0;

    def to_bytes(self: JirHeader) -> bytes;
    def is_compatible(self: JirHeader) -> bool;
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
    magic: Any = SECTIONS_MAGIC;
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
        magic_bytes: Any = SECTIONS_MAGIC;
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

Used for bootstrap JIRs (FLAG_BOOTSTRAP) and precompiled bundles
(FLAG_PRECOMPILED). The AST payload is an empty zlib-compressed single byte
(varint 0x00 = empty string pool).
"""
def write_precompiled_jir(bytecode: bytes, source_hash: int, flags: int = 0) -> bytes {
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
        source_hash & 0xFFFFFFFF,
        0,
        0,
        0,
        flags
    );
    empty_payload = zlib.compress(bytes(1), 1);
    section_bytes = write_sections({SEC_BYTECODE: bytecode});
    return header + empty_payload + section_bytes;
}

"""Check whether a module's JIR cache is still valid.

The cache is valid if it exists, was written by a compatible compiler
version (same jaclang + Python), and is newer than the source file and
all its annex files (impl, test) and variant files (sv, cl, na).
"""
def is_module_cache_valid(source_path: str, cache_path: Path) -> bool {
    import from jaclang.jac0core.bccache { discover_annex_files, discover_variant_files }
    if not cache_path.exists() {
        return False;
    }
    try {
        # Check header compatibility (jaclang version, Python version)
        header_bytes: bytes = cache_path.read_bytes()[:HEADER_SIZE];
        header = parse_header(header_bytes);
        if header is None {
            return False;
        }
        if not header.is_compatible() {
            return False;
        }
        cache_mtime = os.path.getmtime(cache_path);
        if cache_mtime <= os.path.getmtime(source_path) {
            return False;
        }
        for annex in discover_annex_files(source_path) {
            try {
                if cache_mtime <= os.path.getmtime(annex) {
                    return False;
                }
            } except OSError {
                return False;
            }
        }
        for variant in discover_variant_files(source_path) {
            try {
                if cache_mtime <= os.path.getmtime(variant) {
                    return False;
                }
            } except OSError {
                return False;
            }
        }
        return True;
    } except OSError {
        return False;
    }
}
