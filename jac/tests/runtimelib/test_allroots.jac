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
import from jaclang.jac0core.archetype { NodeAnchor, Root }
import from jaclang.runtimelib.memory { SqliteMemory, TieredMemory }


"""Build a persistent, properly-linked Root anchor."""
def _make_root -> NodeAnchor {
    anchor = Root().__jac__;
    anchor.persistent = True;
    return anchor;
}


test "TieredMemory.get_roots surfaces roots held only in the L3 tier" {
    with TemporaryDirectory() as tmpdir {
        tmem = TieredMemory(base_path=tmpdir);
        # Two users' roots, persisted to the shared L3 tier. Neither has been
        # loaded into this request's L1 working set.
        a = _make_root();
        b = _make_root();
        tmem.l3.put(a);
        tmem.l3.put(b);
        roots = list(tmem.get_roots());
        got = {jid(r) for r in roots};
        assert jid(a.archetype) in got , "root persisted in L3 is invisible to get_roots()";
        assert jid(b.archetype) in got , "root persisted in L3 is invisible to get_roots()";
        assert len(roots) == 2 , f"expected 2 roots across tiers, got {len(roots)}";
        tmem.close();
    }
}


test "TieredMemory.get_roots merges the L1 request root with other users' L3 roots" {
    with TemporaryDirectory() as tmpdir {
        tmem = TieredMemory(base_path=tmpdir);
        # `mine` models the current request's own root: loaded into L1 and
        # persisted. `other` models a different user's root that lives only
        # in the shared L3 tier.
        mine = _make_root();
        other = _make_root();
        tmem.l3.put(mine);
        tmem.l3.put(other);
        tmem.__mem__[mine.id] = mine;
        roots = list(tmem.get_roots());
        got = {jid(r) for r in roots};
        assert jid(mine.archetype) in got , "current request's own root missing from get_roots()";
        assert jid(other.archetype) in got , "another user's root invisible — allroots() is single-user";
        # A root resident in both tiers must not be double-counted.
        assert len(roots) == 2 , f"expected 2 distinct roots, got {len(roots)}";
        tmem.close();
    }
}


test "SqliteMemory.get_roots surfaces roots persisted to disk by an earlier session" {
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "graph.db");
        # First session: persist two roots and flush to disk.
        mem = SqliteMemory(path=db_path);
        a = _make_root();
        b = _make_root();
        mem.put(a);
        mem.put(b);
        mem.close();
        # Fresh session over the same database — empty working set.
        mem2 = SqliteMemory(path=db_path);
        roots = list(mem2.get_roots());
        got = {jid(r) for r in roots};
        assert jid(a.archetype) in got , "root on disk is invisible to a fresh SqliteMemory.get_roots()";
        assert jid(b.archetype) in got , "root on disk is invisible to a fresh SqliteMemory.get_roots()";
        assert len(roots) == 2 , f"expected 2 roots from disk, got {len(roots)}";
        mem2.close();
    }
}
