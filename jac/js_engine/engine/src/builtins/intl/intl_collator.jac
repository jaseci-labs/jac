"""Intl.Collator native bridge helpers."""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_int,
    jsv_is_string_cell,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_from_id }
import from engine.src.ffi.libicu { icu_compare_str }

def:priv _arg_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

"""args[0]=locale, [1]=sensitivity, [2]=a, [3]=b → -1/0/1."""
def:pub intl_compare(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    sens: str = "";
    a: str = "";
    b: str = "";
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        sens = _arg_str(args[1]);
    }
    if len(args) >= 3 {
        a = _arg_str(args[2]);
    }
    if len(args) >= 4 {
        b = _arg_str(args[3]);
    }
    return js_int(icu_compare_str(loc, sens, a, b));
}
