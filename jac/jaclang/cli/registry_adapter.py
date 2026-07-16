"""Registry adapter: materialize CommandSpec values from manifest metadata."""

from __future__ import annotations

from collections.abc import Callable
from typing import TYPE_CHECKING

from jaclang.cli.loader import load_handler
from jaclang.cli.manifest import CommandMeta, iter_command_meta

if TYPE_CHECKING:
    from jaclang.cli.command import CommandSpec


def manifest_to_spec(meta: CommandMeta, handler: Callable | None = None) -> CommandSpec:
    from jaclang.cli.command import Arg, ArgKind, CommandSpec

    if handler is None:
        handler = load_handler(meta.name)

    args = []
    for a in meta.args:
        typ = int if a.typ == "int" else str
        args.append(
            Arg(
                name=a.name,
                kind=ArgKind(a.kind.value),
                typ=typ,
                default=a.default,
                help=a.help,
                short=a.short,
                choices=list(a.choices) if a.choices else None,
                required=a.required,
                dest=a.dest,
                metavar=a.metavar,
            )
        )
    return CommandSpec(
        name=meta.name,
        help=meta.help,
        description=meta.description,
        args=args,
        examples=list(meta.examples),
        group=meta.group,
        tier=meta.tier,
        hidden=meta.hidden,
        handler=handler,
    )


def materialize_all_specs(*, include_hidden: bool = False) -> list[CommandSpec]:
    return [
        manifest_to_spec(meta)
        for meta in iter_command_meta(include_hidden=include_hidden)
    ]
