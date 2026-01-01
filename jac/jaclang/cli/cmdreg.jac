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
    has func: Callable,
        sig: inspect.Signature,
        priority: CommandPriority,
        source: str;

    def init(
        self: Command,
        func: Callable,
        priority: CommandPriority = CommandPriority.CORE,
        source: str = 'core'
    ) -> None;

    def call(self: Command, *args: list, **kwargs: dict) -> str;
}

def extract_param_descriptions(docstring: str) -> dict[str, str];

"""Registry for managing commands in the command line interface."""
class CommandRegistry {
    has registry: dict[(str, Command)],
        pending_commands: dict[(str, list[Command])],
        sub_parsers: argparse._SubParsersAction,
        parser: argparse.ArgumentParser,
        args: argparse.Namespace,
        _finalized: bool;

    def init(self: CommandRegistry) -> None;
    def register(
        self: CommandRegistry,
        func: (Callable | None) = None,
        *,
        priority: (int | CommandPriority) = CommandPriority.CORE,
        source: str = 'core'
    ) -> Callable;

    def _bind_command_to_argparse(
        self: CommandRegistry, name: str, cmd: Command
    ) -> None;

    def _resolve_and_bind_command(self: CommandRegistry, name: str) -> None;
    def finalize(self: CommandRegistry) -> None;
    def get(self: CommandRegistry, name: str) -> (Command | None);
}

glob cmd_registry = CommandRegistry();
