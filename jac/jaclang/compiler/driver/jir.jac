import hashlib;
import ntpath;
import os;
import struct;
import sys;
import zlib;
import from contextvars { ContextVar }
import from pathlib { Path }

glob MAGIC = b"JIR\x00",
     FORMAT_VERSION: int = 30,
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
     SEC_PATH_ROOT: int = 0x15,
     SEC_EMITKEY: int = 0x16,
     SEC_TERMINATOR: int = 0xFF,
     FLAG_PRECOMPILED: int = 0x02,
     FLAG_CARRIED: int = 0x08,
     PRECOMPILE_SENTINEL: str = "__PKG_ROOT__",
     CT_PKG_PREFIX: str = "@jaclang/",
     CT_DEF_FLAG: str = "d:",
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

glob LOCK_POOL_SIZE: int = 64;

glob STALE_CODE_SECTIONS: tuple[int, ...] = (
         SEC_BYTECODE,
         SEC_INTEROP,
         SEC_MTIR,
         SEC_CLIENT
     );

obj NativeStamp {
    has compiler_digest: str = "",
        codegen_identity: str = "",
        triple: str = "",
        reloc: str = "pic",
        code_model: str = "small";

    def key -> str;
    def pack(payload: bytes) -> bytes;
    static def unpack_record(
        data: (bytes | None)
    ) -> (tuple[NativeStamp, bytes] | None);

    def matches(other: NativeStamp) -> bool;
}

def current_native_stamp(
    codegen_identity: str, triple: str, producer: str = ""
) -> NativeStamp;

def native_section_variants(data: (bytes | None)) -> dict[str, bytes];

def pack_native_variants(variants: dict[str, bytes]) -> bytes;

def native_section_payload(data: (bytes | None), want: NativeStamp) -> (bytes | None);

obj JirPaths {
    has roots: list[str] = [],
        base_dir: str = "";

    def encode(path: str, package_dir: str) -> str;
    def resolve(path: str) -> str;
    def to_bytes(package_dir: str = "") -> bytes;
    static def from_bytes(data: bytes | None, base_dir: str = "") -> JirPaths;
}

def read_jir_paths(data: bytes, base_dir: str = "") -> JirPaths;

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
) -> JirHeader;

def parse_header(data: (bytes | memoryview)) -> (JirHeader | None);

def get_jir_cache_dir -> Path;

def compute_content_sha256(file_path: str) -> str;

def _related_files(source_path: str) -> list[tuple[str, str]];


def is_compiler_tree_path(source_path: str) -> bool;

def _module_codespace_mode(source_path: str) -> str;

glob COMPILER_DIGEST_ROSTER_MARK: str = "roster",
     COMPILER_DIGEST_SUFFIXES: tuple[str, ...] = (".jac", ".py"),
     COMPILER_DIGEST_SKIP_DIRS: tuple[str, ...] = ("tests", "test", "__pycache__"),
     COMPILER_DIGEST_SKIP: tuple[str, ...] = ();

def compiler_input_rules(pkg_dir: str) -> tuple[tuple[str, ...], tuple[str, ...]];

def compiler_source_files(pkg_dir: str) -> list[str];

def compiler_identity_path(pkg_dir: str) -> Path;

def read_compiler_identity(pkg_dir: str) -> dict[str, str];

def declared_compiler_inputs(pkg_dir: str, recorded: dict[str, str]) -> list[str];

def resolve_compiler_input(pkg_dir: str, rel: str, recorded: dict[str, str]) -> str;

def fold_compiler_digest(rows: list[tuple[str, str]]) -> str;

def compiler_source_digest(pkg_dir: str) -> str;

def write_compiler_identity(pkg_dir: str, dest_dir: str) -> str;

glob _COMPILER_DIGEST_CACHE: list[str] = [],
     _COMPILER_INPUT_ROWS: dict[str, list[tuple[str, str]]] = {},
     _PY_EMITTER_DIGESTS: dict[str, str] = {},
     _NATIVE_PRODUCER_DIGESTS: dict[str, str] = {};

glob PY_EMITTER_ROOTS: tuple[str, ...] = ("compiler/backends/py", ),
     PY_EMITTER_EXCLUDED: tuple[str, ...] = ("compiler/backends/py/jacpython", ),
     DEV_NATIVE_PRODUCER: str = "abi:";

def _manifest_compiler_digest(pkg_dir: str) -> str;

def running_compiler_digest -> str;

def _rel_under(rel: str, roots: tuple[str, ...]) -> bool;

def py_emitter_digest -> str;

def require_exact_compiler_products;

def _handoff -> dict[str, object];

def dev_source -> str;

def dev_carry_enabled -> bool;

def abi_contract_digest(pkg_root: str) -> str;

def native_producer_digest(kernel_build: bool = False) -> str;

def _producer_kind(digest: str) -> str;

glob _COMPILER_GENERATION_CACHE: list[str] = [];

def compiler_generation -> str;

glob _JAC_VERSION_CACHE: list[str] = [];

def jaclang_version -> str;

def _toolchain_env_fingerprint -> str;

def _config_for_module(resolved: Path) -> any;

def _analysis_fingerprint_for(source_path: str) -> str;

def _check_policy_digest(source_path: str) -> str;

def _project_env_fingerprint_uncached(source_path: str) -> str;

def _full_env_fingerprint(source_path: str) -> str;

def _env_fingerprint_for(source_path: str) -> str;

def module_env_fingerprint(source_path: str) -> str;

def _module_projection(source_path: str) -> str;

glob _PREPARE_MEMO: ContextVar[dict[str, str] | None] = ContextVar(
         'jac_prepare_memo', `default=None
     );

def begin_prepare_memo -> any;

def end_prepare_memo(token: any);

def _memoized(kind: str, source_path: str, compute: any) -> str;

def _project_env_fingerprint(source_path: str) -> str;

def compute_module_key(source_path: str) -> str;

glob _WIRING_DIGESTS: dict[str, dict[str, str]] = {},
     _ARCH_STAMPS: dict[str, tuple[tuple[int, int, str], str]] = {};

def _arch_stamp(arch: str, package_name: str) -> (str | None);

def stored_wiring_digest(source_path: str) -> str;

def unit_source_digest(path: str) -> str;

def sidecar_unit_paths(sidecar: dict[str, any]) -> list[str];

def _compute_module_key_uncached(source_path: str) -> str;

def read_section_bytes(data: bytes, sec_type: int) -> (bytes | None);

def _read_key_section(data: bytes, sec_type: int) -> (str | None);

def read_modkey(data: bytes) -> (str | None);

def read_envkey(data: bytes) -> (str | None);

def _ct_dep_rows(text: str) -> list[tuple[(str, str, str)]];

def _row_digest(path: str, flag: str) -> str;

def read_ct_deps(data: bytes) -> list[tuple[(str, str, str)]];

def ct_dep_digest(path: str, with_annexes: bool = False) -> str;

def _ct_pkg_ref(path: str) -> str;

def _ct_row_path(stored: str, base: str) -> str;

def _ct_dep_store_path(path: str, base: str) -> str;

def _ct_dep_line(path: str, digest: str, flag: str, base: str) -> str;

def ct_deps_section(
    paths: list[str],
    body_paths: (list[str] | None) = None,
    base: str = "",
    definitions: (list[tuple[str, str]] | None) = None
) -> bytes;

def module_ct_deps_section(mod: any) -> (bytes | None);


glob _DEFINITION_TEXTS: dict[str, tuple[str, dict[str, list[str]]]] = {};

def _texts_of_spans(real: str, text: str, rows: list[str]) -> dict[str, list[str]];

def _source_and_digest(path: str) -> (tuple[str, str] | None);

def seed_definition_texts(rows: list[str]);

def _definition_texts(path: str) -> dict[str, list[str]];

glob _DEFINITION_DIGESTS: dict[str, str] = {};

def _definition_digest_file(key: str) -> Path;

def definition_digest(path: str, qualname: str) -> str;

def _compute_definition_digest(files: list[str], qualname: str) -> str;

def rebase_placement_section(raw: bytes, base: str) -> bytes;

def rebase_ct_deps_section(raw: bytes, base: str) -> bytes;

def _stale_ct_rows(
    rows: list[tuple[(str, str, str)]], base: str, first_only: bool = False
) -> list[str];

def ct_deps_fresh(data: bytes, base: str = "") -> bool;

def ct_dep_text_fresh(text: str, base: str = "") -> bool;

def stale_ct_dep_rows(text: str, base: str = "") -> list[str];

def module_ct_deps_text(mod: any) -> str;

def absolutize_ct_deps_section(raw: bytes, base: str) -> bytes;

obj DepRow {
    has path: str,
        digest: str = "",
        flags: str = "";
}

def deps_section(rows: list[DepRow]) -> bytes;

def read_dep_rows(data: bytes, base_dir: str = "") -> list[DepRow];

def read_dep_hashes(data: bytes, base_dir: str = "") -> list[tuple[str, str]];

def native_deps_section(dep_digests: dict[str, str]) -> bytes;

def parse_native_dep_rows(raw: bytes, anchor: str = "") -> list[tuple[str, str]];

def _dep_row_path(stored: str, base_dir: str) -> str;

def read_native_dep_hashes(
    data: bytes, stamp: NativeStamp, base_dir: str = "", anchor: str = ""
) -> list[tuple[str, str]];

def compute_stub_module_key(source_path: str) -> str;

def is_stub_like_path(source_path: str) -> bool;

def module_cache_key(source_path: str) -> str;

def module_jir_key_sections(source_path: str) -> dict[int, bytes];

def jir_env_matches(jir_data: bytes, source_path: str) -> bool;

def jir_matches_source(jir_data: bytes, source_path: str) -> bool;

def compute_precompile_module_key(source_path: str, compiler_digest: str = "") -> str;

def precompiled_jir_matches_source(
    jir_data: bytes, source_path: str, compiler_digest: str = "", package_root: str = ""
) -> bool;

def jir_cacheable_source_path(source_path: str) -> bool;

def cache_mode -> tuple[bool, bool];

def set_cache_mode(rebuild: (bool | None) = None, no_precompile: (bool | None) = None);

def bundle_dir_allowed(bundle_dir: str) -> bool;

glob _jaclang_pkg_dir: str = str(
         Path(str(__file__)).resolve().parent.parent.parent
     );

def _module_cache_root(source_path: str) -> Path;

def _get_module_cache_dir(source_path: str) -> Path;

def get_module_cache_path(source_path: str) -> Path;

glob _TOUCHED_GENERATIONS: set[str] = set();

def _touch_generation(cache_dir: Path);

def sweep_stale_generations(cache_root: Path, keep: str) -> int;

def _sweep_once(cache_root: Path);

def get_native_debug_dir(source_path: str) -> Path;

def scrub_cache_dirs(root_dir: str) -> int;

def write_sections(sections: (dict[int, bytes] | None)) -> bytes;

def read_sections_blob(data: bytes) -> dict[int, bytes];

def read_sections(data: (bytes | memoryview), start_pos: int) -> dict[int, bytes];

def _decode_sections(data: (bytes | memoryview), start_pos: int) -> dict[int, bytes];

def read_jir(cache_path: Path) -> bytes;

glob JIR_READ_CACHE_CAP: int = 256,
     JIR_READ_CACHE_BYTES: int = 128 * 1024 * 1024,
     SECTION_TABLE_CAP: int = 512,
     _JIR_READS: dict[str, tuple[tuple[int, int, int, int], bytes]] = {},
     _JIR_READ_TOTAL: list[int] = [0],
     _SECTION_TABLES: dict[int, tuple[bytes, int, dict[int, bytes]]] = {};

def read_bytecode_only(data: bytes) -> (bytes | None);

def write_precompiled_jir(
    bytecode: (bytes | None),
    module_key: str = "",
    flags: int = 0,
    extra_sections: (dict[int, bytes] | None) = None
) -> bytes;

def read_debug_source(data: bytes) -> (str | None);

def is_module_cache_valid(source_path: str, cache_path: Path) -> bool;

def module_cache_invalid_reason(source_path: str, cache_path: Path) -> str;


def _mergeable_sections(
    cache_path: Path,
    key_sections: dict[int, bytes],
    incoming: (dict[int, bytes] | None) = None
) -> tuple[dict[int, bytes], int, bool];

def merge_native_sections(
    existing: dict[int, bytes], incoming: dict[int, bytes]
) -> dict[int, bytes];

def _module_lock_path(cache_path: Path) -> Path;

def carried_module_bytecode(source_path: str) -> (tuple[bytes, bytes] | None);

def carried_native_sections(source_path: str, producer: str) -> dict[int, bytes];

def write_module_cache(
    source_path: str,
    bytecode: (bytes | None),
    extra_sections: (dict[int, bytes] | None) = None,
    flags: int = 0
) -> bool;

def drop_python_lane_products(source_path: str) -> None;

def patch_co_filenames_bytes(raw_bc: bytes, find: str, replace: str) -> bytes;
