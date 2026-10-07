"""Intl.Locale / getCanonicalLocales native bridge helpers."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_from_string_id,
    jsv_is_string_cell,
    jsv_to_table_id,
    jsv_is_int32,
    jsv_to_int32,
    jsv_is_double,
    jsv_to_double
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.ffi.libicu {
    icu_canonical_locale_str,
    icu_default_locale_str,
    icu_maximize_locale_str,
    icu_minimize_locale_str,
    icu_locale_info_str
}

def:priv _arg_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

"""args[0]=locale → canonical BCP-47 string."""
def:pub intl_canonical_locale(args: list[JSValue]) -> JSValue {
    loc: str = "";
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
    }
    out: str = icu_canonical_locale_str(loc);
    return jsv_from_string_id(str_intern(out));
}

"""No args → default locale string."""
def:pub intl_get_default_locale(args: list[JSValue]) -> JSValue {
    out: str = icu_default_locale_str();
    return jsv_from_string_id(str_intern(out));
}

"""args[0]=locale → maximized BCP-47 string (Add Likely Subtags)."""
def:pub intl_maximize_locale(args: list[JSValue]) -> JSValue {
    loc: str = "";
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
    }
    out: str = icu_maximize_locale_str(loc);
    return jsv_from_string_id(str_intern(out));
}

"""args[0]=locale → minimized BCP-47 string (Remove Likely Subtags)."""
def:pub intl_minimize_locale(args: list[JSValue]) -> JSValue {
    loc: str = "";
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
    }
    out: str = icu_minimize_locale_str(loc);
    return jsv_from_string_id(str_intern(out));
}

"""args[0]=locale, args[1]=kind → CSV/token string, or undefined for timeZones
without a region."""
def:pub intl_locale_info(args: list[JSValue]) -> JSValue {
    loc: str = "";
    kind: int = 0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
    }
    if len(args) >= 2 {
        # int32/double directly (native-lowerable); int(jsv_to_number(…)) is NOT
        # lowerable (full ToNumber coercion) and would force this module non-native.
        if jsv_is_int32(args[1]) {
            kind = jsv_to_int32(args[1]);
        } elif jsv_is_double(args[1]) {
            kind = int(jsv_to_double(args[1]));
        }
    }
    out: str = icu_locale_info_str(loc, kind);
    if out == "\x01undefined" {
        return js_undefined();
    }
    return jsv_from_string_id(str_intern(out));
}
