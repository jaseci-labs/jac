"""
JSMapStorage type definition — shared by builtins/map.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _MAP_TABLE — that stays in map.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue }


# ═══════════════════════════════════════════════════════════════════════════════
# JSMapStorage
# ═══════════════════════════════════════════════════════════════════════════════

"""Storage for a JS Map or WeakMap — ordered hash table with SameValueZero keys."""
obj:pub JSMapNode {
    has key: JSValue,
        val: JSValue,
        prev: int = -1,
        next: int = -1,
        tombstone: bool = False;
}

# insertion-order doubly-linked list
obj:pub JSMapStorage {
    has nodes: list[JSMapNode],
        key_index: dict[int, int],
        keys: list[JSValue],
        vals: list[JSValue],
        head: int = -1,
        tail: int = -1,
        live_count: int = 0,
        cell_kind: int = 6,
        cell_flags: int = 0,
        structure_id: int = 0,
        base: int = 0;
}
# Parallel lists retained for WeakMap strong storage only; Map size/iteration
# use `nodes` + `live_count` (tombstones skipped by live iterators).

# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_MAP

# Iterator cursors count nodes from the Map's creation; nodes[0] is node
# number `base` (leading tombstones are dropped, see _map_compact_prefix).
