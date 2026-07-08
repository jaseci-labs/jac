"""Guardrails for the #7255 CLI surface.

The clean break holds only if it cannot silently regrow:

  1. The visible core verb count stays within the budget — adding a verb
     means removing one (or deliberately raising the budget here, in review).
  2. Tombstoned verbs stay unregistered; the tombstone table is authoritative.
  3. A plugin contributes at most ONE visible top-level noun; everything else
     it ships must be a subcommand/extension of an existing verb.
"""

import from jaclang.jac0core.runtime { JacRuntime as Jac }
import from jaclang.cli.registry { get_registry }
import from jaclang.cli.cli { TOMBSTONED_VERBS }
import jaclang.cli.commands;

glob VERB_BUDGET: int = 24;

def _all_specs(include_hidden: bool = False) -> list {
    Jac.create_cmd();
    return get_registry().get_all(include_hidden=include_hidden);
}

test "visible core verbs stay within the budget" {
    core = sorted(
        [
            s.name
            for s in _all_specs()
            if s.source == "jaclang"
        ]
    );
    assert len(core) <= VERB_BUDGET , f"{len(
        core
    )} visible core verbs exceed the budget of {VERB_BUDGET}: {core}. "
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

test "plugins register at most one visible top-level noun" {
    by_source: dict[str, list[str]] = {};
    for s in _all_specs() {
        if s.source != "jaclang" {
            by_source.setdefault(s.source, []).append(s.name);
        }
    }
    offenders = {
        src: sorted(names)
        for (src, names) in by_source.items()
        if len(names) > 1
    };
    assert not offenders , f"plugins must register exactly one visible top-level noun: {offenders}";
}
