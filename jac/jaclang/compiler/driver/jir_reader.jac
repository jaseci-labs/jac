import json;

glob JIR_MAGIC: bytes = b"JIR\x00",
     JIR_SECTIONS_MAGIC: bytes = b"JIRX",
     JIR_HEADER_SIZE: int = 32,
     JIR_FORMAT_VERSION: int = 30,
     JIR_SEC_TERMINATOR: int = 0xFF,
     JIR_STAMP_MAGIC: bytes = b"JNS1",
     JIR_VARIANTS_MAGIC: bytes = b"JNV1",
     JIR_STAMP_SEP: str = "\x1f",
     JIR_STAMP_FIELDS: int = 5;

obj JirHead {
    has magic: bytes = b"",
        format_version: int = 0,
        python_version: int = 0,
        jaclang_version_hash: int = 0,
        source_content_hash: int = 0,
        node_count: int = 0,
        symbol_count: int = 0,
        string_pool_size: int = 0,
        flags: int = 0;
}

obj JirPathRoots {
    has roots: list[str] = [],
        base: str = "",
        subdir: str = "";
}

def u16_at(data: bytes, pos: int) -> int;

def u32_at(data: bytes, pos: int) -> int;

def read_jir_head(data: bytes) -> (JirHead | None);

def sections_start(data: bytes) -> int;

def decode_sections(data: bytes, start_pos: int) -> dict[int, bytes];

def section_bytes(data: bytes, sec_type: int) -> (bytes | None);

def key_section(data: bytes, sec_type: int) -> (str | None);

def stamp_record(data: (bytes | None)) -> (tuple[list[str], bytes] | None);

def variant_records(data: (bytes | None)) -> dict[str, bytes];

def tab_rows(text: str) -> list[list[str]];

def path_roots_of(data: (bytes | None)) -> JirPathRoots;
