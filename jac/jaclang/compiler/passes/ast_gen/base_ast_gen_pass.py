"""Shared helpers for AST generation passes."""

from __future__ import annotations

from typing import Any, Generic, Optional, Sequence, TypeVar

import jaclang.compiler.unitree as uni
from jaclang.compiler.passes.uni_pass import UniPass

T = TypeVar("T")
ChildPassT = TypeVar("ChildPassT", bound="BaseAstGenPass[Any]")


class BaseAstGenPass(UniPass, Generic[T]):
    """Common functionality shared across AST generation passes."""

    def _get_body_inner(
        self, node: uni.Archetype | uni.Enum | uni.Ability
    ) -> Optional[Sequence[uni.UniNode]]:
        """Return the list of body statements regardless of ImplDef wrapping."""
        body = getattr(node, "body", None)
        if isinstance(body, uni.ImplDef) and isinstance(body.body, list):
            return body.body
        if isinstance(body, list):
            return body
        return None

    def _merge_module_bodies(self, node: uni.Module) -> list[uni.UniNode]:
        """Concatenate impl/test bodies with the main module body."""
        clean_body = [item for item in node.body if not isinstance(item, uni.ImplDef)]
        merged: list[uni.UniNode] = []
        for mod in node.impl_mod:
            merged.extend(mod.body)
        merged.extend(clean_body)
        for mod in node.test_mod:
            merged.extend(mod.body)
        return merged

    def _init_child_passes(self, pass_class: type[ChildPassT]) -> list[ChildPassT]:
        """Instantiate child passes for impl and test modules."""
        return [
            pass_class(ir_in=sub_module, prog=self.prog)
            for sub_module in self.ir_in.impl_mod + self.ir_in.test_mod
        ]

    def _flatten_ast_list(self, items: list[T | list[T] | None]) -> list[T]:
        """Flatten nested AST lists while skipping ``None`` entries."""
        flattened: list[T] = []
        for item in items:
            if isinstance(item, list):
                flattened.extend(item)
            elif item is not None:
                flattened.append(item)
        return flattened
