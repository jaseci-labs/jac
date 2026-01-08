"""Common code for command line interface tool for the Jac language."""

import argparse;
import inspect;
import os;
import re;
import sys;
import from collections.abc { Callable }
"""Priority levels for command registration.

Higher values take precedence when multiple commands with the same name are registered.
This allows plugins to override core commands in a controlled manner.
"""
enum CommandPriority {
    CORE = 100,
    PLUGIN = 200,
    USER = 300,
}

"""Represents a command in the command line interface."""
obj Command {
    def init(
        func: Callable,
        priority: CommandPriority = CommandPriority.CORE,
        source: str = 'unknown'
    ) -> None;

    def call( *args: list , **kwargs: dict)  -> str;
}

def extract_param_descriptions(docstring: str) -> dict[str, str];

"""Registry for managing commands in the command line interface."""
obj CommandRegistry {
    def init -> None;
    def register(
        func: (Callable | None) = None,
        *,
        priority: (int | CommandPriority) = CommandPriority.CORE,
        source: str = 'unknown'
    ) -> Callable;

    def _bind_command_to_argparse(name: str, cmd: Command) -> None;
    def _resolve_and_bind_command(name: str) -> None;
    def finalize -> None;
    def get(name: str) -> (Command | None);
}

glob cmd_registry = CommandRegistry();
