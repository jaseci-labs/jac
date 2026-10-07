"""Intl.PluralRules native bridge helpers."""

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
import from engine.src.ffi.libicu { icu_plural_select_str }

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

"""args[0]=locale, [1]=type (cardinal|ordinal), [2]=value → keyword."""
def:pub intl_plural_select(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    typ: str = "cardinal";
    val: float = 0.0;
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        typ = _arg_str(args[1]);
        if typ == "" {
            typ = "cardinal";
        }
    }
    if len(args) >= 3 {
        val = _arg_num(args[2]);
    }
    out: str = icu_plural_select_str(loc, typ, val);
    return jsv_from_string_id(str_intern(out));
}
