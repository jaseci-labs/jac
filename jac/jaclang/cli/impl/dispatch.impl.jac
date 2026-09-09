import os;
import sys;
import from jaclang.cli.command { Arg, ArgKind, CommandSpec, arg_consumes_value }

def _discover_project_config {
    import from jaclang.project.tomlio { MalformedJacTomlError }

    try {
        import from jaclang.project.config { get_config }
        import from jaclang.project.pyvenv { add_venv_to_path }

        config = get_config();
        if config is not None {
            add_venv_to_path(config);
        }
    } except MalformedJacTomlError as exc {
        _exit_on_malformed_jac_toml(exc);
    } except ValueError as exc {
        _exit_on_invalid_jac_toml(exc);
    } except Exception {}
}

def _exit_on_invalid_jac_toml(exc: any) {
    import from jaclang.cli.console { console }

    console.error(f"jac.toml is invalid: {exc}");
    sys.`exit(2);
}

def _exit_on_malformed_jac_toml(exc: any) {
    import from jaclang.cli.console { console }

    console.error(
        f"jac.toml is malformed: {exc.original}", hint=f"File: {exc.file_path}"
    );
    sys.`exit(2);
}

impl split_remainder_argv(
    raw: list[str], meta: CommandSpec
) -> tuple[list[str], list[str]] | None {
    if len(raw) < 2 {
        return None;
    }

    all_args = meta.args;
    has_remainder = any(a.kind == ArgKind.REMAINDER for a in all_args);
    if not has_remainder {
        return None;
    }

    n_positionals = sum(
        1
        for a in all_args
        if a.kind == ArgKind.POSITIONAL
    );
    value_flags: set = set();
    for arg in all_args {
        if not arg_consumes_value(arg.kind, arg.typ) {
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
            return (raw[:i], raw[i + 1:]);
        }
        if token.startswith('-') {
            if '=' in token {
                i += 1;
            } else {
                i += 2 if token in value_flags else 1;
            }
            continue;
        }
        positionals_seen += 1;
        if positionals_seen >= n_positionals {
            script_args = raw[i + 1:];
            if script_args and script_args[0] == '--' {
                script_args = script_args[1:];
            }
            return (raw[:i + 1], script_args);
        }
        i += 1;
    }
    return None;
}

def _extract_script_args(meta: CommandSpec) -> list[str] {
    raw = sys.argv[1:];
    split = split_remainder_argv(raw, meta);
    if split is None {
        return [];
    }
    (trimmed, script_args) = split;
    sys.argv = [sys.argv[0]] + trimmed;
    return script_args;
}

def _apply_profile(meta: CommandSpec, args_dict: dict) {
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
        if not profile and config.environment.default_profile {
            profile = config.environment.default_profile;
        }

        config.apply_profile_overlay(profile or None);
        _apply_config_defaults(
            _command_config(config, meta, args_dict), meta, args_dict
        );
    } except (KeyError, ValueError, OSError) as exc {
        console.warning(f"Failed to apply profile: {exc}");
    }
}

def _arg_dict_key(arg: Arg) -> str {
    if arg.dest {
        return arg.dest;
    }
    return arg.name.replace("-", "_");
}

def _target_app_name(config: any, target: any) -> str {
    if not isinstance(target, str) {
        return "";
    }
    if target in config.apps {
        return target;
    }
    if target == "" {
        try {
            name = config.resolve_app("").name;
        } except ValueError {
            return "";
        }
        return name if name in config.apps else "";
    }
    app = config.app_for_path(os.path.abspath(target));
    return app.name if app is not None else "";
}

def _command_config(config: any, meta: CommandSpec, args_dict: dict) -> any {
    for arg in meta.args {
        if arg.kind != ArgKind.POSITIONAL or arg.name != "target" {
            continue;
        }
        try {
            app_name = _target_app_name(config, args_dict.get(_arg_dict_key(arg)));
            if app_name {
                return config.effective_for_app(app_name);
            }
        } except Exception {}
        return config;
    }
    return config;
}

def _config_value(config: any, config_key: str) -> tuple[str, str, any] | None {
    dot = config_key.find(".");
    if dot < 0 {
        return None;
    }
    section = config_key[:dot];
    key = config_key[dot + 1:];
    section_obj = getattr(config, section, None);
    if section_obj is None {
        return None;
    }
    return (section, key, getattr(section_obj, key, None));
}

def _apply_config_defaults(config: any, meta: CommandSpec, args_dict: dict) {
    for arg in meta.args {
        if not arg.config_key {
            continue;
        }
        resolved = _config_value(config, arg.config_key);
        if resolved is None {
            continue;
        }
        (section, key, config_value) = resolved;
        dict_key = _arg_dict_key(arg);
        if dict_key not in args_dict {
            continue;
        }
        if args_dict[dict_key] != arg.`default {
            continue;
        }
        raw = config._raw_data.get(section, {});
        if isinstance(raw, dict) and key in raw {
            args_dict[dict_key] = config_value;
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

def _exit_now(code: int) -> None {
    if os.environ.get('JAC_SLOW_EXIT') {
        if code != 0 {
            raise SystemExit(code);
        }
        return;
    }
    import atexit;
    try {
        atexit._run_exitfuncs();
    } except Exception {}
    try {
        sys.stdout.flush();
        sys.stderr.flush();
    } except Exception {}
    os._exit(code);
}


impl run_selected_command(command_name: str) -> None {
    import from jaclang.cli.manifest { get_command_meta }
    import from jaclang.cli.manifest_parse { build_command_parser }

    meta = get_command_meta(command_name);
    if meta is None {
        sys.stderr.write(f"Unknown command: {command_name}\n");
        raise SystemExit(2);
    }

    parser = build_command_parser(meta);
    cmd_argv = _command_argv(command_name);

    if _requests_help(cmd_argv) {
        parser.parse_known_args(cmd_argv);
        return;
    }

    import from jaclang.cli.console { console }
    import from jaclang.cli.executor { get_executor }
    import from jaclang.cli.loader { load_handler }

    _discover_project_config();

    script_args = _extract_script_args(meta);
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
    _apply_profile(meta, args_dict);

    handler = load_handler(command_name);
    spec = CommandSpec(name=meta.name, help=meta.help, handler=handler);
    result = get_executor().execute(spec, args_dict);
    if result.error {
        console.error(f"{result.error}");
    }
    _exit_now(result.return_code);
}
