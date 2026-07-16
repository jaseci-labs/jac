"""Parity between manifest metadata and legacy registry CommandSpec values."""

import from jaclang.cli.registry { get_registry, register_feature_commands }
import from jaclang.cli.command { CommandSpec }
import from jaclang.cli.registry_adapter { manifest_to_spec }
import from jaclang.cli.manifest { iter_command_meta, validate_manifest }
import jaclang.cli.commands;


def _registry_specs -> dict[str, CommandSpec] {
    register_feature_commands();
    reg = get_registry();
    return {spec.name: spec for spec in reg.get_all(include_hidden=True)};
}


test "manifest validates" {
    errors = validate_manifest();
    assert not errors , f"manifest validation failed: {errors}";
}

test "manifest matches registry metadata" {
    register_feature_commands();
    registry = _registry_specs();
    for meta in iter_command_meta(include_hidden=True) {
        reg_spec = registry.get(meta.name);
        assert reg_spec is not None , f"missing registry spec for {meta.name}";
        assert reg_spec.help == meta.help;
        assert reg_spec.description == meta.description;
        assert reg_spec.group == meta.group;
        assert reg_spec.tier == meta.tier;
        assert reg_spec.hidden == meta.hidden;
        assert len(reg_spec.args) == len(meta.args);
    }
}

test "manifest adapter handlers match registry" {
    registry = _registry_specs();
    for meta in iter_command_meta(include_hidden=True) {
        reg_spec = registry[meta.name];
        adapted = manifest_to_spec(meta);
        assert adapted.name == reg_spec.name;
        assert adapted.help == reg_spec.help;
        assert reg_spec.handler is not None;
        assert adapted.handler is reg_spec.handler;
    }
}
