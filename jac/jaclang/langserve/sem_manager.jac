import from typing { List, Tuple }
import logging;

import jaclang.jac0core.unitree as uni;
import from jaclang { JacRuntimeInterface as Jac }
import jaclang.lsp.types as lspt;

glob logger = logging.getLogger("jaclang.langserve.sem_manager");

obj SemTokManager {
    has ir: uni.Module,
        target_path: (str | None) = None,
        sem_tokens: List[int] by postinit,
        static_sem_tokens:
            List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] by postinit;

    def postinit -> None;
    def collect_resolved_nodes(ir: uni.Module) -> list;
    def gen_sem_tokens(ir: uni.Module) -> list[int];
    def gen_sem_tok_node(
        ir: uni.Module
    ) -> List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]];
}
