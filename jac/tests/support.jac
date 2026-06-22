"""Shared path anchor for the test suite.

Tests must not assume the editable-install layout (`jaclang.__file__` sitting
next to the repo `tests/`): under the single `jac` binary, jaclang lives in the
sealed runtime cache, not beside the tests. This module resolves the repo root
from its OWN location inside `tests/`, so every test imports one stable anchor
instead of re-deriving it with a `Path(__file__).resolve().parents` walk.

Imported as `from tests.support`, which resolves identically under the binary's
bundled pytest and an editable `pytest` run (same mechanism as
`tests.fixtures_list`).
"""

import from pathlib { Path }

# `tests/`: the directory holding this file.
glob TESTS_DIR: str = str(Path(__file__).resolve().parent),
     # Repo root (the `jac/` dir): the parent of `tests/`.
     JAC_ROOT: str = str(Path(__file__).resolve().parent.parent);
