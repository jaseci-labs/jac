"""Recursively print a Doc node or a list of Doc nodes."""
impl JacFormatPass.format_doc_ir(
    doc_node: (doc.DocType | None) = None,
    indent_level: int = 0,
    width_remaining: (int | None) = None,
    is_broken: bool = False,
    align_spaces: int = 0,
    trailing_width: int = 0
) -> str {
    if (doc_node is None) {
        doc_node = self.ir_in.gen.doc_ir;
    }
    if (width_remaining is None) {
        width_remaining = self.MAX_LINE_LENGTH;
    }
    total_indent = indent_level * self.indent_size + align_spaces;
    if isinstance(doc_node, doc.Text) {
        return doc_node.text;
    } elif isinstance(doc_node, doc.Line) {
        if (is_broken or doc_node.hard) {
            return ('\n' + (' ' * total_indent));
        } elif doc_node.literal {
            return '\n';
        } elif doc_node.tight {
            return '';
        } else {
            return ' ';
        }
    } elif isinstance(doc_node, doc.Group) {
        # Probe whether the group's flat form fits in the space that will
        # actually be available on the current line, which is
        # `width_remaining - trailing_width` (trailing_width is the flat
        # width of content that will follow this group on the same line,
        # propagated from enclosing Concats).
        probe_budget = max(0, (width_remaining - trailing_width));
        fits_flat = self._probe_fits(
            doc_node.contents, indent_level=indent_level, width_remaining=probe_budget
        );
        # break_contiguous=True: when the enclosing group has already
        # broken (is_broken=True), this group breaks unconditionally
        # regardless of whether its own contents would fit flat. Used by
        # JSX children groups to force children onto their own lines
        # whenever the parent element has broken.
        if (doc_node.break_contiguous and is_broken) {
            fits_flat = False;
        }
        return self.format_doc_ir(
            doc_node.contents,
            indent_level,
            width_remaining,
            is_broken=not fits_flat,
            align_spaces=align_spaces,
            trailing_width=trailing_width
        );
    } elif isinstance(doc_node, doc.Indent) {
        new_indent_level = indent_level + 1;
        return self.format_doc_ir(
            doc_node.contents,
            new_indent_level,
            width_remaining,
            is_broken,
            align_spaces=align_spaces,
            trailing_width=trailing_width
        );
    } elif isinstance(doc_node, doc.Concat) {
        result: list[str] = [];
        current_line_budget = width_remaining;
        num_parts = len(doc_node.parts);
        for (idx, part) in enumerate(doc_node.parts) {
            is_last = (idx + 1) == num_parts;
            # Compute the flat width of everything that will follow this
            # part on the current line. For the last part, that's just the
            # caller's trailing_width. For earlier parts, it's the flat
            # first-line width of the following siblings, seeded with
            # trailing_width so that a fully-flat tail extends the reach
            # of the outer context's trailing content.
            if is_last {
                child_trailing = trailing_width;
            } else {
                child_trailing = self._flat_first_line_width(
                    doc.Concat(doc_node.parts[(idx + 1):]),
                    base=trailing_width,
                    is_broken=is_broken
                );
            }
            part_str = self.format_doc_ir(
                part,
                indent_level,
                current_line_budget,
                is_broken,
                align_spaces=align_spaces,
                trailing_width=child_trailing
            );
            if (part_str.startswith('\n') and result and result[-1].endswith(' ')) {
                result[-1] = result[-1].rstrip(' ');
            }
            result.append(part_str);
            if ('\n' in part_str) {
                full_budget = max(0, (self.MAX_LINE_LENGTH - total_indent));
                if part_str.endswith('\n') {
                    # Cursor is at start of fresh line
                    current_line_budget = full_budget;
                } else {
                    lines = part_str.splitlines();
                    last_line = lines[-1] if lines else '';
                    indent_str = ' ' * total_indent;
                    if last_line.startswith(indent_str) {
                        used = len(last_line) - len(indent_str);
                    } else {
                        used = len(last_line);
                    }
                    current_line_budget = max(0, (full_budget - used));
                }
            } else {
                current_line_budget = max(0, (current_line_budget - len(part_str)));
            }
        }
        return ''.join(result);
    } elif isinstance(doc_node, doc.IfBreak) {
        branch = doc_node.break_contents if is_broken else doc_node.flat_contents;
        return self.format_doc_ir(
            branch,
            indent_level,
            width_remaining,
            is_broken,
            align_spaces=align_spaces,
            trailing_width=trailing_width
        );
    } elif isinstance(doc_node, doc.Align) {
        new_align = doc_node.n if (doc_node.n is not None) else self.indent_size;
        child_align_spaces = align_spaces + new_align;
        child_width_budget = max(0, (width_remaining - new_align));
        return self.format_doc_ir(
            doc_node.contents,
            indent_level,
            child_width_budget,
            is_broken,
            align_spaces=child_align_spaces,
            trailing_width=trailing_width
        );
    } else {
        raise self.ice(f"Unknown DocType: {type(doc_node)}");
    }
}

"""After pass."""
impl JacFormatPass.transform(ir_in: uni.Module) -> uni.Module {
    formatted = self.format_doc_ir();
    lines = [line.rstrip() for line in formatted.split('\n')];
    while (lines and (lines[-1] == '')) {
        lines.pop();
    }
    ir_in.gen.jac = ('\n'.join(lines) + '\n') if lines else '';
    # Process impl modules (.impl.jac files)
    # Only do this for the main module (not annex modules themselves)
    if ir_in.annexable_by is None {
        for impl_mod in ir_in.impl_mod {
            # Create a new formatter instance for each impl module
            JacFormatPass(ir_in=impl_mod, prog=self.prog);
        }
    }
    return ir_in;
}

"""Check if flat can be used early.

Returns True if `node` could be printed *flat* on the current line within
`width_remaining` columns at `indent_level`.
Stops early on overflow or hard/literal lines.
"""
impl JacFormatPass._probe_fits(
    nd: doc.DocType, indent_level: int, width_remaining: int, *, max_steps: int = 2000
) -> bool {
    cache_key = (id(nd), indent_level, width_remaining);
    cached = self._probe_cache.get(cache_key);
    if cached is not None {
        return cached;
    }
    work: deque[tuple[(object, int)]] = deque();
    work.append((nd, indent_level));
    steps = 0;
    remaining = width_remaining;
    while work {
        if (steps >= max_steps) {
            self._probe_cache[cache_key] = False;
            return False;
        }
        steps += 1;
        (cur, lvl) = work.pop();
        if isinstance(cur, doc.Text) {
            remaining -= len(cur.text);
            if (remaining < 0) {
                self._probe_cache[cache_key] = False;
                return False;
            }
        } elif isinstance(cur, doc.Line) {
            if (cur.hard or cur.literal) {
                self._probe_cache[cache_key] = False;
                return False;
            }
            if cur.tight {
                continue;
            }
            remaining -= 1;
            if (remaining < 0) {
                self._probe_cache[cache_key] = False;
                return False;
            }
        } elif isinstance(cur, doc.Concat) {
            for p in reversed(cur.parts) {
                work.append((p, lvl));
            }
        } elif isinstance(cur, doc.Group) {
            work.append((cur.contents, lvl));
        } elif isinstance(cur, doc.Indent) {
            work.append((cur.contents, (lvl + 1)));
        } elif isinstance(cur, doc.Align) {
            align_spaces = cur.n if (cur.n is not None) else self.indent_size;
            extra_levels = align_spaces // self.indent_size;
            work.append((cur.contents, (lvl + extra_levels)));
        } elif isinstance(cur, doc.IfBreak) {
            work.append((cur.flat_contents, lvl));
        } else {
            raise self.ice(f"Unknown DocType in probe: {type(cur)}");
        }
    }
    self._probe_cache[cache_key] = True;
    return True;
}

"""Compute the non-breakable trailing width after a position in a Concat.

Walks remaining siblings and counts only non-Group content (Text, Lines,
etc.) that will definitely appear on the same line.  Stops at the first
hard/literal line break or Group (since Groups make their own break
decisions and may wrap to a new line).
"""
impl JacFormatPass._flat_first_line_width(
    nd: doc.DocType, base: int = 0, is_broken: bool = False
) -> int {
    # `base` is the trailing_width from the enclosing context: content that
    # will appear on the current line AFTER this subtree, but only if the
    # subtree itself walks flat to completion (no Group, no hard break).
    # If the walk terminates early at a Group or hard line, that outer
    # trailing content is on a later line, so we don't add `base`.
    #
    # When `is_broken=True`, tight lines also act as breaks (format_doc_ir
    # renders them as newline+indent in a broken context), so we must stop
    # counting there too — otherwise content past a broken tight line gets
    # wrongly charged to the current-line trailing width.
    work: deque[object] = deque();
    work.append(nd);
    width = 0;
    while work {
        cur = work.pop();
        if isinstance(cur, doc.Text) {
            width += len(cur.text);
        } elif isinstance(cur, doc.Line) {
            if (cur.hard or cur.literal) {
                return width;
            }
            if cur.tight {
                if is_broken {
                    return width;
                }
                # Flat tight line: 0 width, continue walking.
            } else {
                if is_broken {
                    return width;
                }
                width += 1;
            }
        } elif isinstance(cur, doc.Concat) {
            for p in reversed(cur.parts) {
                work.append(p);
            }
        } elif isinstance(cur, doc.Group) {
            # Stop at Groups — they make their own break decisions
            return width;
        } elif isinstance(cur, doc.Indent) {
            work.append(cur.contents);
        } elif isinstance(cur, doc.Align) {
            work.append(cur.contents);
        } elif isinstance(cur, doc.IfBreak) {
            if is_broken {
                work.append(cur.break_contents);
            } else {
                work.append(cur.flat_contents);
            }
        }
    }
    return width + base;
}

"""Initialize pass."""
impl JacFormatPass.pre_transform -> None {
    self.indent_size = 4;
    self.MAX_LINE_LENGTH = 88;
    self._probe_cache: dict = {};
}
