"""Common code for command line interface tool for the Jac language."""
import from __future__ { annotations }
import argparse;
import inspect;
import os;
import re;
import sys;
import from collections.abc { Callable }
import from dataclasses { fields as dataclass_fields }
import from enum { IntEnum }
"""Priority levels for command registration.

Higher values take precedence when multiple commands with the same name are registered.
This allows plugins to override core commands in a controlled manner.
"""
class CommandPriority(IntEnum) {
    with entry {
        CORE = 100;
        PLUGIN = 200;
        USER = 300;
    }
}

"""Represents a command in the command line interface."""
class Command {
    with entry {
        func: Callable;
        sig: inspect.Signature;
        priority: CommandPriority;
        source: str;
    }

    """Initialize a Command instance."""
    def __init__(
        self: Command,
        func: Callable,
        priority: CommandPriority = CommandPriority.CORE,
        source: str = 'core'
    ) -> None {
        self.func = func;
        self.sig = inspect.signature(func);
        self.priority = priority;
        self.source = source;
    }

    """Call the associated function with the specified arguments and keyword arguments."""
    def call(self: Command, *args: list, **kwargs: dict) -> str {
        return self.func(*args, **kwargs);
    }
}

"""Extract parameter descriptions from a function's docstring.

Args:
    docstring: The function's docstring

Returns:
    A dictionary mapping parameter names to their descriptions
"""
def extract_param_descriptions(docstring: str) -> dict[str, str] {
    param_descriptions: dict[(str, str)] = {};
    args_match = re.search('Args:(.*?)(?:\\n\\n|\\Z)', docstring, re.DOTALL);
    if not args_match {
        return param_descriptions;
    }
    args_section = args_match.group(1);
    current_param = None;
    current_desc = [];
    for line in args_section.strip().split('\n') {
        line = line.strip();
        if not line {
            continue;
        }
        param_match = re.match(
            '\\s*([a-zA-Z0-9_]+)(?:\\s*\\([^)]*\\))?:\\s*(.*)', line
        );
        if param_match {
            if (current_param and current_desc) {
                param_descriptions[current_param] = ' '.join(current_desc);
                current_desc = [];
            }
            current_param = param_match.group(1);
            if param_match.group(2) {
                current_desc.append(param_match.group(2));
            }
        } elif (current_param and line) {
            current_desc.append(line);
        }
    }
    if (current_param and current_desc) {
        param_descriptions[current_param] = ' '.join(current_desc);
    }
    return param_descriptions;
}

"""Registry for managing commands in the command line interface."""
class CommandRegistry {
    with entry {
        registry: dict[(str, Command)];
        pending_commands: dict[(str, list[Command])];
        sub_parsers: argparse._SubParsersAction;
        parser: argparse.ArgumentParser;
        args: argparse.Namespace;
        _finalized: bool;
    }

    """Initialize a CommandRegistry instance."""
    def __init__(self: CommandRegistry) -> None {
        self.registry = {};
        self.pending_commands = {};
        self._finalized = False;
        self._settings_added = False;
        self.parser = argparse.ArgumentParser(
            prog='jac',
            description='Jac Programming Language CLI - A tool for working with Jac programs',
            epilog='For more information, visit: https://github.com/Jaseci-Labs/jaseci',
            formatter_class=argparse.RawDescriptionHelpFormatter
        );
        self.parser.add_argument(
            '-V',
            '--version',
            action='store_true',
            help='Show the Jac version and installation path'
        );
        self.sub_parsers = self.parser.add_subparsers(
            title='commands',
            dest='command',
            description='The following commands are available:',
            metavar='COMMAND'
        );
        self.args = argparse.Namespace();
    }

    """Add global settings arguments (lazily loaded)."""
    def _add_settings_arguments(self: CommandRegistry) -> None {
        if self._settings_added {
            return;
        }
        self._settings_added = True;
        import from jaclang.pycore.settings { Settings as JacSettings }
        settings_group = self.parser.add_argument_group(
            'settings',
            'Override Jac settings (from config/env). Provide only flags you want to change.'
        );
        for fld in dataclass_fields(JacSettings) {
            name = fld.name;
            opt = f"--{name.replace('_', '-')}";
            if (fld.type is bool) {
                settings_group.add_argument(
                    opt,
                    dest=name,
                    action='store_true',
                    <>default=None,
                    help=f"bool - Override setting '{name}' to true"
                );
                settings_group.add_argument(
                    f"--no-{name.replace('_', '-')}",
                    dest=name,
                    action='store_false',
                    <>default=None,
                    help=f"bool - Override setting '{name}' to false"
                );
            } elif (fld.type is int) {
                settings_group.add_argument(
                    opt,
                    dest=name,
                    <>type=int,
                    <>default=None,
                    help=f"int - Override setting '{name}'"
                );
            } else {
                settings_group.add_argument(
                    opt,
                    dest=name,
                    <>type=str,
                    <>default=None,
                    help=f"str - Override setting '{name}'"
                );
            }
        }
    }

    """Register a command in the registry.

This method supports both decorator syntax with and without arguments:
    @cmd_registry.register
    def my_cmd(): ...

    @cmd_registry.register(priority=CommandPriority.PLUGIN, source="my-plugin")
    def my_cmd(): ...

Args:
    func: The command function to register
    priority: Priority level for conflict resolution
    source: Source plugin/module name for introspection

Returns:
    The original function (for decorator usage)
"""
    def register(
        self: CommandRegistry,
        func: (Callable | None) = None,
        *,
        priority: CommandPriority = CommandPriority.CORE,
        source: str = 'core'
    ) -> Callable {
        """Inner registration function.""";
        def _register(f: Callable) -> Callable {
            name = f.__name__;
            cmd = Command(f, priority=priority, source=source);
            if (name not in self.pending_commands) {
                self.pending_commands[name] = [];
            }
            self.pending_commands[name].append(cmd);
            if self._finalized {
                self._resolve_and_bind_command(name);
            }
            return f;
        }
        if (func is not None) {
            return _register(func);
        }
        return _register;
    }

    """Bind a command to argparse subparser."""
    def _bind_command_to_argparse(
        self: CommandRegistry, name: str, cmd: Command
    ) -> None {
        func = cmd.func;
        doc = func.__doc__ or '';
        brief_desc = doc.split('\n\n')[0].strip();
        cmd_parser: argparse.ArgumentParser = self.sub_parsers.add_parser(
            name,
            description=func.__doc__,
            help=brief_desc,
            formatter_class=argparse.RawDescriptionHelpFormatter
        );
        first = True;
        for (param_name, param) in cmd.sig.parameters.items() {
            type_name = param.annotation.__name__
            if hasattr(param.annotation, '__name__')
            else str(param.annotation);
            docstring_param_descriptions = extract_param_descriptions(doc);
            if (param_name in docstring_param_descriptions) {
                arg_msg = f"{type_name} - {docstring_param_descriptions[param_name]}";
            } else {
                arg_msg = f"{type_name}";
            }
            shorthand = param_name[:1];
            if (f"-{shorthand}" in cmd_parser._option_string_actions) {
                shorthand = param_name[:2];
            }
            if (param_name == 'args') {
                cmd_parser.add_argument('args', nargs=argparse.REMAINDER, help=arg_msg);
            } elif (param_name == 'paths') {
                cmd_parser.add_argument('paths', nargs='+', help=arg_msg);
                first = False;
            } elif (param_name == 'filepath') {
                first = False;
                cmd_parser.add_argument(
                    f"{param_name}",
                    <>type=eval(param.annotation)
                    if isinstance(param.annotation, str)
                    else param.annotation,
                    help=arg_msg,
                    nargs='?'
                );
            } elif (param.default is param.empty) {
                if first {
                    first = False;
                    cmd_parser.add_argument(
                        f"{param_name}",
                        <>type=eval(param.annotation)
                        if isinstance(param.annotation, str)
                        else param.annotation,
                        help=arg_msg
                    );
                } else {
                    cmd_parser.add_argument(
                        f"-{shorthand}",
                        f"--{param_name}",
                        required=True,
                        <>type=eval(param.annotation)
                        if isinstance(param.annotation, str)
                        else param.annotation,
                        help=arg_msg
                    );
                }
            } elif first {
                arg_msg += f", default: {param.default}";
                first = False;
                cmd_parser.add_argument(
                    f"{param_name}",
                    <>default=param.default,
                    <>type=eval(param.annotation),
                    help=arg_msg
                );
            } else {
                arg_msg += f", default: {param.default}";
                if (param.annotation is bool or param.annotation == 'bool') {
                    cmd_parser.add_argument(
                        f"-{shorthand}",
                        f"--{param_name}",
                        <>default=param.default,
                        action='store_true',
                        help=arg_msg
                    );
                    cmd_parser.add_argument(
                        f"-n{shorthand}",
                        f"--no-{param_name}",
                        dest=param_name,
                        action='store_false',
                        help=f"Compliment of {arg_msg}"
                    );
                } else {
                    cmd_parser.add_argument(
                        f"-{shorthand}",
                        f"--{param_name}",
                        <>default=param.default,
                        help=arg_msg,
                        <>type=eval(param.annotation)
                        if isinstance(param.annotation, str)
                        else param.annotation
                    );
                }
            }
        }
    }

    """Resolve command conflicts by priority and bind to argparse."""
    def _resolve_and_bind_command(self: CommandRegistry, name: str) -> None {
        if (name not in self.pending_commands) {
            return;
        }
        commands = self.pending_commands[name];
        if not commands {
            return;
        }
        commands.sort(key=lambda  c: Any: c.priority, reverse=True);
        winner = commands[0];
        if ((len(commands) > 1) and os.getenv('JAC_CLI_VERBOSE')) {
            conflicts = [f"{c.source} (priority={c.priority})" for c in commands[1:]];
            print(
                f"Warning: Command '{name}' registered by multiple sources. Using {winner.source} (priority={winner.priority}). Overriding: {', '.join(
                    conflicts
                )}",
                file=sys.stderr
            );
        }
        self.registry[name] = winner;
        self._bind_command_to_argparse(name, winner);
    }

    """Finalize command registration by resolving conflicts and binding to argparse.

This should be called after all plugins have had a chance to register commands.
"""
    def finalize(self: CommandRegistry) -> None {
        if self._finalized {
            return;
        }
        self._add_settings_arguments();
        for name in <>list(self.pending_commands.keys()) {
            self._resolve_and_bind_command(name);
        }
        self._finalized = True;
        self.pending_commands.clear();
    }

    """Get the Command instance for a given command name."""
    def get(self: CommandRegistry, name: str) -> (Command | None) {
        return self.registry.get(name);
    }
}

with entry {
    cmd_registry = CommandRegistry();
}
