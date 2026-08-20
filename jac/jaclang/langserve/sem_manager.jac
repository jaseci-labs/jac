import logging;

import jaclang.jac0core.unitree as uni;
import from jaclang { JacRuntimeInterface as Jac }
import jaclang.lsp.types as lspt;

glob logger = logging.getLogger("jaclang.langserve.sem_manager");

obj SemTokManager {
    has ir: uni.Module,
        target_path: (str | None) = None,
        sem_tokens: list[int] postinit,
        static_sem_tokens:
            list[tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] postinit;

    def postinit -> None;
    def collect_resolved_nodes(ir: uni.Module) -> list[uni.NameAtom];
    def gen_sem_tokens(ir: uni.Module) -> list[int];
    def gen_sem_tok_node(
        ir: uni.Module
    ) -> list[tuple[(lspt.Position, int, int, uni.AstSymbolNode)]];
}
