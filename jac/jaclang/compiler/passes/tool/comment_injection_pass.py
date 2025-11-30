"""Pass to inject comments using token-level precision.

This pass injects comments into the DocIR structure by:
1. Categorizing comments as inline (same line as token) or standalone
2. Injecting inline comments after their anchor tokens
3. Injecting standalone comments at appropriate positions (module, body, params)
4. Handling spacing adjustments for empty structures that receive comments
"""

from __future__ import annotations

from bisect import bisect_left
from collections.abc import Sequence
from dataclasses import dataclass
from typing import NamedTuple

import jaclang.compiler.passes.tool.doc_ir as doc
import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import Transform


class DelimiterInfo(NamedTuple):
    """Information about a pair of delimiters and their positions."""

    open_idx: int
    close_idx: int
    open_line: int
    close_line: int


@dataclass(slots=True)
class CommentInfo:
    """Rich metadata about a source comment."""

    index: int
    token: uni.CommentToken
    anchor_token_id: int | None

    @property
    def is_inline(self) -> bool:
        """Return True when the comment attaches to a token on the same line."""
        return self.anchor_token_id is not None

    @property
    def first_line(self) -> int:
        """Return the starting line for quick range comparisons."""
        return self.token.loc.first_line

    @property
    def last_line(self) -> int:
        """Return the final line this comment occupies."""
        return self.token.loc.last_line


class CommentStore:
    """Efficient bookkeeping for inline and standalone comments."""

    def __init__(
        self,
        inline: dict[int, list[CommentInfo]],
        standalone: list[CommentInfo],
    ) -> None:
        self._inline: dict[int, list[CommentInfo]] = inline
        self._standalone: list[CommentInfo] = standalone
        self._standalone_lines: list[int] = [c.first_line for c in standalone]
        self._used: set[int] = set()

    @classmethod
    def from_module(cls, module: uni.Module) -> CommentStore:
        """Build a comment store by analysing module tokens once."""
        items: list[tuple[str, int, uni.Token | uni.CommentToken]] = []

        for token in module.src_terminals:
            if not isinstance(token, uni.CommentToken):
                items.append(("token", id(token), token))

        for idx, comment in enumerate(module.source.comments):
            items.append(("comment", idx, comment))

        items.sort(key=lambda entry: (entry[2].loc.first_line, entry[2].loc.col_start))

        inline: dict[int, list[CommentInfo]] = {}
        standalone: list[CommentInfo] = []

        for offset, entry in enumerate(items):
            if entry[0] != "comment":
                continue

            comment_idx = entry[1]
            comment_raw = entry[2]
            if not isinstance(comment_raw, uni.CommentToken):
                continue
            comment = comment_raw

            left_token = None
            for i in range(offset - 1, -1, -1):
                if items[i][0] == "token":
                    left_token = items[i][2]
                    break

            anchor_token_id: int | None = None
            if left_token and left_token.loc.last_line == comment.loc.first_line:
                anchor_token_id = id(left_token)

            info = CommentInfo(comment_idx, comment, anchor_token_id)

            if info.is_inline:
                assert info.anchor_token_id is not None
                inline.setdefault(info.anchor_token_id, []).append(info)
            else:
                standalone.append(info)

        # Preserve source ordering for deterministic emission
        for collection in inline.values():
            collection.sort(key=lambda c: (c.first_line, c.index))

        standalone.sort(key=lambda c: (c.first_line, c.index))

        return cls(inline, standalone)

    def _mark_used(self, info: CommentInfo) -> bool:
        if info.index in self._used:
            return False
        self._used.add(info.index)
        return True

    def take_inline(self, token_id: int) -> list[CommentInfo]:
        """Return inline comments attached to a given token in source order."""
        matches = []
        for info in self._inline.get(token_id, []):
            if self._mark_used(info):
                matches.append(info)
        return matches

    def take_standalone_between(
        self, start_line: int, end_line: int
    ) -> list[CommentInfo]:
        """Return standalone comments within [start_line, end_line)."""
        if start_line >= end_line:
            return []
        idx = bisect_left(self._standalone_lines, start_line)
        result: list[CommentInfo] = []
        while idx < len(self._standalone):
            info = self._standalone[idx]
            if info.first_line >= end_line:
                break
            if self._mark_used(info):
                result.append(info)
            idx += 1
        return result

    def take_standalone_after(self, start_line: int) -> list[CommentInfo]:
        """Drain standalone comments that occur on or after start_line."""
        idx = bisect_left(self._standalone_lines, start_line)
        result: list[CommentInfo] = []
        while idx < len(self._standalone):
            info = self._standalone[idx]
            if self._mark_used(info):
                result.append(info)
            idx += 1
        return result

    def drain_unattached(self) -> list[CommentInfo]:
        """Return comments we never placed (should be rare)."""
        leftovers: list[CommentInfo] = []
        for bucket in self._inline.values():
            for info in bucket:
                if self._mark_used(info):
                    leftovers.append(info)
        for info in self._standalone:
            if self._mark_used(info):
                leftovers.append(info)
        leftovers.sort(key=lambda c: (c.first_line, c.index))
        return leftovers


class CommentInjectionPass(Transform[uni.Module, uni.Module]):
    """Injects comments using token sequence analysis for perfect precision.

    Uses src_terminals to detect inline vs standalone comments, then
    injects them using source_token annotations with automatic duplicate
    line collapsing.
    """

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Inject comments using token-level precision."""
        self._comments: CommentStore | None = None
        if isinstance(ir_in, uni.Module):
            self._comments = CommentStore.from_module(ir_in)

        if not isinstance(ir_in, uni.Module) or not self._comments:
            return ir_in

        # Process the document IR
        processed = self._process(ir_in, ir_in.gen.doc_ir)

        # Check for any leftover comments that couldn't be placed
        leftovers = self._comments.drain_unattached()
        if leftovers:
            # Emit errors for each unplaced comment
            for info in leftovers:
                comment_preview = info.token.value[:50]
                if len(info.token.value) > 50:
                    comment_preview += "..."
                self.log_error(
                    f"Comment could not be placed and would float to bottom: "
                    f"{comment_preview!r} at line {info.first_line}",
                    node_override=ir_in,
                )

            # Still append comments to output (so they're not lost)
            sink: list[doc.DocType] = [processed]
            self._emit_standalone_comments(
                sink,
                leftovers,
                prev_item_line=ir_in.loc.last_line if ir_in.loc else None,
            )
            processed = doc.Concat(sink)

        # Post-process to remove unnecessary line breaks after inline comments
        ir_in.gen.doc_ir = self._remove_redundant_lines(processed)

        return ir_in

    def _process(self, ctx: uni.UniNode, node: doc.DocType) -> doc.DocType:
        """Main recursive processor with type-specific handling."""
        if isinstance(node, doc.Concat):
            ctx = node.ast_node if node.ast_node else ctx
            if isinstance(ctx, uni.Module):
                return self._handle_module(ctx, node)
            if isinstance(ctx, (uni.MatchStmt, uni.SwitchStmt)):
                return self._handle_match_stmt_comments(ctx, node)

            processed_parts = self._inject_into_parts(node.parts, ctx)

            # Apply context-specific transformations
            if isinstance(ctx, uni.FuncSignature):
                processed_parts = self._handle_param_list_comments(ctx, processed_parts)
            processed_parts = self._fix_empty_region_spacing(processed_parts)

            return doc.Concat(processed_parts, ast_node=ctx)

        elif isinstance(node, doc.Group):
            ctx = node.ast_node if node.ast_node else ctx
            return doc.Group(
                self._process(ctx, node.contents),
                node.break_contiguous,
                node.id,
                ast_node=ctx,
            )

        elif isinstance(node, doc.Indent):
            ctx = node.ast_node if node.ast_node else ctx
            if node.ast_node and getattr(ctx, "body", None) is not None:
                return self._handle_body_comments(ctx, node)
            return doc.Indent(self._process(ctx, node.contents), ast_node=ctx)

        elif isinstance(node, doc.IfBreak):
            return doc.IfBreak(
                self._process(ctx, node.break_contents),
                self._process(ctx, node.flat_contents),
            )

        elif isinstance(node, doc.Align):
            return doc.Align(self._process(ctx, node.contents), node.n)

        return node

    # ========================================================================
    # HELPER METHODS: Token and delimiter detection
    # ========================================================================

    def _find_delimiters(
        self, parts: list[doc.DocType], open_tok: Tok, close_tok: Tok
    ) -> DelimiterInfo | None:
        """Find opening and closing delimiter tokens and their line numbers.

        Returns: DelimiterInfo if both delimiters found, None otherwise
        """
        open_idx: int | None = None
        open_line: int | None = None
        close_idx: int | None = None
        close_line: int | None = None

        for i, part in enumerate(parts):
            if not isinstance(part, doc.Text):
                continue

            if part.source_token:
                if part.source_token.name == open_tok and open_idx is None:
                    open_idx, open_line = i, part.source_token.loc.last_line
                elif part.source_token.name == close_tok:
                    close_idx, close_line = i, part.source_token.loc.first_line

        # Return DelimiterInfo only if all values are found
        if (
            open_idx is not None
            and close_idx is not None
            and open_line is not None
            and close_line is not None
        ):
            return DelimiterInfo(open_idx, close_idx, open_line, close_line)

        return None

    def _get_tokens(self, node: doc.DocType) -> list[uni.Token]:
        """Extract source tokens from a DocIR node (visitor pattern)."""
        if isinstance(node, doc.Text):
            return [node.source_token] if node.source_token else []
        elif isinstance(node, (doc.Concat, doc.Group, doc.Indent, doc.Align)):
            tokens = []
            children = node.parts if isinstance(node, doc.Concat) else [node.contents]
            for child in children:
                tokens.extend(self._get_tokens(child))
            return tokens
        elif isinstance(node, doc.IfBreak):
            return self._get_tokens(node.break_contents) + self._get_tokens(
                node.flat_contents
            )
        return []

    # ========================================================================
    # CORE INJECTION METHODS
    # ========================================================================

    def _inject_into_parts(
        self, parts: list[doc.DocType], ctx: uni.UniNode
    ) -> list[doc.DocType]:
        """Inject inline comments after their anchor tokens."""
        result: list[doc.DocType] = []

        for index, part in enumerate(parts):
            processed = self._process(ctx, part)
            result.append(processed)

            # Find tokens in this part and inject their inline comments
            tokens = self._get_tokens(processed)
            if tokens and self._comments:
                last_token = max(tokens, key=lambda t: (t.loc.last_line, t.loc.col_end))
                token_id: int = id(last_token)

                for info in self._comments.take_inline(token_id):
                    # Determine if we should add a line break after the comment
                    add_line: bool = True
                    if index + 1 < len(parts):
                        next_part = parts[index + 1]
                        if self._starts_with_line(
                            next_part
                        ) or self._is_standalone_comment(next_part):
                            add_line = False

                    result.append(
                        self._make_inline_comment(info.token, add_line=add_line)
                    )

        return result

    def _handle_module(self, module: uni.Module, concat: doc.Concat) -> doc.Concat:
        """Handle module-level comment injection between top-level statements."""
        if not self._comments:
            return doc.Concat(
                [self._process(module, part) for part in concat.parts],
                ast_node=module,
            )

        result: list[doc.DocType] = []
        child_idx = 0
        prev_item_line: int | None = None

        for part in concat.parts:
            if isinstance(part, doc.Line):
                result.append(part)
                continue

            if child_idx < len(module.kid):
                child = module.kid[child_idx]

                if child.loc:
                    # Inject standalone comments before this child
                    comments = self._comments.take_standalone_between(
                        (prev_item_line + 1) if prev_item_line is not None else 1,
                        child.loc.first_line,
                    )
                    if comments:
                        prev_item_line = self._emit_standalone_comments(
                            result,
                            comments,
                            prev_item_line=prev_item_line,
                        )

                result.append(self._process(child, part))
                if child.loc:
                    prev_item_line = child.loc.last_line
                child_idx += 1
            else:
                result.append(self._process(module, part))

        # Inject trailing comments
        trailing = self._comments.take_standalone_after(
            (prev_item_line + 1) if prev_item_line is not None else 1
        )
        if trailing:
            self._emit_standalone_comments(
                result,
                trailing,
                prev_item_line=prev_item_line,
            )

        return doc.Concat(result, ast_node=module)

    def _handle_match_stmt_comments(
        self, match_node: uni.UniNode, concat: doc.Concat
    ) -> doc.Concat:
        """Handle comment injection between cases in match/switch statements."""
        if not self._comments:
            return doc.Concat(
                [self._process(match_node, part) for part in concat.parts],
                ast_node=match_node,
            )

        # Get cases from the match statement
        cases: list[uni.UniNode] = []
        if isinstance(match_node, uni.MatchStmt | uni.SwitchStmt):
            cases = list(match_node.cases)

        # Find the opening brace line
        brace_line: int | None = next(
            (
                k.loc.last_line
                for k in match_node.kid
                if isinstance(k, uni.Token) and k.name == Tok.LBRACE and k.loc
            ),
            None,
        )

        result: list[doc.DocType] = []
        case_idx = 0
        prev_item_line: int | None = brace_line

        for part in concat.parts:
            if isinstance(part, doc.Line):
                result.append(part)
                continue

            # Check if this part corresponds to a case
            tokens = self._get_tokens(part)
            part_line = min((t.loc.first_line for t in tokens if t.loc), default=None)

            if case_idx < len(cases) and part_line:
                case = cases[case_idx]
                if case.loc and part_line >= case.loc.first_line:
                    # Inject comments before this case
                    start_line = (prev_item_line + 1) if prev_item_line else 1
                    comments = self._comments.take_standalone_between(
                        start_line, case.loc.first_line
                    )
                    if comments:
                        prev_item_line = self._emit_standalone_comments(
                            result,
                            comments,
                            prev_item_line=prev_item_line,
                        )

                    result.append(self._process(case, part))
                    if case.loc:
                        prev_item_line = case.loc.last_line
                    case_idx += 1
                    continue

            result.append(self._process(match_node, part))

        return doc.Concat(result, ast_node=match_node)

    def _handle_body_comments(
        self, node: uni.UniNode, indent: doc.Indent
    ) -> doc.Indent:
        """Handle comment injection within bodies (functions, classes, etc)."""
        if not hasattr(node, "body"):
            return indent
        body = node.body  # type: ignore[attr-defined]
        if not isinstance(body, Sequence) or not isinstance(
            indent.contents, doc.Concat
        ):
            return indent

        # Find body boundaries
        body_start: int | None = next(
            (
                k.loc.last_line + 1
                for k in node.kid
                if isinstance(k, uni.Token) and k.name == Tok.LBRACE and k.loc
            ),
            None,
        )
        body_end: int | None = next(
            (
                k.loc.first_line
                for k in node.kid
                if isinstance(k, uni.Token) and k.name == Tok.RBRACE and k.loc
            ),
            None,
        )

        # For match/switch cases that use COLON instead of braces
        if body_start is None and isinstance(node, (uni.MatchCase, uni.SwitchCase)):
            body_start = next(
                (
                    k.loc.last_line + 1
                    for k in node.kid
                    if isinstance(k, uni.Token) and k.name == Tok.COLON and k.loc
                ),
                None,
            )
            # For cases without closing brace, use last body item's line or node's end
            if body and body[-1].loc:
                body_end = body[-1].loc.last_line + 1
            elif node.loc:
                body_end = node.loc.last_line + 1

        if body_start is None:
            return indent

        # First pass: inject standalone comments before body items
        result: list[doc.DocType] = []
        current_line: int = body_start
        body_idx: int = 0
        parts_with_standalone: list[doc.DocType] = []

        for part in indent.contents.parts:
            if isinstance(part, doc.Line):
                parts_with_standalone.append(part)
                continue

            # Get the line number of this part
            part_line: int | None = None
            tokens = self._get_tokens(part)
            if tokens:
                part_line = min(t.loc.first_line for t in tokens if t.loc)

            # Inject comments before matching body items
            if part_line and body_idx < len(body):
                while body_idx < len(body):
                    body_item = body[body_idx]
                    if not body_item.loc:
                        body_idx += 1
                        continue

                    if part_line < body_item.loc.first_line:
                        break

                    prev_item_line = (
                        body[body_idx - 1].loc.last_line
                        if body_idx > 0 and body[body_idx - 1].loc
                        else current_line - 1
                    )

                    comments = []
                    if self._comments:
                        comments = self._comments.take_standalone_between(
                            current_line,
                            body_item.loc.first_line,
                        )

                    if comments:
                        prev_item_line = self._emit_standalone_comments(
                            parts_with_standalone,
                            comments,
                            prev_item_line=prev_item_line,
                        )

                    current_line = body_item.loc.last_line + 1

                    if part_line <= body_item.loc.last_line:
                        body_idx += 1
                        break
                    else:
                        body_idx += 1

            parts_with_standalone.append(part)

        # Second pass: process all parts with inline comment injection
        result = self._inject_into_parts(parts_with_standalone, node)

        # Handle trailing comments and empty bodies
        if body_end is not None:
            if body:
                # Non-empty body: add comments after last item
                last_body_line = (
                    body[-1].loc.last_line if body[-1].loc else current_line - 1
                )
                comments = []
                if self._comments:
                    comments = self._comments.take_standalone_between(
                        last_body_line + 1,
                        body_end,
                    )

                if comments:
                    self._emit_standalone_comments(
                        result,
                        comments,
                        prev_item_line=last_body_line,
                    )
                    # Remove trailing line (will be added outside Indent)
                    if result and self._is_comment_with_line(result[-1]):
                        result[-1] = self._strip_trailing_line_from_comment(result[-1])
            else:
                # Empty body: inject comments between braces
                comments = []
                if self._comments:
                    comments = self._comments.take_standalone_between(
                        body_start,
                        body_end,
                    )

                if comments:
                    result.append(doc.Line(hard=True))
                    self._emit_standalone_comments(
                        result,
                        comments,
                        prev_item_line=body_start - 1,
                    )
                    # Remove trailing line (will be added outside Indent)
                    if result and self._is_comment_with_line(result[-1]):
                        result[-1] = self._strip_trailing_line_from_comment(result[-1])

        return doc.Indent(doc.Concat(result), ast_node=node)

    def _handle_param_list_comments(
        self, sig: uni.FuncSignature, parts: list[doc.DocType]
    ) -> list[doc.DocType]:
        """Handle comment injection within parameter lists."""
        if not self._comments:
            return parts

        # Find parentheses
        delim = self._find_delimiters(parts, Tok.LPAREN, Tok.RPAREN)
        if delim is None:
            return parts

        # Find comments between parentheses
        comments = self._comments.take_standalone_between(
            delim.open_line + 1,
            delim.close_line,
        )

        if not comments:
            return parts

        # Find Indent node (present if params are formatted across multiple lines)
        indent_idx = next(
            (i for i, p in enumerate(parts) if isinstance(p, doc.Indent)), None
        )

        if not sig.params:
            # Empty parameter list: create new indent with comments
            result = list(parts[: delim.open_idx + 1])
            comment_parts: list[doc.DocType] = [doc.Line(hard=True, tight=True)]

            for info in comments:
                comment_parts.append(doc.Text(info.token.value))
                comment_parts.append(doc.Line(hard=True))

            if comment_parts and isinstance(comment_parts[-1], doc.Line):
                comment_parts.pop()

            result.append(doc.Indent(doc.Concat(comment_parts)))
            result.append(doc.Line(hard=True, tight=True))
            result.extend(parts[delim.close_idx :])
            return result

        # Non-empty parameter list: append comments to existing structure
        if indent_idx is not None:
            result = list(parts)
            indent_part = result[indent_idx]

            if isinstance(indent_part, doc.Indent) and isinstance(
                indent_part.contents, doc.Concat
            ):
                new_indent_parts = list(indent_part.contents.parts)

                for info in comments:
                    new_indent_parts.append(doc.Line(hard=True))
                    new_indent_parts.append(doc.Text(info.token.value))

                result[indent_idx] = doc.Indent(
                    doc.Concat(
                        new_indent_parts, ast_node=indent_part.contents.ast_node
                    ),
                    ast_node=indent_part.ast_node,
                )

            return result

        return parts

    def _fix_empty_region_spacing(self, parts: list[doc.DocType]) -> list[doc.DocType]:
        """Fix spacing for empty regions (bodies/params) that now contain comments.

        When DocIR was generated, empty regions had a Space before the closing
        delimiter. After injecting comments, we need a hard line instead.
        """
        result: list[doc.DocType] = []
        i: int = 0
        while i < len(parts):
            part = parts[i]

            # Check for Indent with content followed by a single space
            if (
                isinstance(part, doc.Indent)
                and isinstance(part.contents, doc.Concat)
                and part.contents.parts
                and i + 1 < len(parts)
            ):
                next_part = parts[i + 1]
                if (
                    isinstance(next_part, doc.Text)
                    and next_part.text.strip() == ""
                    and len(next_part.text) <= 1
                ):
                    # Replace single space with hard line
                    result.append(part)
                    result.append(doc.Line(hard=True))
                    i += 2
                    continue

            result.append(part)
            i += 1

        return result

    # ========================================================================
    # COMMENT CREATION AND EMISSION
    # ========================================================================

    def _make_standalone_comment(self, comment: uni.CommentToken) -> doc.DocType:
        """Create standalone comment DocIR."""
        return doc.Concat([doc.Text(comment.value), doc.Line(hard=True)])

    def _make_inline_comment(
        self, comment: uni.CommentToken, add_line: bool = True
    ) -> doc.DocType:
        """Create inline comment DocIR."""
        parts: list[doc.DocType] = [doc.Text("  "), doc.Text(comment.value)]
        if add_line:
            parts.append(doc.Line(hard=True))
        return doc.Concat(parts)

    def _emit_standalone_comments(
        self,
        sink: list[doc.DocType],
        comments: Sequence[CommentInfo],
        *,
        prev_item_line: int | None,
    ) -> int | None:
        """Append standalone comments to sink while preserving vertical spacing."""
        last_line = prev_item_line
        prev_comment_line: int | None = None

        for info in comments:
            comment_line = info.first_line
            should_add_line = (
                prev_comment_line is not None and comment_line > prev_comment_line + 1
            ) or (last_line is not None and comment_line > last_line + 1)

            if should_add_line:
                # Blank line gap in source - add line if sink doesn't end with explicit Line
                # (Concat's trailing hard line is not a blank line, just line break)
                if not sink or not isinstance(sink[-1], doc.Line):
                    sink.append(doc.Line(hard=True))
            else:
                self._collapse_duplicate_hard_lines(sink)
                # Ensure at least one hard line before comment (but not at start of file)
                if sink and not self._ends_with_hard_line(sink):
                    sink.append(doc.Line(hard=True))

            sink.append(self._make_standalone_comment(info.token))
            last_line = info.last_line
            prev_comment_line = comment_line

        return last_line

    # ========================================================================
    # HELPER METHODS: DocIR pattern detection
    # ========================================================================

    def _starts_with_line(self, part: doc.DocType) -> bool:
        """Check whether the given doc part begins with a line break."""
        if isinstance(part, doc.Line):
            return True
        if isinstance(part, doc.Concat):
            for child in part.parts:
                if isinstance(child, doc.Text) and not child.text.strip():
                    continue
                return self._starts_with_line(child)
            return False
        if isinstance(part, doc.Group):
            return self._starts_with_line(part.contents)
        if isinstance(part, doc.Indent):
            return self._starts_with_line(part.contents)
        if isinstance(part, doc.Align):
            return self._starts_with_line(part.contents)
        if isinstance(part, doc.IfBreak):
            return self._starts_with_line(part.break_contents)
        return False

    def _is_standalone_comment(self, part: doc.DocType) -> bool:
        """Check if a doc part is a standalone comment."""
        if isinstance(part, doc.Concat) and len(part.parts) == 2:
            first, second = part.parts
            return (
                isinstance(first, doc.Text)
                and first.text.strip().startswith("#")
                and isinstance(second, doc.Line)
            )
        return False

    def _is_comment_with_line(self, part: doc.DocType) -> bool:
        """Check if a doc part is a comment (inline or standalone) with a hard line."""
        if isinstance(part, doc.Concat):
            if len(part.parts) == 2:  # Standalone comment
                return self._is_standalone_comment(part)
            elif len(part.parts) == 3:  # Inline comment
                first, second, third = part.parts
                return (
                    isinstance(first, doc.Text)
                    and first.text.strip() == ""
                    and isinstance(second, doc.Text)
                    and second.text.strip().startswith("#")
                    and isinstance(third, doc.Line)
                    and third.hard
                )
        return False

    def _strip_trailing_line_from_comment(self, comment: doc.DocType) -> doc.DocType:
        """Remove the trailing hard line from a comment Concat."""
        if (
            isinstance(comment, doc.Concat)
            and len(comment.parts) >= 2
            and isinstance(comment.parts[-1], doc.Line)
            and comment.parts[-1].hard
        ):
            # Return comment without the last hard line
            return doc.Concat(list(comment.parts[:-1]), ast_node=comment.ast_node)
        return comment

    def _ends_with_hard_line(self, sink: Sequence[doc.DocType]) -> bool:
        """Return True when the sink already ends with a hard line break."""
        if not sink:
            return False
        last = sink[-1]
        if isinstance(last, doc.Line) and last.hard:
            return True
        # Check inside Concat (e.g., standalone comments end with hard line)
        if isinstance(last, doc.Concat) and last.parts:
            last_part = last.parts[-1]
            if isinstance(last_part, doc.Line) and last_part.hard:
                return True
        return False

    def _collapse_duplicate_hard_lines(self, sink: list[doc.DocType]) -> None:
        """Ensure we never end up with consecutive hard lines from injection."""
        while (
            len(sink) >= 2
            and isinstance(sink[-1], doc.Line)
            and sink[-1].hard
            and isinstance(sink[-2], doc.Line)
            and sink[-2].hard
        ):
            sink.pop()

    # ========================================================================
    # POST-PROCESSING: Line cleanup
    # ========================================================================

    def _ends_with_inline_comment_line(self, node: doc.DocType) -> bool:
        """Check if a node ends with an inline comment that has a hard line break."""
        if isinstance(node, doc.Concat) and len(node.parts) == 3:
            first, second, third = node.parts
            if (
                isinstance(first, doc.Text)
                and first.text.strip() == ""
                and isinstance(second, doc.Text)
                and second.text.strip().startswith("#")
                and isinstance(third, doc.Line)
                and third.hard
            ):
                return True

        if isinstance(node, doc.Concat) and node.parts:
            return self._ends_with_inline_comment_line(node.parts[-1])
        if isinstance(node, doc.Group):
            return self._ends_with_inline_comment_line(node.contents)
        if isinstance(node, doc.Indent):
            return self._ends_with_inline_comment_line(node.contents)
        return False

    def _remove_trailing_line_from_inline_comment(
        self, node: doc.DocType
    ) -> doc.DocType:
        """Remove the trailing hard line from the last inline comment in the node."""
        if isinstance(node, doc.Concat) and len(node.parts) == 3:
            first, second, third = node.parts
            if (
                isinstance(first, doc.Text)
                and first.text.strip() == ""
                and isinstance(second, doc.Text)
                and second.text.strip().startswith("#")
                and isinstance(third, doc.Line)
                and third.hard
            ):
                return doc.Concat(list(node.parts[:-1]))

        if isinstance(node, doc.Concat) and node.parts:
            new_parts = list(node.parts)
            new_parts[-1] = self._remove_trailing_line_from_inline_comment(
                new_parts[-1]
            )
            return doc.Concat(new_parts, ast_node=node.ast_node)
        if isinstance(node, doc.Group):
            return doc.Group(
                self._remove_trailing_line_from_inline_comment(node.contents),
                node.break_contiguous,
                node.id,
                ast_node=node.ast_node,
            )
        if isinstance(node, doc.Indent):
            return doc.Indent(
                self._remove_trailing_line_from_inline_comment(node.contents),
                ast_node=node.ast_node,
            )
        return node

    def _remove_redundant_lines(self, node: doc.DocType) -> doc.DocType:
        """Remove redundant line breaks after inline comments."""
        if isinstance(node, doc.Concat):
            new_parts = []
            i = 0
            while i < len(node.parts):
                part = node.parts[i]
                processed_part = self._remove_redundant_lines(part)

                # Check for inline comment + standalone comment pattern
                if (
                    self._ends_with_inline_comment_line(processed_part)
                    and i + 1 < len(node.parts)
                    and self._is_standalone_comment(node.parts[i + 1])
                ):
                    processed_part = self._remove_trailing_line_from_inline_comment(
                        processed_part
                    )
                    new_parts.append(processed_part)
                    new_parts.append(doc.Line(hard=True))
                    next_part = self._remove_redundant_lines(node.parts[i + 1])
                    if isinstance(next_part, doc.Concat) and len(next_part.parts) == 2:
                        new_parts.append(
                            doc.Concat(
                                [next_part.parts[0]], ast_node=next_part.ast_node
                            )
                        )
                    else:
                        new_parts.append(next_part)
                    i += 2
                    continue

                # Check for inline comment + hard line pattern
                next_line = node.parts[i + 1] if i + 1 < len(node.parts) else None
                if (
                    self._ends_with_inline_comment_line(processed_part)
                    and isinstance(next_line, doc.Line)
                    and next_line.hard
                ):
                    processed_part = self._remove_trailing_line_from_inline_comment(
                        processed_part
                    )

                # Check for Indent with comment + soft line pattern
                if (
                    isinstance(processed_part, doc.Indent)
                    and (
                        self._ends_with_inline_comment_line(processed_part)
                        or (
                            isinstance(processed_part.contents, doc.Concat)
                            and processed_part.contents.parts
                            and self._is_standalone_comment(
                                processed_part.contents.parts[-1]
                            )
                        )
                    )
                    and isinstance(next_line, doc.Line)
                    and not next_line.hard
                ):
                    if self._ends_with_inline_comment_line(processed_part):
                        processed_part = self._remove_trailing_line_from_inline_comment(
                            processed_part
                        )
                    elif (
                        isinstance(processed_part.contents, doc.Concat)
                        and processed_part.contents.parts
                        and self._is_standalone_comment(
                            processed_part.contents.parts[-1]
                        )
                    ):
                        indent_parts = list(processed_part.contents.parts)
                        last_comment = indent_parts[-1]
                        # _is_standalone_comment guarantees this is a Concat
                        assert isinstance(last_comment, doc.Concat)
                        indent_parts[-1] = doc.Concat(
                            [last_comment.parts[0]], ast_node=last_comment.ast_node
                        )
                        processed_part = doc.Indent(
                            doc.Concat(
                                indent_parts, ast_node=processed_part.contents.ast_node
                            ),
                            ast_node=processed_part.ast_node,
                        )

                    new_parts.append(processed_part)
                    new_parts.append(doc.Line(hard=True))
                    i += 2
                    continue

                new_parts.append(processed_part)
                i += 1

            return doc.Concat(new_parts, ast_node=node.ast_node)

        elif isinstance(node, doc.Group):
            return doc.Group(
                self._remove_redundant_lines(node.contents),
                node.break_contiguous,
                node.id,
                ast_node=node.ast_node,
            )
        elif isinstance(node, doc.Indent):
            return doc.Indent(
                self._remove_redundant_lines(node.contents),
                ast_node=node.ast_node,
            )
        elif isinstance(node, doc.IfBreak):
            return doc.IfBreak(
                self._remove_redundant_lines(node.break_contents),
                self._remove_redundant_lines(node.flat_contents),
            )
        elif isinstance(node, doc.Align):
            return doc.Align(self._remove_redundant_lines(node.contents), node.n)

        return node
