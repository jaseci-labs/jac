"""Relational shadow store: typed tables derived from the graph schema.

Routes anchor writes into the relational layout (nodes directory,
per-node-archetype tables, one edges table) alongside the monolithic
`anchors` table. Enabled by JAC_RELATIONAL=shadow|on; `anchors` remains
the source of truth while parity is proven. Table plans come from the
compiler-extracted graph_schema manifest when the defining module is
loaded, with runtime reflection over the archetype class as fallback, so
dynamically created types still route.

No FK constraints in shadow phase: an edge may be flushed before its
endpoints exist relationally (pre-enable rows, stubs). Constraints are a
cutover step after backfill validates.
"""

import from uuid { UUID }

glob __all__ = [
         'ColumnSpec',
         'TablePlan',
         'relational_enabled',
         'plan_for',
         'relational_after_upsert',
         'relational_after_delete',
         'relational_parity',
         'relational_reset_cache'
     ];


obj ColumnSpec {
    has name: str,
        col: str,
        tier: str,
        sql_type: str;
}


obj TablePlan {
    has table: str,
        arch_type: str,
        arch_module: str,
        columns: list[ColumnSpec];
}


def relational_enabled -> bool;

def relational_read_enabled -> bool;

def plan_for(arch_type: str, arch_module: str) -> (TablePlan | None);

def relational_after_upsert(store: object, rows: list) -> None;

def relational_after_delete(store: object, ids: list[UUID]) -> None;

def relational_parity(store: object, limit: int = 1000) -> list[str];

def relational_load_full(store: object, ids: list[UUID]) -> tuple;

def relational_backfill(store: object, batch: int = 2000) -> dict;

def relational_reset_cache -> None;
