"""Intl.DurationFormat — JS-side stub; no native ICU bridge required.

Duration formatting is implemented in engine/src/builtins/js/intl.js by
concatenating unit fields.  This module exists so the intl package surface
matches the ECMA-402 constructor set.
"""

import from engine.src.runtime.jsvalue { JSValue, js_undefined }

"""Placeholder — DurationFormat is fully JS-implemented."""
def:pub intl_duration_format_stub(args: list[JSValue]) -> JSValue {
    return js_undefined();
}
