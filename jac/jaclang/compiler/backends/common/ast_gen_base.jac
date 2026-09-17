import from jaclang.compiler.frontend.unitree { TreeWalker }
import from jaclang.compiler.passes.context { CompileContext }
import from typing { TypeVar }
import jaclang.compiler.frontend.unitree as uni;

import from jaclang.compiler.frontend.module_facts { ModuleFacts }
glob ChildPassT = TypeVar('ChildPassT', bound='BaseAstGenPass[Any]');

walker BaseAstGenPass[AstNodeT](TreeWalker) {
    can enter_walk with uni.UniNode entry {
        self.ctx.enter_node(here);
    }

    can exit_walk with uni.UniNode exit {
        self.ctx.exit_node(here);
    }

    has ctx: CompileContext,
        module: uni.Module;

    def _merge_module_bodies(nd: uni.Module) -> list[uni.UniNode];
    def _init_child_passes(pass_class: type[ChildPassT]) -> list[ChildPassT];
    def _flatten_ast_list(
        items: list[AstNodeT | list[AstNodeT] | None]
    ) -> list[AstNodeT];
}
