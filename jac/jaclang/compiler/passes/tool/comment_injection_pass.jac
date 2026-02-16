"""
Pass to inject comments using token-level precision.

This pass injects comments into the DocIR structure by:
1. Categorizing comments as inline (same line as token) or standalone
2. Injecting inline comments after their anchor tokens
3. Injecting standalone comments at appropriate positions (module, body, params)
4. Handling spacing adjustments for empty structures that receive comments
"""
import from bisect { bisect_left }
import from collections.abc { Sequence }
import from typing { NamedTuple }
import jaclang.compiler.passes.tool.doc_ir as doc;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }
import from jaclang.jac0core.passes { Transform }

"""Information about a pair of delimiters and their positions."""
class DelimiterInfo(NamedTuple) {
    has open_idx: int,
        close_idx: int,
        open_line: int,
        close_line: int;
}

"""Rich metadata about a source comment."""
obj CommentInfo {
    has index: int,
        token: uni.CommentToken,
        anchor_token_id: (int | None);

    @property
    def is_inline -> bool;

    @property
    def first_line -> int;

    @property
    def last_line -> int;
}

"""Efficient bookkeeping for inline and standalone comments."""
obj CommentStore {
    has _inline: dict[(int, list[CommentInfo])],
        _standalone: list[CommentInfo],
        _standalone_lines: list[int] by postinit,
        _used: set by postinit;

    def postinit -> None;
    static def from_module(module: uni.Module) -> CommentStore;
    def _mark_used(info: CommentInfo) -> bool;
    def take_inline(token_id: int) -> list[CommentInfo];
    def take_standalone_between(start_line: int, end_line: int) -> list[CommentInfo];
    def take_standalone_after(start_line: int) -> list[CommentInfo];
    def drain_unattached -> list[CommentInfo];
}

"""
Injects comments using token sequence analysis for perfect precision.

    Uses src_terminals to detect inline vs standalone comments, then
    injects them using source_token annotations with automatic duplicate
    line collapsing.
"""
obj CommentInjectionPass(Transform[(uni.Module, uni.Module)]) {
    def init(ir_in: uni.Module, prog: Any, cancel_token: Any = None);
    def transform(ir_in: uni.Module) -> uni.Module;
    def _process(ctx: uni.UniNode, nd: doc.DocType) -> doc.DocType;
    def _find_delimiters(
        parts: list[doc.DocType], open_tok: Tok, close_tok: Tok
    ) -> (DelimiterInfo | None);

    def _get_tokens(nd: doc.DocType) -> list[uni.Token];
    def _doc_line_span(nd: doc.DocType) -> tuple[(int | None), (int | None)];
    def _inject_into_parts(
        parts: list[doc.DocType], ctx: uni.UniNode
    ) -> list[doc.DocType];

    def _inject_standalone_by_spans(
        parts: list[doc.DocType], ctx: uni.UniNode, *, drain_after: bool = False
    ) -> list[doc.DocType];

    def _handle_body_comments(nd: uni.UniNode, indent: doc.Indent) -> doc.Indent;
    def _handle_paren_comments(
        items: (Sequence[uni.UniNode] | None), parts: list[doc.DocType]
    ) -> list[doc.DocType];

    def _handle_empty_body_comments(
        nd: uni.UniNode, parts: list[doc.DocType]
    ) -> list[doc.DocType];

    def _fix_empty_region_spacing(parts: list[doc.DocType]) -> list[doc.DocType];
    def _make_standalone_comment(comment: uni.CommentToken) -> doc.DocType;
    def _make_inline_comment(
        comment: uni.CommentToken, add_line: bool = True
    ) -> doc.DocType;

    def _emit_standalone_comments(
        sink: list[doc.DocType],
        comments: Sequence[CommentInfo],
        *,
        prev_item_line: (int | None)
    ) -> (int | None);

    def _starts_with_line(part: doc.DocType) -> bool;
    def _is_standalone_comment(part: doc.DocType) -> bool;
    def _is_comment_with_line(part: doc.DocType) -> bool;
    def _strip_trailing_line_from_comment(comment: doc.DocType) -> doc.DocType;
    def _ends_with_hard_line(sink: Sequence[doc.DocType]) -> bool;
    def _collapse_duplicate_hard_lines(sink: list[doc.DocType]) -> None;
    def _ends_with_inline_comment_line(nd: doc.DocType) -> bool;
    def _remove_trailing_line_from_inline_comment(nd: doc.DocType) -> doc.DocType;
    def _remove_redundant_lines(nd: doc.DocType) -> doc.DocType;
}
