"""Register ISA — docs/VM_REARCH_PLAN.md V2.

The three-address form of a compiled function and the translator that
produces it from the finished stack bytecode (`CompiledFunction.code`,
after optimize_fn — megaop heads included).

Why a translator and not a second compiler backend: the stack code's
operand stack has a statically known depth at every instruction, so stack
slot `d` of a frame is register `num_locals + d`, and a symbolic operand
stack (locals and constants are deferred until the instruction that
consumes them, results are retargeted into the local they are stored to)
turns `LL s; LL o; GET_PROP x; ADD; ST s` into `GETFIELD t,o,"x"; ADD s,s,t`
directly — the code Lua's single-pass compiler would emit. A function whose
analysis fails (an unknown stack shape, a generator, a tail call) keeps its
stack code and runs in VM._exec exactly as before: `risa == 2`. That is the
per-function hybrid rollout.

Word layout (64-bit int, always non-negative):
    bits  0–7   opcode (R_*)
    bits  8–23  A   register / slot
    bits 24–39  B   register / slot / small operand
    bits 40–62  C   register, original-instruction index, branch target
                    (a register pc after fixup), or an immediate (+REG_IBIAS)
A register operand in A/B/C may carry REG_TDZ_FLAG (bit 15): the value must
be TDZ-checked before use (the stack code's LOAD_LOCAL_CHECKED). Fast paths
mask it off and reject the sentinel implicitly (it is an object cell, never a
number); slow paths test the flag and throw the ReferenceError.

Registers: [0, reg_tmp_base) are the function's own locals (parameters,
let/const/var, closure cells); [reg_tmp_base, num_locals) are the
translator's temporaries — operand-stack position k lives in register
reg_tmp_base + k — plus one scratch register at the end. num_locals is
bumped so every existing frame/locals allocation site sizes the list.

Every register instruction keeps the index of the stack instruction it came
from in `rorig[pc]`: the VM reads the original Instruction for its constant
/ key / IC state, sets `frame.ip = orig + 1` before anything that can throw
or re-enter (handlers self-patch `code[frame.ip - 1]` and stack traces read
its line), and runs any opcode without a native register handler through
that handler with its operands copied to and from the operand stack (R_STK).
"""

import from engine.src.bytecode.op {
    Opcode,
    Instruction,
    CompiledFunction,
    opcode_to_int,
    opcode_from_int,
    _opname
}
import from engine.src.bytecode.optimizer { _bcopt_small_int_const, _BCOPT_NO_INT }

# ── Gate / diagnostics (JS_REG_ISA=0, JS_REG_DEBUG=1; wired by init_global) ──
glob _REG_GATE: int = 1,
     _REG_DEBUG: int = 0;

def:pub reg_isa_gate_set(on: bool) {
    _REG_GATE = 1 if on else 0;
}

"""True unless JS_REG_ISA=0 (read back by feature_gates_report)."""
def:pub reg_isa_gate_enabled -> bool {
    return _REG_GATE == 1;
}

def:pub reg_isa_debug_set(on: bool) {
    _REG_DEBUG = 1 if on else 0;
}

def:pub reg_isa_debug_on -> bool {
    return _REG_DEBUG == 1;
}

# ── Encoding ──────────────────────────────────────────────────────────────
glob REG_TDZ_FLAG: int = 32768,
     REG_MASK: int = 32767,
     REG_C_MAX: int = 8388607,
     REG_IBIAS: int = 4194304;

# immediates: C = immv + REG_IBIAS, |immv| < 2^22
def:pub reg_word(op: int, a: int, b: int, c: int) -> int {
    return op + (a << 8) + (b << 24) + (c << 40);
}

def:pub reg_op(w: int) -> int {
    return w & 255;
}
def:pub reg_a(w: int) -> int {
    return (w >> 8) & 65535;
}
def:pub reg_b(w: int) -> int {
    return (w >> 24) & 65535;
}
def:pub reg_c(w: int) -> int {
    return (w >> 40) & 8388607;
}

"""Replace the A field of word `w`."""
def reg_set_a(w: int, a: int) -> int {
    return (w - (((w >> 8) & 65535) << 8)) + (a << 8);
}

"""Replace the C field of word `w`."""
def reg_set_c(w: int, c: int) -> int {
    return (w & 1099511627775) + (c << 40);
}

# ── Register opcodes ──────────────────────────────────────────────────────
glob R_NOP: int = 0,
     R_MOVE: int = 1,
     R_LOADK: int = 2,
     R_LOADI: int = 3,
     R_LOADIMM: int = 4,
     R_LOADTHIS: int = 5,
     R_LOADSELF: int = 6,
     R_CHECKTDZ: int = 7,
     R_LOADGLOBAL: int = 8,
     R_LOADFREE: int = 9,
     R_STOREFREE: int = 10,
     R_LOADDEREF: int = 11,
     R_STOREDEREF: int = 12,
     R_MAKECELL: int = 13,
     R_STORENEWCELL: int = 14,
     R_NEWOBJECT: int = 15,
     R_REQCOERCE: int = 16,
     R_TOPROPKEY: int = 17,
     R_INC: int = 18,
     R_ADD: int = 20,
     R_SUB: int = 21,
     R_MUL: int = 22,
     R_DIV: int = 23,
     R_MOD: int = 24,
     R_POW: int = 25,
     R_BAND: int = 26,
     R_BOR: int = 27,
     R_BXOR: int = 28,
     R_SHL: int = 29,
     R_SHR: int = 30,
     R_USHR: int = 31,
     R_ADDI: int = 32,
     R_SUBI: int = 33,
     R_NEG: int = 40,
     R_NOT: int = 41,
     R_BNOT: int = 42,
     R_TYPEOF: int = 43,
     R_VOID: int = 44,
     R_TONUM: int = 45,
     R_TOSTR: int = 46,
     R_LT: int = 50,
     R_LTE: int = 51,
     R_GT: int = 52,
     R_GTE: int = 53,
     R_EQ: int = 54,
     R_NEQ: int = 55,
     R_SEQ: int = 56,
     R_SNEQ: int = 57,
     R_INSTANCEOF: int = 58,
     R_IN: int = 59,
     R_BLT: int = 60,
     R_BNLT: int = 61,
     R_BLE: int = 62,
     R_BNLE: int = 63,
     R_BGT: int = 64,
     R_BNGT: int = 65,
     R_BGE: int = 66,
     R_BNGE: int = 67,
     R_BEQ: int = 68,
     R_BNE: int = 69,
     R_BSEQ: int = 70,
     R_BSNE: int = 71,
     R_BTRUE: int = 72,
     R_BFALSE: int = 73,
     R_BNULL: int = 74,
     R_BUNDEF: int = 75,
     R_JMP: int = 76,
     R_GETFIELD: int = 80,
     R_SETFIELD: int = 81,
     R_GETINDEX: int = 82,
     R_NEWARRAY: int = 85,
     R_GETITER: int = 86,
     R_ITERNEXTVAL: int = 88,
     R_SETINDEX: int = 83,
     R_CALL: int = 90,
     R_CALLM: int = 91,
     R_RETURN: int = 92,
     R_RETUNDEF: int = 93,
     R_TAILCALL: int = 94,
     R_NEW: int = 87,
     R_YIELD: int = 95,
     R_AWAIT: int = 96,
     R_YIELDSTAR: int = 97,
     R_PUSHCATCH: int = 100,
     R_POPCATCH: int = 101,
     R_PUSHFINALLY: int = 102,
     R_POPFINALLY: int = 103,
     R_LANDING: int = 104,
     R_THROW: int = 105,
     R_FINENTER: int = 106,
     R_FINRETHROW: int = 107,
     R_ITERNEXT: int = 110,
     R_STK: int = 120,
     RI_UNDEFINED: int = 0,
     RI_NULL: int = 1,
     RI_TRUE: int = 2,
     RI_FALSE: int = 3,
     RI_HOLE: int = 4,
     RI_TDZ: int = 5,
     K_NORMAL: int = 0,
     K_JUMP: int = 1,
     K_COND: int = 2,
     K_TERM: int = 3,
     K_HANDLER: int = 4,
     K_BAIL: int = 5,
     K_ITERNEXT: int = 6;

# A=dst B=src(f)
# A=dst C=orig (LOAD_CONST; value cached in the Instruction)
# A=dst C=immv+bias
# A=dst B=kind (0 undefined 1 null 2 true 3 false 4 hole 5 tdz)
# A=dst C=orig
# A=dst
# A=slot
# A=dst C=orig
# A=dst B=idx C=orig
# A=src(f) B=idx C=orig
# A=dst B=slot C=orig
# A=src(f) B=slot
# A=slot
# A=src(f) B=slot
# A=dst
# A=reg(f) C=orig  (RequireObjectCoercible, value stays)
# A=dst B=src(f) C=orig
# A=slot B=delta+1 C=skip target; slow path falls through

# A=dst B=src(f) C=immv+bias

# unary: A=dst B=src(f)

# value compares: A=dst B=a(f) C=b(f)

# branches: A=a(f) B=b(f) C=target

# A=r(f) C=target

# C=target

# A=dst B=obj(f) C=orig
# A=obj(f) B=val(f) C=orig
# A=dst B=obj(f) C=idx(f)
# A=base(dst) B=n C=orig — array of regs[base .. base+n)
# A=dst B=src(f) C=orig — for-of iterator of src
# A=dst(=B+1) B=iter C=orig — destructuring step, iter kept
# A=obj(f) B=idx(f) C=val(f)

# A=dst B=callee(f) C=argc, then argc arg words
# A=dst B=fn(f) C=argc, then this word, then argc arg words
# A=r(f)

# as R_CALL; an in-loop frame is replaced by the callee
# as R_CALL: [[Construct]] of B with the args
# A=dst B=src(f) C=orig — suspend; dst gets the sent value
# A=dst B=src(f) C=orig — suspend (or settle); dst gets the value
# A=dst B=src(f) C=orig — delegate; dst gets the delegate's return

# C=target

# C=target

# A=dst (the exception the unwinder pushed)
# A=r(f)
# A=slot B=src
# A=slot

# A=dst B=iter C=target (done)

# A=base B=npop|(npush<<12) C=orig

# Immediate kinds for R_LOADIMM

# ── Stack-effect kinds ────────────────────────────────────────────────────
def _pk(npop: int, npush: int, kind: int) -> int {
    return npop + npush * 4096 + kind * 16777216;
}

def _pk_pop(e: int) -> int {
    return e & 4095;
}
def _pk_push(e: int) -> int {
    return (e >> 12) & 4095;
}
def _pk_kind(e: int) -> int {
    return (e >> 24) & 15;
}

"""Base opcode id a megaop head stands for (its window's first instruction):
LOAD_LOCAL (8), LOAD_LOCAL_CHECKED (105) or LOAD_THIS (82); -1 for a
non-megaop."""
def _head_base(ins: Instruction) -> int {
    op: Opcode = ins.opcode;
    if op == Opcode.LOCAL_INC {
        return 8;
    }
    if op == Opcode.SET_LL_PROP {
        return 8;
    }
    if op == Opcode.BR_CMP_LL
        or op == Opcode.GET_LL_INDEX
        or op == Opcode.SET_LL_INDEX
        or op == Opcode.GET_LLC_PROP {
        if (ins.arg2 >> 20) & 1 == 1 {
            return 105;
        }
        return 8;
    }
    if op == Opcode.SET_THIS_PROP {
        return 82;
    }
    if op == Opcode.PROP_INC {
        if (ins.arg3 & 2) == 0 {
            return 82;
        }
        if (ins.arg3 & 4) != 0 {
            return 105;
        }
        return 8;
    }
    return -1;
}

"""The local slot a megaop head loads (valid when _head_base is 8 or 105)."""
def _head_slot(ins: Instruction) -> int {
    return ins.arg;
}

def _is_ip_op(op: Opcode) -> bool {
    return op == Opcode.JUMP
        or op == Opcode.JUMP_IF_TRUE
        or op == Opcode.JUMP_IF_FALSE
        or op == Opcode.JUMP_IF_NULL
        or op == Opcode.JUMP_IF_UNDEFINED
        or op == Opcode.PUSH_CATCH
        or op == Opcode.PUSH_FINALLY;
}

# Per-opcode effects that do not depend on the instruction's operands, by
# opcode id (-1: computed by _reg_effect_slow). Filled on first use.
glob _EFF_TABLE: list[int] = [];

def _eff_table_init {
    i: int = 0;
    while i < 256 {
        _EFF_TABLE.append(-1);
        i = i + 1;
    }
    probe: Instruction = Instruction(opcode=Opcode.NOP, arg=0, arg2=0, line=0);
    i = 0;
    while i < 256 {
        op: Opcode = opcode_from_int(i);
        if i == 0 or op != Opcode.NOP {
            probe.opcode = op;
            if not _effect_is_dynamic(op) {
                _EFF_TABLE[i] = _reg_effect_slow(probe);
            }
        }
        i = i + 1;
    }
}

"""Opcodes whose stack effect depends on the instruction's operands."""
def _effect_is_dynamic(op: Opcode) -> bool {
    return op == Opcode.NEW_ARRAY
        or op == Opcode.CALL
        or op == Opcode.CALL_METHOD
        or op == Opcode.NEW
        or op == Opcode.MAKE_CLASS
        or op == Opcode.DEFINE_METHOD
        or op == Opcode.DEFINE_GETTER
        or op == Opcode.DEFINE_SETTER
        or op == Opcode.DEFINE_FIELD
        or op == Opcode.DYNAMIC_IMPORT
        or op == Opcode.SUPER_CALL
        or op == Opcode.TAIL_CALL
        or op == Opcode.LOAD_NAME_REF
        or _head_base_op(op) >= 0;
}

"""_head_base by opcode alone (any megaop head counts as dynamic)."""
def _head_base_op(op: Opcode) -> int {
    if op == Opcode.LOCAL_INC
        or op == Opcode.SET_LL_PROP
        or op == Opcode.BR_CMP_LL
        or op == Opcode.GET_LL_INDEX
        or op == Opcode.SET_LL_INDEX
        or op == Opcode.GET_LLC_PROP
        or op == Opcode.SET_THIS_PROP
        or op == Opcode.PROP_INC {
        return 8;
    }
    return -1;
}

"""Stack effect of code[i]: npop | npush << 12 | kind << 24. Peeked values
count in both npop and npush (the bridge pushes them and pops them back).
The translator refuses the function (K_BAIL) for ops it does not model."""
def _reg_effect(ins: Instruction) -> int {
    if len(_EFF_TABLE) == 0 {
        _eff_table_init();
    }
    e: int = _EFF_TABLE[int(ins.opcode)];
    if e >= 0 {
        return e;
    }
    return _reg_effect_slow(ins);
}

def _reg_effect_slow(ins: Instruction) -> int {
    op: Opcode = ins.opcode;
    hb: int = _head_base(ins);
    if hb >= 0 {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.LOAD_CONST
        or op == Opcode.LOAD_UNDEFINED
        or op == Opcode.LOAD_NULL
        or op == Opcode.LOAD_TRUE
        or op == Opcode.LOAD_FALSE
        or op == Opcode.LOAD_HOLE
        or op == Opcode.NOP
        or op == Opcode.TDZ_CLASS {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.DEBUGGER or op == Opcode.FILLER {
        return _pk(0, 0, K_NORMAL);
    }
    if op == Opcode.POP {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.DUP {
        return _pk(1, 2, K_NORMAL);
    }
    if op == Opcode.SWAP {
        return _pk(2, 2, K_NORMAL);
    }
    if op == Opcode.LOAD_LOCAL or op == Opcode.LOAD_LOCAL_CHECKED {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.STORE_LOCAL {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.LOAD_GLOBAL {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.STORE_GLOBAL {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.LOAD_FREE {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.STORE_FREE {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.NEW_OBJECT {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.NEW_ARRAY {
        return _pk(ins.arg, 1, K_NORMAL);
    }
    if op == Opcode.GET_PROP {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.SET_PROP {
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.DEL_PROP {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.GET_INDEX {
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.SET_INDEX {
        return _pk(3, 1, K_NORMAL);
    }
    if op == Opcode.HAS_PROP {
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.GET_ITER {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.ITER_NEXT {
        return _pk(0, 0, K_ITERNEXT);
    }
    if op == Opcode.ADD
        or op == Opcode.SUB
        or op == Opcode.MUL
        or op == Opcode.DIV
        or op == Opcode.MOD
        or op == Opcode.POW
        or op == Opcode.BAND
        or op == Opcode.BOR
        or op == Opcode.BXOR
        or op == Opcode.SHL
        or op == Opcode.SHR
        or op == Opcode.USHR
        or op == Opcode.EQ
        or op == Opcode.NEQ
        or op == Opcode.LT
        or op == Opcode.LTE
        or op == Opcode.GT
        or op == Opcode.GTE
        or op == Opcode.STRICT_EQ
        or op == Opcode.STRICT_NEQ
        or op == Opcode.INSTANCEOF
        or op == Opcode.IN
        or op == Opcode.DELETE {
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.NEG
        or op == Opcode.BNOT
        or op == Opcode.NOT
        or op == Opcode.TYPEOF
        or op == Opcode.VOID
        or op == Opcode.TO_NUMBER
        or op == Opcode.TO_STRING {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.JUMP {
        return _pk(0, 0, K_JUMP);
    }
    if op == Opcode.JUMP_IF_TRUE or op == Opcode.JUMP_IF_FALSE {
        return _pk(1, 0, K_COND);
    }
    if op == Opcode.JUMP_IF_NULL or op == Opcode.JUMP_IF_UNDEFINED {
        return _pk(0, 0, K_COND);
    }
    if op == Opcode.CALL {
        return _pk(ins.arg + 1, 1, K_NORMAL);
    }
    if op == Opcode.CALL_METHOD {
        return _pk(ins.arg + 2, 1, K_NORMAL);
    }
    if op == Opcode.NEW {
        return _pk(ins.arg + 1, 1, K_NORMAL);
    }
    if op == Opcode.RETURN {
        return _pk(1, 0, K_TERM);
    }
    if op == Opcode.RETURN_UNDEFINED {
        return _pk(0, 0, K_TERM);
    }
    if op == Opcode.MAKE_FUNCTION or op == Opcode.MAKE_ARROW {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.MAKE_CLASS {
        return _pk(ins.arg, 1, K_NORMAL);
    }
    if op == Opcode.AWAIT or op == Opcode.YIELD or op == Opcode.YIELD_STAR {
        return _pk(1, 1, K_NORMAL);
    }
    # for-await: ASYNC_ITER_NEXT suspends mid-instruction with its own resume
    # path (_resume_async_iter_frame) — such functions stay on the stack ISA.
    if op == Opcode.GET_ASYNC_ITER or op == Opcode.ASYNC_ITER_NEXT {
        return _pk(0, 0, K_BAIL);
    }
    if op == Opcode.TAIL_CALL {
        return _pk(ins.arg + 1, 1, K_NORMAL);
    }
    if op == Opcode.THROW {
        return _pk(1, 0, K_TERM);
    }
    if op == Opcode.PUSH_CATCH or op == Opcode.PUSH_FINALLY {
        return _pk(0, 0, K_HANDLER);
    }
    if op == Opcode.POP_CATCH or op == Opcode.POP_FINALLY {
        return _pk(0, 0, K_NORMAL);
    }
    if op == Opcode.SPREAD {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.REST_ARGS {
        return _pk(1, 2, K_NORMAL);
    }
    if op == Opcode.UNPACK_ARRAY or op == Opcode.UNPACK_OBJECT {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.IMPORT {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.EXPORT {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.LOAD_SELF or op == Opcode.LOAD_THIS {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.OBJECT_SPREAD {
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.ITER_NEXT_VAL {
        return _pk(1, 2, K_NORMAL);
    }
    if op == Opcode.DEFINE_METHOD
        or op == Opcode.DEFINE_GETTER
        or op == Opcode.DEFINE_SETTER {
        if ins.arg == -1 {
            return _pk(3, 1, K_NORMAL);
        }
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.SUPER_CALL {
        return _pk(ins.arg, 1, K_NORMAL);
    }
    if op == Opcode.LOAD_SUPER_PROTO {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.DEFINE_FIELD {
        if ins.arg3 == 1 {
            return _pk(3, 1, K_NORMAL);
        }
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.MAKE_CELL {
        return _pk(0, 0, K_NORMAL);
    }
    if op == Opcode.LOAD_DEREF {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.STORE_DEREF {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.DYNAMIC_IMPORT {
        if ins.arg2 != 0 {
            return _pk(2, 1, K_NORMAL);
        }
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.MAKE_REGEXP {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.IMPORT_META {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.REEXPORT_STAR or op == Opcode.REEXPORT_LIVE {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.STORE_NEW_CELL {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.STORE_MODULE_GLOBAL {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.ITER_CLOSE or op == Opcode.ITER_CLOSE_NRML {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.WITH_PUSH {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.WITH_POP {
        return _pk(0, 0, K_NORMAL);
    }
    if op == Opcode.LOAD_NAME {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.STORE_NAME {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.USING_DECLARE {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.DISPOSE_MARK or op == Opcode.DISPOSE_RUN {
        return _pk(0, 0, K_NORMAL);
    }
    if op == Opcode.REQUIRE_COERCIBLE {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.ITER_CLOSE_THRW {
        return _pk(2, 0, K_TERM);
    }
    if op == Opcode.CHECK_PRIVATE {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.TO_PROPERTY_KEY {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.DEL_NAME {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.SUPER_GET_PROP {
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.SUPER_GET_INDEX {
        return _pk(3, 1, K_NORMAL);
    }
    if op == Opcode.SUPER_SET_PROP {
        return _pk(3, 1, K_NORMAL);
    }
    if op == Opcode.SUPER_SET_INDEX {
        return _pk(4, 1, K_NORMAL);
    }
    if op == Opcode.INFER_NAME_FROM_KEY {
        return _pk(2, 2, K_NORMAL);
    }
    if op == Opcode.LOAD_NEW_TARGET {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.TEMPLATE_OBJECT {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.LOAD_NAME_REF {
        # arg2 == 1: base only (plain `x = rhs` inside `with`); else [base, value].
        if ins.arg2 == 1 {
            return _pk(0, 1, K_NORMAL);
        }
        return _pk(0, 2, K_NORMAL);
    }
    if op == Opcode.STORE_NAME_REF {
        return _pk(2, 1, K_NORMAL);
    }
    if op == Opcode.LOAD_CLASS_BRAND {
        return _pk(0, 1, K_NORMAL);
    }
    if op == Opcode.CREATE_GLOBAL_FN_BINDING {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.RUN_STATIC_ELEMENTS {
        return _pk(1, 1, K_NORMAL);
    }
    if op == Opcode.INSTALL_BRAND {
        return _pk(2, 0, K_NORMAL);
    }
    if op == Opcode.FINALLY_ENTER {
        return _pk(1, 0, K_NORMAL);
    }
    if op == Opcode.FINALLY_RETHROW {
        return _pk(0, 0, K_TERM);
    }
    return _pk(0, 0, K_BAIL);
}

"""True for the stack ops the symbolic emitter handles without any code
(pure stack shuffles): pending TDZ checks need not be flushed before them."""
def _is_pure_shuffle(op: Opcode) -> bool {
    return op == Opcode.LOAD_CONST
        or op == Opcode.LOAD_UNDEFINED
        or op == Opcode.LOAD_NULL
        or op == Opcode.LOAD_TRUE
        or op == Opcode.LOAD_FALSE
        or op == Opcode.LOAD_HOLE
        or op == Opcode.NOP
        or op == Opcode.TDZ_CLASS
        or op == Opcode.DUP
        or op == Opcode.SWAP
        or op == Opcode.LOAD_LOCAL
        or op == Opcode.LOAD_LOCAL_CHECKED
        or op == Opcode.LOAD_SELF
        or op == Opcode.DEBUGGER
        or op == Opcode.FILLER
        or op == Opcode.STORE_LOCAL
        or op == Opcode.POP;
}

# ══════════════════════════════════════════════════════════════════════════
# Translator
# ══════════════════════════════════════════════════════════════════════════

# Virtual-stack entry kinds
glob VS_REG: int = 0,
     VS_CONST: int = 1,
     VS_IMM: int = 2;  # val = register (may carry REG_TDZ_FLAG)

# val = index of the LOAD_CONST instruction
# val = RI_* kind
obj RegTranslator {
    has fn: CompiledFunction,
        n: int = 0,
        nl: int = 0,
        scratch: int = 0,
        max_depth: int = 0,
        defer_ok: bool = True,
        bail: str = "",
        din: list[int] = [],
        reach: list[int] = [],
        is_tgt: list[int] = [],
        is_hnd: list[int] = [],
        cover: list[int] = [],
        rpc_of: list[int] = [],
        rcode: list[int] = [],
        rorig: list[int] = [],
        fix: list[int] = [],
        work: list[int] = [],
        deep: list[int] = [],
        hin: list[int] = [],
        hpar: list[int] = [],
        htable: bool = True,
        rhandler: list[int] = [],
        reg_gen_start: int = -1,
        seen: list[int] = [],
        stamp: int = 0,
        vs_kind: list[int] = [],
        vs_val: list[int] = [],
        cur: int = 0,
        last_pc: int = -1,
        last_pos: int = -1;

    # ── analysis ──────────────────────────────────────────────────────
    def succ(t: int, dep: int, handler: bool, h: int) -> bool {
        if t == self.n {
            return True;
        }
        if t < 0 or t > self.n {
            self.bail = "target out of range";
            return False;
        }
        rk: int = 1;
        if handler {
            rk = 2;
        }
        if self.din[t] < 0 {
            self.din[t] = dep;
            self.reach[t] = rk;
            self.hin[t] = h;
            self.work.append(t);
            return True;
        }
        # Paths disagreeing on the active handler: keep the catch stack.
        if self.hin[t] != h {
            self.htable = False;
        }
        if self.reach[t] != rk {
            self.bail = "handler entry also a jump target at " + str(t);
            return False;
        }
        if self.din[t] == dep {
            return True;
        }
        if handler {
            self.bail = "handler depth mismatch at " + str(t);
            return False;
        }
        # Different depths at a join: the deeper path's extra entries must be
        # dead (verified by check_deep after the analysis). The label takes
        # the minimum; lowering it re-derives everything downstream.
        self.deep.append(t);
        if dep < self.din[t] {
            self.din[t] = dep;
            self.work.append(t);
        }
        return True;
    }

    """Stack effect and unit length of code[i] as analyze() sees them."""
    def unit_effect(i: int) -> int {
        ins: Instruction = self.fn.code[i];
        if ins.opcode == Opcode.SET_LL_INDEX
            and i + 5 < self.n
            and self.cover[i + 1] == 1 {
            return _pk(0, 1, K_NORMAL);
        }
        return _reg_effect(ins);
    }

    def unit_len(i: int) -> int {
        ins: Instruction = self.fn.code[i];
        if ins.opcode == Opcode.SET_LL_INDEX
            and i + 5 < self.n
            and self.cover[i + 1] == 1 {
            return 6;
        }
        if ins.opcode == Opcode.ITER_NEXT {
            return 2;
        }
        return 1;
    }

    """Nothing reachable from label t may consume a value below din[t]:
    then any extra entries a deeper path left there are never read."""
    def check_deep(t: int) -> bool {
        if len(self.seen) == 0 {
            i: int = 0;
            while i < self.n {
                self.seen.append(0);
                i = i + 1;
            }
        }
        self.stamp = self.stamp + 1;
        sm: int = self.stamp;
        stack: list[int] = [];
        stack.append(t);
        self.seen[t] = sm;
        floor: int = self.din[t];
        while len(stack) > 0 {
            cur: int = stack[len(stack) - 1];
            del stack[len(stack) - 1];
            if self.din[cur] < 0 {
                continue;
            }
            e: int = self.unit_effect(cur);
            if self.din[cur] - _pk_pop(e) < floor {
                self.bail = "garbage consumed below " + str(t) + " at " + str(cur);
                return False;
            }
            kind: int = _pk_kind(e);
            ins: Instruction = self.fn.code[cur];
            nxt: int = cur + self.unit_len(cur);
            if kind == K_NORMAL
                or kind == K_COND
                or kind == K_HANDLER
                or kind == K_ITERNEXT {
                if nxt < self.n and self.seen[nxt] != sm {
                    self.seen[nxt] = sm;
                    stack.append(nxt);
                }
            }
            if kind == K_JUMP or kind == K_COND or kind == K_HANDLER {
                if ins.arg >= 0 and ins.arg < self.n and self.seen[ins.arg] != sm {
                    self.seen[ins.arg] = sm;
                    stack.append(ins.arg);
                }
            }
            if kind == K_ITERNEXT {
                jt: int = self.fn.code[cur + 1].arg;
                if jt >= 0 and jt < self.n and self.seen[jt] != sm {
                    self.seen[jt] = sm;
                    stack.append(jt);
                }
            }
        }
        return True;
    }

    def analyze -> bool {
        code: list[Instruction] = self.fn.code;
        n: int = len(code);
        self.n = n;
        i: int = 0;
        while i < n {
            self.din.append(-1);
            self.reach.append(0);
            self.is_tgt.append(0);
            self.is_hnd.append(0);
            self.cover.append(0);
            self.rpc_of.append(0);
            self.hin.append(-1);
            self.hpar.append(-1);
            op_h: Opcode = code[i].opcode;
            if op_h == Opcode.WITH_PUSH
                or op_h == Opcode.WITH_POP
                or op_h == Opcode.USING_DECLARE
                or op_h == Opcode.DISPOSE_MARK
                or op_h == Opcode.DISPOSE_RUN {
                self.htable = False;
            }
            i = i + 1;
        }
        # Jump / handler targets (the optimizer already retargeted them).
        # A generator's parameter-prologue end is an entry point too (the
        # body starts there after the eager prologue run).
        if self.fn.gen_prologue_end_ip > 0 and self.fn.gen_prologue_end_ip < n {
            self.is_tgt[self.fn.gen_prologue_end_ip] = 1;
        }
        i = 0;
        while i < n {
            t_op: Opcode = code[i].opcode;
            if _is_ip_op(t_op) {
                if code[i].arg >= 0 and code[i].arg < n {
                    self.is_tgt[code[i].arg] = 1;
                    if t_op == Opcode.PUSH_CATCH or t_op == Opcode.PUSH_FINALLY {
                        self.is_hnd[code[i].arg] = 1;
                    }
                }
            } elif t_op == Opcode.BR_CMP_LL {
                if code[i].arg3 >= 0 and code[i].arg3 < n {
                    self.is_tgt[code[i].arg3] = 1;
                }
            }
            i = i + 1;
        }
        # Fused windows decided up front (never when a jump enters the window).
        i = 0;
        while i < n {
            w_op: Opcode = code[i].opcode;
            if w_op == Opcode.LOCAL_INC and i + 8 < n {
                # The INC fast path jumps over the window: its end is a label.
                self.is_tgt[i + 8] = 1;
            } elif w_op == Opcode.SET_LL_INDEX and i + 5 < n {
                sl_ok: bool = True;
                sl_k: int = i + 1;
                while sl_k <= i + 5 {
                    if self.is_tgt[sl_k] == 1 {
                        sl_ok = False;
                    }
                    sl_k = sl_k + 1;
                }
                if sl_ok {
                    sl_k = i + 1;
                    while sl_k <= i + 5 {
                        self.cover[sl_k] = 1;
                        sl_k = sl_k + 1;
                    }
                }
            }
            i = i + 1;
        }
        # Depth analysis over the control-flow graph.
        if n == 0 {
            self.bail = "empty code";
            return False;
        }
        self.din[0] = 0;
        self.reach[0] = 1;
        self.work.append(0);
        while len(self.work) > 0 {
            wi: int = self.work[len(self.work) - 1];
            del self.work[len(self.work) - 1];
            d: int = self.din[wi];
            h: int = self.hin[wi];
            ins: Instruction = code[wi];
            ulen: int = 1;
            e: int = 0;
            if ins.opcode == Opcode.SET_LL_INDEX
                and wi + 5 < n
                and self.cover[wi + 1] == 1 {
                # Fused `local[key] = val` window: the value stays on the stack.
                e = _pk(0, 1, K_NORMAL);
                ulen = 6;
            } else {
                e = _reg_effect(ins);
            }
            kind: int = _pk_kind(e);
            if kind == K_BAIL {
                self.bail = "op " + _opname(ins.opcode);
                return False;
            }
            npop: int = _pk_pop(e);
            npush: int = _pk_push(e);
            if d < npop {
                self.bail = "stack underflow at " + str(wi);
                return False;
            }
            if npop >= 4096 {
                self.bail = "operand count";
                return False;
            }
            dout: int = d - npop + npush;
            if dout > self.max_depth {
                self.max_depth = dout;
            }
            if kind == K_ITERNEXT {
                if wi + 1 >= n
                    or code[wi + 1].opcode != Opcode.JUMP_IF_FALSE
                    or self.is_tgt[wi + 1] == 1 {
                    self.bail = "ITER_NEXT shape";
                    return False;
                }
                self.cover[wi + 1] = 1;
                if d + 1 > self.max_depth {
                    self.max_depth = d + 1;
                }
                if not self.succ(wi + 2, d + 1, False, h) {
                    return False;
                }
                if not self.succ(code[wi + 1].arg, d, False, h) {
                    return False;
                }
            } elif kind == K_NORMAL {
                hn: int = h;
                if ins.opcode == Opcode.POP_CATCH or ins.opcode == Opcode.POP_FINALLY {
                    if h >= 0 {
                        hn = self.hpar[h];
                    } else {
                        self.htable = False;
                    }
                }
                if not self.succ(wi + ulen, dout, False, hn) {
                    return False;
                }
            } elif kind == K_JUMP {
                if not self.succ(ins.arg, dout, False, h) {
                    return False;
                }
            } elif kind == K_COND {
                if not self.succ(wi + 1, dout, False, h) {
                    return False;
                }
                if not self.succ(ins.arg, dout, False, h) {
                    return False;
                }
            } elif kind == K_HANDLER {
                # The try body runs under this handler; the handler itself
                # (and whatever follows it) under the enclosing one.
                self.hpar[wi] = h;
                if not self.succ(wi + 1, dout, False, wi) {
                    return False;
                }
                if dout + 1 > self.max_depth {
                    self.max_depth = dout + 1;
                }
                if not self.succ(ins.arg, dout + 1, True, h) {
                    return False;
                }
            }
            # K_TERM: no successors.
        }
        # Depths may have been lowered after their successors were sized:
        # recompute the register-file height from the final depths.
        self.max_depth = 0;
        i = 0;
        while i < n {
            if self.din[i] >= 0 {
                me: int = self.unit_effect(i);
                mk: int = _pk_kind(me);
                mo: int = self.din[i] - _pk_pop(me) + _pk_push(me);
                if mk == K_ITERNEXT or mk == K_HANDLER {
                    mo = self.din[i] + 1;
                }
                if mo > self.max_depth {
                    self.max_depth = mo;
                }
                if self.din[i] > self.max_depth {
                    self.max_depth = self.din[i];
                }
            }
            i = i + 1;
        }
        di: int = 0;
        while di < len(self.deep) {
            if not self.check_deep(self.deep[di]) {
                return False;
            }
            di = di + 1;
        }
        self.scratch = self.nl + self.max_depth;
        if self.scratch >= 32768 {
            self.bail = "too many registers";
            return False;
        }
        return True;
    }

    # ── emission helpers ──────────────────────────────────────────────
    def e(op: int, a: int, b: int, c: int) {
        self.rcode.append(reg_word(op, a, b, c));
        self.rorig.append(self.cur);
        # Any emission after a producer may read its temporary: the producer
        # can no longer be retargeted (push_result re-arms it right after).
        self.last_pos = -1;
    }

    def e_raw(w: int) {
        self.rcode.append(w);
        self.rorig.append(self.cur);
    }

    def temp(k: int) -> int {
        return self.nl + k;
    }
    def depth -> int {
        return len(self.vs_kind);
    }
    def vpush(kind: int, val: int) {
        self.vs_kind.append(kind);
        self.vs_val.append(val);
    }

    def vpop {
        del self.vs_kind[len(self.vs_kind) - 1];
        del self.vs_val[len(self.vs_val) - 1];
    }

    """Emit the load of a constant-pool entry (the LOAD_CONST at `orig`) into
    register `dst`: an int32 immediate when it fits, else the cached decode."""
    def emit_const(dst: int, orig: int) {
        ci: int = _bcopt_small_int_const(self.fn, self.fn.code[orig].arg);
        if ci != _BCOPT_NO_INT and ci > 0 - REG_IBIAS and ci < REG_IBIAS {
            self.e(R_LOADI, dst, 0, ci + REG_IBIAS);
        } else {
            self.e(R_LOADK, dst, 0, orig);
        }
    }

    """Emit the move of position k's symbolic value into register `dst`."""
    def emit_sym_to(dst: int, k: int) {
        kd: int = self.vs_kind[k];
        v: int = self.vs_val[k];
        if kd == VS_REG {
            if v != dst {
                self.e(R_MOVE, dst, v, 0);
            }
        } elif kd == VS_CONST {
            self.emit_const(dst, v);
        } else {
            self.e(R_LOADIMM, dst, v, 0);
        }
    }

    """True when position k already holds its canonical temporary."""
    def is_canon(k: int) -> bool {
        return self.vs_kind[k] == VS_REG and self.vs_val[k] == self.temp(k);
    }

    """Make register `r` safe to overwrite: every position other than `keep`
    that still reads `r` (an alias a DUP/SWAP left behind) is moved first —
    into its own canonical temporary when nothing else reads that, else into
    the scratch register (the translation is refused if the scratch is busy)."""
    def claim(r: int, keep: int) {
        j: int = 0;
        d: int = self.depth();
        parked: bool = False;
        while j < d {
            if j != keep
                and self.vs_kind[j] == VS_REG
                and (self.vs_val[j] & REG_MASK) == r {
                f: int = self.vs_val[j] & REG_TDZ_FLAG;
                tj: int = self.temp(j);
                if tj != r and self.refs_reg(tj) == 0 {
                    self.e(R_MOVE, tj, r, 0);
                    self.vs_val[j] = tj + f;
                } else {
                    if not parked {
                        if self.refs_reg(self.scratch) > 0 {
                            self.bail = "scratch register busy";
                        }
                        self.e(R_MOVE, self.scratch, r, 0);
                        parked = True;
                    }
                    self.vs_val[j] = self.scratch + f;
                }
            }
            j = j + 1;
        }
    }

    """Materialize position k into its canonical temporary."""
    def mat_pos(k: int) -> None {
        if self.is_canon(k) {
            return;
        }
        self.claim(self.temp(k), k);
        self.emit_sym_to(self.temp(k), k);
        self.vs_kind[k] = VS_REG;
        self.vs_val[k] = self.temp(k);
    }

    """Materialize positions [lo, hi) into their canonical temporaries."""
    def mat_range(lo: int, hi: int) {
        k: int = lo;
        while k < hi {
            self.mat_pos(k);
            k = k + 1;
        }
    }

    def mat_all {
        self.mat_range(0, self.depth());
        self.last_pos = -1;
    }

    def mat_top(m: int) {
        self.mat_range(self.depth() - m, self.depth());
    }

    """Materialize every constant / immediate in positions [lo, hi) so the
    registers of all of them can then be read (materializing one position
    may relocate an alias held by another, so no register is read before
    every operand is in place)."""
    def prep(lo: int, hi: int) {
        k: int = lo;
        while k < hi {
            if self.vs_kind[k] != VS_REG {
                self.mat_pos(k);
            }
            k = k + 1;
        }
    }

    """The canonical temporary of position k as an instruction's destination:
    every other position still aliasing that register is moved away first
    (so the write cannot clobber a live value); `keep` is the operand
    position that legitimately holds it (the instruction reads it before
    writing), -1 for none. Operand registers are read AFTER this."""
    def dest(k: int, keep: int) -> int {
        self.claim(self.temp(k), keep);
        return self.temp(k);
    }

    """Register operand for position k: its register (flag included), or
    its canonical temporary after materializing a constant / immediate.
    For an instruction with several operands use prep() then vs_val."""
    def operand(k: int) -> int {
        if self.vs_kind[k] == VS_REG {
            return self.vs_val[k];
        }
        self.mat_pos(k);
        return self.temp(k);
    }

    """Emit the pending TDZ checks of every position below the top `keep`
    (the ones the next instruction does not consume itself), in stack order."""
    def flush_checks(keep: int) {
        k: int = 0;
        lim: int = self.depth() - keep;
        while k < lim {
            if self.vs_kind[k] == VS_REG and (self.vs_val[k] & REG_TDZ_FLAG) != 0 {
                self.e(R_CHECKTDZ, self.vs_val[k] & REG_MASK, 0, 0);
                self.vs_val[k] = self.vs_val[k] & REG_MASK;
            }
            k = k + 1;
        }
    }

    """Before local slot `s` is written: every position that still refers to
    it must capture the current value first."""
    def write_local(s: int) {
        k: int = 0;
        d: int = self.depth();
        while k < d {
            if self.vs_kind[k] == VS_REG and (self.vs_val[k] & REG_MASK) == s {
                self.mat_pos(k);
            }
            k = k + 1;
        }
    }

    def refs_reg(r: int) -> int {
        c: int = 0;
        k: int = 0;
        d: int = self.depth();
        while k < d {
            if self.vs_kind[k] == VS_REG and (self.vs_val[k] & REG_MASK) == r {
                c = c + 1;
            }
            k = k + 1;
        }
        return c;
    }

    def push_local(slot: int, checked: bool) {
        f: int = 0;
        if checked {
            f = REG_TDZ_FLAG;
        }
        if self.defer_ok {
            self.vpush(VS_REG, slot + f);
        } else {
            t: int = self.temp(self.depth());
            self.claim(t, -1);
            self.e(R_MOVE, t, slot + f, 0);
            self.vpush(VS_REG, t);
        }
    }

    """Push the canonical temporary of the position just produced by the
    instruction at pc `pc` (retargetable by a following STORE_LOCAL)."""
    def push_result(pc: int) {
        d: int = self.depth();
        self.vpush(VS_REG, self.temp(d));
        self.last_pc = pc;
        self.last_pos = d;
    }

    def note_target(pc: int) {
        self.fix.append(pc);
    }

    """Run the stack instruction at `i` through the existing handler via the
    operand stack (R_STK)."""
    def bridge(i: int, npop: int, npush: int) {
        self.flush_checks(npop);
        self.mat_top(npop);
        d: int = self.depth();
        base: int = self.temp(d - npop);
        rk: int = 0;
        while rk < npush {
            if rk < npop {
                self.claim(base + rk, d - npop + rk);
            } else {
                self.claim(base + rk, -1);
            }
            rk = rk + 1;
        }
        self.e(R_STK, base, npop + npush * 4096, i);
        k: int = 0;
        while k < npop {
            self.vpop();
            k = k + 1;
        }
        k = 0;
        while k < npush {
            self.vpush(VS_REG, base + k);
            k = k + 1;
        }
        self.last_pos = -1;
    }

    def store_local(s: int) {
        d: int = self.depth();
        kd: int = self.vs_kind[d - 1];
        v: int = self.vs_val[d - 1];
        ct: int = self.temp(d - 1);
        self.vpop();
        if kd == VS_REG
            and v == ct
            and self.last_pos == d - 1
            and self.last_pc >= 0
            and self.refs_reg(s) == 0
            and (self.defer_ok or self.refs_reg(ct) == 0) {
            # The producer writes the local directly.
            self.rcode[self.last_pc] = reg_set_a(self.rcode[self.last_pc], s);
            if self.refs_reg(ct) > 0 {
                k: int = 0;
                while k < d - 1 {
                    if self.vs_kind[k] == VS_REG
                        and (self.vs_val[k] & REG_MASK) == ct {
                        self.vs_val[k] = s;
                    }
                    k = k + 1;
                }
            }
        } else {
            self.write_local(s);
            if kd == VS_REG {
                if v != s {
                    self.e(R_MOVE, s, v, 0);
                }
            } elif kd == VS_CONST {
                self.emit_const(s, v);
            } else {
                self.e(R_LOADIMM, s, v, 0);
            }
        }
        self.last_pos = -1;
    }

    def branch_op(op: Opcode, jit: bool) -> int {
        if op == Opcode.LT {
            return R_BLT if jit else R_BNLT;
        }
        if op == Opcode.LTE {
            return R_BLE if jit else R_BNLE;
        }
        if op == Opcode.GT {
            return R_BGT if jit else R_BNGT;
        }
        if op == Opcode.GTE {
            return R_BGE if jit else R_BNGE;
        }
        if op == Opcode.STRICT_EQ {
            return R_BSEQ if jit else R_BSNE;
        }
        if op == Opcode.STRICT_NEQ {
            return R_BSNE if jit else R_BSEQ;
        }
        if op == Opcode.EQ {
            return R_BEQ if jit else R_BNE;
        }
        return R_BNE if jit else R_BEQ;
    }

    def value_cmp_op(op: Opcode) -> int {
        if op == Opcode.LT {
            return R_LT;
        }
        if op == Opcode.LTE {
            return R_LTE;
        }
        if op == Opcode.GT {
            return R_GT;
        }
        if op == Opcode.GTE {
            return R_GTE;
        }
        if op == Opcode.EQ {
            return R_EQ;
        }
        if op == Opcode.NEQ {
            return R_NEQ;
        }
        if op == Opcode.STRICT_EQ {
            return R_SEQ;
        }
        if op == Opcode.STRICT_NEQ {
            return R_SNEQ;
        }
        if op == Opcode.INSTANCEOF {
            return R_INSTANCEOF;
        }
        return R_IN;
    }

    def arith_op(op: Opcode) -> int {
        if op == Opcode.ADD {
            return R_ADD;
        }
        if op == Opcode.SUB {
            return R_SUB;
        }
        if op == Opcode.MUL {
            return R_MUL;
        }
        if op == Opcode.DIV {
            return R_DIV;
        }
        if op == Opcode.MOD {
            return R_MOD;
        }
        if op == Opcode.POW {
            return R_POW;
        }
        if op == Opcode.BAND {
            return R_BAND;
        }
        if op == Opcode.BOR {
            return R_BOR;
        }
        if op == Opcode.BXOR {
            return R_BXOR;
        }
        if op == Opcode.SHL {
            return R_SHL;
        }
        if op == Opcode.SHR {
            return R_SHR;
        }
        return R_USHR;
    }

    def unary_op(op: Opcode) -> int {
        if op == Opcode.NEG {
            return R_NEG;
        }
        if op == Opcode.NOT {
            return R_NOT;
        }
        if op == Opcode.BNOT {
            return R_BNOT;
        }
        if op == Opcode.TYPEOF {
            return R_TYPEOF;
        }
        if op == Opcode.VOID {
            return R_VOID;
        }
        if op == Opcode.TO_NUMBER {
            return R_TONUM;
        }
        return R_TOSTR;
    }

    """Translate the stack instruction at `i`. Returns whether control falls
    through to the next (uncovered) instruction."""
    def tr_ins(i: int) -> bool {
        code: list[Instruction] = self.fn.code;
        ins: Instruction = code[i];
        op: Opcode = ins.opcode;
        self.cur = i;
        d: int = self.depth();
        hb: int = _head_base(ins);
        # ── megaop heads ───────────────────────────────────────────────
        if op == Opcode.SET_LL_INDEX and i + 5 < self.n and self.cover[i + 1] == 1 {
            # `localObj[localKey] = localVal;` from the head operands (the
            # window interior may have been copy-propagated away).
            self.flush_checks(0);
            f_obj: int = 0;
            if hb == 105 {
                f_obj = REG_TDZ_FLAG;
            }
            r_obj: int = ins.arg + f_obj;
            r_key: int = ins.arg2 & 65535;
            r_val: int = ins.arg3;
            if not self.defer_ok {
                r_obj = self.dest(d, -1);
                self.e(R_MOVE, r_obj, ins.arg + f_obj, 0);
                r_key = self.dest(d + 1, -1);
                self.e(R_MOVE, r_key, ins.arg2 & 65535, 0);
                r_val = self.dest(d + 2, -1);
                self.e(R_MOVE, r_val, ins.arg3, 0);
            }
            self.cur = i + 1;
            self.e(R_REQCOERCE, r_obj, 0, i + 1);
            self.cur = i + 5;
            self.e(R_SETINDEX, r_obj & REG_MASK, r_key, r_val);
            self.cur = i;
            self.vpush(VS_REG, r_val);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.LOCAL_INC and i + 8 < self.n {
            self.mat_all();
            ipc: int = len(self.rcode);
            self.e(R_INC, ins.arg, ins.arg2 + 1, i + 8);
            self.note_target(ipc);
            self.push_local(ins.arg, False);
            return True;
        }
        if hb == 8 {
            self.push_local(_head_slot(ins), False);
            return True;
        }
        if hb == 105 {
            self.push_local(_head_slot(ins), True);
            return True;
        }
        if hb == 82 {
            op = Opcode.LOAD_THIS;
        }
        # ── pure stack shuffles ────────────────────────────────────────
        if op == Opcode.LOAD_CONST {
            self.vpush(VS_CONST, i);
            return True;
        }
        if op == Opcode.LOAD_UNDEFINED {
            self.vpush(VS_IMM, RI_UNDEFINED);
            return True;
        }
        if op == Opcode.LOAD_NULL {
            self.vpush(VS_IMM, RI_NULL);
            return True;
        }
        if op == Opcode.LOAD_TRUE {
            self.vpush(VS_IMM, RI_TRUE);
            return True;
        }
        if op == Opcode.LOAD_FALSE {
            self.vpush(VS_IMM, RI_FALSE);
            return True;
        }
        if op == Opcode.LOAD_HOLE {
            self.vpush(VS_IMM, RI_HOLE);
            return True;
        }
        if op == Opcode.NOP or op == Opcode.TDZ_CLASS {
            self.vpush(VS_IMM, RI_TDZ);
            return True;
        }
        if op == Opcode.DEBUGGER or op == Opcode.FILLER {
            return True;
        }
        if op == Opcode.LOAD_LOCAL {
            self.push_local(ins.arg, False);
            return True;
        }
        if op == Opcode.LOAD_LOCAL_CHECKED {
            self.push_local(ins.arg, True);
            return True;
        }
        if op == Opcode.DUP {
            self.vpush(self.vs_kind[d - 1], self.vs_val[d - 1]);
            return True;
        }
        if op == Opcode.SWAP {
            tk: int = self.vs_kind[d - 1];
            tv: int = self.vs_val[d - 1];
            self.vs_kind[d - 1] = self.vs_kind[d - 2];
            self.vs_val[d - 1] = self.vs_val[d - 2];
            self.vs_kind[d - 2] = tk;
            self.vs_val[d - 2] = tv;
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.POP
            or op == Opcode.UNPACK_ARRAY
            or op == Opcode.UNPACK_OBJECT {
            if self.vs_kind[d - 1] == VS_REG
                and (self.vs_val[d - 1] & REG_TDZ_FLAG) != 0 {
                self.e(R_CHECKTDZ, self.vs_val[d - 1] & REG_MASK, 0, 0);
            }
            self.vpop();
            if self.last_pos >= d - 1 {
                self.last_pos = -1;
            }
            return True;
        }
        if op == Opcode.STORE_LOCAL {
            self.store_local(ins.arg);
            return True;
        }
        if op == Opcode.LOAD_SELF {
            self.e(R_LOADSELF, self.dest(d, -1), 0, 0);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        # ── everything below may throw or have effects: flush pending checks ──
        if op == Opcode.STORE_DEREF {
            self.flush_checks(1);
            r: int = self.operand(d - 1);
            self.vpop();
            self.e(R_STOREDEREF, r, ins.arg, 0);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.STORE_FREE {
            self.flush_checks(1);
            r: int = self.operand(d - 1);
            self.vpop();
            self.e(R_STOREFREE, r, ins.arg, i);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.STORE_NEW_CELL {
            self.flush_checks(1);
            self.write_local(ins.arg);
            r: int = self.operand(d - 1);
            self.vpop();
            self.e(R_STORENEWCELL, r, ins.arg, 0);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.MAKE_CELL {
            self.flush_checks(0);
            self.write_local(ins.arg);
            self.e(R_MAKECELL, ins.arg, 0, 0);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.LOAD_FREE {
            self.flush_checks(0);
            self.e(R_LOADFREE, self.dest(d, -1), ins.arg, i);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.LOAD_DEREF {
            self.flush_checks(0);
            self.e(R_LOADDEREF, self.dest(d, -1), ins.arg, i);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.LOAD_GLOBAL {
            self.flush_checks(0);
            self.e(R_LOADGLOBAL, self.dest(d, -1), 0, i);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.LOAD_THIS {
            self.flush_checks(0);
            self.e(R_LOADTHIS, self.dest(d, -1), 0, i);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.NEW_OBJECT {
            self.flush_checks(0);
            self.e(R_NEWOBJECT, self.dest(d, -1), 0, 0);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.ADD
            or op == Opcode.SUB
            or op == Opcode.MUL
            or op == Opcode.DIV
            or op == Opcode.MOD
            or op == Opcode.POW
            or op == Opcode.BAND
            or op == Opcode.BOR
            or op == Opcode.BXOR
            or op == Opcode.SHL
            or op == Opcode.SHR
            or op == Opcode.USHR {
            self.flush_checks(2);
            immv: int = _BCOPT_NO_INT;
            if (op == Opcode.ADD or op == Opcode.SUB)
                and self.vs_kind[d - 1] == VS_CONST {
                immv = _bcopt_small_int_const(self.fn, code[self.vs_val[d - 1]].arg);
                if not (immv > 0 - REG_IBIAS and immv < REG_IBIAS) {
                    immv = _BCOPT_NO_INT;
                }
            }
            if immv != _BCOPT_NO_INT {
                self.prep(d - 2, d - 1);
                dst: int = self.dest(d - 2, d - 2);
                ra: int = self.vs_val[d - 2];
                self.vpop();
                self.vpop();
                iop: int = R_SUBI;
                if op == Opcode.ADD {
                    iop = R_ADDI;
                }
                self.e(iop, dst, ra, immv + REG_IBIAS);
            } else {
                self.prep(d - 2, d);
                dst2: int = self.dest(d - 2, d - 2);
                ra2: int = self.vs_val[d - 2];
                rb: int = self.vs_val[d - 1];
                self.vpop();
                self.vpop();
                self.e(self.arith_op(op), dst2, ra2, rb);
            }
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.NEG
            or op == Opcode.NOT
            or op == Opcode.BNOT
            or op == Opcode.TYPEOF
            or op == Opcode.VOID
            or op == Opcode.TO_NUMBER
            or op == Opcode.TO_STRING {
            self.flush_checks(1);
            self.prep(d - 1, d);
            dst: int = self.dest(d - 1, d - 1);
            r: int = self.vs_val[d - 1];
            self.vpop();
            self.e(self.unary_op(op), dst, r, 0);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.EQ
            or op == Opcode.NEQ
            or op == Opcode.LT
            or op == Opcode.LTE
            or op == Opcode.GT
            or op == Opcode.GTE
            or op == Opcode.STRICT_EQ
            or op == Opcode.STRICT_NEQ
            or op == Opcode.INSTANCEOF
            or op == Opcode.IN {
            self.flush_checks(2);
            if i + 1 < self.n
                and op != Opcode.INSTANCEOF
                and op != Opcode.IN
                and (
                    code[i + 1].opcode == Opcode.JUMP_IF_FALSE
                    or code[i + 1].opcode == Opcode.JUMP_IF_TRUE
                )
                and self.is_tgt[i + 1] == 0
                and self.din[i + 1] >= 0 {
                # compare → branch, the boolean never materialized. Both
                # successors expect the positions below the operands canonical.
                self.mat_range(0, d - 2);
                self.prep(d - 2, d);
                fa: int = self.vs_val[d - 2];
                fb: int = self.vs_val[d - 1];
                self.vpop();
                self.vpop();
                bpc: int = len(self.rcode);
                jit: bool = code[i + 1].opcode == Opcode.JUMP_IF_TRUE;
                fop: int = self.branch_op(op, jit);
                self.e(fop, fa, fb, code[i + 1].arg);
                self.note_target(bpc);
                self.cover[i + 1] = 1;
                self.last_pos = -1;
                return True;
            }
            self.prep(d - 2, d);
            dst: int = self.dest(d - 2, d - 2);
            ra: int = self.vs_val[d - 2];
            rb: int = self.vs_val[d - 1];
            self.vpop();
            self.vpop();
            self.e(self.value_cmp_op(op), dst, ra, rb);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.JUMP_IF_TRUE or op == Opcode.JUMP_IF_FALSE {
            self.mat_range(0, d - 1);
            self.prep(d - 1, d);
            r: int = self.vs_val[d - 1];
            self.vpop();
            bpc: int = len(self.rcode);
            bop: int = R_BFALSE;
            if op == Opcode.JUMP_IF_TRUE {
                bop = R_BTRUE;
            }
            self.e(bop, r, 0, ins.arg);
            self.note_target(bpc);
            return True;
        }
        if op == Opcode.JUMP_IF_NULL or op == Opcode.JUMP_IF_UNDEFINED {
            self.mat_all();
            bpc: int = len(self.rcode);
            nop2: int = R_BUNDEF;
            if op == Opcode.JUMP_IF_NULL {
                nop2 = R_BNULL;
            }
            self.e(nop2, self.temp(d - 1), 0, ins.arg);
            self.note_target(bpc);
            return True;
        }
        if op == Opcode.JUMP {
            self.mat_all();
            bpc: int = len(self.rcode);
            self.e(R_JMP, 0, 0, ins.arg);
            self.note_target(bpc);
            return False;
        }
        if op == Opcode.PUSH_CATCH or op == Opcode.PUSH_FINALLY {
            self.mat_all();
            if self.htable {
                self.last_pos = -1;
                return True;
            }
            bpc: int = len(self.rcode);
            pop2: int = R_PUSHFINALLY;
            if op == Opcode.PUSH_CATCH {
                pop2 = R_PUSHCATCH;
            }
            self.e(pop2, 0, 0, ins.arg);
            self.note_target(bpc);
            return True;
        }
        if op == Opcode.POP_CATCH {
            if not self.htable {
                self.e(R_POPCATCH, 0, 0, 0);
            }
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.POP_FINALLY {
            if not self.htable {
                self.e(R_POPFINALLY, 0, 0, 0);
            }
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.THROW {
            self.flush_checks(1);
            r: int = self.operand(d - 1);
            self.vpop();
            self.e(R_THROW, r, 0, 0);
            return False;
        }
        if op == Opcode.RETURN {
            self.flush_checks(1);
            r: int = self.operand(d - 1);
            self.vpop();
            self.e(R_RETURN, r, 0, 0);
            return False;
        }
        if op == Opcode.RETURN_UNDEFINED {
            self.flush_checks(0);
            self.e(R_RETUNDEF, 0, 0, 0);
            return False;
        }
        if op == Opcode.GET_PROP {
            self.flush_checks(1);
            self.prep(d - 1, d);
            dst: int = self.dest(d - 1, d - 1);
            r: int = self.vs_val[d - 1];
            self.vpop();
            self.e(R_GETFIELD, dst, r, i);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.SET_PROP {
            self.flush_checks(2);
            self.prep(d - 2, d);
            ro: int = self.vs_val[d - 2];
            rv: int = self.vs_val[d - 1];
            self.vpop();
            self.vpop();
            self.e(R_SETFIELD, ro, rv, i);
            self.vpush(VS_REG, rv & REG_MASK);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.GET_INDEX {
            self.flush_checks(2);
            self.prep(d - 2, d);
            dst: int = self.dest(d - 2, d - 2);
            ro: int = self.vs_val[d - 2];
            ri: int = self.vs_val[d - 1];
            self.vpop();
            self.vpop();
            self.e(R_GETINDEX, dst, ro, ri);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.SET_INDEX {
            self.flush_checks(3);
            self.prep(d - 3, d);
            ro: int = self.vs_val[d - 3];
            ri: int = self.vs_val[d - 2];
            rv: int = self.vs_val[d - 1];
            self.vpop();
            self.vpop();
            self.vpop();
            self.e(R_SETINDEX, ro, ri, rv);
            self.vpush(VS_REG, rv & REG_MASK);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.REQUIRE_COERCIBLE {
            self.flush_checks(1);
            r: int = self.operand(d - 1);
            self.e(R_REQCOERCE, r, 0, i);
            self.vs_val[d - 1] = r & REG_MASK;
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.TO_PROPERTY_KEY {
            self.flush_checks(1);
            self.prep(d - 1, d);
            dst: int = self.dest(d - 1, d - 1);
            r: int = self.vs_val[d - 1];
            self.vpop();
            self.e(R_TOPROPKEY, dst, r, i);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.CALL
            or op == Opcode.CALL_METHOD
            or op == Opcode.TAIL_CALL
            or op == Opcode.NEW {
            nargs: int = ins.arg;
            below: int = 1;
            if op == Opcode.CALL_METHOD {
                below = 2;
            }
            nop: int = nargs + below;
            self.flush_checks(nop);
            base: int = d - nop;
            # Operand registers, left to right (constants land in their temps).
            self.prep(base, d);
            dst: int = self.dest(base, base);
            k: int = 0;
            cr: int = self.vs_val[base];
            cop: int = R_CALLM;
            if op == Opcode.CALL {
                cop = R_CALL;
            }
            if op == Opcode.TAIL_CALL {
                cop = R_TAILCALL;
            }
            if op == Opcode.NEW {
                cop = R_NEW;
            }
            cpc: int = len(self.rcode);
            self.e(cop, dst, cr, nargs);
            k = 1;
            while k < nop {
                self.e_raw(self.vs_val[base + k]);
                k = k + 1;
            }
            k = 0;
            while k < nop {
                self.vpop();
                k = k + 1;
            }
            self.push_result(cpc);
            return True;
        }
        if op == Opcode.ITER_NEXT {
            self.mat_all();
            bpc: int = len(self.rcode);
            self.e(R_ITERNEXT, self.dest(d, -1), self.temp(d - 1), code[i + 1].arg);
            self.note_target(bpc);
            self.push_result(bpc);
            return True;
        }
        if op == Opcode.FINALLY_ENTER {
            self.flush_checks(1);
            self.write_local(ins.arg);
            r: int = self.operand(d - 1);
            self.vpop();
            self.e(R_FINENTER, ins.arg, r & REG_MASK, 0);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.FINALLY_RETHROW {
            self.flush_checks(0);
            self.e(R_FINRETHROW, ins.arg, 0, 0);
            return False;
        }
        if op == Opcode.NEW_ARRAY and (ins.arg3 & 16) != 0 {
            # `[a, b, c]` without a spread: the elements are materialized into
            # consecutive temporaries (as for a bridged op) and the array
            # lands in the first of them.
            na_n: int = ins.arg;
            self.flush_checks(na_n);
            self.mat_top(na_n);
            na_base: int = self.temp(d - na_n);
            if na_n > 0 {
                self.claim(na_base, d - na_n);
            } else {
                self.claim(na_base, -1);
            }
            self.e(R_NEWARRAY, na_base, na_n, i);
            na_k: int = 0;
            while na_k < na_n {
                self.vpop();
                na_k = na_k + 1;
            }
            self.vpush(VS_REG, na_base);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.YIELD or op == Opcode.AWAIT or op == Opcode.YIELD_STAR {
            # The frame suspends in the handler; the value it resumes with is
            # written into dst by the generator machinery (_reg_resume_value).
            self.flush_checks(1);
            self.prep(d - 1, d);
            ya_dst: int = self.dest(d - 1, d - 1);
            ya_r: int = self.vs_val[d - 1];
            self.vpop();
            ya_op: int = R_YIELD;
            if op == Opcode.AWAIT {
                ya_op = R_AWAIT;
            }
            if op == Opcode.YIELD_STAR {
                ya_op = R_YIELDSTAR;
            }
            self.e(ya_op, ya_dst, ya_r, i);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        if op == Opcode.ITER_NEXT_VAL {
            # [iter] -> [iter, value]: the iterator is materialized into its
            # temporary so the value lands in the next one (the bridge's
            # layout, which the slow path relies on).
            self.flush_checks(1);
            self.mat_top(1);
            inv_base: int = self.temp(d - 1);
            self.claim(inv_base, d - 1);
            self.claim(inv_base + 1, -1);
            self.e(R_ITERNEXTVAL, inv_base + 1, inv_base, i);
            self.vpush(VS_REG, inv_base + 1);
            self.last_pos = -1;
            return True;
        }
        if op == Opcode.GET_ITER and ins.arg == 0 {
            self.flush_checks(1);
            self.prep(d - 1, d);
            gi_dst: int = self.dest(d - 1, d - 1);
            gi_r: int = self.vs_val[d - 1];
            self.vpop();
            self.e(R_GETITER, gi_dst, gi_r, i);
            self.push_result(len(self.rcode) - 1);
            return True;
        }
        # ── everything else: the existing handler, via the operand stack ──
        e: int = _reg_effect(ins);
        self.bridge(i, _pk_pop(e), _pk_push(e));
        return _pk_kind(e) != K_TERM;
    }

    def emit_all -> bool {
        code: list[Instruction] = self.fn.code;
        n: int = self.n;
        prev_falls: bool = False;
        i: int = 0;
        while i < n {
            if self.cover[i] == 1 {
                self.rpc_of[i] = len(self.rcode);
                i = i + 1;
                continue;
            }
            if self.din[i] < 0 {
                # Unreachable: emit nothing. (A jump target is always reached.)
                self.rpc_of[i] = len(self.rcode);
                prev_falls = False;
                i = i + 1;
                continue;
            }
            if self.is_tgt[i] == 1 or not prev_falls {
                if prev_falls {
                    if self.depth() < self.din[i] {
                        self.bail = "label depth drift at " + str(i);
                        return False;
                    }
                    # Entries above the label's depth are dead here (a join
                    # whose other path is shallower); only their pending TDZ
                    # checks still matter.
                    self.flush_checks(0);
                    self.mat_range(0, self.din[i]);
                }
                self.rpc_of[i] = len(self.rcode);
                # Canonical state at a join: position k in temp k.
                while len(self.vs_kind) > 0 {
                    self.vpop();
                }
                k: int = 0;
                while k < self.din[i] {
                    self.vpush(VS_REG, self.temp(k));
                    k = k + 1;
                }
                self.last_pos = -1;
                if self.is_hnd[i] == 1 {
                    self.cur = i;
                    self.e(R_LANDING, self.temp(self.din[i] - 1), 0, 0);
                }
            } else {
                if self.depth() != self.din[i] {
                    self.bail = "emit depth drift at " + str(i);
                    return False;
                }
                self.rpc_of[i] = len(self.rcode);
            }
            prev_falls = self.tr_ins(i);
            if self.bail != "" {
                return False;
            }
            if len(self.rcode) > REG_C_MAX {
                self.bail = "code too large";
                return False;
            }
            i = i + 1;
        }
        # Branch targets: stack index → register pc.
        fi: int = 0;
        while fi < len(self.fix) {
            fpc: int = self.fix[fi];
            w: int = self.rcode[fpc];
            t: int = reg_c(w);
            rt: int = len(self.rcode);
            if t < n {
                rt = self.rpc_of[t];
            }
            self.rcode[fpc] = reg_set_c(w, rt);
            fi = fi + 1;
        }
        self.thread_jumps();
        return True;
    }

    """True for the register opcodes whose C field is a register pc."""
    def is_target_op(op: int) -> bool {
        return (op >= R_BLT and op <= R_JMP)
            or op == R_PUSHCATCH
            or op == R_PUSHFINALLY
            or op == R_ITERNEXT
            or op == R_INC;
    }

    """The branch with the opposite condition, or -1 (BNULL / BUNDEF)."""
    def inverse_branch(op: int) -> int {
        if op >= R_BLT and op <= R_BFALSE {
            return op ^ 1;
        }
        return -1;
    }

    """Post-pass over the finished code: (1) a JMP to the next word is
    dropped; (2) a JMP whose target is a compare-and-branch — the loop
    header — becomes that branch inverted, straight into the body, plus a
    JMP to the header's exit: the back edge costs one dispatch instead of
    two. All register-pc fields are remapped; CALL argument words are copied
    verbatim."""
    def thread_jumps {
        n: int = len(self.rcode);
        pmap: list[int] = [];
        i: int = 0;
        while i <= n {
            pmap.append(0);
            i = i + 1;
        }
        # Pass 1: new positions.
        cur: int = 0;
        i = 0;
        while i < n {
            pmap[i] = cur;
            w: int = self.rcode[i];
            op: int = reg_op(w);
            if op == R_CALL or op == R_CALLM or op == R_TAILCALL or op == R_NEW {
                extra: int = reg_c(w);
                if op == R_CALLM {
                    extra = extra + 1;
                }
                k: int = 0;
                while k < extra {
                    pmap[i + 1 + k] = cur + 1 + k;
                    k = k + 1;
                }
                cur = cur + 1 + extra;
                i = i + 1 + extra;
                continue;
            }
            if op == R_JMP {
                t: int = reg_c(w);
                if t == i + 1 {
                    i = i + 1;
                    continue;
                }
                if t < n and self.inverse_branch(reg_op(self.rcode[t])) >= 0 {
                    cur = cur + 2;
                    i = i + 1;
                    continue;
                }
            }
            cur = cur + 1;
            i = i + 1;
        }
        pmap[n] = cur;
        # Pass 2: emit with remapped targets.
        ncode: list[int] = [];
        norig: list[int] = [];
        i = 0;
        while i < n {
            w2: int = self.rcode[i];
            op2: int = reg_op(w2);
            if op2 == R_CALL or op2 == R_CALLM or op2 == R_TAILCALL or op2 == R_NEW {
                extra2: int = reg_c(w2);
                if op2 == R_CALLM {
                    extra2 = extra2 + 1;
                }
                ncode.append(w2);
                norig.append(self.rorig[i]);
                k2: int = 0;
                while k2 < extra2 {
                    ncode.append(self.rcode[i + 1 + k2]);
                    norig.append(self.rorig[i + 1 + k2]);
                    k2 = k2 + 1;
                }
                i = i + 1 + extra2;
                continue;
            }
            if op2 == R_JMP {
                t2: int = reg_c(w2);
                if t2 == i + 1 {
                    i = i + 1;
                    continue;
                }
                if t2 < n {
                    hw: int = self.rcode[t2];
                    inv: int = self.inverse_branch(reg_op(hw));
                    if inv >= 0 {
                        ncode.append(reg_word(inv, reg_a(hw), reg_b(hw), pmap[t2 + 1]));
                        norig.append(self.rorig[t2]);
                        ncode.append(reg_word(R_JMP, 0, 0, pmap[reg_c(hw)]));
                        norig.append(self.rorig[i]);
                        i = i + 1;
                        continue;
                    }
                }
            }
            if self.is_target_op(op2) {
                w2 = reg_set_c(w2, pmap[reg_c(w2)]);
            }
            ncode.append(w2);
            norig.append(self.rorig[i]);
            i = i + 1;
        }
        self.rcode = ncode;
        self.rorig = norig;
        if self.fn.gen_prologue_end_ip > 0
            and self.fn.gen_prologue_end_ip < self.n
            and self.din[self.fn.gen_prologue_end_ip] >= 0 {
            self.reg_gen_start = pmap[self.rpc_of[self.fn.gen_prologue_end_ip]];
        }
        # The handler table, in final register pcs: for each reachable stack
        # instruction under a try, the register pc of its handler's entry.
        if self.htable {
            hi: int = 0;
            while hi < self.n {
                # An instruction inside a fused window was never visited by
                # the analysis: it is covered by its head's handler (the
                # window's register words name interior indices as orig).
                hj: int = hi;
                while hj > 0 and self.cover[hj] == 1 {
                    hj = hj - 1;
                }
                hh: int = self.hin[hj];
                if hh >= 0 and self.din[hj] >= 0 and self.fn.code[hh].arg < self.n {
                    self.rhandler.append(pmap[self.rpc_of[self.fn.code[hh].arg]]);
                } else {
                    self.rhandler.append(-1);
                }
                hi = hi + 1;
            }
        }
    }
}

# 1 reached by normal edges, 2 by handler edges

# labels reached with more than their depth
# Handler table: hin[i] = the PUSH_CATCH / PUSH_FINALLY active at i (-1
# none), hpar[p] = the one active at PUSH p (its parent); htable stays
# True while every join agrees and the function has no `with` / `using`.

# check_deep's visit stamps
"""True when `src` has an `eval` identifier token that could be a direct
eval: a call callee (`eval(` / `eval /*c*/ (`) that is not a member name
(`x.eval(`) — the compiler's `_aa_collect` rule."""
def _src_has_direct_eval(src: str) -> bool {
    sn: int = len(src);
    at: int = src.find("eval", 0);
    while at >= 0 {
        ok: bool = True;
        if at > 0 {
            pc: int = ord(src[at - 1]);
            if (pc >= 97 and pc <= 122)
                or (pc >= 65 and pc <= 90)
                or (pc >= 48 and pc <= 57)
                or pc == 95
                or pc == 36 {
                ok = False;
            }
        }
        if ok and at + 4 < sn {
            nc: int = ord(src[at + 4]);
            if (nc >= 97 and nc <= 122)
                or (nc >= 65 and nc <= 90)
                or (nc >= 48 and nc <= 57)
                or nc == 95
                or nc == 36 {
                ok = False;
            }
        }
        if ok {
            pj: int = at - 1;
            while pj >= 0
                and (
                    src[pj] == " "
                    or src[pj] == "\t"
                    or src[pj] == "\n"
                    or src[pj] == "\r"
                ) {
                pj = pj - 1;
            }
            if pj >= 0 and src[pj] == "." {
                ok = False;
            }
        }
        if ok {
            nj: int = at + 4;
            while nj < sn
                and (
                    src[nj] == " "
                    or src[nj] == "\t"
                    or src[nj] == "\n"
                    or src[nj] == "\r"
                ) {
                nj = nj + 1;
            }
            if nj >= sn or (src[nj] != "(" and src[nj] != "/") {
                ok = False;
            }
        }
        # The function's own name (`eval() {`, `get eval()`, `function eval(`).
        if ok and _src_eval_own_name(src, 0, at) {
            ok = False;
        }
        if ok {
            return True;
        }
        at = src.find("eval", at + 4);
    }
    return False;
}

"""Locals may be deferred on the symbolic stack only when nothing can write
them behind the translator's back: no mapped `arguments` object, no direct
eval and no name-resolved stores (`with`)."""
def _reg_defer_ok(fn: CompiledFunction) -> bool {
    if fn.arguments_slot >= 0 {
        return False;
    }
    if _src_has_direct_eval(fn.source) {
        return False;
    }
    i: int = 0;
    n: int = len(fn.code);
    while i < n {
        op: Opcode = fn.code[i].opcode;
        if op == Opcode.STORE_NAME
            or op == Opcode.STORE_NAME_REF
            or op == Opcode.LOAD_NAME
            or op == Opcode.LOAD_NAME_REF
            or op == Opcode.WITH_PUSH {
            return False;
        }
        if op == Opcode.LOAD_GLOBAL or op == Opcode.CALL {
            # A direct eval reaches this function's locals by name.
            if op == Opcode.LOAD_GLOBAL
                and fn.code[i].arg >= 0
                and fn.code[i].arg < len(fn.constants.values)
                and fn.constants.values[fn.code[i].arg] == "eval" {
                return False;
            }
        }
        i = i + 1;
    }
    return True;
}

"""Translate `fn` to the register ISA (idempotent; called lazily by the VM
the first time a function is about to run — a build loads far more
functions than it calls). Leaves risa == 2 and the stack code alone when
the function is a generator, async, or its stack shape cannot be
analyzed."""
def:pub reg_translate_fn(fn: CompiledFunction) -> None {
    if fn.risa != 0 {
        return;
    }
    if _REG_GATE == 0 {
        fn.risa = 2;
        return;
    }
    # Bound-function stubs (empty code, run via the bound target) and any
    # other runtime-made empty function stay on the stack path.
    if fn.is_bound or len(fn.code) == 0 {
        fn.risa = 2;
        return;
    }
    t: RegTranslator = RegTranslator(fn=fn);
    t.nl = fn.num_locals;
    t.defer_ok = _reg_defer_ok(fn);
    ok: bool = t.analyze();
    if ok {
        ok = t.emit_all();
    }
    if not ok {
        fn.risa = 2;
        if _REG_DEBUG == 1 {
            print("[regisa] " + fn.name + ": stack ISA (" + t.bail + ")");
        }
        return;
    }
    fn.rcode = t.rcode;
    fn.rorig = t.rorig;
    # A terminator past the last word (V4.25): the register loop does not
    # bound pc, so the code must never run off its end.
    fn.rcode.append(R_RETUNDEF);
    fn.rorig.append(len(fn.code) - 1);
    fn.rhandler = t.rhandler;
    fn.reg_gen_start = t.reg_gen_start;
    fn.reg_tmp_base = fn.num_locals;
    fn.num_locals = fn.num_locals + t.max_depth + 1;
    fn.risa = 1;
    if _REG_DEBUG == 1 {
        dmsg: str = "";
        if not t.defer_ok {
            dmsg = ", no deferral";
        }
        print(
            "[regisa] "
                + fn.name
                + ": "
                + str(len(fn.code))
                + " stack ops -> "
                + str(len(fn.rcode))
                + " words, "
                + str(t.max_depth)
                + " temps"
                + dmsg
        );
    }
}

# ── Disassembler ──────────────────────────────────────────────────────────

def _rname(op: int) -> str {
    if op == R_NOP {
        return "NOP";
    }
    if op == R_MOVE {
        return "MOVE";
    }
    if op == R_LOADK {
        return "LOADK";
    }
    if op == R_LOADI {
        return "LOADI";
    }
    if op == R_LOADIMM {
        return "LOADIMM";
    }
    if op == R_LOADTHIS {
        return "LOADTHIS";
    }
    if op == R_LOADSELF {
        return "LOADSELF";
    }
    if op == R_CHECKTDZ {
        return "CHECKTDZ";
    }
    if op == R_LOADGLOBAL {
        return "LOADGLOBAL";
    }
    if op == R_LOADFREE {
        return "LOADFREE";
    }
    if op == R_STOREFREE {
        return "STOREFREE";
    }
    if op == R_LOADDEREF {
        return "LOADDEREF";
    }
    if op == R_STOREDEREF {
        return "STOREDEREF";
    }
    if op == R_MAKECELL {
        return "MAKECELL";
    }
    if op == R_STORENEWCELL {
        return "STORENEWCELL";
    }
    if op == R_NEWOBJECT {
        return "NEWOBJECT";
    }
    if op == R_REQCOERCE {
        return "REQCOERCE";
    }
    if op == R_TOPROPKEY {
        return "TOPROPKEY";
    }
    if op == R_INC {
        return "INC";
    }
    if op == R_ADD {
        return "ADD";
    }
    if op == R_SUB {
        return "SUB";
    }
    if op == R_MUL {
        return "MUL";
    }
    if op == R_DIV {
        return "DIV";
    }
    if op == R_MOD {
        return "MOD";
    }
    if op == R_POW {
        return "POW";
    }
    if op == R_BAND {
        return "BAND";
    }
    if op == R_BOR {
        return "BOR";
    }
    if op == R_BXOR {
        return "BXOR";
    }
    if op == R_SHL {
        return "SHL";
    }
    if op == R_SHR {
        return "SHR";
    }
    if op == R_USHR {
        return "USHR";
    }
    if op == R_ADDI {
        return "ADDI";
    }
    if op == R_SUBI {
        return "SUBI";
    }
    if op == R_NEG {
        return "NEG";
    }
    if op == R_NOT {
        return "NOT";
    }
    if op == R_BNOT {
        return "BNOT";
    }
    if op == R_TYPEOF {
        return "TYPEOF";
    }
    if op == R_VOID {
        return "VOID";
    }
    if op == R_TONUM {
        return "TONUM";
    }
    if op == R_TOSTR {
        return "TOSTR";
    }
    if op == R_LT {
        return "LT";
    }
    if op == R_LTE {
        return "LTE";
    }
    if op == R_GT {
        return "GT";
    }
    if op == R_GTE {
        return "GTE";
    }
    if op == R_EQ {
        return "EQ";
    }
    if op == R_NEQ {
        return "NEQ";
    }
    if op == R_SEQ {
        return "SEQ";
    }
    if op == R_SNEQ {
        return "SNEQ";
    }
    if op == R_INSTANCEOF {
        return "INSTANCEOF";
    }
    if op == R_IN {
        return "IN";
    }
    if op == R_BLT {
        return "BLT";
    }
    if op == R_BNLT {
        return "BNLT";
    }
    if op == R_BLE {
        return "BLE";
    }
    if op == R_BNLE {
        return "BNLE";
    }
    if op == R_BGT {
        return "BGT";
    }
    if op == R_BNGT {
        return "BNGT";
    }
    if op == R_BGE {
        return "BGE";
    }
    if op == R_BNGE {
        return "BNGE";
    }
    if op == R_BEQ {
        return "BEQ";
    }
    if op == R_BNE {
        return "BNE";
    }
    if op == R_BSEQ {
        return "BSEQ";
    }
    if op == R_BSNE {
        return "BSNE";
    }
    if op == R_BTRUE {
        return "BTRUE";
    }
    if op == R_BFALSE {
        return "BFALSE";
    }
    if op == R_BNULL {
        return "BNULL";
    }
    if op == R_BUNDEF {
        return "BUNDEF";
    }
    if op == R_JMP {
        return "JMP";
    }
    if op == R_GETFIELD {
        return "GETFIELD";
    }
    if op == R_SETFIELD {
        return "SETFIELD";
    }
    if op == R_GETINDEX {
        return "GETINDEX";
    }
    if op == R_NEWARRAY {
        return "NEWARRAY";
    }
    if op == R_GETITER {
        return "GETITER";
    }
    if op == R_ITERNEXTVAL {
        return "ITERNEXTVAL";
    }
    if op == R_YIELD {
        return "YIELD";
    }
    if op == R_AWAIT {
        return "AWAIT";
    }
    if op == R_YIELDSTAR {
        return "YIELDSTAR";
    }
    if op == R_SETINDEX {
        return "SETINDEX";
    }
    if op == R_CALL {
        return "CALL";
    }
    if op == R_NEW {
        return "NEW";
    }
    if op == R_CALLM {
        return "CALLM";
    }
    if op == R_RETURN {
        return "RETURN";
    }
    if op == R_RETUNDEF {
        return "RETUNDEF";
    }
    if op == R_TAILCALL {
        return "TAILCALL";
    }
    if op == R_PUSHCATCH {
        return "PUSHCATCH";
    }
    if op == R_POPCATCH {
        return "POPCATCH";
    }
    if op == R_PUSHFINALLY {
        return "PUSHFINALLY";
    }
    if op == R_POPFINALLY {
        return "POPFINALLY";
    }
    if op == R_LANDING {
        return "LANDING";
    }
    if op == R_THROW {
        return "THROW";
    }
    if op == R_FINENTER {
        return "FINENTER";
    }
    if op == R_FINRETHROW {
        return "FINRETHROW";
    }
    if op == R_ITERNEXT {
        return "ITERNEXT";
    }
    if op == R_STK {
        return "STK";
    }
    return "?" + str(op);
}

def _rreg(fn: CompiledFunction, r: int) -> str {
    s: str = "";
    rr: int = r & REG_MASK;
    if rr >= fn.reg_tmp_base {
        s = "t" + str(rr - fn.reg_tmp_base);
    } else {
        s = "r" + str(rr);
    }
    if (r & REG_TDZ_FLAG) != 0 {
        s = s + "!";
    }
    return s;
}

"""Branch opcodes whose C is a register pc."""
def _is_branch(op: int) -> bool {
    return (op >= R_BLT and op <= R_JMP)
        or op == R_PUSHCATCH
        or op == R_PUSHFINALLY
        or op == R_ITERNEXT
        or op == R_INC;
}

"""Human-readable register code of `fn` (empty when risa != 1)."""
def:pub reg_disassemble(fn: CompiledFunction) -> str {
    if fn.risa != 1 {
        return "";
    }
    out: str = "  register code ("
        + str(fn.reg_tmp_base)
        + " locals, "
        + str(fn.num_locals - fn.reg_tmp_base)
        + " temps):\n";
    pc: int = 0;
    n: int = len(fn.rcode);
    while pc < n {
        w: int = fn.rcode[pc];
        op: int = reg_op(w);
        a: int = reg_a(w);
        b: int = reg_b(w);
        c: int = reg_c(w);
        off: str = str(pc);
        if pc < 10 {
            off = "   " + off;
        } elif pc < 100 {
            off = "  " + off;
        } elif pc < 1000 {
            off = " " + off;
        }
        line: str = off + "  " + _rname(op);
        if op == R_MOVE {
            line = line + " " + _rreg(fn, a) + ", " + _rreg(fn, b);
        } elif op == R_LOADK {
            line = line
                + " "
                + _rreg(fn, a)
                + ", k"
                + str(fn.code[c].arg)
                + " ("
                + fn.constants.values[fn.code[c].arg]
                + ")";
        } elif op == R_LOADI {
            line = line + " " + _rreg(fn, a) + ", #" + str(c - REG_IBIAS);
        } elif op == R_LOADIMM {
            line = line + " " + _rreg(fn, a) + ", imm" + str(b);
        } elif op == R_LOADTHIS
            or op == R_LOADSELF
            or op == R_NEWOBJECT
            or op == R_LANDING
            or op == R_LOADGLOBAL {
            line = line + " " + _rreg(fn, a);
        } elif op == R_CHECKTDZ or op == R_MAKECELL or op == R_FINRETHROW {
            line = line + " r" + str(a);
        } elif op == R_LOADFREE {
            line = line + " " + _rreg(fn, a) + ", free" + str(b);
        } elif op == R_STOREFREE {
            line = line + " free" + str(b) + ", " + _rreg(fn, a);
        } elif op == R_LOADDEREF {
            line = line + " " + _rreg(fn, a) + ", cell r" + str(b);
        } elif op == R_STOREDEREF or op == R_STORENEWCELL {
            line = line + " cell r" + str(b) + ", " + _rreg(fn, a);
        } elif op == R_REQCOERCE or op == R_RETURN or op == R_THROW {
            line = line + " " + _rreg(fn, a);
        } elif op == R_TOPROPKEY or (op >= R_NEG and op <= R_TOSTR) {
            line = line + " " + _rreg(fn, a) + ", " + _rreg(fn, b);
        } elif op == R_INC {
            line = line + " r" + str(a) + ", " + str(b - 1) + " -> " + str(c);
        } elif (op >= R_ADD and op <= R_USHR)
            or (op >= R_LT and op <= R_IN)
            or op == R_GETINDEX {
            line = line
                + " "
                + _rreg(fn, a)
                + ", "
                + _rreg(fn, b)
                + ", "
                + _rreg(fn, c);
        } elif op == R_ADDI or op == R_SUBI {
            line = line
                + " "
                + _rreg(fn, a)
                + ", "
                + _rreg(fn, b)
                + ", #"
                + str(c - REG_IBIAS);
        } elif op >= R_BLT and op <= R_BSNE {
            line = line + " " + _rreg(fn, a) + ", " + _rreg(fn, b) + " -> " + str(c);
        } elif op >= R_BTRUE and op <= R_BUNDEF {
            line = line + " " + _rreg(fn, a) + " -> " + str(c);
        } elif op == R_JMP or op == R_PUSHCATCH or op == R_PUSHFINALLY {
            line = line + " -> " + str(c);
        } elif op == R_GETFIELD {
            line = line
                + " "
                + _rreg(fn, a)
                + ", "
                + _rreg(fn, b)
                + ", "
                + fn.constants.values[fn.code[c].arg];
        } elif op == R_SETFIELD {
            line = line
                + " "
                + _rreg(fn, a)
                + ", "
                + fn.constants.values[fn.code[c].arg]
                + ", "
                + _rreg(fn, b);
        } elif op == R_SETINDEX {
            line = line
                + " "
                + _rreg(fn, a)
                + "["
                + _rreg(fn, b)
                + "], "
                + _rreg(fn, c);
        } elif op == R_NEWARRAY {
            line = line + " " + _rreg(fn, a) + ", n=" + str(b);
        } elif op == R_GETITER
            or op == R_ITERNEXTVAL
            or op == R_YIELD
            or op == R_AWAIT
            or op == R_YIELDSTAR {
            line = line + " " + _rreg(fn, a) + ", " + _rreg(fn, b);
        } elif op == R_CALL or op == R_CALLM or op == R_TAILCALL or op == R_NEW {
            line = line
                + " "
                + _rreg(fn, a)
                + ", "
                + _rreg(fn, b)
                + ", argc="
                + str(c)
                + " [";
            nw: int = c;
            if op == R_CALLM {
                nw = c + 1;
            }
            k: int = 0;
            while k < nw {
                if k > 0 {
                    line = line + ", ";
                }
                line = line + _rreg(fn, fn.rcode[pc + 1 + k]);
                k = k + 1;
            }
            line = line + "]";
            pc = pc + nw;
        } elif op == R_FINENTER {
            line = line + " r" + str(a) + ", " + _rreg(fn, b);
        } elif op == R_ITERNEXT {
            line = line + " " + _rreg(fn, a) + ", " + _rreg(fn, b) + " -> " + str(c);
        } elif op == R_STK {
            line = line
                + " "
                + _opname(fn.code[c].opcode)
                + " base="
                + _rreg(fn, a)
                + " pop="
                + str(b & 4095)
                + " push="
                + str(b >> 12);
            if fn.code[c].arg != 0 {
                line = line + " arg=" + str(fn.code[c].arg);
            }
        }
        ln: int = fn.code[fn.rorig[pc]].line;
        if ln != 0 {
            line = line + "    ; line " + str(ln);
        }
        out = out + line + "\n";
        pc = pc + 1;
    }
    return out;
}

"""True when the `eval` token at `at` in `src` is a definition's own name:
walking back to `start`, only spaces, `*` and the keywords function / async
/ static / get / set come before it (`eval() {`, `get eval()`,
`function* eval(`) — a definition, never a call."""
def _src_eval_own_name(src: str, start: int, at: int) -> bool {
    i: int = at - 1;
    while i >= start {
        ch: str = src[i];
        if ch == " " or ch == "\t" or ch == "\n" or ch == "\r" or ch == "*" {
            i = i - 1;
        } else {
            we: int = i;
            while i >= start
                and (
                    (src[i] >= "a" and src[i] <= "z")
                    or (src[i] >= "A" and src[i] <= "Z")
                ) {
                i = i - 1;
            }
            wl: int = we - i;
            if wl == 0 {
                return False;
            }
            if not (
                _src_word_at(src, i + 1, wl, "function")
                or _src_word_at(src, i + 1, wl, "async")
                or _src_word_at(src, i + 1, wl, "static")
                or _src_word_at(src, i + 1, wl, "get")
                or _src_word_at(src, i + 1, wl, "set")
            ) {
                return False;
            }
        }
    }
    return True;
}

def _src_word_at(src: str, pos: int, wl: int, word: str) -> bool {
    if wl != len(word) {
        return False;
    }
    j: int = 0;
    while j < wl {
        if src[pos + j] != word[j] {
            return False;
        }
        j = j + 1;
    }
    return True;
}
