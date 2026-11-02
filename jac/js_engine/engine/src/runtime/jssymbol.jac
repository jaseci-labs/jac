"""JSSymbol: JavaScript Symbol primitive type.

Each Symbol is a unique, immutable value used as a property key.
Symbols are allocated into a flat table (_SYMBOL_TABLE) indexed by an integer
ID stored in JSValue.as_ptr.

The five well-known symbols (Symbol.iterator etc.) occupy fixed slots 0–4
and are seeded immediately on startup via symbol_seed_well_known() before any
user code runs.

Object key encoding for Symbol-keyed properties (from jsobject.na.jac):
  key id = SYMBOL_KEY_BASE + symbol_id
The separate numeric range prevents collisions with string-interned key IDs.

Bun Zig mapping:
  _SYMBOL_TABLE       → JSC::Symbol UID counter + string description store
  js_symbol()         → JSC::Symbol::create(vm, description)
  js_symbol_for()     → JSC::Symbol::createWithDescription + globalRegistry
  js_symbol_key_for() → global symbol registry reverse lookup
  SYMBOL_ITERATOR     → vm.propertyNames->iteratorSymbol (WellKnownSymbols.h)

ECMAScript spec:
  §6.1.5  The Symbol Type
  §12.8   Well-Known Symbols
  §20.4   The Symbol Constructor  https://tc39.es/ecma262/#sec-symbol-constructor
"""

import from engine.src.runtime.jsvalue {
    JSValue,
    js_undefined,
    jsv_from_symbol_id,
    jsv_is_symbol,
    jsv_is_object_cell,
    jsv_to_table_id
}
import from engine.src.runtime.realm { Realm }
import from engine.src.runtime.jsstring { str_intern }
import from engine.src.runtime.gc_pin { gc_pin_value }
import from engine.src.runtime.jsobject {
    JSProperty,
    js_object_get_own_property_descriptor
}


# ── Well-known Symbol IDs (fixed at startup) ─────────────────────────────────
# These IDs are stable — they are seeded first and never change.

glob SYMBOL_ITERATOR: int = 0,
     SYMBOL_TO_PRIMITIVE: int = 1,
     SYMBOL_HAS_INSTANCE: int = 2,
     SYMBOL_TO_STRING_TAG: int = 3,
     SYMBOL_SPECIES: int = 4,
     SYMBOL_ASYNC_ITERATOR: int = 5,
     SYMBOL_MATCH: int = 6,
     SYMBOL_REPLACE: int = 7,
     SYMBOL_SEARCH: int = 8,
     SYMBOL_SPLIT: int = 9,
     SYMBOL_MATCH_ALL: int = 10,
     SYMBOL_UNSCOPABLES: int = 11,
     SYMBOL_DISPOSE: int = 12,
     SYMBOL_ASYNC_DISPOSE: int = 13,
     SYMBOL_ISOONCATSPREADABLE: int = 14;  # Symbol.iterator


# Symbol.toPrimitive
# Symbol.hasInstance
# Symbol.toStringTag
# Symbol.species
# Symbol.asyncIterator
# Symbol.match
# Symbol.replace
# Symbol.search
# Symbol.split
# Symbol.matchAll
# Symbol.unscopables
# Symbol.dispose (explicit resource management)
# Symbol.asyncDispose
# Symbol.isConcatSpreadable
# ── Runtime tables ────────────────────────────────────────────────────────────

# State is now held in Realm (realm.symbols, realm.symbol_registry, realm.symbol_seeded).
# All public functions receive realm as first parameter.

# ── Startup seeding ───────────────────────────────────────────────────────────

"""
Seed the well-known symbols into _SYMBOL_TABLE at fixed indices.

Must be called as the very first action of init_global() so that the
IDs SYMBOL_ITERATOR…SYMBOL_ASYNC_ITERATOR are guaranteed stable before any
user-land code or intern-table activity.

Idempotent — safe to call multiple times (guarded by _SYMBOL_SEEDED).
"""
def:pub symbol_seed_well_known(realm: Realm) -> None {
    if realm.symbol_seeded {
        return;
    }
    realm.symbols.append("Symbol.iterator");  # 0 = SYMBOL_ITERATOR
    realm.symbols.append("Symbol.toPrimitive");  # 1 = SYMBOL_TO_PRIMITIVE
    realm.symbols.append("Symbol.hasInstance");  # 2 = SYMBOL_HAS_INSTANCE
    realm.symbols.append("Symbol.toStringTag");  # 3 = SYMBOL_TO_STRING_TAG
    realm.symbols.append("Symbol.species");  # 4 = SYMBOL_SPECIES
    realm.symbols.append("Symbol.asyncIterator");  # 5 = SYMBOL_ASYNC_ITERATOR
    realm.symbols.append("Symbol.match");  # 6 = SYMBOL_MATCH
    realm.symbols.append("Symbol.replace");  # 7 = SYMBOL_REPLACE
    realm.symbols.append("Symbol.search");  # 8 = SYMBOL_SEARCH
    realm.symbols.append("Symbol.split");  # 9 = SYMBOL_SPLIT
    realm.symbols.append("Symbol.matchAll");  # 10 = SYMBOL_MATCH_ALL
    realm.symbols.append("Symbol.unscopables");  # 11 = SYMBOL_UNSCOPABLES
    realm.symbols.append("Symbol.dispose");  # 12 = SYMBOL_DISPOSE
    realm.symbols.append("Symbol.asyncDispose");  # 13 = SYMBOL_ASYNC_DISPOSE
    realm.symbols.append("Symbol.isConcatSpreadable");  # 14 = SYMBOL_ISOONCATSPREADABLE
    realm.symbol_seeded = True;
}


# ── Core operations ───────────────────────────────────────────────────────────

"""
Allocate a new unique Symbol with the given description string.

Each call produces a JSValue with a distinct as_ptr (the next table slot),
so Symbol("x") !== Symbol("x") holds.

ECMAScript: Symbol([description]) — §20.4.1.1
"""
# Sentinel stored for a Symbol created with NO description (`Symbol()` /
# `Symbol(undefined)`) — distinct from an empty-string description (`Symbol("")`).
# `.description` returns undefined for the sentinel, "" for a real empty string.
glob:pub _SYMBOL_NO_DESC: str = "\x00\x1fno-symbol-description\x1f\x00";

def:pub js_symbol(realm: Realm, description: str) -> JSValue {
    id: int = len(realm.symbols);
    realm.symbols.append(description);
    return jsv_from_symbol_id(id);
}

"""True when the symbol was created without a description (§ description → undefined)."""
def:pub symbol_has_no_description(realm: Realm, v: JSValue) -> bool {
    return symbol_description(realm, v) == _SYMBOL_NO_DESC;
}

"""The realm's Symbol.prototype, wired from realm_bootstrap once
Object.prototype exists (Symbol.prototype is an ordinary object, §20.4.3)."""
glob _SYMBOL_PROTO: JSValue = js_undefined();

def:pub js_symbol_set_proto(proto: JSValue) {
    _SYMBOL_PROTO = proto;
    gc_pin_value(proto);  # glob-held singleton — invisible to the GC root walk
}

def:pub js_symbol_get_proto -> JSValue {
    return _SYMBOL_PROTO;
}

"""Return True if v is a Symbol JSValue."""
def:pub is_symbol(v: JSValue) -> bool {
    return jsv_is_symbol(v);
}

"""
Return the integer symbol ID (index into _SYMBOL_TABLE).
Returns -1 if v is not a Symbol.
"""
def:pub symbol_id(v: JSValue) -> int {
    if not jsv_is_symbol(v) {
        return -1;
    }
    return jsv_to_table_id(v);
}

"""
Return a JSValue for a well-known symbol by its fixed-ID constant.

Example:  js_well_known_symbol(SYMBOL_ITERATOR)

These JSValues have as_ptr equal to the well-known slot index; they compare
equal to any other JSValue produced by js_well_known_symbol() with the same id.
"""
def:pub js_well_known_symbol(sym_id: int) -> JSValue {
    return jsv_from_symbol_id(sym_id);
}

"""
Return the canonical description string for a Symbol — equals
what JS-land receives from Symbol.prototype.toString().

Returns "Symbol()" for an empty or missing description;
"Symbol(<description>)" otherwise.

ECMAScript: Symbol.prototype.toString() — §20.4.3.3
"""
def _symbol_unbox(v: JSValue) -> JSValue {
    # Unbox Symbol wrapper ([[PrimitiveValue]]) from Object.assign / ToObject.
    if jsv_is_object_cell(v) and jsv_to_table_id(v) > 0 {
        pk: int = str_intern("[[PrimitiveValue]]");
        prop: JSProperty = js_object_get_own_property_descriptor(v, pk);
        if prop.key != 0 and jsv_is_symbol(prop.value) {
            return prop.value;
        }
    }
    return v;
}

def:pub symbol_to_str(realm: Realm, v: JSValue) -> str {
    v = _symbol_unbox(v);
    if not jsv_is_symbol(v) {
        return "Symbol()";
    }
    id: int = jsv_to_table_id(v);
    if id < 0 or id >= len(realm.symbols) {
        return "Symbol()";
    }
    desc: str = realm.symbols[id];
    # Both an empty description and the no-description sentinel render as "Symbol()".
    if desc == "" or desc == _SYMBOL_NO_DESC {
        return "Symbol()";
    }
    return "Symbol(" + desc + ")";
}

"""
Return the description string of a Symbol (JSValue → Jac str), or "" if absent.
Equivalent to the Symbol.prototype.description getter (Stage 3+).
"""
def:pub symbol_description(realm: Realm, v: JSValue) -> str {
    v = _symbol_unbox(v);
    if not jsv_is_symbol(v) {
        return "";
    }
    id: int = jsv_to_table_id(v);
    if id < 0 or id >= len(realm.symbols) {
        return "";
    }
    return realm.symbols[id];
}


# ── Global symbol registry ────────────────────────────────────────────────────

"""
Symbol.for(key) — look up the global registry; create and register if absent.

Symbols created via Symbol.for() ARE in the registry and can be retrieved
by key; all calls with the same key return the same JSValue (same as_ptr).

ECMAScript §20.4.2.1
"""
def:pub js_symbol_for(realm: Realm, key: str) -> JSValue {
    if key in realm.symbol_registry {
        id: int = realm.symbol_registry[key];
        return jsv_from_symbol_id(id);
    }
    id2: int = len(realm.symbols);
    realm.symbols.append(key);
    realm.symbol_registry[key] = id2;
    return jsv_from_symbol_id(id2);
}

"""
Symbol.keyFor(sym) — reverse-look up the global registry.

Returns the key string if sym was created via Symbol.for(), or "" to
signal 'not found' (which the JS caller translates to undefined).

ECMAScript §20.4.2.2
"""
def:pub js_symbol_key_for(realm: Realm, v: JSValue) -> str {
    if not jsv_is_symbol(v) {
        return "";
    }
    id: int = jsv_to_table_id(v);
    for key in realm.symbol_registry {
        if realm.symbol_registry[key] == id {
            return key;
        }
    }
    return "";
}
# Merge note: a second copy of _SYMBOL_PROTO / js_symbol_set_proto /
# js_symbol_get_proto was auto-merged in here; removed as a duplicate of the
# definitions above (~line 117) that caused a native-link symbol collision.
