"""
JSSetStorage type definition — shared by builtins/set.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _SET_TABLE — that stays in set.na.jac.
"""

import from engine.src.runtime.jsvalue { JSValue }


# ═══════════════════════════════════════════════════════════════════════════════
# JSSetStorage
# ═══════════════════════════════════════════════════════════════════════════════

"""Storage for a JS Set or WeakSet object.

A Set's members are `ekeys` in insertion order; a deleted member is the hole
sentinel (live iterators step over it) and `head` is the first live one (-1:
none). Until its first add a Set shares the empty SET_NO_* containers (`owned`
False). WeakSet keeps its members in `items` instead."""
obj:pub JSSetStorage {
    has ekeys: list[JSValue],
        key_index: dict[int, int],
        items: list[JSValue],
        head: int = -1,
        live_count: int = 0,
        owned: bool = False,
        cell_kind: int = 7,
        cell_flags: int = 0,
        structure_id: int = 0,
        base: int = 0;
}
# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_SET

# Iterator cursors count members from the Set's creation; ekeys[0] is member
# number `base` (leading deleted members are dropped, see _set_compact_prefix).

# Shared empty containers (never mutated: writers replace them first).
glob:pub SET_NO_VALS: list[JSValue] = [],
         SET_NO_INDEX: dict[int, int] = {};
