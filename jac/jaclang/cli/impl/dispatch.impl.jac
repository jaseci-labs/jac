import os;
import sys;
import argparse;
import from jaclang.cli.command { ArgKind }
import from jaclang.cli.manifest { ArgMeta, CommandMeta }

def _load_project_config {
    try {
        import from jaclang.jac0core.helpers { MalformedJacTomlError }
    } except Exception {
        return;
    }

    try {
        import from jaclang.project.config { get_config }
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

def _exit_on_malformed_jac_toml(exc: object) {
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

def _add_argument(parser: argparse.ArgumentParser, arg: ArgMeta) {
    kwargs: dict = {'help': arg.help};
    if arg.choices {
        kwargs['choices'] = list(arg.choices);
    }
    if arg.metavar {
        kwargs['metavar'] = arg.metavar;
    }
    if arg.dest {
        kwargs['dest'] = arg.dest;
    }

    if arg.kind == ArgKind.POSITIONAL {
        if arg.default is not None {
            kwargs['nargs'] = '?';
            kwargs['default'] = arg.default;
        }
        parser.add_argument(arg.name, **kwargs);
    } elif arg.kind == ArgKind.MULTI {
        if arg.name in ('paths', 'packages', 'names') {
            kwargs['nargs'] = '+' if arg.default is None else '*';
            if arg.default is not None {
                kwargs['default'] = arg.default;
            }
            parser.add_argument(arg.name, **kwargs);
        } else {
            kwargs['nargs'] = '*';
            if arg.default is not None {
                kwargs['default'] = arg.default;
            }
            if arg.short {
                parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
            } else {
                parser.add_argument(f"--{arg.name}", **kwargs);
            }
        }
    } elif arg.kind == ArgKind.APPEND {
        kwargs['action'] = 'append';
        kwargs['nargs'] = '+';
        kwargs['default'] = None;
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
    } elif arg.kind == ArgKind.REMAINDER {
        kwargs['nargs'] = argparse.REMAINDER;
        parser.add_argument(arg.name, **kwargs);
    } elif arg.kind == ArgKind.FLAG or arg.typ == 'bool' {
        kwargs['action'] = 'store_true';
        kwargs['default'] = arg.default if arg.default is not None else False;
        shared_dest = kwargs.get('dest') or arg.name.replace('-', '_');
        kwargs['dest'] = shared_dest;
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
        parser.add_argument(
            f"--no-{arg.name}",
            action='store_false',
            dest=shared_dest,
            help=f"Disable {arg.name}"
        );
    } else {
        typ = int if arg.typ == 'int' else str;
        kwargs['type'] = typ;
        kwargs['default'] = arg.default;
        if arg.required {
            kwargs['required'] = True;
        }
        if arg.short {
            parser.add_argument(f"-{arg.short}", f"--{arg.name}", **kwargs);
        } else {
            parser.add_argument(f"--{arg.name}", **kwargs);
        }
    }
}

def _build_command_parser(meta: CommandMeta) -> argparse.ArgumentParser {
    description = meta.description or meta.help;
    if meta.examples {
        description += "\n\nExamples:\n";
        for (cmd, desc) in meta.examples {
            description += f"  {cmd}\n";
            if desc {
                description += f"      {desc}\n";
            }
        }
    }

    parser = argparse.ArgumentParser(
        prog=f"jac {meta.name}",
        description=description,
        formatter_class=argparse.RawDescriptionHelpFormatter,
        add_help=True
    );
    for arg in meta.args {
        _add_argument(parser, arg);
    }
    return parser;
}

def _extract_script_args(meta: CommandMeta) -> list[str] {
    raw = sys.argv[1:];
    if len(raw) < 2 {
        return [];
    }

    all_args = meta.args;
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
        if arg.kind == ArgKind.FLAG or arg.typ == 'bool' {
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

def _apply_config_defaults(config: object, args_dict: dict) {
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

impl run_selected_command(command_name: str) -> None {
    import from jaclang.cli.manifest { get_command_meta }

    meta = get_command_meta(command_name);
    if meta is None {
        sys.stderr.write(f"Unknown command: {command_name}\n");
        raise SystemExit(2);
    }

    parser = _build_command_parser(meta);
    cmd_argv = (
        sys.argv[2:]
            if len(sys.argv) > 1 and sys.argv[1] == command_name
            else sys.argv[1:]
    );

    if _requests_help(cmd_argv) {
        parser.parse_known_args(cmd_argv);
    }

    import from jaclang.cli.console { console }
    import from jaclang.cli.loader { load_handler }
    import from jaclang.cli.registry_adapter { manifest_to_spec }
    import from jaclang.cli.executor { get_executor }

    _load_project_config();

    if command_name in ('build', 'start', 'setup') {
        import jaclang.runtimelib.client.cli;
    }

    handler = load_handler(command_name);
    spec = manifest_to_spec(meta, handler);
    script_args = _extract_script_args(meta);

    cmd_argv = (
        sys.argv[2:]
            if len(sys.argv) > 1 and sys.argv[1] == command_name
            else sys.argv[1:]
    );
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
