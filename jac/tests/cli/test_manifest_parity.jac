"""Parity between manifest metadata and legacy registry CommandSpec values."""

import from jaclang.cli.command { Arg, CommandSpec }
import from jaclang.cli.registry { get_registry, register_feature_commands }
import from jaclang.cli.registry_adapter { manifest_to_spec }
import from jaclang.cli.manifest { ArgMeta, iter_command_meta, validate_manifest }
import jaclang.cli.commands;


def _registry_specs -> dict[str, CommandSpec] {
    register_feature_commands();
    reg = get_registry();
    return {spec.name: spec for spec in reg.get_all(include_hidden=True)};
}

def _typ_name(arg: Arg) -> str {
    # Registry stores the type object (str/int/bool); the manifest stores its
    # name. Normalize the registry side so the two compare equal.
    t = arg.typ;
    return getattr(t, "__name__", str(t));
}

def _assert_arg_parity(cmd: str, idx: int, reg_arg: Arg, meta_arg: ArgMeta) {
    label = f"{cmd} arg[{idx}] '{reg_arg.name}'";
    assert reg_arg.name == meta_arg.name , f"{label}: name registry={reg_arg.name!r} manifest={meta_arg.name!r}";
    assert reg_arg.kind == meta_arg.kind , f"{label}: kind registry={reg_arg.kind!r} manifest={meta_arg.kind!r}";
    assert _typ_name(reg_arg) == meta_arg.typ , f"{label}: typ registry={_typ_name(
        reg_arg
    )!r} manifest={meta_arg.typ!r}";
    assert reg_arg.`default == meta_arg.`default , f"{label}: default registry={reg_arg.`default!r} manifest={meta_arg.`default!r}";
    assert reg_arg.help == meta_arg.help , f"{label}: help registry={reg_arg.help!r} manifest={meta_arg.help!r}";
    assert reg_arg.short == meta_arg.short , f"{label}: short registry={reg_arg.short!r} manifest={meta_arg.short!r}";
    assert reg_arg.choices == meta_arg.choices , f"{label}: choices registry={reg_arg.choices!r} manifest={meta_arg.choices!r}";
    assert reg_arg.required == meta_arg.required , f"{label}: required registry={reg_arg.required!r} manifest={meta_arg.required!r}";
    assert reg_arg.dest == meta_arg.dest , f"{label}: dest registry={reg_arg.dest!r} manifest={meta_arg.dest!r}";
    assert reg_arg.metavar == meta_arg.metavar , f"{label}: metavar registry={reg_arg.metavar!r} manifest={meta_arg.metavar!r}";
}

test "manifest validates" {
    errors = validate_manifest();
    assert not errors , f"manifest validation failed: {errors}";
}

test "manifest matches registry metadata" {
    registry = _registry_specs();
    metas = iter_command_meta(include_hidden=True);

    # The manifest and registry must agree on the full command set in both
    # directions: a registered command missing from the manifest (or a stale
    # manifest entry with no registry backing) is routing drift.
    reg_names = set(registry.keys());
    meta_names = {m.name for m in metas};
    assert reg_names == meta_names , (
        "command set mismatch: "
        f"only in registry={sorted(reg_names - meta_names)}, "
        f"only in manifest={sorted(meta_names - reg_names)}"
    );

    for meta in metas {
        reg_spec = registry[meta.name];

        # Top-level user-visible command fields.
        assert reg_spec.help == meta.help , f"{meta.name}: help registry={reg_spec.help!r} manifest={meta.help!r}";
        assert reg_spec.description == meta.description , f"{meta.name}: description registry={reg_spec.description!r} manifest={meta.description!r}";
        assert reg_spec.group == meta.group , f"{meta.name}: group registry={reg_spec.group!r} manifest={meta.group!r}";
        assert reg_spec.tier == meta.tier , f"{meta.name}: tier registry={reg_spec.tier!r} manifest={meta.tier!r}";
        assert reg_spec.hidden == meta.hidden , f"{meta.name}: hidden registry={reg_spec.hidden!r} manifest={meta.hidden!r}";
        assert list(reg_spec.examples) == list(meta.examples) , f"{meta.name}: examples registry={reg_spec.examples!r} manifest={meta.examples!r}";

        # Handler references drive lazy dispatch; guard module + qualified name.
        h = reg_spec.handler;
        assert h is not None , f"{meta.name}: registry handler missing";
        assert h.__module__ == meta.handler_module , f"{meta.name}: handler_module registry={h.__module__!r} manifest={meta.handler_module!r}";
        assert h.__name__ == meta.handler_name , f"{meta.name}: handler_name registry={h.__name__!r} manifest={meta.handler_name!r}";

        # Argument list must match field-for-field, not only in length.
        assert len(reg_spec.args) == len(meta.args) , f"{meta.name}: arg count registry={len(
            reg_spec.args
        )} manifest={len(meta.args)}";
        for i in range(len(reg_spec.args)) {
            _assert_arg_parity(meta.name, i, reg_spec.args[i], meta.args[i]);
        }
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
