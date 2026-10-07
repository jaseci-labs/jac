"""
JSString: JavaScript string type for js_engine.

ECMAScript strings are immutable sequences of UTF-16 code units.  At this
phase we represent them as Jac `str` (UTF-8 / Python unicode) and implement
all ECMAScript String.prototype methods that can be built from the native Jac
str builtins that are verified to work in LLVM codegen.

Known native limitation: `s[a:b]` slice syntax returns only the first character.
All substring extraction uses `str_substr()` which builds the result via
character-by-character index access.

Bun reference: src/string/bun_string.zig, src/bun.js/webcore/Blob.zig
"""

import from engine.src.runtime.realm { Realm, gc_note_alloc, realm_request_gc }
import from engine.src.runtime.mem { Ptr, io_alloc, io_free, write_byte, str_from_raw }

# Byte-based GC trigger for heap strings. The object trigger counts ALLOCATIONS
# (gc_note_alloc), which cannot tell a 500KB slice from a 1-char string: a
# slice-heavy phase with few object allocations (rollup's render — magic-string
# and sourcemap chains over MB chunks) never reached the adaptive object
# threshold, so string garbage accumulated to 12GB under --gc (1GB of discarded
# slices with no object churn: 0 collections). Every leaf byte allocation
# (str_heap, rope flatten) is metered here and requests a collection once the
# bytes allocated since the last sweep exceed a limit that gc_str_bytes_reset
# re-derives from the surviving heap (floor _HS_GC_MIN_LIMIT).
glob _HS_BYTES_SINCE_GC: int = 0,
     _HS_GC_MIN_LIMIT: int = 67108864,
     _HS_GC_LIMIT: int = 67108864;

# 64MB floor (JAC_GC_STR_MB overrides)
"""Meter `nb` freshly allocated heap-string bytes; request a GC at the limit."""
def _hs_note_bytes(nb: int) {
    _HS_BYTES_SINCE_GC = _HS_BYTES_SINCE_GC + nb;
    if _HS_BYTES_SINCE_GC >= _HS_GC_LIMIT and _STR_REALM.gc_enabled {
        realm_request_gc(_STR_REALM);
    }
}

"""Sweep hook: restart the byte meter and size the next limit from the surviving
heap — live heap-string bytes plus ~96B per live object, floored — so the
string-driven collection cadence scales with the heap like the object one."""
def:pub gc_str_bytes_reset(live_bytes: int, live_objs: int) {
    _HS_BYTES_SINCE_GC = 0;
    lim: int = live_bytes + live_objs * 96;
    if lim < _HS_GC_MIN_LIMIT {
        lim = _HS_GC_MIN_LIMIT;
    }
    _HS_GC_LIMIT = lim;
}

"""Set the heap-string byte floor (MB) between collections (JAC_GC_STR_MB)."""
def:pub gc_str_min_limit_set_mb(mb: int) {
    if mb > 0 {
        _HS_GC_MIN_LIMIT = mb * 1048576;
        if _HS_GC_LIMIT < _HS_GC_MIN_LIMIT {
            _HS_GC_LIMIT = _HS_GC_MIN_LIMIT;
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────────
# String intern state — stored in the realm singleton (_STR_REALM).
# The bridge pattern avoids signature changes at the 200+ call sites while
# enabling per-context isolation when str_set_realm() is called at startup.
# Starts null; str_set_realm() MUST be called before any str_intern().
# ─────────────────────────────────────────────────────────────────────────────────
glob _STR_REALM: Realm;

"""Wire this module to a specific realm's intern tables.
Call once at startup (e.g. from global_context_create) before any str_intern()."""
def:pub str_set_realm(r: Realm) {
    _STR_REALM = r;
}

"""Return the realm wired to this module (set via str_set_realm at startup)."""
def:pub str_get_realm -> Realm {
    return _STR_REALM;
}

# ─────────────────────────────────────────────────────────────────────────────
# Low-level str helpers (work around native slice bug)
# ─────────────────────────────────────────────────────────────────────────────

"""
Extract the character at position `i` from `s`.
Supports negative indices (Python semantics).
Returns "" if `i` is out of bounds.
"""
def str_char_at(s: str, i: int) -> str {
    n: int = len(s);
    if n == 0 {
        return "";
    }
    idx: int = i;
    if idx < 0 {
        idx = n + idx;
    }
    if idx < 0 or idx >= n {
        return "";
    }
    return s[idx];
}

"""
Extract the substring s[start:end] (end exclusive, Python semantics).
Negative indices are normalised before the call.
Uses a character loop — avoids the native slice bug.
"""
def:pub str_substr(s: str, start: int, end: int) -> str {
    n: int = len(s);
    # Normalise negative indices
    st: int = start;
    en: int = end;
    if st < 0 {
        st = n + st;
        if st < 0 {
            st = 0;
        }
    }
    if en < 0 {
        en = n + en;
        if en < 0 {
            en = 0;
        }
    }
    if st > n {
        st = n;
    }
    if en > n {
        en = n;
    }
    if st >= en {
        return "";
    }
    # Jac `str` is UTF-8 byte-wise, so [st,en) is one contiguous byte range.
    # `s[st:en]` alone is a BORROWED view ({root, data, len} into `s`); the
    # result goes on to outlive `s` (heap_strings, swept by the JS GC), so take
    # an owned, length-stamped copy: a repeat with a runtime count memcpys the
    # view once (cf. str_stamp_copy). Replaces a per-byte write_byte(ord(s[k]))
    # loop plus a second full copy through str_from_raw.
    cp_n: int = 1;
    return s[st:en] * cp_n;
}

"""Return a length-STAMPED copy of `s`.

A string reinterpreted from a raw buffer pointer (e.g. a file read via
`content: str = buf_ptr`) carries no stamped length header, so every subsequent
`s[i]` recomputes `strlen(s)` for its bounds check — O(len) per index, i.e. O(n²)
to scan the whole string (the lexer scanning a multi-MB imported module froze on
this). `s * 1` (string repetition, types.impl.jac ~L2425) reads `s`'s length once,
memcpys into a fresh buffer, and stamps its length header — a single O(n) pass that
yields an O(1)-indexable copy. (Concatenating an empty-string literal would be
constant-folded away before codegen and skip the stamping copy; a `* 1` repeat with
a runtime count is not folded.)"""
def:pub str_stamp_copy(s: str) -> str {
    n: int = 1;
    return s * n;
}

"""
Return a list of individual characters in `s`.
Useful when you need random access beyond what single-char indexing provides.
"""
def str_chars(s: str) -> list[str] {
    result: list[str] = [];
    for c in s {
        result.append(c);
    }
    return result;
}

# ─────────────────────────────────────────────────────────────────────────────
# FNV-1a hash (same as Bun's string hash for short strings)
# ─────────────────────────────────────────────────────────────────────────────

"""
Compute a 32-bit FNV-1a hash of a string.
Uses ord() on each character — verified to work in native codegen.
"""
def str_hash(s: str) -> int {
    return hash(s);
}

# ─────────────────────────────────────────────────────────────────────────────
# String interning
# ─────────────────────────────────────────────────────────────────────────────

"""True if every byte of `s` is ASCII (< 128). O(n), called once per string."""
def _str_is_ascii(s: str) -> bool {
    # str.isascii() lowers to a tight native byte loop (load/compare/next);
    # the ord(s[i]) loop it replaces cost ~4x as much per byte, on every
    # non-interned string creation (_ascii_flag).
    return s.isascii();
}

"""True when s contains the 4-char NUL sentinel `\\x00` (bytes 92 120 48 48)."""
def _str_has_nul_sentinel(s: str) -> bool {
    n: int = len(s);
    if n < 4 {
        return False;
    }
    return s.find("\\x00") >= 0;
}

"""Cache flag value: 1 = "byte-clean" ASCII (every byte < 128 AND no `\\x00`
NUL sentinel, so byte offset == UTF-16 unit offset for the whole string);
2 = anything else. The sentinel test moved HERE (computed once per cell):
js_string_utf16_len_cell / js_string_unit_at_cell used to `find("\\x00")`
over the WHOLE string on every `.length` / `charCodeAt` call — 32µs per
charCodeAt on a 650KB string, i.e. the sourcemap-codec decode loop in rollup's
render phase took 20s per map and OOM'd the build."""
def _ascii_flag(s: str) -> int {
    if not _str_is_ascii(s) {
        return 2;
    }
    if _str_has_nul_sentinel(s) {
        return 2;
    }
    return 1;
}

"""Reserved hidden-marker-key band: internal object keys (markers.jac
1000001–1000026, jsobject KEY_CTOR_KIND 1000023, NAPI error tags 1000030/31,
NAPI hidden keys 1009001+) live in [1_000_000, 1_010_000). Intern ids are
sequential, so a process that interns >1M distinct strings (a vite/rollup-scale
bundle) would otherwise mint STRING keys aliasing these markers — an ordinary
property write then corrupts promise internals / TDZ sentinels / resolve-fn
brands on that object. Symptom that cost days: one `fileOperationQueue.run()`
promise's state clobbered → resolve() a silent no-op → 'Unexpected early exit'
in `vite build`; repro: intern 1M+ names then `t['name']=1` throws a bogus
"Cannot access 't' before initialization" (the name aliased _KEY_IS_TDZ)."""
glob _INTERN_RESERVED_LO: int = 1000000;
glob _INTERN_RESERVED_HI: int = 1010000;

"""
Intern `s` and return its unique integer ID.
Repeated calls with equal strings return the same ID.
"""
def:pub str_intern(s: str) -> int {
    # One probe for the common already-interned case (`in` then `[]` hashed
    # and compared the string twice).
    si_known: int = _STR_REALM.intern_by_str.get(s, -1);
    if si_known >= 0 {
        return si_known;
    }
    id: int = _STR_REALM.intern_next_id;
    if id >= _INTERN_RESERVED_LO and id < _INTERN_RESERVED_HI {
        id = _INTERN_RESERVED_HI;
    }
    _STR_REALM.intern_next_id = id + 1;
    _STR_REALM.intern_by_str[s] = id;
    _STR_REALM.intern_by_id[id] = s;
    # Record ASCII-ness for O(1) charAt/charCodeAt indexing.
    _STR_REALM.intern_ascii[id] = _ascii_flag(s);
    return id;
}

# Per-intern-id answer to "is this key a canonical array index" (ES §6.1.7:
# ToString(ToUint32(k)) == k, k ≠ 2^32−1): one byte per id, eight ids per
# word — 0 not computed yet, 1 no, 2 yes. An id's text never changes (one
# table for the process, set once at startup; ids are never reused), so an
# answer never goes stale. Property operations ask this about keys on every
# array-like object; scanning the text each time (str_from_id + parse, in two
# copies a substring per digit) was ~2% of a vite build.
glob _AIX_BITS: list[int] = [],
     _AIX_ID_LIMIT: int = 10000000,
     _KCLS_BITS: list[int] = [],
     _KCLS_ID_LIMIT: int = 1000000;

# symbol keys start here (encoding.SYMBOL_KEY_BASE)

# Per-intern-id prefix class of a property key, same table discipline as
# _AIX_BITS (one byte per id, ids never reused): bit 0 computed, bit 1 the
# empty string, bit 2 starts "__", bit 3 starts "__brand@", bit 4 starts
# "__priv_#". Own-key enumeration and for-in filter engine-internal keys by
# these prefixes for every key they list. Ids from 1e6 up (marker keys, not
# interned strings) are classified uncached.

# encoding.BUILTIN_BASE
def _kcls_of(s: str) -> int {
    kc_r: int = 1;
    kc_n: int = len(s);
    if kc_n == 0 {
        return 3;
    }
    if kc_n >= 2 and ord(s[0]) == 95 and ord(s[1]) == 95 {
        kc_r = kc_r | 4;
        if kc_n >= 8 {
            kc_p: str = s[0:8];
            if kc_p == "__brand@" {
                kc_r = kc_r | 8;
            } elif kc_p == "__priv_#" {
                kc_r = kc_r | 16;
            }
        }
    }
    return kc_r;
}

def _kcls(kid: int) -> int {
    if kid < 0 {
        return 1;
    }
    if kid >= _KCLS_ID_LIMIT {
        return _kcls_of(str_from_id(kid));
    }
    kc_w: int = kid >> 3;
    kc_sh: int = (kid & 7) << 3;
    if kc_w < len(_KCLS_BITS) {
        kc_v: int = (_KCLS_BITS[kc_w] >> kc_sh) & 255;
        if kc_v != 0 {
            return kc_v;
        }
    } else {
        while len(_KCLS_BITS) <= kc_w {
            _KCLS_BITS.append(0);
        }
    }
    kc_c: int = _kcls_of(str_from_id(kid));
    _KCLS_BITS[kc_w] = _KCLS_BITS[kc_w] | (kc_c << kc_sh);
    return kc_c;
}

"""True when key `kid`'s text is empty or starts with "__" (the for-in filter
for engine-internal keys)."""
def:pub str_id_is_empty_or_dunder(kid: int) -> bool {
    return (_kcls(kid) & 6) != 0;
}

"""True when key `kid`'s text starts with "__brand@" (a private-method brand)."""
def:pub str_id_is_brand_key(kid: int) -> bool {
    return (_kcls(kid) & 8) != 0;
}

"""True when key `kid`'s text starts with "__priv_#" or "__brand@" (private
class state / brand storage)."""
def:pub str_id_is_private_key(kid: int) -> bool {
    return (_kcls(kid) & 24) != 0;
}

"""True when interned key `kid` is a canonical array index ("0", "17", ...)."""
def:pub str_id_is_array_index(kid: int) -> bool {
    if kid < 0 or kid >= _AIX_ID_LIMIT {
        return False;
    }
    ax_w: int = kid >> 3;
    ax_sh: int = (kid & 7) << 3;
    if ax_w < len(_AIX_BITS) {
        ax_v: int = (_AIX_BITS[ax_w] >> ax_sh) & 3;
        if ax_v != 0 {
            return ax_v == 2;
        }
    } else {
        while len(_AIX_BITS) <= ax_w {
            _AIX_BITS.append(0);
        }
    }
    ax_r: bool = _str_text_is_array_index(str_from_id(kid));
    if ax_r {
        _AIX_BITS[ax_w] = _AIX_BITS[ax_w] | (2 << ax_sh);
    } else {
        _AIX_BITS[ax_w] = _AIX_BITS[ax_w] | (1 << ax_sh);
    }
    return ax_r;
}

"""Canonical array-index text: "0", or a digit 1-9 then digits, below 2^32 − 1."""
def _str_text_is_array_index(s: str) -> bool {
    tx_n: int = len(s);
    if tx_n == 0 {
        return False;
    }
    tx_c0: int = ord(s[0]);
    if tx_c0 == 48 {
        return tx_n == 1;
    }
    if tx_c0 < 49 or tx_c0 > 57 {
        return False;
    }
    tx_v: int = tx_c0 - 48;
    tx_i: int = 1;
    while tx_i < tx_n {
        tx_c: int = ord(s[tx_i]);
        if tx_c < 48 or tx_c > 57 {
            return False;
        }
        tx_v = tx_v * 10 + (tx_c - 48);
        if tx_v >= 4294967295 {
            return False;
        }
        tx_i = tx_i + 1;
    }
    return True;
}

# Intern ids of the decimal keys "0", "1", ... (index i → id, 0 = not yet
# interned), filled on demand up to _IDXK_LIMIT. Array-like code interned
# `str(i)` per element — a str allocation plus a string-keyed dict probe with
# text compares, ~500 instructions per element read through the generic
# property path (array iterators over non-dense objects, arguments, for-in
# keys, sparse writes).
glob _IDXK_IDS: list[int] = [],
     _IDXK_LIMIT: int = 1048576;

"""str_intern(str(i)) for an int `i`, cached for 0 <= i < 2^20."""
def:pub str_intern_index(i: int) -> int {
    if i < 0 or i >= _IDXK_LIMIT {
        return str_intern(str(i));
    }
    if i < len(_IDXK_IDS) {
        ik_id: int = _IDXK_IDS[i];
        if ik_id != 0 {
            return ik_id;
        }
    } else {
        while len(_IDXK_IDS) <= i {
            _IDXK_IDS.append(0);
        }
    }
    ik_new: int = str_intern(str(i));
    _IDXK_IDS[i] = ik_new;
    return ik_new;
}

"""The intern id of `s`, or -1 if `s` was never interned. Unlike str_intern this
never adds an entry, so it can probe for keys that are probably absent: a
string that was never interned is no object's property key."""
def:pub str_intern_lookup(s: str) -> int {
    if s in _STR_REALM.intern_by_str {
        return _STR_REALM.intern_by_str[s];
    }
    return -1;
}

"""Current intern-counter value (diagnostics)."""
def:pub str_intern_count -> int {
    return _STR_REALM.intern_next_id;
}

"""Base for non-interned (heap) string IDs. Above SYMBOL_KEY_BASE and any
plausible intern-table size, so a heap-string ID is unambiguous and — critically
— is never mistaken for a property key (those are < SYMBOL_KEY_BASE). A string
VALUE used as a property key is re-interned via its text in _to_property_key, so
heap strings never leak into the key space."""
glob:pub HEAP_STRING_BASE: int = 1000000000;  # 1e9

# Single-entry UTF-16 units memo for non-ASCII charCodeAt/codePointAt/at loops
# (js_string_unit_at_cell). Keyed by string id; invalidated on any heap-slot
# (re)alloc so a recycled id can never return a prior string's units.
glob _U16MEMO_ID: int = -1,
     _U16MEMO: list[int] = [];

"""UTF-16 position index of one non-ASCII string: (byte offset, unit offset)
checkpoints about every U16IX_STEP code units, plus the total unit count.
`regular` is False when the bytes hold a sequence the simple per-lead-byte
width rules below could mis-measure (stray continuation byte, overlong or
out-of-range lead, truncated tail) — callers then keep the exact decode path."""
obj:pub U16Index {
    has id: int = -1,
        bytes: list[int] = [],
        units: list[int] = [],
        total: int = 0,
        regular: bool = True;
}

# A few recent indexes (round-robin), keyed by string id. Converting a UTF-16
# position used to decode the WHOLE string per call — slice/substring/indexOf on a
# non-ASCII bundle string made magic-string rendering quadratic. Invalidated with
# _U16MEMO when a heap slot is recycled (_heap_slot_alloc).
glob U16IX_STEP: int = 64,
     U16IX_SLOTS: int = 256,
     _U16IX: list[U16Index] = [],
     _U16IX_NEXT: int = 0,
     _U16IX_POS: dict[int, int] = {};

# string id -> its slot in _U16IX: lookups and the per-allocation invalidation
# in _heap_slot_alloc used to scan all U16IX_SLOTS entries (the scan alone was
# ~13% of a string-building loop).
"""Store `s` as a non-interned heap string; return its id (HEAP_STRING_BASE+idx).

Unlike str_intern this does NOT hash `s` or check for duplicates — it appends one
copy and returns. Used for computed string values (concatenation, slicing,
templating) where dedup is pointless and the per-op hashing was the source of the
O(n^2) concat blowup. Callers that need a canonical key must use str_intern."""
# G1.4: allocate a heap-string slot, reusing a swept slot from
# free_heap_string_slots if available (else append). Maintains ALL parallel
# arrays — heap_strings / rope_left / rope_right / rope_len / heap_ascii and the
# heap_strings_mark_epoch GC array — in lockstep, and stamps the slot live
# (mark_epoch = 0, i.e. != gc_epoch >= 1). Returns the 0-based slot index.
def _heap_slot_alloc(s: str, rl: int, rr: int, rlen: int, asc: int) -> int {
    # Units-memo (_U16MEMO) invalidation is done SURGICALLY in the reuse branch
    # below, NOT unconditionally here. A memoized heap id's units only go stale
    # when THAT id's slot is recycled to hold a different string; an append mints a
    # brand-new slot index (never an existing memoized id) and a reuse of a
    # DIFFERENT slot cannot alias it either. Nuking the memo on every alloc made a
    # charCodeAt/.length scan that interleaves slice()/concat (i.e. every acorn +
    # MagicString transform: vite commonjs:transform / vite:define:transform) drop
    # back to the O(n^2) whole-string re-decode per char — ~1000x slowdown, the
    # 178-module "hang" (~7s/module). Interned ids (< HEAP_STRING_BASE) are
    # immutable and never recycled, so the reuse check never fires for them.
    # Heap-string allocation DOES count toward the GC trigger (gc_note_alloc).
    # History: this was disabled because (a) it 5x'd collection frequency and
    # (b) exposed an async-resume rooting gap (intermittent async timeouts,
    # test_integration XC-009). Both reasons are now gone: suspended async
    # frames are rooted in gc_mark_roots, and the trigger threshold is adaptive
    # (scales with the live set), so frequency stays bounded. NOT counting
    # strings made --gc USELESS on string-heavy phases: vite's transform churns
    # string slices (str_substr) with almost no object allocation — under 500K
    # objects while heap strings grew to 11GB in 10s, OOMing WITH --gc because
    # collections simply never triggered.
    gc_note_alloc(_STR_REALM);
    if rl < 0 {
        _hs_note_bytes(len(s));
    }  # leaf bytes (ropes are metered on flatten)
    fn: int = len(_STR_REALM.free_heap_string_slots);
    if fn > 0 {
        idx: int = _STR_REALM.free_heap_string_slots[fn - 1];
        del _STR_REALM.free_heap_string_slots[fn - 1];
        # Reusing a swept slot: if it is the memoized string's slot, its units are
        # now stale — drop the memo. (Any other slot leaves the memo valid.)
        if (HEAP_STRING_BASE + idx) == _U16MEMO_ID {
            _U16MEMO_ID = -1;
        }
        u16_slot: int = _U16IX_POS.get(HEAP_STRING_BASE + idx, -1);
        if u16_slot >= 0 {
            _U16IX[u16_slot].id = -1;
            del _U16IX_POS[HEAP_STRING_BASE + idx];
        }
        _STR_REALM.heap_strings[idx] = s;
        _STR_REALM.rope_left[idx] = rl;
        _STR_REALM.rope_right[idx] = rr;
        _STR_REALM.rope_len[idx] = rlen;
        _STR_REALM.heap_ascii[idx] = asc;
        _STR_REALM.heap_strings_mark_epoch[idx] = 0;  # live, not-yet-marked
        return idx;
    }
    aidx: int = len(_STR_REALM.heap_strings);
    _STR_REALM.heap_strings.append(s);
    _STR_REALM.rope_left.append(rl);
    _STR_REALM.rope_right.append(rr);
    _STR_REALM.rope_len.append(rlen);
    _STR_REALM.heap_ascii.append(asc);
    _STR_REALM.heap_strings_mark_epoch.append(0);
    return aidx;
}

def:pub str_heap(s: str) -> int {
    # The empty string MUST keep its canonical intern id (6): jsv_coerce_to_bool
    # tests `id == 6` for string falsiness, so a heap-allocated "" would wrongly
    # be truthy. Interning "" is also free (it is already in the table).
    if len(s) == 0 {
        return 6;
    }
    return HEAP_STRING_BASE + _heap_slot_alloc(s, -1, -1, len(s), _ascii_flag(s));
}

"""str_heap for text the caller knows is byte-clean ASCII (a slice of a
byte-clean string): no rescan for the cell's ASCII flag."""
def:pub str_heap_ascii(s: str) -> int {
    if len(s) == 0 {
        return 6;
    }
    return HEAP_STRING_BASE + _heap_slot_alloc(s, -1, -1, len(s), 1);
}

"""Character length of a string cell without forcing a rope flatten."""
def:pub str_cell_len(id: int) -> int {
    if id >= HEAP_STRING_BASE {
        hidx: int = id - HEAP_STRING_BASE;
        if hidx >= 0 and hidx < len(_STR_REALM.rope_len) {
            return _STR_REALM.rope_len[hidx];
        }
        return 0;
    }
    return len(str_from_id(id));
}

"""1 if the string cell is known pure-ASCII, 2 if non-ASCII, 0 if unknown.

Cheap and flatten-free: interned/heap leaves carry a precomputed flag, and a rope
is ASCII iff both children are. Used by charAt/charCodeAt to decide the O(1)
byte-index fast path (see js_string_utf16_unit_at)."""
def:pub str_cell_ascii(id: int) -> int {
    if id >= HEAP_STRING_BASE {
        hidx: int = id - HEAP_STRING_BASE;
        if hidx >= 0 and hidx < len(_STR_REALM.heap_ascii) {
            return _STR_REALM.heap_ascii[hidx];
        }
        return 0;
    }
    if id in _STR_REALM.intern_ascii {
        return _STR_REALM.intern_ascii[id];
    }
    return 0;
}

"""Concatenate two string cells lazily as a rope node — O(1), no copy.

Instead of building `left ++ right` eagerly (which makes a `+=` loop O(n^2)),
record the two child ids and the total length. The text is materialised only
when str_from_id is called on the result. Rope nodes are immutable, so it is
always safe to share a child across multiple ropes (no aliasing hazard)."""
def:pub str_rope(a_id: int, b_id: int) -> int {
    la: int = str_cell_len(a_id);
    if la == 0 {
        return b_id;
    }
    lb: int = str_cell_len(b_id);
    if lb == 0 {
        return a_id;
    }
    # A concatenation is pure-ASCII iff both operands are. Computed here without
    # flattening, so charCodeAt on a rope keeps the O(1) fast path. Unknown (0)
    # on either side → unknown, forcing the safe decode path on read.
    aa: int = str_cell_ascii(a_id);
    bb: int = str_cell_ascii(b_id);
    rope_a: int = 0;
    if aa == 1 and bb == 1 {
        rope_a = 1;
    } elif aa == 2 or bb == 2 {
        rope_a = 2;
    }
    # "" text; filled in on flatten. Children a_id/b_id are traced by the GC
    # (gc.jac string branch) so a live rope keeps its children alive (G1.4).
    return HEAP_STRING_BASE + _heap_slot_alloc("", a_id, b_id, la + lb, rope_a);
}

"""A slice at least this many bytes long is kept lazily (str_slice_cell); a
shorter one is copied at once (cheaper than a heap slot that pins its parent)."""
glob:pub LAZY_SLICE_MIN: int = 1024;

"""Bytes [start, start + n) of string cell `pid`, kept lazily — O(1), no copy.

Stored like a rope node: rope_left = the parent cell, rope_right = -2 - start
(<= -2 marks a slice: a rope has a child id >= 1 there, a flat leaf -1),
rope_len = n. The text is cut from the parent only when read (str_from_id).
A slice of an unread slice points at that slice's parent, so slices never
chain. V8 does the same with SlicedString. MagicString.indent() splits a chunk
at every line start and slices the rest of the module off each time: copying
those tails was O(lines x size) — 7 GB for react-dom's 620 KB client bundle in
a vite build, and the garbage set off a full collection every 68 MB."""
def:pub str_slice_cell(pid: int, start: int, n: int, asc: int) -> int {
    if n <= 0 {
        return 6;
    }
    base_id: int = pid;
    off: int = start;
    if base_id >= HEAP_STRING_BASE {
        ph: int = base_id - HEAP_STRING_BASE;
        if _STR_REALM.rope_left[ph] >= 0 and _STR_REALM.rope_right[ph] <= -2 {
            off = off + (-2 - _STR_REALM.rope_right[ph]);
            base_id = _STR_REALM.rope_left[ph];
        }
    }
    return HEAP_STRING_BASE + _heap_slot_alloc("", base_id, -2 - off, n, asc);
}

"""Bytes [st, en) of string cell `id` as an owned str. An unread slice cell is
read through to its parent, so a short piece of a long lazy slice does not
materialise the whole slice."""
def:pub str_substr_cell(id: int, st: int, en: int) -> str {
    if id >= HEAP_STRING_BASE {
        hidx: int = id - HEAP_STRING_BASE;
        if hidx < len(_STR_REALM.rope_left)
            and _STR_REALM.rope_left[hidx] >= 0
            and _STR_REALM.rope_right[hidx] <= -2 {
            off: int = -2 - _STR_REALM.rope_right[hidx];
            return str_substr(
                str_from_id(_STR_REALM.rope_left[hidx]), off + st, off + en
            );
        }
    }
    return str_substr(str_from_id(id), st, en);
}

"""Materialise slice node `hidx` (see str_slice_cell) and cache it as a flat leaf,
which also drops its hold on the parent."""
def _slice_flatten(hidx: int) -> str {
    off: int = -2 - _STR_REALM.rope_right[hidx];
    out: str = str_substr(
        str_from_id(_STR_REALM.rope_left[hidx]), off, off + _STR_REALM.rope_len[hidx]
    );
    _hs_note_bytes(len(out));
    _STR_REALM.heap_strings[hidx] = out;
    _STR_REALM.rope_left[hidx] = -1;
    _STR_REALM.rope_right[hidx] = -1;
    if _STR_REALM.heap_ascii[hidx] == 0 {
        _STR_REALM.heap_ascii[hidx] = _ascii_flag(out);
    }
    return out;
}

"""Flatten rope node at heap index `hidx` into a real string, caching the result.

Iterative (explicit stack) rather than recursive so a deep left-leaning rope —
exactly what `s += x` in a loop builds — cannot overflow the native call stack."""
def _rope_flatten(hidx: int) -> str {
    if _STR_REALM.rope_left[hidx] < 0 {
        return _STR_REALM.heap_strings[hidx];
    }
    if _STR_REALM.rope_right[hidx] <= -2 {
        return _slice_flatten(hidx);
    }
    # Collect leaf strings left-to-right via an explicit work stack of cell ids.
    parts: list[str] = [];
    stack: list[int] = [HEAP_STRING_BASE + hidx];
    while len(stack) > 0 {
        cur: int = stack[len(stack) - 1];
        del stack[len(stack) - 1];
        if cur >= HEAP_STRING_BASE {
            ci: int = cur - HEAP_STRING_BASE;
            if _STR_REALM.rope_left[ci] >= 0 and _STR_REALM.rope_right[ci] <= -2 {
                parts.append(_slice_flatten(ci));
            } elif _STR_REALM.rope_left[ci] >= 0 {
                # Push right then left so left is processed first (LIFO).
                stack.append(_STR_REALM.rope_right[ci]);
                stack.append(_STR_REALM.rope_left[ci]);
            } else {
                parts.append(_STR_REALM.heap_strings[ci]);
            }
        } else {
            parts.append(str_from_id(cur));
        }
    }
    out: str = "".join(parts);
    _hs_note_bytes(len(out));
    # Cache and collapse to a flat leaf so repeated reads are O(1).
    _STR_REALM.heap_strings[hidx] = out;
    _STR_REALM.rope_left[hidx] = -1;
    _STR_REALM.rope_right[hidx] = -1;
    # If ASCII-ness was unknown (a child had an unknown flag), settle it now that
    # the text exists — one scan, amortised over all future indexed reads.
    if _STR_REALM.heap_ascii[hidx] == 0 {
        _STR_REALM.heap_ascii[hidx] = _ascii_flag(out);
    }
    return out;
}


"""Return the string for `id`, resolving both the intern table and the heap
store. "" if the id is unknown."""
def:pub str_from_id(id: int) -> str {
    if id >= HEAP_STRING_BASE {
        hidx: int = id - HEAP_STRING_BASE;
        if hidx >= 0 and hidx < len(_STR_REALM.heap_strings) {
            # Unflattened rope or slice? Materialise (and cache) its text now.
            if _STR_REALM.rope_left[hidx] >= 0 {
                return _rope_flatten(hidx);
            }
            return _STR_REALM.heap_strings[hidx];
        }
        return "";
    }
    if id in _STR_REALM.intern_by_id {
        return _STR_REALM.intern_by_id[id];
    }
    return "";
}

"""BigInt cell ToString — same table lookup as str_from_id."""
def:pub str_from_bigint_cell_id(id: int) -> str {
    return str_from_id(id);
}

"""
Pre-seed the intern table with well-known property-key strings so that the
compile-time KEY_* constants (KEY_PROTO=1, KEY_CONSTRUCTOR=2, KEY_LENGTH=3,
KEY_NAME=4, KEY_VALUE=5) match their dynamic str_intern() results.

Must be called as the VERY FIRST operation in init_global() before any other
str_intern() call.  Safe to call multiple times (idempotent guard).

IDs 6-9 are reserved for future internal keys; dynamic allocation starts at 10
(= KEY_BASE), matching the KEY_BASE constant in jsobject.na.jac.
"""
def:pub str_intern_seed_well_known -> None {
    if _STR_REALM.intern_seeded {
        return;
    }
    # ID 0 is reserved/unused so that jsv_from_string_id(id) never produces
    # JSValue 0 (NULL napi_value) for any valid string — keeps NAPI ABI sound.
    # "" is assigned ID 6; jsv_coerce_to_bool checks id == 6 for string falsiness.
    _STR_REALM.intern_by_str["__proto__"] = 1;
    _STR_REALM.intern_by_id[1] = "__proto__";
    _STR_REALM.intern_by_str["constructor"] = 2;
    _STR_REALM.intern_by_id[2] = "constructor";
    _STR_REALM.intern_by_str["length"] = 3;
    _STR_REALM.intern_by_id[3] = "length";
    _STR_REALM.intern_by_str["name"] = 4;
    _STR_REALM.intern_by_id[4] = "name";
    _STR_REALM.intern_by_str["value"] = 5;
    _STR_REALM.intern_by_id[5] = "value";
    _STR_REALM.intern_by_str[""] = 6;
    _STR_REALM.intern_by_id[6] = "";
    # IDs 7-9 reserved; KEY_BASE=10 is first dynamic ID.
    _STR_REALM.intern_next_id = 10;
    _STR_REALM.intern_seeded = True;
}

# ─────────────────────────────────────────────────────────────────────────────
# JSString object
# ─────────────────────────────────────────────────────────────────────────────

"""
An immutable JavaScript string value with cached hash and interned ID.

`data`      — raw Jac str (UTF-8 representation of the JS string)
`length`    — number of UTF-16 code units; approximated as len(data) for BMP
`hash_val`  — cached FNV-1a hash (0 = not yet computed)
`intern_id` — integer handle in _INTERN_TABLE (-1 = not yet interned)

ECMAScript spec: 6.1.4 The String Type
"""
obj:pub JSString {
    has data: str,
        length: int = 0,
        hash_val: int = 0,
        intern_id: int = -1;

    """Initialise length from data (called after construction)."""
    def:pub postinit {
        self.length = len(self.data);
    }

    # ── Hashing & identity ─────────────────────────────────────────────────

    """Return (and cache) the FNV-1a hash of this string."""
    def:pub hash -> int {
        if self.hash_val == 0 and self.length > 0 {
            self.hash_val = str_hash(self.data);
        }
        return self.hash_val;
    }

    """Intern this string and return its ID."""
    def:pub intern -> int {
        if self.intern_id == -1 {
            self.intern_id = str_intern(self.data);
        }
        return self.intern_id;
    }

    # ── ECMAScript String.prototype — character access ─────────────────────

    """
    String.prototype.charAt(pos)  — ECMAScript §22.1.3.1
    Returns the character at index `pos` as a single-character string,
    or "" if out of range.
    """
    def:pub char_at(pos: int) -> str {
        return str_char_at(self.data, pos);
    }

    """
    String.prototype.charCodeAt(pos)  — ECMAScript §22.1.3.2
    Returns the UTF-16 code unit value at `pos`, or -1 if out of range.
    """
    def:pub char_code_at(pos: int) -> int {
        c: str = str_char_at(self.data, pos);
        if c == "" {
            return -1;
        }
        return ord(c);
    }

    """
    String.prototype.codePointAt(pos)  — ECMAScript §22.1.3.3
    Returns the full Unicode code point at `pos`.
    For BMP characters this equals charCodeAt.
    """
    def:pub code_point_at(pos: int) -> int {
        return self.char_code_at(pos);
    }

    # ── ECMAScript String.prototype — search ───────────────────────────────

    """
    String.prototype.indexOf(searchString, position)  — ECMAScript §22.1.3.8
    Returns the first index of `needle` at or after `from_idx`, or -1.
    """
    def:pub index_of(needle: str, from_idx: int = 0) -> int {
        if from_idx <= 0 {
            return self.data.find(needle);
        }
        # find(needle, start) — native start-offset search, NO copy. The old
        # workaround str_substr'd the ENTIRE TAIL on every call, so a JS scan
        # loop `while ((i = s.indexOf(x, i+1)) !== -1)` over a large string
        # allocated O(n) per iteration → O(n²) bytes total. On vite@6's
        # import-analysis scanning a 340KB chunk source that was ~0.8GB/s of
        # transient allocations until OOM (the parse5 dynamic-import "blowup").
        return self.data.find(needle, from_idx);
    }

    """
    String.prototype.lastIndexOf(searchString)  — ECMAScript §22.1.3.9
    Returns the last index of `needle`, or -1.
    """
    def:pub last_index_of(needle: str) -> int {
        return self.data.rfind(needle);
    }

    """
    String.prototype.includes(searchString)  — ECMAScript §22.1.3.7
    Returns True iff `needle` appears anywhere in the string.
    """
    def:pub includes(needle: str) -> bool {
        return needle in self.data;
    }

    """
    String.prototype.startsWith(prefix)  — ECMAScript §22.1.3.20
    """
    def:pub starts_with(prefix: str) -> bool {
        return self.data.startswith(prefix);
    }

    """
    String.prototype.endsWith(suffix)  — ECMAScript §22.1.3.6
    """
    def:pub ends_with(suffix: str) -> bool {
        return self.data.endswith(suffix);
    }

    # ── ECMAScript String.prototype — extraction ───────────────────────────

    """
    String.prototype.slice(start, end)  — ECMAScript §22.1.3.19
    Negative indices count from the end.  Uses str_substr to avoid the
    native s[a:b] slice bug.
    """
    def:pub slice(start: int, end: int) -> JSString {
        # Bind the substr to a NAMED local before passing it on: an owned str
        # call-result used INLINE as an argument is retained by the callee but
        # never released by this caller (compiler inline-temp RC gap, same
        # family as the fixed inline-call-result-recv leak) — vite's transform
        # leaked ~7.7GB of slice results through this one expression.
        sl_sub: str = str_substr(self.data, start, end);
        return js_string(sl_sub);
    }

    """Slice from `start` to end of string."""
    def:pub slice_from(start: int) -> JSString {
        sf_sub: str = str_substr(self.data, start, self.length);  # named local: see slice()
        return js_string(sf_sub);
    }

    """
    String.prototype.substring(start, end)  — ECMAScript §22.1.3.22
    Like slice but swaps start/end if start > end and clamps to [0, length].
    """
    def:pub substring(start: int, end: int) -> JSString {
        st: int = start;
        en: int = end;
        if st < 0 {
            st = 0;
        }
        if en < 0 {
            en = 0;
        }
        if st > self.length {
            st = self.length;
        }
        if en > self.length {
            en = self.length;
        }
        if st > en {
            # swap
            tmp: int = st;
            st = en;
            en = tmp;
        }
        ss_sub: str = str_substr(self.data, st, en);  # named local: see slice()
        return js_string(ss_sub);
    }

    # ── ECMAScript String.prototype — case conversion ──────────────────────

    """String.prototype.toLowerCase()  — ECMAScript §22.1.3.26"""
    def:pub to_lower_case -> JSString {
        return js_string(self.data.lower());
    }

    """String.prototype.toUpperCase()  — ECMAScript §22.1.3.28"""
    def:pub to_upper_case -> JSString {
        return js_string(self.data.upper());
    }

    # ── ECMAScript String.prototype — trim ─────────────────────────────────

    """String.prototype.trim()  — ECMAScript §22.1.3.30"""
    def:pub trim -> JSString {
        return js_string(self.data.strip());
    }

    """String.prototype.trimStart()  — ECMAScript §22.1.3.31"""
    def:pub trim_start -> JSString {
        return js_string(self.data.lstrip());
    }

    """String.prototype.trimEnd()  — ECMAScript §22.1.3.32"""
    def:pub trim_end -> JSString {
        return js_string(self.data.rstrip());
    }

    # ── ECMAScript String.prototype — split ────────────────────────────────

    """
    String.prototype.split(separator)  — ECMAScript §22.1.3.21
    Returns a list[str] of substrings.
    """
    def:pub split(sep: str) -> list[str] {
        return self.data.split(sep);
    }

    # ── ECMAScript String.prototype — replace ──────────────────────────────

    """
    String.prototype.replace(searchValue, replaceValue)  — ECMAScript §22.1.3.14
    Replaces the *first* occurrence of `search` with `replacement`.
    """
    def:pub replace(search: str, replacement: str) -> JSString {
        return js_string(self.data.replace(search, replacement, 1));
    }

    """
    String.prototype.replaceAll(searchValue, replaceValue)  — ECMAScript §22.1.3.15
    Replaces *all* occurrences.
    """
    def:pub replace_all(search: str, replacement: str) -> JSString {
        return js_string(self.data.replace(search, replacement));
    }

    # ── ECMAScript String.prototype — pad ──────────────────────────────────

    """
    String.prototype.padStart(targetLength, padString)  — ECMAScript §22.1.3.12
    """
    def:pub pad_start(target_len: int, pad_str: str = " ") -> JSString {
        if self.length >= target_len {
            return js_string(self.data);
        }
        if pad_str == " " {
            return js_string(self.data.rjust(target_len));
        }
        needed: int = target_len - self.length;
        pad_parts: list[str] = [];
        k: int = 0;
        pad_len: int = len(pad_str);
        while k < needed {
            idx: int = k;
            # wrap around pad_str
            while idx >= pad_len {
                idx = idx - pad_len;
            }
            pad_parts.append(str_char_at(pad_str, idx));
            k = k + 1;
        }
        return js_string("".join(pad_parts) + self.data);
    }

    """
    String.prototype.padEnd(targetLength, padString)  — ECMAScript §22.1.3.11
    """
    def:pub pad_end(target_len: int, pad_str: str = " ") -> JSString {
        if self.length >= target_len {
            return js_string(self.data);
        }
        if pad_str == " " {
            return js_string(self.data.ljust(target_len));
        }
        needed: int = target_len - self.length;
        pad_parts: list[str] = [];
        k: int = 0;
        pad_len: int = len(pad_str);
        while k < needed {
            idx: int = k;
            while idx >= pad_len {
                idx = idx - pad_len;
            }
            pad_parts.append(str_char_at(pad_str, idx));
            k = k + 1;
        }
        return js_string(self.data + "".join(pad_parts));
    }

    # ── ECMAScript String.prototype — repeat ───────────────────────────────

    """String.prototype.repeat(count)  — ECMAScript §22.1.3.16"""
    def:pub repeat(count: int) -> JSString {
        if count <= 0 {
            return js_string("");
        }
        return js_string(self.data * count);
    }

    # ── ECMAScript String.prototype — concat ───────────────────────────────

    """String.prototype.concat(other)  — ECMAScript §22.1.3.4"""
    def:pub concat(other: str) -> JSString {
        return js_string(self.data + other);
    }

    # ── ECMAScript String.prototype — comparison ───────────────────────────

    """Return True iff this string has the same contents as `other`."""
    def:pub equals(other: str) -> bool {
        return self.data == other;
    }

    """
    String comparison for sorting (< 0 if self < other, 0 if equal, > 0 if greater).
    Used by Array.prototype.sort default comparator.
    """
    def:pub compare_to(other: str) -> int {
        if self.data == other {
            return 0;
        }
        if self.data < other {
            return -1;
        }
        return 1;
    }

    # ── ECMAScript String.prototype — toString / valueOf ──────────────────

    """String.prototype.toString() / valueOf()  — ECMAScript §22.1.3.27"""
    def:pub to_string -> str {
        return self.data;
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# Factory functions (module-level, same idiom as jsvalue.na.jac)
# ─────────────────────────────────────────────────────────────────────────────

"""Create a JSString from a raw Jac str."""
def:pub js_string(s: str) -> JSString {
    return JSString(data=s);
}

"""Create an empty JSString."""
def:pub js_empty_string -> JSString {
    return JSString(data="");
}

"""Create a JSString from a Unicode code point integer."""
def:pub js_string_from_code(code: int) -> JSString {
    return JSString(data=utf8_encode_scalar(code));
}

# ─────────────────────────────────────────────────────────────────────────────
# ECMAScript ToNumber(string) — §7.1.4.1 / StringNumericLiteral
# ─────────────────────────────────────────────────────────────────────────────

"""IEEE-754 constants inline to avoid import cycle with jsvalue.na.jac."""
def _stf_nan -> float {
    return 1e308 * 2.0 - 1e308 * 2.0;
}

def _stf_inf -> float {
    return 1e308 * 2.0;
}

"""ECMAScript WhiteSpace code points (ES §12.2) — excludes U+180E."""
def _stf_is_whitespace_cp(cp: int) -> bool {
    if cp == 0x0009 or cp == 0x000B or cp == 0x000C or cp == 0x0020 {
        return True;
    }
    if cp == 0x00A0 or cp == 0xFEFF or cp == 0x1680 {
        return True;
    }
    if cp >= 0x2000 and cp <= 0x200A {
        return True;
    }
    if cp == 0x202F or cp == 0x205F or cp == 0x3000 {
        return True;
    }
    return False;
}

"""ECMAScript LineTerminator code points (ES §12.3)."""
def _stf_is_line_terminator_cp(cp: int) -> bool {
    return cp == 0x000A or cp == 0x000D or cp == 0x2028 or cp == 0x2029;
}

def _stf_is_str_white_cp(cp: int) -> bool {
    return _stf_is_whitespace_cp(cp) or _stf_is_line_terminator_cp(cp);
}

"""Rebuild a Jac str from Unicode code points."""
def _stf_codepoints_to_str(cps: list[int]) -> str {
    # append+join, not per-codepoint concat (O(n²) bytes).
    out: list[str] = [];
    for cp in cps {
        out.append(utf8_encode_scalar(cp));
    }
    return "".join(out);
}

"""Decode-based trim fallback for strings with non-ASCII boundary bytes
(possible Unicode whitespace: NBSP, U+2028/29, U+FEFF, Zs)."""
def _stf_trim_numeric_slow(s: str) -> str {
    cps: list[int] = utf8_decode_str_to_codepoints(s);
    n: int = len(cps);
    start: int = 0;
    end: int = n;
    while start < end and _stf_is_str_white_cp(cps[start]) {
        start = start + 1;
    }
    while end > start and _stf_is_str_white_cp(cps[end - 1]) {
        end = end - 1;
    }
    if start >= end {
        return "";
    }
    trimmed: list[int] = [];
    i: int = start;
    while i < end {
        trimmed.append(cps[i]);
        i = i + 1;
    }
    return _stf_codepoints_to_str(trimmed);
}

"""Trim ECMAScript StrWhiteSpaceChar / LineTerminator from both ends.

ToNumber(string) runs on every string→number coercion; the old
decode-everything path allocated a codepoint list, a trimmed copy, and a
per-codepoint rebuilt string EVERY call (millions of times in a bundler run).
ASCII fast path: trim TAB/LF/VT/FF/CR/SP by byte offset — zero allocations
when there is nothing to trim, one substr otherwise. Any non-ASCII byte at a
boundary falls back to the full decode (it may be Unicode whitespace)."""
def _stf_trim_numeric(s: str) -> str {
    n: int = len(s);
    start: int = 0;
    while start < n {
        b: int = ord(s[start]);
        if b == 32 or (b >= 9 and b <= 13) {
            start = start + 1;
        } elif b >= 128 {
            return _stf_trim_numeric_slow(s);
        } else {
            break;
        }
    }
    end: int = n;
    while end > start {
        b2: int = ord(s[end - 1]);
        if b2 == 32 or (b2 >= 9 and b2 <= 13) {
            end = end - 1;
        } elif b2 >= 128 {
            return _stf_trim_numeric_slow(s);
        } else {
            break;
        }
    }
    if start >= end {
        return "";
    }
    if start == 0 and end == n {
        return s;
    }
    return str_substr(s, start, end);
}

"""NumericLiteralSeparator (_) is invalid in string ToNumber operands.
Byte scan — `_` is the single byte 0x5F and UTF-8 lead/continuation bytes are
all >= 0x80, so no decode is needed (the old path decoded the whole string to
a fresh codepoint list per call)."""
def _stf_has_numeric_separator(s: str) -> bool {
    n: int = len(s);
    i: int = 0;
    while i < n {
        if ord(s[i]) == 95 {
            return True;
        }
        i = i + 1;
    }
    return False;
}

"""Parse signed integer literal body in `radix` (2, 8, or 16). Returns NaN on failure."""
def _stf_parse_int_body(body: str, radix: int, sign: float) -> float {
    n: int = len(body);
    if n == 0 {
        return _stf_nan();
    }
    val: int = 0;
    i: int = 0;
    while i < n {
        c: str = body[i];
        dv: int = -1;
        o: int = ord(c);
        if o >= 48 and o <= 57 {
            dv = o - 48;
        } elif o >= 65 and o <= 90 {
            dv = o - 55;
        } elif o >= 97 and o <= 122 {
            dv = o - 87;
        }
        if dv < 0 or dv >= radix {
            return _stf_nan();
        }
        val = val * radix + dv;
        i = i + 1;
    }
    return sign * float(val);
}

"""
Validate StrDecimalLiteral grammar; on success convert via native float() for IEEE rounding.
Returns NaN when the trimmed literal is syntactically invalid.
"""
def _stf_parse_decimal_literal(t: str) -> float {
    tlen: int = len(t);
    if tlen == 0 {
        return _stf_nan();
    }
    pos: int = 0;
    sign: float = 1.0;
    if t[0] == "+" {
        pos = 1;
    } elif t[0] == "-" {
        sign = -1.0;
        pos = 1;
    }
    if pos == tlen {
        return _stf_nan();
    }

    # Infinity
    if pos + 8 <= tlen
        and str_substr(t, pos, pos + 8) == "Infinity"
        and pos + 8 == tlen {
        return sign * _stf_inf();
    }

    ipart: int = 0;
    fpart: float = 0.0;
    fdiv: float = 1.0;
    has_dig: bool = False;

    while pos < tlen and t[pos] >= "0" and t[pos] <= "9" {
        ipart = ipart * 10 + ord(t[pos]) - 48;
        has_dig = True;
        pos = pos + 1;
    }
    if pos < tlen and t[pos] == "." {
        pos = pos + 1;
        while pos < tlen and t[pos] >= "0" and t[pos] <= "9" {
            fpart = fpart * 10.0 + float(ord(t[pos]) - 48);
            fdiv = fdiv * 10.0;
            has_dig = True;
            pos = pos + 1;
        }
    }
    if not has_dig {
        return _stf_nan();
    }

    if pos < tlen and (t[pos] == "e" or t[pos] == "E") {
        pos = pos + 1;
        if pos < tlen and (t[pos] == "+" or t[pos] == "-") {
            pos = pos + 1;
        }
        if pos == tlen {
            return _stf_nan();
        }
        exp_has: bool = False;
        while pos < tlen and t[pos] >= "0" and t[pos] <= "9" {
            exp_has = True;
            pos = pos + 1;
        }
        if not exp_has {
            return _stf_nan();
        }
    }

    if pos != tlen {
        return _stf_nan();
    }
    # Native float() after grammar validation preserves IEEE-754 bit patterns
    # expected by test262 SameValue checks (manual accumulation can diverge).
    return float(t);
}

"""
ECMAScript ToNumber(string) — §7.1.4.1
Handles: ECMAScript whitespace trimming, "", "NaN", "Infinity", "-Infinity",
integer literals, decimal literals, exponent notation, 0x/0b/0o prefixes.
Rejects numeric separators in strings. Returns NaN for invalid forms.
"""
def:pub str_to_float(s: str) -> float {
    t: str = _stf_trim_numeric(s);
    if len(t) == 0 {
        return 0.0;
    }
    if _stf_has_numeric_separator(t) {
        return _stf_nan();
    }

    if t == "NaN" {
        return _stf_nan();
    }
    if t == "Infinity" or t == "+Infinity" {
        return _stf_inf();
    }
    if t == "-Infinity" {
        return -_stf_inf();
    }

    pos: int = 0;
    sign: float = 1.0;
    if t[0] == "+" {
        pos = 1;
    } elif t[0] == "-" {
        sign = -1.0;
        pos = 1;
    }
    tlen: int = len(t);
    if pos == tlen {
        return _stf_nan();
    }

    # Hex literal 0x…
    if pos + 1 < tlen and t[pos] == "0" and (t[pos + 1] == "x" or t[pos + 1] == "X") {
        body: str = str_substr(t, pos + 2, tlen);
        return _stf_parse_int_body(body, 16, sign);
    }
    # Binary literal 0b…
    if pos + 1 < tlen and t[pos] == "0" and (t[pos + 1] == "b" or t[pos + 1] == "B") {
        body2: str = str_substr(t, pos + 2, tlen);
        return _stf_parse_int_body(body2, 2, sign);
    }
    # Octal literal 0o…
    if pos + 1 < tlen and t[pos] == "0" and (t[pos + 1] == "o" or t[pos + 1] == "O") {
        body3: str = str_substr(t, pos + 2, tlen);
        return _stf_parse_int_body(body3, 8, sign);
    }

    return _stf_parse_decimal_literal(t);
}

# ─────────────────────────────────────────────────────────────────────────────
# UTF-16 helpers — ECMAScript strings are sequences of UTF-16 code units.
# Strings in LLVM native are stored as raw UTF-8 *bytes*.  chr(cp) is the
# UTF-8 encoding of cp, surrogate halves included (3 bytes, CESU-8).
# ─────────────────────────────────────────────────────────────────────────────

"""
Encode a Unicode scalar (or surrogate half) as a UTF-8 byte sequence.
  0x0000–0x007F → 1 byte
  0x0080–0x07FF → 2 bytes
  0x0800–0xFFFF → 3 bytes (includes surrogates, stored as CESU-8)
  0x10000+      → 4 bytes
"""
def:pub utf8_encode_scalar(cp: int) -> str {
    # cp == 0 is deliberately NOT encoded as a real NUL byte (chr(0)).
    #
    # Jac compares/hashes strings with C-string semantics: `chr(0) == ""` is TRUE
    # and the two collide as dict keys (verified: storing both leaves dict size 1).
    # str_intern therefore maps any NUL-only string onto the pre-seeded ""
    # (id 6), so String.fromCodePoint(0) came back as the EMPTY string and
    # "A"+NUL+"B" lost its middle character.
    #
    # Until Jac gains length-aware string compare/hash, this placeholder keeps a
    # A NUL code unit is stored as the 4-char sentinel `\`,`x`,`0`,`0` — NOT a real
    # NUL byte. Jac-native `str` is a C string that cannot hold an embedded NUL
    # (it collides with "" and the value vanishes), so the whole engine represents
    # code unit 0 as this escape and decodes it back on read (see _str_is_nul_escape
    # / js_string_utf16_unit_at / js_string_utf16_len). The source literal MUST be
    # "\\x00" (escaped backslash) so the compiler emits the four characters and not
    # a real NUL — the current compiler decodes "\x00" to an actual NUL byte.
    if cp == 0 {
        return "\\x00";
    }
    if cp < 0 or cp > 1114111 {
        return "?";
    }
    return chr(cp);
}

"""
Decode a raw list of byte integers (0-255) to Unicode code-point integers.
Validates continuation bytes: invalid sequences fall back to the lone lead byte.
Handles CESU-8 3-byte surrogate encodings as lone code-point values (D800-DFFF).
"""
def:pub _utf8_bytes_to_codepoints(raw: list[int]) -> list[int] {
    out: list[int] = [];
    i: int = 0;
    n: int = len(raw);
    while i < n {
        b0: int = raw[i];
        if b0 < 128 {
            # The 4-byte `\x00` NUL sentinel is ONE code unit (0), exactly as the
            # pure-ASCII fast path in utf8_decode_str_to_codepoints treats it;
            # non-ASCII strings containing U+0000 used to count it as 4 units.
            if b0 == 92
                and i + 3 < n
                and raw[i + 1] == 120
                and raw[i + 2] == 48
                and raw[i + 3] == 48 {
                out.append(0);
                i = i + 4;
            } else {
                out.append(b0);
                i = i + 1;
            }
        } elif (b0 & 224) == 192 and i + 1 < n {
            # 2-byte leader: 110xxxxx  continuation: 10xxxxxx
            b1: int = raw[i + 1];
            if (b1 & 192) == 128 {
                cp: int = (b0 & 31) * 64 + (b1 & 63);
                if cp >= 128 {
                    out.append(cp);
                    i = i + 2;
                    continue;
                }
            }
            out.append(b0);
            i = i + 1;
        } elif (b0 & 240) == 224 and i + 2 < n {
            # 3-byte leader: 1110xxxx  continuation: 10xxxxxx 10xxxxxx
            b1: int = raw[i + 1];
            b2: int = raw[i + 2];
            if (b1 & 192) == 128 and (b2 & 192) == 128 {
                cp2: int = (b0 & 15) * 4096 + (b1 & 63) * 64 + (b2 & 63);
                out.append(cp2);
                i = i + 3;
                continue;
            }
            out.append(b0);
            i = i + 1;
        } elif (b0 & 248) == 240 and i + 3 < n {
            # 4-byte leader: 11110xxx  continuation: 10xxxxxx 10xxxxxx 10xxxxxx
            b1: int = raw[i + 1];
            b2: int = raw[i + 2];
            b3: int = raw[i + 3];
            if (b1 & 192) == 128 and (b2 & 192) == 128 and (b3 & 192) == 128 {
                cp4: int = (b0 & 7) * 262144
                    + (b1 & 63) * 4096
                    + (b2 & 63) * 64
                    + (b3 & 63);
                if cp4 >= 65536 and cp4 <= 1114111 {
                    out.append(cp4);
                    i = i + 4;
                    continue;
                }
            }
            out.append(b0);
            i = i + 1;
        } else {
            out.append(b0);
            i = i + 1;
        }
    }
    return out;
}

"""True when s[i..i+3] is the Jac \\x00 NUL code-unit escape (4 bytes)."""
def _str_is_nul_escape(s: str, i: int) -> bool {
    # byte values, not one-character strings: this runs per byte in the
    # offset walkers (V4.26)
    if i + 3 >= len(s) or ord(s[i]) != 92 {
        return False;
    }
    return ord(s[i + 1]) == 120 and ord(s[i + 2]) == 48 and ord(s[i + 3]) == 48;
}

"""Convert a raw BYTE offset in `s` into a UTF-16 code-unit offset.

Byte offsets (what native `str.find`/`str.rfind` and byte slicing return) do NOT
equal JS string indices when `s` holds multi-byte UTF-8 or the 4-byte \\x00 NUL
sentinel: a 2/3-byte char is 1 unit, a 4-byte char is 2 units (surrogate pair),
and the 4-byte NUL sentinel is 1 unit. Position-returning String methods
(indexOf/lastIndexOf) MUST report code-unit indices — matching .length /
charCodeAt / slice — or callers doing position arithmetic (e.g. rollup's
findFirstOccurrenceOutsideComment + MagicString) go out of bounds."""
def:pub js_string_byte_to_unit(s: str, byte_off: int) -> int {
    n: int = len(s);
    lim: int = byte_off;
    if lim > n {
        lim = n;
    }
    units: int = 0;
    i: int = 0;
    while i < lim {
        if _str_is_nul_escape(s, i) {
            i = i + 4;
            units = units + 1;
        } else {
            b: int = ord(s[i]);
            if b < 128 {
                i = i + 1;
                units = units + 1;
            } elif b < 224 {
                i = i + 2;
                units = units + 1;
            } elif b < 240 {
                i = i + 3;
                units = units + 1;
            } else {
                i = i + 4;
                units = units + 2;
            }
        }
    }
    return units;
}

"""Convert a UTF-16 code-unit offset in `s` into a raw BYTE offset (inverse of
js_string_byte_to_unit; sentinel/multi-byte aware)."""
def:pub js_string_unit_to_byte(s: str, unit_off: int) -> int {
    n: int = len(s);
    units: int = 0;
    i: int = 0;
    while i < n and units < unit_off {
        if _str_is_nul_escape(s, i) {
            i = i + 4;
            units = units + 1;
        } else {
            b: int = ord(s[i]);
            if b < 128 {
                i = i + 1;
                units = units + 1;
            } elif b < 224 {
                i = i + 2;
                units = units + 1;
            } elif b < 240 {
                i = i + 3;
                units = units + 1;
            } else {
                i = i + 4;
                units = units + 2;
            }
        }
    }
    return i;
}

"""Resume js_string_unit_to_byte from a known (byte_from, unit_from) position in
`s` and advance to UTF-16 index unit_to; returns the byte offset reached (a
code-point boundary at or after unit_to). A caller walking left to right — the
`.replace(re, fn)` fast path over successive matches — converts increasing
indices in O(total) instead of rescanning from the start each time."""
def:pub js_string_unit_to_byte_from(
    s: str, byte_from: int, unit_from: int, unit_to: int
) -> int {
    n: int = len(s);
    units: int = unit_from;
    i: int = byte_from;
    while i < n and units < unit_to {
        if _str_is_nul_escape(s, i) {
            i = i + 4;
            units = units + 1;
        } else {
            b: int = ord(s[i]);
            if b < 128 {
                i = i + 1;
                units = units + 1;
            } elif b < 224 {
                i = i + 2;
                units = units + 1;
            } elif b < 240 {
                i = i + 3;
                units = units + 1;
            } else {
                i = i + 4;
                units = units + 2;
            }
        }
    }
    return i;
}

"""Width of the character starting at byte `i` of `s`, packed as
(bytes << 2) | utf16_units, or 0 for a sequence the decoder could read
differently (see U16Index.regular). The \\x00 NUL sentinel is one unit.
(An int, not a tuple: tuple returns are heap-allocated per call.)"""
def _u16_step(s: str, i: int, n: int) -> int {
    b: int = ord(s[i]);
    if b < 128 {
        if b == 92 and _str_is_nul_escape(s, i) {
            return 17;
        }
        return 5;
    }
    if b < 194 or b > 244 {
        return 0;
    }
    w: int = 4;
    if b < 224 {
        w = 2;
    } elif b < 240 {
        w = 3;
    }
    if i + w > n {
        return 0;
    }
    if b == 244 and ord(s[i + 1]) >= 144 {
        return 0;
    }
    if w == 4 {
        return 18;
    }
    return w * 4 + 1;
}

"""Build the U16Index of `s` (one pass). Long ASCII stretches are the common
case even in a non-ASCII string (bundle code with one non-ASCII literal): an
ASCII run advances bytes and units 1:1, so it is skipped with one byte compare
per byte and its checkpoints are placed arithmetically, instead of the full
per-character step (~40 instructions; these builds were 29% of the jac_client
render phase). A backslash ends the run: it may start the 4-byte `\\x00` NUL
sentinel (one UTF-16 unit), which _u16_step measures."""
def _u16ix_build(id: int, s: str) -> U16Index {
    ix: U16Index = U16Index(id=id, bytes=[0], units=[0], total=0, regular=True);
    n: int = len(s);
    i: int = 0;
    u: int = 0;
    nxt: int = U16IX_STEP;
    while i < n {
        r: int = i;
        while r < n {
            rb: int = ord(s[r]);
            if rb >= 128 or rb == 92 {
                break;
            }
            r = r + 1;
        }
        if r > i {
            ru_end: int = u + (r - i);
            while nxt <= ru_end {
                ix.bytes.append(i + (nxt - u));
                ix.units.append(nxt);
                nxt = nxt + U16IX_STEP;
            }
            i = r;
            u = ru_end;
            if i >= n {
                break;
            }
        }
        cw: int = _u16_step(s, i, n);
        if cw == 0 {
            ix.regular = False;
            return ix;
        }
        i = i + (cw >> 2);
        u = u + (cw & 3);
        if u >= nxt {
            ix.bytes.append(i);
            ix.units.append(u);
            nxt = (u // U16IX_STEP + 1) * U16IX_STEP;
        }
    }
    ix.total = u;
    return ix;
}

"""The U16Index of string `id` (whose text is `s`), built on first use."""
def:pub js_string_u16ix(id: int, s: str) -> U16Index {
    hit: int = _U16IX_POS.get(id, -1);
    if hit >= 0 {
        return _U16IX[hit];
    }
    built: U16Index = _u16ix_build(id, s);
    if len(_U16IX) < U16IX_SLOTS {
        _U16IX_POS[id] = len(_U16IX);
        _U16IX.append(built);
    } else {
        old_id: int = _U16IX[_U16IX_NEXT].id;
        if old_id >= 0 and _U16IX_POS.get(old_id, -1) == _U16IX_NEXT {
            del _U16IX_POS[old_id];
        }
        _U16IX[_U16IX_NEXT] = built;
        _U16IX_POS[id] = _U16IX_NEXT;
        _U16IX_NEXT = (_U16IX_NEXT + 1) % U16IX_SLOTS;
    }
    return built;
}

"""Byte offset of UTF-16 unit `t` (0 <= t <= ix.total) in `s`, or -1 when `t`
falls between the two halves of a surrogate pair (no byte boundary there)."""
def:pub u16ix_unit_to_byte(ix: U16Index, s: str, t: int) -> int {
    if t <= 0 {
        return 0;
    }
    if t >= ix.total {
        return len(s);
    }
    j: int = t // U16IX_STEP;
    if j >= len(ix.units) {
        j = len(ix.units) - 1;
    }
    while j > 0 and ix.units[j] > t {
        j = j - 1;
    }
    while j + 1 < len(ix.units) and ix.units[j + 1] <= t {
        j = j + 1;
    }
    i: int = ix.bytes[j];
    u: int = ix.units[j];
    n: int = len(s);
    while u < t {
        cw: int = _u16_step(s, i, n);
        i = i + (cw >> 2);
        u = u + (cw & 3);
    }
    if u > t {
        return -1;
    }
    return i;
}

"""UTF-16 unit offset of byte offset `b` (a character boundary) in `s`."""
def:pub u16ix_byte_to_unit(ix: U16Index, s: str, b: int) -> int {
    lo: int = 0;
    hi: int = len(ix.bytes) - 1;
    while lo < hi {
        mid: int = (lo + hi + 1) // 2;
        if ix.bytes[mid] <= b {
            lo = mid;
        } else {
            hi = mid - 1;
        }
    }
    i: int = ix.bytes[lo];
    u: int = ix.units[lo];
    n: int = len(s);
    while i < b and i < n {
        cw: int = _u16_step(s, i, n);
        i = i + (cw >> 2);
        u = u + (cw & 3);
    }
    return u;
}

"""
Decode a Jac str (raw UTF-8 byte sequence) to a list of Unicode code-point ints.

Optimisation: for pure-ASCII strings (all bytes < 128) each byte IS its own codepoint,
so we skip the expensive _utf8_bytes_to_codepoints parser entirely.
We also read bytes via s[i] (char-cache GEP, O(1)) instead of calling str_char_at
(which performs a redundant bounds check and len() call on each iteration).
"""
def:pub utf8_decode_str_to_codepoints(s: str) -> list[int] {
    n: int = len(s);
    raw: list[int] = [];
    is_ascii: bool = True;
    i: int = 0;
    while i < n {
        b: int = ord(s[i]);
        raw.append(b);
        if b >= 128 {
            is_ascii = False;
        }
        i = i + 1;
    }
    if is_ascii {
        out: list[int] = [];
        j: int = 0;
        while j < n {
            if _str_is_nul_escape(s, j) {
                out.append(0);
                j = j + 4;
                continue;
            }
            out.append(ord(s[j]));
            j = j + 1;
        }
        return out;
    }
    return _utf8_bytes_to_codepoints(raw);
}

"""
Map Unicode scalars (code points) to ECMAScript UTF-16 code units.
BMP scalars → 1 unit; astral scalars (> U+FFFF) → surrogate pair (2 units).
Lone surrogates (0xD800–0xDFFF) pass through as single units.
"""
def:pub codepoints_to_utf16_units(cps: list[int]) -> list[int] {
    out: list[int] = [];
    for cp in cps {
        if cp >= 55296 and cp <= 57343 {
            # Lone surrogate — passes through as-is.
            out.append(cp);
        } elif cp > 65535 and cp <= 1114111 {
            u: int = cp - 65536;
            out.append(55296 + (u >> 10));
            out.append(56320 + (u & 1023));
        } elif cp <= 65535 {
            out.append(cp);
        } else {
            out.append(63);  # U+003F '?' for out-of-range scalars
        }
    }
    return out;
}

"""
Expand a JS string's raw UTF-8 backing store to its ECMAScript UTF-16 code units.
"""
def:pub js_string_utf16_units(s: str) -> list[int] {
    return codepoints_to_utf16_units(utf8_decode_str_to_codepoints(s));
}

"""UTF-16 length of the string CELL `id`, O(1) when the cell is known ASCII.

`.length` is read constantly (often in a loop header), and js_string_utf16_len on
a plain str rescans the bytes every call — O(n^2) in a loop. For an all-ASCII
cell, byte length == UTF-16 length == the cached char length, so no scan is
needed. Falls back to the scanning path when ASCII-ness is unknown or false."""
def:pub js_string_utf16_len_cell(id: int) -> int {
    if str_cell_ascii(id) == 1 {
        # Flag 1 = byte-clean (no multi-byte chars, no `\\x00` sentinel — the
        # sentinel test is folded into _ascii_flag at cell creation), so the
        # byte length IS the UTF-16 length: O(1), no per-call rescan.
        return str_cell_len(id);
    }
    # Non-ASCII: the cached checkpoint index carries the unit count (several
    # strings stay cached, so interleaved `.length` reads don't evict each other).
    l_s: str = str_from_id(id);
    l_ix: U16Index = js_string_u16ix(id, l_s);
    if l_ix.regular {
        return l_ix.total;
    }
    # NON-ASCII `.length` also re-scanned per call → O(n²) in a `for(;i<s.length;)`
    # loop (the transform's other quadratic, alongside charCodeAt). Route through
    # the same units memo: the first .length builds it, and both .length AND the
    # loop-body charCodeAt then hit it. Build FIRST, assign id LAST (str_from_id
    # rope-flatten may reset the memo — see js_string_unit_at_cell).
    if id != _U16MEMO_ID {
        _built_l: list[int] = js_string_utf16_units(str_from_id(id));
        _U16MEMO = _built_l;
        _U16MEMO_ID = id;
    }
    return len(_U16MEMO);
}

"""
Return the number of UTF-16 code units in `s` (ECMAScript String.prototype.length).

ASCII fast path: for strings where every byte is < 128, each byte maps to exactly
one UTF-16 code unit (no surrogates, no multi-byte codepoints), so the length equals
the byte length.  We scan the raw bytes with s[i] (char-cache, O(1) per byte, no
function-call overhead) and bail out to the full decode only when a high byte is found.
For the vite/bundler workload (pure ASCII JS source), this eliminates the
utf8_decode_str_to_codepoints + codepoints_to_utf16_units calls entirely.
"""
def:pub js_string_utf16_len(s: str) -> int {
    n: int = len(s);
    i: int = 0;
    units: int = 0;
    while i < n {
        if ord(s[i]) >= 128 {
            return len(codepoints_to_utf16_units(utf8_decode_str_to_codepoints(s)));
        }
        if _str_is_nul_escape(s, i) {
            units = units + 1;
            i = i + 4;
            continue;
        }
        units = units + 1;
        i = i + 1;
    }
    return units;
}

"""
Return the single UTF-16 code unit at position `n` (or -1 if out of range),
WITHOUT materialising the whole units list.

charCodeAt/codePointAt/at are commonly called in O(n) loops; building the entire
`list[int]` of UTF-16 units on every call (js_string_utf16_units) makes such loops
O(n²) in time and allocation.  Mirroring js_string_utf16_len's ASCII fast path: for
a position inside a leading all-ASCII run, the unit is just ord(s[n]) (O(1) via the
char-cache).  Only when a high byte appears at or before `n` do we fall back to the
full decode for that one call.
"""
def:pub js_string_utf16_unit_at(s: str, n: int) -> int {
    if n < 0 {
        return -1;
    }
    blen: int = len(s);
    ui: int = 0;
    i: int = 0;
    while i < blen {
        if ord(s[i]) >= 128 {
            break;
        }
        if _str_is_nul_escape(s, i) {
            if ui == n {
                return 0;
            }
            ui = ui + 1;
            i = i + 4;
            continue;
        }
        if ui == n {
            return ord(s[i]);
        }
        ui = ui + 1;
        i = i + 1;
    }
    units: list[int] = js_string_utf16_units(s);
    if n >= len(units) {
        return -1;
    }
    return units[n];
}

"""UTF-16 unit at position `n` of the string CELL `id`, using its cached ASCII
flag to stay O(1). This is the version charAt / charCodeAt / codePointAt should
call: the plain-str js_string_utf16_unit_at above must re-scan bytes [0,n] every
call (O(n^2) in a loop) because a bare str has no place to cache ASCII-ness.

When the cell is known pure-ASCII, byte index == UTF-16 index, so the answer is
ord(byte n) — one array index, no scan. Otherwise, or when the flag is unknown,
it delegates to the scanning path (correct, just not O(1))."""
def:pub js_string_unit_at_cell(id: int, n: int) -> int {
    if n < 0 {
        return -1;
    }
    if str_cell_ascii(id) == 1 {
        # Flag 1 = byte-clean (see _ascii_flag): 1 byte == 1 unit, O(1).
        s_a: str = str_from_id(id);
        if n < len(s_a) {
            return ord(s_a[n]);
        }
        return -1;
    }
    # NON-ASCII cell: `charCodeAt(i)` in a loop must NOT re-decode the whole
    # string per call (js_string_utf16_unit_at did — O(n²); a large non-ASCII
    # module string charCodeAt-looped by rollup/esbuild wedged the vite build
    # for >10min). Memoize this cell's decoded UTF-16 units by id: a synchronous
    # index loop hits the same id every call → build once (O(n)), then O(1)
    # lookups. The memo is invalidated whenever a heap slot is (re)allocated
    # (see _heap_slot_alloc), which covers GC freeing+recycling this id's slot —
    # the only way `id` could ever mean a different string. Strings are
    # immutable, so within a live id the units never change.
    if id != _U16MEMO_ID {
        # Build FIRST, assign the id LAST: str_from_id() may flatten a rope,
        # which allocates a heap slot and resets _U16MEMO_ID — setting the id
        # before the build would let that reset clobber it (memo never sticks).
        _built_u: list[int] = js_string_utf16_units(str_from_id(id));
        _U16MEMO = _built_u;
        _U16MEMO_ID = id;
    }
    if n < len(_U16MEMO) {
        return _U16MEMO[n];
    }
    return -1;
}

"""
Recombine adjacent surrogate pairs in a UTF-16 unit list into astral scalars.
"""
def:pub utf16_units_to_scalars(units: list[int]) -> list[int] {
    out: list[int] = [];
    i: int = 0;
    n: int = len(units);
    while i < n {
        u0: int = units[i];
        if u0 >= 55296 and u0 <= 56319 and i + 1 < n {
            u1: int = units[i + 1];
            if u1 >= 56320 and u1 <= 57343 {
                out.append(65536 + ((u0 - 55296) << 10) + (u1 - 56320));
                i = i + 2;
                continue;
            }
        }
        out.append(u0);
        i = i + 1;
    }
    return out;
}

"""Wire-UTF-8 helpers for file/socket writes (leaf module: fs.jac cannot import
buffer_native — that reaches vm_obs → vm → fs, a cycle that silently dropped the
whole native link). Engine strings are CESU-8 + a 4-char NUL sentinel; wire form is
real UTF-8: surrogate pairs → 4-byte scalars, lone halves → U+FFFD, sentinel → 0x00."""
def _ws_at_nul_sentinel(s: str, i: int, n: int) -> bool {
    return i + 3 < n
        and ord(s[i + 1]) == 120
        and ord(s[i + 2]) == 48
        and ord(s[i + 3]) == 48;
}

"""True when `s` needs conversion to wire UTF-8 (NUL sentinel or 0xED surrogate lead)."""
def:pub wire_utf8_needs_convert(s: str) -> bool {
    n: int = len(s);
    i: int = 0;
    while i < n {
        b: int = ord(s[i]);
        if b == 237 {
            return True;
        }
        if b == 92 and _ws_at_nul_sentinel(s, i, n) {
            return True;
        }
        i = i + 1;
    }
    return False;
}

"""Wire UTF-8 byte length of engine string `s`."""
def:pub wire_utf8_len(s: str) -> int {
    n: int = len(s);
    i: int = 0;
    out: int = 0;
    while i < n {
        b: int = ord(s[i]);
        if b < 128 {
            if b == 92 and _ws_at_nul_sentinel(s, i, n) {
                i = i + 4;
            } else {
                i = i + 1;
            }
            out = out + 1;
        } elif b == 237 and i + 2 < n and (ord(s[i + 1]) & 224) == 160 {
            if (ord(s[i + 1]) & 240) == 160
                and i + 5 < n
                and ord(s[i + 3]) == 237
                and (ord(s[i + 4]) & 240) == 176 {
                out = out + 4;  # high + low surrogate → one 4-byte scalar
                i = i + 6;
            } else {
                out = out + 3;  # lone surrogate → U+FFFD
                i = i + 3;
            }
        } else {
            l: int = 2;
            if b >= 240 {
                l = 4;
            } elif b >= 224 {
                l = 3;
            }
            if i + l > n {
                l = n - i;
            }
            out = out + l;
            i = i + l;
        }
    }
    return out;
}

"""Encode `s` as wire UTF-8 into dst[0 .. cap); returns bytes written, never splits a char."""
def:pub wire_utf8_write(s: str, dst: int, cap: int) -> int {
    off: int = 0;
    n: int = len(s);
    i: int = 0;
    w: int = 0;
    while i < n {
        b: int = ord(s[i]);
        if b < 128 {
            if w + 1 > cap {
                break;
            }
            if b == 92 and _ws_at_nul_sentinel(s, i, n) {
                write_byte(dst, off + w, 0);
                i = i + 4;
            } else {
                write_byte(dst, off + w, b);
                i = i + 1;
            }
            w = w + 1;
        } elif b == 237 and i + 2 < n and (ord(s[i + 1]) & 224) == 160 {
            b1: int = ord(s[i + 1]);
            b2: int = ord(s[i + 2]);
            if (b1 & 240) == 160
                and i + 5 < n
                and ord(s[i + 3]) == 237
                and (ord(s[i + 4]) & 240) == 176 {
                if w + 4 > cap {
                    break;
                }
                hi: int = ((b & 15) << 12) | ((b1 & 63) << 6) | (b2 & 63);
                lo: int = ((ord(s[i + 3]) & 15) << 12)
                    | ((ord(s[i + 4]) & 63) << 6)
                    | (ord(s[i + 5]) & 63);
                cp: int = 65536 + ((hi - 55296) << 10) + (lo - 56320);
                write_byte(dst, off + w, 240 | (cp >> 18));
                write_byte(dst, off + w + 1, 128 | ((cp >> 12) & 63));
                write_byte(dst, off + w + 2, 128 | ((cp >> 6) & 63));
                write_byte(dst, off + w + 3, 128 | (cp & 63));
                w = w + 4;
                i = i + 6;
            } else {
                if w + 3 > cap {
                    break;
                }
                write_byte(dst, off + w, 239);
                write_byte(dst, off + w + 1, 191);
                write_byte(dst, off + w + 2, 189);
                w = w + 3;
                i = i + 3;
            }
        } else {
            l: int = 2;
            if b >= 240 {
                l = 4;
            } elif b >= 224 {
                l = 3;
            }
            if i + l > n {
                l = n - i;
            }
            if w + l > cap {
                break;
            }
            k: int = 0;
            while k < l {
                write_byte(dst, off + w + k, ord(s[i + k]));
                k = k + 1;
            }
            w = w + l;
            i = i + l;
        }
    }
    return w;
}

"""One UTF-16 code unit as a string in the engine's internal form: ASCII byte,
the 4-char NUL sentinel for U+0000, UTF-8 for other BMP units and CESU-8 for a
surrogate half."""
def:pub js_string_unit_str(u: int) -> str {
    if u == 0 {
        return "\\x00";
    }
    if u < 128 {
        return chr(u);
    }
    return utf8_encode_scalar(u);
}

def:pub js_string_from_utf16_code_units(units: list[int]) -> str {
    # Encode each UTF-16 code unit independently (CESU-8 for surrogate halves).
    # Do NOT recombine surrogate pairs into a single UTF-8 astral scalar: JS source
    # escapes like "\uD83D\uDE00" are stored as two CESU-8 units, and
    # String.fromCharCode(0xD83D, 0xDE00) must === that form. Merging made
    # fromCharCode produce 4-byte UTF-8 "😀" and broke === with escape literals.
    # append+join, not per-unit `out = out + piece` concat: that is O(n²) bytes
    # and O(n) allocations per call. This function sits under slice/substring/
    # fromCharCode/trim/pad — the quadratic made String.prototype.slice allocate
    # >1MB and burn ~330µs PER CALL (1,188 allocations each), which both OOM'd
    # and stalled vite's transform phase.
    out: list[str] = [];
    i: int = 0;
    n: int = len(units);
    while i < n {
        cu: int = units[i];
        if cu == 0 {
            # 4-char NUL sentinel, not a real NUL byte (see utf8_encode_scalar).
            out.append("\\x00");
        } else {
            out.append(utf8_encode_scalar(cu));
        }
        i = i + 1;
    }
    return "".join(out);
}
