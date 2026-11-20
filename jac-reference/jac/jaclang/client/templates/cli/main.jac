"""{{name}} - a command-line Jac app.

Subcommands are declared with `argparse` and dispatched from the entry block.
Add one by registering a parser in `build_parser` and a branch in `main`.

    jac run main.jac -- greet Ada --shout
"""

import argparse;
import sys;

def greet(name: str, shout: bool = False) -> str {
    message = f"Hello, {name}! This is {{name}}.";
    return message.upper() if shout else message;
}

def build_parser -> argparse.ArgumentParser {
    parser = argparse.ArgumentParser(
        prog="{{name}}", description="{{name}} command-line tool"
    );
    commands = parser.add_subparsers(dest="command", required=True);
    greet_cmd = commands.add_parser("greet", help="Print a greeting");
    greet_cmd.add_argument("name", nargs="?", `default="world", help="Who to greet");
    greet_cmd.add_argument("--shout", action="store_true", help="Greet loudly");
    return parser;
}

def main(argv: list[str] | None = None) -> int {
    args = build_parser().parse_args(argv);
    if args.command == "greet" {
        print(greet(args.name, args.shout));
        return 0;
    }
    return 2;
}

with entry:__main__ {
    sys.`exit(main());
}
