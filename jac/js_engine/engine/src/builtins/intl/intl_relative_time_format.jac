"""Intl.RelativeTimeFormat native bridge helpers."""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_string_id,
    jsv_is_string_cell,
    jsv_to_table_id,
    jsv_is_int32,
    jsv_is_double,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_number
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.ffi.libicu { icu_relative_time_str }

def:priv _arg_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

def:priv _arg_num(v: JSValue) -> float {
    if jsv_is_int32(v) {
        return float(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        return jsv_to_double(v);
    }
    return jsv_to_number(v);
}

"""args[0]=locale, [1]=numeric, [2]=unit, [3]=value → formatted string."""
def:pub intl_relative_time(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    numeric: str = "auto";
    unit: str = "day";
    val: float = 0.0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        numeric = _arg_str(args[1]);
        if numeric == "" {
            numeric = "auto";
        }
    }
    if len(args) >= 3 {
        unit = _arg_str(args[2]);
        if unit == "" {
            unit = "day";
        }
    }
    if len(args) >= 4 {
        val = _arg_num(args[3]);
    }
    out: str = icu_relative_time_str(loc, numeric, unit, val);
    return jsv_from_string_id(str_intern(out));
}
