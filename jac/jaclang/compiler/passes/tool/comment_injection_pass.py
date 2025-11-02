"""Pass to inject comments using token-level precision."""

from __future__ import annotations

from bisect import bisect_left
from dataclasses import dataclass
from typing import Dict, List, Sequence

import jaclang.compiler.passes.tool.doc_ir as doc
import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import Transform


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
        inline: Dict[int, List[CommentInfo]],
        standalone: List[CommentInfo],
    ) -> None:
        self._inline: Dict[int, List[CommentInfo]] = inline
        self._standalone: List[CommentInfo] = standalone
        self._standalone_lines: List[int] = [c.first_line for c in standalone]
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

        inline: Dict[int, List[CommentInfo]] = {}
        standalone: list[CommentInfo] = []

        for offset, entry in enumerate(items):
            if entry[0] != "comment":
                continue

            comment_idx, comment = entry[1], entry[2]

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
    """
    Injects comments using token sequence analysis for perfect precision.

    Uses src_terminals to detect inline vs standalone comments, then
    injects them using source_token annotations with automatic duplicate
    Line collapsing.
    """

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Inject comments using token-level precision."""
        # Initialize comment store
        self._comments: CommentStore | None = None
        if isinstance(ir_in, uni.Module):
            self._comments = CommentStore.from_module(ir_in)

        # Early return if not a module or no comments
        if not isinstance(ir_in, uni.Module) or not self._comments:
            return ir_in

        # Process the document IR
        processed = self._process(ir_in, ir_in.gen.doc_ir)

        # Append any comments that could not be matched to a location (paranoid safety net)
        leftovers = self._comments.drain_unattached()
        if leftovers:
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
            return doc.Concat(self._inject_into_parts(node.parts, ctx), ast_node=ctx)
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
                return self._handle_body(ctx, node)
            return doc.Indent(self._process(ctx, node.contents), ast_node=ctx)
        elif isinstance(node, doc.IfBreak):
            return doc.IfBreak(
                self._process(ctx, node.break_contents),
                self._process(ctx, node.flat_contents),
            )
        elif isinstance(node, doc.Align):
            return doc.Align(self._process(ctx, node.contents), node.n)
        return node

    def _inject_into_parts(
        self, parts: list[doc.DocType], ctx: uni.UniNode
    ) -> list[doc.DocType]:
        """Inject comments into a parts list using token detection."""
        result = []

        for index, part in enumerate(parts):
            processed = self._process(ctx, part)
            result.append(processed)

            # Find tokens in this part and inject their inline comments
            tokens = self._get_tokens(processed)
            if tokens and self._comments:
                last_token = max(tokens, key=lambda t: (t.loc.last_line, t.loc.col_end))
                token_id = id(last_token)

                for info in self._comments.take_inline(token_id):
                    add_line = True
                    if index + 1 < len(parts):
                        next_part = parts[index + 1]
                        # Don't add line if next part starts with a line or is a standalone comment
                        if self._starts_with_line(
                            next_part
                        ) or self._is_standalone_comment(next_part):
                            add_line = False

                    result.append(
                        self._make_inline_comment(info.token, add_line=add_line)
                    )

        return result

    def _get_tokens(self, node: doc.DocType) -> list[uni.Token]:
        """Extract source tokens (visitor pattern for type safety)."""
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

    def _handle_module(self, module: uni.Module, concat: doc.Concat) -> doc.Concat:
        """Handle module-level comment injection."""
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

    def _handle_body(self, node: uni.UniNode, indent: doc.Indent) -> doc.Indent:
        """Handle body comment injection."""
        if not isinstance(node.body, Sequence) or not isinstance(
            indent.contents, doc.Concat
        ):
            return indent

        # Find body start and end
        body_start = next(
            (
                k.loc.last_line + 1
                for k in node.kid
                if isinstance(k, uni.Token) and k.name == Tok.LBRACE and k.loc
            ),
            None,
        )
        body_end = next(
            (
                k.loc.first_line
                for k in node.kid
                if isinstance(k, uni.Token) and k.name == Tok.RBRACE and k.loc
            ),
            None,
        )
        if not body_start:
            return indent

        result = []
        current_line = body_start
        body_idx = 0
        parts_with_standalone = []

        # First pass: inject standalone comments before body items
        for part in indent.contents.parts:
            if isinstance(part, doc.Line):
                parts_with_standalone.append(part)
                continue

            # Check if this part corresponds to a body item by examining its tokens
            part_line = None
            tokens = self._get_tokens(part)
            if tokens:
                part_line = min(t.loc.first_line for t in tokens if t.loc)

            # If we have a part_line and there are more body items to process
            if part_line and body_idx < len(node.body):
                # Check if this part belongs to the current body item or a later one
                while body_idx < len(node.body):
                    body_item = node.body[body_idx]
                    if not body_item.loc:
                        body_idx += 1
                        continue

                    # If part is before current body item, don't increment body_idx
                    if part_line < body_item.loc.first_line:
                        break

                    # If part is part of current body item or after it
                    # Add standalone comments before this body item
                    prev_item_line = (
                        node.body[body_idx - 1].loc.last_line
                        if body_idx > 0 and node.body[body_idx - 1].loc
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

                    # If part is within or at the body item, process it and move to next body item
                    if part_line <= body_item.loc.last_line:
                        body_idx += 1
                        break
                    else:
                        # Part is after this body item, move to next body item
                        body_idx += 1

            parts_with_standalone.append(part)

        # Second pass: process all parts with inline comment injection
        result = self._inject_into_parts(parts_with_standalone, node)

        # Add any remaining comments after all body items but before closing brace
        if body_end and node.body:
            last_body_line = (
                node.body[-1].loc.last_line if node.body[-1].loc else current_line - 1
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

        return doc.Indent(doc.Concat(result), ast_node=node)

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
                if not self._ends_with_hard_line(sink):
                    sink.append(doc.Line(hard=True))
            else:
                self._collapse_duplicate_hard_lines(sink)

            sink.append(self._make_standalone_comment(info.token))
            last_line = info.last_line
            prev_comment_line = comment_line

        return last_line

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

    def _ends_with_hard_line(self, sink: Sequence[doc.DocType]) -> bool:
        """Return True when the sink already ends with a hard line break."""

        return bool(sink) and isinstance(sink[-1], doc.Line) and sink[-1].hard

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

    def _is_inline_comment_with_line(self, part: doc.DocType) -> bool:
        """Check if a doc part is an inline comment with a hard line break."""
        if isinstance(part, doc.Concat) and len(part.parts) == 3:
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

    def _ends_with_inline_comment_line(self, node: doc.DocType) -> bool:
        """Check if a node ends with an inline comment that has a hard line break."""
        if self._is_inline_comment_with_line(node):
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
        if self._is_inline_comment_with_line(node):
            # Remove the last part (the Line)
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

                # Check if this part ends with an inline comment with a hard line
                # and is followed by a standalone comment
                if (
                    self._ends_with_inline_comment_line(processed_part)
                    and i + 1 < len(node.parts)
                    and self._is_standalone_comment(node.parts[i + 1])
                ):
                    # Remove the trailing hard line from the inline comment
                    processed_part = self._remove_trailing_line_from_inline_comment(
                        processed_part
                    )
                    new_parts.append(processed_part)
                    # Standalone comment already has its line break, so just add a line to separate
                    new_parts.append(doc.Line(hard=True))
                    # Process and add the standalone comment
                    next_part = self._remove_redundant_lines(node.parts[i + 1])
                    # Remove the line from the standalone comment since we already added one
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

                # Check if any part ends with an inline comment with hard line followed by hard Line
                # This creates double line breaks - remove the comment's line
                if (
                    self._ends_with_inline_comment_line(processed_part)
                    and i + 1 < len(node.parts)
                    and isinstance(node.parts[i + 1], doc.Line)
                    and node.parts[i + 1].hard
                ):
                    # Remove the inline comment's hard line - the next hard Line will handle it
                    processed_part = self._remove_trailing_line_from_inline_comment(
                        processed_part
                    )

                # Check if this is an Indent ending with inline/standalone comment followed by soft Line
                # This creates unwanted blank lines - fix by replacing with single hard line
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
                    and i + 1 < len(node.parts)
                    and isinstance(node.parts[i + 1], doc.Line)
                    and not node.parts[i + 1].hard  # Only for soft lines
                ):
                    # Remove comment's line and replace soft Line with hard Line
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
                        # Remove line from standalone comment
                        indent_parts = list(processed_part.contents.parts)
                        last_comment = indent_parts[-1]
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
                    new_parts.append(
                        doc.Line(hard=True)
                    )  # Always use hard line for proper dedent
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
