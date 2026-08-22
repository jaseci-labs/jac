# P3.2d — code flag / argcount helpers.
# Lift: Objects/_lifted/codeobject_core.jac
#
# ======================================================================
# PyCode front<->back binary contract -- FROZEN (PLAN.md P4 next-steps a)
# ======================================================================
# The compiler back end (flowgraph -> assembler) produces PyCode; the VM
# front end (marshal Reader oracle, ceval interpreter) consumes it. This
# comment is the normative statement of the binary format they share,
# pinned to CPython 3.14.6 (reference/cpython). Every clause has an ID
# (Cx.y) and is enforced structurally by pycode_diff.jac's
# `pycode_contract_check` -- if you change codegen, the differ must stay
# green, and if you change the format, change the clauses AND the checks
# together. The canonical PyCode object lives in objects.jac.
#
# C1 -- bytecode buffer (co_code)
#   C1.1 co_code is a flat list[int] of raw BYTES: one instruction is the
#        pair (opcode, oparg) at byte offset 2*k for code unit k. It is
#        NOT a list of 16-bit words and NOT de-CACHE-ified.
#   C1.2 EXTENDED_ARG (opcode_meta.OP_EXTENDED_ARG) prefixes fold high
#        oparg bits: effective oparg = fold of successive arg bytes,
#        most-significant prefix first (oparg |= ext << 8 per prefix).
#   C1.3 Cache padding: an instruction whose opcode o has
#        opcode_cache_count(o) > 0 is followed by that many code units of
#        (OP_CACHE, 0) == (0, 0). Byte width of any instruction is exactly
#        2 * (1 + opcode_cache_count(op)).
#   C1.4 Alignment: walking widths per C1.3 from offset 0 lands exactly on
#        len(co_code); no trailing partial instructions, no stray bytes.
#
# C2 -- offsets are code units, not bytes
#   Jump opargs (JUMP_FORWARD/JUMP_BACKWARD/...) and every exception-table
#   offset denote CODE UNITS k where the byte offset is 2*k. Consumers that
#   index co_code by byte multiply by 2 (ceval.jac does).
#
# C3 -- exception table (exceptiontable)
#   C3.1 Sequence of entries; each entry encodes 4 varint7 items in order:
#        start, size, target, depth_lasti = ((depth << 1) | preserve_lasti).
#        All values are code units (C2); size > 0; depth >= 0.
#   C3.2 varint7: little-endian base 2**6; low 6 payload bits per byte;
#        bit 0x40 = continuation; bit 0x80 set ONLY on the first byte of
#        the FIRST item (start) of each entry as the entry marker. Values
#        fit in 30 bits (assemble.c assemble_emit_exception_table_item).
#   C3.3 Ordering: entries appear in ascending start order, non-
#        overlapping ([start, start+size)); starts are strictly increasing
#        so find_handler-style linear/binary scan is well-defined.
#   C3.4 Range: start+size <= code length in units; target < code length
#        in units; target points at a real instruction boundary.
#
# C4 -- merged localsplus layout (co_localsplusnames/kinds)
#   C4.1 The merged array orders [varnames][cellvars][freevars]; jacpython
#        stores the three views separately on PyCode (varnames/cellvars/
#        freevars) and reconstructs the merge positionally: localsplus[i]
#        = varnames first, then cellvars, then freevars.
#   C4.2 Kind flags (pycore_code.h): CO_FAST_LOCAL=0x20, CO_FAST_CELL=0x40,
#        CO_FAST_FREE=0x80. A cell that is also a local (cell parameter)
#        carries BOTH 0x20 and 0x40 and appears only in varnames+cellvars
#        views, never freevars.
#   C4.3 Cell parameters keep their varname slot (kind bits 0x20|0x40);
#        they are NOT duplicated into cellvars -- the appended region holds
#        only non-argument cellvars, then freevars.
#   C4.4 Disjointness: within each view names are unique; no name appears
#        in both cellvars and freevars.
#   C4.5 Merged-index addressing: BOTH operand families -- fast
#        (LOAD_FAST/LOAD_FAST_BORROW/LOAD_FAST_CHECK/LOAD_FAST_AND_CLEAR/
#        STORE_FAST/STORE_FAST_MAYBE_NULL/DELETE_FAST) and deref
#        (LOAD/STORE/DELETE_DEREF, LOAD_CLOSURE, MAKE_CELL) -- carry
#        MERGED localsplus indexes over [varnames][cellvars][freevars]:
#        0 <= oparg < len(varnames)+len(cellvars)+len(freevars).
#        Deref-family ops fetch the slot's PyCell; fast-family ops fetch
#        its value; a cell-kind slot is reachable through both families
#        (CPython 3.14 loads cellvars via LOAD_FAST_BORROW).
#
# C5 -- marshal transport field order (Reader.read_code, marshal.c
#      w_object TYPE_CODE block): argcount, posonlyargcount, kwonlyargcount,
#      stacksize, flags, code, consts, names, localsplusnames,
#      localspluskinds, filename, name, qualname, firstlineno, linetable,
#      exceptiontable. Marshal is oracle/test transport only (PLAN.md);
#      it is not in the product compile path.
#
# Violations of C1-C5 discovered against host-compiled fixtures should be
# reported as codegen bugs, not papered over in the differ.

glob CO_OPTIMIZED: int = 1,
     CO_NEWLOCALS: int = 2,
     CO_VARARGS: int = 4,
     CO_VARKEYWORDS: int = 8,
     CO_NESTED: int = 16,
     CO_GENERATOR: int = 32,
     CO_COROUTINE: int = 128,
     CO_ASYNC_GENERATOR: int = 512;

def code_is_generator(flags: int) -> bool {
    return (flags & CO_GENERATOR) != 0;
}

def code_is_coroutine(flags: int) -> bool {
    return (flags & CO_COROUTINE) != 0;
}

def code_has_varargs(flags: int) -> bool {
    return (flags & CO_VARARGS) != 0;
}

def code_has_varkeywords(flags: int) -> bool {
    return (flags & CO_VARKEYWORDS) != 0;
}

def code_total_argcount(argcount: int, kwonlyargcount: int) -> int {
    return argcount + kwonlyargcount;
}
