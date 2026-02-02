"""Semantic Token Manager module."""
import from typing { List, Optional, Tuple }
import logging;

import jaclang.pycore.unitree as uni;
import from jaclang { JacRuntimeInterface as Jac }
import from jaclang.langserve.utils {
    find_surrounding_tokens,
    get_token_start,
    get_line_of_code
}
import lsprotocol.types as lspt;

# Semantic token flat array field offsets.
# Each token occupies TOK_STRIDE (5) consecutive ints:
#   [line_delta, col_delta, length, token_type, token_modifier]
glob TOK_LINE_DELTA = 0,
     TOK_COL_DELTA = 1,
     TOK_LENGTH = 2,
     TOK_TYPE = 3,
     TOK_MODIFIER = 4,
     TOK_STRIDE = 5,
     logger = logging.getLogger("jaclang.langserve.sem_manager");

"""Semantic Token Manager class."""
obj SemTokManager {
    has ir: uni.Module,
        hub: dict = {},
        sem_tokens: List[int] by postinit,
        static_sem_tokens: List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]] by postinit;

    def postinit -> None;
    def resolve_symbol(nd: uni.NameAtom) -> None;
    def collect_resolved_nodes(ir: uni.Module) -> list;
    def gen_sem_tokens(ir: uni.Module) -> list[int];
    def gen_sem_tok_node(
        ir: uni.Module
    ) -> List[Tuple[(lspt.Position, int, int, uni.AstSymbolNode)]];

    def update_sem_tokens(
        content_changes: lspt.DidChangeTextDocumentParams,
        sem_tokens: list[int],
        document_lines: List[str]
    ) -> list[int];

    static def handle_multi_line_delete(
        self: SemTokManager,
        sem_tokens: list[int],
        next_token_index: int,
        nxt_tok_pos: <>tuple[(int, int, int)],
        change_start_line: int,
        change_end_line: int,
        change_start_char: int,
        change_end_char: int,
        prev_tok_pos: <>tuple[(int, int, int)],
        is_next_token_same_line: bool
    ) -> list[int];

    static def handle_single_line_delete_between_tokens(
        self: SemTokManager,
        sem_tokens: list[int],
        next_token_index: int,
        is_next_token_same_line: bool,
        change: lspt.TextDocumentContentChangeEvent_Type1,
        change_start_line: int,
        change_end_line: int
    ) -> list[int];

    static def handle_single_line_delete(
        self: SemTokManager,
        sem_tokens: list[int],
        next_token_index: int,
        prev_token_index: int,
        is_next_token_same_line: bool,
        change: lspt.TextDocumentContentChangeEvent_Type1
    ) -> list[int];

    static def handle_single_line_insertion(
        self: SemTokManager,
        sem_tokens: list[int],
        next_token_index: int,
        is_next_token_same_line: bool,
        change: lspt.TextDocumentContentChangeEvent_Type1,
        tokens_on_same_line: bool,
        nxt_tok_pos: <>tuple[(int, int, int)],
        change_start_line: int,
        line_delta: int
    ) -> list[int];

    static def handle_multi_line_insertion(
        self: SemTokManager,
        sem_tokens: list[int],
        next_token_index: int,
        nxt_tok_pos: <>tuple[(int, int, int)],
        change_start_line: int,
        change_end_line: int,
        change_end_char: int,
        prev_tok_pos: <>tuple[(int, int, int)],
        tokens_on_same_line: bool,
        changing_line_text: <>tuple[(str, int)],
        line_delta: int
    ) -> list[int];

    static def handle_insert_inside_token(
        self: SemTokManager,
        change: lspt.TextDocumentContentChangeEvent_Type1,
        sem_tokens: list[int],
        prev_token_index: int,
        changing_line_text: <>tuple[(str, int)],
        line_delta: int,
        prev_tok_pos: <>tuple[(int, int, int)],
        change_start_char: int,
        change_end_char: int,
        is_token_boundary_edit: bool,
        nxt_tok_pos: <>tuple[(int, int, int)]
    ) -> <>tuple[list[int], bool, <>tuple[(int, int, int)], Optional[int]];
}
