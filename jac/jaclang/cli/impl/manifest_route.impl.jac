import jaclang;
def _jaclang_manifest_version(start: Path) -> (str | None);

impl resolve_cli_version -> str {
    dev_source = str(handoff().get('compiler_source') or '');
    if dev_source {
        ver = _jaclang_manifest_version(Path(dev_source));
        if ver {
            return ver;
        }
    }

    jac_file = jaclang.__file__;
    if jac_file {
        ver = _jaclang_manifest_version(Path(jac_file).parent);
        if ver {
            return ver;
        }
    }

    return pkg_version('jaclang');
}

def _first_command_token(raw_argv: list[str]) -> (str | None);

def _looks_like_script_token(tok: str) -> bool;

def _workspace_app_names -> set[str];

def _write_stdout(text: str);

def _print_error(message: str);

def _render_version_line -> str;

impl handle_manifest_route(raw_argv: list[str]) -> None {
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
            _write_stdout(format_verbose_help(include_hidden='--all' in raw_argv));
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

    run_selected_command(command_name);
}

impl _jaclang_manifest_version(start: Path) -> (str | None) {
    for folder in [start] + list(start.parents) {
        toml_path = folder / 'jac.toml';
        if not toml_path.is_file() {
            continue;
        }
        try {
            data = tomllib.loads(toml_path.read_text(encoding='utf-8'));
        } except Exception {
            continue;
        }
        project = data.get('project', {});
        if isinstance(project, dict) and project.get('name') == 'jaclang' {
            ver = project.get('version');
            if isinstance(ver, str) and ver {
                return ver;
            }
        }
    }
    return None;
}

impl _first_command_token(raw_argv: list[str]) -> (str | None) {
    for tok in raw_argv {
        if not tok.startswith('-') {
            return tok;
        }
    }
    return None;
}

impl _looks_like_script_token(tok: str) -> bool {
    return (not tok.startswith('-') and tok.lower().endswith(('.jac', '.py', '.jab')));
}

impl _workspace_app_names -> set[str] {
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

impl _write_stdout(text: str) {
    sys.stdout.write(text);
    if not text.endswith('\n') {
        sys.stdout.write('\n');
    }
}

impl _print_error(message: str) {
    sys.stderr.write(f"error: {message}\n");
}

impl _render_version_line -> str {
    sys_info = f"{platform.system()} {platform.machine()}";
    ver = resolve_cli_version();
    use_color = _use_color();
    return f"{_color('jac', _TITLE, use_color)} {ver}  ({sys_info})";
}
