"""_SRC_SHARED eviction: the shared source cache is a small LRU.

The cache previously clear()ed wholesale when full, so the fifth distinct
file dropped every entry including the hottest one. Eviction must instead
drop the least recently used entry and keep hot entries resident.
"""

import os;
import tempfile;
import jaclang.compiler.driver.jir as jir;
import from jaclang.compiler.driver.jir { read_source_shared }


"""Write count files under base and return their paths."""
def _write_files(base: str, count: int) -> list[str] {
    paths: list[str] = [];
    for i in range(count) {
        p = os.path.join(base, f"m{i}.txt");
        with open(p, "w") as fh {
            fh.write(f"src-{i}");
        }
        paths.append(p);
    }
    return paths;
}

test "a hot entry survives an insert burst past capacity" {
    saved = dict(jir._SRC_SHARED);
    jir._SRC_SHARED.clear();
    try {
        with tempfile.TemporaryDirectory() as tmp {
            paths = _write_files(tmp, 5);
            hot = paths[0];
            assert read_source_shared(hot) == "src-0";
            for p in paths[1:4] {
                read_source_shared(p);
            }
            assert len(jir._SRC_SHARED) == 4;
            # a hit refreshes recency, so the hot entry is no longer oldest
            assert read_source_shared(hot) == "src-0";
            read_source_shared(paths[4]);
            assert hot in jir._SRC_SHARED , (
                "the fifth insert dropped the hot entry: not an LRU"
            );
            assert paths[1] not in jir._SRC_SHARED , (
                "expected the least recently used entry to be the one evicted"
            );
            assert len(jir._SRC_SHARED) == 4 , "cache exceeded its capacity";
        }
    } finally {
        jir._SRC_SHARED.clear();
        jir._SRC_SHARED.update(saved);
    }
}

test "a stale entry is refreshed in place without growing the cache" {
    saved = dict(jir._SRC_SHARED);
    jir._SRC_SHARED.clear();
    try {
        with tempfile.TemporaryDirectory() as tmp {
            paths = _write_files(tmp, 4);
            for p in paths {
                read_source_shared(p);
            }
            assert len(jir._SRC_SHARED) == 4;
            with open(paths[0], "w") as fh {
                fh.write("src-0-rewritten");
            }
            assert read_source_shared(paths[0]) == "src-0-rewritten";
            assert len(jir._SRC_SHARED) == 4;
            assert paths[1] in jir._SRC_SHARED;
        }
    } finally {
        jir._SRC_SHARED.clear();
        jir._SRC_SHARED.update(saved);
    }
}
