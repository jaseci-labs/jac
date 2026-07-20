import os;
import sys;
import from jaclang.cli.command { ArgKind, CommandSpec }
import from jaclang.cli.manifest { CommandMeta }

def _discover_project_config {
    import from jaclang.jac0core.helpers { MalformedJacTomlError }

    try {
        import from jaclang.project.config { get_config }
        import from jaclang.project.pyvenv { add_venv_to_path }

        config = get_config();
        if config is not None {
            add_venv_to_path(config);
        }
    } except MalformedJacTomlError as exc {
        _exit_on_malformed_jac_toml(exc);
    } except Exception { }
}

def _exit_on_malformed_jac_toml(exc: any) {
    import from jaclang.cli.console { console }

    console.error(
        f"jac.toml is malformed: {exc.original}", hint=f"File: {exc.file_path}"
    );
    sys.exit(2);
}

def _initialize_provider_registry {
    try {
        import from jaclang.project.providers { initialize_provider_registry }
        initialize_provider_registry();
    } except Exception { }
}

def _initialize_template_registry {
    try {
        import from jaclang.project.template_registry { initialize_template_registry }
        initialize_template_registry();
    } except Exception { }
}

def _load_command_spec(command_name: str, meta: CommandMeta) -> CommandSpec {
    import importlib;
    import from jaclang.cli.registry { get_registry }

    importlib.import_module(meta.handler_module);
    spec = get_registry().get(command_name);
    if spec is None {
        raise KeyError(command_name);
    }
    return spec;
}

def _extract_script_args(spec: CommandSpec) -> list[str] {
    raw = sys.argv[1:];
    if len(raw) < 2 {
        return [];
    }

    all_args = spec.args;
    has_remainder = any(a.kind == ArgKind.REMAINDER for a in all_args);
    if not has_remainder {
        return [];
    }

    n_positionals = sum(
        1
        for a in all_args
        if a.kind == ArgKind.POSITIONAL
    );
    value_flags: set = set();
    for arg in all_args {
        if arg.kind in (ArgKind.POSITIONAL, ArgKind.MULTI, ArgKind.REMAINDER) {
            continue;
        }
        if arg.kind == ArgKind.FLAG or arg.typ == bool {
            continue;
        }
        value_flags.add(f"--{arg.name}");
        if arg.short {
            value_flags.add(f"-{arg.short}");
        }
    }

    i = 1;
    positionals_seen = 0;
    while i < len(raw) {
        token = raw[i];
        if token == '--' {
            script_args = raw[i + 1:];
            sys.argv = [sys.argv[0]] + raw[:i];
            return script_args;
        }
        if token.startswith('-') {
            i += 2 if token in value_flags else 1;
            continue;
        }
        positionals_seen += 1;
        if positionals_seen >= n_positionals {
            script_args = raw[i + 1:];
            if script_args and script_args[0] == '--' {
                script_args = script_args[1:];
            }
            sys.argv = [sys.argv[0]] + raw[:i + 1];
            return script_args;
        }
        i += 1;
    }
    return [];
}

def _apply_profile(args_dict: dict) {
    import from jaclang.cli.console { console }
    try {
        import from jaclang.project.config { get_config }

        config = get_config();
        if config is None {
            return;
        }

        profile = args_dict.pop('profile', None);
        if not profile {
            profile = os.environ.get('JAC_PROFILE');
        }
        if not profile {
            jac_env = os.environ.get('JAC_ENV');
            if jac_env {
                console.warning('JAC_ENV is deprecated, use JAC_PROFILE instead.');
                profile = jac_env;
            }
        }
        if not profile and config.environment.default_profile {
            profile = config.environment.default_profile;
        }

        config.apply_profile_overlay(profile or None);
        _apply_config_defaults(config, args_dict);
    } except (KeyError, ValueError, OSError) as exc {
        console.warning(f"Failed to apply profile: {exc}");
    }
}

def _apply_config_defaults(config: any, args_dict: dict) {
    bridges: list = [
        ('port', 8000, config.serve.port, 'serve', 'port'),
        ('cache', True, config.run.cache, 'run', 'cache'),
        ('main', True, config.run.main, 'run', 'main'),
        ('verbose', False, config.test.verbose, 'test', 'verbose'),
        ('autonative', False, config.run.autonative, 'run', 'autonative')
    ];
    for (arg_name, arg_default, config_value, section, key) in bridges {
        if arg_name not in args_dict {
            continue;
        }
        if args_dict[arg_name] != arg_default {
            continue;
        }
        raw = config._raw_data.get(section, {});
        if isinstance(raw, dict) and key in raw {
            args_dict[arg_name] = config_value;
        }
    }
}

def _requests_help(cmd_argv: list[str]) -> bool {
    for tok in cmd_argv {
        if tok == '--' {
            return False;
        }
        if tok in ('-h', '--help') {
            return True;
        }
    }
    return False;
}

def _command_argv(command_name: str) -> list[str] {
    return (
        sys.argv[2:]
            if len(sys.argv) > 1 and sys.argv[1] == command_name
            else sys.argv[1:]
    );
}

impl run_selected_command(command_name: str) -> None {
    import from jaclang.cli.manifest { get_command_meta }
    import from jaclang.cli.registry { get_registry }

    meta = get_command_meta(command_name);
    if meta is None {
        sys.stderr.write(f"Unknown command: {command_name}\n");
        raise SystemExit(2);
    }

    spec = _load_command_spec(command_name, meta);
    parser = get_registry().build_command_parser(spec);

    if _requests_help(_command_argv(command_name)) {
        parser.parse_known_args(_command_argv(command_name));
    }

    import from jaclang.cli.console { console }
    import from jaclang.cli.executor { get_executor }

    _discover_project_config();
    if 'templates' in meta.needs {
        _initialize_template_registry();
    }
    if 'providers' in meta.needs {
        _initialize_provider_registry();
    }
    if 'client' in meta.needs {
        import jaclang.runtimelib.client.cli;
    }

    script_args = _extract_script_args(spec);

    cmd_argv = _command_argv(command_name);
    (args, unknown) = parser.parse_known_args(cmd_argv);
    if unknown {
        if command_name == 'test' and any(not u.startswith('-') for u in unknown) {
            console.error(
                f"unrecognized arguments: {' '.join(unknown)}\n"
                "hint: use quotes for multi-word test names:\n"
                '  jac test <file.jac> --test_name "my test name"\n'
                '  jac test <file.jac> --test_name my_test_name'
            );
        } else {
            parser.error(f"unrecognized arguments: {' '.join(unknown)}");
        }
        raise SystemExit(2);
    }

    args_dict = vars(args);
    if script_args {
        args_dict['args'] = script_args;
    }
    _apply_profile(args_dict);

    result = get_executor().execute(spec, args_dict);
    if result.error {
        console.error(f"{result.error}");
    }
    if result.return_code != 0 {
        raise SystemExit(result.return_code);
    }
}
