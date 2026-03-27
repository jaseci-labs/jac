"""Shared helpers for AST generation passes."""
import from collections.abc { Sequence }
import from typing { Any, TypeVar }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.uni_pass { UniPass }
glob ChildPassT = TypeVar('ChildPassT', bound='BaseAstGenPass[Any]');

"""Common functionality shared across AST generation passes."""
obj BaseAstGenPass[T](UniPass) {
    """Concatenate impl/test bodies with the main module body."""
    def _merge_module_bodies(nd: uni.Module) -> list;

    """Instantiate child passes for impl and test modules."""
    def _init_child_passes(pass_class: type[ChildPassT]) -> list[ChildPassT];

    """Flatten nested AST lists while skipping ``None`` entries."""
    def _flatten_ast_list(items: list[T | list[T] | None]) -> list[T];
}
