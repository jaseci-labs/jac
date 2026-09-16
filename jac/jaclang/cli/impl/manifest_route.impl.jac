impl resolve_cli_version -> str {
    import from jaclang.cli.version_info { resolve_cli_version as _resolve }

    return _resolve(os.environ.get('JAC_DEV_SOURCE'));
}

def _first_command_token(raw_argv: list[str]) -> (str | None) {
    for tok in raw_argv {
        if not tok.startswith('-') {
            return tok;
        }
    }
    return None;
}

def _looks_like_script_token(tok: str) -> bool {
    return (not tok.startswith('-') and tok.lower().endswith(('.jac', '.py', '.jab')));
}

def _workspace_app_names -> set[str] {
    cwd = Path.cwd();
    for d in [cwd] + list(cwd.parents) {
        toml_path = d / 'jac.toml';
        if not toml_path.is_file() {
            continue;
        }
        try {
            apps = tomllib.loads(toml_path.read_text(encoding='utf-8')).get('apps');
        } except Exception {
            return set();
        }
        return set(apps.keys()) if isinstance(apps, dict) else set();
    }
    return set();
}

def _write_stdout(text: str) {
    sys.stdout.write(text);
    if not text.endswith('\n') {
        sys.stdout.write('\n');
    }
}

def _print_error(message: str) {
    sys.stderr.write(f"error: {message}\n");
}

def _render_version_line -> str {
    import from jaclang.cli.version_info { render_version_line }

    return render_version_line(resolve_cli_version());
}

impl handle_manifest_route(raw_argv: list[str]) -> None {
    import from jaclang.cli.manifest { TOMBSTONED_VERBS, known_command_names }
    import from jaclang.cli.manifest_help {
        format_curated_help,
        format_logo,
        format_verbose_help
    }

    if raw_argv in (['-V'], ['--version']) {
        _write_stdout(_render_version_line());
        return;
    }

    if raw_argv in (['-h'], ['--help']) {
        _write_stdout(format_verbose_help());
        return;
    }

    if not raw_argv {
        ver = resolve_cli_version();
        _write_stdout(format_logo(ver));
        _write_stdout('');
        _write_stdout(format_curated_help());
        return;
    }

    first = _first_command_token(raw_argv);
    if first is None {
        if '-h' in raw_argv or '--help' in raw_argv {
            _write_stdout(format_verbose_help());
            return;
        }
        if '-V' in raw_argv or '--version' in raw_argv {
            _write_stdout(_render_version_line());
            return;
        }
        sys.stderr.write('usage: jac [-h] [-V] COMMAND ...\n');
        _print_error(f"unrecognized arguments: {' '.join(raw_argv)}");
        sys.`exit(2);
    }

    assert first is not None;

    dispatchable = known_command_names(include_hidden=True);
    visible = known_command_names();

    if first in TOMBSTONED_VERBS and first not in dispatchable {
        _print_error(
            f"'jac {first}' was removed in the CLI cleanup (#7255); "
            f"use: {TOMBSTONED_VERBS[first]}"
        );
        sys.`exit(2);
    }

    if first in dispatchable {
        command_name = first;
    } elif _looks_like_script_token(first) or first in _workspace_app_names() {
        sys.argv = [sys.argv[0], 'run'] + raw_argv;
        command_name = 'run';
    } else {
        choices = "', '".join(sorted(visible));
        sys.stderr.write('usage: jac [-h] [-V] COMMAND ...\n');
        _print_error(
            f"argument COMMAND: invalid choice: {first!r} (choose from '{choices}')"
        );
        sys.`exit(2);
    }

    import from jaclang.cli.dispatch { run_selected_command }
    run_selected_command(command_name);
}
