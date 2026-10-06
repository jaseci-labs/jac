"""The libmpdec operations the _decimal methods apply, by operation code.

Modules/_decimal/_decimal.c generates one Decimal method and one Context
method per libmpdec function from a family of macros (Dec_UnaryFuncVA,
DecCtx_BinaryFunc, ...). The Jac port writes each family once and names the
libmpdec function it applies with one of the operation codes here, so the
families dispatch to the same quiet (`mpd_q*`) functions with the same
arguments. See ../LICENSE.cpython.
"""
import from jaclang.runtime.python.modules.mpdecimal {
    mpd_compare_total,
    mpd_compare_total_mag,
    mpd_context_t,
    mpd_iscanonical,
    mpd_isfinite,
    mpd_isinfinite,
    mpd_isnan,
    mpd_isnormal,
    mpd_isqnan,
    mpd_issigned,
    mpd_issnan,
    mpd_issubnormal,
    mpd_iszero,
    mpd_qabs,
    mpd_qadd,
    mpd_qand,
    mpd_qcompare,
    mpd_qcompare_signal,
    mpd_qdiv,
    mpd_qdivint,
    mpd_qexp,
    mpd_qfma,
    mpd_qinvert,
    mpd_qln,
    mpd_qlog10,
    mpd_qlogb,
    mpd_qmax,
    mpd_qmax_mag,
    mpd_qmin,
    mpd_qmin_mag,
    mpd_qminus,
    mpd_qmul,
    mpd_qnext_minus,
    mpd_qnext_plus,
    mpd_qnext_toward,
    mpd_qor,
    mpd_qplus,
    mpd_qpow,
    mpd_qquantize,
    mpd_qreduce,
    mpd_qrem,
    mpd_qrem_near,
    mpd_qrotate,
    mpd_qround_to_int,
    mpd_qround_to_intx,
    mpd_qscaleb,
    mpd_qshift,
    mpd_qsqrt,
    mpd_qsub,
    mpd_qxor,
    mpd_t
}

# Unary operations: result = f(a) in a context.
glob OP_ABS: Final[int] = 0,
     OP_MINUS: Final[int] = 1,
     OP_PLUS: Final[int] = 2,
     OP_EXP: Final[int] = 3,
     OP_LN: Final[int] = 4,
     OP_LOG10: Final[int] = 5,
     OP_NEXT_MINUS: Final[int] = 6,
     OP_NEXT_PLUS: Final[int] = 7,
     OP_REDUCE: Final[int] = 8,
     OP_SQRT: Final[int] = 9,
     OP_INVERT: Final[int] = 10,
     OP_LOGB: Final[int] = 11,
     OP_ROUND_TO_INT: Final[int] = 12,
     OP_ROUND_TO_INTX: Final[int] = 13;

# Binary operations: result = f(a, b) in a context.
glob OP_ADD: Final[int] = 0,
     OP_SUB: Final[int] = 1,
     OP_MUL: Final[int] = 2,
     OP_DIV: Final[int] = 3,
     OP_DIVINT: Final[int] = 4,
     OP_REM: Final[int] = 5,
     OP_REM_NEAR: Final[int] = 6,
     OP_COMPARE: Final[int] = 7,
     OP_COMPARE_SIGNAL: Final[int] = 8,
     OP_MAX: Final[int] = 9,
     OP_MAX_MAG: Final[int] = 10,
     OP_MIN: Final[int] = 11,
     OP_MIN_MAG: Final[int] = 12,
     OP_NEXT_TOWARD: Final[int] = 13,
     OP_QUANTIZE: Final[int] = 14,
     OP_AND: Final[int] = 15,
     OP_OR: Final[int] = 16,
     OP_XOR: Final[int] = 17,
     OP_ROTATE: Final[int] = 18,
     OP_SCALEB: Final[int] = 19,
     OP_SHIFT: Final[int] = 20,
     OP_POW: Final[int] = 21;

# Binary operations without a context (the total orderings).
glob OP_COMPARE_TOTAL: Final[int] = 0,
     OP_COMPARE_TOTAL_MAG: Final[int] = 1;

# Predicates; the last two take a context.
glob OP_IS_CANONICAL: Final[int] = 0,
     OP_IS_FINITE: Final[int] = 1,
     OP_IS_INFINITE: Final[int] = 2,
     OP_IS_NAN: Final[int] = 3,
     OP_IS_QNAN: Final[int] = 4,
     OP_IS_SNAN: Final[int] = 5,
     OP_IS_SIGNED: Final[int] = 6,
     OP_IS_ZERO: Final[int] = 7,
     OP_IS_NORMAL: Final[int] = 8,
     OP_IS_SUBNORMAL: Final[int] = 9;

"""Apply unary operation `op`; the status flags it raised."""
def unary_op(
    op: int, result: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t]
) -> u32 {
    status: u32 = 0;
    if op == OP_ABS {
        mpd_qabs(result, a, ctx, &mut status);
    } elif op == OP_MINUS {
        mpd_qminus(result, a, ctx, &mut status);
    } elif op == OP_PLUS {
        mpd_qplus(result, a, ctx, &mut status);
    } elif op == OP_EXP {
        mpd_qexp(result, a, ctx, &mut status);
    } elif op == OP_LN {
        mpd_qln(result, a, ctx, &mut status);
    } elif op == OP_LOG10 {
        mpd_qlog10(result, a, ctx, &mut status);
    } elif op == OP_NEXT_MINUS {
        mpd_qnext_minus(result, a, ctx, &mut status);
    } elif op == OP_NEXT_PLUS {
        mpd_qnext_plus(result, a, ctx, &mut status);
    } elif op == OP_REDUCE {
        mpd_qreduce(result, a, ctx, &mut status);
    } elif op == OP_SQRT {
        mpd_qsqrt(result, a, ctx, &mut status);
    } elif op == OP_INVERT {
        mpd_qinvert(result, a, ctx, &mut status);
    } elif op == OP_LOGB {
        mpd_qlogb(result, a, ctx, &mut status);
    } elif op == OP_ROUND_TO_INT {
        mpd_qround_to_int(result, a, ctx, &mut status);
    } else {
        mpd_qround_to_intx(result, a, ctx, &mut status);
    }
    return status;
}

"""Apply binary operation `op`; the status flags it raised."""
def binary_op(
    op: int, result: ptr[mpd_t], a: ptr[mpd_t], b: ptr[mpd_t], ctx: ptr[mpd_context_t]
) -> u32 {
    status: u32 = 0;
    if op == OP_ADD {
        mpd_qadd(result, a, b, ctx, &mut status);
    } elif op == OP_SUB {
        mpd_qsub(result, a, b, ctx, &mut status);
    } elif op == OP_MUL {
        mpd_qmul(result, a, b, ctx, &mut status);
    } elif op == OP_DIV {
        mpd_qdiv(result, a, b, ctx, &mut status);
    } elif op == OP_DIVINT {
        mpd_qdivint(result, a, b, ctx, &mut status);
    } elif op == OP_REM {
        mpd_qrem(result, a, b, ctx, &mut status);
    } elif op == OP_REM_NEAR {
        mpd_qrem_near(result, a, b, ctx, &mut status);
    } elif op == OP_COMPARE {
        mpd_qcompare(result, a, b, ctx, &mut status);
    } elif op == OP_COMPARE_SIGNAL {
        mpd_qcompare_signal(result, a, b, ctx, &mut status);
    } elif op == OP_MAX {
        mpd_qmax(result, a, b, ctx, &mut status);
    } elif op == OP_MAX_MAG {
        mpd_qmax_mag(result, a, b, ctx, &mut status);
    } elif op == OP_MIN {
        mpd_qmin(result, a, b, ctx, &mut status);
    } elif op == OP_MIN_MAG {
        mpd_qmin_mag(result, a, b, ctx, &mut status);
    } elif op == OP_NEXT_TOWARD {
        mpd_qnext_toward(result, a, b, ctx, &mut status);
    } elif op == OP_QUANTIZE {
        mpd_qquantize(result, a, b, ctx, &mut status);
    } elif op == OP_AND {
        mpd_qand(result, a, b, ctx, &mut status);
    } elif op == OP_OR {
        mpd_qor(result, a, b, ctx, &mut status);
    } elif op == OP_XOR {
        mpd_qxor(result, a, b, ctx, &mut status);
    } elif op == OP_ROTATE {
        mpd_qrotate(result, a, b, ctx, &mut status);
    } elif op == OP_SCALEB {
        mpd_qscaleb(result, a, b, ctx, &mut status);
    } elif op == OP_SHIFT {
        mpd_qshift(result, a, b, ctx, &mut status);
    } else {
        mpd_qpow(result, a, b, ctx, &mut status);
    }
    return status;
}

"""fma(a, b, c) in a context; the status flags it raised."""
def fma_op(
    result: ptr[mpd_t],
    a: ptr[mpd_t],
    b: ptr[mpd_t],
    c: ptr[mpd_t],
    ctx: ptr[mpd_context_t]
) -> u32 {
    status: u32 = 0;
    mpd_qfma(result, a, b, c, ctx, &mut status);
    return status;
}

"""Apply a total ordering; they raise no flags."""
def total_op(op: int, result: ptr[mpd_t], a: ptr[mpd_t], b: ptr[mpd_t]) {
    if op == OP_COMPARE_TOTAL {
        mpd_compare_total(result, a, b);
    } else {
        mpd_compare_total_mag(result, a, b);
    }
}

"""Apply predicate `op` (is_normal and is_subnormal read the context)."""
def bool_op(op: int, a: ptr[mpd_t], ctx: ptr[mpd_context_t]) -> bool {
    if op == OP_IS_CANONICAL {
        return mpd_iscanonical(a) != 0;
    } elif op == OP_IS_FINITE {
        return mpd_isfinite(a) != 0;
    } elif op == OP_IS_INFINITE {
        return mpd_isinfinite(a) != 0;
    } elif op == OP_IS_NAN {
        return mpd_isnan(a) != 0;
    } elif op == OP_IS_QNAN {
        return mpd_isqnan(a) != 0;
    } elif op == OP_IS_SNAN {
        return mpd_issnan(a) != 0;
    } elif op == OP_IS_SIGNED {
        return mpd_issigned(a) != 0;
    } elif op == OP_IS_ZERO {
        return mpd_iszero(a) != 0;
    } elif op == OP_IS_NORMAL {
        return mpd_isnormal(a, ctx) != 0;
    }
    return mpd_issubnormal(a, ctx) != 0;
}
