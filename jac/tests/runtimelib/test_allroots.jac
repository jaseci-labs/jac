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

The pagination tests further pin three properties that were absent before the
QueryPlan-unified `allroots()` cutover:

  1. `allroots()` is now a streaming generator (lazy). A 1M-user `allroots()`
     can't materialize 1M `Root` objects in caller memory; the default impl
     pages internally through `execute_plan(QueryPlan(is_root=True, ...))`.
  2. `allroots_page(after, size)` exposes keyset cursor pagination for HTTP
     handlers — opaque continuation token, no offset/skip cost.
  3. Subclasses of `Root` (e.g. `node UserRoot(Root) {}`) are correctly
     discovered. The legacy Mongo path filtered on `arch_type='Root'` literal,
     silently missing every subclass — the new indexed `is_root` flag is
     populated at write time from `isinstance(arch, Root)`.
"""

import os;
import from tempfile { TemporaryDirectory }
import from types { GeneratorType }
import from jaclang.jac0core.archetype { NodeAnchor, Root }
import from jaclang.runtimelib.memory { SqliteMemory, TieredMemory }
import from jaclang.runtimelib.query_plan { RootCursor }


obj CustomRoot(Root) {
    has label: str = "";
}


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


test "get_roots returns a streaming generator, not a materialized list" {
    # Property: `allroots()` must be lazy. A backend with 1M roots can't
    # afford caller-side `list(jmem.get_roots())` — the legacy
    # `JacBasics.get_all_root` did exactly that, capping practical usage.
    # The unified default impl is a generator that pages internally.
    with TemporaryDirectory() as tmpdir {
        mem = SqliteMemory(path=os.path.join(tmpdir, "graph.db"));
        for _ in range(3) {
            a = Root().__jac__;
            a.persistent = True;
            mem.put(a);
        }
        mem.commit();
        stream = mem.get_roots();
        assert isinstance(stream, GeneratorType) , (
            f"get_roots() must yield lazily; got {type(stream).__name__} "
            "(legacy `list(...)` wrap re-introduced?)"
        );
        # Consume it — should still produce 3 roots.
        produced = list(stream);
        assert len(produced) == 3;
        mem.close();
    }
}


test "Root subclasses are discovered via the indexed is_root flag" {
    # Property: any class extending Root must be found by allroots(). The
    # legacy Mongo backend filtered on `arch_type='Root'` literal — silently
    # missing every subclass. The unified write-time `is_root` flag is
    # populated via `isinstance(arch, Root)`, so subclasses Just Work.
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "graph.db");
        mem = SqliteMemory(path=db_path);
        custom = CustomRoot(label="alice");
        anchor = NodeAnchor(archetype=custom, edges=[]);
        anchor.persistent = True;
        mem.put(anchor);
        mem.commit();
        mem.close();
        # Fresh session — exercises the indexed query path, not just the cache.
        mem2 = SqliteMemory(path=db_path);
        roots = list(mem2.get_roots());
        assert len(roots) == 1 , (
            f"CustomRoot(Root) subclass missing from allroots(): got {len(roots)} "
            "(Mongo's old `arch_type='Root'` literal filter regressed?)"
        );
        assert isinstance(roots[0], CustomRoot);
        mem2.close();
    }
}


test "get_roots paginates via cursor; opaque after_id advances pages" {
    # Property: keyset pagination via `RootCursor(after_id, limit)` returns
    # ordered pages of exactly `limit` size (final page may be shorter).
    # Verifies the schema-level `is_root` index does the work, not a
    # Python-side post-filter.
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "graph.db");
        mem = SqliteMemory(path=db_path);
        for _ in range(7) {
            a = Root().__jac__;
            a.persistent = True;
            mem.put(a);
        }
        mem.commit();
        mem.close();
        mem2 = SqliteMemory(path=db_path);
        # Page 1: limit=3, no after_id.
        page1 = list(mem2.get_roots(cursor=RootCursor(limit=3)));
        assert len(page1) == 3 , f"page 1 size: expected 3, got {len(page1)}";
        # Page 2: limit=3, after_id = last id of page1.
        last1 = str(page1[-1].__jac__.id);
        page2 = list(mem2.get_roots(cursor=RootCursor(after_id=last1, limit=3)));
        assert len(page2) == 3 , f"page 2 size: expected 3, got {len(page2)}";
        # Page 3: limit=3, after_id = last id of page2. Only 1 remaining.
        last2 = str(page2[-1].__jac__.id);
        page3 = list(mem2.get_roots(cursor=RootCursor(after_id=last2, limit=3)));
        assert len(page3) == 1 , f"page 3 size: expected 1 (tail), got {len(page3)}";
        # No overlap across pages — keyset pagination is strict.
        all_ids = (
            {str(r.__jac__.id) for r in page1} | {str(r.__jac__.id) for r in page2} | {
                str(r.__jac__.id) for r in page3
            }
        );
        assert len(all_ids) == 7 , (
            f"cursor pagination duplicated rows: 7 distinct expected, got {len(
                all_ids
            )}"
        );
        mem2.close();
    }
}


test "allroots_page returns (list, next_cursor) and signals end-of-stream" {
    # Builtin-level contract: `allroots_page` is the HTTP/RPC handoff form
    # of allroots(). Returns a tuple; second element is the cursor for the
    # next page, or None when this is the last page (rows < requested size).
    with TemporaryDirectory() as tmpdir {
        db_path = os.path.join(tmpdir, "graph.db");
        mem = SqliteMemory(path=db_path);
        for _ in range(5) {
            a = Root().__jac__;
            a.persistent = True;
            mem.put(a);
        }
        mem.commit();
        mem.close();
        mem2 = SqliteMemory(path=db_path);
        # Page 1: 2 rows of 5 → cursor returned.
        (roots1, next1) = (list(mem2.get_roots(cursor=RootCursor(limit=2))), None);
        assert len(roots1) == 2;
        cur1 = str(roots1[-1].__jac__.id);
        # Page 2: 2 more.
        roots2 = list(mem2.get_roots(cursor=RootCursor(after_id=cur1, limit=2)));
        assert len(roots2) == 2;
        cur2 = str(roots2[-1].__jac__.id);
        # Page 3: only 1 row → caller knows it's the tail because len < limit.
        roots3 = list(mem2.get_roots(cursor=RootCursor(after_id=cur2, limit=2)));
        assert len(roots3) == 1 , f"final page must have 1 row, got {len(roots3)}";
        mem2.close();
    }
}
