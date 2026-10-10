"""NAPI Strings & Symbol.

Implements dispatch for ops 34–41:
  34  napi_create_string_utf8
  35  napi_create_string_utf16
  36  napi_create_string_latin1
  37  napi_get_value_string_utf8
  38  napi_get_value_string_utf16
  39  napi_get_value_string_latin1
  40  napi_create_symbol
  41  node_api_symbol_for

Encoding coverage
-----------------
- UTF-8:    Jac `str` is UTF-8-backed, so C UTF-8 buffers are copied
            byte-for-byte in both directions (no decode/re-encode).  All
            code points U+0000–U+10FFFF round-trip correctly.
- Latin-1:  1:1 byte↔code-point mapping (U+0000–U+00FF). Code points > 255
            in a JS string are truncated to their low byte on output.
- UTF-16:   BMP code units and surrogate pairs handled by
            js_string_from_utf16_code_units / js_string_utf16_units.

NAPI_AUTO_LENGTH handling
-------------------------
C callers pass NAPI_AUTO_LENGTH = (size_t)-1 packed as int64 → -1.
All _read_* helpers check `len < 0` and scan to the encoding's null terminator.

Bun reference:
  bun/src/bun.js/modules/NodeJSModule.zig  napi_create_string_utf8
  bun/src/bun.js/napi/napi.zig             napi_create_symbol, node_api_symbol_for
"""

import from "lib/libnapi_shim.so" {
    def _napi_argv_i64(argv: int, idx: int) -> int;  def _napi_write_i64(
        p: int, v: int
    ) -> int;
}
# Copy a Jac str's bytes (the FFI passes a str as its char *; a str holds no
# NUL byte, so strncpy of its exact length copies them all) — V4.26. Not
# memcpy: that name is bound elsewhere with an int source.
import from "libc.so.6" { def strncpy(dst: int, src: str, n: int) -> int;  }

import from engine.src.runtime.jsvalue {
    JSValue,
    jsv_is_string_cell,
    jsv_to_table_id,
    jsv_from_string_id
}

import from engine.src.runtime.jsstring {
    str_intern,
    str_from_id,
    str_get_realm,
    js_string_utf16_units,
    js_string_from_utf16_code_units,
    nul_sentinel,
    wire_utf8_needs_convert,
    wire_utf8_len,
    wire_utf8_write
}

import from engine.src.runtime.jssymbol { js_symbol, js_symbol_for }
import from engine.src.runtime.realm { Realm }
import from engine.src.runtime.mem { read_byte, write_byte, read_u16, byte_chr }

import from napi.src.napi_ops {
    NAPI_OP_CREATE_STRING_UTF8,
    NAPI_OP_CREATE_STRING_UTF16,
    NAPI_OP_CREATE_STRING_LATIN1,
    NAPI_OP_GET_VALUE_STRING_UTF8,
    NAPI_OP_GET_VALUE_STRING_UTF16,
    NAPI_OP_GET_VALUE_STRING_LATIN1,
    NAPI_OP_CREATE_SYMBOL,
    NAPI_OP_NODE_API_SYMBOL_FOR,
    NAPI_OK,
    NAPI_STRING_EXPECTED,
    NAPI_GENERIC_FAILURE
}

# Max bytes to scan for a null-terminated string (safety cap).
glob _MAX_STR_SCAN: int = 65536;

# ── Internal helpers ──────────────────────────────────────────────────────────

"""Copy a C UTF-8 byte buffer into a Jac (UTF-8-backed) string.

If len < 0 (NAPI_AUTO_LENGTH), scans until a null byte (0x00) is found.
Otherwise reads exactly `len` bytes.
"""
def _read_utf8(ptr: int, len: int) -> str {
    if ptr == 0 {
        return "";
    }
    # Jac `str` is UTF-8-backed and byte_chr(b) appends one byte, so copy the
    # C buffer's UTF-8 bytes verbatim (chr(b) would UTF-8-encode b >= 128).
    out: str = "";
    i: int = 0;
    if len < 0 {
        while i < _MAX_STR_SCAN {
            b: int = read_byte(ptr, i);
            if b == 0 {
                break;
            }
            out = out + byte_chr(b);
            i = i + 1;
        }
    } else {
        while i < len {
            rb: int = read_byte(ptr, i);
            if rb == 0 {
                out = out + nul_sentinel();  # U+0000 (a C string cannot hold 0x00)
            } else {
                out = out + byte_chr(rb);
            }
            i = i + 1;
        }
    }
    return out;
}

"""Write an engine string to a C char* buffer as true UTF-8.

At most bufsize-1 bytes, then a null terminator. Returns the bytes written
(excluding the NUL), or with a NULL buffer the full UTF-8 byte length.
"""
def _write_utf8(s: str, buf: int, bufsize: int) -> int {
    # napi's contract is the string's TRUE UTF-8 bytes. Engine strings are
    # CESU-8 plus the NUL sentinel C0 80 (jsstring.nul_sentinel), neither of
    # which is valid UTF-8: Rust addons (rollup's parser) panic on them, and a
    # byte length that differs from the real UTF-8 shifts every position the
    # addon reports (rollup's \0-prefixed virtual module ids: SWC returned
    # positions past the module and MagicString threw "range out of bounds").
    # The wire helpers convert both; the usual string needs no conversion and
    # is copied verbatim in one call.
    n: int = len(s);
    if s.isascii() or not wire_utf8_needs_convert(s) {
        if buf == 0 or bufsize == 0 {
            return n;
        }
        wu_n: int = n;
        if wu_n > bufsize - 1 {
            wu_n = bufsize - 1;
        }
        if wu_n > 0 {
            _ = strncpy(buf, s, wu_n);
        }
        write_byte(buf, wu_n, 0);
        return wu_n;
    }
    if buf == 0 or bufsize == 0 {
        return wire_utf8_len(s);
    }
    written: int = wire_utf8_write(s, buf, bufsize - 1);
    write_byte(buf, written, 0);
    # Node reports the number of bytes actually written (excluding the NUL).
    return written;
}

"""Read a Latin-1 byte buffer into a Jac Unicode string.

Latin-1 maps bytes 0x00–0xFF directly to Unicode U+0000–U+00FF.
If len < 0 (NAPI_AUTO_LENGTH), scans until a null byte.
"""
def _read_latin1(ptr: int, len: int) -> str {
    if ptr == 0 {
        return "";
    }
    out: str = "";
    i: int = 0;
    if len < 0 {
        while i < _MAX_STR_SCAN {
            b: int = read_byte(ptr, i);
            if b == 0 {
                return out;
            }
            out = out + byte_chr(b);
            i = i + 1;
        }
        return out;
    }
    while i < len {
        out = out + byte_chr(read_byte(ptr, i));
        i = i + 1;
    }
    return out;
}

"""Write a Jac Unicode string as Latin-1 bytes to a C char* buffer.

Code points > 255 are truncated to their low byte.
Copies at most bufsize-1 bytes then appends a null terminator.
Returns the number of bytes in the full string (without null).
"""
def _write_latin1(s: str, buf: int, bufsize: int) -> int {
    n: int = len(s);
    if buf != 0 and bufsize > 0 {
        copy: int = n;
        limit: int = bufsize - 1;
        if copy > limit {
            copy = limit;
        }
        i: int = 0;
        while i < copy {
            write_byte(buf, i, ord(s[i]) & 255);
            i = i + 1;
        }
        write_byte(buf, copy, 0);
    }
    return n;
}

"""Read a UTF-16LE encoded C string into a list of code units.

If len < 0 (NAPI_AUTO_LENGTH), scans until a null code unit (0x0000) is found.
Otherwise reads exactly `len` code units (each 2 bytes).
"""
def _read_utf16(ptr: int, len: int) -> list[int] {
    units: list[int] = [];
    if ptr == 0 {
        return units;
    }
    i: int = 0;
    if len < 0 {
        while i < _MAX_STR_SCAN {
            u: int = read_u16(ptr, i * 2);
            if u == 0 {
                return units;
            }
            units.append(u);
            i = i + 1;
        }
        return units;
    }
    while i < len {
        units.append(read_u16(ptr, i * 2));
        i = i + 1;
    }
    return units;
}

"""Write UTF-16LE code units to a C char16_t* buffer.

Copies at most bufsize-1 code units then appends a null code unit.
Returns the number of code units in the full string (without null).
"""
def _write_utf16(units: list[int], buf: int, bufsize: int) -> int {
    n: int = len(units);
    if buf != 0 and bufsize > 0 {
        copy: int = n;
        limit: int = bufsize - 1;
        if copy > limit {
            copy = limit;
        }
        i: int = 0;
        while i < copy {
            u: int = units[i];
            write_byte(buf, i * 2, u & 255);
            write_byte(buf, i * 2 + 1, (u >> 8) & 255);
            i = i + 1;
        }
        # null char16_t terminator (2 bytes)
        write_byte(buf, copy * 2, 0);
        write_byte(buf, copy * 2 + 1, 0);
    }
    return n;
}

def _h_create_string_utf8(argv: int) -> int {
    ptr: int = _napi_argv_i64(argv, 1);
    ln: int = _napi_argv_i64(argv, 2);
    rp: int = _napi_argv_i64(argv, 3);
    s: str = _read_utf8(ptr, ln);
    id: int = str_intern(s);
    _napi_write_i64(rp, jsv_from_string_id(id));
    return NAPI_OK;
}

def _h_create_string_utf16(argv: int) -> int {
    ptr: int = _napi_argv_i64(argv, 1);
    ln: int = _napi_argv_i64(argv, 2);
    rp: int = _napi_argv_i64(argv, 3);
    units: list[int] = _read_utf16(ptr, ln);
    s: str = js_string_from_utf16_code_units(units);
    id: int = str_intern(s);
    _napi_write_i64(rp, jsv_from_string_id(id));
    return NAPI_OK;
}

def _h_create_string_latin1(argv: int) -> int {
    # Latin-1 bytes map 1:1 to Unicode code points U+0000–U+00FF.
    ptr: int = _napi_argv_i64(argv, 1);
    ln: int = _napi_argv_i64(argv, 2);
    rp: int = _napi_argv_i64(argv, 3);
    s: str = _read_latin1(ptr, ln);
    id: int = str_intern(s);
    _napi_write_i64(rp, jsv_from_string_id(id));
    return NAPI_OK;
}

# ── Get-value-string handlers ─────────────────────────────────────────────────

def _h_get_value_string_utf8(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    buf: int = _napi_argv_i64(argv, 2);
    bsz: int = _napi_argv_i64(argv, 3);
    rp: int = _napi_argv_i64(argv, 4);
    if v != 0 and not jsv_is_string_cell(v) {
        return NAPI_STRING_EXPECTED;
    }
    s: str = str_from_id(jsv_to_table_id(v));
    n: int = _write_utf8(s, buf, bsz);
    if rp != 0 {
        _napi_write_i64(rp, n);
    }
    return NAPI_OK;
}

def _h_get_value_string_utf16(argv: int) -> int {
    v: int = _napi_argv_i64(argv, 1);
    buf: int = _napi_argv_i64(argv, 2);
    bsz: int = _napi_argv_i64(argv, 3);
    rp: int = _napi_argv_i64(argv, 4);
    if v != 0 and not jsv_is_string_cell(v) {
        return NAPI_STRING_EXPECTED;
    }
    s: str = str_from_id(jsv_to_table_id(v));
    units: list[int] = js_string_utf16_units(s);
    n: int = _write_utf16(units, buf, bsz);
    if rp != 0 {
        _napi_write_i64(rp, n);
    }
    return NAPI_OK;
}

def _h_get_value_string_latin1(argv: int) -> int {
    # Code points > 255 truncate to low byte (defined Latin-1 behaviour).
    v: int = _napi_argv_i64(argv, 1);
    buf: int = _napi_argv_i64(argv, 2);
    bsz: int = _napi_argv_i64(argv, 3);
    rp: int = _napi_argv_i64(argv, 4);
    if v != 0 and not jsv_is_string_cell(v) {
        return NAPI_STRING_EXPECTED;
    }
    s: str = str_from_id(jsv_to_table_id(v));
    n: int = _write_latin1(s, buf, bsz);
    if rp != 0 {
        _napi_write_i64(rp, n);
    }
    return NAPI_OK;
}

# ── Symbol handlers ───────────────────────────────────────────────────────────

def _h_create_symbol(argv: int) -> int {
    # argv[1] = napi_value description (may be 0/null/undefined = no description)
    # argv[2] = napi_value* result
    desc_jsv: int = _napi_argv_i64(argv, 1);
    rp: int = _napi_argv_i64(argv, 2);
    desc_str: str = "";
    if desc_jsv != 0 and jsv_is_string_cell(desc_jsv) {
        desc_str = str_from_id(jsv_to_table_id(desc_jsv));
    }
    realm: Realm = str_get_realm();
    sym: JSValue = js_symbol(realm, desc_str);
    _napi_write_i64(rp, sym);
    return NAPI_OK;
}

def _h_symbol_for(argv: int) -> int {
    # argv[1] = const char* utf8description
    # argv[2] = size_t length
    # argv[3] = napi_value* result
    ptr: int = _napi_argv_i64(argv, 1);
    ln: int = _napi_argv_i64(argv, 2);
    rp: int = _napi_argv_i64(argv, 3);
    key: str = _read_utf8(ptr, ln);
    realm: Realm = str_get_realm();
    sym: JSValue = js_symbol_for(realm, key);
    _napi_write_i64(rp, sym);
    return NAPI_OK;
}

# ── Sub-dispatcher (called from napi_dispatch.na.jac for ops 34–41) ───────────

def:pub _dispatch_string(op: int, argv: int) -> int {
    if op == NAPI_OP_CREATE_STRING_UTF8 {
        return _h_create_string_utf8(argv);
    } elif op == NAPI_OP_CREATE_STRING_UTF16 {
        return _h_create_string_utf16(argv);
    } elif op == NAPI_OP_CREATE_STRING_LATIN1 {
        return _h_create_string_latin1(argv);
    } elif op == NAPI_OP_GET_VALUE_STRING_UTF8 {
        return _h_get_value_string_utf8(argv);
    } elif op == NAPI_OP_GET_VALUE_STRING_UTF16 {
        return _h_get_value_string_utf16(argv);
    } elif op == NAPI_OP_GET_VALUE_STRING_LATIN1 {
        return _h_get_value_string_latin1(argv);
    } elif op == NAPI_OP_CREATE_SYMBOL {
        return _h_create_symbol(argv);
    } elif op == NAPI_OP_NODE_API_SYMBOL_FOR {
        return _h_symbol_for(argv);
    }
    return NAPI_GENERIC_FAILURE;
}
