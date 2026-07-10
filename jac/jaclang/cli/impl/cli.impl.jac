import os;
import sys;
import from importlib.metadata { version as pkg_version }
import from pathlib { Path }

glob TOMBSTONED_VERBS: dict[str, str] = {
         "format": "jac fmt",
         "lint": "jac check --lint",
         "deps": "jac install --plan",
         "script": "jac x <name>",
         "jacpack": "jac create --pack <dir>",
         "enter": "jac run --entry <name> <file>",
         "debug": "jac run --debug <file>",
         "bundle": "jac build [--as jab|sealed|binary|wheel|npm]",
         "eject": "jac build --as source",
         "js": "jac tool jac2js <file>",
         "jac2py": "jac tool jac2py <file>",
         "py2jac": "jac tool py2jac <file>",
         "jac2js": "jac tool jac2js <file>",
         "grammar": "jac tool grammar",
         "destroy": "jac scale destroy <file.jac>",
         "status": "jac scale status <file.jac>"
     };

impl start_cli -> None {
    import from jaclang.cli.registry { get_registry, register_feature_commands }
    import from jaclang.cli.executor { get_executor }
    import from jaclang.cli.help { get_help_formatter }
    import from jaclang.cli.console { console }

    dev_source = os.environ.get('JAC_DEV_SOURCE');
    if dev_source {
        notice = (
            f"🛠  jac dev mode — using compiler source at {dev_source}"
                if console.use_emoji
                else f"[dev] jac dev mode - using compiler source at {dev_source}"
        );
        console.print(notice, style='info', file=sys.stderr);
    }

    _load_project_config();

    register_feature_commands();

    registry = get_registry();
    parser = registry.finalize();

    raw_argv = sys.argv[1:];
    if raw_argv
    and raw_argv[0] in TOMBSTONED_VERBS
    and raw_argv[0] not in registry.commands {
        console.error(
            f"'jac {raw_argv[0]}' was removed in the CLI cleanup (#7255); "
            f"use: {TOMBSTONED_VERBS[raw_argv[0]]}"
        );
        sys.exit(2);
    }
    has_jac_file = any(
        not tok.startswith('-') and tok.lower().endswith(('.jac', '.py', '.jab'))
        for tok in raw_argv
    );
    if has_jac_file and (not raw_argv or raw_argv[0] not in registry.commands) {
        sys.argv = [sys.argv[0], 'run'] + raw_argv;
    }

    script_args = _extract_script_args(registry);

    (args, unknown) = parser.parse_known_args();
    if unknown {
        cmd = sys.argv[1] if len(sys.argv) > 1 else '';
        if cmd == 'test' and any(not u.startswith('-') for u in unknown) {
            console.error(
                f"unrecognized arguments: {' '.join(unknown)}\n"
                "hint: use quotes for multi-word test names:\n"
                "  jac test <file.jac> --test_name \"my test name\"\n"
                "  jac test <file.jac> --test_name my_test_name"
            );
        } else {
            parser.error(f"unrecognized arguments: {' '.join(unknown)}");
        }
        sys.exit(2);
    }

    if args.version {
        import from jaclang.cli.banners { print_version_banner }
        print_version_banner(jac_version());
        return;
    }

    if args.help {
        formatter = get_help_formatter();
        help_text = formatter.format_main_help(
            registry.get_all(), prog="jac", version=jac_version(), verbose=True
        );
        console.print(help_text);
        return;
    }

    if (args.command is None) {
        import from jaclang.cli.banners { print_logo }
        formatter = get_help_formatter();
        print_logo(jac_version());
        console.print("");
        help_text = formatter.format_main_help(
            registry.get_all(), prog="jac", version=jac_version()
        );
        console.print(help_text);
        return;
    }

    command_spec = registry.get(args.command);
    if not command_spec {
        console.error(f"Unknown command: {args.command}");
        parser.print_help();
        return;
    }

    args_dict = vars(args);
    args_dict.pop('command');
    args_dict.pop('version', None);
    args_dict.pop('help', None);

    if script_args {
        args_dict['args'] = script_args;
    }
    _apply_profile(args_dict);

    executor = get_executor();
    result = executor.execute(command_spec, args_dict);

    if result.error {
        console.error(f"{result.error}");
    }
    if result.return_code != 0 {
        sys.exit(result.return_code);
    }
}

impl jac_version -> str {
    import from jaclang.project.config { JacConfig }

    dev_source = os.environ.get('JAC_DEV_SOURCE');
    if dev_source {
        toml_path = Path(dev_source) / 'jac.toml';
        if toml_path.exists() {
            try {
                return JacConfig.load(toml_path).project.version;
            } except Exception { }
        }
    }
    return pkg_version('jaclang');
}

def _extract_script_args(registry: object) -> list {
    import from jaclang.cli.command { ArgKind }

    raw = sys.argv[1:];
    if len(raw) < 2 {
        return [];
    }

    cmd_name = raw[0];
    spec = registry.get(cmd_name);
    if spec is None {
        return [];
    }

    all_args = spec.get_all_args();
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
            if token in value_flags {
                i += 2;
            } else {
                i += 1;
            }
        } else {
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
    }

    return [];
}

def _load_project_config {
    import from jaclang.jac0core.helpers { MalformedJacTomlError }
    try {
        import from jaclang.project.config { get_config, set_config }
        import from jaclang.project.pyvenv { add_venv_to_path }

        config = get_config();
        if config is not None {
            add_venv_to_path(config);
        }

        _initialize_provider_registry();

        _initialize_template_registry();
    } except MalformedJacTomlError as exc {
        _exit_on_malformed_jac_toml(exc);
    } except Exception { }
}


def _exit_on_malformed_jac_toml(exc: 'Any') {
    import sys;
    sys.stderr.write(
        f"\n\033[31mERROR: jac.toml is malformed: {exc.original}\033[0m\n"
        f"  File: {exc.file_path}\n"
        "  Fix the syntax error in jac.toml and re-run.\n"
        "  Common causes: missing closing quote, unbalanced brackets, "
        "trailing comma, missing `=`.\n\n"
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

def _apply_profile(args_dict: dict) -> None {
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
                console.print(
                    "Warning: JAC_ENV is deprecated, use JAC_PROFILE instead.",
                    style="warning"
                );
                profile = jac_env;
            }
        }
        if not profile and config.environment.default_profile {
            profile = config.environment.default_profile;
        }

        config.apply_profile_overlay(profile or None);

        _apply_config_defaults(config, args_dict);
    } except (KeyError, ValueError, OSError) as e {
        console.print(f"Warning: Failed to apply profile: {e}", style="warning");
    }
}

def _apply_config_defaults(config: object, args_dict: dict) {
    bridges: list = [
        ("port", 8000, config.serve.port, "serve", "port"),
        ("cache", True, config.run.cache, "run", "cache"),
        ("main", True, config.run.main, "run", "main"),
        ("verbose", False, config.test.verbose, "test", "verbose"),
        ("autonative", False, config.run.autonative, "run", "autonative"),

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
