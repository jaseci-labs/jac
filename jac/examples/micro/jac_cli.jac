"""
This is the implementation of the command line interface tool for the
Jac languages. It's built with the Jac language V2 via bootstraping and
represents the first such production Jac program.
"""

import inspect;
import from argparse { ArgumentParser, ArgumentError }
import cmd;
import from typing { Any, Callable }

obj Interface {
    has functions: list[callable] = [];

    def register(func: callable) -> callable;
    def create_parser()  -> ArgumentParser;
    def run_from_cli;
    def run_shell;
}

obj ShellCmd(cmd.Cmd) {
    has reg: Interface,
        prompt: str = "> ";

    def init(registry: Interface, *args: list, **kwargs: dict);
    def default(line: str);
    def do_quit(arg: str) -> bool;
}

glob interface = Interface();
@interface.register
def function_one(a: int, b: str, c: bool = False) {
    print(f"Function One -> a: {a}, b: {b}, c: {c}");
}

@interface.register
def function_two(x: float, y: float) {
    print(f"Function Two -> x: {x}, y: {y}");
}

@interface.register
def function_three(name: str, age: int, country: str = 'Unknown') {
    print(f"Function Three -> name: {name}, age: {age}, country: {country}");
}
# Run CLI or Shell mode
# interface.run_from_cli()
with entry {
    interface.run_shell();
}

#***Implementation***#
impl Interface.register(func: callable) -> callable {
    self.functions.append(func);
    return func;
}

impl Interface.create_parser()  -> ArgumentParser {
    parser = ArgumentParser();
    parser.add_argument(
        "base", choices=[f.__name__ for f in functions], help="The function to run"
    );
    for func in self.functions {
        sig = inspect.signature(func);
        for (name, param) in sig.parameters.items() {
            kwargs = {};
            if param.default == inspect.Parameter.empty {
                kwargs = {'required': True};
            } else {
                kwargs = {'default': param.default};
            }
            parser.add_argument(f"--{func.__name__}.{name}", **kwargs);
        }
    }
    return parser;
}

impl Interface.run_from_cli{
    parser = self.create_parser();
    args = parser.parse_args();
    for f in self.functions {
        if f.__name__ == args.base {
            func = f;
            break;
        }
    }
    func_args = {
        k.split('.')[1]: v
        for (k, v) in vars(args).items()
        if k.startswith(func.__name__)
    };
    func(**func_args);
}

impl Interface.run_shell{
    ShellCmd(self).cmdloop();
}

impl ShellCmd.init(registry: Interface, *args: list, **kwargs: dict){
    self.cmd.Cmd.__init__(*args, **kwargs);
    self.reg = registry;
}

impl ShellCmd.default(line: str){
    args = line.split();
    parser = self.reg.create_parser();
    try {
        parsed_args = parser.parse_args(args);
        for f in self.reg.functions {
            if f.__name__ == parsed_args.base {
                func = f;
                break;
            }
        }
        func_args = {
            k.split('.')[1]: v
            for (k, v) in vars(parsed_args).items()
            if k.startswith(func.__name__)
        };
        func(**func_args);
    } except ArgumentError as e {
        print(f"Error: {str(e)}");
    }
}

impl ShellCmd.do_quit(arg: str) -> bool {
    return True;
}
