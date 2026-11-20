#if defined(__wasilibc_printscan_no_floating_point)

#include <stdio.h>

__attribute__((__cold__, __noreturn__))
static void floating_point_not_supported(void) {
    void abort(void) __attribute__((__noreturn__));
    fputs("Support for floating-point formatting is currently disabled.\n"
          "To enable it, " __wasilibc_printscan_floating_point_support_option ".\n", stderr);
    abort();
}

#elif defined(__wasilibc_printscan_no_long_double)

#include <stdio.h>

typedef double long_double;
#undef LDBL_TRUE_MIN
#define LDBL_TRUE_MIN DBL_DENORM_MIN
#undef LDBL_MIN
#define LDBL_MIN DBL_MIN
#undef LDBL_MAX
#define LDBL_MAX DBL_MAX
#undef LDBL_EPSILON
#define LDBL_EPSILON DBL_EPSILON
#undef LDBL_MANT_DIG
#define LDBL_MANT_DIG DBL_MANT_DIG
#undef LDBL_MIN_EXP
#define LDBL_MIN_EXP DBL_MIN_EXP
#undef LDBL_MAX_EXP
#define LDBL_MAX_EXP DBL_MAX_EXP
#undef LDBL_DIG
#define LDBL_DIG DBL_DIG
#undef LDBL_MIN_10_EXP
#define LDBL_MIN_10_EXP DBL_MIN_10_EXP
#undef LDBL_MAX_10_EXP
#define LDBL_MAX_10_EXP DBL_MAX_10_EXP
#undef frexpl
#define frexpl(x, exp) frexp(x, exp)
#undef copysignl
#define copysignl(x, y) copysign(x, y)
#undef fmodl
#define fmodl(x, y) fmod(x, y)
#undef scalbnl
#define scalbnl(arg, exp) scalbn(arg, exp)
/* jac wasm_rt transform: upstream misses this one, and an unmapped fabsl
 * drags f128 compiler-rt (__extenddftf2/__getf2) into every module. */
#undef fabsl
#define fabsl(x) fabs(x)
/* jac wasm_rt transform: the upstream diagnostic goes through
 * fputs(&__stderr_FILE), which would drag musl's FILE machinery into every
 * module via vfprintf's %L handling. Emit it with a bare write(2) instead —
 * write/abort are part of the jac_host1 ABI. */
__attribute__((__cold__, __noreturn__))
static void long_double_not_supported(void) {
    void abort(void) __attribute__((__noreturn__));
    extern int write(int, const void *, unsigned long);
    static const char msg[] =
        "Support for formatting long double values is currently disabled.\n"
        "To enable it, " __wasilibc_printscan_full_support_option ".\n";
    write(2, msg, sizeof(msg) - 1);
    abort();
}

#else

// Full long double support.
typedef long double long_double;

#endif
