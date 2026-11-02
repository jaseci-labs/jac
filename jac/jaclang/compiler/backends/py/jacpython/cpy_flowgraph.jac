# Control flow graph construction and optimization: a port of CPython 3.14's
# Python/flowgraph.c, from the instruction sequence codegen leaves to the
# optimized instruction sequence the assembler encodes.

glob NO_LABEL: int = -1,
     MAX_COPY_SIZE: int = 4,
     STACK_USE_GUIDELINE: int = 30,
     MIN_CONST_SEQUENCE_SIZE: int = 3,
     INT_MAX: int = 2147483647,
     INTRINSIC_UNARY_POSITIVE: int = 5,
     INTRINSIC_LIST_TO_TUPLE: int = 6,
     RESUME_AT_FUNC_START: int = 0,
     RESUME_OPARG_DEPTH1_MASK: int = 4,
     SWAP_VISITED: int = -1,
     STACKDEPTH_UNSET: int = -2147483648,
     REF_NOT_LOCAL: int = -1,
     REF_DUMMY_INSTR: int = -1,
     SUPPORT_KILLED: int = 1,
     STORED_AS_LOCAL: int = 2,
     REF_UNCONSUMED: int = 4;

obj cfg_instr {
    has i_opcode: int,
        i_oparg: int,
        i_loc: srcloc,
        i_target: basicblock | None = None,
        i_except: basicblock | None = None;
}

obj cfg_except_stack {
    has handlers: list[basicblock | None] = [],
        depth: int = 0;
}

obj basicblock {
    has b_label: int = -1,
        b_exceptstack: cfg_except_stack | None = None,
        b_instr: list[cfg_instr] = [],
        b_stale: list[cfg_instr] = [],
        b_next: basicblock | None = None,
        b_unsafe_lo: int = 0,
        b_unsafe_hi: int = 0,
        b_predecessors: int = 0,
        b_startdepth: int = 0,
        b_preserve_lasti: int = 0,
        b_visited: int = 0,
        b_except_handler: int = 0,
        b_cold: int = 0,
        b_warm: int = 0;
}

obj cfg_builder {
    has g_entryblock: basicblock | None = None,
        g_block_list: list[basicblock] = [],
        g_curblock: basicblock | None = None,
        g_current_label: int = -1;
}

obj cfg_consts {
    has consts: list[PyObj] = [],
        index: dict[str, int] = {};
}

obj ref_stack {
    has instr: list[int] = [],
        local: list[int] = [];
}

def is_block_push(i: cfg_instr) -> bool {
    return is_block_push_opcode(i.i_opcode);
}

def is_jump(i: cfg_instr) -> bool {
    return opcode_has_jump(i.i_opcode);
}

def is_terminator_opcode(op: int) -> bool {
    return opcode_has_jump(op) or is_scope_exit_opcode(op);
}

def is_conditional_jump_opcode(op: int) -> bool {
    return op == OP_POP_JUMP_IF_FALSE
        or op == OP_POP_JUMP_IF_TRUE
        or op == OP_POP_JUMP_IF_NONE
        or op == OP_POP_JUMP_IF_NOT_NONE;
}

def opcode_has_eval_break(op: int) -> bool {
    return op == OP_CALL
        or op == OP_CALL_FUNCTION_EX
        or op == OP_JUMP_BACKWARD
        or op == OP_RESUME
        or op == OP_JUMP
        or op == OP_CALL_BUILTIN_CLASS
        or op == OP_CALL_BUILTIN_FAST
        or op == OP_CALL_BUILTIN_FAST_WITH_KEYWORDS
        or op == OP_CALL_BUILTIN_O
        or op == OP_CALL_KW_NON_PY
        or op == OP_CALL_METHOD_DESCRIPTOR_FAST
        or op == OP_CALL_METHOD_DESCRIPTOR_FAST_WITH_KEYWORDS
        or op == OP_CALL_METHOD_DESCRIPTOR_NOARGS
        or op == OP_CALL_METHOD_DESCRIPTOR_O
        or op == OP_CALL_NON_PY_GENERAL
        or op == OP_CALL_STR_1
        or op == OP_CALL_TUPLE_1
        or op == OP_INSTRUMENTED_CALL
        or op == OP_INSTRUMENTED_CALL_FUNCTION_EX
        or op == OP_INSTRUMENTED_JUMP_BACKWARD
        or op == OP_INSTRUMENTED_RESUME
        or op == OP_JUMP_BACKWARD_JIT
        or op == OP_JUMP_BACKWARD_NO_JIT;
}

def instr_set_op1(i: cfg_instr, op: int, arg: int) {
    i.i_opcode = op;
    i.i_oparg = arg;
}

def instr_set_op0(i: cfg_instr, op: int) {
    i.i_opcode = op;
    i.i_oparg = 0;
}

def copy_instr(i: cfg_instr) -> cfg_instr {
    return cfg_instr(
        i_opcode=i.i_opcode,
        i_oparg=i.i_oparg,
        i_loc=i.i_loc,
        i_target=i.i_target,
        i_except=i.i_except
    );
}

def new_instr(opcode: int, oparg: int, lc: srcloc) -> cfg_instr {
    return cfg_instr(
        i_opcode=opcode, i_oparg=oparg, i_loc=lc, i_target=None, i_except=None
    );
}

def basicblock_last_instr(b: basicblock) -> cfg_instr | None {
    n = len(b.b_instr);
    if n > 0 {
        return b.b_instr[n - 1];
    }
    return None;
}

def cfg_builder_new_block(g: cfg_builder) -> basicblock {
    b = basicblock(b_label=NO_LABEL, b_instr=[], b_stale=[]);
    g.g_block_list.append(b);
    return b;
}

def basicblock_next_slot_except(b: basicblock) -> basicblock | None {
    if len(b.b_stale) == 0 {
        return None;
    }
    return b.b_stale.pop(0).i_except;
}

def basicblock_addop(b: basicblock, opcode: int, oparg: int, lc: srcloc) {
    instr = new_instr(opcode, oparg, lc);
    instr.i_except = basicblock_next_slot_except(b);
    b.b_instr.append(instr);
}

def basicblock_add_jump(
    b: basicblock, opcode: int, target: basicblock, lc: srcloc
) -> int {
    last = basicblock_last_instr(b);
    if last is not None and is_jump(last) {
        return -1;
    }
    basicblock_addop(b, opcode, target.b_label, lc);
    b.b_instr[len(b.b_instr) - 1].i_target = target;
    return 0;
}

def basicblock_append_instructions(to: basicblock, frm: basicblock) {
    n = len(frm.b_instr);
    for i in range(n) {
        basicblock_next_slot_except(to);
        to.b_instr.append(copy_instr(frm.b_instr[i]));
    }
}

def basicblock_nofallthrough(b: basicblock) -> bool {
    last = basicblock_last_instr(b);
    if last is None {
        return False;
    }
    return is_scope_exit_opcode(last.i_opcode)
        or is_unconditional_jump_opcode(last.i_opcode);
}

def bb_has_fallthrough(b: basicblock) -> bool {
    return not basicblock_nofallthrough(b);
}

def copy_basicblock(g: cfg_builder, block: basicblock) -> basicblock {
    result = cfg_builder_new_block(g);
    basicblock_append_instructions(result, block);
    return result;
}

def basicblock_insert_instruction(block: basicblock, pos: int, instr: cfg_instr) {
    basicblock_next_slot_except(block);
    block.b_instr.insert(pos, instr);
}

def cfg_builder_use_next_block(g: cfg_builder, block: basicblock) -> basicblock {
    cur = g.g_curblock;
    if cur is not None {
        cur.b_next = block;
    }
    g.g_curblock = block;
    return block;
}

def basicblock_exits_scope(b: basicblock) -> bool {
    last = basicblock_last_instr(b);
    return last is not None and is_scope_exit_opcode(last.i_opcode);
}

def basicblock_has_eval_break(b: basicblock) -> bool {
    for instr in b.b_instr {
        if opcode_has_eval_break(instr.i_opcode) {
            return True;
        }
    }
    return False;
}

def cfg_builder_current_block_is_terminated(g: cfg_builder) -> bool {
    cur = g.g_curblock;
    if cur is None {
        return True;
    }
    last = basicblock_last_instr(cur);
    if last is not None and is_terminator_opcode(last.i_opcode) {
        return True;
    }
    if g.g_current_label != NO_LABEL {
        if last is not None or cur.b_label != NO_LABEL {
            return True;
        }
        cur.b_label = g.g_current_label;
        g.g_current_label = NO_LABEL;
    }
    return False;
}

def cfg_builder_maybe_start_new_block(g: cfg_builder) {
    if cfg_builder_current_block_is_terminated(g) {
        b = cfg_builder_new_block(g);
        b.b_label = g.g_current_label;
        g.g_current_label = NO_LABEL;
        cfg_builder_use_next_block(g, b);
    }
}

def cfg_builder_new -> cfg_builder {
    g = cfg_builder(g_block_list=[]);
    block = cfg_builder_new_block(g);
    g.g_entryblock = block;
    g.g_curblock = block;
    g.g_current_label = NO_LABEL;
    return g;
}

def cfg_builder_use_label(g: cfg_builder, lbl: int) {
    g.g_current_label = lbl;
    cfg_builder_maybe_start_new_block(g);
}

def cfg_builder_addop(g: cfg_builder, opcode: int, oparg: int, lc: srcloc) {
    cfg_builder_maybe_start_new_block(g);
    cur = g.g_curblock;
    if cur is not None {
        basicblock_addop(cur, opcode, oparg, lc);
    }
}

def entry_of(g: cfg_builder) -> basicblock {
    entryb = g.g_entryblock;
    if entryb is None {
        raise SystemError("control flow graph without an entryb block");
    }
    return entryb;
}

def next_nonempty_block(b: basicblock | None) -> basicblock | None {
    cur = b;
    while cur is not None and len(cur.b_instr) == 0 {
        cur = cur.b_next;
    }
    return cur;
}

def normalize_jumps_in_block(g: cfg_builder, b: basicblock) {
    last = basicblock_last_instr(b);
    if last is None or not is_conditional_jump_opcode(last.i_opcode) {
        return;
    }
    target = last.i_target;
    if target is None {
        return;
    }
    if target.b_visited == 0 {
        basicblock_addop(b, OP_NOT_TAKEN, 0, last.i_loc);
        return;
    }
    reversed_opcode = 0;
    if last.i_opcode == OP_POP_JUMP_IF_NOT_NONE {
        reversed_opcode = OP_POP_JUMP_IF_NONE;
    } elif last.i_opcode == OP_POP_JUMP_IF_NONE {
        reversed_opcode = OP_POP_JUMP_IF_NOT_NONE;
    } elif last.i_opcode == OP_POP_JUMP_IF_FALSE {
        reversed_opcode = OP_POP_JUMP_IF_TRUE;
    } elif last.i_opcode == OP_POP_JUMP_IF_TRUE {
        reversed_opcode = OP_POP_JUMP_IF_FALSE;
    }
    backwards_jump = cfg_builder_new_block(g);
    basicblock_addop(backwards_jump, OP_NOT_TAKEN, 0, last.i_loc);
    basicblock_add_jump(backwards_jump, OP_JUMP, target, last.i_loc);
    backwards_jump.b_startdepth = target.b_startdepth;
    last.i_opcode = reversed_opcode;
    last.i_target = b.b_next;
    backwards_jump.b_cold = b.b_cold;
    backwards_jump.b_next = b.b_next;
    b.b_next = backwards_jump;
}

def normalize_jumps(g: cfg_builder) {
    entryb = entry_of(g);
    b: basicblock | None = entryb;
    while b is not None {
        b.b_visited = 0;
        b = b.b_next;
    }
    b = entryb;
    while b is not None {
        b.b_visited = 1;
        normalize_jumps_in_block(g, b);
        b = b.b_next;
    }
}

def check_cfg(g: cfg_builder) {
    b: basicblock | None = entry_of(g);
    while b is not None {
        n = len(b.b_instr);
        for i in range(n) {
            if is_terminator_opcode(b.b_instr[i].i_opcode) and i != n - 1 {
                raise SystemError("malformed control flow graph.");
            }
        }
        b = b.b_next;
    }
}

def get_max_label(entryblock: basicblock) -> int {
    lbl = -1;
    b: basicblock | None = entryblock;
    while b is not None {
        if b.b_label > lbl {
            lbl = b.b_label;
        }
        b = b.b_next;
    }
    return lbl;
}

def translate_jump_labels_to_targets(entryblock: basicblock) {
    max_label = get_max_label(entryblock);
    label2block: list[basicblock | None] = [];
    for k in range(max_label + 1) {
        label2block.append(None);
    }
    b: basicblock | None = entryblock;
    while b is not None {
        if b.b_label >= 0 {
            label2block[b.b_label] = b;
        }
        b = b.b_next;
    }
    b = entryblock;
    while b is not None {
        for instr in b.b_instr {
            if has_target(instr.i_opcode) {
                lbl = instr.i_oparg;
                if lbl < 0 or lbl > max_label {
                    raise SystemError("jump to an undefined label");
                }
                instr.i_target = label2block[lbl];
            }
        }
        b = b.b_next;
    }
}

def mark_except_handlers(entryblock: basicblock) {
    b: basicblock | None = entryblock;
    while b is not None {
        for instr in b.b_instr {
            if is_block_push(instr) {
                target = instr.i_target;
                if target is not None {
                    target.b_except_handler = 1;
                }
            }
        }
        b = b.b_next;
    }
}

def make_except_stack -> cfg_except_stack {
    return cfg_except_stack(handlers=[None], depth=0);
}

def copy_except_stack(stack: cfg_except_stack) -> cfg_except_stack {
    handlers: list[basicblock | None] = [];
    for h in stack.handlers {
        handlers.append(h);
    }
    return cfg_except_stack(handlers=handlers, depth=stack.depth);
}

def push_except_block(stack: cfg_except_stack, setup: cfg_instr) -> basicblock | None {
    target = setup.i_target;
    if target is not None
        and (setup.i_opcode == OP_SETUP_WITH or setup.i_opcode == OP_SETUP_CLEANUP) {
        target.b_preserve_lasti = 1;
    }
    stack.depth += 1;
    while len(stack.handlers) <= stack.depth {
        stack.handlers.append(None);
    }
    stack.handlers[stack.depth] = target;
    return target;
}

def pop_except_block(stack: cfg_except_stack) -> basicblock | None {
    stack.depth -= 1;
    return stack.handlers[stack.depth];
}

def except_stack_top(stack: cfg_except_stack) -> basicblock | None {
    return stack.handlers[stack.depth];
}

def reset_visited(entryblock: basicblock) {
    b: basicblock | None = entryblock;
    while b is not None {
        b.b_visited = 0;
        b = b.b_next;
    }
}

def get_stack_effect(opcode: int, oparg: int, jump: int) -> int {
    eff = stack_effect(opcode, oparg, jump);
    if eff is None {
        raise SystemError(
            "Invalid stack effect for opcode=" + str(opcode) + ", arg=" + str(oparg)
        );
    }
    return eff;
}

def stackdepth_push(sp: list[basicblock], b: basicblock, depth: int) {
    if not (b.b_startdepth < 0 or b.b_startdepth == depth) {
        raise ValueError("Invalid CFG, inconsistent stackdepth");
    }
    if b.b_startdepth < depth and b.b_startdepth < 100 {
        b.b_startdepth = depth;
        sp.append(b);
    }
}

def calculate_stackdepth(g: cfg_builder) -> int {
    entryblock = entry_of(g);
    b: basicblock | None = entryblock;
    while b is not None {
        b.b_startdepth = STACKDEPTH_UNSET;
        b = b.b_next;
    }
    reset_visited(entryblock);
    maxdepth = 0;
    sp: list[basicblock] = [];
    stackdepth_push(sp, entryblock, 0);
    while len(sp) > 0 {
        blk = sp.pop();
        depth = blk.b_startdepth;
        nxt = blk.b_next;
        for instr in blk.b_instr {
            net = get_stack_effect(instr.i_opcode, instr.i_oparg, 0);
            new_depth = depth + net;
            if new_depth < 0 {
                raise ValueError("Invalid CFG, stack underflow");
            }
            if depth > maxdepth {
                maxdepth = depth;
            }
            if has_target(instr.i_opcode) and instr.i_opcode != OP_END_ASYNC_FOR {
                jnet = get_stack_effect(instr.i_opcode, instr.i_oparg, 1);
                target_depth = depth + jnet;
                target = instr.i_target;
                if target is not None {
                    stackdepth_push(sp, target, target_depth);
                }
            }
            depth = new_depth;
            if is_unconditional_jump_opcode(instr.i_opcode)
                or is_scope_exit_opcode(instr.i_opcode) {
                nxt = None;
                break;
            }
        }
        if nxt is not None {
            stackdepth_push(sp, nxt, depth);
        }
    }
    return maxdepth;
}

def label_exception_targets(entryblock: basicblock) {
    reset_visited(entryblock);
    todo: list[basicblock] = [];
    except_stack: cfg_except_stack | None = make_except_stack();
    todo.append(entryblock);
    entryblock.b_visited = 1;
    entryblock.b_exceptstack = except_stack;
    while len(todo) > 0 {
        b = todo.pop();
        except_stack = b.b_exceptstack;
        b.b_exceptstack = None;
        if except_stack is None {
            raise SystemError("basic block without an exception stack");
        }
        handler = except_stack_top(except_stack);
        last_yield_except_depth = -1;
        for instr in b.b_instr {
            if is_block_push(instr) {
                target = instr.i_target;
                if target is not None and not target.b_visited {
                    target.b_exceptstack = copy_except_stack(except_stack);
                    todo.append(target);
                    target.b_visited = 1;
                }
                handler = push_except_block(except_stack, instr);
            } elif instr.i_opcode == OP_POP_BLOCK {
                handler = pop_except_block(except_stack);
                instr_set_op0(instr, OP_NOP);
            } elif is_jump(instr) {
                instr.i_except = handler;
                target = instr.i_target;
                if target is not None and not target.b_visited {
                    if bb_has_fallthrough(b) {
                        target.b_exceptstack = copy_except_stack(except_stack);
                    } else {
                        target.b_exceptstack = except_stack;
                    }
                    todo.append(target);
                    target.b_visited = 1;
                }
            } elif instr.i_opcode == OP_YIELD_VALUE {
                instr.i_except = handler;
                last_yield_except_depth = except_stack.depth;
            } elif instr.i_opcode == OP_RESUME {
                instr.i_except = handler;
                if instr.i_oparg != RESUME_AT_FUNC_START {
                    if last_yield_except_depth == 1 {
                        instr.i_oparg = instr.i_oparg | RESUME_OPARG_DEPTH1_MASK;
                    }
                    last_yield_except_depth = -1;
                }
            } else {
                instr.i_except = handler;
            }
        }
        nxt = b.b_next;
        if bb_has_fallthrough(b) and nxt is not None and not nxt.b_visited {
            nxt.b_exceptstack = except_stack;
            todo.append(nxt);
            nxt.b_visited = 1;
        }
    }
}

def remove_unreachable(entryblock: basicblock) {
    b: basicblock | None = entryblock;
    while b is not None {
        b.b_predecessors = 0;
        b = b.b_next;
    }
    reset_visited(entryblock);
    stack: list[basicblock] = [];
    entryblock.b_predecessors = 1;
    stack.append(entryblock);
    entryblock.b_visited = 1;
    while len(stack) > 0 {
        cur = stack.pop();
        nxt = cur.b_next;
        if nxt is not None and bb_has_fallthrough(cur) {
            if not nxt.b_visited {
                stack.append(nxt);
                nxt.b_visited = 1;
            }
            nxt.b_predecessors += 1;
        }
        for instr in cur.b_instr {
            if is_jump(instr) or is_block_push(instr) {
                target = instr.i_target;
                if target is not None {
                    if not target.b_visited {
                        stack.append(target);
                        target.b_visited = 1;
                    }
                    target.b_predecessors += 1;
                }
            }
        }
    }
    b = entryblock;
    while b is not None {
        if b.b_predecessors == 0 {
            truncate_instrs(b, 0);
            b.b_except_handler = 0;
        }
        b = b.b_next;
    }
}

def truncate_instrs(bb: basicblock, size: int) {
    stale: list[cfg_instr] = [];
    for k in range(size, len(bb.b_instr)) {
        stale.append(bb.b_instr[k]);
    }
    for old in bb.b_stale {
        stale.append(old);
    }
    bb.b_stale = stale;
    while len(bb.b_instr) > size {
        bb.b_instr.pop();
    }
}

def basicblock_remove_redundant_nops(bb: basicblock) -> int {
    dest = 0;
    prev_lineno = -1;
    n = len(bb.b_instr);
    for src in range(n) {
        instr = bb.b_instr[src];
        lineno = instr.i_loc.lineno;
        if instr.i_opcode == OP_NOP {
            if lineno < 0 {
                continue;
            }
            if prev_lineno == lineno {
                continue;
            }
            if src < n - 1 {
                following = bb.b_instr[src + 1];
                next_lineno = following.i_loc.lineno;
                if next_lineno == lineno {
                    continue;
                }
                if next_lineno < 0 {
                    following.i_loc = instr.i_loc;
                    continue;
                }
            } else {
                nxt = next_nonempty_block(bb.b_next);
                if nxt is not None {
                    next_loc = no_location();
                    for ni in nxt.b_instr {
                        if ni.i_opcode == OP_NOP and ni.i_loc.lineno < 0 {
                            continue;
                        }
                        next_loc = ni.i_loc;
                        break;
                    }
                    if lineno == next_loc.lineno {
                        continue;
                    }
                }
            }
        }
        if dest != src {
            bb.b_instr[dest] = instr;
        }
        dest += 1;
        prev_lineno = lineno;
    }
    num_removed = n - dest;
    truncate_instrs(bb, dest);
    return num_removed;
}

def remove_redundant_nops(g: cfg_builder) -> int {
    changes = 0;
    b: basicblock | None = entry_of(g);
    while b is not None {
        changes += basicblock_remove_redundant_nops(b);
        b = b.b_next;
    }
    return changes;
}

def remove_redundant_nops_and_pairs(entryblock: basicblock) {
    done = False;
    while not done {
        done = True;
        prev_instr: cfg_instr | None = None;
        instr: cfg_instr | None = None;
        b: basicblock | None = entryblock;
        while b is not None {
            basicblock_remove_redundant_nops(b);
            if b.b_label != NO_LABEL {
                instr = None;
            }
            for cur in b.b_instr {
                prev_instr = instr;
                instr = cur;
                prev_opcode = 0;
                prev_oparg = 0;
                if prev_instr is not None {
                    prev_opcode = prev_instr.i_opcode;
                    prev_oparg = prev_instr.i_oparg;
                }
                is_redundant_pair = False;
                if cur.i_opcode == OP_POP_TOP {
                    if prev_opcode == OP_LOAD_CONST
                        or prev_opcode == OP_LOAD_SMALL_INT {
                        is_redundant_pair = True;
                    } elif prev_opcode == OP_COPY and prev_oparg == 1 {
                        is_redundant_pair = True;
                    }
                }
                if is_redundant_pair and prev_instr is not None {
                    instr_set_op0(prev_instr, OP_NOP);
                    instr_set_op0(cur, OP_NOP);
                    done = False;
                }
            }
            if (instr is not None and is_jump(instr)) or not bb_has_fallthrough(b) {
                instr = None;
            }
            b = b.b_next;
        }
    }
}

def remove_redundant_jumps(g: cfg_builder) -> int {
    changes = 0;
    b: basicblock | None = entry_of(g);
    while b is not None {
        last = basicblock_last_instr(b);
        if last is not None and is_unconditional_jump_opcode(last.i_opcode) {
            jump_target = next_nonempty_block(last.i_target);
            if jump_target is None {
                raise SystemError("jump with NULL target");
            }
            nxt = next_nonempty_block(b.b_next);
            if jump_target is nxt {
                changes += 1;
                instr_set_op0(last, OP_NOP);
            }
        }
        b = b.b_next;
    }
    return changes;
}

def basicblock_has_no_lineno(b: basicblock) -> bool {
    for instr in b.b_instr {
        if instr.i_loc.lineno >= 0 {
            return False;
        }
    }
    return True;
}

def basicblock_inline_small_or_no_lineno_blocks(bb: basicblock) -> int {
    last = basicblock_last_instr(bb);
    if last is None {
        return 0;
    }
    if not is_unconditional_jump_opcode(last.i_opcode) {
        return 0;
    }
    target = last.i_target;
    if target is None {
        return 0;
    }
    small_exit_block = basicblock_exits_scope(target)
        and len(target.b_instr) <= MAX_COPY_SIZE;
    no_lineno_no_fallthrough = basicblock_has_no_lineno(target)
        and not bb_has_fallthrough(target);
    if small_exit_block or no_lineno_no_fallthrough {
        removed_jump_opcode = last.i_opcode;
        instr_set_op0(last, OP_NOP);
        basicblock_append_instructions(bb, target);
        if no_lineno_no_fallthrough {
            newlast = basicblock_last_instr(bb);
            if newlast is not None
                and is_unconditional_jump_opcode(newlast.i_opcode)
                and removed_jump_opcode == OP_JUMP {
                newlast.i_opcode = OP_JUMP;
            }
        }
        target.b_predecessors -= 1;
        return 1;
    }
    return 0;
}

def inline_small_or_no_lineno_blocks(entryblock: basicblock) {
    changes = True;
    while changes {
        changes = False;
        b: basicblock | None = entryblock;
        while b is not None {
            if basicblock_inline_small_or_no_lineno_blocks(b) {
                changes = True;
            }
            b = b.b_next;
        }
    }
}

def jump_thread(
    bb: basicblock, inst: cfg_instr, target: cfg_instr, opcode: int
) -> bool {
    tt = target.i_target;
    if inst.i_target is not tt and tt is not None {
        instr_set_op0(inst, OP_NOP);
        if basicblock_add_jump(bb, opcode, tt, target.i_loc) < 0 {
            return True;
        }
        return True;
    }
    return False;
}

def loads_const(opcode: int) -> bool {
    return opcode_has_const(opcode) or opcode == OP_LOAD_SMALL_INT;
}

def get_const_value(opcode: int, oparg: int, cc: cfg_consts) -> PyObj {
    if opcode == OP_LOAD_CONST {
        n = len(cc.consts);
        if oparg < 0 or oparg >= n {
            raise ValueError(
                "LOAD_CONST index "
                    + str(oparg)
                    + " is out of range for consts (len="
                    + str(n)
                    + ")"
            );
        }
        return cc.consts[oparg];
    }
    if opcode == OP_LOAD_SMALL_INT {
        return PyInt(t="int", val=oparg);
    }
    raise SystemError("Internal error: failed to get value of a constant");
}

def cfg_consts_new(consts: list[PyObj]) -> cfg_consts {
    cc = cfg_consts(consts=consts, index={});
    for i in range(len(consts)) {
        key = constant_key(consts[i]);
        if key not in cc.index {
            cc.index[key] = i;
        }
    }
    return cc;
}

def add_const(newconst: PyObj, cc: cfg_consts) -> int {
    key = constant_key(newconst);
    if key in cc.index {
        return cc.index[key];
    }
    index = len(cc.consts);
    if index >= INT_MAX - 1 {
        raise OverflowError("too many constants");
    }
    cc.consts.append(newconst);
    cc.index[key] = index;
    return index;
}

def get_const_loading_instrs(
    bb: basicblock, start: int, size: int
) -> list[cfg_instr] | None {
    collected: list[cfg_instr] = [];
    pos = start;
    remaining = size;
    while pos >= 0 and remaining > 0 {
        instr = bb.b_instr[pos];
        pos -= 1;
        if instr.i_opcode == OP_NOP {
            continue;
        }
        if not loads_const(instr.i_opcode) {
            return None;
        }
        collected.append(instr);
        remaining -= 1;
    }
    if remaining != 0 {
        return None;
    }
    result: list[cfg_instr] = [];
    k = len(collected) - 1;
    while k >= 0 {
        result.append(collected[k]);
        k -= 1;
    }
    return result;
}

def nop_out(instrs: list[cfg_instr]) {
    for instr in instrs {
        instr_set_op0(instr, OP_NOP);
        instr.i_loc = no_location();
    }
}

def maybe_instr_make_load_smallint(instr: cfg_instr, newconst: PyObj) -> bool {
    val = small_int_value(newconst);
    if val >= 0 {
        instr_set_op1(instr, OP_LOAD_SMALL_INT, val);
        return True;
    }
    return False;
}

def instr_make_load_const(instr: cfg_instr, newconst: PyObj, cc: cfg_consts) {
    if maybe_instr_make_load_smallint(instr, newconst) {
        return;
    }
    oparg = add_const(newconst, cc);
    instr_set_op1(instr, OP_LOAD_CONST, oparg);
}

def const_values(instrs: list[cfg_instr], cc: cfg_consts) -> list[PyObj] {
    values: list[PyObj] = [];
    for inst in instrs {
        values.append(get_const_value(inst.i_opcode, inst.i_oparg, cc));
    }
    return values;
}

def fold_tuple_of_constants(bb: basicblock, i: int, cc: cfg_consts) {
    instr = bb.b_instr[i];
    seq_size = instr.i_oparg;
    if seq_size > STACK_USE_GUIDELINE {
        return;
    }
    const_instrs = get_const_loading_instrs(bb, i - 1, seq_size);
    if const_instrs is None {
        return;
    }
    const_tuple = PyTuple(t="tuple", items=const_values(const_instrs, cc));
    nop_out(const_instrs);
    instr_make_load_const(instr, const_tuple, cc);
}

def fold_constant_intrinsic_list_to_tuple(bb: basicblock, i: int, cc: cfg_consts) {
    intrinsic = bb.b_instr[i];
    consts_found = 0;
    expect_append = True;
    pos = i - 1;
    while pos >= 0 {
        instr = bb.b_instr[pos];
        opcode = instr.i_opcode;
        oparg = instr.i_oparg;
        if opcode == OP_NOP {
            pos -= 1;
            continue;
        }
        if opcode == OP_BUILD_LIST and oparg == 0 {
            if not expect_append {
                return;
            }
            items: list[PyObj] = [];
            newpos = i - 1;
            while newpos >= pos {
                cur = bb.b_instr[newpos];
                newpos -= 1;
                if cur.i_opcode == OP_NOP {
                    continue;
                }
                if loads_const(cur.i_opcode) {
                    items.append(get_const_value(cur.i_opcode, cur.i_oparg, cc));
                }
                nop_out([cur]);
            }
            ordered: list[PyObj] = [];
            k = len(items) - 1;
            while k >= 0 {
                ordered.append(items[k]);
                k -= 1;
            }
            instr_make_load_const(intrinsic, PyTuple(t="tuple", items=ordered), cc);
            return;
        }
        if expect_append {
            if opcode != OP_LIST_APPEND or oparg != 1 {
                return;
            }
        } else {
            if not loads_const(opcode) {
                return;
            }
            consts_found += 1;
        }
        expect_append = not expect_append;
        pos -= 1;
    }
}

def optimize_lists_and_sets(bb: basicblock, i: int, nextop: int, cc: cfg_consts) {
    instr = bb.b_instr[i];
    contains_or_iter = nextop == OP_GET_ITER or nextop == OP_CONTAINS_OP;
    seq_size = instr.i_oparg;
    if seq_size > STACK_USE_GUIDELINE
        or (seq_size < MIN_CONST_SEQUENCE_SIZE and not contains_or_iter) {
        return;
    }
    const_instrs = get_const_loading_instrs(bb, i - 1, seq_size);
    if const_instrs is None {
        if contains_or_iter and instr.i_opcode == OP_BUILD_LIST {
            instr_set_op1(instr, OP_BUILD_TUPLE, instr.i_oparg);
        }
        return;
    }
    values = const_values(const_instrs, cc);
    const_result: PyObj = PyTuple(t="tuple", items=values);
    if instr.i_opcode == OP_BUILD_SET {
        frozen = make_frozenset(values);
        if frozen is None {
            return;
        }
        const_result = frozen;
    }
    index = add_const(const_result, cc);
    nop_out(const_instrs);
    if contains_or_iter {
        instr_set_op1(instr, OP_LOAD_CONST, index);
    } else {
        build_op = instr.i_opcode;
        first = bb.b_instr[i - 2];
        first.i_loc = instr.i_loc;
        instr_set_op1(first, build_op, 0);
        instr_set_op1(bb.b_instr[i - 1], OP_LOAD_CONST, index);
        instr_set_op1(
            instr, OP_LIST_EXTEND if build_op == OP_BUILD_LIST else OP_SET_UPDATE, 1
        );
    }
}

def fold_const_binop(bb: basicblock, i: int, cc: cfg_consts) {
    binop = bb.b_instr[i];
    operands_instrs = get_const_loading_instrs(bb, i - 1, 2);
    if operands_instrs is None {
        return;
    }
    lhs_instr = operands_instrs[0];
    lhs = get_const_value(lhs_instr.i_opcode, lhs_instr.i_oparg, cc);
    rhs_instr = operands_instrs[1];
    rhs = get_const_value(rhs_instr.i_opcode, rhs_instr.i_oparg, cc);
    newconst = eval_const_binop(lhs, binop.i_oparg, rhs);
    if newconst is None {
        return;
    }
    nop_out(operands_instrs);
    instr_make_load_const(binop, newconst, cc);
}

def fold_const_unaryop(bb: basicblock, i: int, cc: cfg_consts) {
    unaryop = bb.b_instr[i];
    operand_instrs = get_const_loading_instrs(bb, i - 1, 1);
    if operand_instrs is None {
        return;
    }
    operand_instr = operand_instrs[0];
    operand = get_const_value(operand_instr.i_opcode, operand_instr.i_oparg, cc);
    newconst = eval_const_unaryop(operand, unaryop.i_opcode, unaryop.i_oparg);
    if newconst is None {
        return;
    }
    nop_out(operand_instrs);
    instr_make_load_const(unaryop, newconst, cc);
}

def swaptimize(block: basicblock, ix: int) -> int {
    instrs = block.b_instr;
    depth = instrs[ix].i_oparg;
    length = 0;
    more = False;
    limit = len(instrs) - ix;
    length += 1;
    while length < limit {
        opcode = instrs[ix + length].i_opcode;
        if opcode == OP_SWAP {
            if instrs[ix + length].i_oparg > depth {
                depth = instrs[ix + length].i_oparg;
            }
            more = True;
        } elif opcode != OP_NOP {
            break;
        }
        length += 1;
    }
    if not more {
        return ix;
    }
    stack: list[int] = [];
    for k in range(depth) {
        stack.append(k);
    }
    for k in range(length) {
        if instrs[ix + k].i_opcode == OP_SWAP {
            oparg = instrs[ix + k].i_oparg;
            top = stack[0];
            stack[0] = stack[oparg - 1];
            stack[oparg - 1] = top;
        }
    }
    current = length - 1;
    for k in range(depth) {
        if stack[k] == SWAP_VISITED or stack[k] == k {
            continue;
        }
        j = k;
        while True {
            if j {
                instrs[ix + current].i_opcode = OP_SWAP;
                instrs[ix + current].i_oparg = j + 1;
                current -= 1;
            }
            if stack[j] == SWAP_VISITED {
                break;
            }
            next_j = stack[j];
            stack[j] = SWAP_VISITED;
            j = next_j;
        }
    }
    while 0 <= current {
        instr_set_op0(instrs[ix + current], OP_NOP);
        current -= 1;
    }
    return ix + length - 1;
}

def swappable(opcode: int) -> bool {
    return opcode == OP_STORE_FAST
        or opcode == OP_STORE_FAST_MAYBE_NULL
        or opcode == OP_POP_TOP;
}

def stores_to(instr: cfg_instr) -> int {
    if instr.i_opcode == OP_STORE_FAST or instr.i_opcode == OP_STORE_FAST_MAYBE_NULL {
        return instr.i_oparg;
    }
    return -1;
}

def next_swappable_instruction(block: basicblock, i: int, lineno: int) -> int {
    k = i + 1;
    while k < len(block.b_instr) {
        instruction = block.b_instr[k];
        if 0 <= lineno and instruction.i_loc.lineno != lineno {
            return -1;
        }
        if instruction.i_opcode == OP_NOP {
            k += 1;
            continue;
        }
        if swappable(instruction.i_opcode) {
            return k;
        }
        return -1;
    }
    return -1;
}

def apply_static_swaps(block: basicblock, start: int) {
    i = start;
    while 0 <= i {
        swap = block.b_instr[i];
        if swap.i_opcode != OP_SWAP {
            if swap.i_opcode == OP_NOP or swappable(swap.i_opcode) {
                i -= 1;
                continue;
            }
            return;
        }
        j = next_swappable_instruction(block, i, -1);
        if j < 0 {
            return;
        }
        k = j;
        lineno = block.b_instr[j].i_loc.lineno;
        count = swap.i_oparg - 1;
        while 0 < count {
            k = next_swappable_instruction(block, k, lineno);
            if k < 0 {
                return;
            }
            count -= 1;
        }
        store_j = stores_to(block.b_instr[j]);
        store_k = stores_to(block.b_instr[k]);
        if store_j >= 0 or store_k >= 0 {
            if store_j == store_k {
                return;
            }
            for idx in range(j + 1, k) {
                store_idx = stores_to(block.b_instr[idx]);
                if store_idx >= 0 and (store_idx == store_j or store_idx == store_k) {
                    return;
                }
            }
        }
        instr_set_op0(swap, OP_NOP);
        temp = block.b_instr[j];
        block.b_instr[j] = block.b_instr[k];
        block.b_instr[k] = temp;
        i -= 1;
    }
}

def basicblock_optimize_load_const(bb: basicblock, cc: cfg_consts) {
    opcode = 0;
    oparg = 0;
    n = len(bb.b_instr);
    for i in range(n) {
        inst = bb.b_instr[i];
        if inst.i_opcode == OP_LOAD_CONST {
            constant = get_const_value(inst.i_opcode, inst.i_oparg, cc);
            maybe_instr_make_load_smallint(inst, constant);
        }
        is_copy_of_load_const = opcode == OP_LOAD_CONST
            and inst.i_opcode == OP_COPY
            and inst.i_oparg == 1;
        if not is_copy_of_load_const {
            opcode = inst.i_opcode;
            oparg = inst.i_oparg;
        }
        if opcode != OP_LOAD_CONST and opcode != OP_LOAD_SMALL_INT {
            continue;
        }
        nextop = bb.b_instr[i + 1].i_opcode if i + 1 < n else 0;
        if nextop == OP_POP_JUMP_IF_FALSE
            or nextop == OP_POP_JUMP_IF_TRUE
            or nextop == OP_JUMP_IF_FALSE
            or nextop == OP_JUMP_IF_TRUE {
            cnt = get_const_value(opcode, oparg, cc);
            is_true = const_is_true(cnt);
            if stack_effect(nextop, 0, -1) == -1 {
                instr_set_op0(inst, OP_NOP);
            }
            jump_if_true = 1
                if nextop == OP_POP_JUMP_IF_TRUE or nextop == OP_JUMP_IF_TRUE
                else 0;
            if is_true == jump_if_true {
                bb.b_instr[i + 1].i_opcode = OP_JUMP;
            } else {
                instr_set_op0(bb.b_instr[i + 1], OP_NOP);
            }
        } elif nextop == OP_IS_OP {
            cnt = get_const_value(opcode, oparg, cc);
            if not isinstance(cnt, PyNoneType) {
                continue;
            }
            if n <= i + 2 {
                continue;
            }
            is_instr = bb.b_instr[i + 1];
            jump_instr = bb.b_instr[i + 2];
            if jump_instr.i_opcode == OP_TO_BOOL {
                instr_set_op0(jump_instr, OP_NOP);
                if n <= i + 3 {
                    continue;
                }
                jump_instr = bb.b_instr[i + 3];
            }
            invert = is_instr.i_oparg != 0;
            if jump_instr.i_opcode == OP_POP_JUMP_IF_FALSE {
                invert = not invert;
            } elif jump_instr.i_opcode != OP_POP_JUMP_IF_TRUE {
                continue;
            }
            instr_set_op0(inst, OP_NOP);
            instr_set_op0(is_instr, OP_NOP);
            jump_instr.i_opcode = OP_POP_JUMP_IF_NOT_NONE
                if invert
                else OP_POP_JUMP_IF_NONE;
        } elif nextop == OP_TO_BOOL {
            cnt = get_const_value(opcode, oparg, cc);
            is_true = const_is_true(cnt);
            index = add_const(PyBool(t="bool", val=is_true == 1), cc);
            instr_set_op0(inst, OP_NOP);
            instr_set_op1(bb.b_instr[i + 1], OP_LOAD_CONST, index);
        }
    }
}

def optimize_load_const(g: cfg_builder, cc: cfg_consts) {
    b: basicblock | None = entry_of(g);
    while b is not None {
        basicblock_optimize_load_const(b, cc);
        b = b.b_next;
    }
}

def optimize_basic_block(bb: basicblock, cc: cfg_consts) {
    nop = new_instr(OP_NOP, 0, no_location());
    i = 0;
    while i < len(bb.b_instr) {
        inst = bb.b_instr[i];
        opcode = inst.i_opcode;
        oparg = inst.i_oparg;
        target = nop;
        if has_target(opcode) {
            tb = inst.i_target;
            if tb is not None and len(tb.b_instr) > 0 {
                target = tb.b_instr[0];
            }
        }
        nextop = bb.b_instr[i + 1].i_opcode if i + 1 < len(bb.b_instr) else 0;
        if opcode == OP_BUILD_TUPLE {
            if nextop == OP_UNPACK_SEQUENCE and oparg == bb.b_instr[i + 1].i_oparg {
                if oparg == 1 {
                    instr_set_op0(inst, OP_NOP);
                    instr_set_op0(bb.b_instr[i + 1], OP_NOP);
                    i += 1;
                    continue;
                }
                if oparg == 2 or oparg == 3 {
                    instr_set_op0(inst, OP_NOP);
                    bb.b_instr[i + 1].i_opcode = OP_SWAP;
                    i += 1;
                    continue;
                }
            }
            fold_tuple_of_constants(bb, i, cc);
        } elif opcode == OP_BUILD_LIST or opcode == OP_BUILD_SET {
            optimize_lists_and_sets(bb, i, nextop, cc);
        } elif opcode == OP_POP_JUMP_IF_NOT_NONE or opcode == OP_POP_JUMP_IF_NONE {
            if target.i_opcode == OP_JUMP {
                if jump_thread(bb, inst, target, inst.i_opcode) {
                    i -= 1;
                }
            }
        } elif opcode == OP_POP_JUMP_IF_FALSE {
            if target.i_opcode == OP_JUMP {
                if jump_thread(bb, inst, target, OP_POP_JUMP_IF_FALSE) {
                    i -= 1;
                }
            }
        } elif opcode == OP_POP_JUMP_IF_TRUE {
            if target.i_opcode == OP_JUMP {
                if jump_thread(bb, inst, target, OP_POP_JUMP_IF_TRUE) {
                    i -= 1;
                }
            }
        } elif opcode == OP_JUMP_IF_FALSE {
            if target.i_opcode == OP_JUMP or target.i_opcode == OP_JUMP_IF_FALSE {
                if jump_thread(bb, inst, target, OP_JUMP_IF_FALSE) {
                    i -= 1;
                }
                i += 1;
                continue;
            }
            if target.i_opcode == OP_JUMP_IF_TRUE {
                tb2 = inst.i_target;
                if tb2 is not None {
                    inst.i_target = tb2.b_next;
                }
                continue;
            }
        } elif opcode == OP_JUMP_IF_TRUE {
            if target.i_opcode == OP_JUMP or target.i_opcode == OP_JUMP_IF_TRUE {
                if jump_thread(bb, inst, target, OP_JUMP_IF_TRUE) {
                    i -= 1;
                }
                i += 1;
                continue;
            }
            if target.i_opcode == OP_JUMP_IF_FALSE {
                tb3 = inst.i_target;
                if tb3 is not None {
                    inst.i_target = tb3.b_next;
                }
                continue;
            }
        } elif opcode == OP_JUMP or opcode == OP_JUMP_NO_INTERRUPT {
            if target.i_opcode == OP_JUMP {
                if jump_thread(bb, inst, target, OP_JUMP) {
                    i -= 1;
                }
                i += 1;
                continue;
            }
            if target.i_opcode == OP_JUMP_NO_INTERRUPT {
                if jump_thread(bb, inst, target, opcode) {
                    i -= 1;
                }
                i += 1;
                continue;
            }
        } elif opcode == OP_STORE_FAST {
            if opcode == nextop
                and oparg == bb.b_instr[i + 1].i_oparg
                and inst.i_loc.lineno == bb.b_instr[i + 1].i_loc.lineno {
                inst.i_opcode = OP_POP_TOP;
                inst.i_oparg = 0;
            }
        } elif opcode == OP_SWAP {
            if oparg == 1 {
                instr_set_op0(inst, OP_NOP);
            }
        } elif opcode == OP_LOAD_GLOBAL {
            if nextop == OP_PUSH_NULL and (oparg & 1) == 0 {
                instr_set_op1(inst, OP_LOAD_GLOBAL, oparg | 1);
                instr_set_op0(bb.b_instr[i + 1], OP_NOP);
            }
        } elif opcode == OP_COMPARE_OP {
            if nextop == OP_TO_BOOL {
                instr_set_op0(inst, OP_NOP);
                instr_set_op1(bb.b_instr[i + 1], OP_COMPARE_OP, oparg | 16);
                i += 1;
                continue;
            }
        } elif opcode == OP_CONTAINS_OP or opcode == OP_IS_OP {
            if nextop == OP_TO_BOOL {
                instr_set_op0(inst, OP_NOP);
                instr_set_op1(bb.b_instr[i + 1], opcode, oparg);
                i += 1;
                continue;
            }
            if nextop == OP_UNARY_NOT {
                instr_set_op0(inst, OP_NOP);
                instr_set_op1(bb.b_instr[i + 1], opcode, oparg ^ 1);
                i += 1;
                continue;
            }
        } elif opcode == OP_TO_BOOL {
            if nextop == OP_TO_BOOL {
                instr_set_op0(inst, OP_NOP);
                i += 1;
                continue;
            }
        } elif opcode == OP_UNARY_NOT {
            if nextop == OP_TO_BOOL {
                instr_set_op0(inst, OP_NOP);
                instr_set_op0(bb.b_instr[i + 1], OP_UNARY_NOT);
                i += 1;
                continue;
            }
            if nextop == OP_UNARY_NOT {
                instr_set_op0(inst, OP_NOP);
                instr_set_op0(bb.b_instr[i + 1], OP_NOP);
                i += 1;
                continue;
            }
            fold_const_unaryop(bb, i, cc);
        } elif opcode == OP_UNARY_INVERT or opcode == OP_UNARY_NEGATIVE {
            fold_const_unaryop(bb, i, cc);
        } elif opcode == OP_CALL_INTRINSIC_1 {
            if oparg == INTRINSIC_LIST_TO_TUPLE {
                if nextop == OP_GET_ITER {
                    instr_set_op0(inst, OP_NOP);
                } else {
                    fold_constant_intrinsic_list_to_tuple(bb, i, cc);
                }
            } elif oparg == INTRINSIC_UNARY_POSITIVE {
                fold_const_unaryop(bb, i, cc);
            }
        } elif opcode == OP_BINARY_OP {
            fold_const_binop(bb, i, cc);
        }
        i += 1;
    }
    i = 0;
    while i < len(bb.b_instr) {
        if bb.b_instr[i].i_opcode == OP_SWAP {
            i = swaptimize(bb, i);
            apply_static_swaps(bb, i);
        }
        i += 1;
    }
}

def remove_redundant_nops_and_jumps(g: cfg_builder) {
    while True {
        removed_nops = remove_redundant_nops(g);
        removed_jumps = remove_redundant_jumps(g);
        if removed_nops + removed_jumps <= 0 {
            break;
        }
    }
}

def optimize_cfg(g: cfg_builder, cc: cfg_consts, firstlineno: int) {
    entryb = entry_of(g);
    check_cfg(g);
    inline_small_or_no_lineno_blocks(entryb);
    remove_unreachable(entryb);
    resolve_line_numbers(g, firstlineno);
    optimize_load_const(g, cc);
    b: basicblock | None = entryb;
    while b is not None {
        optimize_basic_block(b, cc);
        b = b.b_next;
    }
    remove_redundant_nops_and_pairs(entryb);
    remove_unreachable(entryb);
    remove_redundant_nops_and_jumps(g);
}

def make_super_instruction(inst1: cfg_instr, inst2: cfg_instr, super_op: int) {
    line1 = inst1.i_loc.lineno;
    line2 = inst2.i_loc.lineno;
    if line1 >= 0 and line2 >= 0 and line1 != line2 {
        return;
    }
    if inst1.i_oparg >= 16 or inst2.i_oparg >= 16 {
        return;
    }
    instr_set_op1(inst1, super_op, (inst1.i_oparg << 4) | inst2.i_oparg);
    instr_set_op0(inst2, OP_NOP);
}

def insert_superinstructions(g: cfg_builder) {
    b: basicblock | None = entry_of(g);
    while b is not None {
        n = len(b.b_instr);
        for i in range(n) {
            inst = b.b_instr[i];
            nextop = b.b_instr[i + 1].i_opcode if i + 1 < n else 0;
            if inst.i_opcode == OP_LOAD_FAST {
                if nextop == OP_LOAD_FAST {
                    make_super_instruction(
                        inst, b.b_instr[i + 1], OP_LOAD_FAST_LOAD_FAST
                    );
                }
            } elif inst.i_opcode == OP_STORE_FAST {
                if nextop == OP_LOAD_FAST {
                    make_super_instruction(
                        inst, b.b_instr[i + 1], OP_STORE_FAST_LOAD_FAST
                    );
                } elif nextop == OP_STORE_FAST {
                    make_super_instruction(
                        inst, b.b_instr[i + 1], OP_STORE_FAST_STORE_FAST
                    );
                }
            }
        }
        b = b.b_next;
    }
    remove_redundant_nops(g);
}

def ref_push(refs: ref_stack, instr: int, local: int) {
    refs.instr.append(instr);
    refs.local.append(local);
}

def ref_pop(refs: ref_stack) -> int {
    refs.local.pop();
    return refs.instr.pop();
}

def kill_local(instr_flags: list[int], refs: ref_stack, local: int) {
    for k in range(len(refs.instr)) {
        if refs.local[k] == local {
            r_instr = refs.instr[k];
            instr_flags[r_instr] = instr_flags[r_instr] | SUPPORT_KILLED;
        }
    }
}

def store_local(instr_flags: list[int], refs: ref_stack, local: int, r_instr: int) {
    kill_local(instr_flags, refs, local);
    if r_instr != REF_DUMMY_INSTR {
        instr_flags[r_instr] = instr_flags[r_instr] | STORED_AS_LOCAL;
    }
}

def load_fast_push_block(sp: list[basicblock], target: basicblock | None) {
    if target is not None and not target.b_visited {
        target.b_visited = 1;
        sp.append(target);
    }
}

def optimize_load_fast(g: cfg_builder) {
    entryblock = entry_of(g);
    max_instrs = 0;
    b: basicblock | None = entryblock;
    while b is not None {
        if len(b.b_instr) > max_instrs {
            max_instrs = len(b.b_instr);
        }
        b = b.b_next;
    }
    instr_flags: list[int] = [];
    for k in range(max_instrs + 2) {
        instr_flags.append(0);
    }
    reset_visited(entryblock);
    sp: list[basicblock] = [entryblock];
    entryblock.b_startdepth = 0;
    entryblock.b_visited = 1;
    refs = ref_stack(instr=[], local=[]);
    while len(sp) > 0 {
        block = sp.pop();
        nused = len(block.b_instr);
        for k in range(nused) {
            instr_flags[k] = 0;
        }
        refs.instr = [];
        refs.local = [];
        for k in range(block.b_startdepth) {
            ref_push(refs, REF_DUMMY_INSTR, REF_NOT_LOCAL);
        }
        for i in range(nused) {
            instr = block.b_instr[i];
            opcode = instr.i_opcode;
            oparg = instr.i_oparg;
            if opcode == OP_DELETE_FAST {
                kill_local(instr_flags, refs, oparg);
            } elif opcode == OP_LOAD_FAST {
                ref_push(refs, i, oparg);
            } elif opcode == OP_LOAD_FAST_AND_CLEAR {
                kill_local(instr_flags, refs, oparg);
                ref_push(refs, i, oparg);
            } elif opcode == OP_LOAD_FAST_LOAD_FAST {
                ref_push(refs, i, oparg >> 4);
                ref_push(refs, i, oparg & 15);
            } elif opcode == OP_STORE_FAST {
                r = ref_pop(refs);
                store_local(instr_flags, refs, oparg, r);
            } elif opcode == OP_STORE_FAST_LOAD_FAST {
                r = ref_pop(refs);
                store_local(instr_flags, refs, oparg >> 4, r);
                ref_push(refs, i, oparg & 15);
            } elif opcode == OP_STORE_FAST_STORE_FAST {
                r = ref_pop(refs);
                store_local(instr_flags, refs, oparg >> 4, r);
                r = ref_pop(refs);
                store_local(instr_flags, refs, oparg & 15, r);
            } elif opcode == OP_COPY {
                idx = len(refs.instr) - oparg;
                ref_push(refs, refs.instr[idx], refs.local[idx]);
            } elif opcode == OP_SWAP {
                top = len(refs.instr) - 1;
                idx = len(refs.instr) - oparg;
                ti = refs.instr[idx];
                tl = refs.local[idx];
                refs.instr[idx] = refs.instr[top];
                refs.local[idx] = refs.local[top];
                refs.instr[top] = ti;
                refs.local[top] = tl;
            } elif opcode == OP_FORMAT_SIMPLE
                or opcode == OP_GET_ANEXT
                or opcode == OP_GET_LEN
                or opcode == OP_GET_YIELD_FROM_ITER
                or opcode == OP_IMPORT_FROM
                or opcode == OP_MATCH_KEYS
                or opcode == OP_MATCH_MAPPING
                or opcode == OP_MATCH_SEQUENCE
                or opcode == OP_WITH_EXCEPT_START {
                net_pushed = _opcode_num_pushed(opcode, oparg)
                    - _opcode_num_popped(opcode, oparg);
                for k in range(net_pushed) {
                    ref_push(refs, k, REF_NOT_LOCAL);
                }
            } elif opcode == OP_DICT_MERGE
                or opcode == OP_DICT_UPDATE
                or opcode == OP_LIST_APPEND
                or opcode == OP_LIST_EXTEND
                or opcode == OP_MAP_ADD
                or opcode == OP_RERAISE
                or opcode == OP_SET_ADD
                or opcode == OP_SET_UPDATE {
                net_popped = _opcode_num_popped(opcode, oparg)
                    - _opcode_num_pushed(opcode, oparg);
                for k in range(net_popped) {
                    ref_pop(refs);
                }
            } elif opcode == OP_END_SEND or opcode == OP_SET_FUNCTION_ATTRIBUTE {
                tos_local = refs.local[len(refs.local) - 1];
                tos = ref_pop(refs);
                ref_pop(refs);
                ref_push(refs, tos, tos_local);
            } elif opcode == OP_CHECK_EXC_MATCH {
                ref_pop(refs);
                ref_push(refs, i, REF_NOT_LOCAL);
            } elif opcode == OP_FOR_ITER {
                load_fast_push_block(sp, instr.i_target);
                ref_push(refs, i, REF_NOT_LOCAL);
            } elif opcode == OP_LOAD_ATTR or opcode == OP_LOAD_SUPER_ATTR {
                self_local = refs.local[len(refs.local) - 1];
                self_instr = ref_pop(refs);
                if opcode == OP_LOAD_SUPER_ATTR {
                    ref_pop(refs);
                    ref_pop(refs);
                }
                ref_push(refs, i, REF_NOT_LOCAL);
                if oparg & 1 {
                    ref_push(refs, self_instr, self_local);
                }
            } elif opcode == OP_LOAD_SPECIAL or opcode == OP_PUSH_EXC_INFO {
                tos_local2 = refs.local[len(refs.local) - 1];
                tos2 = ref_pop(refs);
                ref_push(refs, i, REF_NOT_LOCAL);
                ref_push(refs, tos2, tos_local2);
            } elif opcode == OP_SEND {
                load_fast_push_block(sp, instr.i_target);
                ref_pop(refs);
                ref_push(refs, i, REF_NOT_LOCAL);
            } else {
                num_popped = _opcode_num_popped(opcode, oparg);
                num_pushed = _opcode_num_pushed(opcode, oparg);
                if has_target(opcode) {
                    load_fast_push_block(sp, instr.i_target);
                }
                if not is_block_push_opcode(opcode) {
                    for k in range(num_popped) {
                        ref_pop(refs);
                    }
                    for k in range(num_pushed) {
                        ref_push(refs, i, REF_NOT_LOCAL);
                    }
                }
            }
        }
        term = basicblock_last_instr(block);
        if term is not None
            and block.b_next is not None
            and not (
                is_unconditional_jump_opcode(term.i_opcode)
                or is_scope_exit_opcode(term.i_opcode)
            ) {
            load_fast_push_block(sp, block.b_next);
        }
        for k in range(len(refs.instr)) {
            r_instr = refs.instr[k];
            if r_instr != -1 {
                instr_flags[r_instr] = instr_flags[r_instr] | REF_UNCONSUMED;
            }
        }
        for i in range(nused) {
            if not instr_flags[i] {
                instr = block.b_instr[i];
                if instr.i_opcode == OP_LOAD_FAST {
                    instr.i_opcode = OP_LOAD_FAST_BORROW;
                } elif instr.i_opcode == OP_LOAD_FAST_LOAD_FAST {
                    instr.i_opcode = OP_LOAD_FAST_BORROW_LOAD_FAST_BORROW;
                }
            }
        }
    }
}

def maybe_push(b: basicblock, lo: int, hi: int, sp: list[basicblock]) {
    both_lo = b.b_unsafe_lo | lo;
    both_hi = b.b_unsafe_hi | hi;
    if b.b_unsafe_lo != both_lo or b.b_unsafe_hi != both_hi {
        b.b_unsafe_lo = both_lo;
        b.b_unsafe_hi = both_hi;
        if not b.b_visited {
            sp.append(b);
            b.b_visited = 1;
        }
    }
}

def scan_block_for_locals(b: basicblock, sp: list[basicblock]) {
    lo = b.b_unsafe_lo;
    hi = b.b_unsafe_hi;
    for instr in b.b_instr {
        exc = instr.i_except;
        if exc is not None {
            maybe_push(exc, lo, hi, sp);
        }
        arg = instr.i_oparg;
        if arg >= 64 or arg < 0 {
            continue;
        }
        blo = 0;
        bhi = 0;
        if arg < 32 {
            blo = 1 << arg;
        } else {
            bhi = 1 << (arg - 32);
        }
        op = instr.i_opcode;
        if op == OP_DELETE_FAST
            or op == OP_LOAD_FAST_AND_CLEAR
            or op == OP_STORE_FAST_MAYBE_NULL {
            lo = lo | blo;
            hi = hi | bhi;
        } elif op == OP_STORE_FAST or op == OP_LOAD_FAST_CHECK {
            lo = lo & ~blo;
            hi = hi & ~bhi;
        } elif op == OP_LOAD_FAST {
            if (lo & blo) != 0 or (hi & bhi) != 0 {
                instr.i_opcode = OP_LOAD_FAST_CHECK;
            }
            lo = lo & ~blo;
            hi = hi & ~bhi;
        }
    }
    nxt = b.b_next;
    if nxt is not None and bb_has_fallthrough(b) {
        maybe_push(nxt, lo, hi, sp);
    }
    last = basicblock_last_instr(b);
    if last is not None and is_jump(last) {
        target = last.i_target;
        if target is not None {
            maybe_push(target, lo, hi, sp);
        }
    }
}

def fast_scan_many_locals(entryblock: basicblock, nlocals: int) {
    states: list[int] = [];
    for k in range(nlocals - 64) {
        states.append(0);
    }
    blocknum = 0;
    b: basicblock | None = entryblock;
    while b is not None {
        blocknum += 1;
        for instr in b.b_instr {
            arg = instr.i_oparg;
            if arg < 64 {
                continue;
            }
            op = instr.i_opcode;
            if op == OP_DELETE_FAST
                or op == OP_LOAD_FAST_AND_CLEAR
                or op == OP_STORE_FAST_MAYBE_NULL {
                states[arg - 64] = blocknum - 1;
            } elif op == OP_STORE_FAST {
                states[arg - 64] = blocknum;
            } elif op == OP_LOAD_FAST {
                if states[arg - 64] != blocknum {
                    instr.i_opcode = OP_LOAD_FAST_CHECK;
                }
                states[arg - 64] = blocknum;
            }
        }
        b = b.b_next;
    }
}

def remove_unused_consts(entryblock: basicblock, consts: list[PyObj]) {
    nconsts = len(consts);
    if nconsts == 0 {
        return;
    }
    index_map: list[int] = [];
    for k in range(nconsts) {
        index_map.append(-1);
    }
    index_map[0] = 0;
    b: basicblock | None = entryblock;
    while b is not None {
        for instr in b.b_instr {
            if opcode_has_const(instr.i_opcode) {
                index_map[instr.i_oparg] = instr.i_oparg;
            }
        }
        b = b.b_next;
    }
    n_used_consts = 0;
    for k in range(nconsts) {
        if index_map[k] != -1 {
            index_map[n_used_consts] = index_map[k];
            n_used_consts += 1;
        }
    }
    if n_used_consts == nconsts {
        return;
    }
    for k in range(n_used_consts) {
        old_index = index_map[k];
        if k != old_index {
            consts[k] = consts[old_index];
        }
    }
    while len(consts) > n_used_consts {
        consts.pop();
    }
    reverse_index_map: list[int] = [];
    for k in range(nconsts) {
        reverse_index_map.append(-1);
    }
    for k in range(n_used_consts) {
        reverse_index_map[index_map[k]] = k;
    }
    b = entryblock;
    while b is not None {
        for instr in b.b_instr {
            if opcode_has_const(instr.i_opcode) {
                instr.i_oparg = reverse_index_map[instr.i_oparg];
            }
        }
        b = b.b_next;
    }
}

def add_checks_for_loads_of_uninitialized_variables(
    entryblock: basicblock, nlocals: int, nparams: int
) {
    if nlocals == 0 {
        return;
    }
    count = nlocals;
    if count > 64 {
        fast_scan_many_locals(entryblock, count);
        count = 64;
    }
    reset_visited(entryblock);
    sp: list[basicblock] = [];
    start_lo = 0;
    start_hi = 0;
    for k in range(nparams, count) {
        if k < 32 {
            start_lo = start_lo | (1 << k);
        } else {
            start_hi = start_hi | (1 << (k - 32));
        }
    }
    maybe_push(entryblock, start_lo, start_hi, sp);
    b: basicblock | None = entryblock;
    while b is not None {
        scan_block_for_locals(b, sp);
        b = b.b_next;
    }
    while len(sp) > 0 {
        cur = sp.pop();
        cur.b_visited = 0;
        scan_block_for_locals(cur, sp);
    }
}

def mark_warm(entryblock: basicblock) {
    reset_visited(entryblock);
    sp: list[basicblock] = [entryblock];
    entryblock.b_visited = 1;
    while len(sp) > 0 {
        b = sp.pop();
        b.b_warm = 1;
        nxt = b.b_next;
        if nxt is not None and bb_has_fallthrough(b) and not nxt.b_visited {
            sp.append(nxt);
            nxt.b_visited = 1;
        }
        for instr in b.b_instr {
            target = instr.i_target;
            if is_jump(instr) and target is not None and not target.b_visited {
                sp.append(target);
                target.b_visited = 1;
            }
        }
    }
}

def mark_cold(entryblock: basicblock) {
    mark_warm(entryblock);
    reset_visited(entryblock);
    sp: list[basicblock] = [];
    b: basicblock | None = entryblock;
    while b is not None {
        if b.b_except_handler {
            sp.append(b);
            b.b_visited = 1;
        }
        b = b.b_next;
    }
    while len(sp) > 0 {
        cur = sp.pop();
        cur.b_cold = 1;
        nxt = cur.b_next;
        if nxt is not None and bb_has_fallthrough(cur) {
            if not nxt.b_warm and not nxt.b_visited {
                sp.append(nxt);
                nxt.b_visited = 1;
            }
        }
        for instr in cur.b_instr {
            if is_jump(instr) {
                target = instr.i_target;
                if target is not None and not target.b_warm and not target.b_visited {
                    sp.append(target);
                    target.b_visited = 1;
                }
            }
        }
    }
}

def push_cold_blocks_to_end(g: cfg_builder) {
    entryblock = entry_of(g);
    if entryblock.b_next is None {
        return;
    }
    mark_cold(entryblock);
    next_lbl = get_max_label(entryblock) + 1;
    b: basicblock | None = entryblock;
    while b is not None {
        nxt = b.b_next;
        if b.b_cold and bb_has_fallthrough(b) and nxt is not None and nxt.b_warm {
            explicit_jump = cfg_builder_new_block(g);
            if nxt.b_label == NO_LABEL {
                nxt.b_label = next_lbl;
                next_lbl += 1;
            }
            basicblock_addop(
                explicit_jump, OP_JUMP_NO_INTERRUPT, nxt.b_label, no_location()
            );
            explicit_jump.b_cold = 1;
            explicit_jump.b_next = nxt;
            explicit_jump.b_predecessors = 1;
            b.b_next = explicit_jump;
            explicit_jump.b_instr[len(explicit_jump.b_instr) - 1].i_target = nxt;
        }
        b = b.b_next;
    }
    cold_blocks: basicblock | None = None;
    cold_blocks_tail: basicblock | None = None;
    cur = entryblock;
    while cur.b_next is not None {
        while cur.b_next is not None and not cur.b_next.b_cold {
            cur = cur.b_next;
        }
        streak = cur.b_next;
        if streak is None {
            break;
        }
        b_end = streak;
        while b_end.b_next is not None and b_end.b_next.b_cold {
            b_end = b_end.b_next;
        }
        if cold_blocks is None {
            cold_blocks = streak;
        } elif cold_blocks_tail is not None {
            cold_blocks_tail.b_next = streak;
        }
        cold_blocks_tail = b_end;
        cur.b_next = b_end.b_next;
        b_end.b_next = None;
    }
    cur.b_next = cold_blocks;
    if cold_blocks is not None {
        remove_redundant_nops_and_jumps(g);
    }
}

def convert_pseudo_conditional_jumps(g: cfg_builder) {
    b: basicblock | None = entry_of(g);
    while b is not None {
        i = 0;
        while i < len(b.b_instr) {
            instr = b.b_instr[i];
            if instr.i_opcode == OP_JUMP_IF_FALSE
                or instr.i_opcode == OP_JUMP_IF_TRUE {
                instr.i_opcode = OP_POP_JUMP_IF_FALSE
                    if instr.i_opcode == OP_JUMP_IF_FALSE
                    else OP_POP_JUMP_IF_TRUE;
                lc = instr.i_loc;
                exc = instr.i_except;
                copy = cfg_instr(
                    i_opcode=OP_COPY, i_oparg=1, i_loc=lc, i_target=None, i_except=exc
                );
                basicblock_insert_instruction(b, i, copy);
                i += 1;
                to_bool = cfg_instr(
                    i_opcode=OP_TO_BOOL,
                    i_oparg=0,
                    i_loc=lc,
                    i_target=None,
                    i_except=exc
                );
                basicblock_insert_instruction(b, i, to_bool);
                i += 1;
            }
            i += 1;
        }
        b = b.b_next;
    }
}

def convert_pseudo_ops(g: cfg_builder) {
    b: basicblock | None = entry_of(g);
    while b is not None {
        for instr in b.b_instr {
            if is_block_push(instr) {
                instr_set_op0(instr, OP_NOP);
            } elif instr.i_opcode == OP_LOAD_CLOSURE {
                instr.i_opcode = OP_LOAD_FAST;
            } elif instr.i_opcode == OP_STORE_FAST_MAYBE_NULL {
                instr.i_opcode = OP_STORE_FAST;
            }
        }
        b = b.b_next;
    }
    remove_redundant_nops_and_jumps(g);
}

def is_exit_or_eval_check_without_lineno(b: basicblock) -> bool {
    if basicblock_exits_scope(b) or basicblock_has_eval_break(b) {
        return basicblock_has_no_lineno(b);
    }
    return False;
}

def duplicate_exits_without_lineno(g: cfg_builder) {
    entryblock = entry_of(g);
    next_lbl = get_max_label(entryblock) + 1;
    b: basicblock | None = entryblock;
    while b is not None {
        last = basicblock_last_instr(b);
        if last is not None and is_jump(last) {
            target = next_nonempty_block(last.i_target);
            if target is not None
                and is_exit_or_eval_check_without_lineno(target)
                and target.b_predecessors > 1 {
                new_target = copy_basicblock(g, target);
                new_target.b_instr[0].i_loc = last.i_loc;
                last.i_target = new_target;
                target.b_predecessors -= 1;
                new_target.b_predecessors = 1;
                new_target.b_next = target.b_next;
                new_target.b_label = next_lbl;
                next_lbl += 1;
                target.b_next = new_target;
            }
        }
        b = b.b_next;
    }
    b = entryblock;
    while b is not None {
        nxt = b.b_next;
        if bb_has_fallthrough(b) and nxt is not None and len(b.b_instr) > 0 {
            if is_exit_or_eval_check_without_lineno(nxt) {
                last2 = basicblock_last_instr(b);
                if last2 is not None {
                    nxt.b_instr[0].i_loc = last2.i_loc;
                }
            }
        }
        b = b.b_next;
    }
}

def propagate_block_line_numbers(b: basicblock, last: cfg_instr) {
    prev_location = no_location();
    for instr in b.b_instr {
        if instr.i_loc.lineno == -1 {
            instr.i_loc = prev_location;
        } else {
            prev_location = instr.i_loc;
        }
    }
    nxt = b.b_next;
    if bb_has_fallthrough(b) and nxt is not None and nxt.b_predecessors == 1 {
        if len(nxt.b_instr) > 0 {
            if nxt.b_instr[0].i_loc.lineno == -1 {
                nxt.b_instr[0].i_loc = prev_location;
            }
        }
    }
    if is_jump(last) {
        target = last.i_target;
        if target is not None
            and target.b_predecessors == 1
            and len(target.b_instr) > 0 {
            if target.b_instr[0].i_loc.lineno == -1 {
                target.b_instr[0].i_loc = prev_location;
            }
        }
    }
}

def propagate_line_numbers(entryblock: basicblock) {
    b: basicblock | None = entryblock;
    while b is not None {
        last = basicblock_last_instr(b);
        if last is not None {
            propagate_block_line_numbers(b, last);
        }
        b = b.b_next;
    }
}

def resolve_line_numbers(g: cfg_builder, firstlineno: int) {
    duplicate_exits_without_lineno(g);
    propagate_line_numbers(entry_of(g));
}

def cfg_optimize_code_unit(
    g: cfg_builder, consts: list[PyObj], nlocals: int, nparams: int, firstlineno: int
) {
    entryb = entry_of(g);
    translate_jump_labels_to_targets(entryb);
    mark_except_handlers(entryb);
    label_exception_targets(entryb);
    cc = cfg_consts_new(consts);
    optimize_cfg(g, cc, firstlineno);
    remove_unused_consts(entryb, consts);
    add_checks_for_loads_of_uninitialized_variables(entryb, nlocals, nparams);
    insert_superinstructions(g);
    push_cold_blocks_to_end(g);
    resolve_line_numbers(g, firstlineno);
}

def build_cellfixedoffsets(umd: code_unit_metadata) -> list[int] {
    nlocals = len(umd.varnames);
    noffsets = len(umd.cellvars) + len(umd.freevars);
    fixed: list[int] = [];
    for k in range(noffsets) {
        fixed.append(nlocals + k);
    }
    for name in umd.cellvars {
        if name in umd.varname_index {
            fixed[umd.cellvar_index[name]] = umd.varname_index[name];
        }
    }
    return fixed;
}

def is_generator_flags(code_flags: int) -> bool {
    return (code_flags & (CO_GENERATOR | CO_COROUTINE | CO_ASYNC_GENERATOR)) != 0;
}

def insert_prefix_instructions(
    umd: code_unit_metadata,
    entryblock: basicblock,
    fixed: list[int],
    nfreevars: int,
    code_flags: int
) {
    if is_generator_flags(code_flags) {
        lc = mkloc(umd.firstlineno, umd.firstlineno, -1, -1);
        basicblock_insert_instruction(
            entryblock, 0, new_instr(OP_RETURN_GENERATOR, 0, lc)
        );
        basicblock_insert_instruction(entryblock, 1, new_instr(OP_POP_TOP, 0, lc));
    }
    ncellvars = len(umd.cellvars);
    if ncellvars {
        nvars = ncellvars + len(umd.varnames);
        ordered: list[int] = [];
        for k in range(nvars) {
            ordered.append(0);
        }
        for k in range(ncellvars) {
            ordered[fixed[k]] = k + 1;
        }
        k = 0;
        ncellsused = 0;
        while ncellsused < ncellvars {
            oldindex = ordered[k] - 1;
            k += 1;
            if oldindex == -1 {
                continue;
            }
            basicblock_insert_instruction(
                entryblock, ncellsused, new_instr(OP_MAKE_CELL, oldindex, no_location())
            );
            ncellsused += 1;
        }
    }
    if nfreevars {
        basicblock_insert_instruction(
            entryblock, 0, new_instr(OP_COPY_FREE_VARS, nfreevars, no_location())
        );
    }
}

def fix_cell_offsets(
    umd: code_unit_metadata, entryblock: basicblock, fixedmap: list[int]
) -> int {
    nlocals = len(umd.varnames);
    noffsets = len(umd.cellvars) + len(umd.freevars);
    numdropped = 0;
    for k in range(noffsets) {
        if fixedmap[k] == k + nlocals {
            fixedmap[k] -= numdropped;
        } else {
            numdropped += 1;
        }
    }
    b: basicblock | None = entryblock;
    while b is not None {
        for inst in b.b_instr {
            op = inst.i_opcode;
            if op == OP_MAKE_CELL
                or op == OP_LOAD_CLOSURE
                or op == OP_LOAD_DEREF
                or op == OP_STORE_DEREF
                or op == OP_DELETE_DEREF
                or op == OP_LOAD_FROM_DICT_OR_DEREF {
                inst.i_oparg = fixedmap[inst.i_oparg];
            }
        }
        b = b.b_next;
    }
    return numdropped;
}

def prepare_localsplus(
    umd: code_unit_metadata, g: cfg_builder, code_flags: int
) -> int {
    nlocalsplus = len(umd.varnames) + len(umd.cellvars) + len(umd.freevars);
    cellfixedoffsets = build_cellfixedoffsets(umd);
    insert_prefix_instructions(
        umd, entry_of(g), cellfixedoffsets, len(umd.freevars), code_flags
    );
    numdropped = fix_cell_offsets(umd, entry_of(g), cellfixedoffsets);
    return nlocalsplus - numdropped;
}

def cfg_from_instruction_sequence(seq: instr_seq) -> cfg_builder {
    seq.apply_label_map();
    g = cfg_builder_new();
    n = len(seq.instrs);
    is_target: list[bool] = [];
    for k in range(n) {
        is_target.append(False);
    }
    for instr in seq.instrs {
        if has_target(instr.opcode) {
            is_target[instr.oparg] = True;
        }
    }
    offset = 0;
    for i in range(n) {
        instr = seq.instrs[i];
        if instr.opcode == OP_ANNOTATIONS_PLACEHOLDER {
            ann = seq.annotations_code;
            if ann is not None {
                for ann_instr in ann.instrs {
                    cfg_builder_addop(
                        g, ann_instr.opcode, ann_instr.oparg, ann_instr.loc
                    );
                }
                offset += len(ann.instrs) - 1;
            } else {
                offset -= 1;
            }
            continue;
        }
        if is_target[i] {
            cfg_builder_use_label(g, i + offset);
        }
        oparg = instr.oparg;
        if has_target(instr.opcode) {
            oparg += offset;
        }
        cfg_builder_addop(g, instr.opcode, oparg, instr.loc);
    }
    return g;
}

def cfg_to_instruction_sequence(g: cfg_builder, seq: instr_seq) {
    lbl = 0;
    b: basicblock | None = entry_of(g);
    while b is not None {
        b.b_label = lbl;
        lbl += 1;
        b = b.b_next;
    }
    b = entry_of(g);
    while b is not None {
        seq.use_label(b.b_label);
        for instr in b.b_instr {
            target = instr.i_target;
            if has_target(instr.i_opcode) and target is not None {
                instr.i_oparg = target.b_label;
            }
            seq.addop(instr.i_opcode, instr.i_oparg, instr.i_loc);
            hi = seq.instrs[len(seq.instrs) - 1];
            exc = instr.i_except;
            if exc is not None {
                hi.h_label = exc.b_label;
                hi.h_startdepth = exc.b_startdepth;
                hi.h_preserve_lasti = exc.b_preserve_lasti;
            } else {
                hi.h_label = -1;
            }
        }
        b = b.b_next;
    }
    seq.apply_label_map();
}

def optimized_cfg_to_instruction_sequence(
    g: cfg_builder, umd: code_unit_metadata, code_flags: int, seq: instr_seq
) -> tuple[int, int] {
    convert_pseudo_conditional_jumps(g);
    stackdepth = calculate_stackdepth(g);
    nlocalsplus = prepare_localsplus(umd, g, code_flags);
    convert_pseudo_ops(g);
    normalize_jumps(g);
    optimize_load_fast(g);
    cfg_to_instruction_sequence(g, seq);
    return (stackdepth, nlocalsplus);
}
