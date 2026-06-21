"""Shared linker utility implementations."""

impl _align(value: int, alignment: int) -> int {
    if alignment <= 1 {
        return value;
    }
    return (value + alignment - 1) & ~(alignment - 1);
}


impl _build_strtab(
    strings: list[str], initial_bytes: bytes = b"\x00"
) -> tuple[bytes, dict[str, int]] {
    data = bytearray(initial_bytes);
    offsets: dict[str, int] = {};
    for s in strings {
        if s not in offsets {
            offsets[s] = len(data);
            data.extend(s.encode("utf-8") + b"\x00");
        }
    }
    return (bytes(data), offsets);
}


"""Align blob, append data (with BSS zero-fill if mem_size > data),
return the offset where data was placed."""
impl _append_to_blob(
    blob: bytearray, data: bytes, alignment: int, mem_size: int
) -> int {
    aligned_off = _align(len(blob), max(alignment, 1));
    blob.extend(b"\x00" * (aligned_off - len(blob)));
    result_off = len(blob);
    if len(data) > 0 {
        blob.extend(data);
        if mem_size > len(data) {
            blob.extend(b"\x00" * (mem_size - len(data)));
        }
    } else {
        blob.extend(b"\x00" * mem_size);
    }
    return result_off;
}


impl _resolve_seg_vaddr(
    seg: str, seg_off: int, code_vaddr: int, rodata_vaddr: int, data_vaddr: int
) -> int {
    if seg == "code" {
        return code_vaddr + seg_off;
    } elif seg == "rodata" {
        return rodata_vaddr + seg_off;
    } elif seg == "data" {
        return data_vaddr + seg_off;
    }
    return 0;
}


"""Resolve a relocation's patch site. Locates the output blob holding
`target_sec` and returns (patch_buf, patch_off, patch_vaddr): the buffer to
write into, the byte offset of the fixup within that buffer, and the final
virtual address of the fixup. Returns None when `target_sec` is not placed in
the loadable image (e.g. metadata like .eh_frame), so the caller skips it.

A section sits at `sec_off` within its segment's blob, and that blob loads at
`<seg>_vaddr`; the fixup is `reloc_offset` bytes into the section. So both the
buffer offset and the vaddr are `sec_off + reloc_offset` past the segment base.
This is the arithmetic every ELF/Mach-O relocation loop (executable and
shared-object) used to inline by hand — centralized here so the two cannot
drift. (ELF previously added `sec_off` a second time to the vaddr, which only
agreed with the correct value while a segment held a single section, i.e.
`sec_off == 0`; this unifies on the correct form.)"""
impl _resolve_patch_site(
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
) -> tuple[bytearray, int, int] | None {
    if target_sec in code_sections {
        sec_off = code_sections[target_sec][0];
        return (
            code_bytes,
            sec_off + reloc_offset,
            code_vaddr + sec_off + reloc_offset
        );
    } elif target_sec in rodata_sections {
        sec_off = rodata_sections[target_sec][0];
        return (
            rodata_bytes,
            sec_off + reloc_offset,
            rodata_vaddr + sec_off + reloc_offset
        );
    } elif target_sec in data_sections {
        sec_off = data_sections[target_sec][0];
        return (
            data_bytes,
            sec_off + reloc_offset,
            data_vaddr + sec_off + reloc_offset
        );
    }
    return None;
}


impl _find_entry_vaddr(
    local_sym_map: dict[str, tuple[str, int]], code_vaddr: int
) -> int {
    for name in ["_start", "main"] {
        local = local_sym_map.get(name);
        if local is not None {
            (seg, seg_off) = local;
            if seg == "code" {
                return code_vaddr + seg_off;
            }
        }
    }
    return code_vaddr;
}
