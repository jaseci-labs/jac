"""Guardrails for the #7255 CLI surface.

The clean break holds only if it cannot silently regrow:

  1. The visible verb count stays within the budget; adding a verb means
     removing one (or deliberately raising the budget here, in review).
  2. Tombstoned verbs stay unregistered; the tombstone table is authoritative.

Built-in features (client/scale/shadcn/byllm) are folded into core: they add
flags to existing verbs and contribute at most one top-level verb each
(setup / scale / retheme / model), all registered through the same
`@registry.command` path as core.
"""

import from jaclang.cli.registry { get_registry, register_feature_commands }
import from jaclang.cli.cli { TOMBSTONED_VERBS }
import jaclang.cli.commands;

glob VERB_BUDGET: int = 28;

def _all_specs(include_hidden: bool = False) -> list {
    register_feature_commands();
    return get_registry().get_all(include_hidden=include_hidden);
}

test "visible verbs stay within the budget" {
    verbs = sorted([s.name for s in _all_specs()]);
    assert len(verbs) <= VERB_BUDGET , f"{len(
        verbs
    )} visible verbs exceed the budget of {VERB_BUDGET}: {verbs}. "
    "Fold the new capability into an existing verb, or remove one.";
}

test "tombstoned verbs stay unregistered" {
    names = {s.name for s in _all_specs(include_hidden=True)};
    revived = sorted(
        [
            v
            for v in TOMBSTONED_VERBS.keys()
            if v in names
        ]
    );
    assert not revived , f"tombstoned verb(s) re-registered: {revived}";
}
