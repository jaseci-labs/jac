import from jaclang.cli.registry { get_registry }
import from jaclang.cli.executor { get_executor }

import from jaclang.cli.commands {
    execution,
    analysis,
    transform,
    project,
    eject,
    tools,
    config,
    nacompile
}

def start_cli -> None;
def jac_version -> str;

with entry:__main__ {
    start_cli();
}
