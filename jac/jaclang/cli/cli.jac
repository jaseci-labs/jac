import from jaclang.cli.registry { get_registry }
import from jaclang.cli.executor { get_executor }

def start_cli -> None;
def jac_version -> str;

with entry:__main__ {
    start_cli();
}
