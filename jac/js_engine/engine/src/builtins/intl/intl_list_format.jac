"""Intl.ListFormat native bridge helpers."""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_string_id,
    jsv_is_string_cell,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.ffi.libicu { icu_list_format_str }

def:priv _arg_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

"""args[0]=locale, [1]=type, [2]=style, [3]=itemsJoined (\\x1f-sep) → string."""
def:pub intl_list_format(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    typ: str = "conjunction";
    style: str = "long";
    items: str = "";
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        typ = _arg_str(args[1]);
        if typ == "" {
            typ = "conjunction";
        }
    }
    if len(args) >= 3 {
        style = _arg_str(args[2]);
        if style == "" {
            style = "long";
        }
    }
    if len(args) >= 4 {
        items = _arg_str(args[3]);
    }
    out: str = icu_list_format_str(loc, typ, style, items, 31);
    return jsv_from_string_id(str_intern(out));
}
