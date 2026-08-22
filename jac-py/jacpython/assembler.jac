# Compiler assembler for the P4 back track (PLAN.md P0.10 / P0.11 slice).
#
# Turns a prepared_cfg (flat IR from flowgraph) into a native PyCode: EXTENDED_ARG
# folding, mandatory CACHE padding, deterministic const/name tables, PEP 626 line
# table (ported from CPython 3.14 Python/assemble.c), and exception-table
# encoding for comprehension cleanup regions.
#
# Product module: imports flowgraph + compiler_ir + opcode_meta + objects only.

import from objects { PyCode }
import from opcode_meta { OP_CACHE, OP_EXTENDED_ARG, opcode_cache_count, }
import from compiler_ir {
    cinstr,
    cloc,
    loc,
    same_loc,
    NO_LINE,
    instr_size_codeunits,
    except_region,
}
import from flowgraph { verified_cfg, flatten_blocks }

glob CONTINUATION_BIT: int = 64;

def append_except_varint(out: list[int], value: int, first_msb: int) {
    msb = first_msb;
    if value >= 1 << 18 {
        out.append(((value >> 18) & 0x3F) | CONTINUATION_BIT | msb);
        msb = 0;
    }
    if value >= 1 << 12 {
        out.append(((value >> 12) & 0x3F) | CONTINUATION_BIT | msb);
        msb = 0;
    }
    if value >= 1 << 6 {
        out.append(((value >> 6) & 0x3F) | CONTINUATION_BIT | msb);
        msb = 0;
    }
    out.append((value & 0x3F) | msb);
}

def region_start_offset(reg: except_region, block_starts: list[int]) -> int {
    if reg.start_block < 0 or reg.start_block >= len(block_starts) {
        return 2147483647;
    }
    return block_starts[reg.start_block];
}

# CPython encodes co_exceptiontable entries sorted by protected-range start.
def sort_except_region_indices(
    regions: list[except_region], block_starts: list[int]
) -> list[int] {
    indices: list[int] = [];
    ri = 0;
    while ri < len(regions) {
        indices.append(ri);
        ri = ri + 1;
    }
    ni = 0;
    while ni < len(indices) {
        nj = ni + 1;
        while nj < len(indices) {
            si = region_start_offset(regions[indices[ni]], block_starts);
            sj = region_start_offset(regions[indices[nj]], block_starts);
            if sj < si {
                tmp = indices[ni];
                indices[ni] = indices[nj];
                indices[nj] = tmp;
            }
            nj = nj + 1;
        }
        ni = ni + 1;
    }
    return indices;
}

def assemble_exception_table(
    regions: list[except_region], block_starts: list[int]
) -> list[int] {
    out: list[int] = [];
    order = sort_except_region_indices(regions, block_starts);
    oi = 0;
    while oi < len(order) {
        reg = regions[order[oi]];
        if reg.start_block < 0
            or reg.end_block < 0
            or reg.handler_block < 0
            or reg.start_block >= len(block_starts)
            or reg.end_block >= len(block_starts)
            or reg.handler_block >= len(block_starts) {
            oi = oi + 1;
            continue;
        }
        start = block_starts[reg.start_block];
        end = block_starts[reg.end_block];
        target = block_starts[reg.handler_block];
        if end <= start {
            oi = oi + 1;
            continue;
        }
        depth = reg.stack_depth - 1;
        if reg.preserve_lasti {
            depth = depth - 1;
        }
        if depth < 0 {
            depth = 0;
        }
        depth_lasti = depth << 1;
        if reg.preserve_lasti {
            depth_lasti = depth_lasti | 1;
        }
        append_except_varint(out, start, 128);
        append_except_varint(out, end - start, 0);
        append_except_varint(out, target, 0);
        append_except_varint(out, depth_lasti, 0);
        oi = oi + 1;
    }
    return out;
}

# ---------------- bytecode emission ----------------
def emit_instr(code: list[int], ins: cinstr) {
    oparg = ins.oparg;
    op = ins.opcode;
    # EXTENDED_ARG chain, high bytes first (assemble write_instr fall-through).
    if oparg > 0xFFFFFF {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 24) & 0xFF);
    }
    if oparg > 0xFFFF {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 16) & 0xFF);
    }
    if oparg > 0xFF {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 8) & 0xFF);
    }
    code.append(op);
    code.append(oparg & 0xFF);
    caches = opcode_cache_count(op);
    ci = 0;
    while ci < caches {
        code.append(OP_CACHE);
        code.append(0);
        ci = ci + 1;
    }
}

# ---------------- PEP 626 line table (ported from Python/assemble.c) ----------------
# Linetable location-entry kind codes (Include/cpython/code.h).
glob LI_SHORT0: int = 0,
     LI_ONE_LINE0: int = 10,
     LI_NO_COLUMNS: int = 13,
     LI_LONG: int = 14,
     LI_NONE: int = 15;

def write_varint(out: list[int], val: int) {
    v = val;
    while v >= 64 {
        out.append(64 | (v & 63));
        v = v >> 6;
    }
    out.append(v);
}

def write_signed_varint(out: list[int], val: int) {
    v = val;
    if v < 0 {
        # (0 - val) << 1 | 1, matching CPython's unsigned conversion.
        write_varint(out, (((0 - v) << 1) | 1));
    } else {
        write_varint(out, v << 1);
    }
}

def write_entry_start(out: list[int], code: int, length: int) {
    out.append(128 | (code << 3) | (length - 1));
}

def write_location_info_entry(out: list[int], st: lintable_state, lc: cloc) -> None {
    if lc.lineno == NO_LINE {
        write_entry_start(out, LI_NONE, st.length);
        return;
    }
    line_delta = lc.lineno - st.a_lineno;
    column = lc.col_offset;
    end_column = lc.end_col_offset;
    if column < 0 or end_column < 0 {
        if lc.end_lineno == lc.lineno or lc.end_lineno < 0 {
            write_entry_start(out, LI_NO_COLUMNS, st.length);
            write_signed_varint(out, line_delta);
            st.a_lineno = lc.lineno;
            return;
        }
    } elif lc.end_lineno == lc.lineno {
        if line_delta == 0
            and column < 80
            and end_column >= column
            and end_column - column < 16 {
            column_group = column >> 3;
            write_entry_start(out, LI_SHORT0 + column_group, st.length);
            out.append(((column & 7) << 4) | (end_column - column));
            # short form does NOT update a_lineno (matches CPython).
            return;
        }
        if line_delta >= 0 and line_delta < 3 and column < 128 and end_column < 128 {
            write_entry_start(out, LI_ONE_LINE0 + line_delta, st.length);
            out.append(column);
            out.append(end_column);
            st.a_lineno = lc.lineno;
            return;
        }
    }
    write_entry_start(out, LI_LONG, st.length);
    write_signed_varint(out, lc.lineno - st.a_lineno);
    end_ln = lc.end_lineno;
    if end_ln < 0 {
        end_ln = lc.lineno;
    }
    write_varint(out, end_ln - lc.lineno);
    write_varint(out, column + 1);
    write_varint(out, end_column + 1);
    st.a_lineno = lc.lineno;
}

# Per-call mutable state threaded through the location encoder (CPython's
# `struct assembler` a_lineno + a_location_off).
obj lintable_state {
    has a_lineno: int = 1,
        length: int = 0;
}

# Emit a run of `isize` code units all carrying location `lc`, chunked into
# length<=8 entries (assemble_emit_location).
def emit_location_run(
    out: list[int], st: lintable_state, lc: cloc, isize: int
) -> None {
    if isize == 0 {
        return;
    }
    remaining = isize;
    while remaining > 8 {
        st.length = 8;
        write_location_info_entry(out, st, lc);
        remaining = remaining - 8;
    }
    st.length = remaining;
    write_location_info_entry(out, st, lc);
}

# Port of assemble_location_info: group consecutive same-location instructions,
# summing code-unit sizes, and emit one entry per group (chunked at 8).
def assemble_linetable(flat: list[cinstr], firstlineno: int) -> list[int] {
    out: list[int] = [];
    st = lintable_state(a_lineno=firstlineno, length=0);
    cur: cloc = loc(NO_LINE, NO_LINE, -1, -1);
    size = 0;
    i = 0;
    while i < len(flat) {
        ins = flat[i];
        if not same_loc(cur, ins.loc) {
            emit_location_run(out, st, cur, size);
            cur = ins.loc;
            size = 0;
        }
        size = size + instr_size_codeunits(ins);
        i = i + 1;
    }
    emit_location_run(out, st, cur, size);
    return out;
}

# ---------------- assemble ----------------
def assemble(cfg: verified_cfg) -> PyCode {
    u = cfg.unit;
    flat = cfg.flat;
    stacksize = cfg.stacksize;
    code: list[int] = [];
    i = 0;
    while i < len(flat) {
        emit_instr(code, flat[i]);
        i = i + 1;
    }
    linetable = assemble_linetable(flat, u.firstlineno);
    block_starts = cfg.block_starts;
    if len(block_starts) == 0 {
        fr = flatten_blocks(u);
        block_starts = fr.block_starts;
    }
    exctab = assemble_exception_table(u.except_regions, block_starts);
    return PyCode(
        t="code",
        argcount=u.argcount,
        posonlyargcount=u.posonlyargcount,
        kwonlyargcount=u.kwonlyargcount,
        stacksize=stacksize,
        flags=u.flags,
        co_code=code,
        consts=u.consts,
        names=u.names,
        varnames=u.varnames,
        cellvars=u.cellvars,
        freevars=u.freevars,
        filename=u.filename,
        name=u.name,
        qualname=u.qualname,
        firstlineno=u.firstlineno,
        linetable=linetable,
        exceptiontable=exctab
    );
}
