"""Intl.NumberFormat native bridge helpers."""

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
import from engine.src.ffi.libicu {
    icu_format_number_str,
    icu_format_number_parts_str,
    icu_format_number_range_str,
    icu_format_number_range_decimal_str
}

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

"""args[0]=locale, [1]=style, [2]=value → formatted string."""
def:pub intl_format_number(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    style: str = "decimal";
    val: float = 0.0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        style = _arg_str(args[1]);
        if style == "" {
            style = "decimal";
        }
    }
    if len(args) >= 3 {
        val = _arg_num(args[2]);
    }
    out: str = icu_format_number_str(loc, style, val);
    return jsv_from_string_id(str_intern(out));
}

"""args[0]=locale, [1]=style, [2]=value → parts encoding (type\\x1fvalue\\x1e...)."""
def:pub intl_format_number_parts(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    style: str = "decimal";
    val: float = 0.0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        style = _arg_str(args[1]);
        if style == "" {
            style = "decimal";
        }
    }
    if len(args) >= 3 {
        val = _arg_num(args[2]);
    }
    out: str = icu_format_number_parts_str(loc, style, val);
    return jsv_from_string_id(str_intern(out));
}

"""args[0]=locale, [1]=style, [2]=start, [3]=end → range string.

When start/end are string cells, use decimal-range formatting to preserve
precision beyond float64 (test262 large integer strings / BigInt).
"""
def:pub intl_format_number_range(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    style: str = "decimal";
    a: float = 0.0;
    b: float = 0.0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        style = _arg_str(args[1]);
        if style == "" {
            style = "decimal";
        }
    }
    if len(args) >= 4 and jsv_is_string_cell(args[2]) and jsv_is_string_cell(args[3]) {
        sa: str = _arg_str(args[2]);
        sb: str = _arg_str(args[3]);
        out_d: str = icu_format_number_range_decimal_str(loc, style, sa, sb);
        return jsv_from_string_id(str_intern(out_d));
    }
    if len(args) >= 3 {
        a = _arg_num(args[2]);
    }
    if len(args) >= 4 {
        b = _arg_num(args[3]);
    }
    out: str = icu_format_number_range_str(loc, style, a, b);
    return jsv_from_string_id(str_intern(out));
}
