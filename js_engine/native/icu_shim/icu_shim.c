/*
 * icu_shim.c — Thin UTF-8 ICU wrapper for js_engine Intl.
 *
 * Links against -licuuc -licui18n -licudata.  Exports only icu_* via icu.ver.
 */

#include "icu_shim.h"

#include <limits.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#include <unicode/uloc.h>
#include <unicode/unum.h>
#include <unicode/udat.h>
#include <unicode/udatpg.h>
#include <unicode/upluralrules.h>
#include <unicode/ucol.h>
#include <unicode/ucal.h>
#include <unicode/unumsys.h>
#include <unicode/uldnames.h>
#include <unicode/ulistformatter.h>
#include <unicode/ureldatefmt.h>
#include <unicode/ubrk.h>
#include <unicode/ustring.h>
#include <unicode/ucnv.h>
#include <unicode/unorm2.h>
#include <unicode/uenum.h>
#include <unicode/ufieldpositer.h>
#include <unicode/udateintervalformat.h>
#include <unicode/unumberformatter.h>
#include <unicode/unumberrangeformatter.h>
#include <unicode/uformattedvalue.h>

#define ICU_UCHAR_BUF 512
#define ICU_UTF8_TMP  2048
#define ICU_MAX_LIST  64

/* ── UTF helpers ──────────────────────────────────────────────────────────── */

static int utf8_to_uchar(const char *src, UChar *dst, int32_t dst_cap, int32_t *out_len) {
    UErrorCode st = U_ZERO_ERROR;
    int32_t len = 0;
    if (!src) src = "";
    u_strFromUTF8(dst, dst_cap, &len, src, -1, &st);
    if (U_FAILURE(st) && st != U_BUFFER_OVERFLOW_ERROR) return -1;
    if (out_len) *out_len = len;
    if (st == U_BUFFER_OVERFLOW_ERROR || len >= dst_cap) return -1;
    return 0;
}

static int uchar_to_utf8(const UChar *src, int32_t src_len, char *dst, int dst_cap) {
    UErrorCode st = U_ZERO_ERROR;
    int32_t len = 0;
    if (!dst || dst_cap <= 0) return -1;
    u_strToUTF8(dst, dst_cap, &len, src, src_len, &st);
    if (U_FAILURE(st)) {
        dst[0] = '\0';
        return -1;
    }
    if (len >= dst_cap) len = dst_cap - 1;
    dst[len] = '\0';
    return 0;
}

static int write_utf8(char *out, int out_cap, const char *src) {
    if (!out || out_cap <= 0) return -1;
    if (!src) src = "";
    size_t n = strlen(src);
    if ((int)n >= out_cap) return -1;
    memcpy(out, src, n + 1);
    return 0;
}

/* Convert ICU locale underscore form to BCP-47 dash form in-place-ish. */
static void locale_to_bcp47(char *s) {
    for (char *p = s; *p; p++) {
        if (*p == '_') *p = '-';
    }
}

static UDateFormatStyle parse_date_style(const char *s) {
    if (!s || !s[0] || strcmp(s, "none") == 0) return UDAT_NONE;
    if (strcmp(s, "full") == 0) return UDAT_FULL;
    if (strcmp(s, "long") == 0) return UDAT_LONG;
    if (strcmp(s, "medium") == 0) return UDAT_MEDIUM;
    if (strcmp(s, "short") == 0) return UDAT_SHORT;
    return UDAT_DEFAULT;
}

static UNumberFormatStyle parse_number_style(const char *style, char *currency_out, int cur_cap) {
    if (currency_out && cur_cap > 0) currency_out[0] = '\0';
    if (!style || !style[0] || strcmp(style, "decimal") == 0) return UNUM_DECIMAL;
    if (strcmp(style, "percent") == 0) return UNUM_PERCENT;
    if (strcmp(style, "scientific") == 0) return UNUM_SCIENTIFIC;
    if (strncmp(style, "currency", 8) == 0) {
        if (style[8] == ':' && currency_out && cur_cap > 1) {
            /* Stop at ';' option separators from JS style encoding. */
            const char *src = style + 9;
            const char *semi = strchr(src, ';');
            size_t n = semi ? (size_t)(semi - src) : strlen(src);
            if (n >= (size_t)cur_cap) n = (size_t)cur_cap - 1;
            memcpy(currency_out, src, n);
            currency_out[n] = '\0';
        }
        return UNUM_CURRENCY;
    }
    return UNUM_DECIMAL;
}

/* Encode NF options from JS: "currency:USD;notation=compact;maximumFractionDigits=0" */
static int build_number_skeleton(const char *style, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    out[0] = '\0';
    if (!style) style = "decimal";

    char base[64];
    const char *opts = strchr(style, ';');
    size_t blen = opts ? (size_t)(opts - style) : strlen(style);
    if (blen >= sizeof(base)) blen = sizeof(base) - 1;
    memcpy(base, style, blen);
    base[blen] = '\0';
    if (opts) opts++; else opts = "";

    const char *notation = NULL;
    const char *compact_display = "short";
    const char *sign_display = NULL;
    int min_fd = -1, max_fd = -1, min_id = -1;
    int min_sd = -1, max_sd = -1;
    {
        const char *p = opts;
        while (p && *p) {
            const char *semi = strchr(p, ';');
            size_t n = semi ? (size_t)(semi - p) : strlen(p);
            char piece[64];
            if (n >= sizeof(piece)) n = sizeof(piece) - 1;
            memcpy(piece, p, n);
            piece[n] = '\0';
            char *eq = strchr(piece, '=');
            if (eq) {
                *eq = '\0';
                const char *k = piece;
                const char *v = eq + 1;
                if (strcmp(k, "notation") == 0) {
                    if (strcmp(v, "compact") == 0) notation = "compact";
                    else if (strcmp(v, "scientific") == 0) notation = "scientific";
                    else if (strcmp(v, "engineering") == 0) notation = "engineering";
                } else if (strcmp(k, "compactDisplay") == 0) {
                    compact_display = (strcmp(v, "long") == 0) ? "long" : "short";
                } else if (strcmp(k, "signDisplay") == 0) {
                    if (strcmp(v, "always") == 0) sign_display = "sign-always";
                    else if (strcmp(v, "never") == 0) sign_display = "sign-never";
                    else if (strcmp(v, "exceptZero") == 0) sign_display = "sign-except-zero";
                    else if (strcmp(v, "negative") == 0) sign_display = "sign-negative";
                } else if (strcmp(k, "minimumFractionDigits") == 0) min_fd = atoi(v);
                else if (strcmp(k, "maximumFractionDigits") == 0) max_fd = atoi(v);
                else if (strcmp(k, "minimumIntegerDigits") == 0) min_id = atoi(v);
                else if (strcmp(k, "minimumSignificantDigits") == 0) min_sd = atoi(v);
                else if (strcmp(k, "maximumSignificantDigits") == 0) max_sd = atoi(v);
            }
            p = semi ? semi + 1 : NULL;
        }
    }

    char skel[192];
    skel[0] = '\0';
    int pos = 0;
    #define SKEL_ADD(lit) do { \
        int _n = snprintf(skel + pos, sizeof(skel) - (size_t)pos, "%s%s", pos ? " " : "", lit); \
        if (_n < 0 || pos + _n >= (int)sizeof(skel)) return -1; \
        pos += _n; \
    } while (0)

    if (strncmp(base, "currency:", 9) == 0 && base[9]) {
        char cur[16];
        snprintf(cur, sizeof(cur), "currency/%s", base + 9);
        SKEL_ADD(cur);
    } else if (strncmp(base, "unit:", 5) == 0 && base[5]) {
        char u[48];
        snprintf(u, sizeof(u), "unit/%s", base + 5);
        SKEL_ADD(u);
    } else if (strcmp(base, "percent") == 0) {
        /* ICU 74 `percent` stem is sign-only; scale/100 matches UNUM_PERCENT. */
        SKEL_ADD("scale/100");
        SKEL_ADD("percent");
    } else if (strcmp(base, "scientific") == 0) {
        SKEL_ADD("scientific");
    } else {
        /* decimal / default — no stem token required */
    }

    if (notation) {
        if (strcmp(notation, "compact") == 0) {
            SKEL_ADD(strcmp(compact_display, "long") == 0 ? "compact-long" : "compact-short");
        } else if (strcmp(notation, "scientific") == 0) {
            SKEL_ADD("scientific");
        } else if (strcmp(notation, "engineering") == 0) {
            SKEL_ADD("engineering");
        }
    }

    if (sign_display) SKEL_ADD(sign_display);

    if (min_sd >= 0 || max_sd >= 0) {
        int a = min_sd >= 0 ? min_sd : 1;
        int b = max_sd >= 0 ? max_sd : a;
        char prec[32];
        snprintf(prec, sizeof(prec), "@%d*%d", a, b);
        /* ICU significant-digit skeleton: @@@ or @## form — use precision-integer fallback */
        if (a == b) snprintf(prec, sizeof(prec), "%.*s", a > 0 && a < 16 ? a : 1, "@@@@@@@@@@@@@@@@");
        else {
            /* @## = min 1 max 3 when a=1,b=3 → emit @ + (b-a) # */
            int i = 0;
            prec[i++] = '@';
            for (int k = 1; k < a && i < 30; k++) prec[i++] = '@';
            for (int k = a; k < b && i < 30; k++) prec[i++] = '#';
            prec[i] = '\0';
        }
        SKEL_ADD(prec);
    } else if (min_fd >= 0 || max_fd >= 0) {
        int a = min_fd >= 0 ? min_fd : 0;
        int b = max_fd >= 0 ? max_fd : (a > 0 ? a : 3);
        if (a == 0 && b == 0) {
            SKEL_ADD("precision-integer");
        } else {
            char prec[40];
            int i = 0;
            prec[i++] = '.';
            for (int k = 0; k < a && i < 36; k++) prec[i++] = '0';
            for (int k = a; k < b && i < 36; k++) prec[i++] = '#';
            prec[i] = '\0';
            SKEL_ADD(prec);
        }
    }

    if (min_id > 1) {
        char idig[24];
        int i = 0;
        for (int k = 0; k < min_id && i < 20; k++) idig[i++] = '0';
        idig[i] = '\0';
        SKEL_ADD(idig);
    }

    if (pos == 0) {
        /* Bare decimal */
        snprintf(out, (size_t)out_cap, "%s", ".");
    } else {
        snprintf(out, (size_t)out_cap, "%s", skel);
    }
    #undef SKEL_ADD
    return 0;
}

static UDisplayContext parse_display_style(const char *style) {
    if (style && strcmp(style, "short") == 0) return UDISPCTX_LENGTH_SHORT;
    if (style && strcmp(style, "narrow") == 0) return UDISPCTX_LENGTH_SHORT;
    return UDISPCTX_LENGTH_FULL;
}

static UListFormatterType parse_list_type(const char *type) {
    if (type && strcmp(type, "disjunction") == 0) return ULISTFMT_TYPE_OR;
    if (type && strcmp(type, "unit") == 0) return ULISTFMT_TYPE_UNITS;
    return ULISTFMT_TYPE_AND;
}

static UListFormatterWidth parse_list_width(const char *style) {
    if (style && strcmp(style, "short") == 0) return ULISTFMT_WIDTH_SHORT;
    if (style && strcmp(style, "narrow") == 0) return ULISTFMT_WIDTH_NARROW;
    return ULISTFMT_WIDTH_WIDE;
}

static UDateRelativeDateTimeFormatterStyle parse_rel_style(void) {
    return UDAT_STYLE_LONG;
}

static URelativeDateTimeUnit parse_rel_unit(const char *unit) {
    if (!unit) return UDAT_REL_UNIT_DAY;
    if (strcmp(unit, "year") == 0) return UDAT_REL_UNIT_YEAR;
    if (strcmp(unit, "quarter") == 0) return UDAT_REL_UNIT_QUARTER;
    if (strcmp(unit, "month") == 0) return UDAT_REL_UNIT_MONTH;
    if (strcmp(unit, "week") == 0) return UDAT_REL_UNIT_WEEK;
    if (strcmp(unit, "day") == 0) return UDAT_REL_UNIT_DAY;
    if (strcmp(unit, "hour") == 0) return UDAT_REL_UNIT_HOUR;
    if (strcmp(unit, "minute") == 0) return UDAT_REL_UNIT_MINUTE;
    if (strcmp(unit, "second") == 0) return UDAT_REL_UNIT_SECOND;
    return UDAT_REL_UNIT_DAY;
}

/* ── Public API ───────────────────────────────────────────────────────────── */

int icu_get_default_locale(char *out, int out_cap) {
    const char *def = uloc_getDefault();
    if (!def) def = "en-US";
    char tmp[ULOC_FULLNAME_CAPACITY];
    snprintf(tmp, sizeof(tmp), "%s", def);
    locale_to_bcp47(tmp);
    return write_utf8(out, out_cap, tmp);
}

int icu_canonical_locale(const char *locale, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    UErrorCode st = U_ZERO_ERROR;
    char tmp[ULOC_FULLNAME_CAPACITY];
    uloc_canonicalize(locale ? locale : "", tmp, (int32_t)sizeof(tmp), &st);
    if (U_FAILURE(st)) {
        out[0] = '\0';
        return -1;
    }
    /* Prefer language tag form (BCP 47). */
    st = U_ZERO_ERROR;
    char tag[ULOC_FULLNAME_CAPACITY];
    int32_t n = uloc_toLanguageTag(tmp, tag, (int32_t)sizeof(tag), /*strict*/ 0, &st);
    if (U_SUCCESS(st) && n > 0 && n < (int32_t)sizeof(tag)) {
        return write_utf8(out, out_cap, tag);
    }
    locale_to_bcp47(tmp);
    return write_utf8(out, out_cap, tmp);
}

static int locale_transform_to_bcp47(
    int (*transform)(const char *, char *, int32_t, UErrorCode *),
    const char *locale, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    UErrorCode st = U_ZERO_ERROR;
    char tmp[ULOC_FULLNAME_CAPACITY];
    transform(locale ? locale : "", tmp, (int32_t)sizeof(tmp), &st);
    if (U_FAILURE(st)) {
        out[0] = '\0';
        return -1;
    }
    /* Reject ICU keyword-form leftovers (e.g. "@x=private") that are not
     * convertible to a BCP-47 language tag. */
    if (tmp[0] == '@') {
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    char tag[ULOC_FULLNAME_CAPACITY];
    int32_t n = uloc_toLanguageTag(tmp, tag, (int32_t)sizeof(tag), /*strict*/ 0, &st);
    if (U_SUCCESS(st) && n > 0 && n < (int32_t)sizeof(tag) && tag[0] != '@') {
        return write_utf8(out, out_cap, tag);
    }
    locale_to_bcp47(tmp);
    if (tmp[0] == '@' || strchr(tmp, '@') != NULL) {
        out[0] = '\0';
        return -1;
    }
    return write_utf8(out, out_cap, tmp);
}

int icu_maximize_locale(const char *locale, char *out, int out_cap) {
    return locale_transform_to_bcp47(uloc_addLikelySubtags, locale, out, out_cap);
}

int icu_minimize_locale(const char *locale, char *out, int out_cap) {
    return locale_transform_to_bcp47(uloc_minimizeSubtags, locale, out, out_cap);
}

int icu_format_number(const char *locale, const char *style, double value,
                      char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    char skel_utf8[192];
    if (build_number_skeleton(style, skel_utf8, (int)sizeof(skel_utf8)) != 0) {
        out[0] = '\0';
        return -1;
    }
    UChar skel[192];
    int32_t sklen = 0;
    if (utf8_to_uchar(skel_utf8, skel, 192, &sklen) != 0) {
        out[0] = '\0';
        return -1;
    }
    UErrorCode st = U_ZERO_ERROR;
    UNumberFormatter *nf = unumf_openForSkeletonAndLocale(
        skel, sklen, locale ? locale : "en", &st);
    if (U_FAILURE(st) || !nf) {
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    UFormattedNumber *res = unumf_openResult(&st);
    if (U_FAILURE(st) || !res) {
        unumf_close(nf);
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    unumf_formatDouble(nf, value, res, &st);
    unumf_close(nf);
    if (U_FAILURE(st)) {
        unumf_closeResult(res);
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    UChar ubuf[ICU_UCHAR_BUF];
    int32_t ulen = unumf_resultToString(res, ubuf, ICU_UCHAR_BUF, &st);
    unumf_closeResult(res);
    if (U_FAILURE(st) || ulen < 0) {
        out[0] = '\0';
        return -1;
    }
    return uchar_to_utf8(ubuf, ulen, out, out_cap);
}

int icu_format_datetime(const char *locale, const char *date_style,
                        const char *time_style, double epoch_ms,
                        char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    UDateFormatStyle ds = parse_date_style(date_style);
    UDateFormatStyle ts = parse_date_style(time_style);
    if (ds == UDAT_NONE && ts == UDAT_NONE) {
        ds = UDAT_DEFAULT;
        ts = UDAT_DEFAULT;
    }
    UErrorCode st = U_ZERO_ERROR;
    UDateFormat *fmt = udat_open(ts, ds, locale ? locale : "en",
                                 NULL, -1, NULL, 0, &st);
    if (U_FAILURE(st) || !fmt) {
        out[0] = '\0';
        return -1;
    }
    UChar ubuf[ICU_UCHAR_BUF];
    st = U_ZERO_ERROR;
    int32_t ulen = udat_format(fmt, (UDate)epoch_ms, ubuf, ICU_UCHAR_BUF, NULL, &st);
    udat_close(fmt);
    if (U_FAILURE(st) || ulen < 0) {
        out[0] = '\0';
        return -1;
    }
    return uchar_to_utf8(ubuf, ulen, out, out_cap);
}

int icu_set_default_tz(const char *tz) {
    if (!tz || !tz[0]) return -1;
    UChar utz[128];
    int32_t len = 0;
    if (utf8_to_uchar(tz, utz, 128, &len) != 0) return -1;
    UErrorCode st = U_ZERO_ERROR;
    ucal_setDefaultTimeZone(utz, &st);
    return U_FAILURE(st) ? -1 : 0;
}

int icu_plural_select(const char *locale, const char *type, double value,
                      char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    UPluralType pt = UPLURAL_TYPE_CARDINAL;
    if (type && strcmp(type, "ordinal") == 0) pt = UPLURAL_TYPE_ORDINAL;
    UErrorCode st = U_ZERO_ERROR;
    UPluralRules *pr = uplrules_openForType(locale ? locale : "en", pt, &st);
    if (U_FAILURE(st) || !pr) {
        out[0] = '\0';
        return -1;
    }
    UChar ubuf[64];
    st = U_ZERO_ERROR;
    int32_t ulen = uplrules_select(pr, value, ubuf, 64, &st);
    uplrules_close(pr);
    if (U_FAILURE(st) || ulen < 0) {
        out[0] = '\0';
        return -1;
    }
    return uchar_to_utf8(ubuf, ulen, out, out_cap);
}

int icu_compare(const char *locale, const char *sensitivity,
                const char *a, const char *b) {
    UErrorCode st = U_ZERO_ERROR;
    UCollator *col = ucol_open(locale ? locale : "en", &st);
    if (U_FAILURE(st) || !col) return (int)INT32_MIN;

    /* Canonical equivalence (ạ̈ == ạ̈) requires NFD before collation. */
    ucol_setAttribute(col, UCOL_NORMALIZATION_MODE, UCOL_ON, &st);
    st = U_ZERO_ERROR;

    if (sensitivity && sensitivity[0]) {
        if (strcmp(sensitivity, "base") == 0) {
            ucol_setStrength(col, UCOL_PRIMARY);
        } else if (strcmp(sensitivity, "accent") == 0) {
            ucol_setStrength(col, UCOL_SECONDARY);
        } else if (strcmp(sensitivity, "case") == 0) {
            ucol_setStrength(col, UCOL_TERTIARY);
            ucol_setAttribute(col, UCOL_CASE_LEVEL, UCOL_ON, &st);
        } else if (strcmp(sensitivity, "variant") == 0) {
            /* ECMA-402 "variant" ≈ tertiary (not identical). */
            ucol_setStrength(col, UCOL_TERTIARY);
        }
    }

    st = U_ZERO_ERROR;
    UCollationResult r = ucol_strcollUTF8(col, a ? a : "", -1, b ? b : "", -1, &st);
    ucol_close(col);
    if (U_FAILURE(st)) return (int)INT32_MIN;
    if (r == UCOL_LESS) return -1;
    if (r == UCOL_GREATER) return 1;
    return 0;
}

int icu_display_name(const char *locale, const char *type, const char *code,
                     const char *style, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    UErrorCode st = U_ZERO_ERROR;
    UDisplayContext contexts[1];
    contexts[0] = parse_display_style(style);
    ULocaleDisplayNames *ldn = uldn_openForContext(locale ? locale : "en",
                                                   contexts, 1, &st);
    if (U_FAILURE(st) || !ldn) {
        /* Fallback without context. */
        st = U_ZERO_ERROR;
        ldn = uldn_open(locale ? locale : "en", ULDN_DIALECT_NAMES, &st);
    }
    if (U_FAILURE(st) || !ldn) {
        out[0] = '\0';
        return -1;
    }

    UChar ubuf[ICU_UCHAR_BUF];
    int32_t ulen = 0;
    st = U_ZERO_ERROR;
    const char *t = type ? type : "language";
    const char *c = code ? code : "";
    if (strcmp(t, "region") == 0) {
        ulen = uldn_regionDisplayName(ldn, c, ubuf, ICU_UCHAR_BUF, &st);
    } else if (strcmp(t, "script") == 0) {
        ulen = uldn_scriptDisplayName(ldn, c, ubuf, ICU_UCHAR_BUF, &st);
    } else if (strcmp(t, "language") == 0) {
        ulen = uldn_languageDisplayName(ldn, c, ubuf, ICU_UCHAR_BUF, &st);
    } else {
        /* locale / currency / calendar / dateTimeField → localeDisplayName */
        ulen = uldn_localeDisplayName(ldn, c, ubuf, ICU_UCHAR_BUF, &st);
    }
    uldn_close(ldn);
    if (U_FAILURE(st) || ulen < 0) {
        out[0] = '\0';
        return -1;
    }
    return uchar_to_utf8(ubuf, ulen, out, out_cap);
}

int icu_list_format(const char *locale, const char *type, const char *style,
                    const char *items_joined, int sep, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    if (!items_joined) items_joined = "";
    if (sep <= 0) sep = 0x1f;

    /* Split items_joined on sep into UTF-8 pieces, then to UChar. */
    const char *pieces[ICU_MAX_LIST];
    int32_t piece_lens[ICU_MAX_LIST];
    int count = 0;
    const char *p = items_joined;
    while (*p && count < ICU_MAX_LIST) {
        pieces[count] = p;
        const char *q = p;
        while (*q && (unsigned char)*q != (unsigned char)sep) q++;
        piece_lens[count] = (int32_t)(q - p);
        count++;
        if (!*q) break;
        p = q + 1;
    }
    /* Trailing sep with empty final piece is ignored; empty input → 0 items. */
    if (count == 1 && piece_lens[0] == 0 && items_joined[0] == '\0') count = 0;

    UErrorCode st = U_ZERO_ERROR;
    UListFormatter *lf = ulistfmt_openForType(locale ? locale : "en",
                                              parse_list_type(type),
                                              parse_list_width(style), &st);
    if (U_FAILURE(st) || !lf) {
        out[0] = '\0';
        return -1;
    }

    UChar *ustrs[ICU_MAX_LIST];
    UChar storage[ICU_MAX_LIST][256];
    int32_t ulens[ICU_MAX_LIST];
    for (int i = 0; i < count; i++) {
        char tmp[512];
        int n = piece_lens[i];
        if (n >= (int)sizeof(tmp)) n = (int)sizeof(tmp) - 1;
        memcpy(tmp, pieces[i], (size_t)n);
        tmp[n] = '\0';
        if (utf8_to_uchar(tmp, storage[i], 256, &ulens[i]) != 0) {
            ulistfmt_close(lf);
            out[0] = '\0';
            return -1;
        }
        ustrs[i] = storage[i];
    }

    UChar ubuf[ICU_UCHAR_BUF];
    st = U_ZERO_ERROR;
    int32_t ulen = ulistfmt_format(lf, (const UChar *const *)ustrs, ulens, count,
                                   ubuf, ICU_UCHAR_BUF, &st);
    ulistfmt_close(lf);
    if (U_FAILURE(st) || ulen < 0) {
        out[0] = '\0';
        return -1;
    }
    return uchar_to_utf8(ubuf, ulen, out, out_cap);
}

int icu_relative_time(const char *locale, const char *numeric, const char *unit,
                      double value, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    UErrorCode st = U_ZERO_ERROR;
    URelativeDateTimeFormatter *fmt = ureldatefmt_open(
        locale ? locale : "en", NULL, parse_rel_style(),
        UDISPCTX_CAPITALIZATION_NONE, &st);
    if (U_FAILURE(st) || !fmt) {
        out[0] = '\0';
        return -1;
    }

    UChar ubuf[ICU_UCHAR_BUF];
    st = U_ZERO_ERROR;
    int32_t ulen;
    URelativeDateTimeUnit u = parse_rel_unit(unit);
    if (numeric && strcmp(numeric, "always") == 0) {
        ulen = ureldatefmt_formatNumeric(fmt, value, u, ubuf, ICU_UCHAR_BUF, &st);
    } else {
        ulen = ureldatefmt_format(fmt, value, u, ubuf, ICU_UCHAR_BUF, &st);
    }
    ureldatefmt_close(fmt);
    if (U_FAILURE(st) || ulen < 0) {
        out[0] = '\0';
        return -1;
    }
    return uchar_to_utf8(ubuf, ulen, out, out_cap);
}

int icu_segmenter_break(const char *locale, int granularity, const char *text,
                        int *offsets, int max_offsets) {
    if (!offsets || max_offsets <= 0) return -1;
    if (!text) text = "";

    UBreakIteratorType bi_type = UBRK_CHARACTER;
    if (granularity == 1) bi_type = UBRK_WORD;
    else if (granularity == 2) bi_type = UBRK_SENTENCE;

    UChar ubuf[8192];
    int32_t ulen = 0;
    if (utf8_to_uchar(text, ubuf, 8192, &ulen) != 0) {
        /* Fallback: heap-allocate for long text. */
        UErrorCode st0 = U_ZERO_ERROR;
        int32_t need = 0;
        u_strFromUTF8(NULL, 0, &need, text, -1, &st0);
        if (need <= 0) return -1;
        UChar *heap = (UChar *)malloc(((size_t)need + 1) * sizeof(UChar));
        if (!heap) return -1;
        st0 = U_ZERO_ERROR;
        u_strFromUTF8(heap, need + 1, &ulen, text, -1, &st0);
        if (U_FAILURE(st0)) { free(heap); return -1; }

        UErrorCode st = U_ZERO_ERROR;
        UBreakIterator *bi = ubrk_open(bi_type, locale ? locale : "en",
                                       heap, ulen, &st);
        if (U_FAILURE(st) || !bi) { free(heap); return -1; }

        int written = 0;
        int32_t pos = ubrk_first(bi);
        while (pos != UBRK_DONE && written < max_offsets) {
            offsets[written++] = (int)pos;
            pos = ubrk_next(bi);
        }
        ubrk_close(bi);
        free(heap);
        return written;
    }

    UErrorCode st = U_ZERO_ERROR;
    UBreakIterator *bi = ubrk_open(bi_type, locale ? locale : "en",
                                   ubuf, ulen, &st);
    if (U_FAILURE(st) || !bi) return -1;

    int written = 0;
    int32_t pos = ubrk_first(bi);
    while (pos != UBRK_DONE && written < max_offsets) {
        offsets[written++] = (int)pos;
        pos = ubrk_next(bi);
    }
    ubrk_close(bi);
    return written;
}

int icu_normalize(const char *form, const char *text, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    out[0] = '\0';
    if (!form) form = "NFC";
    if (!text) text = "";

    UErrorCode st = U_ZERO_ERROR;
    const UNormalizer2 *norm = NULL;
    if (strcmp(form, "NFC") == 0) {
        norm = unorm2_getNFCInstance(&st);
    } else if (strcmp(form, "NFD") == 0) {
        norm = unorm2_getNFDInstance(&st);
    } else if (strcmp(form, "NFKC") == 0) {
        norm = unorm2_getNFKCInstance(&st);
    } else if (strcmp(form, "NFKD") == 0) {
        norm = unorm2_getNFKDInstance(&st);
    } else {
        return -1;
    }
    if (U_FAILURE(st) || !norm) return -1;

    UChar src[ICU_UCHAR_BUF];
    int32_t src_len = 0;
    UChar *src_ptr = src;
    UChar *src_heap = NULL;
    if (utf8_to_uchar(text, src, ICU_UCHAR_BUF, &src_len) != 0) {
        UErrorCode st0 = U_ZERO_ERROR;
        int32_t need = 0;
        u_strFromUTF8(NULL, 0, &need, text, -1, &st0);
        if (need <= 0) return -1;
        src_heap = (UChar *)malloc(((size_t)need + 1) * sizeof(UChar));
        if (!src_heap) return -1;
        st0 = U_ZERO_ERROR;
        u_strFromUTF8(src_heap, need + 1, &src_len, text, -1, &st0);
        if (U_FAILURE(st0)) { free(src_heap); return -1; }
        src_ptr = src_heap;
    }

    UChar dst_stack[ICU_UCHAR_BUF];
    UChar *dst = dst_stack;
    UChar *dst_heap = NULL;
    int32_t dst_cap = ICU_UCHAR_BUF;
    st = U_ZERO_ERROR;
    int32_t dst_len = unorm2_normalize(norm, src_ptr, src_len, dst, dst_cap, &st);
    if (st == U_BUFFER_OVERFLOW_ERROR) {
        dst_heap = (UChar *)malloc(((size_t)dst_len + 1) * sizeof(UChar));
        if (!dst_heap) { free(src_heap); return -1; }
        dst = dst_heap;
        dst_cap = dst_len + 1;
        st = U_ZERO_ERROR;
        dst_len = unorm2_normalize(norm, src_ptr, src_len, dst, dst_cap, &st);
    }
    if (U_FAILURE(st)) {
        free(src_heap);
        free(dst_heap);
        return -1;
    }

    int rc = uchar_to_utf8(dst, dst_len, out, out_cap);
    free(src_heap);
    free(dst_heap);
    return rc;
}

/* ── Locale Info helpers ──────────────────────────────────────────────────── */

static int append_csv(char *out, int out_cap, int *len, const char *item) {
    if (!item || !item[0]) return 0;
    size_t n = strlen(item);
    int need = (*len > 0) ? 1 : 0;
    if (*len + need + (int)n >= out_cap) return -1;
    if (need) out[(*len)++] = ',';
    memcpy(out + *len, item, n);
    *len += (int)n;
    out[*len] = '\0';
    return 0;
}

static int cmp_cstr(const void *a, const void *b) {
    return strcmp(*(const char *const *)a, *(const char *const *)b);
}

static int enum_to_csv(UEnumeration *en, const char *unicode_key,
                       int (*reject)(const char *), int sort_flag,
                       char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    out[0] = '\0';
    if (!en) return -1;

    char *items[256];
    int nitems = 0;
    UErrorCode st = U_ZERO_ERROR;
    const char *item;
    while ((item = uenum_next(en, NULL, &st)) != NULL && U_SUCCESS(st)) {
        const char *mapped = item;
        if (unicode_key) {
            const char *u = uloc_toUnicodeLocaleType(unicode_key, item);
            if (u) mapped = u;
        }
        if (reject && reject(mapped)) continue;
        if (nitems >= 256) break;
        size_t n = strlen(mapped);
        char *copy = (char *)malloc(n + 1);
        if (!copy) {
            for (int i = 0; i < nitems; i++) free(items[i]);
            return -1;
        }
        memcpy(copy, mapped, n + 1);
        items[nitems++] = copy;
    }
    if (sort_flag && nitems > 1) {
        qsort(items, (size_t)nitems, sizeof(char *), cmp_cstr);
    }
    int len = 0;
    for (int i = 0; i < nitems; i++) {
        if (append_csv(out, out_cap, &len, items[i]) != 0) {
            for (int j = 0; j < nitems; j++) free(items[j]);
            return -1;
        }
        free(items[i]);
    }
    return (nitems > 0) ? 0 : -1;
}

static int reject_collation(const char *c) {
    return c && (strcmp(c, "standard") == 0 || strcmp(c, "search") == 0);
}

static int weekday_ecma_from_icu(UCalendarDaysOfWeek d) {
    /* ICU: SUNDAY=1 … SATURDAY=7 → ECMA: Monday=1 … Sunday=7 */
    return (d == UCAL_SUNDAY) ? 7 : ((int)d - 1);
}

int icu_locale_info(const char *locale, int kind, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    out[0] = '\0';
    const char *loc = (locale && locale[0]) ? locale : "en";
    UErrorCode st = U_ZERO_ERROR;

    if (kind == 0) {
        /* calendars — commonly used, preference order (unsorted) */
        UEnumeration *en = ucal_getKeywordValuesForLocale("calendar", loc,
                                                          /*commonlyUsed*/ 1, &st);
        if (U_FAILURE(st) || !en) {
            return write_utf8(out, out_cap, "gregory");
        }
        int rc = enum_to_csv(en, "ca", NULL, 0, out, out_cap);
        uenum_close(en);
        if (rc != 0) return write_utf8(out, out_cap, "gregory");
        return 0;
    }

    if (kind == 1) {
        /* collations — commonly used, sorted, exclude standard/search */
        st = U_ZERO_ERROR;
        UEnumeration *en = ucol_getKeywordValuesForLocale("collation", loc,
                                                          1, &st);
        if (U_FAILURE(st) || !en) {
            return write_utf8(out, out_cap, "default");
        }
        int rc = enum_to_csv(en, "co", reject_collation, 1, out, out_cap);
        uenum_close(en);
        if (rc != 0 || !out[0]) {
            /* Some locales only expose standard/search; offer a harmless id. */
            return write_utf8(out, out_cap, "emoji");
        }
        return 0;
    }

    if (kind == 2) {
        /* hourCycles — preferred/default hour cycle only */
        st = U_ZERO_ERROR;
        UDateTimePatternGenerator *gen = udatpg_open(loc, &st);
        if (U_FAILURE(st) || !gen) {
            return write_utf8(out, out_cap, "h23");
        }
        st = U_ZERO_ERROR;
        UDateFormatHourCycle hc = udatpg_getDefaultHourCycle(gen, &st);
        udatpg_close(gen);
        if (U_FAILURE(st)) return write_utf8(out, out_cap, "h23");
        const char *s = "h23";
        switch (hc) {
            case UDAT_HOUR_CYCLE_11: s = "h11"; break;
            case UDAT_HOUR_CYCLE_12: s = "h12"; break;
            case UDAT_HOUR_CYCLE_23: s = "h23"; break;
            case UDAT_HOUR_CYCLE_24: s = "h24"; break;
            default: break;
        }
        return write_utf8(out, out_cap, s);
    }

    if (kind == 3) {
        /* numberingSystems — default for locale */
        st = U_ZERO_ERROR;
        char nu[64];
        nu[0] = '\0';
        int32_t nlen = uloc_getKeywordValue(loc, "numbers", nu, (int32_t)sizeof(nu), &st);
        if (U_SUCCESS(st) && nlen > 0 && nu[0]) {
            const char *mapped = uloc_toUnicodeLocaleType("nu", nu);
            return write_utf8(out, out_cap, mapped ? mapped : nu);
        }
        st = U_ZERO_ERROR;
        UNumberingSystem *ns = unumsys_open(loc, &st);
        if (U_FAILURE(st) || !ns) {
            return write_utf8(out, out_cap, "latn");
        }
        const char *name = unumsys_getName(ns);
        const char *mapped = name ? uloc_toUnicodeLocaleType("nu", name) : NULL;
        int rc = write_utf8(out, out_cap, mapped ? mapped : (name ? name : "latn"));
        unumsys_close(ns);
        return rc;
    }

    if (kind == 4) {
        /* timeZones — undefined when no region */
        char region[8];
        st = U_ZERO_ERROR;
        int32_t rlen = uloc_getCountry(loc, region, (int32_t)sizeof(region), &st);
        if (U_FAILURE(st) || rlen <= 0 || !region[0]) {
            /* Also try after likely subtags for tags that omit region in the
             * raw string but… Spec: only the unicode_language_id region counts.
             * So no region → undefined. */
            out[0] = '\0';
            return 1;
        }
        st = U_ZERO_ERROR;
        UEnumeration *en = ucal_openTimeZoneIDEnumeration(
            UCAL_ZONE_TYPE_CANONICAL, region, NULL, &st);
        if (U_FAILURE(st) || !en) {
            out[0] = '\0';
            return -1;
        }
        int rc = enum_to_csv(en, NULL, NULL, 1, out, out_cap);
        uenum_close(en);
        return rc;
    }

    if (kind == 5) {
        /* textDirection */
        return write_utf8(out, out_cap, uloc_isRightToLeft(loc) ? "rtl" : "ltr");
    }

    if (kind == 6) {
        /* weekInfo: "firstDay;weekendCsv" */
        st = U_ZERO_ERROR;
        UCalendar *cal = ucal_open(NULL, -1, loc, UCAL_DEFAULT, &st);
        if (U_FAILURE(st) || !cal) {
            return write_utf8(out, out_cap, "7;6,7");
        }
        UCalendarDaysOfWeek fd_icu = ucal_getAttribute(cal, UCAL_FIRST_DAY_OF_WEEK);
        int fd = weekday_ecma_from_icu(fd_icu);
        char week[64];
        int wlen = snprintf(week, sizeof(week), "%d;", fd);
        int first = 1;
        for (int i = 1; i <= 7; i++) {
            UCalendarDaysOfWeek day =
                (i == 7) ? UCAL_SUNDAY : (UCalendarDaysOfWeek)(i + 1);
            st = U_ZERO_ERROR;
            UCalendarWeekdayType t = ucal_getDayOfWeekType(cal, day, &st);
            if (U_SUCCESS(st) && t != UCAL_WEEKDAY) {
                if (!first) {
                    if (wlen < (int)sizeof(week) - 1) week[wlen++] = ',';
                }
                first = 0;
                wlen += snprintf(week + wlen, sizeof(week) - (size_t)wlen, "%d", i);
            }
        }
        ucal_close(cal);
        if (first) {
            /* Fallback weekend Sat+Sun if ICU reports none */
            snprintf(week, sizeof(week), "%d;6,7", fd);
        }
        return write_utf8(out, out_cap, week);
    }

    return -1;
}

/* ── formatToParts / formatRange ─────────────────────────────────────────── */

#define PARTS_MAX_FIELDS 64
#define PARTS_UTF8_CAP   2048

typedef struct {
    int32_t begin;
    int32_t end;
    int32_t field;
} PartField;

static const char *number_field_type(int32_t field, const char *slice, int32_t slen) {
    switch (field) {
    case UNUM_INTEGER_FIELD: return "integer";
    case UNUM_FRACTION_FIELD: return "fraction";
    case UNUM_DECIMAL_SEPARATOR_FIELD: return "decimal";
    case UNUM_EXPONENT_SYMBOL_FIELD: return "exponentSeparator";
    case UNUM_EXPONENT_SIGN_FIELD:
        if (slen > 0 && slice[0] == '+') return "exponentPlusSign";
        return "exponentMinusSign";
    case UNUM_EXPONENT_FIELD: return "exponentInteger";
    case UNUM_GROUPING_SEPARATOR_FIELD: return "group";
    case UNUM_CURRENCY_FIELD: return "currency";
    case UNUM_PERCENT_FIELD: return "percentSign";
    case UNUM_PERMILL_FIELD: return "literal";
    case UNUM_SIGN_FIELD:
        if (slen > 0 && slice[0] == '+') return "plusSign";
        return "minusSign";
    case UNUM_MEASURE_UNIT_FIELD: return "unit";
    case UNUM_COMPACT_FIELD: return "compact";
    case UNUM_APPROXIMATELY_SIGN_FIELD: return "approximatelySign";
    default: return "literal";
    }
}

static const char *datetime_field_type(int32_t field) {
    switch (field) {
    case UDAT_ERA_FIELD: return "era";
    case UDAT_YEAR_FIELD:
    case UDAT_EXTENDED_YEAR_FIELD:
    case UDAT_YEAR_WOY_FIELD: return "year";
    case UDAT_MONTH_FIELD:
    case UDAT_STANDALONE_MONTH_FIELD: return "month";
    case UDAT_DATE_FIELD: return "day";
    case UDAT_HOUR_OF_DAY1_FIELD:
    case UDAT_HOUR_OF_DAY0_FIELD:
    case UDAT_HOUR1_FIELD:
    case UDAT_HOUR0_FIELD: return "hour";
    case UDAT_MINUTE_FIELD: return "minute";
    case UDAT_SECOND_FIELD: return "second";
    case UDAT_FRACTIONAL_SECOND_FIELD: return "fractionalSecond";
    case UDAT_DAY_OF_WEEK_FIELD:
    case UDAT_DOW_LOCAL_FIELD:
    case UDAT_STANDALONE_DAY_FIELD: return "weekday";
    case UDAT_AM_PM_FIELD:
    case UDAT_AM_PM_MIDNIGHT_NOON_FIELD:
    case UDAT_FLEXIBLE_DAY_PERIOD_FIELD: return "dayPeriod";
    case UDAT_TIMEZONE_FIELD:
    case UDAT_TIMEZONE_RFC_FIELD:
    case UDAT_TIMEZONE_GENERIC_FIELD:
    case UDAT_TIMEZONE_SPECIAL_FIELD:
    case UDAT_TIMEZONE_LOCALIZED_GMT_OFFSET_FIELD:
    case UDAT_TIMEZONE_ISO_FIELD:
    case UDAT_TIMEZONE_ISO_LOCAL_FIELD: return "timeZoneName";
    case UDAT_QUARTER_FIELD:
    case UDAT_STANDALONE_QUARTER_FIELD: return "relatedYear";
    default: return "literal";
    }
}

static int append_part(char *out, int out_cap, int *olen,
                       const char *type, const char *val, int32_t vlen) {
    if (!type || !val || vlen < 0) return -1;
    if (*olen > 0) {
        if (*olen + 1 >= out_cap) return -1;
        out[(*olen)++] = '\x1e';
    }
    int tlen = (int)strlen(type);
    if (*olen + tlen + 1 + vlen >= out_cap) return -1;
    memcpy(out + *olen, type, (size_t)tlen);
    *olen += tlen;
    out[(*olen)++] = '\x1f';
    memcpy(out + *olen, val, (size_t)vlen);
    *olen += vlen;
    out[*olen] = '\0';
    return 0;
}

static int emit_parts_from_fields(const char *utf8, int32_t ulen,
                                  PartField *fields, int nfields,
                                  int is_number, char *out, int out_cap) {
    if (!out || out_cap <= 0 || !utf8 || ulen < 0) return -1;
    if (ulen == 0) {
        out[0] = '\0';
        return 0;
    }
    /* Innermost field wins per code unit (UTF-8 byte index ≈ UChar index here
     * because we map using UTF-8 offsets from the same converted string). */
    int8_t *owner = (int8_t *)calloc((size_t)ulen, 1);
    if (!owner) return -1;
    memset(owner, -1, (size_t)ulen);
    for (int f = 0; f < nfields; f++) {
        int32_t b = fields[f].begin;
        int32_t e = fields[f].end;
        if (b < 0) b = 0;
        if (e > ulen) e = ulen;
        if (b >= e) continue;
        int32_t span = e - b;
        for (int32_t i = b; i < e; i++) {
            int prev = owner[i];
            if (prev < 0) {
                owner[i] = (int8_t)f;
            } else {
                int32_t pspan = fields[prev].end - fields[prev].begin;
                if (span <= pspan) owner[i] = (int8_t)f;
            }
        }
    }
    int olen = 0;
    out[0] = '\0';
    int32_t i = 0;
    while (i < ulen) {
        int f = owner[i];
        int32_t j = i + 1;
        while (j < ulen && owner[j] == f) j++;
        const char *type = "literal";
        if (f >= 0) {
            if (is_number) {
                type = number_field_type(fields[f].field, utf8 + i, j - i);
            } else {
                type = datetime_field_type(fields[f].field);
            }
        }
        if (append_part(out, out_cap, &olen, type, utf8 + i, j - i) != 0) {
            free(owner);
            return -1;
        }
        i = j;
    }
    free(owner);
    return 0;
}

/* Convert UChar field offsets to UTF-8 byte offsets for the same string. */
static void uchar_fields_to_utf8(const UChar *ubuf, int32_t ulen,
                                 PartField *fields, int nfields) {
    int32_t *u2b = (int32_t *)malloc((size_t)(ulen + 1) * sizeof(int32_t));
    if (!u2b) return;
    int32_t bpos = 0;
    for (int32_t i = 0; i < ulen; i++) {
        u2b[i] = bpos;
        UChar c = ubuf[i];
        if (c < 0x80) bpos += 1;
        else if (c < 0x800) bpos += 2;
        else if (c >= 0xD800 && c <= 0xDBFF && i + 1 < ulen &&
                 ubuf[i + 1] >= 0xDC00 && ubuf[i + 1] <= 0xDFFF) {
            /* surrogate pair → 4 UTF-8 bytes; map both halves */
            u2b[i] = bpos;
            i++;
            u2b[i] = bpos;
            bpos += 4;
        } else {
            bpos += 3;
        }
    }
    u2b[ulen] = bpos;
    for (int f = 0; f < nfields; f++) {
        int32_t b = fields[f].begin;
        int32_t e = fields[f].end;
        if (b < 0) b = 0;
        if (e < 0) e = 0;
        if (b > ulen) b = ulen;
        if (e > ulen) e = ulen;
        fields[f].begin = u2b[b];
        fields[f].end = u2b[e];
    }
    free(u2b);
}

static int collect_fields(UFieldPositionIterator *fpi, PartField *fields, int maxf) {
    int n = 0;
    int32_t begin = 0, end = 0;
    int32_t field;
    while ((field = ufieldpositer_next(fpi, &begin, &end)) >= 0) {
        if (n >= maxf) break;
        fields[n].begin = begin;
        fields[n].end = end;
        fields[n].field = field;
        n++;
    }
    return n;
}

int icu_format_number_parts(const char *locale, const char *style, double value,
                            char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    char skel_utf8[192];
    if (build_number_skeleton(style, skel_utf8, (int)sizeof(skel_utf8)) != 0) {
        out[0] = '\0';
        return -1;
    }
    UChar skel[192];
    int32_t sklen = 0;
    if (utf8_to_uchar(skel_utf8, skel, 192, &sklen) != 0) {
        out[0] = '\0';
        return -1;
    }
    UErrorCode st = U_ZERO_ERROR;
    UNumberFormatter *nf = unumf_openForSkeletonAndLocale(
        skel, sklen, locale ? locale : "en", &st);
    if (U_FAILURE(st) || !nf) {
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    UFormattedNumber *res = unumf_openResult(&st);
    if (U_FAILURE(st) || !res) {
        unumf_close(nf);
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    unumf_formatDouble(nf, value, res, &st);
    unumf_close(nf);
    if (U_FAILURE(st)) {
        unumf_closeResult(res);
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    const UFormattedValue *fv = unumf_resultAsValue(res, &st);
    if (U_FAILURE(st) || !fv) {
        unumf_closeResult(res);
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    int32_t ulen = 0;
    const UChar *ustr = ufmtval_getString(fv, &ulen, &st);
    if (U_FAILURE(st) || !ustr || ulen < 0) {
        unumf_closeResult(res);
        out[0] = '\0';
        return -1;
    }
    if (ulen >= ICU_UCHAR_BUF) ulen = ICU_UCHAR_BUF - 1;
    UChar ubuf[ICU_UCHAR_BUF];
    u_strncpy(ubuf, ustr, ulen);
    ubuf[ulen] = 0;

    PartField fields[PARTS_MAX_FIELDS];
    int nfields = 0;
    st = U_ZERO_ERROR;
    UConstrainedFieldPosition *ucfpos = ucfpos_open(&st);
    if (U_SUCCESS(st) && ucfpos) {
        ucfpos_constrainCategory(ucfpos, UFIELD_CATEGORY_NUMBER, &st);
        while (nfields < PARTS_MAX_FIELDS &&
               ufmtval_nextPosition(fv, ucfpos, &st) && U_SUCCESS(st)) {
            int32_t b = 0, e = 0;
            fields[nfields].field = ucfpos_getField(ucfpos, &st);
            ucfpos_getIndexes(ucfpos, &b, &e, &st);
            fields[nfields].begin = b;
            fields[nfields].end = e;
            nfields++;
        }
        ucfpos_close(ucfpos);
    }
    unumf_closeResult(res);

    char utf8[PARTS_UTF8_CAP];
    if (uchar_to_utf8(ubuf, ulen, utf8, PARTS_UTF8_CAP) != 0) {
        out[0] = '\0';
        return -1;
    }
    uchar_fields_to_utf8(ubuf, ulen, fields, nfields);
    int32_t blen = (int32_t)strlen(utf8);
    return emit_parts_from_fields(utf8, blen, fields, nfields, 1, out, out_cap);
}

int icu_format_datetime_parts(const char *locale, const char *date_style,
                              const char *time_style, double epoch_ms,
                              char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    UDateFormatStyle ds = parse_date_style(date_style);
    UDateFormatStyle ts = parse_date_style(time_style);
    if (ds == UDAT_NONE && ts == UDAT_NONE) {
        ds = UDAT_DEFAULT;
        ts = UDAT_DEFAULT;
    }
    UErrorCode st = U_ZERO_ERROR;
    UDateFormat *fmt = udat_open(ts, ds, locale ? locale : "en",
                                 NULL, -1, NULL, 0, &st);
    if (U_FAILURE(st) || !fmt) {
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    UFieldPositionIterator *fpi = ufieldpositer_open(&st);
    if (U_FAILURE(st) || !fpi) {
        udat_close(fmt);
        out[0] = '\0';
        return -1;
    }
    UChar ubuf[ICU_UCHAR_BUF];
    st = U_ZERO_ERROR;
    int32_t ulen = udat_formatForFields(fmt, (UDate)epoch_ms, ubuf, ICU_UCHAR_BUF, fpi, &st);
    udat_close(fmt);
    if (U_FAILURE(st) || ulen < 0) {
        ufieldpositer_close(fpi);
        out[0] = '\0';
        return -1;
    }
    PartField fields[PARTS_MAX_FIELDS];
    int nfields = collect_fields(fpi, fields, PARTS_MAX_FIELDS);
    ufieldpositer_close(fpi);
    char utf8[PARTS_UTF8_CAP];
    if (uchar_to_utf8(ubuf, ulen, utf8, PARTS_UTF8_CAP) != 0) {
        out[0] = '\0';
        return -1;
    }
    uchar_fields_to_utf8(ubuf, ulen, fields, nfields);
    int32_t blen = (int32_t)strlen(utf8);
    return emit_parts_from_fields(utf8, blen, fields, nfields, 0, out, out_cap);
}

static void style_to_skeleton(const char *date_style, const char *time_style,
                              char *skel, int skel_cap) {
    const char *d = "";
    const char *t = "";
    if (date_style && strcmp(date_style, "full") == 0) d = "yMMMMEEEEd";
    else if (date_style && strcmp(date_style, "long") == 0) d = "yMMMMd";
    else if (date_style && strcmp(date_style, "medium") == 0) d = "yMMMd";
    else if (date_style && strcmp(date_style, "short") == 0) d = "yMd";
    if (time_style && strcmp(time_style, "full") == 0) t = "jmszzzz";
    else if (time_style && strcmp(time_style, "long") == 0) t = "jmsz";
    else if (time_style && strcmp(time_style, "medium") == 0) t = "jms";
    else if (time_style && strcmp(time_style, "short") == 0) t = "jm";
    if (!d[0] && !t[0]) {
        snprintf(skel, (size_t)skel_cap, "%s", "yMMMdjms");
        return;
    }
    snprintf(skel, (size_t)skel_cap, "%s%s", d, t);
}

static UNumberRangeFormatter *open_number_range_formatter(const char *locale,
                                                          const char *style,
                                                          UErrorCode *st) {
    char skel_utf8[192];
    if (build_number_skeleton(style, skel_utf8, (int)sizeof(skel_utf8)) != 0) {
        *st = U_ILLEGAL_ARGUMENT_ERROR;
        return NULL;
    }
    UChar skel[192];
    int32_t sklen = 0;
    if (utf8_to_uchar(skel_utf8, skel, 192, &sklen) != 0) {
        *st = U_ILLEGAL_ARGUMENT_ERROR;
        return NULL;
    }
    *st = U_ZERO_ERROR;
    return unumrf_openForSkeletonWithCollapseAndIdentityFallback(
        skel, sklen, UNUM_RANGE_COLLAPSE_AUTO,
        UNUM_IDENTITY_FALLBACK_APPROXIMATELY_OR_SINGLE_VALUE,
        locale ? locale : "en", NULL, st);
}

static int finish_number_range_result(UNumberRangeFormatter *nrf,
                                      UFormattedNumberRange *res,
                                      char *out, int out_cap) {
    UErrorCode st = U_ZERO_ERROR;
    const UFormattedValue *fv = unumrf_resultAsValue(res, &st);
    if (U_FAILURE(st) || !fv) {
        unumrf_closeResult(res);
        unumrf_close(nrf);
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    int32_t ulen = 0;
    const UChar *ustr = ufmtval_getString(fv, &ulen, &st);
    int rc = -1;
    if (U_SUCCESS(st) && ustr) {
        rc = uchar_to_utf8(ustr, ulen, out, out_cap);
    } else {
        out[0] = '\0';
    }
    unumrf_closeResult(res);
    unumrf_close(nrf);
    return rc;
}

int icu_format_number_range(const char *locale, const char *style,
                            double start, double end, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    UErrorCode st = U_ZERO_ERROR;
    UNumberRangeFormatter *nrf = open_number_range_formatter(locale, style, &st);
    if (U_FAILURE(st) || !nrf) {
        char a[512], b[512];
        if (icu_format_number(locale, style, start, a, (int)sizeof(a)) != 0 ||
            icu_format_number(locale, style, end, b, (int)sizeof(b)) != 0) {
            out[0] = '\0';
            return -1;
        }
        if (strcmp(a, b) == 0) return write_utf8(out, out_cap, a);
        char tmp[1024];
        snprintf(tmp, sizeof(tmp), "%s\xe2\x80\x93%s", a, b); /* en-dash */
        return write_utf8(out, out_cap, tmp);
    }
    st = U_ZERO_ERROR;
    UFormattedNumberRange *res = unumrf_openResult(&st);
    if (U_FAILURE(st) || !res) {
        unumrf_close(nrf);
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    unumrf_formatDoubleRange(nrf, start, end, res, &st);
    if (U_FAILURE(st)) {
        unumrf_closeResult(res);
        unumrf_close(nrf);
        out[0] = '\0';
        return -1;
    }
    return finish_number_range_result(nrf, res, out, out_cap);
}

int icu_format_number_range_decimal(const char *locale, const char *style,
                                    const char *start_dec, const char *end_dec,
                                    char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    if (!start_dec) start_dec = "0";
    if (!end_dec) end_dec = "0";
    UErrorCode st = U_ZERO_ERROR;
    UNumberRangeFormatter *nrf = open_number_range_formatter(locale, style, &st);
    if (U_FAILURE(st) || !nrf) {
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    UFormattedNumberRange *res = unumrf_openResult(&st);
    if (U_FAILURE(st) || !res) {
        unumrf_close(nrf);
        out[0] = '\0';
        return -1;
    }
    st = U_ZERO_ERROR;
    unumrf_formatDecimalRange(nrf, start_dec, -1, end_dec, -1, res, &st);
    if (U_FAILURE(st)) {
        unumrf_closeResult(res);
        unumrf_close(nrf);
        out[0] = '\0';
        return -1;
    }
    return finish_number_range_result(nrf, res, out, out_cap);
}

int icu_format_datetime_range(const char *locale, const char *date_style,
                              const char *time_style, double start_ms,
                              double end_ms, char *out, int out_cap) {
    if (!out || out_cap <= 0) return -1;
    char skel_utf8[64];
    style_to_skeleton(date_style, time_style, skel_utf8, (int)sizeof(skel_utf8));
    UChar skel[64];
    int32_t sklen = 0;
    if (utf8_to_uchar(skel_utf8, skel, 64, &sklen) != 0) {
        out[0] = '\0';
        return -1;
    }
    UErrorCode st = U_ZERO_ERROR;
    UDateIntervalFormat *dif = udtitvfmt_open(locale ? locale : "en",
                                              skel, sklen, NULL, -1, &st);
    if (U_FAILURE(st) || !dif) {
        char a[512], b[512];
        if (icu_format_datetime(locale, date_style, time_style, start_ms, a, (int)sizeof(a)) != 0 ||
            icu_format_datetime(locale, date_style, time_style, end_ms, b, (int)sizeof(b)) != 0) {
            out[0] = '\0';
            return -1;
        }
        if (strcmp(a, b) == 0) return write_utf8(out, out_cap, a);
        char tmp[1024];
        snprintf(tmp, sizeof(tmp), "%s\xe2\x80\x93%s", a, b);
        return write_utf8(out, out_cap, tmp);
    }
    UChar ubuf[ICU_UCHAR_BUF];
    st = U_ZERO_ERROR;
    int32_t ulen = udtitvfmt_format(dif, (UDate)start_ms, (UDate)end_ms,
                                    ubuf, ICU_UCHAR_BUF, NULL, &st);
    udtitvfmt_close(dif);
    if (U_FAILURE(st) || ulen < 0) {
        out[0] = '\0';
        return -1;
    }
    return uchar_to_utf8(ubuf, ulen, out, out_cap);
}
