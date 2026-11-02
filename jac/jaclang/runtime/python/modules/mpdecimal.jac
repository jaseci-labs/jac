"""The libmpdec interface of the _decimal module.

Modules/_decimal/_decimal.c wraps libmpdec, which stays a C library: the build
links the mpdecimal 4.0.1 archive (`-lmpdec`). This module declares the
records, allocator hooks, functions and constants of mpdecimal.h that
_decimal uses. Every supported target is a 64-bit build, where mpdecimal.h
selects MPD_CONFIG_64: mpd_ssize_t is int64_t, mpd_uint_t is uint64_t and the
limits below are that configuration's. See ../LICENSE.cpython.
"""

import from mpdec {
    # mpd_t: a decimal number. `data` holds `len` words of `alloc` in radix
    # 10**19, least significant first.
    obj mpd_t {
        has flags: u8 = 0,
            exp: i64 = 0,
            digits: i64 = 0,
            len: i64 = 0,
            alloc: i64 = 0,
            data: ptr[u64] = ptr[u64]();
    }
    # mpd_context_t: precision, exponent limits, traps, status and rounding.
    obj mpd_context_t {
        has prec: i64 = 0,
            emax: i64 = 0,
            emin: i64 = 0,
            traps: u32 = 0,
            status: u32 = 0,
            newtrap: u32 = 0,
            round: i32 = 0,
            clamp: i32 = 0,
            allcr: i32 = 0;
    }
    # mpd_spec_t: a parsed format specification; `fill` is char[5].
    obj mpd_spec_t {
        has min_width: i64 = 0,
            prec: i64 = 0,
            type: u8 = 0,
            align: u8 = 0,
            sign: u8 = 0,
            sign_coerce: u8 = 0,
            fill_0: u8 = 0,
            fill_1: u8 = 0,
            fill_2: u8 = 0,
            fill_3: u8 = 0,
            fill_4: u8 = 0,
            dot: ptr[u8] = ptr[u8](),
            sep: ptr[u8] = ptr[u8](),
            grouping: ptr[u8] = ptr[u8]();
    }
    # The allocator and trap handler hooks libmpdec calls through.
    glob mpd_mallocfunc: ptr,
         mpd_callocfunc: ptr,
         mpd_reallocfunc: ptr,
         mpd_free: ptr,
         mpd_traphandler: ptr,
         mpd_round_string: list[ptr[u8]]; def mpd_callocfunc_em(
        nmemb: u64, size: u64
    ) -> ptr;  def mpd_setminalloc(n: i64);  def mpd_version -> ptr[u8];
    # Context.
    def mpd_maxcontext(ctx: ptr[mpd_context_t]);  def mpd_ieee_context(
        ctx: ptr[mpd_context_t], bits: i32
    ) -> i32;  def mpd_getprec(ctx: ptr[mpd_context_t]) -> i64;  def mpd_getemax(
        ctx: ptr[mpd_context_t]
    ) -> i64;  def mpd_getemin(ctx: ptr[mpd_context_t]) -> i64;  def mpd_getround(
        ctx: ptr[mpd_context_t]
    ) -> i32;  def mpd_getclamp(ctx: ptr[mpd_context_t]) -> i32;  def mpd_getcr(
        ctx: ptr[mpd_context_t]
    ) -> i32;  def mpd_etiny(ctx: ptr[mpd_context_t]) -> i64;  def mpd_etop(
        ctx: ptr[mpd_context_t]
    ) -> i64;  def mpd_qsetprec(ctx: ptr[mpd_context_t], prec: i64) -> i32;  def mpd_qsetemax(
        ctx: ptr[mpd_context_t], emax: i64
    ) -> i32;  def mpd_qsetemin(ctx: ptr[mpd_context_t], emin: i64) -> i32;  def mpd_qsetround(
        ctx: ptr[mpd_context_t], newround: i32
    ) -> i32;  def mpd_qsettraps(ctx: ptr[mpd_context_t], flags: u32) -> i32;  def mpd_qsetstatus(
        ctx: ptr[mpd_context_t], flags: u32
    ) -> i32;  def mpd_qsetclamp(ctx: ptr[mpd_context_t], c: i32) -> i32;  def mpd_lsnprint_signals(
        dest: ptr[u8], nmemb: i32, flags: u32, signal_string: ptr[ptr[u8]]
    ) -> i32;
    # Allocation and assignment.
    def mpd_qnew -> ptr[mpd_t];  def mpd_del(dec: ptr[mpd_t]);  def mpd_qncopy(
        a: ptr[mpd_t]
    ) -> ptr[mpd_t];  def mpd_qcopy(
        result: ptr[mpd_t], a: ptr[mpd_t], status: &mut u32
    ) -> i32;  def mpd_qcopy_abs(
        result: ptr[mpd_t], a: ptr[mpd_t], status: &mut u32
    ) -> i32;  def mpd_qcopy_negate(
        result: ptr[mpd_t], a: ptr[mpd_t], status: &mut u32
    ) -> i32;  def mpd_qcopy_sign(
        result: ptr[mpd_t], a: ptr[mpd_t], b: ptr[mpd_t], status: &mut u32
    ) -> i32;  def mpd_qset_string(
        dec: ptr[mpd_t], s: ptr[u8], ctx: ptr[mpd_context_t], status: &mut u32
    );  def mpd_qset_ssize(
        result: ptr[mpd_t], a: i64, ctx: ptr[mpd_context_t], status: &mut u32
    );  def mpd_qset_i64(
        result: ptr[mpd_t], a: i64, ctx: ptr[mpd_context_t], status: &mut u32
    );  def mpd_qset_uint(
        result: ptr[mpd_t], a: u64, ctx: ptr[mpd_context_t], status: &mut u32
    );  def mpd_qsset_ssize(
        result: ptr[mpd_t], a: i64, ctx: ptr[mpd_context_t], status: &mut u32
    );  def mpd_qimport_u32(
        result: ptr[mpd_t],
        srcdata: ptr[u32],
        srclen: u64,
        srcsign: u8,
        srcbase: u32,
        ctx: ptr[mpd_context_t],
        status: &mut u32
    );  def mpd_qimport_u16(
        result: ptr[mpd_t],
        srcdata: ptr[u16],
        srclen: u64,
        srcsign: u8,
        srcbase: u32,
        ctx: ptr[mpd_context_t],
        status: &mut u32
    );  def mpd_qexport_u32(
        rdata: &mut ptr[u32], rlen: u64, base: u32, src: ptr[mpd_t], status: &mut u32
    ) -> u64;  def mpd_qexport_u16(
        rdata: &mut ptr[u16], rlen: u64, base: u32, src: ptr[mpd_t], status: &mut u32
    ) -> u64;  def mpd_qget_i64(dec: ptr[mpd_t], status: &mut u32) -> i64;  def mpd_qget_ssize(
        dec: ptr[mpd_t], status: &mut u32
    ) -> i64;  def mpd_seterror(result: ptr[mpd_t], flags: u32, status: &mut u32);  def mpd_setspecial(
        result: ptr[mpd_t], sign: u8, type: u8
    );  def mpd_set_flags(result: ptr[mpd_t], flags: u8);  def mpd_set_sign(
        result: ptr[mpd_t], sign: u8
    );  def mpd_set_positive(result: ptr[mpd_t]);  def mpd_clear_flags(
        result: ptr[mpd_t]
    );  def mpd_setdigits(result: ptr[mpd_t]);  def mpd_qfinalize(
        result: ptr[mpd_t], ctx: ptr[mpd_context_t], status: &mut u32
    );
    # Predicates and properties.
    def mpd_isnan(dec: ptr[mpd_t]) -> i32;  def mpd_issnan(dec: ptr[mpd_t]) -> i32;  def mpd_isqnan(
        dec: ptr[mpd_t]
    ) -> i32;  def mpd_isinfinite(dec: ptr[mpd_t]) -> i32;  def mpd_isfinite(
        dec: ptr[mpd_t]
    ) -> i32;  def mpd_isspecial(dec: ptr[mpd_t]) -> i32;  def mpd_iszero(
        dec: ptr[mpd_t]
    ) -> i32;  def mpd_issigned(dec: ptr[mpd_t]) -> i32;  def mpd_isnegative(
        dec: ptr[mpd_t]
    ) -> i32;  def mpd_ispositive(dec: ptr[mpd_t]) -> i32;  def mpd_iscanonical(
        dec: ptr[mpd_t]
    ) -> i32;  def mpd_isdynamic_data(dec: ptr[mpd_t]) -> i32;  def mpd_isnormal(
        dec: ptr[mpd_t], ctx: ptr[mpd_context_t]
    ) -> i32;  def mpd_issubnormal(dec: ptr[mpd_t], ctx: ptr[mpd_context_t]) -> i32;  def mpd_sign(
        dec: ptr[mpd_t]
    ) -> u8;  def mpd_arith_sign(dec: ptr[mpd_t]) -> i32;  def mpd_adjexp(
        dec: ptr[mpd_t]
    ) -> i64;  def mpd_class(a: ptr[mpd_t], ctx: ptr[mpd_context_t]) -> ptr[u8];  def mpd_same_quantum(
        a: ptr[mpd_t], b: ptr[mpd_t]
    ) -> i32;  def mpd_qcmp(a: ptr[mpd_t], b: ptr[mpd_t], status: &mut u32) -> i32;
    # Arithmetic.
    def mpd_qabs(r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32);  def mpd_qminus(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qplus(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qexp(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qln(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qlog10(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qnext_minus(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qnext_plus(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qreduce(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qsqrt(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qinvert(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qlogb(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qround_to_int(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qround_to_intx(
        r: ptr[mpd_t], a: ptr[mpd_t], ctx: ptr[mpd_context_t], s: &mut u32
    );  def mpd_qadd(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qsub(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qmul(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qdiv(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qdivint(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qrem(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qrem_near(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qcompare(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    ) -> i32;  def mpd_qcompare_signal(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    ) -> i32;  def mpd_qmax(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qmax_mag(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qmin(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qmin_mag(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qnext_toward(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qquantize(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qand(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qor(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qxor(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qrotate(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qscaleb(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qshift(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qpow(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qdivmod(
        q: ptr[mpd_t],
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qfma(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        c: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_qpowmod(
        r: ptr[mpd_t],
        a: ptr[mpd_t],
        b: ptr[mpd_t],
        c: ptr[mpd_t],
        ctx: ptr[mpd_context_t],
        s: &mut u32
    );  def mpd_compare_total(r: ptr[mpd_t], a: ptr[mpd_t], b: ptr[mpd_t]) -> i32;  def mpd_compare_total_mag(
        r: ptr[mpd_t], a: ptr[mpd_t], b: ptr[mpd_t]
    ) -> i32;
    # Conversion to strings.
    def mpd_to_sci(dec: ptr[mpd_t], fmt: i32) -> ptr[u8];  def mpd_to_sci_size(
        res: &mut ptr[u8], dec: ptr[mpd_t], fmt: i32
    ) -> i64;  def mpd_to_eng_size(
        res: &mut ptr[u8], dec: ptr[mpd_t], fmt: i32
    ) -> i64;  def mpd_parse_fmt_str(
        spec: &mut mpd_spec_t, fmt: ptr[u8], caps: i32
    ) -> i32;  def mpd_validate_lconv(spec: &mut mpd_spec_t) -> i32;  def mpd_qformat_spec(
        dec: ptr[mpd_t], spec: &mpd_spec_t, ctx: ptr[mpd_context_t], status: &mut u32
    ) -> ptr[u8];
}

# mpd_t flags.
glob MPD_POS: Final[u8] = 0,
     MPD_NEG: Final[u8] = 1,
     MPD_INF: Final[u8] = 2,
     MPD_NAN: Final[u8] = 4,
     MPD_SNAN: Final[u8] = 8,
     MPD_STATIC: Final[u8] = 16,
     MPD_STATIC_DATA: Final[u8] = 32,
     MPD_SHARED_DATA: Final[u8] = 64,
     MPD_CONST_DATA: Final[u8] = 128;

# Status flags.
glob MPD_Clamped: Final[u32] = 0x00000001,
     MPD_Conversion_syntax: Final[u32] = 0x00000002,
     MPD_Division_by_zero: Final[u32] = 0x00000004,
     MPD_Division_impossible: Final[u32] = 0x00000008,
     MPD_Division_undefined: Final[u32] = 0x00000010,
     MPD_Fpu_error: Final[u32] = 0x00000020,
     MPD_Inexact: Final[u32] = 0x00000040,
     MPD_Invalid_context: Final[u32] = 0x00000080,
     MPD_Invalid_operation: Final[u32] = 0x00000100,
     MPD_Malloc_error: Final[u32] = 0x00000200,
     MPD_Not_implemented: Final[u32] = 0x00000400,
     MPD_Overflow: Final[u32] = 0x00000800,
     MPD_Rounded: Final[u32] = 0x00001000,
     MPD_Subnormal: Final[u32] = 0x00002000,
     MPD_Underflow: Final[u32] = 0x00004000,
     MPD_Max_status: Final[u32] = 0x00007FFF,
     # Conditions that result in an IEEE 754 exception.
     MPD_IEEE_Invalid_operation: Final[u32] = 0x000003BA,
     # Errors that require the result of an operation to be set to NaN.
     MPD_Errors: Final[u32] = 0x000003BE,
     # Default traps.
     MPD_Traps: Final[u32] = 0x00004BBE;

# Rounding modes.
glob MPD_ROUND_UP: Final[i32] = 0,
     MPD_ROUND_DOWN: Final[i32] = 1,
     MPD_ROUND_CEILING: Final[i32] = 2,
     MPD_ROUND_FLOOR: Final[i32] = 3,
     MPD_ROUND_HALF_UP: Final[i32] = 4,
     MPD_ROUND_HALF_DOWN: Final[i32] = 5,
     MPD_ROUND_HALF_EVEN: Final[i32] = 6,
     MPD_ROUND_05UP: Final[i32] = 7,
     MPD_ROUND_TRUNC: Final[i32] = 8,
     MPD_ROUND_GUARD: Final[i32] = 9;

# The MPD_CONFIG_64 limits.
glob MPD_MAX_PREC: Final[i64] = 999999999999999999,
     MPD_MAX_EMAX: Final[i64] = 999999999999999999,
     MPD_MIN_EMIN: Final[i64] = -999999999999999999,
     MPD_MIN_ETINY: Final[i64] = -1999999999999999997,
     MPD_SSIZE_MAX: Final[i64] = 9223372036854775807,
     MPD_SSIZE_MIN: Final[i64] = -9223372036854775808,
     MPD_EXPDIGITS: Final[int] = 19,
     MPD_IEEE_CONTEXT_MAX_BITS: Final[int] = 512,
     MPD_NUM_FLAGS: Final[int] = 15,
     MPD_MAX_SIGNAL_LIST: Final[int] = 121,
     # sizeof(mpd_context_t) and sizeof(mpd_uint_t).
     MPD_CONTEXT_SIZE: Final[int] = 48,
     MPD_UINT_SIZE: Final[int] = 8;

import from c {
    # A call through a `void (*)(void *)` hook.
    obj FreeHook {
        has call: Callable[[ptr], None] = 0;
    }
}

"""mpd_free(p): release memory libmpdec allocated, through its hook."""
def mpd_free_memory(address: ptr) {
    hook = FreeHook();
    hook.call = int(mpd_free);
    hook.call(address);
}
