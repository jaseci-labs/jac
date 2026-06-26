"""Common utilities shared between ELF and Mach-O linkers.

Extracts duplicated patterns: alignment, string table building,
section blob collection, virtual address resolution, relocation
patch-site resolution, and entry point lookup.
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

# ─── Static `ar` archive support (#6978 Phase 0.1a) ───────────
# A `.a` static archive is `!<arch>\n` followed by 60-byte member headers each
# introducing a relocatable object. Two name encodings appear in the wild: BSD
# (`#1/N`, the real name is the first N bytes of the member payload; used by
# macOS) and GNU (a `//` long-name string table referenced by `/offset`). The
# first member is a symbol index mapping every exported symbol to the header
# offset of its defining member -- BSD spells it `__.SYMDEF[ SORTED][_64]`, GNU
# spells it `/` (or `/SYM64/`). We reuse that index to pull only the members a
# program actually needs (transitive closure over undefined symbols) instead of
# linking the whole archive.
"""One relocatable object member of an `ar` archive. `header_offset` is the file
offset of the member's 60-byte header -- the key the symbol index points at."""
obj ArMember {
    has name: str,
        header_offset: int,
        data: bytes;
}

"""Parse `data` as an `ar` archive, returning its object members (the symbol
index, the `//` long-name table, and `__.SYMDEF*` are excluded). Returns []
when `data` is not an archive."""
def parse_ar_archive(data: bytes) -> list[ArMember];

"""Read an `ar` archive's symbol index into {symbol_name -> defining member's
header_offset}. Handles both the BSD `__.SYMDEF` ranlib table and the GNU `/`
big-endian table (32- and 64-bit). Returns {} when there is no index."""
def parse_ar_symbol_index(data: bytes) -> dict[str, int];

"""Select the minimal set of archive members needed to satisfy `root_undef`,
chasing each pulled member's own undefined symbols transitively through the
symbol index. Symbols not in the index (libc, other archives) are left for the
rest of the link to resolve. Result is ordered by header offset for
determinism."""
def select_ar_members(data: bytes, root_undef: list[str]) -> list[ArMember];
