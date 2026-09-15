import sys;

glob __all__ = ['exit_on_config_error'];

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
