"""Unit tests for the FormatCache deep module (`jaclang.cli.format_cache`).

The cache is a content-addressed store of *proven-clean* format results.
A valid entry proves:

    (content digest + lintfix mode + config fingerprint + formatter stamp) -> clean

These tests exercise the module only through its public interface:
  - FormatCache(cache_dir, enabled, formatter_stamp)
  - make_key(content, lintfix=, config_fingerprint=) -> hex digest
  - is_clean(key) -> bool
  - mark_clean(key) -> None
  - entry_path(key) -> Path   (also the corruption-recovery hook)

No JacProgram, no AST, no config discovery here -- those are integration
concerns covered by test_cli.jac / test_precommit.jac.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }

import from jaclang.cli.format_cache { FormatCache, FORMAT_CACHE_SCHEMA_VERSION }


"""Build a FormatCache rooted at a fresh temp dir. Returns (cache, dir)."""
def fresh_cache(stamp: str = "test-stamp-1") -> tuple[FormatCache, Path] {
    d = Path(tempfile.mkdtemp(prefix="fmtcache-"));
    return (FormatCache(d, enabled=True, formatter_stamp=stamp), d);
}

test "format cache misses when empty" {
    (cache, _d) = fresh_cache();
    try {
        key = cache.make_key(b"hello", lintfix=False, config_fingerprint="cfg");
        assert not cache.is_clean(key) , "a brand-new cache must miss for every key";
    } finally {
        shutil.rmtree(_d, ignore_errors=True);
    }
}

test "format cache hit after mark_clean" {
    (cache, _d) = fresh_cache();
    try {
        key = cache.make_key(b"hello", lintfix=False, config_fingerprint="cfg");
        assert not cache.is_clean(key);
        cache.mark_clean(key);
        assert cache.is_clean(key) , "mark_clean must make the same key clean";
    } finally {
        shutil.rmtree(_d, ignore_errors=True);
    }
}

test "different content produces different keys" {
    (cache, _d) = fresh_cache();
    try {
        ka = cache.make_key(b"aaa", lintfix=False, config_fingerprint="cfg");
        kb = cache.make_key(b"bbb", lintfix=False, config_fingerprint="cfg");
        assert ka != kb , "content change must change the key";
        # And one clean entry must not satisfy a different content key.
        cache.mark_clean(ka);
        assert cache.is_clean(ka);
        assert not cache.is_clean(kb);
    } finally {
        shutil.rmtree(_d, ignore_errors=True);
    }
}

test "lintfix mode changes the key" {
    (cache, _d) = fresh_cache();
    try {
        k_off = cache.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        k_on = cache.make_key(b"x", lintfix=True, config_fingerprint="cfg");
        assert k_off != k_on , "lintfix on/off run on different schedules -- keys must differ";
    } finally {
        shutil.rmtree(_d, ignore_errors=True);
    }
}

test "config fingerprint changes the key" {
    (cache, _d) = fresh_cache();
    try {
        k1 = cache.make_key(b"x", lintfix=True, config_fingerprint="lint-select-all");
        k2 = cache.make_key(
            b"x", lintfix=True, config_fingerprint="lint-select-default"
        );
        assert k1 != k2 , "a change in effective lint config must invalidate";
    } finally {
        shutil.rmtree(_d, ignore_errors=True);
    }
}

test "formatter stamp change invalidates across instances" {
    (cache_a, _da) = fresh_cache(stamp="formatter-1");
    (cache_b, _db) = fresh_cache(stamp="formatter-2");
    try {
        # Same content/config, but the cache directory is shared conceptually;
        # what matters is that a stamp bump yields a different digest so an old
        # clean entry cannot satisfy a new formatter.
        ka = cache_a.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        kb = cache_b.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        assert ka != kb , "formatter stamp change must invalidate the key";
    } finally {
        shutil.rmtree(_da, ignore_errors=True);
        shutil.rmtree(_db, ignore_errors=True);
    }
}

test "disabled cache never hits and never writes" {
    d = Path(tempfile.mkdtemp(prefix="fmtcache-off-"));
    try {
        cache = FormatCache(d, enabled=False, formatter_stamp="s");
        key = cache.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(key);
        assert not cache.is_clean(key) , "disabled cache must always miss";
        assert not any(d.iterdir()) , "disabled cache must not write any files";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "corrupt cache entry is treated as miss and removed" {
    (cache, d) = fresh_cache();
    try {
        key = cache.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        # Plant a garbage entry file exactly where the cache would look.
        junk = cache.entry_path(key);
        junk.parent.mkdir(parents=True, exist_ok=True);
        junk.write_bytes(b"not a valid cache entry, thank you");
        assert not cache.is_clean(key) , "a corrupt entry must miss, never false-hit";
        assert not junk.exists() , "a corrupt entry must be self-healing -- deleted on read";
        # And a subsequent mark_clean must work normally (directory usable).
        cache.mark_clean(key);
        assert cache.is_clean(key);
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "missing cache dir is a miss without error" {
    d = Path(tempfile.mkdtemp(prefix="fmtcache-missing-")) / "never" / "created";
    try {
        cache = FormatCache(d, enabled=True, formatter_stamp="s");
        key = cache.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        assert not cache.is_clean(key) , "missing cache dir must miss quietly";
    } finally {
        shutil.rmtree(d.parent.parent, ignore_errors=True);
    }
}

test "mark_clean is best-effort on an unwritable dir" {
    # A read-only cache directory: mark_clean must not raise. Whether the
    # write silently fails is the cache's business; the contract is "never
    # breaks the formatter".
    d = Path(tempfile.mkdtemp(prefix="fmtcache-ro-"));
    try {
        os.chmod(d, 0o555);
        cache = FormatCache(d, enabled=True, formatter_stamp="s");
        key = cache.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        ran = True;
        try {
            cache.mark_clean(key);
        } except Exception {
            ran = False;
        }
        assert ran , "mark_clean on an unwritable dir must not raise";
    } finally {
        os.chmod(d, 0o755);
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "schema version is namespaced so old entries cannot be misread" {
    # The on-disk layout must be namespaced by schema version so an
    # incompatible future change discards rather than interprets old state.
    (cache, d) = fresh_cache();
    try {
        key = cache.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(key);
        # The entry lives under a version-namespaced subtree.
        assert FORMAT_CACHE_SCHEMA_VERSION in str(
            cache.entry_path(key).relative_to(d)
        ) , (f"cache path must carry the schema version; got {cache.entry_path(key)}");
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "frame_unit is unambiguous and byte-stable" {
    # The unit framer feeds make_key's `content`, so its output must be both
    # unambiguous (different part splits never collide) and byte-stable (a
    # change to the framing would silently invalidate every existing cache
    # entry, so lock the exact bytes a future "helpful" change would break).
    import from jaclang.cli.format_cache { frame_unit }
    # Plain b"".join would make these identical; length framing must not.
    assert frame_unit([b"ab", b"c"]) != frame_unit([b"a", b"bc"]) , (
        "length framing must distinguish different part boundaries"
    );
    assert frame_unit([b"hello"]) == b"5:hello";
    assert frame_unit([b"ab", b"c"]) == b"2:ab1:c";
}
