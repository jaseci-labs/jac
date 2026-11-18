def run_selected_command(command_name: str) -> None;
def warn_unmet_jac_version(pin: str);
def warn_unmet_project_pins(paths: list[str]);
def split_remainder_argv(
    raw: list[str], meta: CommandSpec
) -> tuple[list[str], list[str]] | None;
