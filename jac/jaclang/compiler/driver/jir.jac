import hashlib;
import os;
import struct;
import sys;
import zlib;
import from pathlib { Path }
import from jaclang.jac0core.cache_paths { FileLock, atomic_write }

glob MAGIC = b"JIR\x00",
     FORMAT_VERSION: int = 28,
     HEADER_SIZE: int = 32,
     HEADER_FMT: str = "<4sHHIIIIII",
     EXTERNAL_REF: int = 0xFFFFFF,
     SECTIONS_MAGIC: any = b"JIRX",
     SEC_BYTECODE: int = 0x02,
     SEC_MTIR: int = 0x03,
     SEC_INTEROP: int = 0x05,
     SEC_NBITCODE: int = 0x06,
     SEC_SYMINDEX: int = 0x07,
     SEC_MODKEY: int = 0x08,
     SEC_DEBUG_SRC: int = 0x09,
     SEC_PLACEMENT: int = 0x0A,
     SEC_ENVKEY: int = 0x0B,
     SEC_CTDEPS: int = 0x0C,
     SEC_IFACE: int = 0x0D,
     SEC_DEPS: int = 0x0E,
     SEC_DIAG: int = 0x0F,
     SEC_CLIENT: int = 0x10,
     SEC_NIFACE: int = 0x11,
     SEC_NOBJ: int = 0x12,
     SEC_NDEPS: int = 0x13,
     SEC_NCTDEPS: int = 0x14,
     SEC_TERMINATOR: int = 0xFF,
     FLAG_PRECOMPILED: int = 0x02,
     PRECOMPILE_SENTINEL: str = "__PKG_ROOT__",
     FLAG_BOOTSTRAP: int = 0x04;

glob NATIVE_SECTIONS: tuple[int, ...] = (
         SEC_NBITCODE,
         SEC_NIFACE,
         SEC_NOBJ,
         SEC_NDEPS,
         SEC_NCTDEPS
     ),
     NATIVE_STAMP_MAGIC: bytes = b"JNS1",
     NATIVE_VARIANTS_MAGIC: bytes = b"JNV1";

obj NativeStamp {
    has compiler_digest: str = "",
        codegen_identity: str = "",
        triple: str = "",
        reloc: str = "pic",
        code_model: str = "small";

    def key -> str {
        return "\x1f".join(
            [
                self.compiler_digest,
                self.codegen_identity,
                self.triple,
                self.reloc,
                self.code_model
            ]
        );
    }

    def pack(payload: bytes) -> bytes {
        head = self.key().encode("utf-8");
        record = NATIVE_STAMP_MAGIC + struct.pack("<I", len(head)) + head + payload;
        return pack_native_variants({self.key(): record});
    }

    static def unpack_record(
        data: (bytes | None)
    ) -> (tuple[NativeStamp, bytes] | None) {
        if data is None or len(data) < 8 or data[:4] != NATIVE_STAMP_MAGIC {
            return None;
        }
        (head_len, ) = struct.unpack_from("<I", data, 4);
        if len(data) < 8 + head_len {
            return None;
        }
        try {
            parts = data[8:8 + head_len].decode("utf-8").split("\x1f");
        } except Exception {
            return None;
        }
        if len(parts) != 5 {
            return None;
        }
        return (
            NativeStamp(
                compiler_digest=parts[0],
                codegen_identity=parts[1],
                triple=parts[2],
                reloc=parts[3],
                code_model=parts[4]
            ),
            data[8 + head_len:]
        );
    }

    def matches(other: NativeStamp) -> bool {
        return self.key() == other.key();
    }
}

def current_native_stamp(codegen_identity: str, triple: str) -> NativeStamp {
    return NativeStamp(
        compiler_digest=running_compiler_digest(),
        codegen_identity=codegen_identity,
        triple=triple
    );
}

def native_section_variants(data: (bytes | None)) -> dict[str, bytes] {
    variants: dict[str, bytes] = {};
    if data is None or len(data) < 8 or data[:4] != NATIVE_VARIANTS_MAGIC {
        return variants;
    }
    (count, ) = struct.unpack_from("<I", data, 4);
    pos = 8;
    for _ in range(count) {
        if pos + 4 > len(data) {
            return {};
        }
        (size, ) = struct.unpack_from("<I", data, pos);
        pos += 4;
        if size > len(data) - pos {
            return {};
        }
        record = data[pos:pos + size];
        found = NativeStamp.unpack_record(record);
        if found is None or found[0].key() in variants {
            return {};
        }
        variants[found[0].key()] = record;
        pos += size;
    }
    return variants if pos == len(data) else {};
}

def pack_native_variants(variants: dict[str, bytes]) -> bytes {
    records = [variants[key] for key in sorted(variants)];
    return NATIVE_VARIANTS_MAGIC
        + struct.pack("<I", len(records))
        + b"".join(struct.pack("<I", len(record)) + record for record in records);
}

def native_section_payload(data: (bytes | None), want: NativeStamp) -> (bytes | None) {
    record = native_section_variants(data).get(want.key());
    found = NativeStamp.unpack_record(record);
    return found[1] if found is not None else None;
}

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
    import from jaclang.compiler.driver.bccache {
        discover_annex_files,
        discover_style_annex
    }
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


def is_compiler_tree_path(source_path: str) -> bool {
    try {
        resolved = str(Path(source_path).resolve());
    } except OSError {
        return False;
    }
    base = _jaclang_pkg_dir + os.sep;
    if not resolved.startswith(base) {
        return False;
    }
    rel = resolved[len(base):].replace(os.sep, "/");
    for digest_root in COMPILER_DIGEST_ROOTS {
        if rel == digest_root or rel.startswith(digest_root + "/") {
            return True;
        }
    }
    return False;
}

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
        import from jaclang.compiler.frontend.codeinfo { effective_default_codespace }
        return effective_default_codespace();
    } except Exception {
        return "server";
    }
}

glob COMPILER_DIGEST_ROOTS: tuple = (
         "jac0.py",
         "bootstrap_manifest.py",
         "meta_importer.py",
         "jac0core",
         "compiler",
         "runtime",
         "lib",
         "cli/cli_boot.jac",
         "project/tomlio.jac",
         "dist/precompile_bytecode.jac"
     ),
     COMPILER_DIGEST_SUFFIXES: tuple = (".jac", ".py"),
     COMPILER_DIGEST_SKIP_DIRS: tuple = ("tests", "test", "__pycache__"),
     COMPILER_DIGEST_SKIP: tuple = ();

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

def _digest_manifest_path(pkg_dir: str) -> Path {
    tag = hashlib.sha256(str(Path(pkg_dir).resolve()).encode()).hexdigest()[:8];
    return get_jir_cache_dir() / f"compiler_digest.{tag}.json";
}

def _manifest_compiler_digest(pkg_dir: str) -> str {
    import json;
    base = str(Path(pkg_dir));
    rels = compiler_source_files(base);
    manifest_path = _digest_manifest_path(base);
    entries: dict = {};
    stored_digest = "";
    try {
        raw = json.loads(manifest_path.read_text());
        entries = raw.get("entries", {}) or {};
        stored_digest = raw.get("digest", "") or "";
    } except Exception {
        entries = {};
        stored_digest = "";
    }
    changed = False;
    new_entries: dict = {};
    h = hashlib.sha256();
    for rel in rels {
        full = os.path.join(base, rel.replace("/", os.sep));
        st = os.stat(full);
        prev = entries.get(rel);
        if (
            isinstance(prev, list)
            and len(prev) == 3
            and prev[0] == st.st_mtime
            and prev[1] == st.st_size
        ) {
            sha = prev[2];
        } else {
            sha = compute_content_sha256(full);
            changed = True;
        }
        new_entries[rel] = [st.st_mtime, st.st_size, sha];
        h.update(rel.encode());
        h.update(sha.encode());
    }
    if len(new_entries) != len(entries) {
        changed = True;
    }
    digest = f"{len(rels)}:{h.hexdigest()}";
    if changed or digest != stored_digest {
        try {
            manifest_path.parent.mkdir(parents=True, exist_ok=True);
            tmp = manifest_path.with_suffix(f".{os.getpid()}.tmp");
            tmp.write_text(json.dumps({"entries": new_entries, "digest": digest}));
            tmp.rename(manifest_path);
        } except Exception {}
    }
    return digest;
}

def running_compiler_digest -> str {
    if not _COMPILER_DIGEST_CACHE {
        pinned = os.environ.get("JAC_COMPILER_DIGEST_PIN", "").strip();
        if pinned {
            _COMPILER_DIGEST_CACHE.append(f"pin:{pinned}");
        } else {
            try {
                digest = _manifest_compiler_digest(_jaclang_pkg_dir);
            } except Exception {
                digest = compiler_source_digest(_jaclang_pkg_dir);
            }
            _COMPILER_DIGEST_CACHE.append(digest);
        }
    }
    return _COMPILER_DIGEST_CACHE[0];
}

glob _COMPILER_GENERATION_CACHE: list = [];

def compiler_generation -> str {
    if not _COMPILER_GENERATION_CACHE {
        _COMPILER_GENERATION_CACHE.append(
            hashlib.sha256(running_compiler_digest().encode()).hexdigest()[:16]
        );
    }
    return _COMPILER_GENERATION_CACHE[0];
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

def _config_for_module(resolved: Path) -> any {
    config_mod = __import__("jaclang.project.config", fromlist=["get_config_for_path"]);
    return config_mod.get_config_for_path(resolved.parent);
}

def _analysis_fingerprint_for(source_path: str) -> str {
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    cfg: any = None;
    try {
        cfg = _config_for_module(Path(source_path).resolve());
    } except Exception {
        cfg = None;
    }
    import from jaclang.compiler.frontend.codeinfo { effective_native_target }
    mem_cfg = cfg.memory if cfg is not None else None;
    native_cfg = cfg.native if cfg is not None else None;
    return CompileOptions(
        memory_profile=(mem_cfg.profile if mem_cfg else "managed"),
        memory_enforce=(list(mem_cfg.enforce) if mem_cfg else []),
        memory_exempt=(list(mem_cfg.exempt) if mem_cfg else []),
        native_target=(
            effective_native_target() or (native_cfg.target if native_cfg else "")
        )
    ).analysis_fingerprint();
}

def _project_env_fingerprint(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_module_codespace_mode(source_path).encode());
    import from jaclang.compiler.placement.placement_pins {
        pins_digest,
        config_kind_space
    }
    import from jaclang.compiler.placement.workspace {
        app_fact_digest,
        app_for_path,
        workspace_for_path
    }
    h.update(pins_digest(source_path).encode());
    h.update(config_kind_space(source_path).encode());
    h.update(app_fact_digest(app_for_path(source_path)).encode());
    _ws = workspace_for_path(source_path);
    h.update((_ws.digest if _ws is not None else '').encode());
    if _ws is not None and _ws.explicit {
        import from jaclang.compiler.placement.ownership { consumer_graph }
        (_, ownership_digest) = consumer_graph(_ws);
        h.update(ownership_digest.encode());
    }
    h.update(_analysis_fingerprint_for(source_path).encode());
    return h.hexdigest();
}

def _full_env_fingerprint(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_toolchain_env_fingerprint().encode());
    h.update(_project_env_fingerprint(source_path).encode());
    return h.hexdigest();
}

def _env_fingerprint_for(source_path: str) -> str {
    if is_stub_like_path(source_path) or is_compiler_source_path(source_path) {
        return _toolchain_env_fingerprint();
    }
    return _full_env_fingerprint(source_path);
}

def module_env_fingerprint(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_env_fingerprint_for(source_path).encode());
    h.update(running_compiler_digest().encode());
    return h.hexdigest();
}

def compute_module_key(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_env_fingerprint_for(source_path).encode());
    h.update(compute_content_sha256(source_path).encode());
    for (rel, digest) in _related_files(source_path) {
        h.update(rel.encode());
        h.update(digest.encode());
    }
    return h.hexdigest();
}

def read_section_bytes(data: bytes, sec_type: int) -> (bytes | None) {
    try {
        magic: any = SECTIONS_MAGIC;
        pos = data.find(magic, HEADER_SIZE);
        if pos < 0 {
            return None;
        }
        sections = read_sections(data, pos + len(magic));
        return sections.get(sec_type);
    } except Exception {
        return None;
    }
}

def _read_key_section(data: bytes, sec_type: int) -> (str | None) {
    try {
        key_bytes = read_section_bytes(data, sec_type);
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

def _ct_dep_rows(text: str) -> list[tuple[(str, str, bool)]] {
    out: list[tuple[(str, str, bool)]] = [];
    for line in text.split("\n") {
        if "\t" not in line {
            continue;
        }
        parts = line.split("\t");
        digest = parts[1] if len(parts) > 1 else "";
        mode = parts[2] if len(parts) > 2 else "";
        out.append((parts[0], digest, mode == "b", ));
    }
    return out;
}

def read_ct_deps(data: bytes) -> list[tuple[(str, str, bool)]] {
    raw = _read_key_section(data, SEC_CTDEPS);
    return _ct_dep_rows(raw) if raw else [];
}

def ct_dep_digest(path: str, with_annexes: bool = False) -> str {
    try {
        h = hashlib.sha256();
        h.update(compute_content_sha256(path).encode());
        if with_annexes and path.endswith('.jac') {
            for (rel, digest) in _related_files(path) {
                h.update(rel.encode());
                h.update(digest.encode());
            }
        }
        return h.hexdigest();
    } except OSError {
        return "";
    }
}

def _ct_dep_store_path(path: str, base: str) -> str {
    if not base {
        return path;
    }
    try {
        if os.path.commonpath([path, base]) == base {
            return os.path.relpath(path, base);
        }
    } except ValueError {}
    return path;
}

def _ct_dep_line(path: str, digest: str, is_body: bool, base: str) -> str {
    flag = "b" if is_body else "";
    stored = _ct_dep_store_path(path, base);
    return f"{stored}\t{digest}\t{flag}";
}

def ct_deps_section(
    paths: list[str], body_paths: (list[str] | None) = None, base: str = ""
) -> bytes {
    body: set = set(body_paths or []);
    lines: list[str] = [];
    for path in sorted(set(paths) | body) {
        is_body = path in body;
        lines.append(_ct_dep_line(path, ct_dep_digest(path, is_body), is_body, base));
    }
    return "\n".join(lines).encode("utf-8");
}

def rebase_placement_section(raw: bytes, base: str) -> bytes {
    """A placement summary names its module by path; sealed under a
    package it names it under the package sentinel, so two seals of one
    tree are the same bytes wherever they were staged.""";
    import json as _json;
    try {
        parsed = _json.loads(raw.decode("utf-8"));
    } except Exception {
        return raw;
    }
    roots: list[str] = [];
    for cand in (os.path.normpath(base), os.path.realpath(base)) {
        if cand not in roots {
            roots.append(cand);
        }
    }

    def _rebase(value: any) -> any {
        if isinstance(value, str) {
            for base_dir in roots {
                if value == base_dir {
                    return PRECOMPILE_SENTINEL;
                }
                prefix = base_dir + os.sep;
                if value.startswith(prefix) {
                    return (
                        PRECOMPILE_SENTINEL
                        + "/"
                        + value[len(prefix):].replace(os.sep, "/")
                    );
                }
            }
            return value;
        }
        if isinstance(value, list) {
            return [_rebase(v) for v in value];
        }
        if isinstance(value, dict) {
            return {k: _rebase(v) for (k, v) in value.items()};
        }
        return value;
    }
    return _json.dumps(_rebase(parsed), sort_keys=True).encode("utf-8");
}

def rebase_ct_deps_section(raw: bytes, base: str) -> bytes {
    lines: list[str] = [];
    for (path, digest, is_body) in _ct_dep_rows(raw.decode("utf-8")) {
        lines.append(_ct_dep_line(path, digest, is_body, base));
    }
    return "\n".join(lines).encode("utf-8");
}

def _ct_rows_fresh(rows: list[tuple[(str, str, bool)]], base: str) -> bool {
    for (path, digest, is_body) in rows {
        full = path if os.path.isabs(path) else os.path.join(base, path);
        if not digest or ct_dep_digest(full, is_body) != digest {
            return False;
        }
    }
    return True;
}

def ct_deps_fresh(data: bytes, base: str = "") -> bool {
    return _ct_rows_fresh(read_ct_deps(data), base);
}

def ct_dep_text_fresh(text: str, base: str = "") -> bool {
    return _ct_rows_fresh(_ct_dep_rows(text), base);
}

def module_ct_deps_text(mod: any) -> str {
    return ct_deps_section(
        getattr(mod, "ct_file_deps", []) or [], getattr(mod, "ct_body_deps", []) or []
    ).decode(
        "utf-8"
    );
}

def absolutize_ct_deps_section(raw: bytes, base: str) -> bytes {
    lines: list[str] = [];
    for (path, digest, is_body) in _ct_dep_rows(raw.decode("utf-8")) {
        full = path
            if os.path.isabs(path)
            else os.path.normpath(os.path.join(base, path));
        lines.append(_ct_dep_line(full, digest, is_body, ""));
    }
    return "\n".join(lines).encode("utf-8");
}

obj DepRow {
    has path: str,
        digest: str = "",
        flags: str = "";
}

def deps_section(rows: list[DepRow]) -> bytes {
    lines: list[str] = [];
    for row in sorted(rows, key=lambda (r: DepRow) { r.path; }) {
        lines.append(f"{row.path}\t{row.digest}\t{row.flags}");
    }
    return "\n".join(lines).encode("utf-8");
}

def read_dep_rows(data: bytes, base_dir: str = "") -> list[DepRow] {
    raw = _read_key_section(data, SEC_DEPS);
    out: list[DepRow] = [];
    if not raw {
        return out;
    }
    for line in raw.split("\n") {
        if "\t" not in line {
            continue;
        }
        parts = line.split("\t");
        out.append(
            DepRow(
                path=_dep_row_path(parts[0], base_dir),
                digest=parts[1] if len(parts) > 1 else "",
                flags=parts[2] if len(parts) > 2 else ""
            )
        );
    }
    return out;
}

def _dep_row_path(stored: str, base_dir: str) -> str {
    prefix = PRECOMPILE_SENTINEL + "/";
    if base_dir and stored.startswith(prefix) {
        return os.path.normpath(os.path.join(base_dir, stored[len(prefix):]));
    }
    return stored;
}

def read_dep_hashes(data: bytes, base_dir: str = "") -> list[tuple[str, str]] {
    out: list[tuple[str, str]] = [];
    for row in read_dep_rows(data, base_dir) {
        out.append((row.path, row.digest, ));
    }
    return out;
}

def native_deps_section(dep_digests: dict[str, str]) -> bytes {
    import from jaclang.compiler.frontend.codeinfo { native_unit_ref }
    lines: list[str] = [];
    for path in sorted(dep_digests) {
        lines.append(f"{native_unit_ref(path)}\t{dep_digests[path]}");
    }
    return "\n".join(lines).encode("utf-8");
}

def parse_native_dep_rows(raw: bytes, anchor: str = "") -> list[tuple[str, str]] {
    import from jaclang.compiler.frontend.codeinfo { resolve_native_unit_ref }
    out: list[tuple[str, str]] = [];
    for line in raw.decode("utf-8").split("\n") {
        if "\t" not in line {
            continue;
        }
        (path, digest) = line.split("\t", 1);
        out.append((resolve_native_unit_ref(path, anchor), digest, ));
    }
    return out;
}

def read_native_dep_hashes(
    data: bytes, stamp: NativeStamp, base_dir: str = "", anchor: str = ""
) -> list[tuple[str, str]] {
    raw = native_section_payload(read_section_bytes(data, SEC_NDEPS), stamp);
    if not raw {
        return [];
    }
    return [
        (_dep_row_path(path, base_dir), digest, )
        for (path, digest) in parse_native_dep_rows(raw, anchor)
    ];
}

def compute_stub_module_key(source_path: str) -> str {
    h = hashlib.sha256();
    h.update(_toolchain_env_fingerprint().encode());
    h.update(compute_content_sha256(source_path).encode());
    return h.hexdigest();
}

def is_stub_like_path(source_path: str) -> bool {
    if source_path.endswith('.pyi') {
        return True;
    }
    if not source_path.endswith('.py') {
        return False;
    }
    normalized = source_path.replace(os.sep, '/');
    return '/site-packages/' in normalized or '/dist-packages/' in normalized;
}

def module_cache_key(source_path: str) -> str {
    if is_stub_like_path(source_path) {
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
    jir_data: bytes, source_path: str, compiler_digest: str = "", package_root: str = ""
) -> bool {
    stored = read_modkey(jir_data);
    if stored is None {
        return False;
    }
    return stored == compute_precompile_module_key(source_path, compiler_digest)
        and ct_deps_fresh(jir_data, package_root);
}

def jir_cacheable_source_path(source_path: str) -> bool {
    return is_stub_like_path(source_path)
        or (source_path.endswith('.jac') and not source_path.endswith('.na.jac'));
}

def cache_mode -> tuple[bool, bool] {
    truthy: set = {'1', 'true', 'True', 'TRUE', 'yes', 'YES', 'on', 'ON'};
    rebuild = os.environ.get('JAC_REBUILD', '') in truthy;
    no_precompile = os.environ.get('JAC_NO_PRECOMPILE', '') in truthy;
    return (rebuild, no_precompile);
}

glob _jaclang_pkg_dir: str = str(
         Path(str(__file__)).resolve().parent.parent.parent
     );

def _module_cache_root(source_path: str) -> Path {
    resolved = Path(source_path).resolve();
    resolved_str = str(resolved);

    if resolved_str.startswith(_jaclang_pkg_dir + os.sep) {
        return get_jir_cache_dir() / 'modules';
    }
    try {
        resolved.relative_to(sys.prefix);
        return get_jir_cache_dir() / 'modules';
    } except ValueError {}

    try {
        cfg = _config_for_module(resolved);
        if cfg is not None and cfg.is_valid() and cfg.project_root is not None {
            try {
                resolved.relative_to(cfg.project_root);
                return cfg.get_cache_dir();
            } except ValueError {}

            return get_jir_cache_dir() / 'modules';
        }
    } except Exception {}

    return resolved.parent / ".jac" / "cache";
}

def _get_module_cache_dir(source_path: str) -> Path {
    return _module_cache_root(source_path) / compiler_generation();
}

def get_module_cache_path(source_path: str) -> Path {
    cache_dir = _get_module_cache_dir(source_path);
    source = Path(source_path).resolve();
    path_hash = hashlib.sha256(str(source).encode()).hexdigest()[:8];
    (major, minor) = (sys.version_info.major, sys.version_info.minor);
    return cache_dir / f"{source.stem}.{path_hash}.cpython-{major}{minor}.jir";
}

glob GENERATION_TTL_DAYS: float = 14.0,
     _SWEPT_ROOTS: set[str] = set();

def generation_ttl_seconds -> float {
    raw = os.environ.get("JAC_CACHE_GENERATION_TTL_DAYS", "").strip();
    if not raw {
        return GENERATION_TTL_DAYS * 86400.0;
    }
    try {
        return max(0.0, float(raw)) * 86400.0;
    } except ValueError {
        return GENERATION_TTL_DAYS * 86400.0;
    }
}

def _is_generation_name(name: str) -> bool {
    if len(name) != 16 {
        return False;
    }
    for ch in name {
        if ch not in "0123456789abcdef" {
            return False;
        }
    }
    return True;
}

def sweep_stale_generations(cache_root: Path, keep: str) -> int {
    import shutil;
    import time;
    ttl = generation_ttl_seconds();
    if ttl <= 0.0 {
        return 0;
    }
    now = time.time();
    removed = 0;
    try {
        items = list(cache_root.iterdir());
    } except OSError {
        return 0;
    }
    for item in items {
        name = item.name;
        is_dir = item.is_dir();
        if is_dir {
            if name == keep or not (_is_generation_name(name) or name == "native") {
                continue;
            }
        } elif not name.endswith(".jir") {
            continue;
        }
        try {
            if now - item.stat().st_mtime <= ttl {
                continue;
            }
        } except OSError {
            continue;
        }
        if is_dir {
            shutil.rmtree(item, ignore_errors=True);
        } else {
            try {
                item.unlink();
            } except OSError {
                continue;
            }
        }
        removed += 1;
    }
    return removed;
}

def _sweep_once(cache_root: Path) {
    key = str(cache_root);
    if key in _SWEPT_ROOTS {
        return;
    }
    _SWEPT_ROOTS.add(key);
    try {
        sweep_stale_generations(cache_root, compiler_generation());
    } except Exception {}
}

def get_native_debug_dir(source_path: str) -> Path {
    return _get_module_cache_dir(source_path) / "native-debug";
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

def read_sections_blob(data: bytes) -> dict[int, bytes] {
    magic: any = SECTIONS_MAGIC;
    if not data.startswith(magic) {
        return {};
    }
    return read_sections(data, len(magic));
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
    } except Exception {}
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
    bytecode: (bytes | None),
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
    sections: dict[int, bytes] = {};
    if bytecode is not None {
        sections[SEC_BYTECODE] = bytecode;
    }
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
        if not ct_deps_fresh(data) {
            return False;
        }
        """Timestamps are not source identities: restores can preserve mtimes
        and annex deletion must invalidate the same way annex edits do.""";
        return jir_matches_source(data, source_path);
    } except OSError {
        return False;
    }
}


def _mergeable_sections(
    cache_path: Path, key_sections: dict[int, bytes]
) -> tuple[dict[int, bytes], int] {
    try {
        if not cache_path.exists() {
            return ({}, 0, );
        }
        data: bytes = cache_path.read_bytes();
        header = parse_header(data[:HEADER_SIZE]);
        if header is None or not header.is_compatible() {
            return ({}, 0, );
        }
        magic: any = SECTIONS_MAGIC;
        pos = data.find(magic, HEADER_SIZE);
        if pos < 0 {
            return ({}, 0, );
        }
        secs = read_sections(data, pos + len(magic));
        if secs.get(SEC_MODKEY) != key_sections.get(SEC_MODKEY) {
            return ({}, 0, );
        }
        if secs.get(SEC_ENVKEY) == key_sections.get(SEC_ENVKEY) {
            return (secs, header.flags, );
        }
        native_only: dict[int, bytes] = {
            sec: secs[sec]
            for sec in NATIVE_SECTIONS
            if sec in secs
        };
        return (native_only, 0, );
    } except Exception {
        return ({}, 0, );
    }
}

def merge_native_sections(
    existing: dict[int, bytes], incoming: dict[int, bytes]
) -> dict[int, bytes] {
    merged: dict[int, bytes] = {};
    before = native_section_variants(existing.get(SEC_NBITCODE));
    after = native_section_variants(incoming.get(SEC_NBITCODE));
    changed = {
        key
        for (key, value) in after.items()
        if before.get(key) != value
    };
    for tag in NATIVE_SECTIONS {
        variants = native_section_variants(existing.get(tag));
        if tag == SEC_NOBJ {
            for key in changed {
                variants.pop(key, None);
            }
        }
        if tag in incoming {
            updates = native_section_variants(incoming[tag]);
            digests = {key.split("\x1f")[0] for key in updates};
            variants = {
                key: value
                for (key, value) in variants.items()
                if key.split("\x1f")[0] in digests
            };
            variants.update(updates);
        }
        if tag in existing or tag in incoming {
            merged[tag] = pack_native_variants(variants);
        }
    }
    return merged;
}

def write_module_cache(
    source_path: str,
    bytecode: (bytes | None),
    extra_sections: (dict[int, bytes] | None) = None,
    flags: int = 0
) -> bool {
    resolved_path = str(Path(source_path).resolve());
    if not jir_cacheable_source_path(resolved_path) {
        return False;
    }
    try {
        cache_path = get_module_cache_path(resolved_path);
        key_sections = module_jir_key_sections(resolved_path);
        _sweep_once(_module_cache_root(resolved_path));
        with FileLock(cache_path.with_suffix(".lock")) {
            (existing, existing_flags) = _mergeable_sections(cache_path, key_sections);
            sections: dict[int, bytes] = {};
            sections.update(existing);
            sections.update(key_sections);
            if bytecode is not None {
                sections[SEC_BYTECODE] = bytecode;
            }
            if extra_sections is not None {
                for (k, v) in extra_sections.items() {
                    if k not in NATIVE_SECTIONS {
                        sections[k] = v;
                    }
                }
                if any(tag in extra_sections for tag in NATIVE_SECTIONS) {
                    sections.update(merge_native_sections(existing, extra_sections));
                }
            }
            merged_flags = flags | existing_flags;
            if existing and sections == existing and merged_flags == existing_flags {
                return False;
            }
            cache_path.parent.mkdir(parents=True, exist_ok=True);
            jir_bytes = write_precompiled_jir(None, "", merged_flags, sections);
            atomic_write(cache_path, jir_bytes);
            return True;
        }
    } except Exception as exc {
        import logging;
        logging.getLogger(__name__).warning(
            f"Could not write module cache for {resolved_path}: {exc}", exc_info=True
        );
        return False;
    }
}

def patch_co_filenames_bytes(raw_bc: bytes, find: str, replace: str) -> bytes {
    try {
        import marshal;
        import types as _types;
        code = marshal.loads(raw_bc);
        def _patch(c: _types.CodeType) -> _types.CodeType {
            new_filename = c.co_filename.replace(find, replace);
            new_consts = tuple(
                _patch(x) if isinstance(x, _types.CodeType) else x for x in c.co_consts
            );
            return c.replace(co_filename=new_filename, co_consts=new_consts);
        }
        return marshal.dumps(_patch(code));
    } except Exception {
        return raw_bc;
    }
}
