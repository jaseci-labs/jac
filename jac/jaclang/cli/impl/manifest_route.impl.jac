import jaclang;

def _read_version_from_toml(toml_path: Path) -> (str | None) {
    try {
        data = tomllib.loads(toml_path.read_text(encoding='utf-8'));
        project = data.get('project', {});
        if isinstance(project, dict) {
            ver = project.get('version');
            if isinstance(ver, str) and ver {
                return ver;
            }
        }
    } except Exception { }
    return None;
}

def _resolve_cli_version -> str {
    dev_source = os.environ.get('JAC_DEV_SOURCE');
    if dev_source {
        toml_path = Path(dev_source) / 'jac.toml';
        if toml_path.exists() {
            ver = _read_version_from_toml(toml_path);
            if ver {
                return ver;
            }
        }
    }

    jac_file = jaclang.__file__;
    if jac_file {
        source_toml = Path(jac_file).parent.parent / 'jac.toml';
        if source_toml.exists() {
            ver = _read_version_from_toml(source_toml);
            if ver {
                return ver;
            }
        }
    }

    return pkg_version('jaclang');
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

def _has_script_file(raw_argv: list[str]) -> bool {
    return any(_looks_like_script_token(tok) for tok in raw_argv);
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

impl handle_manifest_route(raw_argv: list[str]) -> bool {
    import from jaclang.cli.manifest { TOMBSTONED_VERBS, known_command_names }
    import from jaclang.cli.manifest_help {
        _use_color,
        format_curated_help,
        format_logo,
        format_verbose_help
    }
    import from jaclang.cli.dispatch { run_selected_command }

    if raw_argv in (['-V'], ['--version']) {
        sys_info = f"{platform.system()} {platform.machine()}";
        ver = _resolve_cli_version();
        use_color = _use_color();
        bold = '\033[1m' if use_color else '';
        reset = '\033[0m' if use_color else '';
        _write_stdout(f"{bold}jac{reset} {ver}  ({sys_info})");
        return True;
    }

    if raw_argv in (['-h'], ['--help']) {
        _write_stdout(format_verbose_help());
        return True;
    }

    if not raw_argv {
        ver = _resolve_cli_version();
        _write_stdout(format_logo(ver));
        _write_stdout('');
        _write_stdout(format_curated_help());
        return True;
    }

    first = _first_command_token(raw_argv);
    if first is None {
        return False;
    }

    dispatchable = known_command_names(include_hidden=True);
    visible = known_command_names();

    if first in TOMBSTONED_VERBS and first not in dispatchable {
        _print_error(
            f"'jac {first}' was removed in the CLI cleanup (#7255); "
            f"use: {TOMBSTONED_VERBS[first]}"
        );
        sys.exit(2);
    }

    if _has_script_file(raw_argv) and first not in dispatchable {
        sys.argv = [sys.argv[0], 'run'] + raw_argv;
        command_name = 'run';
    } elif first in dispatchable {
        command_name = first;
    } else {
        choices = "', '".join(sorted(visible));
        sys.stderr.write('usage: jac [-h] [-V] COMMAND ...\n');
        _print_error(
            f"argument COMMAND: invalid choice: {first!r} (choose from '{choices}')"
        );
        sys.exit(2);
    }

    run_selected_command(command_name);
    return True;
}
