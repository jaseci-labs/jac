"""Tests for store hashing and lockfile why_chains.

Pins the content-addressed store race fix (dirhash must ignore the
.jac-origin marker so a concurrent winner's tree hash matches the
pre-marker expected hash) and the `jac why` fix that surfaces a direct
npm dependency even when jac/python chains exist for the same name.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.project.jac_store {
    ORIGIN_MARKER,
    dirhash,
    _tree_matches,
    _write_origin_meta
}
import from jaclang.project.lockfile { why_chains }


def make_tree(path: Path) -> str {
    (path / "sub").mkdir(parents=True);
    (path / "lib.jac").write_text("def f -> int { return 1; }\n", encoding="utf-8");
    (path / "sub" / "g.jac").write_text("def g {}\n", encoding="utf-8");
    return dirhash(path);
}


test "dirhash ignores the store origin marker" {
    tmp = tempfile.mkdtemp(prefix="jac_marker_hash_");
    try {
        tree = Path(tmp) / "tree";
        before = make_tree(tree);
        _write_origin_meta(
            tree, {"url": "https://x/y", "sha": "a" * 40, "tree": before}
        );
        assert (tree / ORIGIN_MARKER).is_file();
        assert dirhash(tree) == before;
        # A store entry is content + marker: it must still match the tree
        # hash recorded before the marker was written (concurrent-winner
        # race in fetch_package).
        twin = Path(tmp) / "twin";
        shutil.copytree(tree, twin);
        assert _tree_matches(twin, before);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "dirhash still distinguishes real content changes" {
    tmp = tempfile.mkdtemp(prefix="jac_marker_real_");
    try {
        tree = Path(tmp) / "tree";
        before = make_tree(tree);
        (tree / "extra.jac").write_text("def h {}\n", encoding="utf-8");
        assert dirhash(tree) != before;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "why_chains appends the direct npm chain" {
    # npm-only name: the single direct chain.
    npm_only = {"npm": {"left-pad": "1.2.3"}};
    assert why_chains(npm_only, "left-pad") == [("npm", ["left-pad"])];

    # Name required by a python package and also a direct npm dep:
    # both chains surface.
    shared = {
        "python_graph": {"dup": ["root"], "requests": ["root"]},
        "npm": {"dup": "2.0.0"}
    };
    dup_chains = why_chains(shared, "dup");
    assert ("python", ["dup", "root"]) in dup_chains;
    assert ("npm", ["dup"]) in dup_chains;
    assert len(dup_chains) == 2;

    # A jac row that already yields the bare [name] chain is not duplicated.
    direct = {
        "jac": {"direct": {"git": "https://x", "requested_by": []}},
        "npm": {"direct": "1.0.0"}
    };
    assert why_chains(direct, "direct") == [("jac", ["direct"])];

    # Jac/python chains without npm stay untouched; unknown names keep the
    # [[name]] fallback.
    assert why_chains({"jac": {"a": {"requested_by": ["root"]}}}, "a")
        == [("jac", ["a", "root"])];
    assert why_chains({"jac": {"a": {"requested_by": ["root"]}}}, "ghost")
        == [("jac", ["ghost"])];
}
