"""
JSMapStorage type definition — shared by builtins/map.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _MAP_TABLE — that stays in map.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue }


# ═══════════════════════════════════════════════════════════════════════════════
# JSMapStorage
# ═══════════════════════════════════════════════════════════════════════════════

"""Storage for a JS Map or WeakMap — ordered hash table with SameValueZero keys.

A Map's entries are the parallel lists `ekeys` / `evals` in insertion order; a
deleted entry's key is the hole sentinel (live iterators step over it) and
`head` is the first live entry (-1: none). `key_index` maps a key's stable id to
its entry. Until its first insert a Map shares the empty MAP_NO_* containers
(`owned` False) — most Maps a bundler makes stay small or empty. WeakMap keeps
its entries in `keys` / `vals` instead."""
obj:pub JSMapStorage {
    has ekeys: list[JSValue],
        evals: list[JSValue],
        key_index: dict[int, int],
        keys: list[JSValue],
        vals: list[JSValue],
        head: int = -1,
        live_count: int = 0,
        owned: bool = False,
        cell_kind: int = 6,
        cell_flags: int = 0,
        structure_id: int = 0,
        base: int = 0;
}
# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_MAP

# Iterator cursors count entries from the Map's creation; ekeys[0] is entry
# number `base` (leading deleted entries are dropped, see _map_compact_prefix).

# Shared empty containers (never mutated: writers replace them first).
glob:pub MAP_NO_VALS: list[JSValue] = [],
         MAP_NO_INDEX: dict[int, int] = {};
