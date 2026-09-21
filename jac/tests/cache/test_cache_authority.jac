"""The cache authority: one root rule, one registry of buckets, one sweep.

`~/.cache/jac` used to have five independent root resolvers and, apart from
the module-generation bucket, nothing was ever evicted. `jaclang.cache` now
owns the root (JAC_CACHE_HOME, else XDG_CACHE_HOME/jac, else the platform
default), stamps CACHEDIR.TAG, declares every bucket with its retention
policy, and provides the single best-effort sweep every writer and `jac cache`
run through. These tests exercise that contract on private roots only; the
real user cache is never touched.
"""

import os;
import shutil;
import stat;
import sys;
import tempfile;
import time;
import from pathlib { Path }
import from unittest.mock { patch }
import from tests.support { cache_env }
import from jaclang.cache.locking { FileLock }
import from jaclang.toolchains.store { InstallLock }
import from jaclang.jac0core.cache_paths { get_cache_home, get_jir_cache_dir }
import from jaclang.cache.home {
    CACHEDIR_TAG,
    CACHEDIR_TAG_TEXT,
    cache_home,
    ensure_root
}
import from jaclang.cache.policy {
    Policy,
    WriterState,
    TemporaryClaim,
    Retention,
    SWEEP_SENTINEL,
    TMP_TTL_SECONDS,
    maybe_sweep_dir,
    sweep_dir
}
import from jaclang.cache.registry {
    BUCKETS,
    RETIRED,
    bucket,
    gc,
    managed_buckets,
    purge,
    status,
    unmanaged
}

glob DAY: float = 86400.0,
     EXPECTED_BUCKETS: set[str] = {
         "rt",
         "jir-modules",
         "jir-bootstrap",
         "jir-stubcat",
         "jir-kernel-units",
         "jir-digests",
         "apps",
         "scale-binaries",
         "models",
         "toolchains-downloads",
         "toolchains-installed",
         "toolchains-build",
         "toolchains-gradle",
         "toolchains-android-sdk",
         "pg"
     };

"""Set a path's mtime `seconds_ago` before now."""
def backdate(path: Path, seconds_ago: float) {
    t = time.time() - seconds_ago;
    os.utime(path, (t, t));
}

"""A fresh private cache root, exported as JAC_CACHE_HOME for the block."""
def private_root -> tuple[Path, dict[str, str]] {
    base = Path(tempfile.mkdtemp(prefix="jac-cache-test-"));
    return (base, cache_env(base));
}

def entry_dir(base: Path, name: str, age: float, marker: str = "") -> Path {
    d = base / name;
    d.mkdir(parents=True, exist_ok=True);
    (d / "blob").write_bytes(b"x" * 1024);
    if marker {
        (d / marker).write_bytes(b"");
        backdate(d / marker, age);
    }
    backdate(d, age);
    return d;
}

test "JAC_CACHE_HOME wins over XDG_CACHE_HOME, which wins over the platform default" {
    tmp = Path(tempfile.mkdtemp());
    explicit = tmp / "explicit";
    xdg = tmp / "xdg";
    with patch.dict(
        os.environ, {"JAC_CACHE_HOME": str(explicit), "XDG_CACHE_HOME": str(xdg)}
    ) {
        assert cache_home() == explicit;
        assert get_cache_home() == explicit;
    }
    with patch.dict(os.environ, {"XDG_CACHE_HOME": str(xdg)}) {
        os.environ.pop("JAC_CACHE_HOME", None);
        assert cache_home() == xdg / "jac";
    }
    with patch.dict(os.environ, {}) {
        os.environ.pop("JAC_CACHE_HOME", None);
        os.environ.pop("XDG_CACHE_HOME", None);
        home = cache_home();
        if sys.platform == "darwin" {
            assert home == Path.home() / "Library" / "Caches" / "jac";
        } elif sys.platform == "win32" {
            assert home.name == "cache" and home.parent.name == "jac";
        } else {
            assert home == Path.home() / ".cache" / "jac";
        }
    }
    with patch.dict(os.environ, {"JAC_CACHE_HOME": "~/somewhere/jac-cache"}) {
        assert cache_home() == Path.home() / "somewhere" / "jac-cache" , "a tilde in JAC_CACHE_HOME must expand";
    }
}

test "every pre-bootstrap path derives from the one root" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        assert get_jir_cache_dir() == base / "jir";
        assert bucket("jir-modules").path() == base / "jir" / "modules";
        assert bucket("apps").path() == base / "apps";
        assert bucket("rt").path() == base / "rt";
    }
}

test "only disposable buckets are tagged and an old Jac root tag is retired" {
    (base, env) = private_root();
    (base / CACHEDIR_TAG).write_text(CACHEDIR_TAG_TEXT);
    pg = entry_dir(base, "pg/main", 0.0);
    with patch.dict(os.environ, env) {
        assert ensure_root() == base;
        assert not (base / CACHEDIR_TAG).exists();
        rt = bucket("rt").ensure();
        assert (rt / CACHEDIR_TAG).read_text() == CACHEDIR_TAG_TEXT;
        bucket("pg").ensure();
        assert not (base / "pg" / CACHEDIR_TAG).exists();
        assert pg.exists();
        (base / CACHEDIR_TAG).write_text("user backup policy");
        ensure_root();
        assert (base / CACHEDIR_TAG).read_text() == "user backup policy";
    }
}

test "the registry names every bucket the tree writes, each with a policy" {
    names = {b.name for b in BUCKETS};
    missing = EXPECTED_BUCKETS - names;
    assert not missing , f"buckets missing from the registry: {sorted(missing)}";
    assert len(names) == len(BUCKETS) , "bucket names must be unique";
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        for b in BUCKETS {
            assert str(b.path()).startswith(str(base)) , f"{b.name} does not live under the shared root";
            assert b.policy.describe() , f"{b.name} has no policy description";
        }
    }
    assert bucket("models").policy.retention == Retention.PINNED;
    assert bucket("pg").policy.retention == Retention.EXTERNAL;
    assert bucket("toolchains-gradle").policy.retention == Retention.EXTERNAL;
    assert bucket("rt").policy.retention == Retention.LAST_USE;
    managed = {b.name for b in managed_buckets()};
    assert "pg" not in managed and "toolchains-gradle" not in managed;
    assert "rt" in managed and "jir-modules" in managed;
    raised = False;
    try {
        bucket("no-such-bucket");
    } except KeyError {
        raised = True;
    }
    assert raised , "an unregistered bucket name must be refused, not invented";
    assert "seal-tests" in RETIRED and "timing" in RETIRED;
}

test "sweep_dir removes entries unused past the TTL and keeps live and fresh ones" {
    base = Path(tempfile.mkdtemp());
    policy = Policy(retention=Retention.LAST_USE, ttl_days=14.0, markers=[".used"]);
    expired = entry_dir(base, "expired", 40.0 * DAY, ".used");
    fresh = entry_dir(base, "fresh", 1.0 * DAY, ".used");
    live = entry_dir(base, "live", 40.0 * DAY, ".used");
    # A marker touched recently outranks an old directory mtime.
    touched = entry_dir(base, "touched", 40.0 * DAY, ".used");
    os.utime(touched / ".used", None);
    result = sweep_dir(base, policy, keep={"live"});
    assert not expired.exists() , "an entry unused past the TTL survived";
    assert fresh.exists() and live.exists() and touched.exists();
    assert result.removed == ["expired"];
    assert result.reclaimed_bytes >= 1024;
    assert result.kept == 3;
}

test "sweep_dir reclaims orphaned temp extractions older than an hour" {
    base = Path(tempfile.mkdtemp());
    policy = Policy(retention=Retention.LAST_USE, ttl_days=14.0);
    stale_tmp = entry_dir(base, "0123456789abcdef.tmp.4242", TMP_TTL_SECONDS + 60.0);
    fresh_tmp = entry_dir(base, "fedcba9876543210.tmp.pending", 60.0);
    stale_file = base / "mod.4242.tmp";
    stale_file.write_bytes(b"x");
    backdate(stale_file, TMP_TTL_SECONDS + 60.0);
    with patch(
        "jaclang.cache.policy.temporary_owner", return_value=WriterState.INACTIVE
    ) {
        result = sweep_dir(base, policy);
    }
    assert not stale_tmp.exists() , "a crashed extraction older than an hour must be reclaimed";
    assert not stale_file.exists() , "a crashed writer's temp file must be reclaimed";
    assert fresh_tmp.exists() , "an extraction in progress must be left alone";
    assert sorted(result.removed)
        == sorted(["0123456789abcdef.tmp.4242", "mod.4242.tmp"]);
}

test "sweep_dir never touches a pinned bucket and reports nothing for it" {
    base = Path(tempfile.mkdtemp());
    old = entry_dir(base, "weights", 400.0 * DAY);
    result = sweep_dir(base, Policy(retention=Retention.PINNED, ttl_days=14.0));
    assert old.exists();
    assert result.removed == [];
}

test "sweep_dir caps the entry count, evicting the least recently used first" {
    base = Path(tempfile.mkdtemp());
    for i in range(6) {
        f = base / f"entry{i}.jbc";
        f.write_bytes(b"x");
        backdate(f, float(6 - i) * 60.0);
    }
    policy = Policy(retention=Retention.LAST_USE, ttl_days=14.0, max_entries=4);
    result = sweep_dir(base, policy);
    assert sorted(result.removed) == ["entry0.jbc", "entry1.jbc"];
    assert len([p for p in base.iterdir()]) == 4;
}

test "sweep_dir walks to the declared depth and prunes emptied parents" {
    base = Path(tempfile.mkdtemp());
    policy = Policy(
        retention=Retention.LAST_USE,
        ttl_days=14.0,
        depth=3,
        markers=[".jac-install.json"]
    );
    stale = entry_dir(base, "ndk/26/linux-x64-abcd", 100.0 * DAY, ".jac-install.json");
    live = entry_dir(base, "jdk/17/linux-x64-ef01", 1.0 * DAY, ".jac-install.json");
    lock = base / "ndk" / "26" / "linux-x64-abcd.lock";
    lock.write_bytes(b"");
    backdate(lock, 100.0 * DAY);
    result = sweep_dir(base, policy);
    assert not stale.exists();
    assert lock.exists() , "lock inodes must survive collection so existing waiters remain synchronized";
    assert live.exists();
    assert result.removed == ["ndk/26/linux-x64-abcd"];
}

test "sweep_dir only sees entries matching the bucket pattern" {
    base = Path(tempfile.mkdtemp());
    digest = base / "compiler_digest.abcd1234.json";
    digest.write_bytes(b"{}");
    other = base / "notes.txt";
    other.write_bytes(b"keep");
    backdate(digest, 40.0 * DAY);
    backdate(other, 40.0 * DAY);
    policy = Policy(
        retention=Retention.LAST_USE, ttl_days=14.0, pattern="compiler_digest.*.json"
    );
    result = sweep_dir(base, policy);
    assert not digest.exists();
    assert other.exists() , "the sweep removed something the bucket does not own";
    assert result.removed == ["compiler_digest.abcd1234.json"];
}

test "sweep_dir is best-effort: an undeletable entry is skipped, not raised" {
    if os.name != "posix" or os.geteuid() == 0 {
        return;
    }
    base = Path(tempfile.mkdtemp());
    locked = entry_dir(base, "locked", 40.0 * DAY);
    inner = locked / "inner";
    inner.mkdir();
    (inner / "file").write_bytes(b"x");
    os.chmod(inner, stat.S_IRUSR | stat.S_IXUSR);
    # Adding `inner` refreshed the entry's mtime; age it again.
    backdate(locked, 40.0 * DAY);
    gone = entry_dir(base, "gone", 40.0 * DAY);
    try {
        result = sweep_dir(base, Policy(retention=Retention.LAST_USE, ttl_days=14.0));
    } finally {
        os.chmod(inner, stat.S_IRWXU);
    }
    assert not gone.exists() , "the deletable sibling must still be reclaimed";
    assert "gone" in result.removed;
    assert "locked" not in result.removed , "a partial removal must not be reported as reclaimed";
    assert result.errors , "the failure must be recorded, not hidden";
}

test "sweep_dir dry run reports what it would remove and removes nothing" {
    base = Path(tempfile.mkdtemp());
    expired = entry_dir(base, "expired", 40.0 * DAY);
    result = sweep_dir(
        base, Policy(retention=Retention.LAST_USE, ttl_days=14.0), dry_run=True
    );
    assert expired.exists();
    assert result.removed == ["expired"];
    assert result.reclaimed_bytes >= 1024;
}

test "a zero TTL disables the age sweep" {
    base = Path(tempfile.mkdtemp());
    old = entry_dir(base, "old", 400.0 * DAY);
    result = sweep_dir(base, Policy(retention=Retention.LAST_USE, ttl_days=0.0));
    assert old.exists();
    assert result.removed == [];
}

test "JAC_CACHE_TTL_DAYS overrides every bucket default and a bucket env overrides that" {
    generic = Policy(retention=Retention.LAST_USE, ttl_days=14.0);
    specific = Policy(
        retention=Retention.LAST_USE,
        ttl_days=14.0,
        ttl_env="JAC_CACHE_GENERATION_TTL_DAYS"
    );
    with patch.dict(os.environ, {"JAC_CACHE_TTL_DAYS": "3"}) {
        os.environ.pop("JAC_CACHE_GENERATION_TTL_DAYS", None);
        assert generic.ttl_seconds() == 3.0 * DAY;
        assert specific.ttl_seconds() == 3.0 * DAY;
    }
    with patch.dict(
        os.environ, {"JAC_CACHE_TTL_DAYS": "3", "JAC_CACHE_GENERATION_TTL_DAYS": "7"}
    ) {
        assert generic.ttl_seconds() == 3.0 * DAY;
        assert specific.ttl_seconds() == 7.0 * DAY;
    }
    with patch.dict(os.environ, {"JAC_CACHE_TTL_DAYS": "not-a-number"}) {
        os.environ.pop("JAC_CACHE_GENERATION_TTL_DAYS", None);
        assert generic.ttl_seconds() == 14.0 * DAY , "garbage in the env falls back to the default";
    }
}

test "maybe_sweep_dir is throttled by the sentinel and by the process" {
    base = Path(tempfile.mkdtemp());
    policy = Policy(retention=Retention.LAST_USE, ttl_days=14.0);
    first = entry_dir(base, "first", 40.0 * DAY);
    assert maybe_sweep_dir(base, policy) , "the first sweep of a root must run";
    assert not first.exists();
    assert (base / SWEEP_SENTINEL).is_file();
    second = entry_dir(base, "second", 40.0 * DAY);
    assert not maybe_sweep_dir(base, policy) , "a second sweep in the same process must not run";
    assert second.exists();
    backdate(base / SWEEP_SENTINEL, 2.0 * DAY);
    assert not maybe_sweep_dir(base, policy) , "the per-process throttle holds even past the sentinel interval";
    assert maybe_sweep_dir(base, policy, force=True);
    assert not second.exists();
}

test "gc runs every managed policy under the root, reports bytes, and dry-run removes nothing" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        rt = bucket("rt").path();
        expired = entry_dir(rt, "0123456789abcdef", 60.0 * DAY, ".used");
        fresh = entry_dir(rt, "fedcba9876543210", 1.0 * DAY, ".used");
        apps = bucket("apps").path();
        old_app = entry_dir(apps, "a" * 20, 60.0 * DAY, ".used");
        weights = entry_dir(bucket("models").path(), "gemma", 400.0 * DAY);
        pg = bucket("pg").path();
        pg_data = entry_dir(pg, "main", 400.0 * DAY);
        retired = entry_dir(base, "seal-tests", 1.0 * DAY);
        dry = gc(dry_run=True);
        assert expired.exists() and old_app.exists() and retired.exists();
        by_name = {r.bucket: r for r in dry};
        assert "rt" in by_name and by_name["rt"].removed == ["0123456789abcdef"];
        assert "pg" not in by_name , "an external bucket is never swept";
        reports = gc();
        assert not expired.exists() , "gc left an expired runtime behind";
        assert fresh.exists();
        assert not old_app.exists();
        assert weights.exists() , "a pinned bucket must survive gc";
        assert pg_data.exists() , "gc must not reach into pg/";
        assert not retired.exists() , "a retired bucket is removed wholesale";
        total = sum([r.reclaimed_bytes for r in reports]);
        assert total >= 3 * 1024;
    }
}

test "status lists every registered bucket with its path, size and policy" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        entry_dir(bucket("rt").path(), "0123456789abcdef", 0.0, ".used");
        entry_dir(bucket("pg").path(), "main", 0.0);
        rows = status();
    }
    names = {r.name for r in rows};
    assert EXPECTED_BUCKETS <= names , f"status omitted {sorted(
        EXPECTED_BUCKETS - names
    )}";
    by_name = {r.name: r for r in rows};
    assert by_name["rt"].entries == 1;
    assert by_name["rt"].size_bytes >= 1024;
    assert str(by_name["rt"].path) == str(base / "rt");
    assert by_name["pg"].external;
    assert by_name["pg"].size_bytes >= 1024 , "external buckets are still measured";
    assert not by_name["jir-modules"].exists , "an absent bucket reports as absent, not as an error";
    assert by_name["models"].policy , "every row carries a policy description";
}

test "purge removes managed buckets and refuses external ones" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        rt = entry_dir(bucket("rt").path(), "0123456789abcdef", 0.0, ".used");
        pg = entry_dir(bucket("pg").path(), "main", 0.0);
        models = entry_dir(bucket("models").path(), "gemma", 0.0);
        refused = False;
        try {
            purge(["pg"]);
        } except ValueError {
            refused = True;
        }
        assert refused and pg.exists() , "purge must refuse an external bucket";
        result = purge(["rt"]);
        assert not rt.exists();
        assert models.exists() , "a named purge touches only that bucket";
        assert result.reclaimed_bytes >= 1024;
        result = purge(None);
        assert not models.exists() , "a full purge clears pinned buckets too";
        assert pg.exists() , "a full purge still leaves external buckets alone";
    }
}


test "inspection and purge include staging while unknown JIR content remains visible" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        install = entry_dir(
            base, "toolchains/installed/demo/v1/.install-abandoned", 120.0 * DAY
        );
        (install.parent / "platform.lock").touch();
        runtime = entry_dir(base, "rt/abc.tmp.4242", 120.0 * DAY);
        unknown = entry_dir(base, "jir/unregistered", 120.0 * DAY);
        rows = {r.name: r for r in status()};
        assert rows["toolchains-installed"].size_bytes == 1024;
        assert rows["rt"].size_bytes == 1024;
        assert rows["jir-digests"].size_bytes == 0;
        assert unmanaged() == [("jir/unregistered", 1024)];
        with patch(
            "jaclang.cache.policy.temporary_owner", return_value=WriterState.INACTIVE
        ) {
            # Lazy compiler imports can populate other buckets in this private root.
            # Account for the fixture buckets only, including the unmanaged JIR.
            dry = purge(["toolchains-installed", "rt", "jir-digests"], dry_run=True);
        }
        assert dry.reclaimed_bytes == 2048;
        assert install.exists() and runtime.exists();
        with patch(
            "jaclang.cache.policy.temporary_owner", return_value=WriterState.INACTIVE
        ) {
            result = purge(["toolchains-installed", "rt", "jir-digests"]);
        }
        assert result.reclaimed_bytes == 2048;
        assert not install.exists() and not runtime.exists();
        assert unknown.exists();
    }
}

test "nested staging uses the orphan TTL and never follows symlinks" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        parent = bucket("toolchains-installed").path();
        old = entry_dir(parent, "demo/v1/.install-old", TMP_TTL_SECONDS + 60.0);
        fresh = entry_dir(parent, "demo/v1/.install-fresh", 60.0);
        old_build = entry_dir(
            bucket("toolchains-build").path(),
            "demo/linux/tmpdeadbeef",
            TMP_TTL_SECONDS + 60.0
        );
        (old.parent / "platform.lock").touch();
        (old_build.parent / "build.lock").touch();
        named_tool = entry_dir(
            parent, ".install-tool/v1/platform", 0.0, ".jac-install.json"
        );
        active = entry_dir(parent, f"demo/v1/.tmp.{os.getpid()}.active", 120.0 * DAY);
        backdate(parent / ".install-tool", TMP_TTL_SECONDS + 60.0);
        outside = entry_dir(base, "outside", 120.0 * DAY);
        link = parent / "linked";
        try {
            link.symlink_to(outside, target_is_directory=True);
        } except OSError {}
        gc();
        assert not old.exists();
        assert fresh.exists() and active.exists();
        assert not old_build.exists();
        assert named_tool.exists();
        assert (outside / "blob").is_file();
        purge(["toolchains-installed"]);
        assert active.exists() , "purge must not delete staging owned by a live writer";
        assert not fresh.exists();
    }
}

test "retired toolchains honor custom roots and never remove an active bucket root" {
    (base, env) = private_root();
    with tempfile.TemporaryDirectory() as custom {
        env["JAC_TOOLCHAIN_DIR"] = custom;
        old = entry_dir(Path(custom), "llvm-cbe", 0.0);
        default_old = entry_dir(base, "toolchains/cocoapods", 0.0);
        with patch.dict(os.environ, env) {
            extra = dict(unmanaged());
            assert str(old) in extra;
            gc(dry_run=True);
            assert old.exists() and default_old.exists();
            gc();
            assert not old.exists() and not default_old.exists();
        }
        env["JAC_TOOLCHAIN_DIR"] = str(base / "toolchains/llvm-cbe");
        with patch.dict(os.environ, env) {
            active = entry_dir(
                bucket("toolchains-installed").path(), "demo/v1/platform", 0.0
            );
            gc();
            assert active.exists();
        }
    }
}

test "private test environments override every inherited cache family" {
    with tempfile.TemporaryDirectory() as tmp {
        inherited = {
            "JAC_CACHE_HOME": "/unrelated",
            "JAC_TOOLCHAIN_DIR": "/unrelated-tools",
            "JAC_MODELS_DIR": "/unrelated-models",
            "JAC_SCALE_CACHE_DIR": "/unrelated-binaries"
        };
        with patch.dict(os.environ, inherited) {
            with patch.dict(os.environ, cache_env(tmp)) {
                for b in BUCKETS {
                    assert b.path().is_relative_to(Path(tmp).resolve());
                }
            }
            assert os.environ["JAC_CACHE_HOME"] == "/unrelated";
        }
    }
}


test "temporary ownership keeps inaccessible writers and reclaims exited writers" {
    import from jaclang.cache.policy { temporary_owner }
    if os.name != "posix" {
        testskip("POSIX process-probe error semantics");
    }
    item = Path("artifact.tmp.4242");
    with patch("os.kill", side_effect=PermissionError) {
        assert temporary_owner(item) == WriterState.UNKNOWN;
    }
    with patch("os.kill", side_effect=ProcessLookupError) {
        assert temporary_owner(item) == WriterState.INACTIVE;
    }
    with patch("os.kill") as probe {
        assert temporary_owner(item) == WriterState.ACTIVE;
        probe.assert_called_once_with(4242, 0);
    }
}


test "legacy writers keep staging through purge and GC until their locks are released" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        for (name, rel) in [
            ("toolchains-downloads", "archive.part"),
            ("toolchains-installed", "demo/v1/.install-active"),
            ("toolchains-build", "demo/linux/tmpdeadbeef")
        ] {
            p = bucket(name).path() / rel;
            lock_path = p.with_suffix(".lock")
                if name == "toolchains-downloads"
                else p.parent / "platform.lock";
            with InstallLock(lock_path) {
                # Older writers acquire the lock before creating PID-less staging.
                if name == "toolchains-downloads" {
                    item = p;
                    item.write_bytes(b"partial archive");
                    backdate(item, 120.0 * DAY);
                } else {
                    item = entry_dir(bucket(name).path(), rel, 120.0 * DAY);
                }
                dry = purge([name], dry_run=True);
                assert len(dry.kept) == 1 and not dry.removed;
                gc();
                assert item.exists();
                result = purge([name]);
                assert item.exists() and len(result.kept) == 1;
            }
            if name == "toolchains-installed" {
                gc();
            } else {
                purge([name]);
            }
            assert not item.exists();
            assert lock_path.exists();
        }
    }
}

test "unknown temporary ownership is preserved even beyond the orphan TTL" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        for (name, rel) in [
            ("rt", "artifact.tmp.unknown"),
            ("toolchains-downloads", "archive.part"),
            ("toolchains-installed", "demo/v1/.install-unknown"),
            ("toolchains-build", "demo/linux/tmpunknown1")
        ] {
            item = entry_dir(bucket(name).path(), rel, 120.0 * DAY);
            gc();
            result = purge([name]);
            assert item.exists() and len(result.kept) == 1;
        }
    }
}

test "temporary claims hold sibling locks and release them after a partial acquisition" {
    (base, env) = private_root();
    with patch.dict(os.environ, env) {
        b = bucket("toolchains-installed");
        item = entry_dir(b.path(), "demo/v1/.install-old", 120.0 * DAY);
        first = item.parent / "a.lock";
        second = item.parent / "b.lock";
        first.touch();
        with InstallLock(second) {
            with TemporaryClaim(item, b.policy) as claim {
                assert not claim.reclaimable;
            }
            probe = FileLock(first);
            assert probe.acquire(create=False);
            probe.release();
        }
        with TemporaryClaim(item, b.policy) as claim {
            assert claim.reclaimable;
            probe = FileLock(second);
            assert not probe.acquire(create=False);
        }
        assert probe.acquire(create=False);
        probe.release();
        with patch(
            "jaclang.cache.locking.FileLock.acquire", side_effect=PermissionError
        ) {
            assert len(purge([b.name]).kept) == 1;
            assert item.exists();
        }
    }
}
