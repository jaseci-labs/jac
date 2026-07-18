"""Drift guard between the hand-authored route table and the live registry.

The compact route table in ``jaclang.cli.manifest`` carries only routing/help
fields; the full argument surface lives with the ``@registry.command``
decorators. These tests import every command module (build-time full
registration) and assert the route table agrees with the registry on the
command set and every routing field, so a decorator change without a matching
route row (or vice versa) fails CI.
"""

import from jaclang.cli.command { CommandSpec }
import from jaclang.cli.registry {
    get_registry,
    register_core_commands,
    register_feature_commands
}
import from jaclang.cli.manifest { iter_command_meta, validate_manifest }


def _registry_specs -> dict[str, CommandSpec] {
    register_core_commands();
    register_feature_commands();
    reg = get_registry();
    return {spec.name: spec for spec in reg.get_all(include_hidden=True)};
}

test "manifest validates" {
    errors = validate_manifest();
    assert not errors , f"manifest validation failed: {errors}";
}

test "route table matches registry" {
    registry = _registry_specs();
    metas = iter_command_meta(include_hidden=True);

    # The route table and registry must agree on the full command set in both
    # directions: a registered command missing from the table (or a stale table
    # row with no registry backing) is routing drift.
    reg_names = set(registry.keys());
    meta_names = {m.name for m in metas};
    assert reg_names == meta_names , (
        "command set mismatch: "
        f"only in registry={sorted(reg_names - meta_names)}, "
        f"only in route table={sorted(meta_names - reg_names)}"
    );

    for meta in metas {
        reg_spec = registry[meta.name];

        # Top-level user-visible routing fields must match the decorator.
        assert reg_spec.help == meta.help , f"{meta.name}: help registry={reg_spec.help!r} table={meta.help!r}";
        assert reg_spec.group == meta.group , f"{meta.name}: group registry={reg_spec.group!r} table={meta.group!r}";
        assert reg_spec.tier == meta.tier , f"{meta.name}: tier registry={reg_spec.tier!r} table={meta.tier!r}";
        assert reg_spec.hidden == meta.hidden , f"{meta.name}: hidden registry={reg_spec.hidden!r} table={meta.hidden!r}";

        # Handler references drive lazy dispatch; guard module + qualified name.
        h = reg_spec.handler;
        assert h is not None , f"{meta.name}: registry handler missing";
        assert h.__module__ == meta.handler_module , f"{meta.name}: handler_module registry={h.__module__!r} table={meta.handler_module!r}";
        assert h.__name__ == meta.handler_name , f"{meta.name}: handler_name registry={h.__name__!r} table={meta.handler_name!r}";
    }
}
