"""Compiler utilities - Pure Python, no runtimelib dependencies.

This module contains utilities needed by the compiler that must be available
during the bootstrap phase before .jac files can be imported.
"""

from __future__ import annotations


def read_file_with_encoding(file_path: str) -> str:
    """Read file with proper encoding detection.

    Tries multiple encodings to handle files with different encodings.
    """
    encodings_to_try = [
        "utf-8-sig",
        "utf-8",
        "utf-16",
        "utf-16le",
        "utf-16be",
    ]

    for encoding in encodings_to_try:
        try:
            with open(file_path, encoding=encoding) as f:
                return f.read()
        except UnicodeError:
            continue
        except Exception as e:
            raise OSError(
                f"Could not read file {file_path}: {e}. "
                f"Report this issue: https://github.com/jaseci-labs/jaseci/issues"
            ) from e

    raise OSError(
        f"Could not read file {file_path} with any encoding. "
        f"Report this issue: https://github.com/jaseci-labs/jaseci/issues"
    )
