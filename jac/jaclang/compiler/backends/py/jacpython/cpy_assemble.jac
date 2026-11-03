# Bytecode assembly: a port of CPython 3.14's Python/assemble.c (jump offsets,
# bytecode, location and exception tables, localsplus layout and the code
# object) and of compile.c's optimize_and_assemble_code_unit driver.

glob CONTINUATION_BIT: int = 64,
     END_SEND_OFFSET: int = 5,
     LOC_SHORT0: int = 0,
     LOC_ONE_LINE0: int = 10,
     LOC_NO_COLUMNS: int = 13,
     LOC_LONG: int = 14,
     LOC_NONE: int = 15,
     CO_FAST_ARG_POS: int = 2,
     CO_FAST_ARG_KW: int = 4,
     CO_FAST_ARG_VAR: int = 8;

obj assembler {
    has a_bytecode: list[int] = [],
        a_except_table: list[int] = [],
        a_lineno: int = 0,
        a_linetable: list[int] = [];
}

def instr_size(instr: seq_instr) -> int {
    oparg = instr.oparg;
    extended_args = 0;
    if 16777215 < oparg {
        extended_args += 1;
    }
    if 65535 < oparg {
        extended_args += 1;
    }
    if 255 < oparg {
        extended_args += 1;
    }
    return extended_args + 1 + opcode_cache_count(instr.opcode);
}

def assemble_emit_exception_table_item(a: assembler, value: int, msb: int) {
    bit = msb;
    if value >= 1 << 24 {
        a.a_except_table.append((value >> 24) | CONTINUATION_BIT | bit);
        bit = 0;
    }
    if value >= 1 << 18 {
        a.a_except_table.append(((value >> 18) & 63) | CONTINUATION_BIT | bit);
        bit = 0;
    }
    if value >= 1 << 12 {
        a.a_except_table.append(((value >> 12) & 63) | CONTINUATION_BIT | bit);
        bit = 0;
    }
    if value >= 1 << 6 {
        a.a_except_table.append(((value >> 6) & 63) | CONTINUATION_BIT | bit);
        bit = 0;
    }
    a.a_except_table.append((value & 63) | bit);
}

def assemble_emit_exception_table_entry(
    a: assembler, start: int, end: int, handler_offset: int, handler: seq_instr
) {
    size = end - start;
    depth = handler.h_startdepth - 1;
    if handler.h_preserve_lasti > 0 {
        depth -= 1;
    }
    depth_lasti = (depth << 1) | handler.h_preserve_lasti;
    assemble_emit_exception_table_item(a, start, 128);
    assemble_emit_exception_table_item(a, size, 0);
    assemble_emit_exception_table_item(a, handler_offset, 0);
    assemble_emit_exception_table_item(a, depth_lasti, 0);
}

def assemble_exception_table(a: assembler, instrs: list[seq_instr]) {
    ioffset = 0;
    handler = seq_instr(
        opcode=0,
        oparg=0,
        loc=no_location(),
        h_label=-1,
        h_startdepth=-1,
        h_preserve_lasti=-1
    );
    start = -1;
    for instr in instrs {
        if instr.h_label != handler.h_label {
            if handler.h_label >= 0 {
                handler_offset = instrs[handler.h_label].offset;
                assemble_emit_exception_table_entry(
                    a, start, ioffset, handler_offset, handler
                );
            }
            start = ioffset;
            handler = instr;
        }
        ioffset += instr_size(instr);
    }
    if handler.h_label >= 0 {
        handler_offset = instrs[handler.h_label].offset;
        assemble_emit_exception_table_entry(a, start, ioffset, handler_offset, handler);
    }
}

def write_location_varint(a: assembler, value: int) {
    val = value & 4294967295;
    while val >= 64 {
        a.a_linetable.append(64 | (val & 63));
        val = val >> 6;
    }
    a.a_linetable.append(val);
}

def write_location_signed_varint(a: assembler, val: int) {
    if val < 0 {
        write_location_varint(a, ((0 - val) << 1) | 1);
    } else {
        write_location_varint(a, val << 1);
    }
}

def write_location_first_byte(a: assembler, code: int, length: int) {
    a.a_linetable.append(128 | (code << 3) | (length - 1));
}

def write_location_info_entry(a: assembler, lc: srcloc, isize: int) {
    if lc.lineno == -1 {
        write_location_first_byte(a, LOC_NONE, isize);
        return;
    }
    line_delta = lc.lineno - a.a_lineno;
    column = lc.col_offset;
    end_column = lc.end_col_offset;
    if column < 0 or end_column < 0 {
        if lc.end_lineno == lc.lineno or lc.end_lineno < 0 {
            write_location_first_byte(a, LOC_NO_COLUMNS, isize);
            write_location_signed_varint(a, line_delta);
            a.a_lineno = lc.lineno;
            return;
        }
    } elif lc.end_lineno == lc.lineno {
        if line_delta == 0
            and column < 80
            and end_column - column < 16
            and end_column >= column {
            write_location_first_byte(a, LOC_SHORT0 + (column >> 3), isize);
            a.a_linetable.append(((column & 7) << 4) | (end_column - column));
            return;
        }
        if line_delta >= 0 and line_delta < 3 and column < 128 and end_column < 128 {
            write_location_first_byte(a, LOC_ONE_LINE0 + line_delta, isize);
            a.a_linetable.append(column);
            a.a_linetable.append(end_column);
            a.a_lineno = lc.lineno;
            return;
        }
    }
    write_location_first_byte(a, LOC_LONG, isize);
    write_location_signed_varint(a, lc.lineno - a.a_lineno);
    write_location_varint(a, lc.end_lineno - lc.lineno);
    write_location_varint(a, lc.col_offset + 1);
    write_location_varint(a, lc.end_col_offset + 1);
    a.a_lineno = lc.lineno;
}

def assemble_emit_location(a: assembler, lc: srcloc, isize: int) {
    if isize == 0 {
        return;
    }
    size = isize;
    while size > 8 {
        write_location_info_entry(a, lc, 8);
        size -= 8;
    }
    write_location_info_entry(a, lc, size);
}

def assemble_location_info(a: assembler, instrs: list[seq_instr], firstlineno: int) {
    a.a_lineno = firstlineno;
    lc = no_location();
    i = len(instrs) - 1;
    while i >= 0 {
        instr = instrs[i];
        if instr.loc.lineno == -2
            and instr.loc.end_lineno == -2
            and instr.loc.col_offset == -2
            and instr.loc.end_col_offset == -2 {
            if is_terminator_opcode(instr.opcode) {
                instr.loc = no_location();
            } elif i + 1 < len(instrs) {
                instr.loc = instrs[i + 1].loc;
            }
        }
        i -= 1;
    }
    size = 0;
    for instr in instrs {
        if not same_location(lc, instr.loc) {
            assemble_emit_location(a, lc, size);
            lc = instr.loc;
            size = 0;
        }
        size += instr_size(instr);
    }
    assemble_emit_location(a, lc, size);
}

def write_instr(code: list[int], instr: seq_instr, ilen: int) {
    opcode = instr.opcode;
    oparg = instr.oparg;
    caches = opcode_cache_count(opcode);
    width = ilen - caches;
    if width >= 4 {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 24) & 255);
    }
    if width >= 3 {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 16) & 255);
    }
    if width >= 2 {
        code.append(OP_EXTENDED_ARG);
        code.append((oparg >> 8) & 255);
    }
    code.append(opcode);
    code.append(oparg & 255);
    k = caches;
    while k > 0 {
        code.append(OP_CACHE);
        code.append(0);
        k -= 1;
    }
}

def assemble_emit(a: assembler, instrs: list[seq_instr], first_lineno: int) {
    a.a_lineno = first_lineno;
    for instr in instrs {
        write_instr(a.a_bytecode, instr, instr_size(instr));
    }
    assemble_location_info(a, instrs, a.a_lineno);
    assemble_exception_table(a, instrs);
}

def resolve_jump_offsets(instrs: list[seq_instr]) {
    for instr in instrs {
        if opcode_has_jump(instr.opcode) {
            instr.target = instr.oparg;
        }
    }
    extended_arg_recompile = True;
    while extended_arg_recompile {
        totsize = 0;
        for instr in instrs {
            instr.offset = totsize;
            totsize += instr_size(instr);
        }
        extended_arg_recompile = False;
        offset = 0;
        for instr in instrs {
            isize = instr_size(instr);
            offset += isize;
            if opcode_has_jump(instr.opcode) {
                target_offset = instrs[instr.target].offset;
                if instr.opcode == OP_END_ASYNC_FOR {
                    instr.oparg = offset - target_offset - END_SEND_OFFSET;
                } elif target_offset < offset {
                    instr.oparg = offset - target_offset;
                } else {
                    instr.oparg = target_offset - offset;
                }
                if instr_size(instr) != isize {
                    extended_arg_recompile = True;
                }
            }
        }
    }
}

def resolve_unconditional_jumps(instrs: list[seq_instr]) {
    for i in range(len(instrs)) {
        instr = instrs[i];
        is_forward = instr.oparg > i;
        if instr.opcode == OP_JUMP {
            instr.opcode = OP_JUMP_FORWARD if is_forward else OP_JUMP_BACKWARD;
        } elif instr.opcode == OP_JUMP_NO_INTERRUPT {
            instr.opcode = OP_JUMP_FORWARD
                if is_forward
                else OP_JUMP_BACKWARD_NO_INTERRUPT;
        } elif opcode_has_jump(instr.opcode) and instr.opcode > MAX_REAL_OPCODE {
            raise SystemError("unresolved pseudo jump instruction");
        }
    }
}

def compute_localsplus_info(
    umd: code_unit_metadata,
    nlocalsplus: int,
    flags: int,
    names: list[str],
    kinds: list[int]
) {
    counts: list[int] = [
        umd.posonlyargcount,
        umd.argcount,
        umd.kwonlyargcount,
        1 if flags & CO_VARARGS else 0,
        1 if flags & CO_VARKEYWORDS else 0,
        -1
    ];
    argkinds: list[int] = [
        CO_FAST_ARG_POS,
        CO_FAST_ARG_POS | CO_FAST_ARG_KW,
        CO_FAST_ARG_KW,
        CO_FAST_ARG_VAR | CO_FAST_ARG_POS,
        CO_FAST_ARG_VAR | CO_FAST_ARG_KW,
        0
    ];
    pos = 0;
    maxpos = 0;
    nvarnames = len(umd.varnames);
    for i in range(6) {
        if counts[i] < 0 {
            maxpos = nvarnames;
        } else {
            maxpos = maxpos + counts[i];
        }
        while pos < maxpos and pos < nvarnames {
            k = umd.varnames[pos];
            offset = umd.varname_index[k];
            kind = CO_FAST_LOCAL | argkinds[i];
            if k in umd.fasthidden {
                kind = kind | CO_FAST_HIDDEN;
            }
            if k in umd.cellvar_index {
                kind = kind | CO_FAST_CELL;
            }
            names[offset] = k;
            kinds[offset] = kind;
            pos += 1;
        }
    }
    nlocals = nvarnames;
    numdropped = 0;
    for k in umd.cellvars {
        if k in umd.varname_index {
            numdropped += 1;
            continue;
        }
        cellvar_offset = umd.cellvar_index[k] + nlocals - numdropped;
        names[cellvar_offset] = k;
        kinds[cellvar_offset] = CO_FAST_CELL;
    }
    for k in umd.freevars {
        offset = umd.freevar_index[k] + nlocals - numdropped;
        names[offset] = k;
        kinds[offset] = CO_FAST_FREE;
    }
}

def makecode(
    umd: code_unit_metadata,
    a: assembler,
    constslist: list[PyObj],
    maxdepth: int,
    nlocalsplus: int,
    code_flags: int,
    filename: str
) -> PyCode {
    names: list[str] = [];
    for n in umd.names {
        names.append(n);
    }
    consts: list[PyObj] = [];
    for c in constslist {
        consts.append(c);
    }
    localsplusnames: list[str] = [];
    localspluskinds: list[int] = [];
    for k in range(nlocalsplus) {
        localsplusnames.append("");
        localspluskinds.append(0);
    }
    compute_localsplus_info(
        umd, nlocalsplus, code_flags, localsplusnames, localspluskinds
    );
    varnames: list[str] = [];
    cellvars: list[str] = [];
    freevars: list[str] = [];
    for k in range(nlocalsplus) {
        kind = localspluskinds[k];
        if kind & CO_FAST_LOCAL {
            varnames.append(localsplusnames[k]);
        }
        if kind & CO_FAST_CELL {
            cellvars.append(localsplusnames[k]);
        }
        if kind & CO_FAST_FREE {
            freevars.append(localsplusnames[k]);
        }
    }
    qualname = umd.qualname or umd.name;
    stacksize = maxdepth if maxdepth > 0 else 1;
    return PyCode(
        t="code",
        argcount=umd.posonlyargcount + umd.argcount,
        posonlyargcount=umd.posonlyargcount,
        kwonlyargcount=umd.kwonlyargcount,
        stacksize=stacksize,
        flags=code_flags,
        co_code=a.a_bytecode,
        consts=consts,
        names=names,
        varnames=varnames,
        cellvars=cellvars,
        freevars=freevars,
        filename=filename,
        name=umd.name,
        qualname=qualname,
        firstlineno=umd.firstlineno,
        linetable=a.a_linetable,
        exceptiontable=a.a_except_table,
        localsplusnames=localsplusnames,
        localspluskinds=localspluskinds
    );
}

def assemble_make_code_object(
    umd: code_unit_metadata,
    consts: list[PyObj],
    maxdepth: int,
    instrs: instr_seq,
    nlocalsplus: int,
    code_flags: int,
    filename: str
) -> PyCode {
    instrs.apply_label_map();
    resolve_unconditional_jumps(instrs.instrs);
    resolve_jump_offsets(instrs.instrs);
    a = assembler(a_bytecode=[], a_except_table=[], a_lineno=0, a_linetable=[]);
    assemble_emit(a, instrs.instrs, umd.firstlineno);
    return makecode(umd, a, consts, maxdepth, nlocalsplus, code_flags, filename);
}

def cpy_optimize_and_assemble(
    seq: instr_seq,
    umd: code_unit_metadata,
    code_flags: int,
    nparams: int,
    filename: str
) -> PyCode {
    consts: list[PyObj] = [];
    for c in umd.consts {
        consts.append(c);
    }
    g = cfg_from_instruction_sequence(seq);
    nlocals = len(umd.varnames);
    cfg_optimize_code_unit(g, consts, nlocals, nparams, umd.firstlineno);
    optimized = instr_seq(instrs=[], labelmap=[], nested=[]);
    (stackdepth, nlocalsplus) = optimized_cfg_to_instruction_sequence(
        g, umd, code_flags, optimized
    );
    return assemble_make_code_object(
        umd, consts, stackdepth, optimized, nlocalsplus, code_flags, filename
    );
}
