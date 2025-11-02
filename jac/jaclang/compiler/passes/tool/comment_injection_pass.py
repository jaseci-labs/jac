"""Pass to inject comments using token-level precision."""

from typing import Sequence, Set

import jaclang.compiler.passes.tool.doc_ir as doc
import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import Transform


class CommentInjectionPass(Transform[uni.Module, uni.Module]):
    """
    Injects comments using token sequence analysis for perfect precision.

    Uses src_terminals to detect inline vs standalone comments, then
    injects them using source_token annotations with automatic duplicate
    Line collapsing.
    """

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """Inject comments using token-level precision."""
        # Initialize state
        self.inline_comment_ids: Set[int] = set()
        self.used_comments: Set[int] = set()
        self.token_to_comment: dict[int, list[tuple[int, uni.CommentToken]]] = {}
        self.ir_out = ir_in  # Set for helper methods to access

        if isinstance(ir_in, uni.Module):
            self._analyze_comments()
            ir_in.gen.doc_ir = self._process(ir_in, ir_in.gen.doc_ir)
            # Post-process to remove unnecessary line breaks after inline comments
            ir_in.gen.doc_ir = self._remove_redundant_lines(ir_in.gen.doc_ir)

        return ir_in

    def _analyze_comments(self) -> None:
        """Analyze token sequence to detect inline comments and build lookup map."""
        # Merge tokens + comments in source order
        items: list[tuple[str, int, uni.Token | uni.CommentToken]] = []

        for token in self.ir_out.src_terminals:
            if not isinstance(token, uni.CommentToken):
                items.append(("token", id(token), token))

        for idx, comment in enumerate(self.ir_out.source.comments):
            items.append(("comment", idx, comment))

        items.sort(key=lambda x: (x[2].loc.first_line, x[2].loc.col_start))

        # Analyze each comment
        for i, item in enumerate(items):
            if item[0] != "comment":
                continue

            comment_idx, comment = item[1], item[2]

            # Find left neighbor token
            left_token = None
            for j in range(i - 1, -1, -1):
                if items[j][0] == "token":
                    left_token = items[j][2]
                    break

            # Detect inline (comment on same line as left token)
            if left_token and left_token.loc.last_line == comment.loc.first_line:
                self.inline_comment_ids.add(comment_idx)
                # Map left_token -> comment for injection
                token_id = id(left_token)
                if token_id not in self.token_to_comment:
                    self.token_to_comment[token_id] = []
                self.token_to_comment[token_id].append((comment_idx, comment))

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

        for i, part in enumerate(parts):
            processed = self._process(ctx, part)
            result.append(processed)

            # Find tokens in this part and inject their inline comments
            tokens = self._get_tokens(processed)
            if tokens:
                last_token = max(tokens, key=lambda t: (t.loc.last_line, t.loc.col_end))
                token_id = id(last_token)

                if token_id in self.token_to_comment:
                    for comment_idx, comment in self.token_to_comment[token_id]:
                        if comment_idx not in self.used_comments:
                            add_line = True
                            if i + 1 < len(parts):
                                next_part = parts[i + 1]
                                # Don't add line if next part starts with a line or is a standalone comment
                                if self._starts_with_line(
                                    next_part
                                ) or self._is_standalone_comment(next_part):
                                    add_line = False

                            result.append(
                                self._make_inline_comment(comment, add_line=add_line)
                            )

                            self.used_comments.add(comment_idx)

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
        result = []
        current_line = 1
        child_idx = 0

        for part in concat.parts:
            if isinstance(part, doc.Line):
                result.append(part)
                continue

            if child_idx < len(module.kid):
                child = module.kid[child_idx]

                # Add standalone comments before child
                if child.loc:
                    prev_comment = None
                    prev_item_line = (
                        module.kid[child_idx - 1].loc.last_line
                        if child_idx > 0 and module.kid[child_idx - 1].loc
                        else 0
                    )

                    for idx, comment in enumerate(self.ir_out.source.comments):
                        if (
                            idx not in self.used_comments
                            and idx not in self.inline_comment_ids
                            and current_line
                            <= comment.loc.first_line
                            < child.loc.first_line
                        ):
                            # Check if we need a blank line before this comment
                            should_add_line = (
                                prev_comment
                                and comment.loc.first_line
                                > prev_comment.loc.last_line + 1
                            ) or (
                                prev_item_line > 0
                                and comment.loc.first_line > prev_item_line + 1
                            )

                            # If comment immediately follows previous item but there's a
                            # gap line (two consecutive hard lines),
                            # remove one to avoid double spacing
                            if (
                                not should_add_line
                                and len(result) >= 2
                                and isinstance(result[-1], doc.Line)
                                and result[-1].hard
                                and isinstance(result[-2], doc.Line)
                                and result[-2].hard
                            ):
                                result.pop()

                            if should_add_line and not (
                                result
                                and isinstance(result[-1], doc.Line)
                                and result[-1].hard
                            ):
                                result.append(doc.Line(hard=True))

                            result.append(self._make_standalone_comment(comment))
                            self.used_comments.add(idx)
                            prev_comment = comment

                    current_line = child.loc.last_line + 1

                result.append(self._process(child, part))
                child_idx += 1
            else:
                result.append(self._process(module, part))

        # Safety net: Add unused comments
        for idx, comment in enumerate(self.ir_out.source.comments):
            if idx not in self.used_comments:
                result.append(
                    self._make_inline_comment(comment)
                    if idx in self.inline_comment_ids
                    else self._make_standalone_comment(comment)
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
                    prev_comment = None
                    prev_item_line = (
                        node.body[body_idx - 1].loc.last_line
                        if body_idx > 0 and node.body[body_idx - 1].loc
                        else current_line - 1
                    )

                    for idx, comment in enumerate(self.ir_out.source.comments):
                        if (
                            idx not in self.used_comments
                            and idx not in self.inline_comment_ids
                            and current_line
                            <= comment.loc.first_line
                            < body_item.loc.first_line
                        ):
                            # Check if we need a blank line before this comment
                            should_add_line = (
                                prev_comment
                                and comment.loc.first_line
                                > prev_comment.loc.last_line + 1
                            ) or (
                                prev_item_line > 0
                                and comment.loc.first_line > prev_item_line + 1
                            )

                            # If comment immediately follows previous item but '
                            # there's a gap line (two consecutive hard lines),
                            # remove one to avoid double spacing
                            if (
                                not should_add_line
                                and len(parts_with_standalone) >= 2
                                and isinstance(parts_with_standalone[-1], doc.Line)
                                and parts_with_standalone[-1].hard
                                and isinstance(parts_with_standalone[-2], doc.Line)
                                and parts_with_standalone[-2].hard
                            ):
                                parts_with_standalone.pop()

                            if should_add_line and not (
                                parts_with_standalone
                                and isinstance(parts_with_standalone[-1], doc.Line)
                                and parts_with_standalone[-1].hard
                            ):
                                parts_with_standalone.append(doc.Line(hard=True))

                            parts_with_standalone.append(
                                self._make_standalone_comment(comment)
                            )
                            self.used_comments.add(idx)
                            prev_comment = comment

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
            prev_comment = None

            for idx, comment in enumerate(self.ir_out.source.comments):
                if (
                    idx not in self.used_comments
                    and idx not in self.inline_comment_ids
                    and last_body_line < comment.loc.first_line < body_end
                ):
                    # Check if we need a blank line before this comment
                    should_add_line = (
                        prev_comment
                        and comment.loc.first_line > prev_comment.loc.last_line + 1
                    ) or (comment.loc.first_line > last_body_line + 1)

                    # If comment immediately follows previous item but there's a gap line (two consecutive hard lines),
                    # remove one to avoid double spacing
                    if (
                        not should_add_line
                        and len(result) >= 2
                        and isinstance(result[-1], doc.Line)
                        and result[-1].hard
                        and isinstance(result[-2], doc.Line)
                        and result[-2].hard
                    ):
                        result.pop()

                    if should_add_line and not (
                        result and isinstance(result[-1], doc.Line) and result[-1].hard
                    ):
                        result.append(doc.Line(hard=True))

                    result.append(self._make_standalone_comment(comment))
                    self.used_comments.add(idx)
                    prev_comment = comment

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
