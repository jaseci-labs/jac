import from jaclang.cli.manifest { CommandMeta }

def run_selected_command(command_name: str) -> None;
def split_remainder_argv(
    raw: list[str], meta: CommandMeta
) -> tuple[list[str], list[str]] | None;
