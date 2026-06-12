"""Declarative schema drift rules for Jac persistence.

Archetypes declare how their stored shape evolved by defining a
`static def __jac_schema__() -> None;` whose body calls the ambient
builders (`schema_was`, `schema_alias`, `schema_drop`, `schema_upgrade`).
The Serializer executes that method once at class registration under a
rule collector, validates the rules against the live dataclass fields,
and applies them to raw stored dicts before field deserialization.

Rules are shape-matched, not version-matched: a rename applies to any
stored document that still carries the old key and lacks the new one,
which keeps repair robust when different environments saw different
intermediate schemas. Repaired-away values are never destroyed — they
move into the document's attic (`__jac_attic__`) instead.

The `JAC_SCHEMA_REPAIR` environment variable gates the whole engine:
`repair` (default) applies rules and write-backs, `detect` only logs
what would change, and `off` restores legacy load behavior.
"""

import logging;
import os;
import threading;
import from collections.abc { Callable }
import from dataclasses { fields, is_dataclass }

glob logger = logging.getLogger(__name__),
     # Wire-format key for preserved (dropped/unknown) field values inside a
     # stored archetype dict, and the instance attribute it round-trips on.
     ATTIC_KEY: str = '__jac_attic__',
     # Instance attribute recording the repair steps applied during load, so
     # persistence backends can decide to write the repaired form back.
     REPAIRS_ATTR: str = '__jac_schema_repairs__',
     # Name of the static hook archetypes define to declare their rules.
     SCHEMA_HOOK: str = '__jac_schema__';

"""A field rename: documents stored under `stored_name` load as `new_name`."""
obj AliasRule {
    has new_name: str,
        stored_name: str;
}

"""A removed field whose stored remains are preserved in the attic.

`until` is reserved for the future contract lifecycle (the date after
which atticed values may be permanently removed); it is inert here.
"""
obj DropRule {
    has field_name: str,
        until: (str | None) = None;
}

"""An arbitrary dict -> dict transform, run when `when(doc)` is true.

Callbacks receive a copy of the raw stored archetype dict (including
`__type__` / `__module__` metadata keys) and must return the full
replacement dict. They must be idempotent: after a successful run the
`when` predicate should no longer match.
"""
obj UpgradeRule {
    has fn: Callable,
        when: (Callable | None) = None;
}

"""The collected drift rules of one defining class."""
obj SchemaRules {
    has owner: str,
        was_names: list[str] = [],
        aliases: list[AliasRule] = [],
        drops: list[DropRule] = [],
        upgrades: list[UpgradeRule] = [];

    def add_was(old_fqn: str) -> None;
    def add_alias(new_name: str, stored_name: str) -> None;
    def add_drop(field_name: str, until: (str | None) = None) -> None;
    def add_upgrade(fn: Callable, when: (Callable | None) = None) -> None;
    def is_empty -> bool;
}

# --- Ambient builders (only valid inside an executing __jac_schema__) --------
"""Declare that this archetype was previously `old_fqn` (module.ClassName)."""
def schema_was(old_fqn: str) -> None;

"""Declare that field `new_name` was previously stored as `stored`."""
def schema_alias(new_name: str, stored: str) -> None;

"""Declare that removed field `field_name` may still exist in stored docs."""
def schema_drop(field_name: str, until: (str | None) = None) -> None;

"""Declare an arbitrary upgrade callback, gated by an optional predicate."""
def schema_upgrade(fn: Callable, when: (Callable | None) = None) -> None;

# --- Collection / lookup ------------------------------------------------------
"""Execute `cls`'s own __jac_schema__ (if defined on the class itself, not
inherited) under a fresh collector; validate and cache the result. Called by
`Serializer.register` once per class creation. Returns None when the class
defines no schema hook."""
def collect_rules(cls: type) -> (SchemaRules | None);

"""MRO-merged field rules for `cls` (base-first order), cached per class.

Field-level rules (aliases, drops, upgrades) are inherited by subclasses —
they inherited the fields and therefore the fields' history. `was_names`
are definer-only and excluded: a subclass was never the renamed class.
Returns None when no class in the MRO declares rules."""
def merged_rules_for(cls: type) -> (SchemaRules | None);

"""Validate rules against the live dataclass fields of `cls`. Raises
ValueError at registration time (i.e. app startup) on contradictions:
an alias whose new field is not declared, an alias or drop naming a
still-declared field, or non-callable upgrade hooks."""
def validate_rules(rules: SchemaRules, cls: type) -> None;

# --- Repair engine -------------------------------------------------------------
"""Resolve the JAC_SCHEMA_REPAIR mode: 'repair' (default), 'detect', 'off'."""
def repair_mode -> str;

"""Apply `rules` to a raw stored archetype dict. Pure: returns a new
(repaired_dict, applied_step_descriptions) pair; `data` is not mutated
(the original object is returned when nothing changed).
Order: renames/shadow-strip, then upgrades, then drop-attic. Every step
is idempotent: a rename only fires when the old key is present and the
new one absent. When BOTH are present the doc is dual-written — an equal
shadow strips silently (changed data, no step, so no write-back churn);
a differing shadow loses to the new name and is atticed as
'shadow-conflict' (a recorded step). A failing upgrade callback is
logged and skipped — it never half-applies."""
def apply_rules(data: dict, rules: SchemaRules) -> tuple;

# --- Internal -------------------------------------------------------------------
def _require_collector -> SchemaRules;
def _owner_key(cls: type) -> str;
