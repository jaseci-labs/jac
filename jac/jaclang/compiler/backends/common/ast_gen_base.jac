import from jaclang.compiler.frontend.unitree { TreeWalker }
import from jaclang.compiler.passes.context { CompileContext, TreePass }
import from typing { TypeVar }
import jaclang.compiler.frontend.unitree as uni;

import from jaclang.compiler.frontend.module_facts { ModuleFacts }
glob ChildPassT = TypeVar('ChildPassT', bound='BaseAstGenPass[Any]');

walker BaseAstGenPass[AstNodeT](TreePass) {
    def _merge_module_bodies(nd: uni.Module) -> list[uni.UniNode];
    def _init_child_passes(pass_class: type[ChildPassT]) -> list[ChildPassT];
    def _flatten_ast_list(
        items: list[AstNodeT | list[AstNodeT] | None]
    ) -> list[AstNodeT];
}
