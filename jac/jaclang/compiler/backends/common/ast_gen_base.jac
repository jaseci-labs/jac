import from typing { TypeVar }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.compiler.frontend.module_facts { ModuleFacts }
glob ChildPassT = TypeVar('ChildPassT', bound='BaseAstGenPass[Any]');

walker BaseAstGenPass[AstNodeT](UniPass) {
    def _merge_module_bodies(nd: uni.Module) -> list;
    def _init_child_passes(pass_class: type[ChildPassT]) -> list[ChildPassT];
    def _flatten_ast_list(
        items: list[AstNodeT | list[AstNodeT] | None]
    ) -> list[AstNodeT];
}
