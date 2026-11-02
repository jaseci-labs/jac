"""Intl.Segmenter native bridge helpers."""

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_from_string_id,
    jsv_is_string_cell,
    jsv_to_table_id,
    jsv_is_int32,
    jsv_is_double,
    jsv_to_int32,
    jsv_to_double
}
import from engine.src.runtime.jsstring { str_intern, str_from_id }
import from engine.src.ffi.libicu { icu_segmenter_break_str }

def:priv _arg_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    return "";
}

def:priv _arg_int(v: JSValue) -> int {
    if jsv_is_int32(v) {
        return jsv_to_int32(v);
    }
    if jsv_is_double(v) {
        return int(jsv_to_double(v));
    }
    return 0;
}

"""args[0]=locale, [1]=granularity (0/1/2), [2]=text → comma-separated offsets."""
def:pub intl_segmenter_break(args: list[JSValue]) -> JSValue {
    loc: str = "en";
    gran: int = 0;
    text: str = "";
    if len(args) >= 1 {
        loc = _arg_str(args[0]);
        if loc == "" {
            loc = "en";
        }
    }
    if len(args) >= 2 {
        gran = _arg_int(args[1]);
    }
    if len(args) >= 3 {
        text = _arg_str(args[2]);
    }
    out: str = icu_segmenter_break_str(loc, gran, text);
    return jsv_from_string_id(str_intern(out));
}
