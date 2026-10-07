"""
JSSetStorage type definition — shared by builtins/set.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _SET_TABLE — that stays in set.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue }


# ═══════════════════════════════════════════════════════════════════════════════
# JSSetStorage
# ═══════════════════════════════════════════════════════════════════════════════

"""Insertion-order node for Set (SameValueZero keys, tombstones for live iters)."""
obj:pub JSSetNode {
    has key: JSValue,
        prev: int = -1,
        next: int = -1,
        tombstone: bool = False;
}

"""Storage for a JS Set or WeakSet object.
Set uses ordered nodes + live_count; WeakSet keeps a parallel `items` list."""
obj:pub JSSetStorage {
    has nodes: list[JSSetNode],
        key_index: dict[int, int],
        items: list[JSValue],
        head: int = -1,
        tail: int = -1,
        live_count: int = 0,
        cell_kind: int = 7,
        cell_flags: int = 0,
        structure_id: int = 0,
        base: int = 0;
}
# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_SET

# Iterator cursors count nodes from the Set's creation; nodes[0] is node
# number `base` (leading tombstones are dropped, see _set_compact_prefix).
