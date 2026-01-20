"""Initialize the JacFormatPass."""
impl JacFormatPass.init(ir_in: uni.Module, prog: Any, cancel_token: Any = None) -> None {
    super.init(ir_in, prog, cancel_token);
}

"""Recursively print a Doc node or a list of Doc nodes."""
impl JacFormatPass.format_doc_ir(
    doc_node: (doc.DocType | None) = None,
    indent_level: int = 0,
    width_remaining: (int | None) = None,
    is_broken: bool = False,
    align_spaces: int = 0
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
        fits_flat = self._probe_fits(
            doc_node.contents,
            indent_level=indent_level,
            width_remaining=width_remaining
        );
        return self.format_doc_ir(
            doc_node.contents,
            indent_level,
            width_remaining,
            is_broken=not fits_flat,
            align_spaces=align_spaces
        );
    } elif isinstance(doc_node, doc.Indent) {
        new_indent_level = indent_level + 1;
        return self.format_doc_ir(
            doc_node.contents,
            new_indent_level,
            width_remaining,
            is_broken,
            align_spaces=align_spaces
        );
    } elif isinstance(doc_node, doc.Concat) {
        result: list[str] = [];
        current_line_budget = width_remaining;
        for part in doc_node.parts {
            part_str = self.format_doc_ir(
                part,
                indent_level,
                current_line_budget,
                is_broken,
                align_spaces=align_spaces
            );
            if (part_str.startswith('\n') and result and result[-1].endswith(' ')) {
                result[-1] = result[-1].rstrip(' ');
            }
            result.append(part_str);
            if ('\n' in part_str) {
                lines = part_str.splitlines();
                last_line = lines[-1] if lines else '';
                full_budget = max(0, (self.MAX_LINE_LENGTH - total_indent));
                indent_str = ' ' * total_indent;
                if last_line.startswith(indent_str) {
                    used = len(last_line) - len(indent_str);
                } else {
                    used = len(last_line);
                }
                current_line_budget = max(0, (full_budget - used));
            } else {
                current_line_budget = max(0, (current_line_budget - len(part_str)));
            }
        }
        return ''.join(result);
    } elif isinstance(doc_node, doc.IfBreak) {
        branch = doc_node.break_contents if is_broken else doc_node.flat_contents;
        return self.format_doc_ir(
            branch, indent_level, width_remaining, is_broken, align_spaces=align_spaces
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
            align_spaces=child_align_spaces
        );
    } else {
        raise ValueError(f"Unknown DocType: {type(doc_node)}") ;
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
    <>node: doc.DocType,
    indent_level: int,
    width_remaining: int,
    *,
    max_steps: int = 2000
) -> bool {
    work: deque[tuple[(object, int)]] = deque();
    work.append((<>node, indent_level));
    steps = 0;
    remaining = width_remaining;
    while work {
        if (steps >= max_steps) {
            return False;
        }
        steps += 1;
        (cur, lvl) = work.pop();
        if isinstance(cur, doc.Text) {
            remaining -= len(cur.text);
            if (remaining <= 0) {
                return False;
            }
        } elif isinstance(cur, doc.Line) {
            if (cur.hard or cur.literal) {
                return False;
            }
            if cur.tight {
                continue;
            }
            remaining -= 1;
            if (remaining <= 0) {
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
            raise ValueError(f"Unknown DocType in probe: {type(cur)}") ;
        }
    }
    return True;
}

"""Initialize pass."""
impl JacFormatPass.pre_transform -> None {
    self.indent_size = 4;
    self.MAX_LINE_LENGTH = 88;
}
