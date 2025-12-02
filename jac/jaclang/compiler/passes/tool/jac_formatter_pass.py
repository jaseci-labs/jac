"""JacFormatPass for Jaseci Ast.

This is a pass for formatting Jac code.
"""

from collections import deque

import jaclang.compiler.passes.tool.doc_ir as doc
import jaclang.compiler.unitree as uni
from jaclang.compiler.passes import Transform
from jaclang.settings import settings


class JacFormatPass(Transform[uni.Module, uni.Module]):
    """JacFormat Pass format Jac code."""

    def pre_transform(self) -> None:
        """Initialize pass."""
        self.indent_size = 4
        self.MAX_LINE_LENGTH = settings.max_line_length

    def _probe_fits(
        self,
        node: doc.DocType,
        indent_level: int,
        width_remaining: int,
        *,
        max_steps: int = 2000,
    ) -> bool:
        """
        Check if flat can be used early.

        returns True if `node` could be printed *flat* on the current line within
        `width_remaining` columns at `indent_level`.
        Stops early on overflow or hard/literal lines.
        """
        # Worklist holds (node, indent_level). We only ever push FLAT in a probe.
        work: deque[tuple[object, int]] = deque()
        work.append((node, indent_level))
        steps = 0
        remaining = width_remaining

        while work:
            if steps >= max_steps:
                # Safety cutoff: if it's *that* complex, assume it doesn't fit.
                return False
            steps += 1

            cur, lvl = work.pop()

            if isinstance(cur, doc.Text):
                remaining -= len(cur.text)
                if remaining <= 0:
                    return False

            elif isinstance(cur, doc.Line):
                if cur.hard or cur.literal:
                    # Any *real* newline (hard or literal) in FLAT means "doesn't fit"
                    return False
                if cur.tight:
                    # tight softline disappears in flat mode
                    continue
                # regular soft line becomes a single space in flat mode
                remaining -= 1
                if remaining <= 0:
                    return False

            # --- Structural nodes (walk children in LIFO) ---
            elif isinstance(cur, doc.Concat):
                # push reversed so we process left-to-right as work is a stack
                for p in reversed(cur.parts):
                    work.append((p, lvl))

            elif isinstance(cur, doc.Group):
                # Probe is always FLAT for groups.
                work.append((cur.contents, lvl))

            elif isinstance(cur, doc.Indent):
                # In flat mode, indentation has no effect until a newline; keep lvl in case
                # children contain Lines (which would have already returned False).
                work.append((cur.contents, lvl + 1))

            elif isinstance(cur, doc.Align):
                # In flat mode, alignment doesn’t change width immediately (no newline),
                # but we carry its virtual indent so nested (illegal) Line would be caught.
                align_spaces = cur.n if cur.n is not None else self.indent_size
                extra_levels = align_spaces // self.indent_size
                work.append((cur.contents, lvl + extra_levels))

            elif isinstance(cur, doc.IfBreak):
                # Flat branch while probing
                work.append((cur.flat_contents, lvl))

            else:
                raise ValueError(f"Unknown DocType in probe: {type(cur)}")

        return True

    def transform(self, ir_in: uni.Module) -> uni.Module:
        """After pass."""
        formatted = self.format_doc_ir()
        # Strip trailing whitespace from each line
        lines = [line.rstrip() for line in formatted.split("\n")]
        # Remove trailing empty lines and ensure single newline at end
        while lines and lines[-1] == "":
            lines.pop()
        ir_in.gen.jac = "\n".join(lines) + "\n" if lines else ""
        return ir_in

    def format_doc_ir(
        self,
        doc_node: doc.DocType | None = None,
        indent_level: int = 0,
        width_remaining: int | None = None,
        is_broken: bool = False,
    ) -> str:
        """Recursively print a Doc node or a list of Doc nodes."""
        if doc_node is None:
            doc_node = self.ir_in.gen.doc_ir

        if width_remaining is None:
            width_remaining = self.MAX_LINE_LENGTH

        if isinstance(doc_node, doc.Text):
            return doc_node.text

        elif isinstance(doc_node, doc.Line):
            if is_broken or doc_node.hard:
                return "\n" + " " * (indent_level * self.indent_size)
            elif doc_node.literal:  # literal soft line
                return "\n"
            elif doc_node.tight:
                return ""
            else:  # soft line, not broken
                return " "

        elif isinstance(doc_node, doc.Group):
            fits_flat = self._probe_fits(
                doc_node.contents,
                indent_level=indent_level,
                width_remaining=width_remaining,
            )
            return self.format_doc_ir(
                doc_node.contents,
                indent_level,
                width_remaining,
                is_broken=not fits_flat,
            )

        elif isinstance(doc_node, doc.Indent):
            new_indent_level = indent_level + 1
            return self.format_doc_ir(
                doc_node.contents,
                new_indent_level,
                width_remaining,  # width_for_indented_content  # Budget for lines within indent
                is_broken,  # is_broken state propagates
            )

        elif isinstance(doc_node, doc.Concat):
            result: list[str] = []
            current_line_budget = width_remaining

            for part in doc_node.parts:
                part_str = self.format_doc_ir(
                    part, indent_level, current_line_budget, is_broken
                )

                # Trim trailing spaces when a newline begins next
                if part_str.startswith("\n") and result and result[-1].endswith(" "):
                    result[-1] = result[-1].rstrip(" ")

                result.append(part_str)

                if "\n" in part_str:
                    # After a newline, reset budget to full width at this indent.
                    last_line = part_str.splitlines()[-1]
                    full_budget = max(
                        0, self.MAX_LINE_LENGTH - indent_level * self.indent_size
                    )
                    # Compute how many chars are already on the last line (after indent).
                    indent_spaces = " " * (indent_level * self.indent_size)
                    if last_line.startswith(indent_spaces):
                        used = len(last_line) - len(indent_spaces)
                    else:
                        used = len(last_line)
                    current_line_budget = max(0, full_budget - used)
                else:
                    current_line_budget = max(0, current_line_budget - len(part_str))

            return "".join(result)

        elif isinstance(doc_node, doc.IfBreak):
            branch = doc_node.break_contents if is_broken else doc_node.flat_contents
            return self.format_doc_ir(branch, indent_level, width_remaining, is_broken)

        elif isinstance(doc_node, doc.Align):
            align_spaces = doc_node.n if doc_node.n is not None else self.indent_size
            extra_levels = align_spaces // self.indent_size
            child_indent_level = indent_level + extra_levels

            # On the same line, alignment "consumes" part of the current budget.
            child_width_budget = max(0, width_remaining - align_spaces)

            return self.format_doc_ir(
                doc_node.contents,
                child_indent_level,
                child_width_budget,
                is_broken,
            )

        else:
            raise ValueError(f"Unknown DocType: {type(doc_node)}")
