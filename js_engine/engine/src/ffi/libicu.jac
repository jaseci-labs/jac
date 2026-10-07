"""ICU shim FFI bindings for js_engine Intl.

Thin wrapper over lib/libicu_shim.so.  Other modules should import from
this file rather than the .so directly.

  import from engine.src.ffi.libicu {
      icu_canonical_locale_str, icu_format_number_str, ...
  }
"""

import from "lib/libicu_shim.so" {
    def icu_get_default_locale(out: int, out_cap: int) -> int;  def icu_canonical_locale(
        locale: str, out: int, out_cap: int
    ) -> int;  def icu_maximize_locale(locale: str, out: int, out_cap: int) -> int;  def icu_minimize_locale(
        locale: str, out: int, out_cap: int
    ) -> int;  def icu_format_number(
        locale: str, style: str, value: float, out: int, out_cap: int
    ) -> int;  def icu_format_datetime(
        locale: str,
        date_style: str,
        time_style: str,
        epoch_ms: float,
        out: int,
        out_cap: int
    ) -> int;  def icu_set_default_tz(tz: str) -> int;  def icu_format_number_parts(
        locale: str, style: str, value: float, out: int, out_cap: int
    ) -> int;  def icu_format_datetime_parts(
        locale: str,
        date_style: str,
        time_style: str,
        epoch_ms: float,
        out: int,
        out_cap: int
    ) -> int;  def icu_format_number_range(
        locale: str, style: str, start: float, end: float, out: int, out_cap: int
    ) -> int;  def icu_format_number_range_decimal(
        locale: str, style: str, start_dec: str, end_dec: str, out: int, out_cap: int
    ) -> int;  def icu_format_datetime_range(
        locale: str,
        date_style: str,
        time_style: str,
        start_ms: float,
        end_ms: float,
        out: int,
        out_cap: int
    ) -> int;  def icu_plural_select(
        locale: str, type: str, value: float, out: int, out_cap: int
    ) -> int;  def icu_compare(locale: str, sensitivity: str, a: str, b: str) -> int;  def icu_display_name(
        locale: str, type: str, code: str, style: str, out: int, out_cap: int
    ) -> int;  def icu_list_format(
        locale: str,
        type: str,
        style: str,
        items_joined: str,
        sep: int,
        out: int,
        out_cap: int
    ) -> int;  def icu_relative_time(
        locale: str, numeric: str, unit: str, value: float, out: int, out_cap: int
    ) -> int;  def icu_segmenter_break(
        locale: str, granularity: int, text: str, offsets: int, max_offsets: int
    ) -> int;  def icu_normalize(form: str, text: str, out: int, out_cap: int) -> int;  def icu_locale_info(
        locale: str, kind: int, out: int, out_cap: int
    ) -> int;
}

import from engine.src.runtime.mem { io_alloc, read_byte, read_i32 }
import from engine.src.runtime.jsstring { str_substr }

glob:priv _ICU_OUT_CAP: int = 2048,
     _ICU_MAX_BREAKS: int = 4096;

def:priv _cstrlen(ptr: int, max_len: int) -> int {
    i: int = 0;
    while i < max_len {
        if read_byte(ptr, i) == 0 {
            return i;
        }
        i = i + 1;
    }
    return max_len;
}

def:priv _buf_to_str(ptr: int, cap: int) -> str {
    n: int = _cstrlen(ptr, cap);
    s: str = ptr;  # jac:ignore[E1001] pointer reinterpreted as str
    return str_substr(s, 0, n);
}

"""Default locale (BCP-47-ish), or empty string on failure."""
def:pub icu_default_locale_str -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_get_default_locale(buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""Canonicalize locale id; returns "" on failure."""
def:pub icu_canonical_locale_str(locale: str) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_canonical_locale(locale, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""Add likely subtags; returns "" on failure."""
def:pub icu_maximize_locale_str(locale: str) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_maximize_locale(locale, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""Remove likely subtags; returns "" on failure."""
def:pub icu_minimize_locale_str(locale: str) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_minimize_locale(locale, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""Format a number; returns "" on failure."""
def:pub icu_format_number_str(locale: str, style: str, value: float) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_format_number(locale, style, value, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""Format a datetime from epoch milliseconds; returns "" on failure."""
def:pub icu_format_number_parts_str(locale: str, style: str, value: float) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_format_number_parts(locale, style, value, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

def:pub icu_format_datetime_parts_str(
    locale: str, date_style: str, time_style: str, epoch_ms: float
) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_format_datetime_parts(
        locale, date_style, time_style, epoch_ms, buf, _ICU_OUT_CAP
    );
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

def:pub icu_format_number_range_str(
    locale: str, style: str, start: float, end: float
) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_format_number_range(locale, style, start, end, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

def:pub icu_format_number_range_decimal_str(
    locale: str, style: str, start_dec: str, end_dec: str
) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_format_number_range_decimal(
        locale, style, start_dec, end_dec, buf, _ICU_OUT_CAP
    );
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

def:pub icu_format_datetime_range_str(
    locale: str, date_style: str, time_style: str, start_ms: float, end_ms: float
) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_format_datetime_range(
        locale, date_style, time_style, start_ms, end_ms, buf, _ICU_OUT_CAP
    );
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

def:pub icu_format_datetime_str(
    locale: str, date_style: str, time_style: str, epoch_ms: float
) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_format_datetime(
        locale, date_style, time_style, epoch_ms, buf, _ICU_OUT_CAP
    );
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""Set ICU's process-wide default time zone (IANA id). 0 = ok, -1 = error."""
def:pub icu_set_default_tz_str(tz: str) -> int {
    return icu_set_default_tz(tz);
}

"""Plural category keyword; returns "" on failure."""
def:pub icu_plural_select_str(locale: str, type: str, value: float) -> str {
    buf: int = io_alloc(64);
    rc: int = icu_plural_select(locale, type, value, buf, 64);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, 64);
}

"""Collation compare: -1 / 0 / 1, or -2147483648 on error."""
def:pub icu_compare_str(locale: str, sensitivity: str, a: str, b: str) -> int {
    return icu_compare(locale, sensitivity, a, b);
}

"""Display name; returns "" on failure."""
def:pub icu_display_name_str(locale: str, type: str, code: str, style: str) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_display_name(locale, type, code, style, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""List format; items joined with sep (default 0x1f). Returns "" on failure."""
def:pub icu_list_format_str(
    locale: str, type: str, style: str, items_joined: str, sep: int
) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    s: int = sep;
    if s <= 0 {
        s = 31;
    }
    rc: int = icu_list_format(locale, type, style, items_joined, s, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""Relative time format; returns "" on failure."""
def:pub icu_relative_time_str(
    locale: str, numeric: str, unit: str, value: float
) -> str {
    buf: int = io_alloc(_ICU_OUT_CAP);
    rc: int = icu_relative_time(locale, numeric, unit, value, buf, _ICU_OUT_CAP);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, _ICU_OUT_CAP);
}

"""Segmenter breaks as comma-separated UTF-16 offsets, or "" on failure."""
def:pub icu_segmenter_break_str(locale: str, granularity: int, text: str) -> str {
    off_buf: int = io_alloc(_ICU_MAX_BREAKS * 4);
    n: int = icu_segmenter_break(locale, granularity, text, off_buf, _ICU_MAX_BREAKS);
    if n < 0 {
        return "";
    }
    out: str = "";
    i: int = 0;
    while i < n {
        v: int = read_i32(off_buf, i * 4);
        if i > 0 {
            out = out + ",";
        }
        out = out + str(v);
        i = i + 1;
    }
    return out;
}

"""Unicode normalize (NFC/NFD/NFKC/NFKD). Returns "" on failure.
Empty input yields "" on success too — callers must treat that as success when
the source string is empty."""
def:pub icu_normalize_str(form: str, text: str) -> str {
    # Long strings may exceed the default buffer; allocate a generous one.
    cap: int = _ICU_OUT_CAP;
    if len(text) * 4 + 16 > cap {
        cap = len(text) * 4 + 16;
    }
    buf: int = io_alloc(cap);
    rc: int = icu_normalize(form, text, buf, cap);
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, cap);
}

"""Locale info CSV / token. Returns "" on error.
For kind=4 (timeZones) without a region, returns the sentinel \"\\x01undefined\"
so callers can map it to JS undefined."""
def:pub icu_locale_info_str(locale: str, kind: int) -> str {
    cap: int = 8192;
    buf: int = io_alloc(cap);
    rc: int = icu_locale_info(locale, kind, buf, cap);
    if rc == 1 {
        return "\x01undefined";
    }
    if rc != 0 {
        return "";
    }
    return _buf_to_str(buf, cap);
}
