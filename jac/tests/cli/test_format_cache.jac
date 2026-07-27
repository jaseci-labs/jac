"""Unit tests for the FormatCache deep module (`jaclang.cli.format_cache`).

The cache is a content-addressed store of *proven-clean* format results.
A valid entry proves:

    (content digest + lintfix mode + config fingerprint
     + logical path when lintfix + formatter stamp) -> clean

These tests exercise the module only through its public interface:
  - FormatCache(cache_dir, enabled, formatter_stamp)
  - make_key(content, lintfix=, config_fingerprint=, logical_path=) -> hex digest
  - is_clean(key) -> bool
  - mark_clean(key) -> None
  - entry_path(key) -> Path   (also the corruption-recovery hook)
  - config_fingerprint / canonical_logical_path / formatter_pipeline_revision

No JacProgram, no AST, no config discovery here -- those are integration
concerns covered by test_format_cache_integration.jac.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }

import time;

import from jaclang.cli.format_cache {
    FormatCache,
    FORMAT_CACHE_SCHEMA_VERSION,
    ENTRY_TTL_SECONDS,
    PRUNE_INTERVAL_SECONDS,
    PRUNE_SENTINEL,
    config_fingerprint,
    canonical_logical_path,
    formatter_pipeline_revision,
    frame_unit
}


"""Set a path's mtime to `seconds_ago` before now (best-effort test helper)."""
def backdate(path: Path, seconds_ago: float) {
    t = time.time() - seconds_ago;
    os.utime(path, (t, t));
}


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

test "logical path changes the key under lintfix" {
    # lint.exclude is path-sensitive; identical bytes in an excluded vs
    # non-excluded path must not share a clean entry under lintfix.
    (cache, _d) = fresh_cache();
    try {
        k_src = cache.make_key(
            b"x", lintfix=True, config_fingerprint="cfg", logical_path="src/a.jac"
        );
        k_vendor = cache.make_key(
            b"x", lintfix=True, config_fingerprint="cfg", logical_path="vendor/a.jac"
        );
        assert k_src != k_vendor , (
            "path-sensitive lintfix keys must differ across logical paths"
        );
        cache.mark_clean(k_src);
        assert cache.is_clean(k_src);
        assert not cache.is_clean(k_vendor) , (
            "a clean entry for src/ must not satisfy vendor/"
        );
        # Without lintfix, path is ignored (content-addressed rename-stable).
        k_a = cache.make_key(
            b"x", lintfix=False, config_fingerprint="cfg", logical_path="src/a.jac"
        );
        k_b = cache.make_key(
            b"x", lintfix=False, config_fingerprint="cfg", logical_path="vendor/a.jac"
        );
        assert k_a == k_b , "without lintfix, path must not affect the key";
    } finally {
        shutil.rmtree(_d, ignore_errors=True);
    }
}

test "config_fingerprint includes suppress settings" {
    import from jaclang.project.config { JacConfig }

    base = JacConfig();
    base.check.suppress = [];
    base.check.suppress_categories = [];
    with_suppress = JacConfig();
    with_suppress.check.suppress = ["E1030"];
    with_suppress.check.suppress_categories = [];
    with_cat = JacConfig();
    with_cat.check.suppress = [];
    with_cat.check.suppress_categories = ["lint"];
    fp_base = config_fingerprint(base, True);
    fp_suppress = config_fingerprint(with_suppress, True);
    fp_cat = config_fingerprint(with_cat, True);
    assert fp_base != fp_suppress , (
        "check.suppress must invalidate the config fingerprint under lintfix"
    );
    assert fp_base != fp_cat , (
        "check.suppress_categories must invalidate the config fingerprint"
    );
    # Without lintfix, check section is not folded in.
    assert config_fingerprint(base, False) == config_fingerprint(with_suppress, False);
}

test "canonical_logical_path prefers project-relative form" {
    proj_root = "/home/me/proj";
    assert canonical_logical_path("/home/me/proj/src/a.jac", proj_root) == "src/a.jac";
    assert canonical_logical_path("src/a.jac", None).replace("\\", "/").endswith(
        "src/a.jac"
    );
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

test "formatter_pipeline_revision is stable and non-empty" {
    a = formatter_pipeline_revision();
    b = formatter_pipeline_revision();
    assert a , "pipeline revision must be non-empty";
    assert a == b , "pipeline revision must be stable across calls";
    assert len(a) == 16 , f"expected 16-hex digest prefix, got {a!r}";
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

test "stale entries are pruned on the next write after ttl expiry" {
    (cache, d) = fresh_cache();
    try {
        ka = cache.make_key(b"old", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(ka);
        # Age the entry past the TTL and the sentinel past the throttle
        # window, then any subsequent write must sweep the stale entry.
        backdate(cache.entry_path(ka), ENTRY_TTL_SECONDS + 60.0);
        backdate(cache.cache_root / PRUNE_SENTINEL, PRUNE_INTERVAL_SECONDS + 60.0);
        kb = cache.make_key(b"new", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(kb);
        assert not cache.entry_path(ka).exists() , (
            "an entry unused for longer than the TTL must be pruned on write"
        );
        assert cache.is_clean(kb) , "the entry just written must survive the prune";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "hits refresh entry mtime so active entries survive pruning" {
    (cache, d) = fresh_cache();
    try {
        ka = cache.make_key(b"hot", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(ka);
        backdate(cache.entry_path(ka), ENTRY_TTL_SECONDS + 60.0);
        # A hit must reset the entry's age...
        assert cache.is_clean(ka);
        # ...so the next prune keeps it.
        backdate(cache.cache_root / PRUNE_SENTINEL, PRUNE_INTERVAL_SECONDS + 60.0);
        kb = cache.make_key(b"new", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(kb);
        assert cache.entry_path(ka).exists() , (
            "an entry hit since its last write must never be pruned"
        );
        assert cache.is_clean(ka);
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "prune is throttled by the sentinel interval" {
    (cache, d) = fresh_cache();
    try {
        ka = cache.make_key(b"old", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(ka);
        backdate(cache.entry_path(ka), ENTRY_TTL_SECONDS + 60.0);
        # Sentinel is fresh (created by the first write), so this write
        # must NOT rescan the store even though ka is past the TTL.
        kb = cache.make_key(b"new", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(kb);
        assert cache.entry_path(ka).exists() , (
            "prune must run at most once per interval, not on every write"
        );
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "entry count is capped by evicting oldest first" {
    d = Path(tempfile.mkdtemp(prefix="fmtcache-cap-"));
    try {
        cache = FormatCache(d, enabled=True, formatter_stamp="s", max_entries=3);
        keys: list[str] = [];
        for i in range(5) {
            k = cache.make_key(
                f"content-{i}".encode(), lintfix=False, config_fingerprint="cfg"
            );
            cache.mark_clean(k);
            keys.append(k);
        }
        # Stagger ages: keys[0] oldest ... keys[4] newest, all within TTL.
        for (i, k) in enumerate(keys) {
            backdate(cache.entry_path(k), 3600.0 - i * 60.0);
        }
        backdate(cache.cache_root / PRUNE_SENTINEL, PRUNE_INTERVAL_SECONDS + 60.0);
        k_new = cache.make_key(b"trigger", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(k_new);
        # 6 live entries, cap 3 -> the 3 oldest (keys[0..2]) must go.
        for k in keys[:3] {
            assert not cache.entry_path(k).exists() , (
                "over the cap, the oldest entries must be evicted first"
            );
        }
        for k in keys[3:] {
            assert cache.entry_path(k).exists() , (
                "under the cap, newer entries must be kept"
            );
        }
        assert cache.is_clean(k_new);
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "orphaned temp files are swept by prune" {
    (cache, d) = fresh_cache();
    try {
        ka = cache.make_key(b"x", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(ka);
        # A crashed writer leaves .<digest>.<pid>.tmp behind; prune must
        # sweep it once it is old enough to be unambiguously dead.
        orphan = cache.cache_root / ".deadbeef.99999.tmp";
        orphan.write_bytes(b"partial");
        backdate(orphan, PRUNE_INTERVAL_SECONDS + 60.0);
        backdate(cache.cache_root / PRUNE_SENTINEL, PRUNE_INTERVAL_SECONDS + 60.0);
        kb = cache.make_key(b"y", lintfix=False, config_fingerprint="cfg");
        cache.mark_clean(kb);
        assert not orphan.exists() , "stale writer temp files must be swept";
        assert cache.is_clean(ka) , "fresh entries must survive the sweep";
    } finally {
        shutil.rmtree(d, ignore_errors=True);
    }
}

test "frame_unit is unambiguous and byte-stable" {
    # The unit framer feeds make_key's `content`, so its output must be both
    # unambiguous (different part splits never collide) and byte-stable (a
    # change to the framing would silently invalidate every existing cache
    # entry, so lock the exact bytes a future "helpful" change would break).
    # Plain b"".join would make these identical; length framing must not.
    assert frame_unit([b"ab", b"c"]) != frame_unit([b"a", b"bc"]) , (
        "length framing must distinguish different part boundaries"
    );
    assert frame_unit([b"hello"]) == b"5:hello";
    assert frame_unit([b"ab", b"c"]) == b"2:ab1:c";
}
