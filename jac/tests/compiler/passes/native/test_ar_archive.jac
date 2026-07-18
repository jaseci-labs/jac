"""Unit tests for the static `ar` archive reader (#6978 Phase 0.1a).

`parse_ar_archive` / `parse_ar_symbol_index` / `select_ar_members` underpin
static-linking a bundled C floor archive: they pull only the members a program
transitively needs instead of the whole `.a`. The synthetic case builds a
minimal GNU archive in-memory so the parser + selection are covered with no
external dependency; the second case runs the real transitive closure (incl. the
Mach-O/ELF undefined-symbol scan) against a bundled `libexpat.a` when a pbs build
is present, and skips otherwise.
"""

import struct;
import from pathlib { Path }
import from jaclang.compiler.passes.native.linker_common {
    parse_ar_archive,
    parse_ar_symbol_index,
    select_ar_members
}


"""Build a 60-byte `ar` member header (GNU layout: space-padded fields)."""
def _ar_hdr(name: str, size: int) -> bytes {
    out = name.ljust(16) + "0".ljust(12) + "0".ljust(6) + "0".ljust(6) + "100644".ljust(
        8
    ) + str(size).ljust(10) + "`\n";
    return out.encode("ascii");
}


"""Assemble a minimal GNU archive: a `/` symbol index over two trivial members
`a.o` (defines sym_a) and `b.o` (defines sym_b). Member payloads are not real
objects, so the transitive scan finds no further deps -- selection is exactly
the directly-referenced members. Returns (archive_bytes, off_a, off_b)."""
def _mk_gnu_ar -> tuple[bytes, int, int] {
    obj_a = b"AAAA";  # 4 bytes (even -> no padding)
    obj_b = b"BBBBBB";  # 6 bytes
    # Layout is fully determined, so the member offsets the index must point at
    # are known up front: magic(8) + idx_hdr(60) + idx_data, then a.o, then b.o.
    idx_data_len = 4 + 8 + len(b"sym_a\x00sym_b\x00");  # count + 2 offsets + names
    off_idx_data = 8 + 60;
    off_a = off_idx_data + idx_data_len;  # a.o header offset
    off_b = off_a + 60 + len(obj_a);  # b.o header offset
    idx = struct.pack(">I", 2) + struct.pack(">I", off_a) + struct.pack(">I", off_b) + b"sym_a\x00sym_b\x00";
    archive = b"!<arch>\n" + _ar_hdr("/", len(idx)) + idx + _ar_hdr(
        "a.o/", len(obj_a)
    ) + obj_a + _ar_hdr("b.o/", len(obj_b)) + obj_b;
    return (archive, off_a, off_b);
}


test "ar parse + symbol index + selection (synthetic GNU)" {
    (archive, off_a, off_b) = _mk_gnu_ar();

    members = parse_ar_archive(archive);
    names = [m.name for m in members];
    assert names == ["a.o", "b.o"] , f"member names: {names}";
    assert members[0].header_offset == off_a;
    assert members[1].header_offset == off_b;
    assert members[0].data == b"AAAA";
    assert members[1].data == b"BBBBBB";

    idx = parse_ar_symbol_index(archive);
    assert idx == {"sym_a": off_a, "sym_b": off_b} , f"index: {idx}";

    # Selection pulls only the members that define the requested roots.
    one = [m.name for m in select_ar_members(archive, ["sym_a"])];
    assert one == ["a.o"] , f"select sym_a: {one}";
    both = [m.name for m in select_ar_members(archive, ["sym_a", "sym_b"])];
    assert both == ["a.o", "b.o"] , f"select both: {both}";
    # A symbol the archive does not define pulls nothing (resolved elsewhere).
    none = select_ar_members(archive, ["not_here"]);
    assert none == [] , f"select unknown: {[m.name for m in none]}";
}


"""Locate a bundled libexpat.a from any pbs build, or None."""
def _find_bundled_expat -> (str | None) {
    jac_dir = Path(__file__).resolve().parents[4];
    hits = list(jac_dir.glob(".pbs-build/*/python/build/lib/libexpat.a"));
    return str(hits[0]) if hits else None;
}


test "ar transitive member selection over bundled libexpat (skip if absent)" {
    arch = _find_bundled_expat();
    if arch is None {
        return;  # no pbs build staged here -- nothing to exercise
    }
    data = Path(arch).read_bytes();

    members = parse_ar_archive(data);
    names = [m.name for m in members];
    assert "xmlparse.o" in names , f"expected xmlparse.o among {names}";

    idx = parse_ar_symbol_index(data);
    # Mach-O mangles a leading underscore; ELF does not.
    ver = "_XML_ExpatVersion" if "_XML_ExpatVersion" in idx else "XML_ExpatVersion";
    assert ver in idx , "XML_ExpatVersion not in symbol index";
    ver_off = idx[ver];
    defining = [
        m.name
        for m in members
        if m.header_offset == ver_off
    ];
    assert defining == ["xmlparse.o"] , f"XML_ExpatVersion defined in {defining}";

    # Transitive closure must pull the defining member, chase its own undefined
    # symbols, and still leave at least one unrelated member out (proof it
    # narrows rather than dragging in the whole archive).
    sel = [m.name for m in select_ar_members(data, [ver])];
    assert "xmlparse.o" in sel , f"selection missing xmlparse.o: {sel}";
    assert len(sel) < len(members) , f"selection {sel} should be a strict subset";
}
