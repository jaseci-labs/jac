#!/usr/bin/env python3
"""Sync the agent-facing documentation corpus into the jaclang package.

`jac guide` serves two bodies of content: the curated skill files in
jac/jaclang/cli/skills/ (hand-written, the source of truth lives there) and
the documentation corpus in jac/jaclang/cli/docs/ (generated, the source of
truth is docs/docs/). This script produces the latter: it copies the
agent-relevant subset of the mkdocs tree into the package, namespaced into
four corpora, injecting a small frontmatter block (name / description /
source) that jaclang.cli.guide_store parses for its index.

    ref/        <- docs/docs/reference/       (minus the ninja easter egg)
    learn/      <- docs/docs/quick-guide/     (minus marketing pages)
                   + community/breaking-changes.md
    tutorial/   <- docs/docs/tutorials/
    internals/  <- docs/docs/internals/
                   + community/codebase-guide.md

Usage:
    python3 scripts/sync_agent_docs.py          # regenerate the corpus
    python3 scripts/sync_agent_docs.py --check  # exit 1 if the corpus is stale

The generated mirror is checked in (the jac binary payload and editable
installs both ship the jaclang tree verbatim); CI runs --check so a docs/
edit cannot land without the resync, and a hand-edit of the mirror cannot
land at all. Bodies are copied verbatim after the frontmatter block, so
line numbers reported by `jac guide --search` match the printed doc.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DOCS_ROOT = REPO_ROOT / "docs" / "docs"
CORPUS_ROOT = REPO_ROOT / "jac" / "jaclang" / "cli" / "docs"

# (namespace, source dir relative to docs/docs, excluded basenames)
CORPORA: tuple[tuple[str, str, frozenset[str]], ...] = (
    ("ref", "reference", frozenset({"ninja.md"})),
    (
        "learn",
        "quick-guide",
        frozenset({"what-makes-jac-different.md", "jac-vs-traditional-stack.md"}),
    ),
    ("tutorial", "tutorials", frozenset()),
    ("internals", "internals", frozenset()),
)

# Individual files cherry-picked from outside the corpus dirs: (source
# relative to docs/docs, target guide name).
EXTRA_DOCS: tuple[tuple[str, str], ...] = (
    ("community/breaking-changes.md", "learn/breaking-changes"),
    ("community/codebase-guide.md", "internals/codebase-guide"),
)

# Descriptions are auto-derived from the first prose paragraph; docs with no
# intro prose (e.g. generated references) get theirs here instead.
DESCRIPTION_OVERRIDES: dict[str, str] = {
    "internals/uniir_node": (
        "Generated reference of every UniIR AST node class in the compiler's "
        "unified IR: constructor signatures plus field name/type diagrams."
    ),
}

# mkdocs snippet-include marker: bundling a file that uses it would ship a
# hole where the include belongs, so refuse until it is resolved or excluded.
SNIPPET_MARKER = "--8<--"

DESCRIPTION_MAX = 180
# A wildly low file count means DOCS_ROOT moved or an exclude went wrong.
MIN_EXPECTED_DOCS = 50

_MD_LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
_MD_IMAGE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
_MD_MARKUP = re.compile(r"[*_`]")
_ANCHOR = re.compile(r"\s*\{#[^}]*\}")


def _clean_markdown(text: str) -> str:
    text = _MD_IMAGE.sub("", text)
    text = _MD_LINK.sub(r"\1", text)
    text = _MD_MARKUP.sub("", text)
    text = _ANCHOR.sub("", text)
    return " ".join(text.split())


def derive_description(body: str) -> str:
    """First prose paragraph of the doc, cleaned and truncated to one line."""
    title = ""
    para: list[str] = []
    in_fence = False
    for raw in body.splitlines():
        stripped = raw.strip()
        if stripped.startswith("```"):
            if para:
                break
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        if not stripped:
            if para:
                break
            continue
        if stripped.startswith("#"):
            if para:
                break
            if not title:
                title = stripped.lstrip("#").strip()
            continue
        # Skip admonitions, tabs, html, tables, rules, list items, and
        # indented (admonition/code) blocks -- we want plain prose.
        if stripped.startswith(("!!!", "???", "===", "<", "|", "---", "- ", "* ")):
            if para:
                break
            continue
        if re.match(r"^\d+\. ", stripped) or raw.startswith(("    ", "\t")):
            if para:
                break
            continue
        para.append(stripped)
    text = _clean_markdown(" ".join(para)) or _clean_markdown(title)
    if len(text) > DESCRIPTION_MAX:
        cut = text[: DESCRIPTION_MAX + 1]
        text = cut[: cut.rfind(" ")].rstrip(" ,;:") + " ..."
    return text


def doc_name(namespace: str, rel: Path) -> str:
    """reference/config/index.md -> ref/config; reference/index.md -> ref/index."""
    parts = list(rel.parts)
    parts[-1] = rel.stem
    if parts[-1] == "index" and len(parts) > 1:
        parts.pop()
    return "/".join([namespace, *parts])


def render_doc(name: str, source_rel: Path, body: str) -> str:
    description = DESCRIPTION_OVERRIDES.get(name) or derive_description(body)
    header = "\n".join(
        [
            "---",
            f"name: {name}",
            f"description: {description}",
            f"source: docs/docs/{source_rel.as_posix()}",
            "---",
        ]
    )
    return f"{header}\n\n{body.strip()}\n"


def build_corpus() -> dict[str, str]:
    """Map of guide name -> rendered file content for the whole corpus."""
    sources: dict[str, Path] = {}
    for namespace, subdir, excludes in CORPORA:
        base = DOCS_ROOT / subdir
        if not base.is_dir():
            sys.exit(f"error: source directory missing: {base}")
        for path in sorted(base.rglob("*.md")):
            if path.name in excludes:
                continue
            name = doc_name(namespace, path.relative_to(base))
            if name in sources:
                sys.exit(f"error: name collision: {name} ({path} vs {sources[name]})")
            sources[name] = path
    for rel, name in EXTRA_DOCS:
        path = DOCS_ROOT / rel
        if not path.is_file():
            sys.exit(f"error: cherry-picked source missing: {path}")
        if name in sources:
            sys.exit(f"error: name collision: {name}")
        sources[name] = path

    corpus: dict[str, str] = {}
    for name, path in sorted(sources.items()):
        body = path.read_text(encoding="utf-8")
        if SNIPPET_MARKER in body:
            sys.exit(
                f"error: {path} uses a mkdocs snippet include ({SNIPPET_MARKER}); "
                "resolve it or exclude the file before bundling"
            )
        corpus[name] = render_doc(name, path.relative_to(DOCS_ROOT), body)
    if len(corpus) < MIN_EXPECTED_DOCS:
        sys.exit(f"error: only {len(corpus)} docs collected; manifest looks broken")
    return corpus


def existing_corpus() -> dict[str, str]:
    if not CORPUS_ROOT.is_dir():
        return {}
    return {
        path.relative_to(CORPUS_ROOT).with_suffix("").as_posix(): path.read_text(
            encoding="utf-8"
        )
        for path in sorted(CORPUS_ROOT.rglob("*.md"))
    }


def check(corpus: dict[str, str]) -> int:
    on_disk = existing_corpus()
    stale = sorted(
        set(corpus) - set(on_disk)
        | {n for n, c in corpus.items() if on_disk.get(n) != c}
    )
    orphaned = sorted(set(on_disk) - set(corpus))
    if not stale and not orphaned:
        print(f"agent docs corpus is in sync ({len(corpus)} docs)")
        return 0
    for name in stale:
        print(f"stale: jac/jaclang/cli/docs/{name}.md")
    for name in orphaned:
        print(f"orphaned: jac/jaclang/cli/docs/{name}.md")
    print(
        "\nthe bundled agent docs corpus does not match docs/ -- "
        "run: python3 scripts/sync_agent_docs.py"
    )
    return 1


def write(corpus: dict[str, str]) -> int:
    if CORPUS_ROOT.exists():
        shutil.rmtree(CORPUS_ROOT)
    for name, content in corpus.items():
        target = CORPUS_ROOT / f"{name}.md"
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    total_kb = sum(len(c.encode()) for c in corpus.values()) // 1024
    print(f"wrote {len(corpus)} docs ({total_kb} KiB) to {CORPUS_ROOT}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="verify the bundled corpus matches docs/ instead of writing it",
    )
    args = parser.parse_args()
    corpus = build_corpus()
    return check(corpus) if args.check else write(corpus)


if __name__ == "__main__":
    sys.exit(main())
