"""Common utilities shared between ELF and Mach-O linkers.

Extracts duplicated patterns: alignment, string table building,
section blob collection, virtual address resolution, patch target
dispatch, and entry point lookup.
"""

def _align(value: int, alignment: int) -> int;

def _build_strtab(
    strings: list[str], initial_bytes: bytes = b"\x00"
) -> tuple[bytes, dict[str, int]];

def _append_to_blob(
    blob: bytearray, data: bytes, alignment: int, mem_size: int
) -> int;

def _resolve_seg_vaddr(
    seg: str, seg_off: int, code_vaddr: int, rodata_vaddr: int, data_vaddr: int
) -> int;

def _find_patch_target(
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
