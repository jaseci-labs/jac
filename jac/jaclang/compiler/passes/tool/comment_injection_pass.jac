"""Pass to inject comments using token-level precision.\n\nThis pass injects comments into the DocIR structure by:\n1. Categorizing comments as inline (same line as token) or standalone\n2. Injecting inline comments after their anchor tokens\n3. Injecting standalone comments at appropriate positions (module, body, params)\n4. Handling spacing adjustments for empty structures that receive comments\n"""
import from bisect { bisect_left }
import from collections.abc { Sequence }
import from dataclasses { dataclass }
import from typing { NamedTuple }
import jaclang.compiler.passes.tool.doc_ir as doc;
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.passes { Transform }
"""Information about a pair of delimiters and their positions."""
class DelimiterInfo(NamedTuple) {
    with entry {
        open_idx: int;
        close_idx: int;
        open_line: int;
        close_line: int;
    }
}

"""Rich metadata about a source comment."""
@dataclass(slots=True)
class CommentInfo {
    with entry {
        index: int;
        token: uni.CommentToken;
        anchor_token_id: (int | None);
    }

    @property
    def is_inline(self: CommentInfo) -> bool;

    @property
    def first_line(self: CommentInfo) -> int;

    @property
    def last_line(self: CommentInfo) -> int;
}

"""Efficient bookkeeping for inline and standalone comments."""
class CommentStore {
    def init(
        self: CommentStore,
        inline: dict[(int, list[CommentInfo])],
        standalone: list[CommentInfo]
    ) -> None;

    @classmethod
    def from_module(cls: Any, module: uni.Module) -> CommentStore;

    def _mark_used(self: CommentStore, info: CommentInfo) -> bool;
    def take_inline(self: CommentStore, token_id: int) -> list[CommentInfo];
    def take_standalone_between(
        self: CommentStore, start_line: int, end_line: int
    ) -> list[CommentInfo];

    def take_standalone_after(self: CommentStore, start_line: int) -> list[CommentInfo];
    def drain_unattached(self: CommentStore) -> list[CommentInfo];
}

"""Injects comments using token sequence analysis for perfect precision.\n\n    Uses src_terminals to detect inline vs standalone comments, then\n    injects them using source_token annotations with automatic duplicate\n    line collapsing.\n    """
class CommentInjectionPass(Transform[(uni.Module, uni.Module)]) {
    def transform(self: CommentInjectionPass, ir_in: uni.Module) -> uni.Module;
    def _process(
        self: CommentInjectionPass, ctx: uni.UniNode, <>node: doc.DocType
    ) -> doc.DocType;

    def _find_delimiters(
        self: CommentInjectionPass,
        parts: list[doc.DocType],
        open_tok: Tok,
        close_tok: Tok
    ) -> (DelimiterInfo | None);

    def _get_tokens(self: CommentInjectionPass, <>node: doc.DocType) -> list[uni.Token];
    def _doc_line_span(
        self: CommentInjectionPass, <>node: doc.DocType
    ) -> tuple[(int | None), (int | None)];

    def _inject_into_parts(
        self: CommentInjectionPass, parts: list[doc.DocType], ctx: uni.UniNode
    ) -> list[doc.DocType];

    def _inject_standalone_by_spans(
        self: CommentInjectionPass,
        parts: list[doc.DocType],
        ctx: uni.UniNode,
        *,
        drain_after: bool = False
    ) -> list[doc.DocType];

    def _handle_body_comments(
        self: CommentInjectionPass, <>node: uni.UniNode, indent: doc.Indent
    ) -> doc.Indent;

    def _handle_paren_comments(
        self: CommentInjectionPass,
        items: (Sequence[uni.UniNode] | None),
        parts: list[doc.DocType]
    ) -> list[doc.DocType];

    def _handle_empty_body_comments(
        self: CommentInjectionPass, <>node: uni.UniNode, parts: list[doc.DocType]
    ) -> list[doc.DocType];

    def _fix_empty_region_spacing(
        self: CommentInjectionPass, parts: list[doc.DocType]
    ) -> list[doc.DocType];

    def _make_standalone_comment(
        self: CommentInjectionPass, comment: uni.CommentToken
    ) -> doc.DocType;

    def _make_inline_comment(
        self: CommentInjectionPass, comment: uni.CommentToken, add_line: bool = True
    ) -> doc.DocType;

    def _emit_standalone_comments(
        self: CommentInjectionPass,
        sink: list[doc.DocType],
        comments: Sequence[CommentInfo],
        *,
        prev_item_line: (int | None)
    ) -> (int | None);

    def _starts_with_line(self: CommentInjectionPass, part: doc.DocType) -> bool;
    def _is_standalone_comment(self: CommentInjectionPass, part: doc.DocType) -> bool;
    def _is_comment_with_line(self: CommentInjectionPass, part: doc.DocType) -> bool;
    def _strip_trailing_line_from_comment(
        self: CommentInjectionPass, comment: doc.DocType
    ) -> doc.DocType;

    def _ends_with_hard_line(
        self: CommentInjectionPass, sink: Sequence[doc.DocType]
    ) -> bool;

    def _collapse_duplicate_hard_lines(
        self: CommentInjectionPass, sink: list[doc.DocType]
    ) -> None;

    def _ends_with_inline_comment_line(
        self: CommentInjectionPass, <>node: doc.DocType
    ) -> bool;

    def _remove_trailing_line_from_inline_comment(
        self: CommentInjectionPass, <>node: doc.DocType
    ) -> doc.DocType;

    def _remove_redundant_lines(
        self: CommentInjectionPass, <>node: doc.DocType
    ) -> doc.DocType;
}
