"""
Built-in: console

Implements the WHATWG Console API (https://console.spec.whatwg.org/).
Output goes to stdout via print() in ;  wires libuv stream writes.

Bun reference   : bun/src/bun.js/ConsoleObject.zig
                  bun/src/js/builtins/ConsoleObject.ts
ECMAScript spec : N/A — WHATWG Console Standard

Methods implemented:
  log, error, warn, info, debug, dir, assert
  count, countReset, time, timeEnd, timeLog
  group, groupEnd, table (stub)

Value formatting mirrors Node/Bun:
  Primitives printed as-is at top level; strings are quoted when nested.
  Arrays   → [ 1, 'x', ... ]
  Objects  → { key: value, ... }
  Function → [Function: name]
  Depth capped at MAX_DEPTH (3) to prevent infinite recursion.
"""

import from engine.src.runtime.jsvalue {
    jsv_double_bits,
    JSValue,
    js_undefined,
    jsv_is_undefined,
    jsv_is_null,
    jsv_is_bool,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_object_cell,
    jsv_is_string_cell,
    jsv_is_symbol,
    jsv_is_bigint_cell,
    jsv_is_cell,
    jsv_cell_kind,
    JS_CELL_KIND_NATIVE,
    jsv_to_bool,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id
}
import from engine.src.runtime.jsstring { str_intern, str_from_id, str_char_at }
import from engine.src.builtins.array { _KEY_IS_ARRAY }
import from engine.src.builtins.map { _KEY_IS_MAP }
import from engine.src.builtins.native_registry { is_native_val, get_native_name }
import from engine.src.builtins.number { NUM_MAX_VALUE }
import from engine.src.runtime.dtoa { number_to_string_radix10 }
import from engine.src.runtime.jsobject { KEY_LENGTH, js_object_get, js_object_keys }
import from engine.src.ffi.libc { write, isatty, fflush }

# ══════════════════════════════════════════════════════════════════════════════
# 1.  Constants
# ══════════════════════════════════════════════════════════════════════════════

"""Maximum nesting depth for object/array display."""
glob MAX_DEPTH: int = 3;

"""--console-depth=<n> (bun) / util.inspect's `depth`: how many nested levels
are expanded before "[Object]". Node's default of 2 corresponds to MAX_DEPTH 3
(the value at nesting level depth+1 is collapsed)."""
def:pub console_set_max_depth(depth: int) {
    if depth >= 0 {
        MAX_DEPTH = depth + 1;
    }
}

"""File descriptor for stderr (POSIX fd 2)."""
glob STDERR_FD: int = 2;

# ══════════════════════════════════════════════════════════════════════════════
# 2.  Module-level state (count / time / group)
# ══════════════════════════════════════════════════════════════════════════════

"""Counter table for console.count(label)."""
glob _COUNT_TABLE: dict[str, int] = {};

"""
Timer table for console.time(label).
Stores start ticks.   uses a monotonic counter (not wall clock).
"""
glob _TIME_TABLE: dict[str, int] = {};

"""Global tick counter incremented by console.time — stand-in for hrtime."""
glob _TICK: int = 0;

"""Current group indentation depth (number of spaces = _INDENT * 2)."""
glob _INDENT: int = 0;

# ══════════════════════════════════════════════════════════════════════════════
# 3.  Value formatter
# ══════════════════════════════════════════════════════════════════════════════

"""
Build an indentation prefix of `level * 2` spaces.
"""
def _indent_str(level: int) -> str {
    result: str = "";
    i: int = 0;
    while i < level * 2 {
        result = result + " ";
        i = i + 1;
    }
    return result;
}

"""Return True if v is a JS Array (has the _KEY_IS_ARRAY sentinel property)."""
def _is_js_array(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    marker: JSValue = js_object_get(v, _KEY_IS_ARRAY);
    return jsv_is_bool(marker) and jsv_to_bool(marker);
}

"""
Return the interned key string for a given key ID, or a numeric fallback.
Used when enumerating object properties for display.
"""
def _key_display(key_id: int) -> str {
    s: str = str_from_id(key_id);
    if len(s) > 0 {
        return s;
    }
    return str(key_id);
}

"""
Format a single JSValue for console output.

`depth`   — current recursion depth (stops expanding at MAX_DEPTH)
`quoted`  — True when inside an array/object (strings show with quotes)
"""
def:pub js_value_to_display(v: JSValue, depth: int, quoted: bool) -> str {
    if jsv_is_undefined(v) {
        return "undefined";
    }
    if jsv_is_null(v) {
        return "null";
    }
    if jsv_is_bool(v) {
        if jsv_to_bool(v) {
            return "true";
        } else {
            return "false";
        }
    }
    if jsv_is_int32(v) {
        return str(jsv_to_int32(v));
    }
    if jsv_is_double(v) {
        n: float = jsv_to_double(v);
        if not (n == n) {
            return "NaN";
        }
        if n > NUM_MAX_VALUE {
            return "Infinity";
        }
        if n < -NUM_MAX_VALUE {
            return "-Infinity";
        }
        # Number::toString (node prints -0 as "-0")
        if n == 0.0 and jsv_double_bits(n) < 0 {
            return "-0";
        }
        return number_to_string_radix10(n);
    }
    if jsv_is_string_cell(v) {
        s: str = str_from_id(jsv_to_table_id(v));
        if quoted {
            return "'" + s + "'";
        }
        return s;
    }
    if jsv_is_cell(v) and jsv_cell_kind(v) == JS_CELL_KIND_NATIVE {
        if is_native_val(v) {
            nn: str = get_native_name(v);
            return "[Function: " + nn + "]";
        }
        return "[Function (anonymous)]";
    }
    if jsv_is_object_cell(v) {
        if depth >= MAX_DEPTH {
            return "[Object]";
        }
        # Array path
        if _is_js_array(v) {
            lv: JSValue = js_object_get(v, KEY_LENGTH);
            length: int = 0;
            if jsv_is_int32(lv) {
                length = jsv_to_int32(lv);
            }
            parts: list[str] = [];
            i: int = 0;
            while i < length {
                elem: JSValue = js_object_get(v, str_intern(str(i)));
                parts.append(js_value_to_display(elem, depth + 1, True));
                i = i + 1;
            }
            inner: str = "";
            j: int = 0;
            while j < len(parts) {
                if j > 0 {
                    inner = inner + ", ";
                }
                inner = inner + parts[j];  # jac:ignore[E1001]
                j = j + 1;
            }
            return "[ " + inner + " ]";
        }
        # Plain object path
        keys: list[int] = js_object_keys(v);
        parts2: list[str] = [];
        k: int = 0;
        while k < len(keys) {
            key_id: int = keys[k];
            # Skip hidden sentinel keys
            if key_id != _KEY_IS_ARRAY and key_id != _KEY_IS_MAP {
                val: JSValue = js_object_get(v, key_id);
                kname: str = _key_display(key_id);
                parts2.append(kname + ": " + js_value_to_display(val, depth + 1, True));
            }
            k = k + 1;
        }
        if len(parts2) == 0 {
            return "{}";
        }
        inner2: str = "";
        m: int = 0;
        while m < len(parts2) {
            if m > 0 {
                inner2 = inner2 + ", ";
            }
            inner2 = inner2 + parts2[m];  # jac:ignore[E1001]
            m = m + 1;
        }
        return "{ " + inner2 + " }";
    }
    if jsv_is_symbol(v) {
        return "Symbol()";
    }
    # A BigInt cell stores its decimal digits in the string table; console shows a
    # BigInt with a trailing `n` (Node's util.inspect style), e.g. `5n`.
    if jsv_is_bigint_cell(v) {
        return str_from_id(jsv_to_table_id(v)) + "n";
    }
    return "undefined";
}

# ══════════════════════════════════════════════════════════════════════════════
# 4.  Argument formatter  (printf-style substitution)
# ══════════════════════════════════════════════════════════════════════════════

"""
Format a list of JSValues for console output.

If the first argument is a String and contains %s/%d/%i/%f/%o substitution
tokens, applies printf-style substitution using subsequent arguments.
Otherwise joins all arguments with a single space.

ECMAScript Console Standard §2.1 (Formatter).
"""
def:pub js_format_args(args: list[JSValue]) -> str {
    if len(args) == 0 {
        return "";
    }
    # Check if first arg is a string with substitution tokens
    first: JSValue = args[0];
    if jsv_is_string_cell(first) and len(args) > 1 {
        fmt: str = str_from_id(jsv_to_table_id(first));
        result: str = "";
        arg_idx: int = 1;
        i: int = 0;
        n: int = len(fmt);
        while i < n {
            c: str = str_char_at(fmt, i);
            if c == "%" and i + 1 < n {
                next: str = str_char_at(fmt, i + 1);
                if (
                    next == "s"
                    or next == "d"
                    or next == "i"
                    or next == "f"
                    or next == "o"
                    or next == "O"
                )
                    and arg_idx < len(args) {
                    sub: JSValue = args[arg_idx];
                    arg_idx = arg_idx + 1;
                    if next == "s" {
                        result = result + js_value_to_display(sub, 0, False);
                    } elif next == "d" or next == "i" {
                        if jsv_is_int32(sub) {
                            result = result + str(jsv_to_int32(sub));
                        } elif jsv_is_double(sub) {
                            result = result + str(int(jsv_to_double(sub)));
                        } else {
                            result = result + "NaN";
                        }
                    } elif next == "f" {
                        if jsv_is_double(sub) {
                            result = result + str(jsv_to_double(sub));
                        } elif jsv_is_int32(sub) {
                            result = result + str(float(jsv_to_int32(sub)));
                        } else {
                            result = result + "NaN";
                        }
                    } else {
                        # %o / %O — object inspection
                        result = result + js_value_to_display(sub, 0, False);
                    }
                    i = i + 2;
                    continue;
                }
            }
            result = result + c;
            i = i + 1;
        }
        # Append any remaining args not consumed by substitution
        while arg_idx < len(args) {
            result = result + " " + js_value_to_display(args[arg_idx], 0, False);
            arg_idx = arg_idx + 1;
        }
        return result;
    }
    # No substitution — join with spaces
    out: str = "";
    idx: int = 0;
    while idx < len(args) {
        if idx > 0 {
            out = out + " ";
        }
        out = out + js_value_to_display(args[idx], 0, False);
        idx = idx + 1;
    }
    return out;
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Core console methods
# ══════════════════════════════════════════════════════════════════════════════

# 1 when stdout is not a terminal (file / pipe): flush after every console line.
glob _CON_FLUSH: int = -1;

"""Write one console line to stdout. print() goes through C stdio, which is
block-buffered when stdout is a file or pipe — console.log output then sat in
the buffer until exit (or was lost on a kill), while process.stdout.write (a raw
write(1)) went out at once and overtook it. Node writes both synchronously: a
parent reading the pipe (`jac start --dev` waiting for Vite's "ready in" banner)
never saw the line. Flush after each line when stdout is not a TTY."""
def _con_print(s: str) {
    print(s);
    if _CON_FLUSH < 0 {
        _CON_FLUSH = 0;
        if isatty(1) == 0 {
            _CON_FLUSH = 1;
        }
    }
    if _CON_FLUSH == 1 {
        fflush(0);
    }
}

"""
console.log(...args) — print formatted args to stdout.
WHATWG Console §2.3.1
"""
def:pub js_console_log(args: list[JSValue]) -> JSValue {
    prefix: str = _indent_str(_INDENT);
    _con_print(prefix + js_format_args(args));
    return js_undefined();
}

"""
console.info(...args) — same as console.log.
WHATWG Console §2.3.2
"""
def:pub js_console_info(args: list[JSValue]) -> JSValue {
    return js_console_log(args);
}

"""
console.debug(...args) — same as console.log.
WHATWG Console §2.3.3
"""
def:pub js_console_debug(args: list[JSValue]) -> JSValue {
    return js_console_log(args);
}

"""
console.error(...args) — print to stderr (: stdout with prefix).
WHATWG Console §2.3.4
"""
def:pub js_console_error(args: list[JSValue]) -> JSValue {
    prefix: str = _indent_str(_INDENT);
    msg: str = prefix + js_format_args(args) + "\n";
    write(STDERR_FD, msg, len(msg));
    return js_undefined();
}

"""
console.warn(...args) — print to stderr with WARNING prefix.
WHATWG Console §2.3.5
"""
def:pub js_console_warn(args: list[JSValue]) -> JSValue {
    prefix: str = _indent_str(_INDENT);
    # Node prints warnings as-is (no prefix) — Vite's warnings must read the same.
    msg: str = prefix + js_format_args(args) + "\n";
    write(STDERR_FD, msg, len(msg));
    return js_undefined();
}

"""
console.dir(obj, options?) — deep object inspection.
Prints the object at depth MAX_DEPTH regardless of nesting.
WHATWG Console §2.3.6
"""
def:pub js_console_dir(args: list[JSValue]) -> JSValue {
    if len(args) == 0 {
        _con_print("undefined");
        return js_undefined();
    }
    prefix: str = _indent_str(_INDENT);
    _con_print(prefix + js_value_to_display(args[0], 0, False));
    return js_undefined();
}

"""
console.assert(condition, ...msg) — print Assertion failed if condition is falsy.
WHATWG Console §2.3.7
"""
def:pub js_console_assert(args: list[JSValue]) -> JSValue {
    # Evaluate condition
    condition: bool = False;
    if len(args) > 0 {
        v: JSValue = args[0];
        if jsv_is_bool(v) {
            condition = jsv_to_bool(v);
        } elif jsv_is_int32(v) {
            condition = jsv_to_int32(v) != 0;
        } elif jsv_is_double(v) {
            condition = jsv_to_double(v) != 0.0
                and jsv_to_double(v) == jsv_to_double(v);
        } elif jsv_is_string_cell(v) {
            condition = len(str_from_id(jsv_to_table_id(v))) > 0;
        } elif jsv_is_object_cell(v) {
            condition = True;
        } elif jsv_is_undefined(v) or jsv_is_null(v) {
            condition = False;
        }
    }
    if not condition {
        rest: list[JSValue] = [];
        i: int = 1;
        while i < len(args) {
            rest.append(args[i]);
            i = i + 1;
        }
        msg: str = "Assertion failed";
        if len(rest) > 0 {
            msg = msg + ": " + js_format_args(rest);
        }
        _con_print(msg);
    }
    return js_undefined();
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  count / countReset
# ══════════════════════════════════════════════════════════════════════════════

"""
console.count(label?) — increment and print the counter for `label`.
Default label is "default".
WHATWG Console §2.3.8
"""
def:pub js_console_count(args: list[JSValue]) -> JSValue {
    label: str = "default";
    if len(args) > 0 {
        v: JSValue = args[0];
        if jsv_is_string_cell(v) {
            label = str_from_id(jsv_to_table_id(v));
        }
    }
    cur: int = 0;
    if label in _COUNT_TABLE {
        cur = _COUNT_TABLE[label];
    }
    cur = cur + 1;
    _COUNT_TABLE[label] = cur;
    _con_print(label + ": " + str(cur));
    return js_undefined();
}

"""
console.countReset(label?) — reset the counter for `label` to 0.
WHATWG Console §2.3.9
"""
def:pub js_console_countReset(args: list[JSValue]) -> JSValue {
    label: str = "default";
    if len(args) > 0 {
        v: JSValue = args[0];
        if jsv_is_string_cell(v) {
            label = str_from_id(jsv_to_table_id(v));
        }
    }
    _COUNT_TABLE[label] = 0;
    return js_undefined();
}

# ══════════════════════════════════════════════════════════════════════════════
# 7.  time / timeEnd / timeLog
# ══════════════════════════════════════════════════════════════════════════════

"""
console.time(label?) — start a timer for `label`.
: uses a monotonic tick counter (no wall clock).
WHATWG Console §2.3.10
"""
def:pub js_console_time(args: list[JSValue]) -> JSValue {
    label: str = "default";
    if len(args) > 0 {
        v: JSValue = args[0];
        if jsv_is_string_cell(v) {
            label = str_from_id(jsv_to_table_id(v));
        }
    }
    _TICK = _TICK + 1;
    _TIME_TABLE[label] = _TICK;
    return js_undefined();
}

"""
console.timeEnd(label?) — stop and print the elapsed ticks for `label`.
WHATWG Console §2.3.11
"""
def:pub js_console_timeEnd(args: list[JSValue]) -> JSValue {
    label: str = "default";
    if len(args) > 0 {
        v: JSValue = args[0];
        if jsv_is_string_cell(v) {
            label = str_from_id(jsv_to_table_id(v));
        }
    }
    _TICK = _TICK + 1;
    elapsed: int = 0;
    if label in _TIME_TABLE {
        elapsed = _TICK - _TIME_TABLE[label];
    }
    _con_print(label + ": " + str(elapsed) + "ms");
    if label in _TIME_TABLE {
        del _TIME_TABLE[label];
    }
    return js_undefined();
}

"""
console.timeLog(label?) — print elapsed ticks without stopping the timer.
WHATWG Console §2.3.11 (timeLog variant)
"""
def:pub js_console_timeLog(args: list[JSValue]) -> JSValue {
    label: str = "default";
    if len(args) > 0 {
        v: JSValue = args[0];
        if jsv_is_string_cell(v) {
            label = str_from_id(jsv_to_table_id(v));
        }
    }
    _TICK = _TICK + 1;
    elapsed: int = 0;
    if label in _TIME_TABLE {
        elapsed = _TICK - _TIME_TABLE[label];
    }
    _con_print(label + ": " + str(elapsed) + "ms");
    return js_undefined();
}

# ══════════════════════════════════════════════════════════════════════════════
# 8.  group / groupEnd
# ══════════════════════════════════════════════════════════════════════════════

"""
console.group(...label) — print label and increase indentation.
WHATWG Console §2.3.12
"""
def:pub js_console_group(args: list[JSValue]) -> JSValue {
    if len(args) > 0 {
        prefix: str = _indent_str(_INDENT);
        _con_print(prefix + js_format_args(args));
    }
    _INDENT = _INDENT + 1;
    return js_undefined();
}

"""
console.groupCollapsed(...label) — same as group (no visual difference in ).
WHATWG Console §2.3.13
"""
def:pub js_console_groupCollapsed(args: list[JSValue]) -> JSValue {
    return js_console_group(args);
}

"""
console.groupEnd() — decrease indentation.
WHATWG Console §2.3.14
"""
def:pub js_console_groupEnd(args: list[JSValue]) -> JSValue {
    if _INDENT > 0 {
        _INDENT = _INDENT - 1;
    }
    return js_undefined();
}

# ══════════════════════════════════════════════════════════════════════════════
# 9.  table  (stub)
# ══════════════════════════════════════════════════════════════════════════════

"""
console.table(data, columns?) — ASCII table.
 stub: falls back to console.log display.
WHATWG Console §2.3.15
"""
def:pub js_console_table(args: list[JSValue]) -> JSValue {
    # Stub: display like console.dir
    return js_console_dir(args);
}
