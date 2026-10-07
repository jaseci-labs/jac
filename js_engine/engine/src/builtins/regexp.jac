"""Built-in: RegExp — Phase 2.9 (PCRE2 backend).

Regular expressions are compiled once (via pcre2_compile_8) and cached in
_RE_REALM.regexps.  Each match call allocates a fresh match_data block, reads
the ovector, then frees it.

PCRE2 ovector layout (x86-64, size_t = uint64):
  ov[0], ov[1]  —  full match  [start, end)  byte offsets
  ov[2], ov[3]  —  capture group 1
  …
  PCRE2_UNSET (= -1 as i64) means "group did not participate"

For ASCII/Latin-1 subjects: PCRE2 byte offsets == Jac character indices.

ECMAScript spec : §22.2 — RegExp Objects
Bun reference   : bun/src/bun.js/bindings/RegExpObject.zig
PCRE2 reference : https://www.pcre.org/current/doc/html/
"""

import from engine.src.ffi.libpcre2 {
    pcre2_compile_8,
    pcre2_compile_context_create_8,
    pcre2_set_max_varlookbehind_8,
    pcre2_compile_context_free_8,
    pcre2_set_compile_extra_options_8,
    pcre2_match_data_create_from_pattern_8,
    pcre2_match_data_free_8,
    pcre2_match_context_create_8,
    pcre2_match_context_free_8,
    pcre2_set_match_limit_8,
    pcre2_match_8,
    pcre2_get_ovector_pointer_8,
    pcre2_get_ovector_count_8,
    pcre2_pattern_info_8,
    pcre2_code_free_8
}
import from engine.src.runtime.mem { io_alloc, read_u64, read_u32, byte_chr }
import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    js_null,
    js_true,
    js_false,
    js_int,
    jsv_is_int32,
    jsv_is_double,
    jsv_is_null,
    jsv_is_string_cell,
    jsv_is_object_cell,
    jsv_is_undefined,
    jsv_to_int32,
    jsv_to_double,
    jsv_to_table_id,
    jsv_from_string_id,
    jsv_hole
}
import from engine.src.builtins.regexp_type { JSRegExpState }
import from engine.src.runtime.realm { Realm }
import from engine.src.runtime.jscell { CELL_FLAG_DEAD }  # G0.5: regexp slot tombstone
import from engine.src.runtime.jsstring {
    str_intern_index,
    str_intern,
    str_from_id,
    str_substr,
    str_heap,
    str_cell_ascii,
    js_string_byte_to_unit,
    js_string_unit_to_byte,
    js_string_utf16_len,
    utf8_encode_scalar,
    utf8_decode_str_to_codepoints,
    utf16_units_to_scalars
}
import from engine.src.runtime.jsobject {
    js_object_create_null,
    js_object_create,
    js_object_get,
    js_object_set,
    js_object_has_own,
    js_object_define_property,
    js_object_get_prototype,
    js_object_set_prototype,
    js_object_create_data_property_or_throw,
    JSProperty,
    KEY_LENGTH,
    SYMBOL_KEY_BASE,
    js_object_ic_shape,
    js_object_ic_hit,
    js_object_ic_set_hit,
    js_object_slot_at_id,
    js_object_proto_idx_id,
    js_object_elems_kind_id,
    js_object_get_own_accessor_getter
}
import from engine.src.runtime.jsobj_type { JSProperty, ELEMS_NONE }
import from engine.src.runtime.shape { shape_lookup, SHAPE_ATTR_ACCESSOR }
import from engine.src.builtins.array { _KEY_IS_ARRAY }
import from engine.src.builtins.markers { _KEY_IS_REGEXP_MARK }
import from engine.src.builtins.array { js_array_create }
import from engine.src.builtins.string { js_to_string_prim, js_coerce_to_string }
import from engine.src.vm.vm_obs { js_to_string_observable, js_to_number_observable }
import from engine.src.builtins.native_kinds {
    NATIVE_KIND_REGEXP,
    NATIVE_KIND_REGEXP_TEST,
    NATIVE_KIND_REGEXP_EXEC,
    NATIVE_KIND_REGEXP_TOSTRING,
    NATIVE_KIND_REGEXP_MATCHALL_NEXT,
    NATIVE_KIND_REGEXP_MATCHALL_ITER,
    NATIVE_KIND_REGEXP_SYMBOL_MATCH,
    NATIVE_KIND_REGEXP_SYMBOL_MATCHALL,
    NATIVE_KIND_REGEXP_SYMBOL_REPLACE,
    NATIVE_KIND_REGEXP_SYMBOL_SEARCH,
    NATIVE_KIND_REGEXP_SYMBOL_SPLIT
}
import from engine.src.builtins.native_registry {
    js_native_create,
    js_callable_create,
    is_native_val,
    get_native_kind
}
import from engine.src.runtime.error {
    make_syntax_error,
    make_type_error,
    vm_throw_native,
    vm_has_native_exc
}
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.runtime.jssymbol {
    SYMBOL_ITERATOR,
    SYMBOL_MATCH,
    SYMBOL_MATCH_ALL,
    SYMBOL_REPLACE,
    SYMBOL_SEARCH,
    SYMBOL_SPLIT,
    SYMBOL_SPECIES
}

# ══════════════════════════════════════════════════════════════════════════════
# 1.  PCRE2 option constants (must match /usr/include/pcre2.h)
# ══════════════════════════════════════════════════════════════════════════════

glob:priv PCRE2_CASELESS: int = 8,
     PCRE2_DOTALL: int = 32,
     PCRE2_MULTILINE: int = 1024,
     PCRE2_DUPNAMES: int = 64,
     PCRE2_MATCH_UNSET_BACKREF: int = 512,
     PCRE2_UTF: int = 524288,
     PCRE2_UCP: int = 131072,
     PCRE2_EXTRA_ALLOW_SURROGATE_ESCAPES: int = 1,
     PCRE2_INFO_CAPTURECOUNT: int = 4,
     U64_MAX: int = 18446744073709551615;  # 0x00000008  /i

# 0x00000020  /s
# 0x00000400  /m
# 0x00000040  allow duplicate (?<n>) names
# 0x00000200  \k to unset group → ""
# 0x00080000  /u or /v
# 0x00020000  Unicode properties
# compile-context extra option
# ══════════════════════════════════════════════════════════════════════════════
# 2.  Hidden property keys for RegExp objects
# ══════════════════════════════════════════════════════════════════════════════

"""Hidden key marking JSObject as a RegExp.  Value = int index into _RE_REALM.regexps."""
glob:pub _KEY_IS_REGEXP: int = 0;
glob:priv _KEY_MATCHALL_STATE: int = 0,
     _KEY_MATCHALL_INDEX: int = 0;

glob _REGEXP_PROTO: JSValue = js_undefined(),
     _K_LAST_INDEX: int = 0,
     _K_INDEX: int = 0,
     _K_INPUT: int = 0,
     _K_GROUPS: int = 0;


# ══════════════════════════════════════════════════════════════════════════════
# 4.  Compile helper
# ══════════════════════════════════════════════════════════════════════════════

def:pub regexp_seed_keys -> None {
    if _KEY_IS_REGEXP != 0 {
        return;
    }
    # Hidden numeric marker (>= BUILTIN_BASE) so it never surfaces as an own
    # property name — see markers.na.jac.
    _KEY_IS_REGEXP = _KEY_IS_REGEXP_MARK;
    _KEY_MATCHALL_STATE = str_intern("__regexp_matchall_state__");
    _KEY_MATCHALL_INDEX = str_intern("__regexp_matchall_index__");
    _K_LAST_INDEX = str_intern("lastIndex");
    _K_INDEX = str_intern("index");
    _K_INPUT = str_intern("input");
    _K_GROUPS = str_intern("groups");
}

def:pub js_regexp_set_proto(proto: JSValue) {
    _REGEXP_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

glob _RE_REALM: Realm,
     _RE_CACHE: dict[str, int] = {};

# O(1) cache keyed by "pattern\0flags" — see _get_or_compile.
def:pub re_set_realm(r: Realm) {
    _RE_REALM = r;
    # Realm swap invalidates index→state mapping; drop the O(1) cache.
    _RE_CACHE = {};
}

"""Scan `pattern` for `(?<name>...)` and plain `(` groups; one name entry per
capturing group in order (empty string if unnamed)."""
def _extract_group_names(pattern: str) -> list[str] {
    names: list[str] = [];
    i: int = 0;
    escaped: bool = False;
    in_class: bool = False;
    while i < len(pattern) {
        ch: str = pattern[i];
        if escaped {
            escaped = False;
            i = i + 1;
            continue;
        }
        if ch == "\\" {
            escaped = True;
            i = i + 1;
            continue;
        }
        if ch == "[" {
            in_class = True;
            i = i + 1;
            continue;
        }
        if ch == "]" and in_class {
            in_class = False;
            i = i + 1;
            continue;
        }
        if in_class {
            i = i + 1;
            continue;
        }
        if ch == "(" {
            # `(?<=` / `(?<!` before `(?<name>` — same `(?<` prefix; lookbehind is not a named group.
            if i + 3 < len(pattern)
                and pattern[i + 1] == "?"
                and pattern[i + 2] == "<"
                and (pattern[i + 3] == "=" or pattern[i + 3] == "!") {
                i = i + 1;
                continue;
            } elif i + 2 < len(pattern)
                and pattern[i + 1] == "?"
                and pattern[i + 2] == "<" {
                j: int = i + 3;
                nm: str = "";
                while j < len(pattern) and pattern[j] != ">" {
                    nm = nm + pattern[j];
                    j = j + 1;
                }
                if j < len(pattern) {
                    names.append(nm);
                    i = j + 1;
                    continue;
                }
                names.append("");
            } elif i + 2 < len(pattern)
                and pattern[i + 1] == "?"
                and pattern[i + 2] == ":" {
                i = i + 1;
                continue;
            } elif i + 2 < len(pattern)
                and pattern[i + 1] == "?"
                and (pattern[i + 2] == "=" or pattern[i + 2] == "!") {
                i = i + 1;
                continue;
            } else {
                names.append("");
            }
        }
        i = i + 1;
    }
    return names;
}

# Error code from pcre2.h
glob:priv PCRE2_ERROR_LOOKBEHIND_NOT_FIXED_LENGTH: int = 125,
     MAX_VLB: int = 10000,
     PCRE2_MATCH_LIMIT: int = 1000000,
     VLB_QUANT_BOUND: int = 1000;

# Runtime limit we pass to pcre2_set_max_varlookbehind.  Must be larger than
# the quantifier bound used in _transform_vlb_quantifiers so that
# (?<=a\s{0,VLB_QUANT_BOUND}) total_len ≤ MAX_VLB.

# Backtracking step cap per match — prevents catastrophic Unicode property hangs.

# Quantifier bound used when transforming * -> {0,N} and + -> {1,N} inside lookbehinds.
# Must be significantly smaller than MAX_VLB to leave room for fixed-length atoms.
"""Transform unbounded quantifiers (* and +) inside lookbehind assertions
(?<=...) and (?<!...) into bounded ones so PCRE2 10.45 can compile them.

  (?<=\\s*)   →  (?<=\\s{0,255})
  (?<=\\s+)   →  (?<=\\s{1,255})

PCRE2 10.45 with pcre2_set_max_varlookbehind(255) can handle bounded variable
lookbehinds but still rejects unbounded ones (error 125).  This pre-pass bounds
them at 255 characters — far beyond any practical JS source.

The scan is character-by-character so that escaped chars (\\*) and character
classes ([*]) are handled correctly.
"""
def _transform_vlb_quantifiers(pattern: str) -> str {
    result: str = "";
    i: int = 0;
    n: int = len(pattern);
    in_charclass: bool = False;
    # Stack: 1 if this group is a lookbehind ((?<= or (?<!), 0 otherwise.
    vlb_stack: list[int] = [];

    while i < n {
        c: str = pattern[i];

        # ── Inside a character class: pass through until unescaped ] ──────
        if in_charclass {
            result = result + c;
            if c == "\\" and i + 1 < n {
                result = result + pattern[i + 1];
                i = i + 2;
            } elif c == "]" {
                in_charclass = False;
                i = i + 1;
            } else {
                i = i + 1;
            }
            continue;
        }

        # ── Escape sequence: two chars, pass through ───────────────────────
        if c == "\\" {
            result = result + c;
            if i + 1 < n {
                result = result + pattern[i + 1];
                i = i + 2;
            } else {
                i = i + 1;
            }
            continue;
        }

        # ── Start of character class ───────────────────────────────────────
        if c == "[" {
            result = result + c;
            in_charclass = True;
            i = i + 1;
            continue;
        }

        # ── Start of group ─────────────────────────────────────────────────
        if c == "(" {
            is_vlb: int = 0;
            # Detect (?<= and (?<!  (lookbehind markers)
            if i + 3 < n {
                if pattern[i + 1] == "?" and pattern[i + 2] == "<" {
                    if pattern[i + 3] == "=" or pattern[i + 3] == "!" {
                        is_vlb = 1;
                    }
                }
            }
            vlb_stack.append(is_vlb);
            result = result + c;
            i = i + 1;
            continue;
        }

        # ── End of group ───────────────────────────────────────────────────
        if c == ")" {
            if len(vlb_stack) > 0 {
                del vlb_stack[len(vlb_stack) - 1];
            }
            result = result + c;
            i = i + 1;
            continue;
        }

        # ── Check if inside any lookbehind context ─────────────────────────
        in_vlb: bool = False;
        j_v: int = 0;
        while j_v < len(vlb_stack) {
            if vlb_stack[j_v] == 1 {
                in_vlb = True;
            }
            j_v = j_v + 1;
        }

        # ── Transform unbounded quantifiers inside lookbehinds ─────────────
        if in_vlb and c == "*" {
            result = result + "{0," + str(VLB_QUANT_BOUND) + "}";
            i = i + 1;
            continue;
        }
        if in_vlb and c == "+" {
            result = result + "{1," + str(VLB_QUANT_BOUND) + "}";
            i = i + 1;
            continue;
        }
        # `{n,}` / `{,}` open-ended forms → bound the upper end so PCRE2's
        # max_varlookbehind accepts them (ES lookbehind allows these).
        if in_vlb and c == "{" {
            j: int = i + 1;
            digits: str = "";
            while j < n {
                cj: str = pattern[j];
                if cj >= "0" and cj <= "9" {
                    digits = digits + cj;
                    j = j + 1;
                } else {
                    break;
                }
            }
            if j < n and pattern[j] == "," {
                j2: int = j + 1;
                upper: str = "";
                while j2 < n {
                    cj2: str = pattern[j2];
                    if cj2 >= "0" and cj2 <= "9" {
                        upper = upper + cj2;
                        j2 = j2 + 1;
                    } else {
                        break;
                    }
                }
                if j2 < n and pattern[j2] == "}" and upper == "" {
                    # `{n,}` or `{,}` → `{n,BOUND}` / `{0,BOUND}`
                    lo: str = digits;
                    if lo == "" {
                        lo = "0";
                    }
                    result = result + "{" + lo + "," + str(VLB_QUANT_BOUND) + "}";
                    i = j2 + 1;
                    continue;
                }
            }
        }

        result = result + c;
        i = i + 1;
    }

    return result;
}

# ══════════════════════════════════════════════════════════════════════════════
# 4b.  ES2024 unicodeSets (/v) → PCRE2 rewrite
# ══════════════════════════════════════════════════════════════════════════════
# PCRE2 has no ClassSetExpression (nested classes, &&, --, \q{…}).  When the
# `v` flag is set we lower those forms to lookarounds / alternations before
# compile.  Small property-of-strings (\p{Emoji_Keycap_Sequence}) are expanded;
# large ones (\p{RGI_Emoji}) are left for PCRE2 to reject as SyntaxError.
#
# NOTE: Jac string literals cannot embed a real NUL (`chr(0) == ""`), so \q
# alternatives are kept as list[str] — never joined with "\x00".

glob:priv _US_S: str = "",
     _US_I: int = 0,
     _US_N: int = 0,
     _US_ERR: bool = False,
     _US_LAST_QALTS: list[str] = [];

# Non-empty when the last operand came from \q{…} / property-of-strings.
def _us_reset(s: str) {
    _US_S = s;
    _US_I = 0;
    _US_N = len(s);
    _US_ERR = False;
    _US_LAST_QALTS = [];
}

def _us_peek -> str {
    if _US_I >= _US_N {
        return "";
    }
    return _US_S[_US_I];
}

def _us_starts(lit: str) -> bool {
    n: int = len(lit);
    if _US_I + n > _US_N {
        return False;
    }
    j: int = 0;
    while j < n {
        if _US_S[_US_I + j] != lit[j] {
            return False;
        }
        j = j + 1;
    }
    return True;
}

def _us_adv(k: int) {
    _US_I = _US_I + k;
}

"""True if `name` is a Unicode property-of-strings (needs string-set lowering)."""
def _us_is_pos_name(name: str) -> bool {
    return name == "Emoji_Keycap_Sequence";
}

"""Return the finite string set for a known property-of-strings, else []."""
def _us_pos_alts(name: str) -> list[str] {
    out: list[str] = [];
    if name == "Emoji_Keycap_Sequence" {
        # 12 keycap sequences: [#*0-9] + VS16 + combining enclosing keycap
        out.append("#\\uFE0F\\u20E3");
        out.append("*\\uFE0F\\u20E3");
        out.append("0\\uFE0F\\u20E3");
        out.append("1\\uFE0F\\u20E3");
        out.append("2\\uFE0F\\u20E3");
        out.append("3\\uFE0F\\u20E3");
        out.append("4\\uFE0F\\u20E3");
        out.append("5\\uFE0F\\u20E3");
        out.append("6\\uFE0F\\u20E3");
        out.append("7\\uFE0F\\u20E3");
        out.append("8\\uFE0F\\u20E3");
        out.append("9\\uFE0F\\u20E3");
    }
    return out;
}

"""True if a /v class body needs set-notation lowering."""
def _us_body_needs_rewrite(body: str) -> bool {
    i: int = 0;
    n: int = len(body);
    while i < n {
        c: str = body[i];
        if c == "\\" and i + 1 < n {
            nxt: str = body[i + 1];
            if nxt == "q" {
                return True;
            }
            if nxt == "p" or nxt == "P" {
                # \p{Name} / \P{Name} — rewrite when Name is property-of-strings.
                if i + 2 < n and body[i + 2] == "{" {
                    j: int = i + 3;
                    nm: str = "";
                    while j < n and body[j] != "}" {
                        nm = nm + body[j];
                        j = j + 1;
                    }
                    if _us_is_pos_name(nm) {
                        return True;
                    }
                }
            }
            i = i + 2;
            continue;
        }
        if c == "[" {
            return True;
        }
        if c == "&" and i + 1 < n and body[i + 1] == "&" {
            return True;
        }
        if c == "-" and i + 1 < n and body[i + 1] == "-" {
            return True;
        }
        i = i + 1;
    }
    return False;
}

"""Escape a \q alternative for use outside a character class."""
def _us_escape_outside(s: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(s);
    while i < n {
        if s[i] == "\\" and i + 1 < n {
            out = out + "\\";
            i = i + 1;
            c: str = s[i];
            out = out + c;
            i = i + 1;
            if (c == "p" or c == "P") and i < n and s[i] == "{" {
                out = out + "{";
                i = i + 1;
                while i < n and s[i] != "}" {
                    out = out + s[i];
                    i = i + 1;
                }
                if i < n and s[i] == "}" {
                    out = out + "}";
                    i = i + 1;
                }
            } elif c == "u" {
                if i < n and s[i] == "{" {
                    out = out + "{";
                    i = i + 1;
                    while i < n and s[i] != "}" {
                        out = out + s[i];
                        i = i + 1;
                    }
                    if i < n and s[i] == "}" {
                        out = out + "}";
                        i = i + 1;
                    }
                } else {
                    k: int = 0;
                    while k < 4 and i < n {
                        out = out + s[i];
                        i = i + 1;
                        k = k + 1;
                    }
                }
            } elif c == "x" {
                k2: int = 0;
                while k2 < 2 and i < n {
                    out = out + s[i];
                    i = i + 1;
                    k2 = k2 + 1;
                }
            }
            continue;
        }
        c2: str = s[i];
        if (
            c2 == "\\"
            or c2 == "."
            or c2 == "^"
            or c2 == "$"
            or c2 == "*"
            or c2 == "+"
            or c2 == "?"
            or c2 == "("
            or c2 == ")"
            or c2 == "["
            or c2 == "]"
            or c2 == "{"
            or c2 == "}"
            or c2 == "|"
        ) {
            out = out + "\\" + c2;
        } else {
            out = out + c2;
        }
        i = i + 1;
    }
    return out;
}

"""Advance past one ClassSetCharacter / escape; returns consumed fragment."""
def _us_consume_escape_or_char -> str {
    start: int = _US_I;
    if _US_I >= _US_N {
        _US_ERR = True;
        return "";
    }
    if _us_peek() != "\\" {
        _us_adv(1);
        return _US_S[start:_US_I];
    }
    _us_adv(1);
    if _US_I >= _US_N {
        _US_ERR = True;
        return "";
    }
    c: str = _us_peek();
    _us_adv(1);
    if c == "p" or c == "P" {
        if _us_peek() != "{" {
            _US_ERR = True;
            return "";
        }
        _us_adv(1);
        while _US_I < _US_N and _us_peek() != "}" {
            _us_adv(1);
        }
        if _us_peek() != "}" {
            _US_ERR = True;
            return "";
        }
        _us_adv(1);
    } elif c == "u" {
        if _us_peek() == "{" {
            _us_adv(1);
            while _US_I < _US_N and _us_peek() != "}" {
                _us_adv(1);
            }
            if _us_peek() == "}" {
                _us_adv(1);
            }
        } else {
            k: int = 0;
            while k < 4 and _US_I < _US_N {
                _us_adv(1);
                k = k + 1;
            }
        }
    } elif c == "x" {
        k2: int = 0;
        while k2 < 2 and _US_I < _US_N {
            _us_adv(1);
            k2 = k2 + 1;
        }
    }
    # else: single-char escape (\d, \w, \n, …) — already consumed
    return _US_S[start:_US_I];
}

"""True if a \q alternative is a single code point (possibly via \\u / \\x)."""
def _us_alt_is_single_cp(alt: str) -> bool {
    if alt == "" {
        return False;
    }
    if alt[0] != "\\" {
        if len(alt) > 4 {
            return False;
        }
        if len(alt) == 1 {
            return True;
        }
        b0: int = ord(alt[0]);
        if b0 >= 192 and b0 < 224 and len(alt) == 2 {
            return True;
        }
        if b0 >= 224 and b0 < 240 and len(alt) == 3 {
            return True;
        }
        if b0 >= 240 and b0 < 248 and len(alt) == 4 {
            return True;
        }
        return False;
    }
    if len(alt) >= 2 and alt[1] == "u" {
        if len(alt) >= 3 and alt[2] == "{" {
            j: int = 3;
            while j < len(alt) and alt[j] != "}" {
                j = j + 1;
            }
            return j < len(alt) and j + 1 == len(alt);
        }
        return len(alt) == 6;
    }
    if len(alt) >= 2 and alt[1] == "x" {
        return len(alt) == 4;
    }
    return len(alt) == 2;
}

def _us_emit_union(parts: list[str]) -> str {
    if len(parts) == 0 {
        return "[^\\s\\S]";
    }
    if len(parts) == 1 {
        return parts[0];
    }
    out: str = "(?:" + parts[0];
    i: int = 1;
    while i < len(parts) {
        out = out + "|" + parts[i];
        i = i + 1;
    }
    return out + ")";
}

"""Build (?:alt|alt|…) from raw \q / property-of-strings alternatives."""
def _us_alts_to_atom(alts: list[str]) -> str {
    if len(alts) == 0 {
        return "[^\\s\\S]";
    }
    esc_parts: list[str] = [];
    ai: int = 0;
    while ai < len(alts) {
        esc_parts.append(_us_escape_outside(alts[ai]));
        ai = ai + 1;
    }
    return _us_emit_union(esc_parts);
}

def _us_list_contains(alts: list[str], s: str) -> bool {
    i: int = 0;
    while i < len(alts) {
        if alts[i] == s {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def _us_list_intersect(a: list[str], b: list[str]) -> list[str] {
    out: list[str] = [];
    i: int = 0;
    while i < len(a) {
        if _us_list_contains(b, a[i]) {
            out.append(a[i]);
        }
        i = i + 1;
    }
    return out;
}

def _us_list_subtract(a: list[str], b: list[str]) -> list[str] {
    out: list[str] = [];
    i: int = 0;
    while i < len(a) {
        if not _us_list_contains(b, a[i]) {
            out.append(a[i]);
        }
        i = i + 1;
    }
    return out;
}

def _us_emit_intersect(parts: list[str], qalts: list[list[str]]) -> str {
    str_sets: list[list[str]] = [];
    char_parts: list[str] = [];
    k: int = 0;
    while k < len(parts) {
        if len(qalts[k]) > 0 {
            str_sets.append(qalts[k]);
        } else {
            char_parts.append(parts[k]);
        }
        k = k + 1;
    }
    if len(str_sets) > 0 {
        result: list[str] = str_sets[0];
        si: int = 1;
        while si < len(str_sets) {
            result = _us_list_intersect(result, str_sets[si]);
            si = si + 1;
        }
        if len(char_parts) > 0 {
            # Code-point class ∩ string-set: only single-CP strings can remain.
            filtered: list[str] = [];
            ri: int = 0;
            while ri < len(result) {
                if _us_alt_is_single_cp(result[ri]) {
                    filtered.append(_us_escape_outside(result[ri]));
                }
                ri = ri + 1;
            }
            if len(filtered) == 0 {
                return "[^\\s\\S]";
            }
            core: str = _us_emit_union(filtered);
            ci: int = 0;
            while ci < len(char_parts) {
                core = "(?=" + char_parts[ci] + ")" + core;
                ci = ci + 1;
            }
            return "(?:" + core + ")";
        }
        return _us_alts_to_atom(result);
    }
    # Character-class operands only: (?=A)(?=B)…C
    if len(char_parts) == 0 {
        return "[^\\s\\S]";
    }
    core2: str = char_parts[len(char_parts) - 1];
    j: int = len(char_parts) - 2;
    while j >= 0 {
        core2 = "(?=" + char_parts[j] + ")" + core2;
        j = j - 1;
    }
    return "(?:" + core2 + ")";
}

def _us_emit_subtract(parts: list[str], qalts: list[list[str]]) -> str {
    if len(parts) == 0 {
        return "[^\\s\\S]";
    }
    # String-set minuend: prefer explicit set difference.  Lookaheads like
    # (?!0) would wrongly reject multi-CP strings that merely start with 0.
    if len(qalts[0]) > 0 {
        result: list[str] = qalts[0];
        i: int = 1;
        while i < len(parts) {
            if len(qalts[i]) > 0 {
                result = _us_list_subtract(result, qalts[i]);
            } else {
                # Minus a code-point class: multi-CP alts always survive;
                # single-CP alts are kept only when they fail the class.
                next_res: list[str] = [];
                singles: list[str] = [];
                ri: int = 0;
                while ri < len(result) {
                    if _us_alt_is_single_cp(result[ri]) {
                        singles.append(result[ri]);
                    } else {
                        next_res.append(result[ri]);
                    }
                    ri = ri + 1;
                }
                if len(singles) == 0 {
                    result = next_res;
                } elif len(next_res) == 0 {
                    # Only singles: (?!class)(?:s1|s2|…)
                    s_atom: str = "(?!" + parts[i] + ")" + _us_alts_to_atom(singles);
                    # Further subtrahends wrap the guarded singles atom.
                    i = i + 1;
                    while i < len(parts) {
                        if len(qalts[i]) > 0 {
                            s_atom = "(?!" + _us_alts_to_atom(qalts[i]) + ")" + s_atom;
                        } else {
                            s_atom = "(?!" + parts[i] + ")" + s_atom;
                        }
                        i = i + 1;
                    }
                    return "(?:" + s_atom + ")";
                } else {
                    # Mix multis with guarded singles.
                    s_atom2: str = "(?!" + parts[i] + ")" + _us_alts_to_atom(singles);
                    mix: list[str] = [];
                    mix.append(_us_alts_to_atom(next_res));
                    mix.append("(?:" + s_atom2 + ")");
                    i = i + 1;
                    atom: str = _us_emit_union(mix);
                    while i < len(parts) {
                        if len(qalts[i]) > 0 {
                            atom = "(?!" + _us_alts_to_atom(qalts[i]) + ")" + atom;
                        } else {
                            atom = "(?!" + parts[i] + ")" + atom;
                        }
                        i = i + 1;
                    }
                    return "(?:" + atom + ")";
                }
            }
            i = i + 1;
        }
        return _us_alts_to_atom(result);
    }
    # Character-class minuend: (?!sub)…core
    core: str = parts[0];
    i2: int = 1;
    while i2 < len(parts) {
        if len(qalts[i2]) > 0 {
            qi: int = 0;
            while qi < len(qalts[i2]) {
                core = "(?!" + _us_escape_outside(qalts[i2][qi]) + ")" + core;
                qi = qi + 1;
            }
        } else {
            core = "(?!" + parts[i2] + ")" + core;
        }
        i2 = i2 + 1;
    }
    return "(?:" + core + ")";
}

"""Parse \q{a|b|c} → (?:a|b|c); sets _US_LAST_QALTS to the alt list."""
def _us_parse_q -> str {
    _US_LAST_QALTS = [];
    if not _us_starts("\\q") {
        _US_ERR = True;
        return "";
    }
    _us_adv(2);
    if _us_peek() != "{" {
        _US_ERR = True;
        return "";
    }
    _us_adv(1);
    alts: list[str] = [];
    cur: str = "";
    while _US_I < _US_N and _us_peek() != "}" {
        if _us_peek() == "\\" {
            frag: str = _us_consume_escape_or_char();
            if _US_ERR {
                return "";
            }
            cur = cur + frag;
        } elif _us_peek() == "|" {
            alts.append(cur);
            cur = "";
            _us_adv(1);
        } else {
            cur = cur + _us_peek();
            _us_adv(1);
        }
    }
    if _us_peek() != "}" {
        _US_ERR = True;
        return "";
    }
    _us_adv(1);
    alts.append(cur);
    _US_LAST_QALTS = alts;
    return _us_alts_to_atom(alts);
}

"""Peek \\p{Name} at _US_I; return Name or \"\" if not a \\p{/\\P{ form."""
def _us_peek_prop_name -> str {
    if not (_us_starts("\\p{") or _us_starts("\\P{")) {
        return "";
    }
    j: int = _US_I + 3;
    nm: str = "";
    while j < _US_N and _US_S[j] != "}" {
        nm = nm + _US_S[j];
        j = j + 1;
    }
    if j >= _US_N {
        return "";
    }
    return nm;
}

def _us_parse_operand -> str {
    _US_LAST_QALTS = [];
    if _us_peek() == "[" {
        return _us_parse_class();
    }
    if _us_starts("\\q") {
        return _us_parse_q();
    }
    # Property-of-strings: expand to a string-set operand.
    pnm: str = _us_peek_prop_name();
    if pnm != "" and _us_is_pos_name(pnm) and _us_starts("\\p{") {
        _us_adv(3);
        while _US_I < _US_N and _us_peek() != "}" {
            _us_adv(1);
        }
        if _us_peek() != "}" {
            _US_ERR = True;
            return "";
        }
        _us_adv(1);
        alts: list[str] = _us_pos_alts(pnm);
        _US_LAST_QALTS = alts;
        return _us_alts_to_atom(alts);
    }
    start: int = _US_I;
    frag: str = _us_consume_escape_or_char();
    if _US_ERR {
        return "";
    }
    # Range: char - char, but not the -- operator.
    if (
        _us_peek() == "-"
        and not _us_starts("--")
        and _US_I + 1 < _US_N
        and _us_peek() != "]"
    ) {
        if _US_I + 1 < _US_N {
            nxt: str = _US_S[_US_I + 1];
            if nxt != "]" and nxt != "" {
                _us_adv(1);
                _us_consume_escape_or_char();
                if _US_ERR {
                    return "";
                }
            }
        }
    }
    return "[" + _US_S[start:_US_I] + "]";
}

def _us_parse_expr -> str {
    parts: list[str] = [];
    qalts: list[list[str]] = [];
    a0: str = _us_parse_operand();
    if _US_ERR {
        return "";
    }
    parts.append(a0);
    qalts.append(_US_LAST_QALTS);

    if _us_starts("&&") {
        while _us_starts("&&") {
            _us_adv(2);
            ai: str = _us_parse_operand();
            if _US_ERR {
                return "";
            }
            parts.append(ai);
            qalts.append(_US_LAST_QALTS);
        }
        return _us_emit_intersect(parts, qalts);
    }
    if _us_starts("--") {
        while _us_starts("--") {
            _us_adv(2);
            asub: str = _us_parse_operand();
            if _US_ERR {
                return "";
            }
            parts.append(asub);
            qalts.append(_US_LAST_QALTS);
        }
        return _us_emit_subtract(parts, qalts);
    }
    # Union (juxtaposition).  Flatten string-set alts into the union list.
    if len(qalts[0]) > 0 {
        parts = [];
        fi: int = 0;
        while fi < len(qalts[0]) {
            parts.append(_us_escape_outside(qalts[0][fi]));
            fi = fi + 1;
        }
    }
    while _US_I < _US_N and _us_peek() != "" {
        if _us_starts("&&") or _us_starts("--") {
            break;
        }
        _US_LAST_QALTS = [];
        ai2: str = _us_parse_operand();
        if _US_ERR {
            return "";
        }
        if len(_US_LAST_QALTS) > 0 {
            fj: int = 0;
            while fj < len(_US_LAST_QALTS) {
                parts.append(_us_escape_outside(_US_LAST_QALTS[fj]));
                fj = fj + 1;
            }
        } else {
            parts.append(ai2);
        }
    }
    return _us_emit_union(parts);
}

"""Parse a [ClassSetExpression] / [^ClassSetExpression] at _US_I."""
def _us_parse_class -> str {
    if _us_peek() != "[" {
        _US_ERR = True;
        return "";
    }
    _us_adv(1);
    neg: bool = False;
    if _us_peek() == "^" {
        neg = True;
        _us_adv(1);
    }
    # Empty class [] / [^]
    if _us_peek() == "]" {
        _us_adv(1);
        if neg {
            return "[\\s\\S]";
        }
        return "[^\\s\\S]";
    }
    body_start: int = _US_I;
    depth: int = 0;
    while _US_I < _US_N {
        c: str = _us_peek();
        if c == "\\" and _US_I + 1 < _US_N {
            _us_adv(2);
            continue;
        }
        if c == "[" {
            depth = depth + 1;
            _us_adv(1);
            continue;
        }
        if c == "]" {
            if depth == 0 {
                body: str = _US_S[body_start:_US_I];
                _us_adv(1);
                if not _us_body_needs_rewrite(body) {
                    if neg {
                        return "[^" + body + "]";
                    }
                    return "[" + body + "]";
                }
                # Parse body as ClassSetExpression in a nested reset.
                saved_s: str = _US_S;
                saved_i: int = _US_I;
                saved_n: int = _US_N;
                saved_err: bool = _US_ERR;
                _us_reset(body);
                atom: str = _us_parse_expr();
                nest_err: bool = _US_ERR;
                # Restore outer cursor (already past ']').
                _US_S = saved_s;
                _US_N = saved_n;
                _US_I = saved_i;
                _US_ERR = saved_err;
                if nest_err or atom == "" {
                    _US_ERR = True;
                    return "";
                }
                if neg {
                    return "(?:(?!" + atom + ")[\\s\\S])";
                }
                return atom;
            }
            depth = depth - 1;
            _us_adv(1);
            continue;
        }
        _us_adv(1);
    }
    _US_ERR = True;
    return "";
}

"""Rewrite ES /v character-class set notation into PCRE2-legal atoms."""
def _rewrite_unicode_sets(pattern: str) -> str {
    out: str = "";
    _us_reset(pattern);
    while _US_I < _US_N {
        c: str = _us_peek();
        if c == "\\" and _US_I + 1 < _US_N {
            # Top-level property-of-strings: \p{Emoji_Keycap_Sequence}
            pnm: str = _us_peek_prop_name();
            if pnm != "" and _us_is_pos_name(pnm) and _us_starts("\\p{") {
                _us_adv(3);
                while _US_I < _US_N and _us_peek() != "}" {
                    _us_adv(1);
                }
                if _us_peek() == "}" {
                    _us_adv(1);
                }
                out = out + _us_alts_to_atom(_us_pos_alts(pnm));
                continue;
            }
            # Copy a full escape (\p{…}, \u{…}, \q is only legal in classes).
            start: int = _US_I;
            _us_consume_escape_or_char();
            if _US_ERR {
                return pattern;
            }
            out = out + _US_S[start:_US_I];
            continue;
        }
        if c == "[" {
            atom: str = _us_parse_class();
            if _US_ERR {
                # Leave original pattern so pcre2_compile fails → SyntaxError.
                return pattern;
            }
            out = out + atom;
            continue;
        }
        out = out + c;
        _us_adv(1);
    }
    if _US_ERR {
        return pattern;
    }
    return out;
}

"""Two group-participation chains conflict when both groups can participate in
the same match attempt. Chains are flattened [scope_serial, alt_idx, ...] pairs
from the top-level disjunction down to the group's enclosing scope. Walking the
common prefix: same scope but different alternative → mutually exclusive (OK);
sibling scopes inside the same alternative, or one chain a prefix of the other
→ both participate → conflict."""
def _re_chains_conflict(a: list[int], b: list[int]) -> bool {
    i: int = 0;
    while i + 1 < len(a) and i + 1 < len(b) {
        if a[i] != b[i] {
            return True;
        }
        if a[i + 1] != b[i + 1] {
            return False;
        }
        i = i + 2;
    }
    return True;
}

"""ES2025 duplicate named capture groups: `(?<a>)…(?<a>)` is a SyntaxError
unless every same-named pair sits in mutually-exclusive alternatives (branches
of a `|`). PCRE2 runs with DUPNAMES (accepts everything), so the JS-level rule
is enforced here. Returns the offending name, or "" when the pattern is fine."""
def _dup_named_group_conflict(pattern: str) -> str {
    seen: dict[str, list[list[int]]] = {};
    scope_serial: list[int] = [0];
    scope_alt: list[int] = [0];
    next_serial: int = 1;
    i: int = 0;
    escaped: bool = False;
    in_class: bool = False;
    while i < len(pattern) {
        ch: str = pattern[i];
        if escaped {
            escaped = False;
            i = i + 1;
            continue;
        }
        if ch == "\\" {
            escaped = True;
            i = i + 1;
            continue;
        }
        if ch == "[" and not in_class {
            in_class = True;
            i = i + 1;
            continue;
        }
        if ch == "]" and in_class {
            in_class = False;
            i = i + 1;
            continue;
        }
        if in_class {
            i = i + 1;
            continue;
        }
        if ch == "|" {
            scope_alt[len(scope_alt) - 1] = scope_alt[len(scope_alt) - 1] + 1;
            i = i + 1;
            continue;
        }
        if ch == ")" {
            if len(scope_serial) > 1 {
                _ = scope_serial.pop();
                _ = scope_alt.pop();
            }
            i = i + 1;
            continue;
        }
        if ch == "(" {
            is_named: bool = False;
            nm: str = "";
            if i + 3 < len(pattern)
                and pattern[i + 1] == "?"
                and pattern[i + 2] == "<"
                and (pattern[i + 3] == "=" or pattern[i + 3] == "!") {
                # lookbehind — not a named group
            } elif i + 2 < len(pattern)
                and pattern[i + 1] == "?"
                and pattern[i + 2] == "<" {
                j: int = i + 3;
                while j < len(pattern) and pattern[j] != ">" {
                    nm = nm + pattern[j];
                    j = j + 1;
                }
                if j < len(pattern) {
                    is_named = True;
                }
            }
            if is_named and nm != "" {
                chain: list[int] = [];
                ci: int = 0;
                while ci < len(scope_serial) {
                    chain.append(scope_serial[ci]);
                    chain.append(scope_alt[ci]);
                    ci = ci + 1;
                }
                if nm in seen {
                    prev: list[list[int]] = seen[nm];
                    pi: int = 0;
                    while pi < len(prev) {
                        if _re_chains_conflict(prev[pi], chain) {
                            return nm;
                        }
                        pi = pi + 1;
                    }
                    prev.append(chain);
                } else {
                    seen[nm] = [chain];
                }
            }
            scope_serial.append(next_serial);
            scope_alt.append(0);
            next_serial = next_serial + 1;
            i = i + 1;
            continue;
        }
        i = i + 1;
    }
    return "";
}

"""True if `pattern[i:]` starts a class escape `\d \D \w \W \s \S`."""
def _is_class_escape_at(pattern: str, i: int) -> bool {
    if i + 1 >= len(pattern) or pattern[i] != "\\" {
        return False;
    }
    ce: str = pattern[i + 1];
    return ce == "d" or ce == "D" or ce == "w" or ce == "W" or ce == "s" or ce == "S";
}

"""Annex B (non-unicode patterns only): inside a character class, a `-` with a
class escape on either side is a literal hyphen, not a range — `[\w- ]` is
`\w`, `-` and space (ES §B.1.2 ClassAtomNoDash / NonemptyClassRangesNoDash).
PCRE2 rejects such a hyphen unless it is last in the class, so escape it.
`]` right after `[` / `[^` ends the class, as in JS."""
def _annexb_class_dash_literal(pattern: str) -> str {
    n: int = len(pattern);
    out: str = "";
    i: int = 0;
    in_class: bool = False;
    first_atom: bool = False;
    prev_class_esc: bool = False;
    while i < n {
        c: str = pattern[i];
        if c == "\\" and i + 1 < n {
            if in_class {
                prev_class_esc = _is_class_escape_at(pattern, i);
                first_atom = False;
            }
            out = out + pattern[i:i + 2];
            i = i + 2;
            continue;
        }
        if not in_class {
            if c == "[" {
                in_class = True;
                first_atom = True;
                prev_class_esc = False;
                out = out + c;
                i = i + 1;
                if i < n and pattern[i] == "^" {
                    out = out + "^";
                    i = i + 1;
                }
                continue;
            }
            out = out + c;
            i = i + 1;
            continue;
        }
        if c == "]" {
            in_class = False;
            out = out + c;
            i = i + 1;
            continue;
        }
        if c == "-" and not first_atom and i + 1 < n and pattern[i + 1] != "]" {
            if prev_class_esc or _is_class_escape_at(pattern, i + 1) {
                out = out + "\\-";
                prev_class_esc = False;
                i = i + 1;
                continue;
            }
        }
        prev_class_esc = False;
        first_atom = False;
        out = out + c;
        i = i + 1;
    }
    return out;
}

"""Compile `pattern` with `flags` via PCRE2.  Returns the new JSRegExpState.
Returns a state with pcre2_code_ptr=0 on compilation failure."""
def _pcre2_compile(pattern: str, flags: str) -> JSRegExpState {
    # ES2025: duplicate `(?<name>)` in the same alternative path is an early
    # SyntaxError — surface it as the null-code_ptr state that every caller
    # already turns into "Invalid regular expression" SyntaxError.
    if _dup_named_group_conflict(pattern) != "" {
        return JSRegExpState(
            pattern=pattern,
            flags=flags,
            last_index=0,
            pcre2_code_ptr=0,
            num_groups=0,
            group_names=[],
            flag_g=False,
            flag_i=False,
            flag_m=False,
            flag_s=False,
            flag_u=False,
            flag_y=False,
            flag_d=False,
            flag_v=False
        );
    }
    # Build PCRE2 options bitmask from JS flags.  DUPNAMES is always on: ES2025
    # permits the same `(?<name>)` in mutually-exclusive alternatives, which PCRE2
    # rejects by default.  MATCH_UNSET_BACKREF matches JS semantics where a
    # backreference to a non-participating group (`\k<a>` when `a` was in an
    # untaken alternative) matches the empty string instead of failing.
    options: int = PCRE2_DUPNAMES + PCRE2_MATCH_UNSET_BACKREF;
    fg: bool = False;
    fi: bool = False;
    fm: bool = False;
    fs: bool = False;
    fu: bool = False;
    fy: bool = False;
    fd: bool = False;
    fv: bool = False;
    i_fl: int = 0;
    while i_fl < len(flags) {
        c: str = flags[i_fl];
        if c == "g" {
            fg = True;
        } elif c == "i" {
            fi = True;
            options = options + PCRE2_CASELESS;
        } elif c == "m" {
            fm = True;
            options = options + PCRE2_MULTILINE;
        } elif c == "s" {
            fs = True;
            options = options + PCRE2_DOTALL;
        } elif c == "u" {
            fu = True;
            options = options + PCRE2_UTF + PCRE2_UCP;
        } elif c == "y" {
            fy = True;
        } elif c == "d" {
            fd = True;
        } elif c == "v" {
            fv = True;
            options = options + PCRE2_UTF + PCRE2_UCP;
        }
        i_fl = i_fl + 1;
    }

    # Allocate error output buffers (8 bytes each is enough)
    err_code_buf: int = io_alloc(8);
    err_off_buf: int = io_alloc(8);

    compile_pat: str = pattern;
    # Lower ES2024 /v ClassSetExpression (nested classes, &&, --, \q) to
    # PCRE2-legal lookarounds / alternations before unicode normalize.
    if fv {
        compile_pat = _rewrite_unicode_sets(compile_pat);
    }
    if not (fu or fv) {
        compile_pat = _annexb_class_dash_literal(compile_pat);
    }
    compile_pat = _normalize_unicode_pattern(compile_pat, fu or fv, fi);
    # Proactively bound unbounded lookbehind quantifiers (* / + / {n,}) so PCRE2
    # variable-length lookbehind (max_varlookbehind) can accept ES patterns.
    # Harmless when the pattern has no lookbehind.
    compile_pat = _transform_vlb_quantifiers(compile_pat);

    # Create a compile context so we can enable variable-length lookbehinds.
    # PCRE2 10.45: pcre2_set_max_varlookbehind(MAX_VLB) allows bounded quantifiers
    # up to MAX_VLB chars inside (?<=...).
    cctx: int = pcre2_compile_context_create_8(0);
    if cctx != 0 {
        pcre2_set_max_varlookbehind_8(cctx, MAX_VLB);
        # A JS /u or /v pattern may name surrogate code points — @babel/parser's
        # `const loneSurrogate = /[\uD800-\uDFFF]/u` — which PCRE2's UTF-8 mode
        # rejects as escapes ("Invalid regular expression" killed the whole module).
        # Allow them: on well-formed subjects they simply never match.
        if fu or fv {
            pcre2_set_compile_extra_options_8(
                cctx, PCRE2_EXTRA_ALLOW_SURROGATE_ESCAPES
            );
        }
    }

    code_ptr: int = pcre2_compile_8(
        compile_pat, len(compile_pat), options, err_code_buf, err_off_buf, cctx
    );

    if cctx != 0 {
        pcre2_compile_context_free_8(cctx);
    }

    num_g: int = 0;
    if code_ptr != 0 {
        # Query capture count (PCRE2_INFO_CAPTURECOUNT = 4) → uint32_t
        cap_buf: int = io_alloc(8);
        pcre2_pattern_info_8(code_ptr, PCRE2_INFO_CAPTURECOUNT, cap_buf);
        num_g = read_u32(cap_buf, 0);
    }

    gnames: list[str] = _extract_group_names(pattern);

    return JSRegExpState(
        pattern=pattern,
        flags=flags,
        last_index=0,
        pcre2_code_ptr=code_ptr,
        num_groups=num_g,
        group_names=gnames,
        flag_g=fg,
        flag_i=fi,
        flag_m=fm,
        flag_s=fs,
        flag_u=fu,
        flag_y=fy,
        flag_d=fd,
        flag_v=fv
    );
}

def _is_decimal_digit(c: str) -> bool {
    return c >= "0" and c <= "9";
}

def _hex_to_int(hexs: str) -> int {
    n: int = 0;
    i: int = 0;
    while i < len(hexs) {
        c: str = hexs[i];
        v: int = 0;
        if c >= "0" and c <= "9" {
            v = ord(c) - ord("0");
        } elif c >= "a" and c <= "f" {
            v = 10 + (ord(c) - ord("a"));
        } elif c >= "A" and c <= "F" {
            v = 10 + (ord(c) - ord("A"));
        }
        n = n * 16 + v;
        i = i + 1;
    }
    return n;
}

"""Length of a U+0000 escape at p[i] (`\\0` not followed by a digit → 2,
`\\x00` → 4, `\\u0000` → 6), else 0."""
def _re_nul_escape_len(p: str, i: int) -> int {
    n: int = len(p);
    if i + 1 >= n or p[i] != "\\" {
        return 0;
    }
    c1: str = p[i + 1];
    if c1 == "0" {
        if i + 2 < n and _is_decimal_digit(p[i + 2]) {
            return 0;
        }
        return 2;
    }
    if c1 == "x" and i + 3 < n and p[i + 2] == "0" and p[i + 3] == "0" {
        return 4;
    }
    if c1 == "u"
        and i + 5 < n
        and p[i + 2] == "0"
        and p[i + 3] == "0"
        and p[i + 4] == "0"
        and p[i + 5] == "0" {
        return 6;
    }
    return 0;
}

"""True when pattern[pos:pos+4] is four hex digits."""
def _re_is_hex4(pattern: str, pos: int) -> bool {
    if pos + 4 > len(pattern) {
        return False;
    }
    k: int = pos;
    while k < pos + 4 {
        c: str = pattern[k];
        if not (
            (c >= "0" and c <= "9")
            or (c >= "a" and c <= "f")
            or (c >= "A" and c <= "F")
        ) {
            return False;
        }
        k = k + 1;
    }
    return True;
}

def _normalize_unicode_pattern(
    pattern: str, use_unicode: bool, is_caseless: bool
) -> str {
    out: str = "";
    i: int = 0;
    # Whether the cursor is inside a character class. A `[` is only a class
    # OPENER at top level; inside a class it is a LITERAL (JS regex — only `]`
    # and `\` are special within `[...]`). Without this, `[[]` (a class holding
    # a literal `[`) hit the `[]`-empty-class rewrite on its inner `[]` pair and
    # was mangled to `[[^\s\S]`, so `removeBrackets`'s `/[<[]/` matched every
    # char — which broke vite's CLI command routing (`vite build` → dev/preview).
    nz_in_class: bool = False;
    while i < len(pattern) {
        # An escaped char (`\X`) is two chars that toggle no class state — but
        # `\u`/`\u{}` still need the normalization below, so only fast-path
        # NON-`\u` escapes here (e.g. `\[`, `\]`, `\.`). This keeps `\]` from
        # closing a class and `\[` from opening one.
        # U+0000 escapes (`\\0` not followed by a digit, `\\x00`, `\\u0000`) must
        # match the engine's 4-char NUL sentinel text `\\x00` — engine strings
        # never hold a NUL byte, so PCRE2's `\\0` matched nothing:
        # `/^\\0/.test("\\0id")` was false and `id.replace(/\\0/g, "")` a no-op
        # (vite's virtual-module ids leaked into sourcemap `sources`). Top level
        # only: inside a class the 4-char form has no meaning.
        if not nz_in_class and _re_nul_escape_len(pattern, i) > 0 {
            out = out + "\\\\x00";
            i = i + _re_nul_escape_len(pattern, i);
            continue;
        }
        if pattern[i] == "\\" and i + 1 < len(pattern) and pattern[i + 1] != "u" {
            out = out + pattern[i] + pattern[i + 1];
            i = i + 2;
            continue;
        }
        # `[^]`/`[]` rewrites and class-opener tracking apply ONLY at top level.
        # Inside a class, `[` is a LITERAL (JS regex — only `]`/`\` are special
        # there); the `\u` normalization below still runs in both contexts.
        # Without this, `[[]` hit the `[]`-empty-class rewrite on its inner `[]`
        # pair and was mangled to `[[^\s\S]`, so `removeBrackets`'s `/[<[]/`
        # matched every char — breaking vite's CLI routing (`vite build`).
        if not nz_in_class {
            # [^] → [\s\S]: JS empty negated class = "any char incl. newlines";
            # PCRE2 rejects [^], so rewrite it.
            if i + 2 < len(pattern)
                and pattern[i] == "["
                and pattern[i + 1] == "^"
                and pattern[i + 2] == "]" {
                out = out + "[\\s\\S]";
                i = i + 3;
                continue;
            }
            # [] → [^\s\S]: JS empty class matches nothing; PCRE2 rejects bare [].
            if i + 1 < len(pattern) and pattern[i] == "[" and pattern[i + 1] == "]" {
                out = out + "[^\\s\\S]";
                i = i + 2;
                continue;
            }
            if pattern[i] == "[" {
                nz_in_class = True;
            }
        } else {
            # A `\]` inside a class does not close it — the escape branch below
            # consumes it. A bare `]` closes the class.
            if pattern[i] == "]" {
                nz_in_class = False;
            }
        }
        if i + 5 < len(pattern) and pattern[i] == "\\" and pattern[i + 1] == "u" {
            h0: str = pattern[i + 2];
            h1: str = pattern[i + 3];
            h2: str = pattern[i + 4];
            h3: str = pattern[i + 5];
            is4hex: bool = (
                (
                    (h0 >= "0" and h0 <= "9")
                    or (h0 >= "a" and h0 <= "f")
                    or (h0 >= "A" and h0 <= "F")
                )
                and (
                    (h1 >= "0" and h1 <= "9")
                    or (h1 >= "a" and h1 <= "f")
                    or (h1 >= "A" and h1 <= "F")
                )
                and (
                    (h2 >= "0" and h2 <= "9")
                    or (h2 >= "a" and h2 <= "f")
                    or (h2 >= "A" and h2 <= "F")
                )
                and (
                    (h3 >= "0" and h3 <= "9")
                    or (h3 >= "a" and h3 <= "f")
                    or (h3 >= "A" and h3 <= "F")
                )
            );
            if is4hex {
                cp4: int = _hex_to_int(h0 + h1 + h2 + h3);
                # /u: `\uD83D\uDE00` (a high + low surrogate escape pair) is ONE code
                # point — emit its 4-byte UTF-8, not two separate halves.
                if use_unicode
                    and cp4 >= 55296
                    and cp4 <= 56319
                    and i + 11 < len(pattern)
                    and pattern[i + 6] == "\\"
                    and pattern[i + 7] == "u"
                    and _re_is_hex4(pattern, i + 8) {
                    lo4: int = _hex_to_int(pattern[i + 8:i + 12]);
                    if lo4 >= 56320 and lo4 <= 57343 {
                        out = out
                            + utf8_encode_scalar(
                                65536 + (cp4 - 55296) * 1024 + (lo4 - 56320)
                            );
                        i = i + 12;
                        continue;
                    }
                }
                if use_unicode and is_caseless and cp4 == 383 {
                    out = out + "s";
                } elif use_unicode and cp4 >= 55296 and cp4 <= 57343 {
                    # A LONE surrogate code point under /u (`/[\uD800-\uDFFF]/u`,
                    # @babel/parser's loneSurrogate): its raw bytes are not valid
                    # UTF-8, so PCRE2's UTF mode rejected the whole pattern. Emit an
                    # escape instead — _pcre2_compile sets ALLOW_SURROGATE_ESCAPES.
                    out = out + "\\x{" + h0 + h1 + h2 + h3 + "}";
                } else {
                    out = out + utf8_encode_scalar(cp4);
                }
                i = i + 6;
                continue;
            }
        }
        if i + 3 < len(pattern)
            and pattern[i] == "\\"
            and pattern[i + 1] == "u"
            and pattern[i + 2] == "{" {
            j: int = i + 3;
            hexs: str = "";
            ok: bool = True;
            while j < len(pattern) and pattern[j] != "}" {
                ch: str = pattern[j];
                if (ch >= "0" and ch <= "9")
                    or (ch >= "a" and ch <= "f")
                    or (ch >= "A" and ch <= "F") {
                    hexs = hexs + ch;
                } else {
                    ok = False;
                }
                j = j + 1;
            }
            if ok and j < len(pattern) and len(hexs) > 0 {
                if use_unicode {
                    cp: int = _hex_to_int(hexs);
                    if cp >= 55296 and cp <= 57343 {
                        # Lone surrogate via \u{...}: escape it (see the \uXXXX case).
                        out = out + "\\x{" + hexs + "}";
                    } elif cp >= 0 and cp <= 1114111 {
                        out = out + utf8_encode_scalar(cp);
                    } else {
                        out = out + "\\x{" + hexs + "}";
                    }
                } else {
                    out = out + "u\\x7B" + hexs + "\\x7D";
                }
                i = j + 1;
                continue;
            }
        }
        out = out + pattern[i];
        i = i + 1;
    }
    return out;
}

def _canonicalize_flags(flags: str) -> str {
    seen_g: bool = False;
    seen_i: bool = False;
    seen_m: bool = False;
    seen_s: bool = False;
    seen_u: bool = False;
    seen_y: bool = False;
    seen_d: bool = False;
    seen_v: bool = False;
    i: int = 0;
    while i < len(flags) {
        c: str = flags[i];
        if c == "g" {
            if seen_g {
                vm_throw_native(
                    make_syntax_error("Invalid flags supplied to RegExp constructor")
                );
                return "";
            }
            seen_g = True;
        } elif c == "i" {
            if seen_i {
                vm_throw_native(
                    make_syntax_error("Invalid flags supplied to RegExp constructor")
                );
                return "";
            }
            seen_i = True;
        } elif c == "m" {
            if seen_m {
                vm_throw_native(
                    make_syntax_error("Invalid flags supplied to RegExp constructor")
                );
                return "";
            }
            seen_m = True;
        } elif c == "s" {
            if seen_s {
                vm_throw_native(
                    make_syntax_error("Invalid flags supplied to RegExp constructor")
                );
                return "";
            }
            seen_s = True;
        } elif c == "u" {
            if seen_u or seen_v {
                vm_throw_native(
                    make_syntax_error("Invalid flags supplied to RegExp constructor")
                );
                return "";
            }
            seen_u = True;
        } elif c == "y" {
            if seen_y {
                vm_throw_native(
                    make_syntax_error("Invalid flags supplied to RegExp constructor")
                );
                return "";
            }
            seen_y = True;
        } elif c == "d" {
            if seen_d {
                vm_throw_native(
                    make_syntax_error("Invalid flags supplied to RegExp constructor")
                );
                return "";
            }
            seen_d = True;
        } elif c == "v" {
            if seen_v or seen_u {
                vm_throw_native(
                    make_syntax_error("Invalid flags supplied to RegExp constructor")
                );
                return "";
            }
            seen_v = True;
        } else {
            vm_throw_native(
                make_syntax_error("Invalid flags supplied to RegExp constructor")
            );
            return "";
        }
        i = i + 1;
    }
    out: str = "";
    if seen_d {
        out = out + "d";
    }
    if seen_g {
        out = out + "g";
    }
    if seen_i {
        out = out + "i";
    }
    if seen_m {
        out = out + "m";
    }
    if seen_s {
        out = out + "s";
    }
    if seen_u {
        out = out + "u";
    }
    if seen_v {
        out = out + "v";
    }
    if seen_y {
        out = out + "y";
    }
    return out;
}

"""Look up or compile (pattern, flags).  Returns table index.

O(1) via `_RE_CACHE` keyed by "pattern\\x1fflags"; linear scan is only a
defensive fallback if the dict somehow misses a live entry."""
def _get_or_compile(pattern: str, flags: str) -> int {
    # US (\x1f), NOT \x00: a NUL separator is truncated by jac-native's C-string
    # dict-key handling, so "<pat>\x00<flags>" collapses to just "<pat>" — then
    # /re/y and /re/my collide and the second reuses the first's compiled form
    # with the wrong flags (y-assertion-start: an `m` regex behaved non-multiline).
    cache_key: str = pattern + "\x1f" + flags;
    if cache_key in _RE_CACHE {
        _c_idx: int = _RE_CACHE[cache_key];
        # G0.5: the cached slot may have been GC-swept (tombstoned DEAD) or its
        # index recycled for a different pattern — validate before trusting it.
        if _c_idx >= 0
            and _c_idx < len(_RE_REALM.regexps)
            and _RE_REALM.regexps[_c_idx].cell_flags != CELL_FLAG_DEAD
            and _RE_REALM.regexps[_c_idx].pattern == pattern
            and _RE_REALM.regexps[_c_idx].flags == flags {
            return _c_idx;
        }
        del _RE_CACHE[cache_key];  # stale — recompile / reuse below
    }
    # Defensive fallback: linear scan if the dict somehow missed a live entry
    # (skip GC-tombstoned slots — their pattern/flags are stale).
    i: int = 0;
    while i < len(_RE_REALM.regexps) {
        ri: JSRegExpState = _RE_REALM.regexps[i];
        if ri.cell_flags != CELL_FLAG_DEAD
            and ri.pattern == pattern
            and ri.flags == flags {
            _RE_CACHE[cache_key] = i;
            return i;
        }
        i = i + 1;
    }
    st: JSRegExpState = _pcre2_compile(pattern, flags);
    # G0.5: reuse a GC-swept regexp slot when available, else append. A fresh
    # `st` (cell_flags=0) clears the DEAD tombstone; the swept slot's pcre2_code
    # was already freed by gc_sweep_regexps (ptr zeroed), so no double-free.
    idx: int = -1;
    if len(_RE_REALM.free_regexp_slots) > 0 {
        _fr_last: int = len(_RE_REALM.free_regexp_slots) - 1;
        idx = _RE_REALM.free_regexp_slots[_fr_last];
        del _RE_REALM.free_regexp_slots[_fr_last];
        _RE_REALM.regexps[idx] = st;
        _RE_REALM.regexps_mark_epoch[idx] = 0;
    } else {
        idx = len(_RE_REALM.regexps);
        _RE_REALM.regexps.append(st);
        _RE_REALM.regexps_mark_epoch.append(0);  # A2.2b GC mark bitmap
    }
    # G0.5: bound the cache dict (dynamic-pattern churn would otherwise grow it
    # unbounded). On overflow, drop the whole map — the linear scan above rebuilds
    # entries lazily for still-live patterns.
    if len(_RE_CACHE) >= 4096 {
        _RE_CACHE = {};
    }
    _RE_CACHE[cache_key] = idx;
    return idx;
}

# ══════════════════════════════════════════════════════════════════════════════
# 5.  Single-call match helper
# ══════════════════════════════════════════════════════════════════════════════

"""Run PCRE2 match for `re` on `s` starting at byte offset `start`.
Returns list[int]:
  [-1]                               — no match
  [match_start, match_end, ov...]    — success; followed by raw ovector pairs
    cap group k: ov[2+k*2], ov[2+k*2+1]  (value < 0  →  group did not match)

Public entry points set _DM_ASCII (from the subject's cell flag) right before
calling, so a known-ASCII subject skips the surrogate scan entirely; otherwise a
/u or /v pattern only pays the CESU-8 → UTF-8 conversion when the subject
actually contains a surrogate half (lead byte 0xED), instead of decoding and
re-encoding the whole string on EVERY call (O(n) per match → quadratic loops).
"""
glob _DM_ASCII: bool = False;
glob _DM_ED: str = "",
     _DM_MD: dict[int, int] = {},
     _DM_MCTX: int = 0;

# One match-data block per compiled pattern and one shared match context (4
# malloc/free per match gone). Keyed by the pcre2 code POINTER, which the GC now
# frees (gc_sweep_regexps) and malloc reuses for later compiles — so an entry can
# belong to a dead pattern; _do_match_raw replaces one that is too small.
def _do_match(re: JSRegExpState, s: str, start: int) -> list[int] {
    if re.pcre2_code_ptr == 0 {
        return [-1];
    }
    if (re.flag_u or re.flag_v) and not _DM_ASCII {
        if len(_DM_ED) == 0 {
            _DM_ED = byte_chr(237);
        }
        if s.find(_DM_ED) >= 0 {
            return _do_match_conv(re, s, start);
        }
    }
    return _do_match_raw(re, s, start);
}

"""/u or /v subject holding CESU-8 surrogate halves: pair them into 4-byte astral
scalars (PCRE2 UTF mode needs valid UTF-8), then match."""
def _do_match_conv(re: JSRegExpState, s: str, start: int) -> list[int] {
    cps: list[int] = utf8_decode_str_to_codepoints(s);
    scalars: list[int] = utf16_units_to_scalars(cps);
    parts: list[str] = [];
    for sc in scalars {
        parts.append(utf8_encode_scalar(sc));
    }
    return _do_match_raw(re, "".join(parts), start);
}

def _do_match_raw(re: JSRegExpState, subj: str, start: int) -> list[int] {
    md: int = 0;
    if re.pcre2_code_ptr in _DM_MD {
        md = _DM_MD[re.pcre2_code_ptr];
    } else {
        md = pcre2_match_data_create_from_pattern_8(re.pcre2_code_ptr, 0);
        if md == 0 {
            return [-1];
        }
        _DM_MD[re.pcre2_code_ptr] = md;
    }
    if _DM_MCTX == 0 {
        _DM_MCTX = pcre2_match_context_create_8(0);
        if _DM_MCTX != 0 {
            pcre2_set_match_limit_8(_DM_MCTX, PCRE2_MATCH_LIMIT);
        }
    }
    slen: int = len(subj);
    rc: int = pcre2_match_8(re.pcre2_code_ptr, subj, slen, start, 0, md, _DM_MCTX);
    if rc == 0 {
        # rc 0 = matched, but the ovector is too small for this pattern's groups:
        # the cached block was made for a swept regexp whose freed pcre2 code
        # address this pattern now occupies. It used to read as NO MATCH (rollup's
        # /\[(\w+)(:\d+)?]/g missed "assets/[name]-[hash].js" and emitted chunks
        # literally named "[name]-[hash].js"). Size a block for this pattern, retry.
        pcre2_match_data_free_8(md);
        md = pcre2_match_data_create_from_pattern_8(re.pcre2_code_ptr, 0);
        if md == 0 {
            del _DM_MD[re.pcre2_code_ptr];
            return [-1];
        }
        _DM_MD[re.pcre2_code_ptr] = md;
        rc = pcre2_match_8(re.pcre2_code_ptr, subj, slen, start, 0, md, _DM_MCTX);
    }

    # pcre2_match_8 is a C function returning int (32-bit). The Jac native
    # JIT declares it as i64, so errors (negative ints) arrive zero-extended:
    # PCRE2_ERROR_NOMATCH = -1 → 4294967295.  Treat any rc > 65536 as error.
    if rc < 1 or rc > 65536 {
        return [-1];
    }

    ov_ptr: int = pcre2_get_ovector_pointer_8(md);
    ov_cnt: int = pcre2_get_ovector_count_8(md);
    max_pairs: int = re.num_groups + 1;  # full match + all captures
    if max_pairs < 1 {
        max_pairs = 1;
    }
    take_pairs: int = ov_cnt;
    if take_pairs > max_pairs {
        take_pairs = max_pairs;
    }
    # rc is "number of pairs with data" on success; use it as an additional bound.
    if rc > 0 and rc < take_pairs {
        take_pairs = rc;
    }
    if take_pairs < 1 {
        return [-1];
    }

    result: list[int] = [];
    k: int = 0;
    while k < take_pairs * 2 {
        # read_u64 returns the raw size_t; on 64-bit PCRE2_UNSET = ~0ULL
        # which becomes -1 in Jac's i64 representation — we keep it as-is.
        ovv: int = read_u64(ov_ptr, k * 8);
        if ovv == U64_MAX {
            ovv = -1;
        }
        result.append(ovv);
        k = k + 1;
    }
    # Pad to the pattern's full group count so consumers can index any group
    # blindly. PCRE2 only writes pairs up to rc (the highest participating
    # group); with the match data reused across calls the entries past rc are
    # stale, so they must never be read — pad with "unset" instead.
    while len(result) < max_pairs * 2 {
        result.append(-1);
    }
    # result[0], result[1] = full match start / end
    return result;
}

# ══════════════════════════════════════════════════════════════════════════════
# 6.  Public creation / reflection API
# ══════════════════════════════════════════════════════════════════════════════

"""Helper: wrap a computed Jac str as a heap (GC-collectable) JSValue string.
Was str_intern: every match / capture / split piece / replace result was parked
in the never-freed intern table (3.2GB of retained substrings in vite's render)."""
def _mk_jstr(s: str) -> JSValue {
    return jsv_from_string_id(str_heap(s));
}

"""The `input` / receiver string as a JSValue: reuse the original string cell
when there is one (no copy, no new heap slot per match)."""
def _re_input_value(v: JSValue, s: str) -> JSValue {
    if jsv_is_string_cell(v) {
        return v;
    }
    return _mk_jstr(s);
}

"""True when the subject is a string cell known to be pure ASCII (no CESU-8
surrogates possible, so /u matching can use the bytes as-is)."""
def _dm_subject_ascii(v: JSValue) -> bool {
    if not jsv_is_string_cell(v) {
        return False;
    }
    return str_cell_ascii(jsv_to_table_id(v)) == 1;
}

"""Byte offset → UTF-16 unit index (identity for a known-ASCII subject). JS
sees `index` / `lastIndex` / search() in code units; the matcher works in bytes,
so a non-ASCII subject (é = 2 bytes, 1 unit) needs the walk."""
def _re_b2u(s: str, byte_off: int, asc: bool) -> int {
    if asc or byte_off <= 0 {
        return byte_off;
    }
    return js_string_byte_to_unit(s, byte_off);
}

"""UTF-16 unit index → byte offset; -1 when the index lies past the end (a
lastIndex beyond the string must FAIL the match, not clamp onto it)."""
def _re_u2b(s: str, units: int, asc: bool) -> int {
    if units <= 0 {
        return 0;
    }
    if asc {
        if units > len(s) {
            return -1;
        }
        return units;
    }
    if units > js_string_utf16_len(s) {
        return -1;
    }
    return js_string_unit_to_byte(s, units);
}

"""Helper: JSValue → Jac str (String tag only, else "")."""
def _jsval_str(v: JSValue) -> str {
    if jsv_is_string_cell(v) {
        return str_from_id(jsv_to_table_id(v));
    }
    # A non-string receiver (String.prototype.replace.call(new Number(1), ...))
    # goes through observable ToString so the value's own toString/valueOf runs,
    # and a conversion yielding no primitive throws instead of silently
    # degrading to "" — which used to make the pattern never match.
    if jsv_is_object_cell(v) {
        return js_to_string_observable(v);
    }
    return js_coerce_to_string(v);
}

"""Helper: bool → JSValue."""
def _js_bool(b: bool) -> JSValue {
    if b {
        return js_true();
    }
    return js_false();
}

"""Create a RegExp JSValue from pattern and flags strings."""
def:pub js_regexp_create(pattern: str, flags: str) -> JSValue {
    canon_flags: str = _canonicalize_flags(flags);
    if canon_flags == "" and len(flags) > 0 {
        return js_undefined();
    }
    idx: int = _get_or_compile(pattern, canon_flags);
    re: JSRegExpState = _RE_REALM.regexps[idx];
    if re.pcre2_code_ptr == 0 {
        vm_throw_native(make_syntax_error("Invalid regular expression"));
        return js_undefined();
    }

    re_obj: JSValue = js_object_create(_REGEXP_PROTO)
        if jsv_is_object_cell(_REGEXP_PROTO)
        else js_object_create_null();
    js_object_set(re_obj, _KEY_IS_REGEXP, js_int(idx));
    # ES §22.2.7.2: `lastIndex` is the ONLY own property of a RegExp instance,
    # and it is { writable: true, enumerable: false, configurable: false }.
    # source/flags/global/... are accessors on RegExp.prototype (installed in
    # global.na.jac lines ~2161-2170) that read this instance's compiled state —
    # defining them as own data properties here (as adel_fixes did) would shadow
    # those accessors and make Object.getOwnPropertyNames(re) report a dozen
    # extra keys, violating §22.2.7.2.
    js_object_define_property(
        re_obj,
        str_intern("lastIndex"),
        JSProperty(
            key=str_intern("lastIndex"),
            value=js_int(0),
            writable=True,
            enumerable=False,
            configurable=False,
            deleted=False
        )
    );

    return re_obj;
}

# ══════════════════════════════════════════════════════════════════════════════
# RegExp.prototype accessors (ES §22.2.6)
# ══════════════════════════════════════════════════════════════════════════════

"""Shared brand check for the RegExp.prototype flag accessors.

ES §22.2.6.4.1: each getter requires an object with a [[OriginalFlags]] slot.
`RegExp.prototype` itself has no such slot but is explicitly allowed and yields
the sentinel (undefined for flag getters, "(?:)" for `source`). Any other
receiver is a TypeError.

Returns the regexp table index, -1 for the prototype sentinel case, and -2 when
a TypeError has been thrown (caller must return undefined immediately)."""
def _re_accessor_idx(this_val: JSValue, name: str) -> int {
    if not jsv_is_object_cell(this_val) {
        vm_throw_native(
            make_type_error("RegExp.prototype." + name + " getter called on non-object")
        );
        return -2;
    }
    idx: int = _re_idx(this_val);
    if idx >= 0 {
        return idx;
    }
    # RegExp.prototype itself: legacy sentinel rather than a throw.
    if jsv_is_object_cell(_REGEXP_PROTO)
        and jsv_to_table_id(this_val) == jsv_to_table_id(_REGEXP_PROTO) {
        return -1;
    }
    vm_throw_native(
        make_type_error(
            "RegExp.prototype." + name + " getter called on incompatible receiver"
        )
    );
    return -2;
}

"""EscapeRegExpPattern (§22.2.3.2.5): produce a source string S such that
re-parsing `/S/flags` yields the same pattern. The empty pattern becomes
"(?:)"; an unescaped "/" becomes "\\/"; and the four line terminators are
escaped so the one-line literal form stays valid.

The scan tracks escape state and character classes so an already-escaped "\\/"
is left as-is and a "/" inside `[...]` (which does not terminate the literal in
JS) is still escaped for a normalized, always-valid single-line form."""
def _escape_regexp_pattern(pattern: str) -> str {
    if len(pattern) == 0 {
        return "(?:)";
    }
    out: str = "";
    i: int = 0;
    n: int = len(pattern);
    escaped: bool = False;
    while i < n {
        c: str = pattern[i];
        if escaped {
            out = out + c;
            escaped = False;
            i = i + 1;
            continue;
        }
        if c == "\\" {
            out = out + c;
            escaped = True;
            i = i + 1;
            continue;
        }
        if c == "/" {
            out = out + "\\/";
            i = i + 1;
            continue;
        }
        if c == "\n" {
            out = out + "\\n";
            i = i + 1;
            continue;
        }
        if c == "\r" {
            out = out + "\\r";
            i = i + 1;
            continue;
        }
        cp: int = ord(c);
        if cp == 8232 {
            out = out + "\\u2028";
            i = i + 1;
            continue;
        }  # LINE SEPARATOR
        if cp == 8233 {
            out = out + "\\u2029";
            i = i + 1;
            continue;
        }  # PARAGRAPH SEPARATOR
        out = out + c;
        i = i + 1;
    }
    return out;
}

"""get RegExp.prototype.source (ES §22.2.6.13) — escaped pattern text."""
def:pub js_regexp_get_source(this_val: JSValue) -> JSValue {
    idx: int = _re_accessor_idx(this_val, "source");
    if idx == -2 {
        return js_undefined();
    }
    if idx == -1 {
        return _mk_jstr("(?:)");
    }
    return _mk_jstr(_escape_regexp_pattern(_RE_REALM.regexps[idx].pattern));
}

"""get RegExp.prototype.flags (ES §22.2.6.5) — flag chars in spec order."""
def:pub js_regexp_get_flags(this_val: JSValue) -> JSValue {
    if not jsv_is_object_cell(this_val) {
        vm_throw_native(
            make_type_error("RegExp.prototype.flags getter called on non-object")
        );
        return js_undefined();
    }
    idx: int = _re_idx(this_val);
    if idx < 0 {
        # §22.2.6.5 reads each flag through Get(R, name), so RegExp.prototype
        # (all flags undefined) yields "" rather than throwing.
        if jsv_is_object_cell(_REGEXP_PROTO)
            and jsv_to_table_id(this_val) == jsv_to_table_id(_REGEXP_PROTO) {
            return _mk_jstr("");
        }
        vm_throw_native(
            make_type_error(
                "RegExp.prototype.flags getter called on incompatible receiver"
            )
        );
        return js_undefined();
    }
    return _mk_jstr(_RE_REALM.regexps[idx].flags);
}

"""Shared body for the boolean flag getters."""
def _re_flag_getter(this_val: JSValue, name: str, which: int) -> JSValue {
    idx: int = _re_accessor_idx(this_val, name);
    if idx == -2 {
        return js_undefined();
    }
    if idx == -1 {
        return js_undefined();
    }
    re: JSRegExpState = _RE_REALM.regexps[idx];
    if which == 0 {
        return _js_bool(re.flag_g);
    }
    if which == 1 {
        return _js_bool(re.flag_i);
    }
    if which == 2 {
        return _js_bool(re.flag_m);
    }
    if which == 3 {
        return _js_bool(re.flag_s);
    }
    if which == 4 {
        return _js_bool(re.flag_u);
    }
    if which == 5 {
        return _js_bool(re.flag_y);
    }
    if which == 6 {
        return _js_bool(re.flag_d);
    }
    return _js_bool(re.flag_v);
}

def:pub js_regexp_get_global(this_val: JSValue) -> JSValue {
    return _re_flag_getter(this_val, "global", 0);
}

def:pub js_regexp_get_ignorecase(this_val: JSValue) -> JSValue {
    return _re_flag_getter(this_val, "ignoreCase", 1);
}

def:pub js_regexp_get_multiline(this_val: JSValue) -> JSValue {
    return _re_flag_getter(this_val, "multiline", 2);
}

def:pub js_regexp_get_dotall(this_val: JSValue) -> JSValue {
    return _re_flag_getter(this_val, "dotAll", 3);
}

def:pub js_regexp_get_unicode(this_val: JSValue) -> JSValue {
    return _re_flag_getter(this_val, "unicode", 4);
}

def:pub js_regexp_get_sticky(this_val: JSValue) -> JSValue {
    return _re_flag_getter(this_val, "sticky", 5);
}

def:pub js_regexp_get_hasindices(this_val: JSValue) -> JSValue {
    return _re_flag_getter(this_val, "hasIndices", 6);
}

def:pub js_regexp_get_unicodesets(this_val: JSValue) -> JSValue {
    return _re_flag_getter(this_val, "unicodeSets", 7);
}

"""Return True if v is a RegExp JSObject."""
def:pub js_is_regexp(v: JSValue) -> bool {
    if not jsv_is_object_cell(v) {
        return False;
    }
    marker: JSValue = js_object_get(v, _KEY_IS_REGEXP);
    return jsv_is_int32(marker);
}

"""Get the table index from a RegExp JSValue (or -1)."""
def _re_idx(v: JSValue) -> int {
    # a fresh instance's layout: the marker's slot (V4.17 snapshot)
    if _RE_PS_MK_SI >= 0 {
        ri_m: JSValue = js_object_ic_hit(v, _RE_PS_INST_SID, _RE_PS_MK_SI);
        if jsv_is_int32(ri_m) {
            return jsv_to_int32(ri_m);
        }
    }
    m: JSValue = js_object_get(v, _KEY_IS_REGEXP);
    if jsv_is_int32(m) {
        return jsv_to_int32(m);
    }
    return -1;
}

"""Coerce a value to a RegExp.  If already a regexp, return it; else `new RegExp(val)`.
The pattern is ToString(val) (§22.2.3.1) — so match(3) → /3/, match(true) → /true/ —
except `new RegExp(undefined)` yields the empty pattern (not the literal "undefined")."""
def:pub js_coerce_regexp(val: JSValue) -> JSValue {
    if js_is_regexp(val) {
        return val;
    }
    pat: str = "";
    if jsv_is_undefined(val) {
        pat = "";
    } else {
        pat = js_to_string_prim(val);
    }
    return js_regexp_create(pat, "");
}

def _to_nonneg_int(v: JSValue) -> int {
    out: int = 0;
    if jsv_is_int32(v) {
        out = jsv_to_int32(v);
    } elif jsv_is_double(v) {
        out = int(jsv_to_double(v));
    }
    if out < 0 {
        return 0;
    }
    return out;
}

"""ToLength(? Get(R,"lastIndex")) per RegExpBuiltinExec §22.2.7.2 step 4.
Reads lastIndex through observable ToNumber so a string ("1.9"→1) coerces and a
throwing valueOf propagates via the native-exc channel. Clamps to [0, 2^53-1]."""
def _re_last_index_tolength(re_val: JSValue) -> int {
    li: JSValue = js_undefined();
    # a fresh instance's layout: the own data slot (a miss reads the hole)
    if _RE_PS_LI_SI >= 0 {
        li = js_object_ic_hit(re_val, _RE_PS_INST_SID, _RE_PS_LI_SI);
    }
    if jsv_is_int32(li) {
        if jsv_to_int32(li) < 0 {
            return 0;
        }
        return jsv_to_int32(li);
    }
    li = js_object_get(re_val, _K_LAST_INDEX);
    if jsv_is_int32(li) {
        v: int = jsv_to_int32(li);
        if v < 0 {
            return 0;
        }
        return v;
    }
    n: float = js_to_number_observable(li);
    if n != n {
        return 0;
    }  # NaN → 0
    if n <= 0.0 {
        return 0;
    }
    if n >= 9007199254740991.0 {
        return 9007199254740991;
    }
    return int(n);
}

def _start_index_for(re: JSRegExpState, re_val: JSValue) -> int {
    # Even for non-global/non-sticky, RegExpBuiltinExec still reads (and coerces)
    # lastIndex — a throwing valueOf must propagate — but then ignores its value.
    li_i: int = _re_last_index_tolength(re_val);
    if not re.flag_g and not re.flag_y {
        return 0;
    }
    return li_i;
}

"""Set R.lastIndex to idx via [[Set]] with Throw=true (§22.2.7.2 steps 15/18).
Returns True if a TypeError was thrown (lastIndex is non-writable)."""
def _re_set_last_index(re_val: JSValue, idx: int) -> bool {
    # a fresh instance's layout: `lastIndex` is an own writable data slot
    if _RE_PS_LI_SI >= 0
        and js_object_ic_set_hit(re_val, _RE_PS_INST_SID, _RE_PS_LI_SI, js_int(idx)) {
        return False;
    }
    kid: int = _K_LAST_INDEX;
    rc: int = js_object_set(re_val, kid, js_int(idx));
    if rc != 0 {
        vm_throw_native(
            make_type_error("Cannot assign to read only property 'lastIndex' of object")
        );
        return True;
    }
    return False;
}

# ══════════════════════════════════════════════════════════════════════════════
# 7.  Core RegExp methods
# ══════════════════════════════════════════════════════════════════════════════

"""RegExp.prototype.test(str) — returns JSValue true/false."""
def:pub js_regexp_test(re_val: JSValue, str_val: JSValue) -> JSValue {
    ri: int = _re_idx(re_val);
    if ri < 0 {
        return js_false();
    }
    re: JSRegExpState = _RE_REALM.regexps[ri];
    s: str = _jsval_str(str_val);

    start: int = _start_index_for(re, re_val);
    if vm_has_native_exc() {
        return js_false();
    }

    _DM_ASCII = _dm_subject_ascii(str_val);
    asc_t: bool = _DM_ASCII;
    start = _re_u2b(s, start, asc_t);
    res: list[int] = [-1];
    if start >= 0 {
        res = _do_match(re, s, start);
    }
    if res[0] < 0 {
        if re.flag_g or re.flag_y {
            if _re_set_last_index(re_val, 0) {
                return js_false();
            }
        }
        return js_false();
    }
    if re.flag_y and res[0] != start {
        if _re_set_last_index(re_val, 0) {
            return js_false();
        }
        return js_false();
    }
    if re.flag_g or re.flag_y {
        if _re_set_last_index(re_val, _re_b2u(s, res[1], asc_t)) {
            return js_false();
        }
    }
    return js_true();
}

"""RegExp.prototype.exec(str) — returns match array or null."""
def:pub js_regexp_exec(re_val: JSValue, str_val: JSValue) -> JSValue {
    ri2: int = _re_idx(re_val);
    if ri2 < 0 {
        return js_null();
    }
    re2: JSRegExpState = _RE_REALM.regexps[ri2];
    s2: str = _jsval_str(str_val);
    if vm_has_native_exc() {
        return js_null();
    }

    start2: int = _start_index_for(re2, re_val);
    if vm_has_native_exc() {
        return js_null();
    }

    _DM_ASCII = _dm_subject_ascii(str_val);
    asc2: bool = _DM_ASCII;
    # lastIndex is a UTF-16 unit index; the matcher works in bytes. A unit index
    # past the end fails the match (§22.2.7.2 step 12.a) instead of clamping.
    start2 = _re_u2b(s2, start2, asc2);
    res2: list[int] = [-1];
    if start2 >= 0 {
        res2 = _do_match(re2, s2, start2);
    }
    if res2[0] < 0 {
        if re2.flag_g or re2.flag_y {
            if _re_set_last_index(re_val, 0) {
                return js_null();
            }
        }
        return js_null();
    }
    if re2.flag_y and res2[0] != start2 {
        if _re_set_last_index(re_val, 0) {
            return js_null();
        }
        return js_null();
    }
    if re2.flag_g or re2.flag_y {
        if _re_set_last_index(re_val, _re_b2u(s2, res2[1], asc2)) {
            return js_null();
        }
    }
    return _build_match_array(re2, s2, res2, _re_input_value(str_val, s2), asc2);
}

"""RegExp.prototype.toString() — returns "/pattern/flags"."""
def:pub js_regexp_tostring(re_val: JSValue) -> JSValue {
    ri3: int = _re_idx(re_val);
    if ri3 < 0 {
        return _mk_jstr("(?:)");
    }
    re3: JSRegExpState = _RE_REALM.regexps[ri3];
    return _mk_jstr("/" + _escape_regexp_pattern(re3.pattern) + "/" + re3.flags);
}

# ══════════════════════════════════════════════════════════════════════════════
# 8.  Match array builder
# ══════════════════════════════════════════════════════════════════════════════

"""Build a JS match array from a _do_match result.
Layout: ["full", "g1", "g2", ...] with .index and .input. `input_v` is the
subject as a JSValue (the caller's original string cell when it had one)."""
def _build_match_array(
    re4: JSRegExpState, s3: str, ov: list[int], input_v: JSValue, asc: bool
) -> JSValue {
    match_start: int = ov[0];
    match_end: int = ov[1];
    # §22.2.7.2 step 24: ArrayCreate → [[Prototype]] is %Array.prototype%. The
    # elements are collected first and handed to js_array_create in one go
    # (dense storage, no per-index key interning, no length re-sets).
    elems: list[JSValue] = [_mk_jstr(str_substr(s3, match_start, match_end))];

    # Capture groups: ov[2], ov[3] = group 1; ov[4], ov[5] = group 2; …
    names4: list[str] = re4.group_names;
    # `groups` exists whenever the *pattern* has a named group (§22.2.7.2 step 32),
    # regardless of whether any of them matched.
    has_named: bool = False;
    nq: int = 0;
    while nq < len(names4) {
        if names4[nq] != "" {
            has_named = True;
        }
        nq = nq + 1;
    }
    groups_obj: JSValue = js_undefined();
    if has_named {
        groups_obj = js_object_create_null();
    }
    avail_pairs: int = (len(ov) // 2) - 1;
    if avail_pairs < 0 {
        avail_pairs = 0;
    }
    gi: int = 0;
    while gi < re4.num_groups {
        cap_s: int = -1;
        cap_e: int = -1;
        if gi < avail_pairs {
            cap_s = ov[2 + gi * 2];
            cap_e = ov[2 + gi * 2 + 1];
        }
        gv: JSValue = js_undefined();
        # PCRE2_UNSET becomes -1 (i64 all-ones).  Any negative value = unset.
        if cap_s >= 0 and cap_e >= 0 {
            gv = _mk_jstr(str_substr(s3, cap_s, cap_e));
        }
        elems.append(gv);
        if has_named and gi < len(names4) and names4[gi] != "" {
            nm_key: int = str_intern(names4[gi]);
            # CreateDataProperty (§22.2.7.2 step 33.f) — an own data property, so a
            # group literally named `__proto__` becomes a key rather than changing
            # [[Prototype]]. Duplicate names (ES2025, `(?<n>a)|(?<n>b)`): keep the
            # participating group's value, don't let a later non-matching
            # alternative overwrite a matched one with `undefined`.
            if not js_object_has_own(groups_obj, nm_key) {
                js_object_create_data_property_or_throw(groups_obj, nm_key, gv);
            } elif not jsv_is_undefined(gv) {
                js_object_create_data_property_or_throw(groups_obj, nm_key, gv);
            }
        }
        gi = gi + 1;
    }

    arr: JSValue = js_array_create(elems);
    js_object_set(arr, _K_INDEX, js_int(_re_b2u(s3, match_start, asc)));
    js_object_set(arr, _K_INPUT, input_v);
    # `groups` is ALWAYS an own property (undefined without named groups) —
    # CreateDataProperty so an `Array.prototype.groups` setter is not invoked
    # (§22.2.7.2 steps 32-34); the match array's [[Prototype]] is %Array.prototype%.
    js_object_create_data_property_or_throw(arr, _K_GROUPS, groups_obj);
    if re4.flag_d {
        idx_arr: JSValue = js_array_create([]);
        full_pair: JSValue = js_array_create(
            [js_int(_re_b2u(s3, match_start, asc)), js_int(_re_b2u(s3, match_end, asc))]
        );
        js_object_set(idx_arr, str_intern("0"), full_pair);
        idx_len: int = 1;
        # `indices.groups` (§22.2.7.7): a null-proto object of name → [start,end]
        # (or undefined) present whenever the pattern has a named group.
        idx_groups: JSValue = js_object_create_null();
        gi2: int = 0;
        while gi2 < re4.num_groups {
            cap_s2: int = -1;
            cap_e2: int = -1;
            if gi2 < avail_pairs {
                cap_s2 = ov[2 + gi2 * 2];
                cap_e2 = ov[2 + gi2 * 2 + 1];
            }
            pair_iv: JSValue = js_undefined();
            if cap_s2 >= 0 and cap_e2 >= 0 {
                pair_iv = js_array_create(
                    [js_int(_re_b2u(s3, cap_s2, asc)), js_int(_re_b2u(s3, cap_e2, asc))]
                );
            }
            js_object_set(idx_arr, str_intern_index(idx_len), pair_iv);
            if gi2 < len(names4) and names4[gi2] != "" {
                nmk_i: int = str_intern(names4[gi2]);
                if not js_object_has_own(idx_groups, nmk_i) {
                    js_object_create_data_property_or_throw(idx_groups, nmk_i, pair_iv);
                } elif not jsv_is_undefined(pair_iv) {
                    js_object_create_data_property_or_throw(idx_groups, nmk_i, pair_iv);
                }
            }
            idx_len = idx_len + 1;
            gi2 = gi2 + 1;
        }
        js_object_set(idx_arr, KEY_LENGTH, js_int(idx_len));
        if has_named {
            js_object_create_data_property_or_throw(
                idx_arr, str_intern("groups"), idx_groups
            );
        } else {
            js_object_create_data_property_or_throw(
                idx_arr, str_intern("groups"), js_undefined()
            );
        }
        js_object_create_data_property_or_throw(arr, str_intern("indices"), idx_arr);
    }
    return arr;
}

# ══════════════════════════════════════════════════════════════════════════════
# 9.  new RegExp() constructor  (NATIVE_KIND_REGEXP)
# ══════════════════════════════════════════════════════════════════════════════

"""new RegExp(pattern[, flags]) — §22.2.3.1 (called from dispatch.na.jac).

Pattern and flags are coerced with observable `ToString` (a throwing
`toString`/`valueOf` propagates), so `new RegExp({toString(){throw}})` and
`new RegExp(x, {toString(){throw}})` surface the abrupt completion. When
`pattern` is a RegExp the source is taken from its compiled state; a `flags`
argument (even `{}` → `"[object Object]"` → SyntaxError) always overrides."""
def:pub js_RegExp_ctor(args: list[JSValue]) -> JSValue {
    return js_RegExp_ctor_nt(args, True);
}

"""RegExp constructor body with the NewTarget-is-undefined flag.

`is_call` is True when invoked as `RegExp(...)` (no `new`): §22.2.3.1 step 1 then
short-circuits when `pattern` is a RegExp, `flags` is undefined, and
`pattern.constructor === RegExp` — the argument is returned unchanged (so
`RegExp(re) === re`). The construct path passes False and re-parents the result
onto NewTarget.prototype itself."""
def:pub js_RegExp_ctor_nt(args: list[JSValue], is_call: bool) -> JSValue {
    a0: JSValue = js_undefined();
    a1: JSValue = js_undefined();
    if len(args) > 0 {
        a0 = args[0];
    }
    if len(args) > 1 {
        a1 = args[1];
    }

    pat: str = "";
    fl: str = "";
    flags_given: bool = not jsv_is_undefined(a1);
    pat_is_regexp: bool = js_is_regexp(a0);

    # §22.2.3.1 step 1: `RegExp(re)` with no flags returns `re` unchanged when its
    # constructor is %RegExp% (checked via the shared RegExp.prototype identity).
    if is_call and pat_is_regexp and not flags_given {
        proto_v: JSValue = js_object_get_prototype(a0);
        if jsv_is_object_cell(proto_v)
            and jsv_is_object_cell(_REGEXP_PROTO)
            and jsv_to_table_id(proto_v) == jsv_to_table_id(_REGEXP_PROTO) {
            return a0;
        }
    }

    # ── Pattern ───────────────────────────────────────────────────────────────
    if pat_is_regexp {
        ri4: int = _re_idx(a0);
        if ri4 >= 0 {
            re5: JSRegExpState = _RE_REALM.regexps[ri4];
            pat = re5.pattern;
            if not flags_given {
                fl = re5.flags;
            }
        }
    } elif jsv_is_undefined(a0) {
        pat = "";
    } else {
        pat = js_to_string_observable(a0);
        if vm_has_native_exc() {
            return js_undefined();
        }
    }

    # ── Flags ─────────────────────────────────────────────────────────────────
    if flags_given {
        if jsv_is_string_cell(a1) {
            fl = str_from_id(jsv_to_table_id(a1));
        } else {
            fl = js_to_string_observable(a1);
            if vm_has_native_exc() {
                return js_undefined();
            }
        }
    }

    return js_regexp_create(pat, fl);
}

# ══════════════════════════════════════════════════════════════════════════════
# 10.  Replacement string expander  ($& $1 $2 etc.)
# ══════════════════════════════════════════════════════════════════════════════

"""Expand a replacement template string.
  $&  → full match
  $`  → prefix (text before match)
  $'  → suffix (text after match)
  $n  → capture group n (1-indexed)
  $$  → literal '$'
"""
def _expand_replacement(repl: str, s: str, ov: list[int], re_st: JSRegExpState) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(repl);
    while i < n {
        c: str = repl[i];
        if c == "$" and i + 1 < n {
            nc: str = repl[i + 1];
            if nc == "&" {
                out = out + str_substr(s, ov[0], ov[1]);
                i = i + 2;
                continue;
            } elif nc == "`" {
                out = out + str_substr(s, 0, ov[0]);
                i = i + 2;
                continue;
            } elif nc == "'" {
                out = out + str_substr(s, ov[1], len(s));
                i = i + 2;
                continue;
            } elif nc >= "0" and nc <= "9" {
                # $n / $nn — a one- or two-digit capture index (§22.2.5.9). The
                # two-digit form 01–99 is tried first; a leading-zero single digit
                # ($0) is not a valid group, so it falls through to a literal.
                gn: int = ord(nc) - 48;
                consumed2: bool = False;
                if i + 2 < n and _is_decimal_digit(repl[i + 2]) {
                    gn2: int = gn * 10 + (ord(repl[i + 2]) - 48);
                    if gn2 >= 1 and gn2 <= re_st.num_groups {
                        gn = gn2;
                        consumed2 = True;
                    }
                }
                if gn >= 1 and gn <= re_st.num_groups {
                    cs: int = ov[2 + (gn - 1) * 2];
                    ce: int = ov[2 + (gn - 1) * 2 + 1];
                    if cs >= 0 and ce >= 0 {
                        out = out + str_substr(s, cs, ce);
                    }
                    i = i + 2;
                    if consumed2 {
                        i = i + 1;
                    }
                    continue;
                }
            } elif nc == "<" {
                names: list[str] = re_st.group_names;
                jn: int = i + 2;
                nm2: str = "";
                while jn < n and repl[jn] != ">" {
                    nm2 = nm2 + repl[jn];
                    jn = jn + 1;
                }
                if jn < n {
                    gi_name: int = 0;
                    while gi_name < len(names) {
                        if names[gi_name] == nm2 {
                            csn: int = ov[2 + gi_name * 2];
                            cen: int = ov[2 + gi_name * 2 + 1];
                            if csn >= 0 and cen >= 0 {
                                out = out + str_substr(s, csn, cen);
                            }
                            break;
                        }
                        gi_name = gi_name + 1;
                    }
                    i = jn + 1;
                    continue;
                }
            } elif nc == "$" {
                out = out + "$";
                i = i + 2;
                continue;
            }
        }
        out = out + c;
        i = i + 1;
    }
    return out;
}

# ══════════════════════════════════════════════════════════════════════════════
# 11.  String.prototype helpers backed by PCRE2
# ══════════════════════════════════════════════════════════════════════════════

"""String.prototype.match(regexp) — returns match array or null."""
def:pub js_str_match_re(s_val: JSValue, re_val: JSValue) -> JSValue {
    re6: JSValue = js_coerce_regexp(re_val);
    ri5: int = _re_idx(re6);
    if ri5 < 0 {
        return js_null();
    }
    re7: JSRegExpState = _RE_REALM.regexps[ri5];
    s: str = _jsval_str(s_val);

    if not re7.flag_g {
        # Non-global: return single exec result
        return js_regexp_exec(re6, s_val);
    }

    # Global: collect all full-match strings into a real Array.
    elems_m: list[JSValue] = [];
    pos: int = 0;
    slen: int = len(s);
    _DM_ASCII = _dm_subject_ascii(s_val);
    while pos <= slen {
        res: list[int] = _do_match(re7, s, pos);
        if res[0] < 0 {
            break;
        }
        elems_m.append(_mk_jstr(str_substr(s, res[0], res[1])));
        # lastIndex = e; an empty match then advances one character (§22.2.6.8
        # step 6.e.iii — AdvanceStringIndex; the subject is UTF-8)
        if res[1] > res[0] {
            pos = res[1];
        } else {
            pos = res[1] + _re_char_len(s, res[1]);
        }
    }
    if len(elems_m) == 0 {
        return js_null();
    }
    return js_array_create(elems_m);
}

def _iter_result(value: JSValue, done: bool) -> JSValue {
    r: JSValue = js_object_create_null();
    js_object_set(r, str_intern("value"), value);
    js_object_set(r, str_intern("done"), _js_bool(done));
    return r;
}

def:pub js_str_matchAll_re(s_val: JSValue, re_val: JSValue) -> JSValue {
    re_m: JSValue = js_coerce_regexp(re_val);
    ri_m: int = _re_idx(re_m);
    if ri_m < 0 {
        return _iter_result(js_undefined(), True);
    }
    re_s: JSRegExpState = _RE_REALM.regexps[ri_m];
    if not re_s.flag_g {
        vm_throw_native(
            make_type_error(
                "String.prototype.matchAll called with a non-global RegExp argument"
            )
        );
        return js_undefined();
    }
    s: str = _jsval_str(s_val);
    inp_m: JSValue = _re_input_value(s_val, s);
    out: JSValue = js_array_create([]);
    pos: int = 0;
    cnt: int = 0;
    slen: int = len(s);
    _DM_ASCII = _dm_subject_ascii(s_val);
    asc_m: bool = _DM_ASCII;
    while pos <= slen {
        res: list[int] = _do_match(re_s, s, pos);
        if res[0] < 0 {
            break;
        }
        js_object_set(
            out, str_intern_index(cnt), _build_match_array(re_s, s, res, inp_m, asc_m)
        );
        cnt = cnt + 1;
        if res[1] > res[0] {
            pos = res[1];
        } else {
            pos = res[1] + _re_char_len(s, res[1]);
        }
    }
    js_object_set(out, KEY_LENGTH, js_int(cnt));
    it: JSValue = js_object_create_null();
    js_object_set(it, _KEY_MATCHALL_STATE, out);
    js_object_set(it, _KEY_MATCHALL_INDEX, js_int(0));
    js_object_set(
        it,
        str_intern("next"),
        js_native_create("next", 0, NATIVE_KIND_REGEXP_MATCHALL_NEXT)
    );
    # Iterator protocol: [Symbol.iterator]() must return `this` so for...of works.
    js_object_set(
        it,
        SYMBOL_KEY_BASE + SYMBOL_ITERATOR,
        js_native_create("[Symbol.iterator]", 0, NATIVE_KIND_REGEXP_MATCHALL_ITER)
    );
    return it;
}

def:pub js_regexp_matchall_next(this_val: JSValue) -> JSValue {
    state: JSValue = js_object_get(this_val, _KEY_MATCHALL_STATE);
    idx_v: JSValue = js_object_get(this_val, _KEY_MATCHALL_INDEX);
    idx: int = _to_nonneg_int(idx_v);
    ln: int = 0;
    lv: JSValue = js_object_get(state, KEY_LENGTH);
    if jsv_is_int32(lv) {
        ln = jsv_to_int32(lv);
    } elif jsv_is_double(lv) {
        ln = int(jsv_to_double(lv));
    }
    if idx >= ln {
        return _iter_result(js_undefined(), True);
    }
    item: JSValue = js_object_get(state, str_intern_index(idx));
    js_object_set(this_val, _KEY_MATCHALL_INDEX, js_int(idx + 1));
    return _iter_result(item, False);
}

"""String.prototype.search(regexp) — returns index or -1."""
def:pub js_str_search_re(s_val2: JSValue, re_val2: JSValue) -> JSValue {
    re8: JSValue = js_coerce_regexp(re_val2);
    ri6: int = _re_idx(re8);
    if ri6 < 0 {
        return js_int(-1);
    }
    re9: JSRegExpState = _RE_REALM.regexps[ri6];
    s6: str = _jsval_str(s_val2);
    _DM_ASCII = _dm_subject_ascii(s_val2);
    res6: list[int] = _do_match(re9, s6, 0);
    if res6[0] < 0 {
        return js_int(-1);
    }
    return js_int(_re_b2u(s6, res6[0], _DM_ASCII));
}

"""String.prototype.replace(regexp_or_str, replacement)."""
def:pub js_str_replace_re(
    s_val3: JSValue, search3: JSValue, repl3: JSValue
) -> JSValue {
    s7: str = _jsval_str(s_val3);
    if not js_is_regexp(search3) {
        # Plain string — delegate to caller who already checked js_is_regexp
        return s_val3;
    }
    ri7: int = _re_idx(search3);
    if ri7 < 0 {
        return s_val3;
    }
    re10: JSRegExpState = _RE_REALM.regexps[ri7];
    r7: str = "";
    if jsv_is_string_cell(repl3) {
        r7 = str_from_id(jsv_to_table_id(repl3));
    } else {
        r7 = js_to_string_prim(repl3);
    }
    slen7: int = len(s7);
    _DM_ASCII = _dm_subject_ascii(s_val3);

    if not re10.flag_g {
        res7: list[int] = _do_match(re10, s7, 0);
        if res7[0] < 0 {
            return _re_input_value(s_val3, s7);
        }
        # All pieces inline: a named owned str local would never be released.
        return _mk_jstr(
            str_substr(s7, 0, res7[0])
                + _expand_replacement(r7, s7, res7, re10)
                + str_substr(s7, res7[1], slen7)
        );
    }
    return _mk_jstr(_re_replace_global_build(re10, s7, r7, _DM_ASCII));
}

"""Global regexp replace body: one PCRE2 scan per match, pieces joined once
(was `out = out + piece` — O(n²) copying and a leaked intermediate per match)."""
def _re_replace_global_build(re10: JSRegExpState, s7: str, r7: str, asc: bool) -> str {
    parts: list[str] = [];
    has_dollar: bool = r7.find("$") >= 0;
    slen7: int = len(s7);
    pos7: int = 0;
    # nextSourcePosition (§22.2.6.11 step 14): the subject copied up to each
    # match, the replacement for it, then from the match's end.
    nsp7: int = 0;
    _DM_ASCII = asc;
    while pos7 <= slen7 {
        res8: list[int] = _do_match(re10, s7, pos7);
        if res8[0] < 0 {
            break;
        }
        parts.append(str_substr(s7, nsp7, res8[0]));
        if has_dollar {
            parts.append(_expand_replacement(r7, s7, res8, re10));
        } else {
            parts.append(r7);
        }
        nsp7 = res8[1];
        # lastIndex = e; an empty match then advances one character
        if res8[1] > res8[0] {
            pos7 = res8[1];
        } else {
            pos7 = res8[1] + _re_char_len(s7, res8[1]);
        }
    }
    parts.append(str_substr(s7, nsp7, slen7));
    return "".join(parts);
}

"""Byte length of the UTF-8 character at byte `i` of `s` (1 past the end):
the matchers' AdvanceStringIndex step."""
def _re_char_len(s: str, i: int) -> int {
    if i >= len(s) {
        return 1;
    }
    cl_b: int = ord(s[i]);
    if cl_b < 192 {
        return 1;
    }
    if cl_b >= 240 {
        return 4;
    }
    if cl_b >= 224 {
        return 3;
    }
    return 2;
}

"""String.prototype.split(regexp_or_str, limit?)."""
def:pub js_str_split_re(s_val4: JSValue, sep4: JSValue, limit_v4: JSValue) -> JSValue {
    s9: str = _jsval_str(s_val4);
    # §22.2.5.11 step 8: lim = ToUint32(limit) (observable — valueOf/Symbol throw).
    lim9: int = 4294967295;
    if not jsv_is_undefined(limit_v4) {
        lnum: float = js_to_number_observable(limit_v4);
        if lnum != lnum {
            lim9 = 0;
        } elif lnum >= 1.7976931348623157e+308 {
            lim9 = 0;
        } elif lnum <= -1.7976931348623157e+308 {
            lim9 = 0;
        } else {
            lt: int = int(lnum);
            lm: int = lt % 4294967296;
            if lm < 0 {
                lm = lm + 4294967296;
            }
            lim9 = lm;
        }
    }

    if not js_is_regexp(sep4) {
        return s_val4;
    }  # caller checked

    ri8: int = _re_idx(sep4);
    if ri8 < 0 {
        # Real Array (Array.prototype chain) so `.constructor`/`.map`/… resolve.
        return js_array_create([s_val4]);
    }
    re14: JSRegExpState = _RE_REALM.regexps[ri8];
    _DM_ASCII = _dm_subject_ascii(s_val4);
    # RegExp.prototype[@@split] — ECMAScript §22.2.5.11. Build a real Array via
    # js_array_create so it inherits Array.prototype.
    elems10: list[JSValue] = [];
    slen10: int = len(s9);

    # lim == 0 → empty array (spec step 12).
    if lim9 == 0 {
        return js_array_create(elems10);
    }

    # Empty string special case (step 14): one match attempt; empty result if it
    # matches, else the whole (empty) string.
    if slen10 == 0 {
        res_e: list[int] = _do_match(re14, s9, 0);
        if res_e[0] >= 0 {
            return js_array_create(elems10);
        }
        elems10.append(_mk_jstr(s9));
        return js_array_create(elems10);
    }

    p10: int = 0;  # start of the current (not-yet-emitted) piece
    q10: int = 0;  # scan cursor
    while q10 < slen10 {
        # SplitMatch semantics (§22.2.5.11): the separator must match *at* q, not
        # merely somewhere after it. _do_match searches forward, so a match that
        # starts past q (e.g. /$/ found at the end while q is interior) does not
        # count as a separator at q — advance q by one and retry. Without this,
        # `"x".split(/$/)` would wrongly split off a trailing "".
        res10: list[int] = _do_match(re14, s9, q10);
        if res10[0] < 0 {
            break;
        }
        mstart: int = res10[0];
        # _do_match returns the LEFTMOST match at or after q, so no separator can
        # start anywhere in [q, mstart): jump q there instead of re-searching one
        # code unit at a time (was one full PCRE2 scan per character — 14ms and
        # 800 matcher calls for an 800-byte split(/\n/)). A match that starts at
        # the end of the string is never a separator (the spec only tries
        # q < size), so `"ab".split(/$/)` stays ["ab"].
        if mstart >= slen10 {
            break;
        }
        q10 = mstart;
        e10: int = res10[1];
        if e10 > slen10 {
            e10 = slen10;
        }
        # Zero-width match at the last split point (e.g. /^/ or /(?:)/ at p) would
        # emit a spurious empty piece — skip it and advance one code unit.
        if e10 == p10 {
            q10 = q10 + 1;
            continue;
        }
        # Emit the piece [p, mstart) and any captures, then resume after the match.
        elems10.append(_mk_jstr(str_substr(s9, p10, mstart)));
        if len(elems10) >= lim9 {
            return js_array_create(elems10);
        }
        gi10: int = 0;
        while gi10 < re14.num_groups {
            cap_s: int = res10[2 + gi10 * 2];
            cap_e: int = res10[2 + gi10 * 2 + 1];
            gv10: JSValue = js_undefined();
            if cap_s >= 0 and cap_e >= 0 {
                gv10 = _mk_jstr(str_substr(s9, cap_s, cap_e));
            }
            elems10.append(gv10);
            if len(elems10) >= lim9 {
                return js_array_create(elems10);
            }
            gi10 = gi10 + 1;
        }
        p10 = e10;
        q10 = p10;
    }
    elems10.append(_mk_jstr(str_substr(s9, p10, slen10)));
    return js_array_create(elems10);
}

# ══════════════════════════════════════════════════════════════════════════════
# Pristine-RegExp fast paths (V4.17)
# ══════════════════════════════════════════════════════════════════════════════
# String.prototype.match / replace / split / search run the engine's own
# matchers (one PCRE2 scan per match, no per-match result objects) directly,
# without the JS-layer @@match / @@replace / @@split / @@search wrappers
# (builtins_stubs.js) and their `pristine(rx)` probe, when nothing those
# algorithms could observe differs from the built-ins: the RegExp has the
# layout of a fresh one (only `lastIndex` own, holding a number) and
# %RegExp.prototype% as [[Prototype]], and %RegExp.prototype% still has the
# shape and the exec / flags / flag-getter / constructor / @@method values
# recorded at the end of bootstrap. Shapes are never recycled and the
# recorded values are pinned, so an equal shape id or value is the same one.

glob _RE_PS_PROTO: JSValue = js_undefined(),
     _RE_PS_PROTO_SID: int = -1,
     _RE_PS_SI: list[int] = [],
     _RE_PS_VAL: list[JSValue] = [],
     _RE_PS_INST_SID: int = -1,
     _RE_PS_LI_SI: int = -1,
     _RE_PS_MK_SI: int = -1,
     _RE_PS_CTOR: JSValue = js_undefined(),
     _RE_PS_SPECIES: JSValue = js_undefined();

"""Record the pristine state; called once at the end of bootstrap, before any
user code. Leaves the fast paths off when a layout is not the expected one."""
def:pub js_regexp_pristine_snapshot -> None {
    _RE_PS_PROTO_SID = -1;
    if not jsv_is_object_cell(_REGEXP_PROTO) or jsv_to_table_id(_REGEXP_PROTO) <= 0 {
        return;
    }
    ps_sid: int = js_object_ic_shape(_REGEXP_PROTO);
    if ps_sid < 0 {
        return;
    }
    # index 0: exec, 1: flags, 10: constructor (read below)
    ps_keys: list[int] = [
        str_intern("exec"),
        str_intern("flags"),
        str_intern("global"),
        str_intern("ignoreCase"),
        str_intern("multiline"),
        str_intern("dotAll"),
        str_intern("unicode"),
        str_intern("unicodeSets"),
        str_intern("sticky"),
        str_intern("hasIndices"),
        str_intern("constructor"),
        SYMBOL_KEY_BASE + SYMBOL_MATCH,
        SYMBOL_KEY_BASE + SYMBOL_REPLACE,
        SYMBOL_KEY_BASE + SYMBOL_SEARCH,
        SYMBOL_KEY_BASE + SYMBOL_SPLIT
    ];
    ps_si: list[int] = [];
    ps_val: list[JSValue] = [];
    ps_k: int = 0;
    while ps_k < len(ps_keys) {
        ps_pk: int = shape_lookup(ps_sid, ps_keys[ps_k]);
        if ps_pk < 0 {
            return;
        }
        ps_v: JSValue = js_object_slot_at_id(
            jsv_to_table_id(_REGEXP_PROTO), ps_pk // 16
        );
        gc_pin_value(ps_v);
        ps_si.append(ps_pk // 16);
        ps_val.append(ps_v);
        ps_k = ps_k + 1;
    }
    # exec must be the native one the fast paths stand in for (the flags
    # getter is builtins_stubs.js's spec getter: it reads the flag getters,
    # which are compared below, so its result is the compiled flags)
    if not is_native_val(ps_val[0])
        or get_native_kind(ps_val[0]) != NATIVE_KIND_REGEXP_EXEC {
        return;
    }
    ps_ctor: JSValue = ps_val[10];
    if not jsv_is_object_cell(ps_ctor) {
        return;
    }
    ps_sp: JSValue = js_object_get_own_accessor_getter(
        ps_ctor, SYMBOL_KEY_BASE + SYMBOL_SPECIES
    );
    if jsv_is_undefined(ps_sp) {
        return;
    }
    gc_pin_value(ps_sp);
    # a fresh instance's layout, from a sample kept alive
    ps_re: JSValue = js_regexp_create("a", "");
    if not jsv_is_object_cell(ps_re) {
        return;
    }
    gc_pin_value(ps_re);
    ps_isid: int = js_object_ic_shape(ps_re);
    if ps_isid < 0 {
        return;
    }
    ps_li: int = shape_lookup(ps_isid, str_intern("lastIndex"));
    if ps_li < 0 or (ps_li & SHAPE_ATTR_ACCESSOR) != 0 {
        return;
    }
    ps_mk: int = shape_lookup(ps_isid, _KEY_IS_REGEXP);
    _RE_PS_MK_SI = -1;
    if ps_mk >= 0 and (ps_mk & SHAPE_ATTR_ACCESSOR) == 0 {
        _RE_PS_MK_SI = ps_mk // 16;
    }
    _RE_PS_SI = ps_si;
    _RE_PS_VAL = ps_val;
    _RE_PS_INST_SID = ps_isid;
    _RE_PS_LI_SI = ps_li // 16;
    _RE_PS_CTOR = ps_ctor;
    _RE_PS_SPECIES = ps_sp;
    _RE_PS_PROTO = _REGEXP_PROTO;
    _RE_PS_PROTO_SID = ps_sid;
}

"""Compiled-regexp index of `rx` when the fast paths may stand in for the spec
algorithms on it (see above), else -1."""
def:pub js_regexp_pristine_idx(rx: JSValue) -> int {
    if _RE_PS_PROTO_SID < 0 or not jsv_is_object_cell(rx) {
        return -1;
    }
    pi_id: int = jsv_to_table_id(rx);
    if pi_id <= 0 {
        return -1;
    }
    # the fresh-instance shape (a miss reads the hole) and a numeric lastIndex
    pi_li: JSValue = js_object_ic_hit(rx, _RE_PS_INST_SID, _RE_PS_LI_SI);
    if not (jsv_is_int32(pi_li) or jsv_is_double(pi_li)) {
        return -1;
    }
    pi_pid: int = jsv_to_table_id(_RE_PS_PROTO);
    if js_object_proto_idx_id(pi_id) != pi_pid
        or js_object_elems_kind_id(pi_id) != ELEMS_NONE {
        return -1;
    }
    if js_object_ic_shape(_RE_PS_PROTO) != _RE_PS_PROTO_SID {
        return -1;
    }
    pi_k: int = 0;
    while pi_k < len(_RE_PS_SI) {
        if not (js_object_slot_at_id(pi_pid, _RE_PS_SI[pi_k]) == _RE_PS_VAL[pi_k]) {
            return -1;
        }
        pi_k = pi_k + 1;
    }
    pi_m: JSValue = js_undefined();
    if _RE_PS_MK_SI >= 0 {
        pi_m = js_object_slot_at_id(pi_id, _RE_PS_MK_SI);
    } else {
        pi_m = js_object_get(rx, _KEY_IS_REGEXP);
    }
    if not jsv_is_int32(pi_m) {
        return -1;
    }
    pi_i: int = jsv_to_int32(pi_m);
    if pi_i < 0 or pi_i >= len(_RE_REALM.regexps) {
        return -1;
    }
    return pi_i;
}

"""String.prototype.match(rx) on a primitive string, as @@match does it for
a pristine rx (§22.2.6.8): a non-global rx is RegExpExec — the built-in exec;
a global one sets lastIndex to 0 and collects every match (the final failing
exec leaves lastIndex 0). The hole when the spec path must run."""
def:pub js_regexp_fast_str_match(s_val: JSValue, rx: JSValue) -> JSValue {
    if not jsv_is_string_cell(s_val) {
        return jsv_hole();
    }
    fm_i: int = js_regexp_pristine_idx(rx);
    if fm_i < 0 {
        return jsv_hole();
    }
    fm_re: JSRegExpState = _RE_REALM.regexps[fm_i];
    if not fm_re.flag_g {
        return js_regexp_exec(rx, s_val);
    }
    # sticky: the JS path; /u /v on a non-ASCII subject: positions in the
    # surrogate-paired copy (_do_match_conv) — the JS path
    if fm_re.flag_y {
        return jsv_hole();
    }
    if (fm_re.flag_u or fm_re.flag_v) and not _dm_subject_ascii(s_val) {
        return jsv_hole();
    }
    _ = js_object_ic_set_hit(rx, _RE_PS_INST_SID, _RE_PS_LI_SI, js_int(0));
    return js_str_match_re(s_val, rx);
}

"""String.prototype.replace(rx, replacement) with a primitive string subject
and replacement — @@replace's pristine branch (§22.2.6.11): a global rx's
lastIndex is set to 0, then the native replace. The hole otherwise."""
def:pub js_regexp_fast_str_replace(
    s_val: JSValue, rx: JSValue, rv: JSValue
) -> JSValue {
    if not jsv_is_string_cell(s_val) or not jsv_is_string_cell(rv) {
        return jsv_hole();
    }
    fr_i: int = js_regexp_pristine_idx(rx);
    if fr_i < 0 or _RE_REALM.regexps[fr_i].flag_y {
        return jsv_hole();
    }
    if _RE_REALM.regexps[fr_i].flag_g {
        _ = js_object_ic_set_hit(rx, _RE_PS_INST_SID, _RE_PS_LI_SI, js_int(0));
    }
    return js_str_replace_re(s_val, rx, rv);
}

"""String.prototype.split(rx, limit) with a primitive string subject and an
absent or int32 limit — @@split's pristine branch (§22.2.6.14: the species
constructor is %RegExp%, so the splitter is an equivalent fresh RegExp and rx
itself is untouched). The hole otherwise."""
def:pub js_regexp_fast_str_split(s_val: JSValue, rx: JSValue, lim: JSValue) -> JSValue {
    if not jsv_is_string_cell(s_val)
        or not (jsv_is_undefined(lim) or jsv_is_int32(lim)) {
        return jsv_hole();
    }
    fs_i: int = js_regexp_pristine_idx(rx);
    if fs_i < 0 or _RE_REALM.regexps[fs_i].flag_y {
        return jsv_hole();
    }
    if not (
        js_object_get_own_accessor_getter(_RE_PS_CTOR, SYMBOL_KEY_BASE + SYMBOL_SPECIES)
        == _RE_PS_SPECIES
    ) {
        return jsv_hole();
    }
    return js_str_split_re(s_val, rx, lim);
}

"""String.prototype.search(rx) on a primitive string — @@search's pristine
branch (§22.2.6.12: lastIndex ends where it started). The hole otherwise."""
def:pub js_regexp_fast_str_search(s_val: JSValue, rx: JSValue) -> JSValue {
    if not jsv_is_string_cell(s_val) {
        return jsv_hole();
    }
    fq_i: int = js_regexp_pristine_idx(rx);
    if fq_i < 0 or _RE_REALM.regexps[fq_i].flag_y {
        return jsv_hole();
    }
    return js_str_search_re(s_val, rx);
}

def:pub js_regexp_symbol_match(this_val: JSValue, arg: JSValue) -> JSValue {
    return js_str_match_re(arg, this_val);
}

def:pub js_regexp_symbol_matchall(this_val: JSValue, arg: JSValue) -> JSValue {
    return js_str_matchAll_re(arg, this_val);
}

def:pub js_regexp_symbol_search(this_val: JSValue, arg: JSValue) -> JSValue {
    return js_str_search_re(arg, this_val);
}

def:pub js_regexp_symbol_replace(
    this_val: JSValue, arg0: JSValue, arg1: JSValue
) -> JSValue {
    return js_str_replace_re(arg0, this_val, arg1);
}

def:pub js_regexp_symbol_split(
    this_val: JSValue, arg0: JSValue, arg1: JSValue
) -> JSValue {
    return js_str_split_re(arg0, this_val, arg1);
}
