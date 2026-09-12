# CFG preparation for the P4 back track (PLAN.md P0.11 slice).
#
# Turns a compile_unit's block IR into a flat instruction list ready for bytecode
# emission: flatten blocks, insert NOT_TAKEN after forward conditional jumps,
# resolve jump targets to code-unit offsets, rewrite small-int LOAD_CONST, and
# verify stack depth.
#
# Product module: imports compiler_ir + opcode_meta + objects only.
# Never imports assembler.

import from jaclang.runtime.python.objects { PyInt, PyObj, PyTuple, PySet, is_error }
import from jaclang.runtime.python.opcode_meta {
    OP_LOAD_CONST,
    OP_BUILD_LIST,
    OP_BUILD_SET,
    OP_CONTAINS_OP,
    OP_GET_ITER,
    OP_LOAD_SMALL_INT,
    opcode_has_const,
    OP_NOT_TAKEN,
    OP_POP_JUMP_IF_FALSE,
    OP_POP_JUMP_IF_TRUE,
    OP_POP_JUMP_IF_NONE,
    OP_POP_JUMP_IF_NOT_NONE,
    OP_END_ASYNC_FOR,
    OP_JUMP_FORWARD,
    OP_JUMP_BACKWARD,
    OP_JUMP_BACKWARD_NO_INTERRUPT,
    OP_SWAP,
    OP_NOP,
    OP_POP_TOP,
    OP_STORE_FAST,
    OP_STORE_FAST_MAYBE_NULL,
    OP_LOAD_FAST,
    OP_LOAD_FAST_CHECK,
    OP_LOAD_FAST_BORROW,
    OP_LOAD_FAST_LOAD_FAST,
    OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW,
    OP_LOAD_FAST_AND_CLEAR,
    OP_STORE_FAST_LOAD_FAST,
    OP_STORE_FAST_STORE_FAST,
    OP_DELETE_FAST,
    OP_COPY,
    OP_LOAD_ATTR,
    OP_LOAD_SUPER_ATTR,
    OP_LOAD_SPECIAL,
    OP_PUSH_EXC_INFO,
    OP_CHECK_EXC_MATCH,
    OP_FOR_ITER,
    OP_SEND,
    OP_END_SEND,
    OP_RETURN_VALUE,
    OP_SET_FUNCTION_ATTRIBUTE,
    OP_FORMAT_SIMPLE,
    OP_GET_ANEXT,
    OP_GET_LEN,
    OP_GET_YIELD_FROM_ITER,
    OP_IMPORT_FROM,
    OP_MATCH_KEYS,
    OP_MATCH_MAPPING,
    OP_MATCH_SEQUENCE,
    OP_WITH_EXCEPT_START,
    OP_DICT_MERGE,
    OP_DICT_UPDATE,
    OP_LIST_APPEND,
    OP_LIST_EXTEND,
    OP_MAP_ADD,
    OP_RERAISE,
    OP_SET_ADD,
    OP_SET_UPDATE,
    stack_effect,
    _opcode_num_popped,
    _opcode_num_pushed,
    has_target,
    is_unconditional_jump_opcode,
    is_scope_exit_opcode,
}
import from jaclang.compiler.backends.py.jacpython.compiler_ir {
    unverified_cfg,
    basicblock,
    except_region,
    cinstr,
    mk_instr,
    instr_size_codeunits,
}
import from jaclang.compiler.frontend.python.compiler_diagnostics {
    compiler_diagnostic,
    internal_compiler_diagnostic,
}

# Verified CFG: flat instruction stream with stack depth, ready for assembly.
# Phase 3 adds hard errors on underflow and inconsistent joins via diag.
obj verified_cfg {
    has unit: unverified_cfg,
        flat: list[cinstr],
        stacksize: int,
        block_starts: list[int] = [],
        diag: compiler_diagnostic | None = None;
}

# Intermediate flatten result.
obj flatten_result {
    has flat: list[cinstr],
        block_starts: list[int];
}

def is_conditional_jump(opcode: int) -> bool {
    if opcode == OP_POP_JUMP_IF_FALSE {
        return True;
    }
    if opcode == OP_POP_JUMP_IF_TRUE {
        return True;
    }
    if opcode == OP_POP_JUMP_IF_NONE {
        return True;
    }
    if opcode == OP_POP_JUMP_IF_NOT_NONE {
        return True;
    }
    return False;
}

# Lay blocks out in allocation order and record each block's code-unit start.
def flatten_blocks(u: unverified_cfg) -> flatten_result {
    flat: list[cinstr] = [];
    block_starts: list[int] = [];
    cur = 0;
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        while len(block_starts) <= b.id {
            block_starts.append(0);
        }
        block_starts[b.id] = cur;
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            flat.append(ins);
            cur = cur + instr_size_codeunits(ins);
            ii = ii + 1;
        }
        bi = bi + 1;
    }
    return flatten_result(flat=flat, block_starts=block_starts);
}

# Layout order (u.blocks list order) is authoritative, not block-id order.
# With deferred block placement (CPython USE_LABEL), a block allocated early can
# be laid out late, so "next block" and forward/backward jump direction must be
# read from layout position, never from id arithmetic. When every block is placed
# at allocation (the common case) blocks[i].id == i and these reduce to id math.
def build_layout_pos(u: unverified_cfg) -> dict[int, int] {
    pos: dict[int, int] = {};
    i = 0;
    while i < len(u.blocks) {
        pos[u.blocks[i].id] = i;
        i = i + 1;
    }
    return pos;
}

def layout_pos(pos: dict[int, int], block_id: int) -> int {
    if block_id in pos {
        return pos[block_id];
    }
    return -1;
}

# CPython flowgraph.c: after each forward conditional jump, insert NOT_TAKEN
# (backward jump reversal is deferred to a later slice).
def layout_next_block(u: unverified_cfg, idx: int) -> basicblock | None {
    if idx >= 0 and idx + 1 < len(u.blocks) {
        return u.blocks[idx + 1];
    }
    return None;
}

def normalize_jumps(u: unverified_cfg) {
    pos = build_layout_pos(u);
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        new_instrs: list[cinstr] = [];
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            new_instrs.append(ins);
            if is_conditional_jump(ins.opcode) and ins.target_block >= 0 {
                if layout_pos(pos, ins.target_block) > bi {
                    nb = layout_next_block(u, bi);
                    skip_not_taken = False;
                    if nb is not None and len(nb.instrs) > 0 {
                        if nb.instrs[0].opcode == OP_NOT_TAKEN {
                            skip_not_taken = True;
                        }
                    }
                    if not skip_not_taken {
                        new_instrs.append(mk_instr(OP_NOT_TAKEN, 0, ins.loc));
                    }
                }
            }
            ii = ii + 1;
        }
        b.instrs = new_instrs;
        bi = bi + 1;
    }
}

# POP_JUMP_* targets are forward code-unit offsets from the next instruction:
#   ip += 2 * oparg. target_block ids map to block starts laid out in order.
def resolve_jump_offsets(flat: list[cinstr], block_starts: list[int]) {
    offsets: list[int] = [];
    cur = 0;
    i = 0;
    while i < len(flat) {
        offsets.append(cur);
        cur = cur + instr_size_codeunits(flat[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(flat) {
        ins = flat[i];
        if ins.target_block >= 0 {
            target = block_starts[ins.target_block];
            next_ip = offsets[i] + instr_size_codeunits(ins);
            # Cleanup and shared-tail layout can move an unconditional target
            # across its source. Resolve direction from the final layout.
            if is_unconditional_jump_opcode(ins.opcode) {
                if target >= next_ip {
                    ins.opcode = OP_JUMP_FORWARD;
                } elif ins.opcode == OP_JUMP_FORWARD {
                    ins.opcode = OP_JUMP_BACKWARD_NO_INTERRUPT;
                }
            }
            if ins.opcode == OP_JUMP_BACKWARD
                or ins.opcode == OP_JUMP_BACKWARD_NO_INTERRUPT
                or ins.opcode == OP_END_ASYNC_FOR {
                ins.oparg = next_ip - target;
            } else {
                ins.oparg = target - next_ip;
            }
        }
        i = i + 1;
    }
}

# CPython's maybe_instr_make_load_smallint rewrites LOAD_CONST <int in 0..255> to
# LOAD_SMALL_INT <value>. The const remains in the table (now unreferenced).
def rewrite_small_ints(u: unverified_cfg, flat: list[cinstr]) {
    i = 0;
    while i < len(flat) {
        ins = flat[i];
        if ins.opcode == OP_LOAD_CONST {
            if ins.oparg < len(u.consts) {
                c = u.consts[ins.oparg];
                if isinstance(c, PyInt) {
                    v = (c as PyInt).val;
                    if v >= 0 and v <= 255 {
                        ins.opcode = OP_LOAD_SMALL_INT;
                        ins.oparg = v;
                    }
                }
            }
        }
        i = i + 1;
    }
}

glob UNSET_STARTDEPTH: int = -1000000;

def block_last_instr(b: basicblock) -> cinstr | None {
    if len(b.instrs) == 0 {
        return None;
    }
    return b.instrs[len(b.instrs) - 1];
}

def block_has_fallthrough(b: basicblock) -> bool {
    last = block_last_instr(b);
    if last is None {
        return True;
    }
    if is_scope_exit_opcode(last.opcode) or is_unconditional_jump_opcode(last.opcode) {
        return False;
    }
    return True;
}

def stackdepth_diag(kind: str, message: str) -> internal_compiler_diagnostic {
    return internal_compiler_diagnostic(kind=kind, message=message);
}

# Reject dead instructions after an unconditional jump or scope exit in the
# same basic block (INTEGRATION_PLAN Phase 3 negative surface).
def block_has_dead_code_after_terminator(b: basicblock) -> bool {
    past_term = False;
    ii = 0;
    while ii < len(b.instrs) {
        ins = b.instrs[ii];
        if past_term {
            return True;
        }
        if is_unconditional_jump_opcode(ins.opcode)
            or is_scope_exit_opcode(ins.opcode) {
            past_term = True;
        }
        ii = ii + 1;
    }
    return False;
}

def check_cfg_terminators(u: unverified_cfg) -> compiler_diagnostic | None {
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        if block_has_dead_code_after_terminator(b) {
            return stackdepth_diag(
                "ValueError", "Invalid CFG, instructions after terminator"
            );
        }
        bi = bi + 1;
    }
    return None;
}

def stackdepth_push(
    startdepths: list[int], work: list[int], b: basicblock, depth: int
) -> bool {
    idx = b.id;
    if idx < 0 or idx >= len(startdepths) {
        return False;
    }
    cur = startdepths[idx];
    if cur != UNSET_STARTDEPTH and cur != depth {
        return False;
    }
    if cur == UNSET_STARTDEPTH {
        startdepths[idx] = depth;
        work.append(idx);
    }
    return True;
}

# Walk one block's instructions for max stack depth (exception-handler paths).
def walk_block_maxdepth(
    b: basicblock, start_depth: int, maxdepth: int
) -> tuple[int, compiler_diagnostic | None] {
    depth = start_depth;
    maxd = maxdepth;
    ii = 0;
    while ii < len(b.instrs) {
        ins = b.instrs[ii];
        if depth > maxd {
            maxd = depth;
        }
        eff = stack_effect(ins.opcode, ins.oparg, 0);
        if eff is None {
            return (
                0,
                stackdepth_diag(
                    "SystemError",
                    "Invalid stack effect for opcode="
                        + str(ins.opcode)
                        + ", arg="
                        + str(ins.oparg)
                )
            );
        }
        new_depth = depth + eff;
        if new_depth < 0 {
            return (0, stackdepth_diag("ValueError", "Invalid CFG, stack underflow"));
        }
        depth = new_depth;
        if is_scope_exit_opcode(ins.opcode)
            or is_unconditional_jump_opcode(ins.opcode) {
            break;
        }
        ii = ii + 1;
    }
    return (maxd, None);
}

# CPython flowgraph.c calculate_stackdepth: worklist over block edges with
# generated stack_effect metadata (INTEGRATION_PLAN Phase 3).
def calculate_stackdepth(u: unverified_cfg) -> tuple[int, compiler_diagnostic | None] {
    if len(u.blocks) == 0 {
        return (0, None);
    }
    n = len(u.blocks);
    blocks_by_id = {block.id: block for block in u.blocks};
    # startdepths is indexed by block id. Ids are sparse once the optimizer prunes
    # unreachable blocks, so size to the id space (next_block_id), not the block
    # count, or a surviving high-id block indexes out of range.
    cap = u.next_block_id;
    if cap < n {
        cap = n;
    }
    startdepths: list[int] = [];
    i = 0;
    while i < cap {
        startdepths.append(UNSET_STARTDEPTH);
        i = i + 1;
    }
    work: list[int] = [];
    maxdepth = 0;
    entry_blk = u.blocks[0];
    pos = build_layout_pos(u);

    if not stackdepth_push(startdepths, work, entry_blk, 0) {
        return (
            0,
            stackdepth_diag("ValueError", "Invalid CFG, inconsistent stackdepth")
        );
    }
    # Handler entries are roots of the same graph traversal as normal code.
    # Walking only their first block misses stack peaks in nested handlers and
    # their successors, producing a co_stacksize too small for the evaluator.
    for reg in u.except_regions {
        if reg.depth_from_block >= 0 {
            continue;
        }
        handler = blocks_by_id.get(reg.handler_block);
        if handler is not None
            and not stackdepth_push(startdepths, work, handler, reg.stack_depth) {
            return (
                0,
                stackdepth_diag(
                    "ValueError",
                    "Invalid CFG, inconsistent exception handler stackdepth"
                )
            );
        }
    }
    while len(work) > 0 {
        bid = work.pop();
        b = blocks_by_id.get(bid);
        if b is None {
            return (
                0,
                stackdepth_diag("ValueError", "Invalid CFG, missing basic block")
            );
        }
        depth = startdepths[bid];
        for reg in u.except_regions {
            if reg.depth_from_block == bid {
                reg.stack_depth = depth + reg.depth_offset;
                handler = blocks_by_id.get(reg.handler_block);
                if handler is not None
                    and not stackdepth_push(
                        startdepths, work, handler, reg.stack_depth
                    ) {
                    return (
                        0,
                        stackdepth_diag(
                            "ValueError",
                            "Invalid CFG, inconsistent computed handler stackdepth"
                        )
                    );
                }
            }
        }
        next_blk = layout_next_block(u, layout_pos(pos, b.id));
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            # Net stack effects alone miss invalid COPY/SWAP operands and
            # RETURN_VALUE without a value (its 3.14 net effect is zero).
            needed = _opcode_num_popped(ins.opcode, ins.oparg);
            if needed > depth {
                return (
                    0,
                    stackdepth_diag(
                        "ValueError",
                        "Invalid CFG, insufficient operands for opcode="
                            + str(ins.opcode)
                            + ", arg="
                            + str(ins.oparg)
                    )
                );
            }
            if depth > maxdepth {
                maxdepth = depth;
            }
            eff = stack_effect(ins.opcode, ins.oparg, 0);
            if eff is None {
                return (
                    0,
                    stackdepth_diag(
                        "SystemError",
                        "Invalid stack effect for opcode="
                            + str(ins.opcode)
                            + ", arg="
                            + str(ins.oparg)
                    )
                );
            }
            new_depth = depth + eff;
            if new_depth < 0 {
                return (
                    0,
                    stackdepth_diag("ValueError", "Invalid CFG, stack underflow")
                );
            }
            if has_target(ins.opcode) and ins.opcode != OP_END_ASYNC_FOR {
                if ins.target_block < 0 {
                    return (
                        0,
                        stackdepth_diag(
                            "ValueError", "Invalid CFG, jump missing target block"
                        )
                    );
                }
                target = blocks_by_id.get(ins.target_block);
                if target is None {
                    return (
                        0,
                        stackdepth_diag(
                            "ValueError", "Invalid CFG, invalid jump target"
                        )
                    );
                }
                jeff = stack_effect(ins.opcode, ins.oparg, 1);
                if jeff is None {
                    return (
                        0,
                        stackdepth_diag(
                            "SystemError",
                            "Invalid stack effect for opcode="
                                + str(ins.opcode)
                                + ", arg="
                                + str(ins.oparg)
                        )
                    );
                }
                target_depth = depth + jeff;
                if target_depth < 0 {
                    return (
                        0,
                        stackdepth_diag("ValueError", "Invalid CFG, stack underflow")
                    );
                }
                if not stackdepth_push(startdepths, work, target, target_depth) {
                    return (
                        0,
                        stackdepth_diag(
                            "ValueError",
                            "Invalid CFG, inconsistent stackdepth at block "
                                + str(target.id)
                                + " via jump (want "
                                + str(target_depth)
                                + " have "
                                + str(startdepths[target.id])
                                + ")"
                        )
                    );
                }
            }
            depth = new_depth;
            if is_unconditional_jump_opcode(ins.opcode)
                or is_scope_exit_opcode(ins.opcode) {
                next_blk = None;
                break;
            }
            ii = ii + 1;
        }
        if next_blk is not None and block_has_fallthrough(b) {
            if not stackdepth_push(startdepths, work, next_blk, depth) {
                return (
                    0,
                    stackdepth_diag(
                        "ValueError",
                        "Invalid CFG, inconsistent stackdepth at block "
                            + str(next_blk.id)
                            + " via fallthrough (want "
                            + str(depth)
                            + " have "
                            + str(startdepths[next_blk.id])
                            + ")"
                    )
                );
            }
        }
    }
    # Publish per-block entry depths for optimize_load_fast (indexed by block id;
    # UNSET_STARTDEPTH for blocks unreachable via normal / jump / fallthrough edges).
    u.block_startdepths = startdepths;
    return (maxdepth, None);
}

# UnverifiedCFG -> VerifiedCFG (Phase 2 contract; Phase 3 worklist stack proof).
# ---------------------------------------------------------------------------
# SWAP / superinstruction optimization (CPython flowgraph.c: swaptimize,
# apply_static_swaps, insert_superinstructions). Runs per basic block. Match
# pattern codegen emits naive rotate (SWAP) + separate STORE_FAST/POP_TOP; these
# passes fold them into CPython's exact post-optimizer shape. Eliminated
# instructions are marked with target_block == OPT_DELETE and compacted out (so
# no spurious NOPs reach assembly — intentional NOPs keep target_block == -1).
glob OPT_DELETE: int = -999;

def opt_is_swappable(op: int) -> bool {
    return op == OP_STORE_FAST or op == OP_STORE_FAST_MAYBE_NULL or op == OP_POP_TOP;
}

def opt_stores_to(ins: cinstr) -> int {
    if ins.opcode == OP_STORE_FAST or ins.opcode == OP_STORE_FAST_MAYBE_NULL {
        return ins.oparg;
    }
    return -1;
}

def opt_mark_delete(ins: cinstr) {
    ins.opcode = OP_NOP;
    ins.target_block = OPT_DELETE;
}

# Skip NOPs; return index of the next swappable instruction to the right of i,
# or -1 if a non-swappable (or line-crossing, when lineno >= 0) instruction is
# reached first.
def opt_next_swappable(instrs: list[cinstr], i: int, lineno: int) -> int {
    while True {
        i = i + 1;
        if i >= len(instrs) {
            return -1;
        }
        ins = instrs[i];
        if lineno >= 0 and ins.loc.lineno != lineno {
            return -1;
        }
        if ins.opcode == OP_NOP {
            continue;
        }
        if opt_is_swappable(ins.opcode) {
            return i;
        }
        return -1;
    }
}

# Replace a run of SWAPs/NOPs starting at ix with the minimal equivalent set of
# SWAPs (written at the end of the run). Returns the index of the run's last
# instruction (CPython's *ix += len - 1); returns ix unchanged for a lone SWAP.
def opt_swaptimize(instrs: list[cinstr], ix: int) -> int {
    depth = instrs[ix].oparg;
    length = 0;
    more = False;
    limit = len(instrs) - ix;
    while True {
        length = length + 1;
        if length >= limit {
            break;
        }
        op = instrs[ix + length].opcode;
        if op == OP_SWAP {
            if instrs[ix + length].oparg > depth {
                depth = instrs[ix + length].oparg;
            }
            more = True;
        } elif op != OP_NOP {
            break;
        }
    }
    if not more {
        return ix;
    }
    stack: list[int] = [];
    i = 0;
    while i < depth {
        stack.append(i);
        i = i + 1;
    }
    i = 0;
    while i < length {
        if instrs[ix + i].opcode == OP_SWAP {
            oparg = instrs[ix + i].oparg;
            top = stack[0];
            stack[0] = stack[oparg - 1];
            stack[oparg - 1] = top;
        }
        i = i + 1;
    }
    VISITED = -1;
    current = length - 1;
    i = 0;
    while i < depth {
        if stack[i] == VISITED or stack[i] == i {
            i = i + 1;
            continue;
        }
        j = i;
        while True {
            if j != 0 {
                instrs[ix + current].opcode = OP_SWAP;
                instrs[ix + current].oparg = j + 1;
                instrs[ix + current].target_block = -1;
                current = current - 1;
            }
            if stack[j] == VISITED {
                break;
            }
            next_j = stack[j];
            stack[j] = VISITED;
            j = next_j;
        }
        i = i + 1;
    }
    while current >= 0 {
        opt_mark_delete(instrs[ix + current]);
        current = current - 1;
    }
    return ix + length - 1;
}

# Push SWAPs statically into the following store/pop operands where safe, e.g.
# SWAP(2), POP_TOP, STORE_FAST(x) -> NOP, STORE_FAST(x), POP_TOP.
def opt_apply_static_swaps(instrs: list[cinstr], i: int, lo: int) {
    while i >= lo {
        swap = instrs[i];
        if swap.opcode != OP_SWAP {
            if swap.opcode == OP_NOP or opt_is_swappable(swap.opcode) {
                i = i - 1;
                continue;
            }
            return;
        }
        j = opt_next_swappable(instrs, i, -1);
        if j < 0 {
            return;
        }
        k = j;
        lineno = instrs[j].loc.lineno;
        count = swap.oparg - 1;
        while count > 0 {
            k = opt_next_swappable(instrs, k, lineno);
            if k < 0 {
                return;
            }
            count = count - 1;
        }
        store_j = opt_stores_to(instrs[j]);
        store_k = opt_stores_to(instrs[k]);
        if store_j >= 0 or store_k >= 0 {
            if store_j == store_k {
                return;
            }
            idx = j + 1;
            while idx < k {
                store_idx = opt_stores_to(instrs[idx]);
                if store_idx >= 0 and (store_idx == store_j or store_idx == store_k) {
                    return;
                }
                idx = idx + 1;
            }
        }
        opt_mark_delete(swap);
        tmp = instrs[j];
        instrs[j] = instrs[k];
        instrs[k] = tmp;
        i = i - 1;
    }
}

def opt_compact_block(b: basicblock) {
    out: list[cinstr] = [];
    ii = 0;
    while ii < len(b.instrs) {
        ins = b.instrs[ii];
        if ins.target_block != OPT_DELETE {
            out.append(ins);
        }
        ii = ii + 1;
    }
    b.instrs = out;
}

def opt_make_super(inst1: cinstr, inst2: cinstr, superop: int) {
    l1 = inst1.loc.lineno;
    l2 = inst2.loc.lineno;
    if l1 >= 0 and l2 >= 0 and l1 != l2 {
        return;
    }
    if inst1.oparg >= 16 or inst2.oparg >= 16 {
        return;
    }
    inst1.opcode = superop;
    inst1.oparg = (inst1.oparg << 4) | inst2.oparg;
    opt_mark_delete(inst2);
}

# Superinstruction fusion over instrs[lo:]. Marked-delete slots (former SWAPs)
# only ever sit before a store run, never between the two stores of a pair, so
# raw i+1 adjacency is sufficient (matching CPython's post-compaction scan).
def opt_superinstructions(b: basicblock, lo: int) {
    i = lo;
    n = len(b.instrs);
    while i < n {
        inst = b.instrs[i];
        nextop = -1;
        if i + 1 < n {
            nextop = b.instrs[i + 1].opcode;
        }
        if inst.opcode == OP_LOAD_FAST and nextop == OP_LOAD_FAST {
            opt_make_super(inst, b.instrs[i + 1], OP_LOAD_FAST_LOAD_FAST);
        } elif inst.opcode == OP_STORE_FAST {
            if nextop == OP_LOAD_FAST {
                opt_make_super(inst, b.instrs[i + 1], OP_STORE_FAST_LOAD_FAST);
            } elif nextop == OP_STORE_FAST {
                opt_make_super(inst, b.instrs[i + 1], OP_STORE_FAST_STORE_FAST);
            }
        }
        i = i + 1;
    }
}

# Optimize only the instruction range [lo, end) of one block, in place. Scoped
# to match-pattern arms: the reimpl emits already-optimized bytecode elsewhere
# with its own block layout, so a global CPython-style pass would mis-fire (e.g.
# fuse comprehension-restore stores CPython keeps split). Match arms emit naive
# rotate (SWAP) + separate STORE_FAST/POP_TOP into a single success block, which
# this folds into CPython's exact shape.
def optimize_swap_range(b: basicblock, lo: int) {
    i = lo;
    while i < len(b.instrs) {
        if b.instrs[i].opcode == OP_SWAP {
            end = opt_swaptimize(b.instrs, i);
            opt_apply_static_swaps(b.instrs, end, lo);
            i = end;
        }
        i = i + 1;
    }
    opt_superinstructions(b, lo);
    opt_compact_block(b);
}

# CPython flowgraph.c CFG optimizer (subset). Runs on the block IR before jump
# normalization and offset assignment. Currently ports:
#   * inline_small_exit_blocks: a forward jump to a small (<= MAX_COPY_SIZE)
#     scope-exit block is rewritten to a copy of that block's instructions
#     (jump-to-return threading / tail duplication).
#   * remove_unreachable_blocks: drop a block left with no incoming edge, so an
#     exit block fully consumed by inlining leaves no dead bytes behind.
# Both passes are SCOPED to blocks flagged exit_inline_ok -- the shared success /
# next-arm / join targets emitted by match. Every other construct already emits
# CPython's post-optimizer shape by hand (see optimize_swap_range's same-scoped
# rationale), so a global pass would mis-fire on their back-edges and handlers.
glob MAX_COPY_SIZE: int = 4;

def block_exits_scope(b: basicblock) -> bool {
    last = block_last_instr(b);
    if last is None {
        return False;
    }
    return is_scope_exit_opcode(last.opcode);
}

def copy_cinstr(ins: cinstr) -> cinstr {
    return cinstr(
        opcode=ins.opcode, oparg=ins.oparg, loc=ins.loc, target_block=ins.target_block
    );
}

# A forward unconditional jump is a candidate for tail-duplication. Backward jumps
# (loop back-edges, generator resume) are excluded: CPython's optimizer runs
# before jump direction is assigned and only threads jumps to scope-exit blocks,
# which are never loop back-edges. Inlining a back-edge would corrupt loop shape.
def is_inlinable_jump(op: int) -> bool {
    return op == OP_JUMP_FORWARD;
}

# Tail-duplicate small scope-exit targets into their forward-jump sources.
def inline_small_exit_blocks(u: unverified_cfg) -> bool {
    changed = False;
    blocks_by_id = {block.id: block for block in u.blocks};
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        last = block_last_instr(b);
        if last is not None
            and is_inlinable_jump(last.opcode)
            and last.target_block >= 0 {
            target = blocks_by_id.get(last.target_block);
            if target is not None
                and target.id != b.id
                and target.exit_inline_ok
                and block_exits_scope(target)
                and len(target.instrs) <= MAX_COPY_SIZE {
                new_instrs: list[cinstr] = [];
                ki = 0;
                while ki < len(b.instrs) - 1 {
                    new_instrs.append(b.instrs[ki]);
                    ki = ki + 1;
                }
                ti = 0;
                while ti < len(target.instrs) {
                    new_instrs.append(copy_cinstr(target.instrs[ti]));
                    ti = ti + 1;
                }
                b.instrs = new_instrs;
                changed = True;
            }
        }
        bi = bi + 1;
    }
    return changed;
}

# Mark blocks reachable from the entry via fallthrough and jump edges.
def mark_reachable(u: unverified_cfg) -> list[int] {
    reachable: list[int] = [];
    i = 0;
    while i < len(u.blocks) {
        reachable.append(0);
        i = i + 1;
    }
    if len(u.blocks) == 0 {
        return reachable;
    }
    pos = build_layout_pos(u);
    stack: list[int] = [0];
    reachable[0] = 1;
    # Exception handler blocks are only reachable via the exception table, never
    # via a jump/fallthrough edge, so seed them (and blocks referenced as region
    # start/end markers) as roots or they would be wrongly pruned.
    ri = 0;
    while ri < len(u.except_regions) {
        reg = u.except_regions[ri];
        rb = 0;
        while rb < 4 {
            bid = reg.handler_block;
            if rb == 1 {
                bid = reg.start_block;
            }
            if rb == 2 {
                bid = reg.end_block;
            }
            if rb == 3 {
                bid = reg.depth_from_block;
            }
            if bid >= 0 {
                rp = layout_pos(pos, bid);
                if rp >= 0 and reachable[rp] == 0 {
                    reachable[rp] = 1;
                    stack.append(rp);
                }
            }
            rb = rb + 1;
        }
        ri = ri + 1;
    }
    while len(stack) > 0 {
        idx = stack.pop();
        b = u.blocks[idx];
        ii = 0;
        while ii < len(b.instrs) {
            ins = b.instrs[ii];
            if has_target(ins.opcode) and ins.target_block >= 0 {
                tp = layout_pos(pos, ins.target_block);
                if tp >= 0 and reachable[tp] == 0 {
                    reachable[tp] = 1;
                    stack.append(tp);
                }
            }
            ii = ii + 1;
        }
        if block_has_fallthrough(b) {
            nxt = idx + 1;
            if nxt < len(u.blocks) and reachable[nxt] == 0 {
                reachable[nxt] = 1;
                stack.append(nxt);
            }
        }
    }
    return reachable;
}

# Drop match join/end blocks orphaned by tail-duplication. Removal is limited to
# exit_inline_ok blocks so the incomplete edge model (which does not follow
# generator resume or async-for unwind edges) can never prune a live block of an
# already-hand-optimized construct.
def remove_unreachable_blocks(u: unverified_cfg) -> bool {
    reachable = mark_reachable(u);
    kept: list[basicblock] = [];
    removed = False;
    i = 0;
    while i < len(u.blocks) {
        b = u.blocks[i];
        if reachable[i] == 1 or not b.exit_inline_ok {
            kept.append(b);
        } else {
            removed = True;
        }
        i = i + 1;
    }
    if removed {
        u.blocks = kept;
    }
    return removed;
}

def optimize_literal_iterables(u: unverified_cfg) {
    # Membership and iteration never expose their temporary list/set. Replace
    # constant displays with a tuple/frozenset, as CPython's flowgraph pass does.
    # This also preserves shared nested constants across code objects.
    for block in u.blocks {
        for index in range(len(block.instrs) - 1) {
            ins = block.instrs[index];
            nextop = block.instrs[index + 1].opcode;
            if nextop not in (OP_CONTAINS_OP, OP_GET_ITER) {
                continue;
            }
            if ins.opcode in (OP_LIST_EXTEND, OP_SET_UPDATE)
                and ins.oparg == 1
                and index >= 2 {
                start = block.instrs[index - 2];
                const_load = block.instrs[index - 1];
                buildop = OP_BUILD_LIST
                    if ins.opcode == OP_LIST_EXTEND
                    else OP_BUILD_SET;
                if start.opcode == buildop
                    and start.oparg == 0
                    and const_load.opcode == OP_LOAD_CONST
                    and (
                        (
                            buildop == OP_BUILD_LIST
                            and isinstance(u.consts[const_load.oparg], PyTuple)
                        )
                        or (
                            buildop == OP_BUILD_SET
                            and isinstance(u.consts[const_load.oparg], PySet)
                        )
                    ) {
                    start.opcode = OP_NOP;
                    ins.opcode = OP_NOP;
                }
                continue;
            }
            if ins.opcode not in (OP_BUILD_LIST, OP_BUILD_SET) or ins.oparg > index {
                continue;
            }
            count = ins.oparg;
            loads = block.instrs[index - count:index];
            values: list[PyObj] = [];
            for load in loads {
                if load.opcode == OP_LOAD_CONST {
                    values.append(u.consts[load.oparg]);
                } elif load.opcode == OP_LOAD_SMALL_INT {
                    values.append(PyInt(t="int", val=load.oparg));
                } else {
                    break;
                }
            }
            if len(values) != count {
                continue;
            }
            folded: PyObj = PyTuple(t="tuple", items=values);
            if ins.opcode == OP_BUILD_SET {
                frozen = PySet(t="frozenset", items={}, frozen=True);
                valid = True;
                for value in values {
                    if is_error(frozen.set_add(value)) {
                        valid = False;
                        break;
                    }
                }
                if not valid {
                    continue;
                }
                folded = frozen;
            }
            for load in loads {
                load.opcode = OP_NOP;
            }
            ins.opcode = OP_LOAD_CONST;
            ins.oparg = u.add_const(folded);
        }
        opt_compact_block(block);
    }
}

def optimize_cfg(u: unverified_cfg) {
    optimize_literal_iterables(u);
    iterations = 0;
    while iterations < 100 {
        c1 = inline_small_exit_blocks(u);
        c2 = remove_unreachable_blocks(u);
        if not c1 and not c2 {
            break;
        }
        iterations = iterations + 1;
    }
}

# ---------------------------------------------------------------------------
# Superinstruction fusion (CPython flowgraph.c insert_superinstructions), run
# globally over every block, restricted to LOAD_FAST -> LOAD_FAST_LOAD_FAST. Runs
# BEFORE optimize_load_fast, which downgrades the non-escaping fused loads to their
# borrow variants. Comprehension bodies already emit borrow shapes by hand, so this
# finds nothing owned there and is inert on them (see emit_name_load).
#
# STORE_FAST pair fusion (STORE_FAST_{LOAD,STORE}_FAST) is deliberately NOT done
# here: jac's codegen already hand-emits those where CPython fuses (tuple targets,
# swaps), and CPython keeps some adjacent same-line store pairs unfused because they
# straddle a basic-block boundary its finer CFG splits but jac's coarser one does
# not (e.g. a comprehension's save/restore epilogue). A global store fuse would
# over-fuse exactly those, so store shapes are left to the existing emission.
def insert_superinstructions(u: unverified_cfg) {
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        i = 0;
        while i < len(b.instrs) {
            inst = b.instrs[i];
            nextop = -1;
            if i + 1 < len(b.instrs) {
                nextop = b.instrs[i + 1].opcode;
            }
            if inst.opcode == OP_LOAD_FAST and nextop == OP_LOAD_FAST {
                opt_make_super(inst, b.instrs[i + 1], OP_LOAD_FAST_LOAD_FAST);
            }
            i = i + 1;
        }
        opt_compact_block(b);
        bi = bi + 1;
    }
}

# ---------------------------------------------------------------------------
# LOAD_FAST -> LOAD_FAST_BORROW strength reduction (CPython flowgraph.c
# optimize_load_fast). Codegen emits owned LOAD_FAST for every fast-local load;
# this pass proves, per basic block via abstract interpretation over a stack of
# "references", which loads produce values that are fully consumed before their
# supporting frame local can be killed -- those can borrow. Any load whose value
# escapes (stored back as a local, left on the stack across the local's death, or
# still live at block end) stays owned. Faithful port of CPython 3.14.6; both
# sentinels NOT_LOCAL and DUMMY_INSTR are -1 there, so we mirror that.
glob LF_NOT_LOCAL: int = -1,
     LF_DUMMY_INSTR: int = -1,
     LF_SUPPORT_KILLED: int = 1,
     LF_STORED_AS_LOCAL: int = 2,
     LF_REF_UNCONSUMED: int = 4;

# Abstract operand stack of references. instr[k] = index of the instruction that
# produced ref k (or DUMMY_INSTR for a value inherited from a predecessor block);
# local[k] = the frame local it refers to (or NOT_LOCAL).
obj lf_stack {
    has instr: list[int] = [],
        local: list[int] = [];
}

def lf_push(s: lf_stack, instr: int, local: int) {
    s.instr.append(instr);
    s.local.append(local);
}

def lf_pop(s: lf_stack) -> tuple[int, int] {
    n = len(s.instr);
    if n == 0 {
        return (LF_DUMMY_INSTR, LF_NOT_LOCAL);
    }
    return (s.instr.pop(), s.local.pop());
}

def lf_at(s: lf_stack, idx: int) -> tuple[int, int] {
    if idx < 0 or idx >= len(s.instr) {
        return (LF_DUMMY_INSTR, LF_NOT_LOCAL);
    }
    return (s.instr[idx], s.local[idx]);
}

def lf_swap_top(s: lf_stack, off: int) {
    n = len(s.instr);
    idx = n - off;
    if idx < 0 or idx >= n {
        return;
    }
    ti = s.instr[idx];
    tl = s.local[idx];
    s.instr[idx] = s.instr[n - 1];
    s.local[idx] = s.local[n - 1];
    s.instr[n - 1] = ti;
    s.local[n - 1] = tl;
}

# Mark every load that supports a still-on-stack reference to `local`: overwriting
# or deleting the local kills the frame slot those borrowed refs depend on.
def lf_kill_local(flags: list[int], s: lf_stack, local: int) {
    i = 0;
    while i < len(s.instr) {
        if s.local[i] == local {
            ii = s.instr[i];
            if ii >= 0 {
                flags[ii] = flags[ii] | LF_SUPPORT_KILLED;
            }
        }
        i = i + 1;
    }
}

def lf_store_local(flags: list[int], s: lf_stack, local: int, r_instr: int) {
    lf_kill_local(flags, s, local);
    if r_instr != LF_DUMMY_INSTR {
        flags[r_instr] = flags[r_instr] | LF_STORED_AS_LOCAL;
    }
}

# The opcodes that consume no inputs (net-push new, unnamed values) -- their
# existing operands stay on the ref stack with their identity intact.
def lf_is_no_input_op(op: int) -> bool {
    return op == OP_FORMAT_SIMPLE
        or op == OP_GET_ANEXT
        or op == OP_GET_LEN
        or op == OP_GET_YIELD_FROM_ITER
        or op == OP_IMPORT_FROM
        or op == OP_MATCH_KEYS
        or op == OP_MATCH_MAPPING
        or op == OP_MATCH_SEQUENCE
        or op == OP_WITH_EXCEPT_START;
}

# The opcodes that consume some inputs and push nothing new.
def lf_is_consume_only_op(op: int) -> bool {
    return op == OP_DICT_MERGE
        or op == OP_DICT_UPDATE
        or op == OP_LIST_APPEND
        or op == OP_LIST_EXTEND
        or op == OP_MAP_ADD
        or op == OP_RERAISE
        or op == OP_SET_ADD
        or op == OP_SET_UPDATE;
}

def optimize_load_fast(u: unverified_cfg) {
    # CPython's escape analysis runs over ITS basic blocks; jac splits blocks
    # finer (e.g. at exception-region boundaries), which would strand a fast
    # load's ref identity at every seam. So analyze maximal fallthrough chains
    # of blocks as one virtual block, exactly matching CPython's granularity:
    # a chain breaks at any jump target, jump, or scope exit.
    sds = u.block_startdepths;
    jump_targets: set[int] = set();
    bj = 0;
    while bj < len(u.blocks) {
        bjt = u.blocks[bj];
        ij = 0;
        while ij < len(bjt.instrs) {
            inj = bjt.instrs[ij];
            if is_conditional_jump(inj.opcode)
                or is_unconditional_jump_opcode(inj.opcode) {
                jump_targets.add(inj.target_block);
            }
            ij = ij + 1;
        }
        bj = bj + 1;
    }
    bi = 0;
    while bi < len(u.blocks) {
        # Collect the next chain [bi..bj_end).
        bj_end = bi + 1;
        while bj_end < len(u.blocks) {
            prev_blk = u.blocks[bj_end - 1];
            nxt_blk = u.blocks[bj_end];
            np_i = len(prev_blk.instrs);
            if np_i == 0 or nxt_blk.id in jump_targets {
                break;
            }
            lop = prev_blk.instrs[np_i - 1].opcode;
            if is_conditional_jump(lop)
                or is_unconditional_jump_opcode(lop)
                or is_scope_exit_opcode(lop) {
                break;
            }
            if sds[nxt_blk.id] == UNSET_STARTDEPTH {
                break;
            }
            bj_end = bj_end + 1;
        }
        head = u.blocks[bi];
        sd = UNSET_STARTDEPTH;
        if head.id >= 0 and head.id < len(sds) {
            sd = sds[head.id];
        }
        # Unreachable via normal/jump/fallthrough edges: leave loads owned.
        if sd != UNSET_STARTDEPTH {
            # Flatten the chain into one instruction run.
            cins: list[cinstr] = [];
            coffs: list[int] = [0];
            cb = bi;
            while cb < bj_end {
                cblk = u.blocks[cb];
                ci2 = 0;
                while ci2 < len(cblk.instrs) {
                    cins.append(cblk.instrs[ci2]);
                    ci2 = ci2 + 1;
                }
                coffs.append(len(cins));
                cb = cb + 1;
            }
            n = len(cins);
            flags: list[int] = [];
            k = 0;
            while k < n {
                flags.append(0);
                k = k + 1;
            }
            s = lf_stack(instr=[], local=[]);
            # Seed the incoming stack with dummy refs (identity unknown).
            k = 0;
            while k < sd {
                lf_push(s, LF_DUMMY_INSTR, LF_NOT_LOCAL);
                k = k + 1;
            }
            i = 0;
            while i < n {
                ins = cins[i];
                op = ins.opcode;
                arg = ins.oparg;
                if op == OP_DELETE_FAST {
                    lf_kill_local(flags, s, arg);
                } elif op == OP_LOAD_FAST {
                    lf_push(s, i, arg);
                } elif op == OP_LOAD_FAST_AND_CLEAR {
                    lf_kill_local(flags, s, arg);
                    lf_push(s, i, arg);
                } elif op == OP_LOAD_FAST_LOAD_FAST {
                    lf_push(s, i, arg // 16);
                    lf_push(s, i, arg % 16);
                } elif op == OP_STORE_FAST or op == OP_STORE_FAST_MAYBE_NULL {
                    r = lf_pop(s);
                    lf_store_local(flags, s, arg, r[0]);
                } elif op == OP_STORE_FAST_LOAD_FAST {
                    r = lf_pop(s);
                    lf_store_local(flags, s, arg // 16, r[0]);
                    lf_push(s, i, arg % 16);
                } elif op == OP_STORE_FAST_STORE_FAST {
                    r = lf_pop(s);
                    lf_store_local(flags, s, arg // 16, r[0]);
                    r2 = lf_pop(s);
                    lf_store_local(flags, s, arg % 16, r2[0]);
                } elif op == OP_COPY {
                    idx = len(s.instr) - arg;
                    r = lf_at(s, idx);
                    lf_push(s, r[0], r[1]);
                } elif op == OP_SWAP {
                    lf_swap_top(s, arg);
                } elif op == OP_RETURN_VALUE {
                    # Terminator: TOS is consumed; references left below are
                    # dead frame state, not values escaping into a successor,
                    # so they reset silently (CPython still borrows such loads).
                    dr = lf_pop(s);
                    seg = 0;
                    while seg < len(s.instr) {
                        s.instr[seg] = LF_DUMMY_INSTR;
                        s.local[seg] = LF_NOT_LOCAL;
                        seg = seg + 1;
                    }
                } elif lf_is_no_input_op(op) {
                    np = _opcode_num_popped(op, arg);
                    pu = _opcode_num_pushed(op, arg);
                    net_pushed = pu - np;
                    k2 = 0;
                    while k2 < net_pushed {
                        lf_push(s, k2, LF_NOT_LOCAL);
                        k2 = k2 + 1;
                    }
                } elif lf_is_consume_only_op(op) {
                    np = _opcode_num_popped(op, arg);
                    pu = _opcode_num_pushed(op, arg);
                    net_popped = np - pu;
                    k2 = 0;
                    while k2 < net_popped {
                        dr = lf_pop(s);
                        k2 = k2 + 1;
                    }
                } elif op == OP_END_SEND or op == OP_SET_FUNCTION_ATTRIBUTE {
                    tos = lf_pop(s);
                    dr = lf_pop(s);
                    lf_push(s, tos[0], tos[1]);
                } elif op == OP_CHECK_EXC_MATCH {
                    dr = lf_pop(s);
                    lf_push(s, i, LF_NOT_LOCAL);
                } elif op == OP_FOR_ITER {
                    lf_push(s, i, LF_NOT_LOCAL);
                } elif op == OP_LOAD_ATTR or op == OP_LOAD_SUPER_ATTR {
                    self_ref = lf_pop(s);
                    if op == OP_LOAD_SUPER_ATTR {
                        dr = lf_pop(s);
                        dr2 = lf_pop(s);
                    }
                    lf_push(s, i, LF_NOT_LOCAL);
                    if arg % 2 == 1 {
                        # method form: self is conservatively pushed back.
                        lf_push(s, self_ref[0], self_ref[1]);
                    }
                } elif op == OP_LOAD_SPECIAL or op == OP_PUSH_EXC_INFO {
                    tos = lf_pop(s);
                    lf_push(s, i, LF_NOT_LOCAL);
                    lf_push(s, tos[0], tos[1]);
                } elif op == OP_SEND {
                    dr = lf_pop(s);
                    lf_push(s, i, LF_NOT_LOCAL);
                } else {
                    np = _opcode_num_popped(op, arg);
                    pu = _opcode_num_pushed(op, arg);
                    k2 = 0;
                    while k2 < np {
                        dr = lf_pop(s);
                        k2 = k2 + 1;
                    }
                    k2 = 0;
                    while k2 < pu {
                        lf_push(s, i, LF_NOT_LOCAL);
                        k2 = k2 + 1;
                    }
                }
                # CPython ends a basic block at every jump / scope exit and
                # re-seeds the next block's ref stack with dummies. Chains end
                # there too by construction, but jac coalesces conditional-jump
                # tails (e.g. match guards) into one block, so replicate the
                # fine-grained boundary inside the chain: any reference still
                # live at the jump escapes, and identities reset afterwards.
                if is_conditional_jump(op)
                    or is_unconditional_jump_opcode(op)
                    or is_scope_exit_opcode(op) {
                    seg = 0;
                    while seg < len(s.instr) {
                        pseg = s.instr[seg];
                        if pseg >= 0 {
                            flags[pseg] = flags[pseg] | LF_REF_UNCONSUMED;
                        }
                        s.instr[seg] = LF_DUMMY_INSTR;
                        s.local[seg] = LF_NOT_LOCAL;
                        seg = seg + 1;
                    }
                }
                i = i + 1;
            }
            # Any produced reference still live at chain end escapes into the
            # next block; the load that produced it must stay owned.
            j = 0;
            while j < len(s.instr) {
                pi = s.instr[j];
                if pi >= 0 {
                    flags[pi] = flags[pi] | LF_REF_UNCONSUMED;
                }
                j = j + 1;
            }
            # Strength-reduce every unflagged fast load to its borrow variant.
            i = 0;
            while i < n {
                if flags[i] == 0 {
                    op = cins[i].opcode;
                    if op == OP_LOAD_FAST {
                        cins[i].opcode = OP_LOAD_FAST_BORROW;
                    } elif op == OP_LOAD_FAST_LOAD_FAST {
                        cins[i].opcode = OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW;
                    }
                }
                i = i + 1;
            }
        }
        bi = bj_end;
    }
}

# ---------------------------------------------------------------------------
# CPython flowgraph.c add_checks_for_loads_of_uninitialized_variables. A
# worklist dataflow over "unsafe" bitmasks (local i may be uninitialized at a
# block entry): seeds are non-parameter locals at the entry block; each scanned
# instruction also propagates the block's current mask to its innermost
# exception handler (derived from except_regions, unlike CPython's per-instr
# i_except links). LOAD_FAST under an unsafe bit becomes LOAD_FAST_CHECK.
# Runs BEFORE superinstruction fusion and borrow analysis, matching CPython's
# pass order (CHECK loads never fuse or downgrade to borrows).
def ac_innermost_handler(u: unverified_cfg, pos: list[int], bid: int) -> int {
    # Innermost region covering block bid = greatest start position among
    # regions whose [start,end) layout span contains it (spans nest properly).
    if bid >= len(pos) or pos[bid] < 0 {
        return -1;
    }
    bp = pos[bid];
    best_start = -1;
    handler = -1;
    ri = 0;
    while ri < len(u.except_regions) {
        r = u.except_regions[ri];
        if r.start_block < 0
            or r.end_block < 0
            or r.start_block >= len(pos)
            or r.end_block >= len(pos) {
            ri = ri + 1;
            continue;
        }
        sp = pos[r.start_block];
        ep = pos[r.end_block];
        if sp >= 0 and ep >= 0 and sp <= bp and bp < ep and sp > best_start {
            best_start = sp;
            handler = r.handler_block;
        }
        ri = ri + 1;
    }
    return handler;
}

def ac_maybe_push(
    nbids: int,
    unsafe: int,
    masks: list[int],
    onstack: list[bool],
    blocks_by_id: list[basicblock | None],
    worklist: list[basicblock]
) {
    both = masks[nbids] | unsafe;
    if masks[nbids] != both {
        masks[nbids] = both;
        if not onstack[nbids] and blocks_by_id[nbids] is not None {
            worklist.append(blocks_by_id[nbids] as basicblock);
            onstack[nbids] = True;
        }
    }
}

def ac_scan_block(
    u: unverified_cfg,
    b: basicblock,
    pos: list[int],
    mask_in: int,
    masks: list[int],
    onstack: list[bool],
    blocks_by_id: list[basicblock | None],
    worklist: list[basicblock],
    nlocals: int
) {
    all_mask = 0;
    if nlocals < 63 {
        all_mask = (1 << nlocals) - 1;
    } else {
        all_mask = -1;
    }
    mask = mask_in & all_mask;
    h = ac_innermost_handler(u, pos, b.id);
    i = 0;
    n = len(b.instrs);
    while i < n {
        ins = b.instrs[i];
        # Exception edge: the handler can start at any point of this block.
        if h >= 0 and h < len(masks) {
            ac_maybe_push(h, mask, masks, onstack, blocks_by_id, worklist);
        }
        if ins.target_block >= 0 and ins.opcode != OP_END_ASYNC_FOR {
            ac_maybe_push(
                ins.target_block, mask, masks, onstack, blocks_by_id, worklist
            );
        }
        oparg = ins.oparg;
        # Fused superinstructions carry packed nibble pairs, so they are not
        # subject to the single-local oparg bound. Scoped pre-fusion (match
        # arms, bind seams) can produce them before this pass runs.
        op = ins.opcode;
        if op == OP_STORE_FAST_STORE_FAST
            or op == OP_STORE_FAST_LOAD_FAST
            or op == OP_LOAD_FAST_LOAD_FAST
            or op == OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW {
            f_lo = oparg & 15;
            f_hi = (oparg >> 4) & 15;
            if op == OP_STORE_FAST_STORE_FAST {
                mask = mask & ~((1 << f_lo) | (1 << f_hi));
            } elif op == OP_STORE_FAST_LOAD_FAST {
                mask = mask & ~(1 << f_hi);
                if mask & (1 << f_lo) {
                    # CHECK cannot be encoded in the fused form: split.
                    ins.opcode = OP_STORE_FAST;
                    ins.oparg = f_hi;
                    b.instrs.insert(
                        i + 1,
                        cinstr(
                            opcode=OP_LOAD_FAST_CHECK,
                            oparg=f_lo,
                            loc=ins.loc,
                            target_block=-1
                        )
                    );
                    n = n + 1;
                }
                mask = mask & ~(1 << f_lo);
            } else {
                if mask & ((1 << f_lo) | (1 << f_hi)) {
                    ins.opcode = (
                        OP_LOAD_FAST_CHECK if mask & (1 << f_hi) else OP_LOAD_FAST
                    );
                    ins.oparg = f_hi;
                    b.instrs.insert(
                        i + 1,
                        cinstr(
                            opcode=(
                                OP_LOAD_FAST_CHECK
                                    if mask & (1 << f_lo)
                                    else OP_LOAD_FAST
                            ),
                            oparg=f_lo,
                            loc=ins.loc,
                            target_block=-1
                        )
                    );
                    n = n + 1;
                }
                mask = mask & ~((1 << f_lo) | (1 << f_hi));
            }
            i = i + 1;
            continue;
        }
        if oparg >= 0 and oparg < nlocals {
            bit = 1 << oparg;
            op = ins.opcode;
            if op == OP_DELETE_FAST
                or op == OP_LOAD_FAST_AND_CLEAR
                or op == OP_STORE_FAST_MAYBE_NULL {
                mask = mask | bit;
            } elif op == OP_STORE_FAST or op == OP_LOAD_FAST_CHECK {
                mask = mask & ~bit;
            } elif op == OP_LOAD_FAST {
                if mask & bit {
                    ins.opcode = OP_LOAD_FAST_CHECK;
                }
                mask = mask & ~bit;
            }
        }
        i = i + 1;
    }
    # Fallthrough successor.
    if block_has_fallthrough(b) {
        index = pos[b.id];
        if index >= 0 and index + 1 < len(u.blocks) {
            nb = u.blocks[index + 1];
            ac_maybe_push(nb.id, mask, masks, onstack, blocks_by_id, worklist);
        }
    }
    last = block_last_instr(b);
    if last is not None
        and last.target_block >= 0
        and (
            is_conditional_jump(last.opcode)
            or is_unconditional_jump_opcode(last.opcode)
        ) {
        tb = blocks_by_id[last.target_block]
            if last.target_block < len(blocks_by_id)
            else None;
        if tb is not None {
            ac_maybe_push(tb.id, mask, masks, onstack, blocks_by_id, worklist);
        }
    }
}

def add_checks_for_uninitialized(u: unverified_cfg) {
    nlocals = len(u.varnames);
    if nlocals == 0 {
        return;
    }
    # Layout position per block id (ids are dense 0..next_block_id-1).
    nblocks = u.next_block_id;
    pos: list[int] = [];
    i = 0;
    while i < nblocks {
        pos.append(-1);
        i = i + 1;
    }
    bi = 0;
    while bi < len(u.blocks) {
        if u.blocks[bi].id < nblocks {
            pos[u.blocks[bi].id] = bi;
        }
        bi = bi + 1;
    }
    blocks_by_id: list[basicblock | None] = [];
    i = 0;
    while i < nblocks {
        blocks_by_id.append(None);
        i = i + 1;
    }
    for b in u.blocks {
        if b.id < nblocks {
            blocks_by_id[b.id] = b;
        }
    }
    masks: list[int] = [];
    onstack: list[bool] = [];
    i = 0;
    while i < nblocks {
        masks.append(0);
        onstack.append(False);
        i = i + 1;
    }
    worklist: list[basicblock] = [];
    # Seed 1: non-parameter locals are uninitialized at function entry.
    start_mask = 0;
    i = u.param_count;
    while i < nlocals {
        start_mask = start_mask | (1 << i);
        i = i + 1;
    }
    entry_blk = u.blocks[0];
    masks[entry_blk.id] = start_mask;
    onstack[entry_blk.id] = True;
    worklist.append(entry_blk);
    # Seed 2: scan every block once so DELETE_FAST origins are covered.
    bi = 0;
    while bi < len(u.blocks) {
        ac_scan_block(
            u,
            u.blocks[bi],
            pos,
            masks[u.blocks[bi].id],
            masks,
            onstack,
            blocks_by_id,
            worklist,
            nlocals
        );
        bi = bi + 1;
    }
    while len(worklist) > 0 {
        b = worklist[len(worklist) - 1];
        worklist.pop();
        onstack[b.id] = False;
        ac_scan_block(
            u, b, pos, masks[b.id], masks, onstack, blocks_by_id, worklist, nlocals
        );
    }
}

# Scoped STORE_FAST -> LOAD_FAST fusion for flagged bind-seam blocks. Runs
# after add_checks_for_uninitialized so the dataflow sees the plain store
# (CPython's CFG has these in one block and fuses after the same pass).
def fuse_flagged_stores(u: unverified_cfg) {
    bi = 0;
    while bi < len(u.blocks) {
        b = u.blocks[bi];
        if b.fuse_store_ok {
            opt_superinstructions(b, 0);
            opt_compact_block(b);
        }
        bi = bi + 1;
    }
}

# CPython flowgraph.c remove_unused_consts: after optimization, drop co_consts
# entries no longer referenced by any instruction. Index 0 is always kept
# (CPython preserves it as the potential docstring slot). Pure emission-level
# cleanup: survivors keep their relative order and const opargs are remapped.
def remove_unused_consts(u: unverified_cfg, flat: list[cinstr]) {
    n = len(u.consts);
    if n == 0 {
        return;
    }
    keep: list[bool] = [];
    remap: list[int] = [];
    i = 0;
    while i < n {
        keep.append(i == 0);
        remap.append(-1);
        i = i + 1;
    }
    for ins in flat {
        if opcode_has_const(ins.opcode) {
            a = ins.oparg;
            if a >= 0 and a < n {
                keep[a] = True;
            }
        }
    }
    used = 0;
    i = 0;
    while i < n {
        if keep[i] {
            remap[i] = used;
            used = used + 1;
        }
        i = i + 1;
    }
    if used == n {
        return;
    }
    kept: list[PyObj] = [];
    i = 0;
    while i < n {
        if keep[i] {
            kept.append(u.consts[i]);
        }
        i = i + 1;
    }
    u.consts = kept;
    u.const_indices.clear();
    u.indexed_consts = 0;
    for ins in flat {
        if opcode_has_const(ins.opcode) {
            a = ins.oparg;
            if a >= 0 and a < n and remap[a] >= 0 {
                ins.oparg = remap[a];
            }
        }
    }
}

def normalize_except_regions(u: unverified_cfg) {
    # CPython's exception lookup requires disjoint, sorted ranges. A nested
    # cleanup can sit inside an enclosing handler's protected span: select the
    # innermost span at every boundary instead of serializing overlapping rows.
    pos = build_layout_pos(u);
    spans: list[tuple[int, int, except_region]] = [];
    boundaries: set[int] = set();
    for reg in u.except_regions {
        start = layout_pos(pos, reg.start_block);
        end = layout_pos(pos, reg.end_block);
        if start < 0 or end <= start or layout_pos(pos, reg.handler_block) < 0 {
            continue;
        }
        spans.append((start, end, reg));
        boundaries.add(start);
        boundaries.add(end);
    }
    ordered = sorted(boundaries);
    result: list[except_region] = [];
    for index in range(len(ordered) - 1) {
        start = ordered[index];
        end = ordered[index + 1];
        chosen: except_region | None = None;
        chosen_start = -1;
        chosen_end = len(u.blocks);
        for (left, right, reg) in spans {
            if left <= start
                and end <= right
                and (
                    left > chosen_start or (left == chosen_start and right < chosen_end)
                ) {
                chosen = reg;
                chosen_start = left;
                chosen_end = right;
            }
        }
        if chosen is None {
            continue;
        }
        reg = chosen as except_region;
        start_id = u.blocks[start].id;
        end_id = u.blocks[end].id;
        if result
            and result[-1].end_block == start_id
            and result[-1].handler_block == reg.handler_block
            and result[-1].stack_depth == reg.stack_depth
            and result[-1].preserve_lasti == reg.preserve_lasti
            and result[-1].depth_from_block == reg.depth_from_block
            and result[-1].depth_offset == reg.depth_offset {
            result[-1].end_block = end_id;
        } else {
            result.append(
                except_region(
                    start_block=start_id,
                    end_block=end_id,
                    handler_block=reg.handler_block,
                    stack_depth=reg.stack_depth,
                    preserve_lasti=reg.preserve_lasti,
                    depth_from_block=reg.depth_from_block,
                    depth_offset=reg.depth_offset
                )
            );
        }
    }
    u.except_regions = result;
}

def verify_cfg(u: unverified_cfg) -> verified_cfg {
    # Every code unit, including lambdas and comprehensions, must resolve its
    # staged constants before optimization or operand encoding.
    u.flush_late_consts();
    normalize_except_regions(u);
    optimize_cfg(u);
    add_checks_for_uninitialized(u);
    fuse_flagged_stores(u);
    insert_superinstructions(u);
    normalize_jumps(u);
    tdiag = check_cfg_terminators(u);
    if tdiag is not None {
        return verified_cfg(unit=u, flat=[], stacksize=0, diag=tdiag);
    }
    sd = calculate_stackdepth(u);
    stacksize = sd[0];
    sdiag = sd[1];
    if sdiag is not None {
        return verified_cfg(unit=u, flat=[], stacksize=0, diag=sdiag);
    }
    # Strength-reduce owned fast loads to borrows now that per-block entry depths
    # are known (published on u by calculate_stackdepth). Preserves stack effects,
    # so the stacksize computed above stays valid.
    optimize_load_fast(u);
    # Preserve nullable restores through initialization and borrow analysis.
    # The pseudo instruction becomes STORE_FAST only when those passes finish.
    for block in u.blocks {
        for ins in block.instrs {
            if ins.opcode == OP_STORE_FAST_MAYBE_NULL {
                ins.opcode = OP_STORE_FAST;
            }
        }
    }
    fr = flatten_blocks(u);
    flat = fr.flat;
    rewrite_small_ints(u, flat);
    remove_unused_consts(u, flat);
    # Constant remapping and LOAD_SMALL_INT change instruction widths. Resolve
    # jumps only after those passes, then repeat while EXTENDED_ARG growth moves
    # block boundaries. Exception tables must use this same final layout.
    changed = True;
    while changed {
        fr = flatten_blocks(u);
        flat = fr.flat;
        block_starts = fr.block_starts;
        sizes = [instr_size_codeunits(ins) for ins in flat];
        resolve_jump_offsets(flat, block_starts);
        changed = False;
        for (index, ins) in enumerate(flat) {
            if ins.oparg < 0 or ins.oparg > 0xFFFFFFFF {
                return verified_cfg(
                    unit=u,
                    flat=[],
                    stacksize=0,
                    diag=stackdepth_diag("SystemError", "invalid instruction operand")
                );
            }
            if instr_size_codeunits(ins) != sizes[index] {
                changed = True;
            }
        }
    }
    return verified_cfg(
        unit=u, flat=flat, block_starts=block_starts, stacksize=stacksize
    );
}
