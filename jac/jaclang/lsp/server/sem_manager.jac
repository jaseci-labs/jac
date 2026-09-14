import logging;

import jaclang.compiler.frontend.unitree as uni;
import from jaclang { JacRuntimeInterface as Jac }
import jaclang.lsp.protocol.types as lspt;

glob logger = logging.getLogger("jaclang.lsp.server.sem_manager");

obj SemanticToken {
    has position: lspt.Position,
        end_character: int,
        length: int,
        symbol: uni.NameAtom;
}

obj SemTokManager {
    has ir: uni.Module,
        target_path: (str | None) = None,
        tokens_by_line: dict[int, list[uni.Token]] = {},
        sem_tokens: list[int] postinit,
        static_sem_tokens: list[SemanticToken] postinit;

    def postinit -> None;
    def collect_resolved_nodes(ir: uni.Module) -> list[uni.NameAtom];
    def encode_tokens -> list[int];
    def gen_sem_tok_node(ir: uni.Module) -> list[SemanticToken];
}
