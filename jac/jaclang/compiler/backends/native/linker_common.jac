def _align(value: int, alignment: int) -> int;

def read_uleb128(b: bytes, o: int) -> tuple[int, int];

def read_sleb128(b: bytes, o: int) -> tuple[int, int];

def encode_uleb128(v: int) -> bytes;

def encode_uleb128_padded5(v: int) -> bytes;

def encode_sleb128(v: int) -> bytes;

def read_leb_name(b: bytes, o: int) -> tuple[str, int];


def _build_strtab(
    strings: list[str], initial_bytes: bytes = b"\x00"
) -> tuple[bytes, dict[str, int]];

def _append_to_blob(
    blob: bytearray, data: bytes, alignment: int, mem_size: int
) -> int;

def _resolve_seg_vaddr(
    seg: str, seg_off: int, code_vaddr: int, rodata_vaddr: int, data_vaddr: int
) -> int;

def _resolve_patch_site(
    reloc_offset: int,
    target_sec: str,
    code_sections: dict[str, tuple[int, int]],
    rodata_sections: dict[str, tuple[int, int]],
    data_sections: dict[str, tuple[int, int]],
    code_bytes: bytearray,
    rodata_bytes: bytearray,
    data_bytes: bytearray,
    code_vaddr: int,
    rodata_vaddr: int,
    data_vaddr: int
) -> tuple[bytearray, int, int] | None;

def _find_entry_vaddr(
    local_sym_map: dict[str, tuple[str, int]], code_vaddr: int
) -> int;

obj ArMember {
    has name: str,
        header_offset: int,
        data: bytes;
}

def parse_ar_archive(data: bytes) -> list[ArMember];

def parse_ar_symbol_index(data: bytes) -> dict[str, int];

def select_ar_members(data: bytes, root_undef: list[str]) -> list[ArMember];

def object_undefined_symbols(mem: bytes) -> list[str];
