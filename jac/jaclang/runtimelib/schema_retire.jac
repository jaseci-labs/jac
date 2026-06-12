"""Brace-aware codemod that removes a fully-migrated `__jac_schema__` hook (decl + impl block) from `.jac` source. Pure string transforms; the CLI adds the census gate and file I/O."""

import os;
import re;
import from pathlib { Path }
import from typing { cast }


"""Index just past the string literal at `i` (quotes/triples/escapes; stops at newline if unterminated)."""
def _skip_string(src: str, i: int) -> int;


"""Index of the `}` matching the `{` at `open_idx` (string/comment-aware), or -1 if unbalanced."""
def match_brace(src: str, open_idx: int) -> int;


"""Start index of the line containing `idx`."""
def _line_start(src: str, idx: int) -> int;


"""Pull a line-start `start` back over one contiguous doc-comment/`#` line and blank lines above it."""
def _absorb_leading_doc(src: str, start: int) -> int;


"""(body_open+1, body_close) span of `class_name`'s obj/node/edge/walker block, or None."""
def _class_body_span(src: str, class_name: str) -> (tuple | None);


"""Remove `class_name`'s `__jac_schema__` decl and impl block(s); returns (new_source, removed_snippets)."""
def strip_hook_from_source(src: str, class_name: str) -> tuple;


"""`.jac` files under `search_root` the codemod would actually change for `class_name`."""
def hook_source_files(search_root: str, class_name: str) -> list[str];
