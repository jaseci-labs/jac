def run_selected_command(command_name: str) -> None;
def split_remainder_argv(
    raw: list[str], meta: CommandSpec
) -> tuple[list[str], list[str]] | None;
