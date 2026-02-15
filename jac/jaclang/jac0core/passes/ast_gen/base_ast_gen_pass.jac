"""Shared helpers for AST generation passes."""
import from collections.abc { Sequence }
import from typing { Any, Generic, TypeVar }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.uni_pass { UniPass }
glob T = TypeVar('T'),
     ChildPassT = TypeVar('ChildPassT', bound='BaseAstGenPass[Any]');

"""Common functionality shared across AST generation passes."""
class BaseAstGenPass(UniPass, Generic[T]) {
    """Return the list of body statements regardless of ImplDef wrapping."""
    def _get_body_inner(
        self: BaseAstGenPass, nd: uni.Archetype | uni.Enum | uni.Ability
    ) -> (Sequence | None);

    """Concatenate impl/test bodies with the main module body."""
    def _merge_module_bodies(self: BaseAstGenPass, nd: uni.Module) -> list;

    """Instantiate child passes for impl and test modules."""
    def _init_child_passes(
        self: BaseAstGenPass, pass_class: type[ChildPassT]
    ) -> list[ChildPassT];

    """Flatten nested AST lists while skipping ``None`` entries."""
    def _flatten_ast_list(
        self: BaseAstGenPass, items: list[T | list[T] | None]
    ) -> list[T];
}
