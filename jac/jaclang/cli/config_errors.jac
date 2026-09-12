import sys;

glob __all__ = ['apply_overlay_or_exit', 'exit_on_config_error'];

def exit_on_config_error(exc: Exception) {
    import from jaclang.cli.console { console }
    import from jaclang.project.tomlio { MalformedJacTomlError }

    if isinstance(exc, MalformedJacTomlError) {
        console.error(
            f"jac.toml is malformed: {exc.original}", hint=f"File: {exc.file_path}"
        );
    } else {
        console.error(f"jac.toml is invalid: {exc}");
    }
    sys.`exit(2);
}

def apply_overlay_or_exit(config: any, profile: str | None) {
    try {
        config.apply_profile_overlay(profile);
    } except ValueError as exc {
        exit_on_config_error(exc);
    }
}
