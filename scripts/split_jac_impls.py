#!/usr/bin/env python3
from __future__ import annotations

import argparse
import contextlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Span:
    start_line: int
    end_line: int


@dataclass(frozen=True)
class ImplChunk:
    span: Span
    impl_text: str
    decl_text: str
    key: str
    doc_text: str


DEF_LINE_RE = re.compile(r"^\s*(async\s+)?(static\s+def|def)\s+")
DECORATOR_LINE_RE = re.compile(r"^\s*@")


def _indent_of(line: str) -> str:
    return line[: len(line) - len(line.lstrip(" "))]


def _find_first_def_line(lines: list[str]) -> int | None:
    for idx, line in enumerate(lines):
        if DEF_LINE_RE.match(line):
            return idx
    return None


def _find_first_body_brace(lines: list[str], start_idx: int) -> tuple[int, int] | None:
    paren_depth = 0
    bracket_depth = 0
    for i in range(start_idx, len(lines)):
        line = lines[i]
        for j, ch in enumerate(line):
            if ch == "(":
                paren_depth += 1
            elif ch == ")":
                paren_depth = max(paren_depth - 1, 0)
            elif ch == "[":
                bracket_depth += 1
            elif ch == "]":
                bracket_depth = max(bracket_depth - 1, 0)
            elif ch == "{" and paren_depth == 0 and bracket_depth == 0:
                return (i, j)
    return None


def _method_name_from_def_line(def_line: str) -> str:
    s = def_line.lstrip(" ")
    if s.startswith("async "):
        s = s[len("async ") :]
    if s.startswith("static def "):
        s = s[len("static def ") :]
    elif s.startswith("def "):
        s = s[len("def ") :]
    name = s.split("(", 1)[0].strip()
    return name.split()[0]


def _make_decl_text(block_lines: list[str]) -> str:
    def_idx = _find_first_def_line(block_lines)
    if def_idx is None:
        return ""
    brace_pos = _find_first_body_brace(block_lines, def_idx)
    if brace_pos is None:
        return ""
    brace_line_idx, brace_col = brace_pos
    head_lines = block_lines[: brace_line_idx + 1]
    last = head_lines[-1]
    head_lines[-1] = last[:brace_col] + ";" + ("\n" if last.endswith("\n") else "")
    return "".join(head_lines)


def _make_impl_text(block_lines: list[str], class_name: str | None) -> str:
    def_idx = _find_first_def_line(block_lines)
    if def_idx is None:
        return ""
    brace_pos = _find_first_body_brace(block_lines, def_idx)
    if brace_pos is None:
        return ""

    # De-indent by one level when coming from a class body (4 spaces).
    if class_name is not None:
        block_lines = [ln[4:] if ln.startswith("    ") else ln for ln in block_lines]

    first = block_lines[def_idx if class_name is None else def_idx]
    indent = _indent_of(first)
    def_line = first.lstrip(" ")
    if def_line.startswith("async "):
        def_line = def_line[len("async ") :]
    if def_line.startswith("static def "):
        rest = def_line[len("static def ") :]
    elif def_line.startswith("def "):
        rest = def_line[len("def ") :]
    else:
        return ""

    method_name = _method_name_from_def_line(first)
    if class_name is None:
        impl_first = indent + "impl " + method_name + rest[len(method_name) :]
    else:
        impl_first = (
            indent + "impl " + class_name + "." + method_name + rest[len(method_name) :]
        )

    out = block_lines[:]
    out[def_idx] = impl_first
    if not out[def_idx].endswith("\n") and first.endswith("\n"):
        out[def_idx] += "\n"
    return "".join(out)


def _extract_blocks_for_file(path: Path) -> list[ImplChunk]:
    jac_root = (Path(__file__).resolve().parents[1] / "jac").resolve()
    if str(jac_root) not in sys.path:
        sys.path.insert(0, str(jac_root))

    import jaclang.pycore.unitree as uni  # type: ignore
    from jaclang.pycore.program import JacProgram  # type: ignore

    prog = JacProgram()
    mod = prog.compile(file_path=str(path), no_cgen=True)
    if not mod:
        return []

    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)

    chunks: list[ImplChunk] = []

    def slice_lines(span: Span) -> list[str]:
        return lines[span.start_line - 1 : span.end_line]

    def walk(container: object) -> None:
        if isinstance(container, uni.Module):
            for stmt in container.body:
                walk(stmt)
            return
        if isinstance(container, uni.ClientBlock):
            for stmt in container.body:
                walk(stmt)
            return
        if isinstance(container, uni.Archetype) and isinstance(container.body, list):
            for item in container.body:
                walk(item)
            return
        if isinstance(container, uni.Ability) and container.body:
            span = Span(container.loc.first_line, container.loc.last_line)
            block_lines = slice_lines(span)
            # Only split python-style defs (skip `can`, etc.)
            if _find_first_def_line(block_lines) is None:
                return

            class_name = None
            if isinstance(container.parent, uni.Archetype):
                class_name = container.parent.name.sym_name

            method_name = None
            def_idx = _find_first_def_line(block_lines)
            if def_idx is None:
                return
            method_name = _method_name_from_def_line(block_lines[def_idx])
            key = f"{class_name}.{method_name}" if class_name else method_name

            # Extract and remove ability docstring (if any) using AST token location.
            doc_text = ""
            doc_span: Span | None = None
            doc = getattr(container, "doc", None)
            if doc is not None and getattr(doc, "loc", None) is not None:
                doc_span = Span(doc.loc.first_line, doc.loc.last_line)
                doc_lines = slice_lines(doc_span)
                # normalize to top-level docstring block style
                doc_text = "".join([ln.lstrip(" ") for ln in doc_lines]).rstrip() + "\n"

            def remove_span_from_block(
                block: list[str], full_span: Span, remove: Span | None
            ) -> list[str]:
                if remove is None:
                    return block
                # Only remove when the doc span is fully inside the ability span.
                if (
                    remove.start_line < full_span.start_line
                    or remove.end_line > full_span.end_line
                ):
                    return block
                rel_start = remove.start_line - full_span.start_line
                rel_end = remove.end_line - full_span.start_line
                new_block = block[:rel_start] + block[rel_end + 1 :]
                return new_block

            block_wo_doc = remove_span_from_block(block_lines, span, doc_span)

            # Remove decorators from impl blocks (keep decorators in interface).
            def_idx2 = _find_first_def_line(block_wo_doc)
            if def_idx2 is None:
                return
            deco_start = def_idx2
            while deco_start - 1 >= 0 and DECORATOR_LINE_RE.match(
                block_wo_doc[deco_start - 1]
            ):
                deco_start -= 1
            impl_block = block_wo_doc[:deco_start] + block_wo_doc[def_idx2:]
            decl_block = block_wo_doc

            decl_text = _make_decl_text(block_lines)
            # Recompute decl/impl using doc-stripped blocks.
            decl_text = _make_decl_text(decl_block)
            impl_text = _make_impl_text(impl_block, class_name)
            if not decl_text or not impl_text:
                return

            # Ensure decorators remain in declaration (they are included in decl_text already)
            # and not in the impl text.
            chunks.append(
                ImplChunk(
                    span=span,
                    impl_text=impl_text,
                    decl_text=decl_text,
                    key=key,
                    doc_text=doc_text,
                )
            )
            return

    walk(mod)

    # De-duplicate spans (defensive).
    unique: dict[tuple[int, int], ImplChunk] = {}
    for ch in chunks:
        unique[(ch.span.start_line, ch.span.end_line)] = ch
    out = list(unique.values())
    out.sort(key=lambda c: (c.span.start_line, c.span.end_line), reverse=True)
    return out


def _apply_chunks_to_interface(path: Path, chunks: list[ImplChunk]) -> tuple[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    impl_parts: list[str] = []

    for ch in chunks:
        start = ch.span.start_line - 1
        end = ch.span.end_line
        lines[start:end] = [ch.decl_text]
        if ch.doc_text:
            impl_parts.append(ch.doc_text)
            if not ch.doc_text.endswith("\n"):
                impl_parts.append("\n")
            impl_parts.append("\n")
        impl_parts.append(ch.impl_text)
        if not ch.impl_text.endswith("\n"):
            impl_parts.append("\n")
        impl_parts.append("\n")

    return ("".join(lines), "".join(impl_parts).rstrip() + "\n")


def _format_in_place(path: Path) -> None:
    jac_root = (Path(__file__).resolve().parents[1] / "jac").resolve()
    if str(jac_root) not in sys.path:
        sys.path.insert(0, str(jac_root))
    from jaclang.pycore.program import JacProgram  # type: ignore

    prog = JacProgram.jac_file_formatter(str(path), auto_lint=True)
    if prog.errors_had:
        msgs = "\n".join(str(e) for e in prog.errors_had[:15])
        raise RuntimeError(f"Formatter errors for {path}:\n{msgs}")
    path.write_text(prog.mod.main.gen.jac, encoding="utf-8")


def should_split(path: Path, min_def_bodies: int, min_lines: int) -> bool:
    txt = path.read_text(encoding="utf-8")
    if re.search(r"^impl\\b", txt, re.M):
        return False
    if (path.with_suffix("").as_posix() + ".impl") in txt:
        # defensive: don't touch files that mention their own annex folder in code/docs
        pass
    lines = txt.count("\n") + 1
    if lines < min_lines:
        return False
    # quick def-body estimate
    bodies = 0
    for line in txt.splitlines():
        s = line.lstrip(" ")
        if s.startswith(("def ", "static def ", "async def ", "async static def ")):
            if s.rstrip().endswith(";"):
                continue
            bodies += 1
    return bodies >= min_def_bodies


def split_file(path: Path, dry_run: bool, min_def_bodies: int, min_lines: int) -> bool:
    if path.name.endswith(".cl.jac"):
        base = Path(str(path)[: -len(".cl.jac")])
        stem = path.name[: -len(".cl.jac")]
    else:
        base = path.with_suffix("")
        stem = path.stem
    impl_dir = Path(str(base) + ".impl")
    impl_file = impl_dir / (stem + ".impl.jac")

    if impl_dir.exists():
        return False
    if not should_split(path, min_def_bodies=min_def_bodies, min_lines=min_lines):
        return False

    chunks = _extract_blocks_for_file(path)
    if len(chunks) < min_def_bodies:
        return False

    iface_text, impl_text = _apply_chunks_to_interface(path, chunks)

    if dry_run:
        print(f"[would-split] {path} -> {impl_file} ({len(chunks)} bodies)")
        return True

    # Transactional write: format first, then commit to disk.
    impl_dir.mkdir(parents=True, exist_ok=False)
    tmp_iface = path.with_suffix(path.suffix + ".tmp")
    tmp_impl = impl_file.with_suffix(impl_file.suffix + ".tmp")
    try:
        tmp_iface.write_text(iface_text, encoding="utf-8")
        tmp_impl.write_text(impl_text, encoding="utf-8")
        _format_in_place(tmp_iface)
        _format_in_place(tmp_impl)
        tmp_iface.replace(path)
        tmp_impl.replace(impl_file)
    except Exception:
        with contextlib.suppress(Exception):
            tmp_iface.unlink()
        with contextlib.suppress(Exception):
            tmp_impl.unlink()
        # remove empty directory if we created it
        with contextlib.suppress(Exception):
            if impl_dir.exists():
                for child in impl_dir.iterdir():
                    child.unlink()
                impl_dir.rmdir()
        raise

    return True


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Split implementation-heavy Jac modules into .jac interface + .impl annexes."
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Only print what would change."
    )
    parser.add_argument(
        "--roots",
        nargs="*",
        default=["jac/jaclang"],
        help="Root directories to scan (defaults to jac/jaclang).",
    )
    parser.add_argument("--min-def-bodies", type=int, default=10)
    parser.add_argument("--min-lines", type=int, default=200)
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[1]
    changed = 0

    for root in args.roots:
        root_path = (repo_root / root).resolve()
        if not root_path.exists():
            continue
        for path in root_path.rglob("*.jac"):
            if path.name.endswith((".impl.jac", ".test.jac", ".cl.jac")):
                continue
            rel = path.relative_to(repo_root)
            rel_str = rel.as_posix()
            if "/vendor/" in rel_str or "/tests/" in rel_str or "/fixtures/" in rel_str:
                continue
            if ".impl/" in rel_str or ".test/" in rel_str:
                continue
            # skip modules already split previously
            if Path(str(path.with_suffix("")) + ".impl").exists():
                continue
            try:
                if split_file(
                    rel,
                    dry_run=args.dry_run,
                    min_def_bodies=args.min_def_bodies,
                    min_lines=args.min_lines,
                ):
                    changed += 1
            except Exception as exc:
                print(f"[skip-error] {rel}: {exc}", file=sys.stderr)

    if args.dry_run:
        return 0
    print(f"Split {changed} module(s).", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
