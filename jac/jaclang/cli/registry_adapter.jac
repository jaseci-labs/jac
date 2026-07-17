import from jaclang.cli.command { CommandSpec }
import from jaclang.cli.manifest { CommandMeta }
import from typing { Callable }

def manifest_to_spec(
    meta: CommandMeta, handler: Callable | None = None
) -> CommandSpec;

def materialize_all_specs(include_hidden: bool = False) -> list[CommandSpec];
