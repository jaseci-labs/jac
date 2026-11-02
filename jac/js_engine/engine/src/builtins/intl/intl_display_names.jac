"""Intl.DisplayNames native bridge helpers."""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_string_id,
    jsv_is_string_cell,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.ffi.libicu { icu_display_name_str }

def:priv _arg_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

"""args[0]=locale, [1]=type, [2]=code, [3]=style → display name."""
def:pub intl_display_name(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    typ: str = "language";
    code: str = "";
    style: str = "long";
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        typ = _arg_str(args[1]);
        if typ == "" {
            typ = "language";
        }
    }
    if len(args) >= 3 {
        code = _arg_str(args[2]);
    }
    if len(args) >= 4 {
        style = _arg_str(args[3]);
        if style == "" {
            style = "long";
        }
    }
    out: str = icu_display_name_str(loc, typ, code, style);
    return jsv_from_string_id(str_intern(out));
}
