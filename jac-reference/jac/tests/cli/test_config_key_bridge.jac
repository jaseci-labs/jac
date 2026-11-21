"""Guard for Arg.config_key jac.toml bridges.

Each CLI flag that falls back to jac.toml when left at its argparse default
must declare ``config_key="section.key"`` on its ``Arg.create`` call. Dispatch
reads those keys at runtime instead of a hand-maintained bridge table.
"""

import from jaclang.cli.manifest { get_command_meta }

glob _EXPECTED_CONFIG_KEYS: list[tuple[str, str, str]] = [
         ("run", "cache", "run.cache"),
         ("run", "main", "run.main"),
         ("run", "port", "serve.port"),
         ("test", "verbose", "test.verbose"),

     ];


test "config_key bridges are declared on command args" {
    for (command_name, arg_name, expected_config_key) in _EXPECTED_CONFIG_KEYS {
        spec = get_command_meta(command_name);
        assert spec is not None , f"missing command spec: {command_name}";
        by_name = {arg.name: arg for arg in spec.args};
        arg = by_name.get(arg_name);
        assert arg is not None , (f"{command_name} is missing arg {arg_name!r}");
        assert arg.config_key == expected_config_key , (
            f"{command_name}.{arg_name} config_key={arg.config_key!r}, "
            f"expected {expected_config_key!r}"
        );
    }
}
