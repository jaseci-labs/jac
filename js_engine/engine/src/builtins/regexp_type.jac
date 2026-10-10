"""
JSRegExpState type definition — shared by builtins/regexp.na.jac and realm.na.jac.

Does NOT import runtime.realm (that would create a cycle).
Does NOT define _REGEXP_TABLE — that stays in regexp.na.jac.
"""

# ═══════════════════════════════════════════════════════════════════════════════
# JSRegExpState
# ═══════════════════════════════════════════════════════════════════════════════

"""Compiled RegExp state."""
obj:pub JSRegExpState {
    has pattern: str,
        flags: str,
        last_index: int,
        pcre2_code_ptr: int,
        num_groups: int,
        group_names: list[str],
        flag_g: bool,
        flag_i: bool,
        flag_m: bool,
        flag_s: bool,
        flag_u: bool,
        flag_y: bool,
        flag_d: bool,
        flag_v: bool,
        cell_kind: int = 9,
        cell_flags: int = 0,
        structure_id: int = 0;
}
# pcre2_code* — C heap, never freed (process lifetime)

# Parallel to capturing groups 1..n; empty string where group has no name.

# ── Cell header (A2.1) ─────────────────────────────────────────────────
# CELL_KIND_REGEXP
