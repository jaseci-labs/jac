"""Bytecode optimizer pass — docs/bytecode_optimizer_impl_plan.md.

Phase 1 scope: jump threading + jump retargeting over FILLER runs. Every
rewrite is LENGTH-PRESERVING — instruction positions never move; only the
ip args of the seven ip-carrying opcodes (JUMP, JUMP_IF_TRUE/FALSE/NULL/
UNDEFINED, PUSH_CATCH, PUSH_FINALLY — the full audit of op.jac; any new
ip-carrying opcode MUST be added to _bcopt_is_ip_op) are rewritten, so
there is no jump-target remapping, no end_ip math, and a half-applied
pass is still correct bytecode.

Retargeting through a JUMP or past a FILLER run is semantics-preserving
for ALL seven ops (including the PUSH_CATCH/PUSH_FINALLY handler entry
ips): executing a FILLER does nothing and executing the intermediate
JUMP just lands at the same place one dispatch later.

Invoked from Compiler._pop_fn — the single chokepoint every
CompiledFunction (top-level, inner, eval, Function, jsbc precompile)
passes through exactly once; the `optimized` flag makes reuse paths
(eval cache, jsbc decode) no-ops.
"""

import from engine.src.bytecode.op {
    Opcode,
    Instruction,
    CompiledFunction,
    make_instruction
}

# JS_BCOPT=0 lever. Wired from init_global (runtime/global.jac); the
# js_compiler / jsbc-precompile binary never calls init_global and runs
# with this default (ON) — .jsbc ships optimized code by design.
glob _BCOPT_GATE: int = 1,
     _BCOPT_P3: int = 1;

# Phase-3 sub-lever (JS_BCOPT_P3=0): disables copy-prop, the ST/LL
# peephole, and filler compaction while keeping Phase 1+2 — exists so
# Phase 3's contribution can be measured inside ONE binary (build-to-
# build layout variance is ±5%, the same order as Phase 3's effect).
"""Set the optimizer gate (called once from init_global)."""
def:pub bcopt_gate_set(enabled: bool) {
    _BCOPT_GATE = 1 if enabled else 0;
}

"""Set the Phase-3 sub-gate (called next to bcopt_gate_set)."""
def:pub bcopt_p3_gate_set(enabled: bool) {
    _BCOPT_P3 = 1 if enabled else 0;
}

"""True unless JS_BCOPT=0 (read back by feature_gates_report)."""
def:pub bcopt_gate_enabled -> bool {
    return _BCOPT_GATE == 1;
}

"""True unless JS_BCOPT_P3=0 (read back by feature_gates_report)."""
def:pub bcopt_p3_gate_enabled -> bool {
    return _BCOPT_P3 == 1;
}

def _bcopt_is_ip_op(op: Opcode) -> bool {
    return op == Opcode.JUMP
        or op == Opcode.JUMP_IF_TRUE
        or op == Opcode.JUMP_IF_FALSE
        or op == Opcode.JUMP_IF_NULL
        or op == Opcode.JUMP_IF_UNDEFINED
        or op == Opcode.PUSH_CATCH
        or op == Opcode.PUSH_FINALLY;
}

"""Resolve a jump target: skip FILLER runs, then follow unconditional
JUMP chains, repeating to a fixpoint. Hop-capped so a bytecode-level
infinite loop (`for(;;);` compiles to a JUMP cycle) terminates — bailing
mid-chain is always legal, the intermediate ip is still a real target.
Returns the original target on anything out of range (a FILLER run to
end-of-code cannot happen in valid bytecode, but the pass must not be
the thing that turns weird into wrong)."""
def _bcopt_resolve(code: list[Instruction], t0: int) -> int {
    n: int = len(code);
    cur: int = t0;
    hops: int = 0;
    while hops < 64 {
        while cur >= 0 and cur < n and code[cur].opcode == Opcode.FILLER {
            cur = cur + 1;
        }
        if cur < 0 or cur >= n {
            return t0;
        }
        if code[cur].opcode == Opcode.JUMP {
            nxt: int = code[cur].arg;
            if nxt == cur {
                return cur;
            }
            cur = nxt;
            hops = hops + 1;
        } else {
            return cur;
        }
    }
    return cur;
}

# ══════════════════════════════════════════════════════════════════════════
# Phase 2 — megaop window matchers (QUICKENING: only the window HEAD is
# replaced; interiors stay, so a jump into the window — or a slow-path
# fallthrough — executes the original sequence verbatim). Slot operands
# packed into arg2 must fit 16 bits; windows with larger slot numbers are
# simply left unfused.
# ══════════════════════════════════════════════════════════════════════════

def _bcopt_const_is(fn: CompiledFunction, idx: int, s: str) -> bool {
    if idx < 0 or idx >= len(fn.constants.values) {
        return False;
    }
    return fn.constants.values[idx] == s;
}

"""Postfix `i++`/`i--` statement: LL s; LC "n:0"; SUB; DUP; LC unit; SUB;
ST s; POP  →  LOCAL_INC(arg=s, arg2=±1). Returns window length or 0."""
def _bcopt_try_local_inc(fn: CompiledFunction, i: int) -> int {
    code: list[Instruction] = fn.code;
    if code[i].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    if code[i + 1].opcode != Opcode.LOAD_CONST
        or not _bcopt_const_is(fn, code[i + 1].arg, "n:0") {
        return 0;
    }
    if code[i + 2].opcode != Opcode.SUB {
        return 0;
    }
    if code[i + 3].opcode != Opcode.DUP {
        return 0;
    }
    if code[i + 4].opcode != Opcode.LOAD_CONST {
        return 0;
    }
    li_delta: int = 0;
    if _bcopt_const_is(fn, code[i + 4].arg, "n:-1") {
        li_delta = 1;
    } elif _bcopt_const_is(fn, code[i + 4].arg, "n:1") {
        li_delta = -1;
    } else {
        return 0;
    }
    if code[i + 5].opcode != Opcode.SUB {
        return 0;
    }
    if code[i + 6].opcode != Opcode.STORE_LOCAL or code[i + 6].arg != code[i].arg {
        return 0;
    }
    if code[i + 7].opcode != Opcode.POP {
        return 0;
    }
    fn.code[i] = make_instruction(
        Opcode.LOCAL_INC, code[i].arg, li_delta, code[i].line
    );
    return 8;
}

"""Loop condition: LL(_C) a; LL(_C) b; cmp; JIF/JIT t → BR_CMP_LL."""
def _bcopt_try_br_cmp(fn: CompiledFunction, i: int) -> int {
    code: list[Instruction] = fn.code;
    br_ca: int = 0;
    if code[i].opcode == Opcode.LOAD_LOCAL_CHECKED {
        br_ca = 1;
    } elif code[i].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    br_cb: int = 0;
    if code[i + 1].opcode == Opcode.LOAD_LOCAL_CHECKED {
        br_cb = 1;
    } elif code[i + 1].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    if code[i + 1].arg >= 65536 {
        return 0;
    }
    br_op: int = -1;
    if code[i + 2].opcode == Opcode.LT {
        br_op = 0;
    } elif code[i + 2].opcode == Opcode.LTE {
        br_op = 1;
    } elif code[i + 2].opcode == Opcode.GT {
        br_op = 2;
    } elif code[i + 2].opcode == Opcode.GTE {
        br_op = 3;
    } elif code[i + 2].opcode == Opcode.STRICT_EQ {
        br_op = 4;
    } else {
        return 0;
    }
    br_jit: int = 0;
    if code[i + 3].opcode == Opcode.JUMP_IF_TRUE {
        br_jit = 1;
    } elif code[i + 3].opcode != Opcode.JUMP_IF_FALSE {
        return 0;
    }
    br_arg2: int = code[i + 1].arg
        + (br_op * 65536)
        + (br_ca * 1048576)
        + (br_cb * 2097152)
        + (br_jit * 4194304);
    br_ni: Instruction = make_instruction(
        Opcode.BR_CMP_LL, code[i].arg, br_arg2, code[i].line, code[i + 3].arg
    );
    fn.code[i] = br_ni;
    return 4;
}

"""Indexed store: LL(_C) obj; REQUIRE_COERCIBLE; LL key; TO_PROPERTY_KEY;
LL val; SET_INDEX → SET_LL_INDEX."""
def _bcopt_try_set_ll(fn: CompiledFunction, i: int) -> int {
    code: list[Instruction] = fn.code;
    sl_co: int = 0;
    if code[i].opcode == Opcode.LOAD_LOCAL_CHECKED {
        sl_co = 1;
    } elif code[i].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    if code[i + 1].opcode != Opcode.REQUIRE_COERCIBLE {
        return 0;
    }
    if code[i + 2].opcode != Opcode.LOAD_LOCAL or code[i + 2].arg >= 65536 {
        return 0;
    }
    if code[i + 3].opcode != Opcode.TO_PROPERTY_KEY {
        return 0;
    }
    if code[i + 4].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    if code[i + 5].opcode != Opcode.SET_INDEX {
        return 0;
    }
    sl_ni: Instruction = make_instruction(
        Opcode.SET_LL_INDEX,
        code[i].arg,
        code[i + 2].arg + (sl_co * 1048576),
        code[i].line,
        code[i + 4].arg
    );
    fn.code[i] = sl_ni;
    return 6;
}

"""Property read: LL(_C) s; GET_PROP → GET_LLC_PROP (2→1)."""
def _bcopt_try_get_llc(fn: CompiledFunction, i: int) -> int {
    code: list[Instruction] = fn.code;
    gc_c: int = 0;
    if code[i].opcode == Opcode.LOAD_LOCAL_CHECKED {
        gc_c = 1;
    } elif code[i].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    if code[i + 1].opcode != Opcode.GET_PROP {
        return 0;
    }
    fn.code[i] = make_instruction(
        Opcode.GET_LLC_PROP, code[i].arg, gc_c * 1048576, code[i].line
    );
    return 2;
}

"""Local-obj store: LL val; LL(_C) obj; SWAP; SET_PROP; POP →
SET_LL_PROP (5→1)."""
def _bcopt_try_set_ll_prop(fn: CompiledFunction, i: int) -> int {
    code: list[Instruction] = fn.code;
    if code[i].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    slp_c: int = 0;
    if code[i + 1].opcode == Opcode.LOAD_LOCAL_CHECKED {
        slp_c = 1;
    } elif code[i + 1].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    if code[i + 1].arg >= 65536 {
        return 0;
    }
    if code[i + 2].opcode != Opcode.SWAP {
        return 0;
    }
    if code[i + 3].opcode != Opcode.SET_PROP {
        return 0;
    }
    if code[i + 4].opcode != Opcode.POP {
        return 0;
    }
    fn.code[i] = make_instruction(
        Opcode.SET_LL_PROP,
        code[i].arg,
        code[i + 1].arg + (slp_c * 1048576),
        code[i].line
    );
    return 5;
}

"""Ctor store: LOAD_THIS; SWAP; SET_PROP; POP → SET_THIS_PROP (4→1)."""
def _bcopt_try_set_this(fn: CompiledFunction, i: int) -> int {
    code: list[Instruction] = fn.code;
    if code[i].opcode != Opcode.LOAD_THIS {
        return 0;
    }
    if code[i + 1].opcode != Opcode.SWAP {
        return 0;
    }
    if code[i + 2].opcode != Opcode.SET_PROP {
        return 0;
    }
    if code[i + 3].opcode != Opcode.POP {
        return 0;
    }
    fn.code[i] = make_instruction(Opcode.SET_THIS_PROP, 0, 0, code[i].line);
    return 4;
}

glob _BCOPT_NO_INT: int = 4294967296;

"""Small int value of the numeric constant `n:<digits>` at pool index `idx`
(optionally negative, decimal digits only, |c| < 2^20), else _BCOPT_NO_INT.
A leading 0 is rejected (sloppy-mode `012` is octal)."""
def _bcopt_small_int_const(fn: CompiledFunction, idx: int) -> int {
    if idx < 0 or idx >= len(fn.constants.values) {
        return _BCOPT_NO_INT;
    }
    sc_s: str = fn.constants.values[idx];
    if len(sc_s) < 3 or len(sc_s) > 10 or sc_s[0] != "n" or sc_s[1] != ":" {
        return _BCOPT_NO_INT;
    }
    sc_i: int = 2;
    sc_neg: bool = False;
    if sc_s[2] == "-" {
        sc_neg = True;
        sc_i = 3;
    }
    if sc_i >= len(sc_s) {
        return _BCOPT_NO_INT;
    }
    if sc_s[sc_i] == "0" and sc_i + 1 < len(sc_s) {
        return _BCOPT_NO_INT;
    }
    sc_v: int = 0;
    while sc_i < len(sc_s) {
        sc_c: int = ord(sc_s[sc_i]);
        if sc_c < 48 or sc_c > 57 {
            return _BCOPT_NO_INT;
        }
        sc_v = sc_v * 10 + (sc_c - 48);
        sc_i = sc_i + 1;
    }
    if sc_v >= 1048576 {
        return _BCOPT_NO_INT;
    }
    if sc_neg {
        return 0 - sc_v;
    }
    return sc_v;
}

"""Compound member add statement `this.k += c;` / `o.k += c;` (c an int32
constant): head + GET_PROP k matched by the caller, then LC c; ADD;
<same receiver load>; SWAP; SET_PROP k; POP → PROP_INC with flag 8 (8 → 1)."""
def _bcopt_try_prop_add(fn: CompiledFunction, i: int, slot: int, flags: int) -> int {
    code: list[Instruction] = fn.code;
    if i + 8 > len(code) {
        return 0;
    }
    if code[i + 2].opcode != Opcode.LOAD_CONST or code[i + 3].opcode != Opcode.ADD {
        return 0;
    }
    pa_c: int = _bcopt_small_int_const(fn, code[i + 2].arg);
    if pa_c == _BCOPT_NO_INT {
        return 0;
    }
    pa_r: Opcode = code[i + 4].opcode;
    if (flags & 2) == 0 {
        if pa_r != Opcode.LOAD_THIS {
            return 0;
        }
    } elif not (pa_r == Opcode.LOAD_LOCAL or pa_r == Opcode.LOAD_LOCAL_CHECKED)
        or code[i + 4].arg != slot {
        return 0;
    }
    if code[i + 5].opcode != Opcode.SWAP {
        return 0;
    }
    if code[i + 6].opcode != Opcode.SET_PROP or code[i + 6].arg3 != 0 {
        return 0;
    }
    pa_ka: int = code[i + 1].arg;
    pa_kb: int = code[i + 6].arg;
    if pa_ka < 0
        or pa_kb < 0
        or pa_ka >= len(fn.constants.values)
        or pa_kb >= len(fn.constants.values) {
        return 0;
    }
    if fn.constants.values[pa_ka] != fn.constants.values[pa_kb] {
        return 0;
    }
    if code[i + 7].opcode != Opcode.POP {
        return 0;
    }
    fn.code[i] = make_instruction(Opcode.PROP_INC, slot, pa_c, code[i].line, flags + 8);
    return 8;
}

"""Postfix member update `this.k++` / `o.k++` (o a local), value used or not:
  LOAD_THIS | LL(_C) s; GET_PROP k; LC "n:0"; SUB; DUP; LC "n:∓1"; SUB;
  LOAD_THIS | LL(_C) s; SWAP; SET_PROP k; POP [; POP]
→ PROP_INC (11 or 12 → 1). Both receiver loads must name the same receiver
and both property ops the same key; the SET_PROP must be a plain [[Set]]
(arg3 == 0, not a define-own)."""
def _bcopt_try_prop_inc(fn: CompiledFunction, i: int) -> int {
    code: list[Instruction] = fn.code;
    pi_flags: int = 0;
    pi_slot: int = 0;
    h_op: Opcode = code[i].opcode;
    if h_op == Opcode.LOAD_LOCAL or h_op == Opcode.LOAD_LOCAL_CHECKED {
        pi_slot = code[i].arg;
        pi_flags = 2;
        if h_op == Opcode.LOAD_LOCAL_CHECKED {
            pi_flags = 6;
        }
    } elif h_op != Opcode.LOAD_THIS {
        return 0;
    }
    if code[i + 1].opcode != Opcode.GET_PROP {
        return 0;
    }
    # The 8-op `x.k += c;` form first, then the 11/12-op postfix form.
    pi_add: int = _bcopt_try_prop_add(fn, i, pi_slot, pi_flags);
    if pi_add > 0 {
        return pi_add;
    }
    if i + 11 > len(code) {
        return 0;
    }
    r_op: Opcode = code[i + 7].opcode;
    if pi_flags == 0 {
        if r_op != Opcode.LOAD_THIS {
            return 0;
        }
    } elif not (r_op == Opcode.LOAD_LOCAL or r_op == Opcode.LOAD_LOCAL_CHECKED)
        or code[i + 7].arg != pi_slot {
        return 0;
    }
    if code[i + 2].opcode != Opcode.LOAD_CONST
        or not _bcopt_const_is(fn, code[i + 2].arg, "n:0") {
        return 0;
    }
    if code[i + 3].opcode != Opcode.SUB {
        return 0;
    }
    if code[i + 4].opcode != Opcode.DUP {
        return 0;
    }
    if code[i + 5].opcode != Opcode.LOAD_CONST {
        return 0;
    }
    pi_delta: int = 0;
    if _bcopt_const_is(fn, code[i + 5].arg, "n:-1") {
        pi_delta = 1;
    } elif _bcopt_const_is(fn, code[i + 5].arg, "n:1") {
        pi_delta = -1;
    } else {
        return 0;
    }
    if code[i + 6].opcode != Opcode.SUB {
        return 0;
    }
    if code[i + 8].opcode != Opcode.SWAP {
        return 0;
    }
    if code[i + 9].opcode != Opcode.SET_PROP or code[i + 9].arg3 != 0 {
        return 0;
    }
    # Same key: the two ops may use different constant-pool entries.
    pi_ka: int = code[i + 1].arg;
    pi_kb: int = code[i + 9].arg;
    if pi_ka < 0
        or pi_kb < 0
        or pi_ka >= len(fn.constants.values)
        or pi_kb >= len(fn.constants.values) {
        return 0;
    }
    if fn.constants.values[pi_ka] != fn.constants.values[pi_kb] {
        return 0;
    }
    if code[i + 10].opcode != Opcode.POP {
        return 0;
    }
    pi_len: int = 11;
    if i + 11 < len(code) and code[i + 11].opcode == Opcode.POP {
        pi_flags = pi_flags + 1;
        pi_len = 12;
    }
    fn.code[i] = make_instruction(
        Opcode.PROP_INC, pi_slot, pi_delta, code[i].line, pi_flags
    );
    return pi_len;
}

"""Indexed read: LL(_C) obj; LL key; GET_INDEX → GET_LL_INDEX."""
def _bcopt_try_get_ll(fn: CompiledFunction, i: int) -> int {
    code: list[Instruction] = fn.code;
    gl_co: int = 0;
    if code[i].opcode == Opcode.LOAD_LOCAL_CHECKED {
        gl_co = 1;
    } elif code[i].opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    if code[i + 1].opcode != Opcode.LOAD_LOCAL or code[i + 1].arg >= 65536 {
        return 0;
    }
    if code[i + 2].opcode != Opcode.GET_INDEX {
        return 0;
    }
    fn.code[i] = make_instruction(
        Opcode.GET_LL_INDEX,
        code[i].arg,
        code[i + 1].arg + (gl_co * 1048576),
        code[i].line
    );
    return 3;
}

# ══════════════════════════════════════════════════════════════════════════
# Phase 3 — copy propagation into SET_LL_INDEX + STORE/LOAD peephole.
# Both rewrites REMOVE work (filler out copies / change two positions), so
# unlike the quickening pass they need explicit safety analysis:
#   targets  — every ip a jump/handler can enter (incl. BR_CMP_LL.arg3,
#              ip 0, and the generator prologue boundary)
#   interior — positions inside a megaop window (slow-path fallback code:
#              must stay VERBATIM, never rewritten)
# ══════════════════════════════════════════════════════════════════════════

def _bcopt_targets(fn: CompiledFunction) -> dict[int, int] {
    tg: dict[int, int] = {};
    tg[0] = 1;
    if fn.gen_prologue_end_ip >= 0 {
        tg[fn.gen_prologue_end_ip] = 1;
    }
    ti: int = 0;
    tn: int = len(fn.code);
    while ti < tn {
        t_ins: Instruction = fn.code[ti];
        if _bcopt_is_ip_op(t_ins.opcode) {
            tg[t_ins.arg] = 1;
        } elif t_ins.opcode == Opcode.BR_CMP_LL {
            tg[t_ins.arg3] = 1;
        }
        ti = ti + 1;
    }
    return tg;
}

"""Mark megaop window interiors (head+1 .. head+len-1) — a 0/1 list."""
def _bcopt_interiors(fn: CompiledFunction) -> list[int] {
    mk: list[int] = [];
    mi: int = 0;
    mn: int = len(fn.code);
    while mi < mn {
        mk.append(0);
        mi = mi + 1;
    }
    mi = 0;
    while mi < mn {
        m_op: Opcode = fn.code[mi].opcode;
        m_len: int = 0;
        if m_op == Opcode.LOCAL_INC {
            m_len = 8;
        } elif m_op == Opcode.SET_LL_INDEX {
            m_len = 6;
        } elif m_op == Opcode.SET_LL_PROP {
            m_len = 5;
        } elif m_op == Opcode.BR_CMP_LL {
            m_len = 4;
        } elif m_op == Opcode.SET_THIS_PROP {
            m_len = 4;
        } elif m_op == Opcode.GET_LL_INDEX {
            m_len = 3;
        } elif m_op == Opcode.GET_LLC_PROP {
            m_len = 2;
        } elif m_op == Opcode.PROP_INC {
            if (fn.code[mi].arg3 & 8) != 0 {
                m_len = 8;
            } else {
                m_len = 11 + (fn.code[mi].arg3 & 1);
            }
        }
        if m_len > 0 {
            m_j: int = mi + 1;
            while m_j < mi + m_len and m_j < mn {
                mk[m_j] = 1;
                m_j = m_j + 1;
            }
            mi = mi + m_len;
        } else {
            mi = mi + 1;
        }
    }
    return mk;
}

"""True iff `op` may run user code or write locals we can't account for.
The whitelist for the span between a spill-copy and its megaop use:
pure loads, local stores (checked per-slot by the caller), and int-ish
arithmetic. Arithmetic CAN invoke valueOf — but user code cannot write a
plain (non-param, non-captured, non-eval-visible) local slot, which the
caller's fn-level gates guarantee."""
def _bcopt_span_op_ok(op: Opcode) -> bool {
    return op == Opcode.LOAD_LOCAL
        or op == Opcode.LOAD_LOCAL_CHECKED
        or op == Opcode.LOAD_CONST
        or op == Opcode.STORE_LOCAL
        or op == Opcode.ADD
        or op == Opcode.SUB
        or op == Opcode.MUL;
}

"""Count uses of local slot `t` OUTSIDE [lo, hi] (inclusive window +
copy span). Any touch — read, write, cell, megaop operand — counts; the
caller requires ZERO so fillering t's only write is provably safe."""
def _bcopt_slot_uses_outside(fn: CompiledFunction, t: int, lo: int, hi: int) -> int {
    us: int = 0;
    ui: int = 0;
    un: int = len(fn.code);
    while ui < un {
        if ui < lo or ui > hi {
            u_ins: Instruction = fn.code[ui];
            u_op: Opcode = u_ins.opcode;
            if u_op == Opcode.LOAD_LOCAL
                or u_op == Opcode.LOAD_LOCAL_CHECKED
                or u_op == Opcode.STORE_LOCAL
                or u_op == Opcode.LOCAL_INC
                or u_op == Opcode.MAKE_CELL
                or u_op == Opcode.STORE_NEW_CELL
                or u_op == Opcode.GET_LLC_PROP {
                if u_ins.arg == t {
                    us = us + 1;
                }
            } elif u_op == Opcode.PROP_INC {
                if (u_ins.arg3 & 2) != 0 and u_ins.arg == t {
                    us = us + 1;
                }
            } elif u_op == Opcode.BR_CMP_LL
                or u_op == Opcode.GET_LL_INDEX
                or u_op == Opcode.SET_LL_PROP {
                if u_ins.arg == t or (u_ins.arg2 & 65535) == t {
                    us = us + 1;
                }
            } elif u_op == Opcode.SET_LL_INDEX {
                if u_ins.arg == t or (u_ins.arg2 & 65535) == t or u_ins.arg3 == t {
                    us = us + 1;
                }
            }
        }
        ui = ui + 1;
    }
    return us;
}

"""Try to propagate ONE source of the SET_LL_INDEX at `k` (kind: 0=obj,
1=key, 2=val), replacing temp slot `t` with the copy's source slot and
fillering the 2-instruction copy. Returns 1 on success."""
def _bcopt_prop_one(
    fn: CompiledFunction, k: int, kind: int, t: int, tg: dict[int, int]
) -> int {
    code: list[Instruction] = fn.code;
    # Find `STORE_LOCAL t` scanning back from k-1 (bounded — the emission
    # puts spills within a few instructions of the store site).
    j: int = k - 1;
    lim: int = k - 12;
    if lim < 1 {
        lim = 1;
    }
    while j >= lim
        and not (code[j].opcode == Opcode.STORE_LOCAL and code[j].arg == t) {
        j = j - 1;
    }
    if j < lim {
        return 0;
    }
    cp_ld: Instruction = code[j - 1];
    cp_checked: int = 0;
    if cp_ld.opcode == Opcode.LOAD_LOCAL_CHECKED {
        cp_checked = 1;
    } elif cp_ld.opcode != Opcode.LOAD_LOCAL {
        return 0;
    }
    # Key/val slots pack into 16 bits / plain args; only the obj source may
    # carry the TDZ-checked flag.
    if kind != 0 and cp_checked == 1 {
        return 0;
    }
    x: int = cp_ld.arg;
    if x == t {
        return 0;
    }
    if kind == 1 and x >= 65536 {
        return 0;
    }
    # No jump may enter anywhere from the copy through the window end —
    # after fillering, an entry there would find t unwritten.
    sp: int = j - 1;
    while sp <= k + 5 {
        if sp in tg {
            return 0;
        }
        sp = sp + 1;
    }
    # Span whitelist + X must not be re-stored between copy and use.
    sp = j + 1;
    while sp < k {
        sp_ins: Instruction = code[sp];
        if not _bcopt_span_op_ok(sp_ins.opcode) {
            return 0;
        }
        if sp_ins.opcode == Opcode.STORE_LOCAL and sp_ins.arg == x {
            return 0;
        }
        sp = sp + 1;
    }
    # t must be dead outside copy+window (its only write is the copy; its
    # only reads are the megaop head + the never-executed window interior).
    if _bcopt_slot_uses_outside(fn, t, j - 1, k + 5) != 0 {
        return 0;
    }
    # Rewrite the megaop head + filler the copy pair.
    h: Instruction = code[k];
    h_arg: int = h.arg;
    h_arg2: int = h.arg2;
    h_arg3: int = h.arg3;
    if kind == 0 {
        h_arg = x;
        h_arg2 = (h_arg2 & 65535) + (cp_checked * 1048576);
    } elif kind == 1 {
        h_arg2 = (h_arg2 - (h_arg2 & 65535)) + x;
    } else {
        h_arg3 = x;
    }
    hn: Instruction = make_instruction(
        Opcode.SET_LL_INDEX, h_arg, h_arg2, h.line, h_arg3
    );
    code[k] = hn;
    code[j - 1] = make_instruction(Opcode.FILLER, 0, 0, cp_ld.line);
    code[j] = make_instruction(Opcode.FILLER, 0, 0, cp_ld.line);
    return 1;
}

"""Run the optimizer over one function's finished code. Phase 1: ip-arg
retargeting (threading + filler skip). Phase 2: megaop head-quickening —
longest window first; on a match, scanning resumes AFTER the window so
fused regions never overlap. Phase 3: copy propagation into SET_LL_INDEX
operands + the ST x;LL x → DUP;ST x peephole (composes with the runtime
DUP→STORE dispatch fusion)."""
def:pub optimize_fn(fn: CompiledFunction) -> None {
    if _BCOPT_GATE == 0 {
        return;
    }
    if fn.optimized == 1 {
        return;
    }
    fn.optimized = 1;
    code: list[Instruction] = fn.code;
    n: int = len(code);
    i: int = 0;
    while i < n {
        ins: Instruction = code[i];
        if _bcopt_is_ip_op(ins.opcode) {
            nt: int = _bcopt_resolve(code, ins.arg);
            if nt != ins.arg {
                # Replace the entire instruction — same rule as the MAKE_CELL
                # prefix fixup in compiler._pop_fn ("avoid list-subscript
                # field-mutation bugs"). These 7 ops carry no arg3/ic state.
                code[i] = make_instruction(ins.opcode, nt, ins.arg2, ins.line);
            }
        }
        i = i + 1;
    }
    # Megaop pass runs AFTER retargeting so branch args read from window
    # tails (BR_CMP_LL copies the JIF's arg) are already final.
    i = 0;
    while i < n {
        mw: int = 0;
        if i + 8 <= n {
            mw = _bcopt_try_prop_inc(fn, i);
        }
        if mw == 0 and i + 8 <= n {
            mw = _bcopt_try_local_inc(fn, i);
        }
        if mw == 0 and i + 6 <= n {
            mw = _bcopt_try_set_ll(fn, i);
        }
        if mw == 0 and i + 5 <= n {
            mw = _bcopt_try_set_ll_prop(fn, i);
        }
        if mw == 0 and i + 4 <= n {
            mw = _bcopt_try_br_cmp(fn, i);
        }
        if mw == 0 and i + 4 <= n {
            mw = _bcopt_try_set_this(fn, i);
        }
        if mw == 0 and i + 3 <= n {
            mw = _bcopt_try_get_ll(fn, i);
        }
        if mw == 0 and i + 2 <= n {
            mw = _bcopt_try_get_llc(fn, i);
        }
        if mw > 0 {
            i = i + mw;
        } else {
            i = i + 1;
        }
    }
    # ── Phase 3 ──────────────────────────────────────────────────────────
    if _BCOPT_P3 == 0 {
        return;
    }
    tg: dict[int, int] = _bcopt_targets(fn);
    mk: list[int] = _bcopt_interiors(fn);
    # Copy propagation: only when no arguments object exists (mapped
    # `arguments` lets callees write PARAMETER slots remotely) and the
    # source never mentions eval (direct eval could read a fillered temp's
    # synthetic name via the dynamic-scope machinery).
    if fn.arguments_slot == -1 and "eval" not in fn.source {
        i = 0;
        while i < n {
            if fn.code[i].opcode == Opcode.SET_LL_INDEX {
                cp_h: Instruction = fn.code[i];
                _bcopt_prop_one(fn, i, 0, cp_h.arg, tg);
                cp_h = fn.code[i];
                _bcopt_prop_one(fn, i, 1, cp_h.arg2 & 65535, tg);
                cp_h = fn.code[i];
                _bcopt_prop_one(fn, i, 2, cp_h.arg3, tg);
                i = i + 6;
            } else {
                i = i + 1;
            }
        }
    }
    # Peephole: ST x; LL x → DUP; ST x (same net effect: x=v, v on stack;
    # composes with the runtime DUP→STORE fusion into ONE dispatch). Both
    # positions change semantics for a jump landing exactly there, so both
    # must be non-targets; megaop interiors must stay verbatim.
    i = 0;
    while i + 1 < n {
        if fn.code[i].opcode == Opcode.STORE_LOCAL
            and fn.code[i + 1].opcode == Opcode.LOAD_LOCAL
            and fn.code[i + 1].arg == fn.code[i].arg
            and mk[i] == 0
            and mk[i + 1] == 0
            and i not in tg
            and (i + 1) not in tg {
            ph_x: int = fn.code[i].arg;
            ph_ln: int = fn.code[i].line;
            fn.code[i] = make_instruction(Opcode.DUP, 0, 0, ph_ln);
            fn.code[i + 1] = make_instruction(Opcode.STORE_LOCAL, ph_x, 0, ph_ln);
            i = i + 2;
        } else {
            i = i + 1;
        }
    }
    # Compact FILLER runs (len ≥ 2) into one JUMP over the run — a filler
    # costs a dispatch when flowed into; one JUMP costs one. Skip if any
    # jump target lands strictly INSIDE the run (the run head being a
    # target is fine: the JUMP executes and lands past, same as falling
    # through the pads). Runs ending at code-end are left alone.
    i = 0;
    while i < n {
        if fn.code[i].opcode == Opcode.FILLER {
            fr_e: int = i + 1;
            fr_ok: bool = True;
            while fr_e < n and fn.code[fr_e].opcode == Opcode.FILLER {
                if fr_e in tg {
                    fr_ok = False;
                }
                fr_e = fr_e + 1;
            }
            if fr_ok and fr_e - i >= 2 and fr_e < n {
                fn.code[i] = make_instruction(Opcode.JUMP, fr_e, 0, fn.code[i].line);
            }
            i = fr_e;
        } else {
            i = i + 1;
        }
    }
}
