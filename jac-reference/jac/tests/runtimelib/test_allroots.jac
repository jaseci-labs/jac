"""Tests for cross-tier root discovery (`allroots()` / `get_roots`).

`allroots()` resolves to the memory backend's `get_roots()` (via
`JacBasics.get_all_root`). In a multi-user server every request gets a fresh L1
working set over a shared persistent tier: the current user's own root is
loaded into L1, while other users' roots live only in L3 (or on disk).

A backend that enumerates roots from its in-process working set alone reports
only the requesting user's own root, so every cross-user walker (discovery,
follow, cross-user feeds) is silently reduced to single-user. These tests pin
the expected behavior: `get_roots()` must surface every root across all tiers,
de-duplicated.
"""

import os;
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.archetype { NodeAnchor, Root }


"""Build a persistent, properly-linked Root anchor."""
def _make_root -> NodeAnchor {
    anchor = Root().__jac__;
    anchor.persistent = True;
    return anchor;
}
