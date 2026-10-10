/*
 * icu_shim.h — Stable unversioned ICU wrapper for js_engine Intl.
 *
 * Compiled as lib/libicu_shim.so.  All string I/O is UTF-8 at the boundary;
 * UTF-16 conversion is handled internally.
 */

#ifndef ICU_SHIM_H
#define ICU_SHIM_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Status: 0 = ok, non-zero = error.  Out buffers are always NUL-terminated
 * on success when out_cap > 0. */

/* Write the ICU default locale id into out. */
int icu_get_default_locale(char *out, int out_cap);

/* Canonicalize a BCP-47 / ICU locale id (e.g. "EN-us" → "en_US" / "en-US").
 * Writes a BCP-47-ish form with '-' separators when possible. */
int icu_canonical_locale(const char *locale, char *out, int out_cap);

/* Add likely subtags (Intl.Locale.prototype.maximize). BCP-47 out. */
int icu_maximize_locale(const char *locale, char *out, int out_cap);

/* Remove likely subtags (Intl.Locale.prototype.minimize). BCP-47 out. */
int icu_minimize_locale(const char *locale, char *out, int out_cap);

/* Number formatting. style: "decimal"|"percent"|"currency"|"scientific"
 * (optional ":CUR" suffix for currency, e.g. "currency:USD"). */
int icu_format_number(const char *locale, const char *style, double value,
                      char *out, int out_cap);

/* DateTime formatting. date_style/time_style: "full"|"long"|"medium"|"short"|"none".
 * epoch_ms is milliseconds since Unix epoch (UTC). */
int icu_format_datetime(const char *locale, const char *date_style,
                        const char *time_style, double epoch_ms,
                        char *out, int out_cap);

/* Set the process-wide ICU default time zone (IANA id, e.g. "UTC",
 * "America/New_York"). Formatters opened afterwards render in that zone.
 * Returns 0 on success, -1 on error. */
int icu_set_default_tz(const char *tz);

/* Plural rules. type: "cardinal"|"ordinal". Writes keyword (one/two/few/…). */
int icu_plural_select(const char *locale, const char *type, double value,
                      char *out, int out_cap);

/* Collation compare. sensitivity: ""|"base"|"accent"|"case"|"variant".
 * Returns -1 / 0 / 1 on success, or INT32_MIN (-2147483648) on error. */
int icu_compare(const char *locale, const char *sensitivity,
                const char *a, const char *b);

/* Display names. type: "language"|"region"|"script"|"currency"|"calendar"|
 * "dateTimeField". style: "long"|"short"|"narrow". */
int icu_display_name(const char *locale, const char *type, const char *code,
                     const char *style, char *out, int out_cap);

/* List formatting. items_joined is UTF-8 items separated by sep (e.g. '\\x1f').
 * type: "conjunction"|"disjunction"|"unit". style: "long"|"short"|"narrow". */
int icu_list_format(const char *locale, const char *type, const char *style,
                    const char *items_joined, int sep, char *out, int out_cap);

/* Relative time. numeric: "always"|"auto". unit: year|quarter|month|week|
 * day|hour|minute|second. */
int icu_relative_time(const char *locale, const char *numeric, const char *unit,
                      double value, char *out, int out_cap);

/* Segmentation. granularity: 0=grapheme, 1=word, 2=sentence.
 * Writes up to max_offsets UTF-16 code-unit break offsets into offsets.
 * Returns count written (>=0), or -1 on error. */
int icu_segmenter_break(const char *locale, int granularity, const char *text,
                        int *offsets, int max_offsets);

/* Unicode string normalization. form: "NFC"|"NFD"|"NFKC"|"NFKD".
 * Writes NUL-terminated UTF-8 into out. Returns 0 on success. */
int icu_normalize(const char *form, const char *text, char *out, int out_cap);

/* Locale Info APIs (ECMA-402 Intl.Locale Info).
 * kind:
 *   0 = calendars (comma-separated BCP-47 calendar ids)
 *   1 = collations (comma-separated; excludes standard/search; sorted)
 *   2 = hourCycles (comma-separated h11|h12|h23|h24)
 *   3 = numberingSystems (comma-separated)
 *   4 = timeZones (comma-separated IANA ids, sorted).
 *       Returns 1 with empty out when locale has no region → JS undefined.
 *   5 = textDirection ("ltr" or "rtl")
 *   6 = weekInfo ("firstDay;w1,w2,..." e.g. "7;6,7")
 * Returns 0 on success, 1 for timeZones-without-region, -1 on error. */
int icu_locale_info(const char *locale, int kind, char *out, int out_cap);

/* formatToParts: writes records "type\\x1fvalue" joined by \\x1e. */
int icu_format_number_parts(const char *locale, const char *style, double value,
                            char *out, int out_cap);
int icu_format_datetime_parts(const char *locale, const char *date_style,
                              const char *time_style, double epoch_ms,
                              char *out, int out_cap);

/* formatRange: writes a formatted range string. */
int icu_format_number_range(const char *locale, const char *style,
                            double start, double end, char *out, int out_cap);
/* Decimal-string range (preserves precision beyond float64). */
int icu_format_number_range_decimal(const char *locale, const char *style,
                                    const char *start_dec, const char *end_dec,
                                    char *out, int out_cap);
int icu_format_datetime_range(const char *locale, const char *date_style,
                              const char *time_style, double start_ms,
                              double end_ms, char *out, int out_cap);

#ifdef __cplusplus
}
#endif

#endif /* ICU_SHIM_H */
