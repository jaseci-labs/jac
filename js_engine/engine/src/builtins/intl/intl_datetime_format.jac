"""Intl.DateTimeFormat native bridge helpers."""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_string_id,
    jsv_from_int32,
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
    icu_format_datetime_str,
    icu_format_datetime_parts_str,
    icu_format_datetime_range_str,
    icu_set_default_tz_str
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

"""args[0]=locale, [1]=dateStyle, [2]=timeStyle, [3]=epochMs → formatted string."""
def:pub intl_format_datetime(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    ds: str = "medium";
    ts: str = "medium";
    ms: float = 0.0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        ds = _arg_str(args[1]);
        if ds == "" {
            ds = "medium";
        }
    }
    if len(args) >= 3 {
        ts = _arg_str(args[2]);
        if ts == "" {
            ts = "medium";
        }
    }
    if len(args) >= 4 {
        ms = _arg_num(args[3]);
    }
    out: str = icu_format_datetime_str(loc, ds, ts, ms);
    return jsv_from_string_id(str_intern(out));
}

"""args[0]=IANA time zone id → 0 ok / -1 error. Sets ICU's default zone so
subsequently opened date formatters render wall-clock time in that zone."""
def:pub intl_set_default_tz(args: list[JSValue]) -> JSValue {
    tz: str = "UTC";
    if len(args) >= 1 {
        tz_a: str = _arg_str(args[0]);
        if tz_a != "" {
            tz = tz_a;
        }
    }
    return jsv_from_int32(icu_set_default_tz_str(tz));
}

"""args[0]=locale, [1]=dateStyle, [2]=timeStyle, [3]=epochMs → parts encoding."""
def:pub intl_format_datetime_parts(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    ds: str = "medium";
    ts: str = "medium";
    ms: float = 0.0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        ds = _arg_str(args[1]);
        if ds == "" {
            ds = "medium";
        }
    }
    if len(args) >= 3 {
        ts = _arg_str(args[2]);
        if ts == "" {
            ts = "medium";
        }
    }
    if len(args) >= 4 {
        ms = _arg_num(args[3]);
    }
    out: str = icu_format_datetime_parts_str(loc, ds, ts, ms);
    return jsv_from_string_id(str_intern(out));
}

"""args[0]=locale, [1]=dateStyle, [2]=timeStyle, [3]=startMs, [4]=endMs → range."""
def:pub intl_format_datetime_range(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    ds: str = "medium";
    ts: str = "medium";
    a: float = 0.0;
    b: float = 0.0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        ds = _arg_str(args[1]);
        if ds == "" {
            ds = "medium";
        }
    }
    if len(args) >= 3 {
        ts = _arg_str(args[2]);
        if ts == "" {
            ts = "medium";
        }
    }
    if len(args) >= 4 {
        a = _arg_num(args[3]);
    }
    if len(args) >= 5 {
        b = _arg_num(args[4]);
    }
    out: str = icu_format_datetime_range_str(loc, ds, ts, a, b);
    return jsv_from_string_id(str_intern(out));
}
