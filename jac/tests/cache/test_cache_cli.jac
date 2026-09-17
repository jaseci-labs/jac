"""`jac cache`: the one command over the machine-wide cache.

`jac purge` reached a fifth of the cache (and two directories that no longer
exist); it is gone and tombstoned. `jac cache status` reports every bucket,
`jac cache gc` runs every policy now, `jac cache purge` clears managed
buckets and refuses external ones. The handler is exercised in-process on a
private root (a subprocess with a private root would recompile the compiler
cold); only the read-only `status` and the tombstone go through the real CLI.
"""

import contextlib;
import io;
import os;
import subprocess;
import sys;
import tempfile;
import time;
import from pathlib { Path }
import from unittest.mock { patch }
import from tests.support { jac_command }
import from jaclang.cli.commands.cache { cache }
import from jaclang.cache.registry { BUCKETS, bucket }

glob DAY: float = 86400.0;

def private_env -> tuple[Path, dict[str, str]] {
    base = Path(tempfile.mkdtemp(prefix="jac-cache-cli-"));
    return (base, {"JAC_CACHE_HOME": str(base), "XDG_CACHE_HOME": str(base / "xdg")});
}

def seed_entry(base: Path, rel: str, age_days: float, marker: str = ".used") -> Path {
    d = base / rel;
    d.mkdir(parents=True, exist_ok=True);
    (d / "blob").write_bytes(b"x" * 4096);
    (d / marker).write_bytes(b"");
    t = time.time() - age_days * DAY;
    os.utime(d / marker, (t, t));
    os.utime(d, (t, t));
    return d;
}

"""Run the handler in-process, returning (exit code, captured stdout)."""
def run_cache(env: dict[str, str], **kwargs: any) -> tuple[int, str] {
    out = io.StringIO();
    with patch.dict(os.environ, env) {
        with contextlib.redirect_stdout(out) {
            rc = cache(**kwargs);
        }
    }
    return (rc, out.getvalue());
}

test "jac purge is tombstoned and points at jac cache purge" {
    proc = subprocess.run(
        jac_command("purge"), capture_output=True, text=True, timeout=600
    );
    assert proc.returncode == 2 , f"expected the tombstone exit code, got {proc.returncode}: {proc.stderr}";
    assert "jac cache purge" in proc.stderr , f"the tombstone must name the replacement: {proc.stderr}";
}

test "jac cache status lists every registered bucket through the real CLI" {
    proc = subprocess.run(
        jac_command("cache", "status"), capture_output=True, text=True, timeout=900
    );
    assert proc.returncode == 0 , f"jac cache status failed: {proc.stderr}";
    for b in BUCKETS {
        assert b.name in proc.stdout , f"bucket {b.name} missing from status output:\n{proc.stdout}";
    }
}

test "cache status reports the private root and every bucket" {
    (base, env) = private_env();
    seed_entry(base, "rt/0123456789abcdef", 0.0);
    (rc, out) = run_cache(env, action="status");
    assert rc == 0;
    assert str(base) in out;
    for b in BUCKETS {
        assert b.name in out , f"{b.name} missing from status";
    }
    assert "pg" in out and "external" in out , "external buckets are reported, marked as such";
}

test "cache gc reclaims expired entries and dry-run only reports" {
    (base, env) = private_env();
    expired = seed_entry(base, "rt/0123456789abcdef", 60.0);
    fresh = seed_entry(base, "rt/fedcba9876543210", 1.0);
    (rc, out) = run_cache(env, action="gc", dry_run=True);
    assert rc == 0;
    assert expired.exists() , "a dry run removed something";
    assert "0123456789abcdef" in out , "a dry run must name what it would remove";
    (rc, out) = run_cache(env, action="gc");
    assert rc == 0;
    assert not expired.exists();
    assert fresh.exists();
    assert "reclaimed" in out.lower();
}

test "cache purge clears one bucket or all managed ones and refuses external ones" {
    (base, env) = private_env();
    rt = seed_entry(base, "rt/0123456789abcdef", 0.0);
    apps = seed_entry(base, "apps/" + "a" * 20, 0.0);
    pg = seed_entry(base, "pg/main", 0.0, ".ok");
    (rc, out) = run_cache(env, action="purge", bucket="pg");
    assert rc != 0 , "purging an external bucket must fail";
    assert pg.exists();
    (rc, out) = run_cache(env, action="purge", bucket="no-such-bucket");
    assert rc != 0;
    (rc, out) = run_cache(env, action="purge", bucket="rt");
    assert rc == 0 , out;
    assert not rt.exists() and apps.exists();
    (rc, out) = run_cache(env, action="purge");
    assert rc == 0 , out;
    assert not apps.exists();
    assert pg.exists() , "a full purge never touches pg/";
}

test "an unknown action is refused" {
    (base, env) = private_env();
    (rc, out) = run_cache(env, action="frobnicate");
    assert rc != 0;
}

"""The upgrade window: a launcher built before the rekey runs the new Python
code from a runtime it extracted under the legacy `<hash>-<pathhash>` key,
which carries no `.used` marker and is not what the recomputed payload key
names. The runtime the interpreter actually lives in (the parent of
`sys.prefix`, carrying `.ok`) must survive purge and gc regardless, and so
must the entry the recomputed key names."""
test "purge and gc keep the runtime the interpreter runs from, whatever key it was extracted under" {
    import from jaclang.dist.fused_binary {
        materialized_runtime_dir,
        running_runtime_entries,
        running_runtime_key
    }
    (base, env) = private_env();
    legacy = seed_entry(base, "rt/0123456789abcdef-89abcdef01234567", 400.0, ".ok");
    (legacy / "python").mkdir();
    expired = seed_entry(base, "rt/fedcba9876543210", 400.0);
    recomputed = running_runtime_key();
    rekeyed = seed_entry(base, f"rt/{recomputed}", 400.0) if recomputed else None;
    env["JAC_CACHE_TTL_DAYS"] = "0.001";
    with patch.object(sys, "prefix", str(legacy / "python")) {
        with patch.dict(os.environ, env) {
            assert materialized_runtime_dir() == str(legacy) , "the running runtime is where the interpreter lives, not where the recomputed key points";
            live = running_runtime_entries();
        }
        assert legacy.name in live , f"the legacy-keyed runtime is not protected: {live}";
        if recomputed {
            assert recomputed in live , "the recomputed key must stay protected too";
        }
        (rc, out) = run_cache(env, action="gc");
        assert rc == 0 , out;
        assert legacy.exists() , "gc reclaimed the runtime this interpreter runs from";
        assert not expired.exists() , "gc left an expired sibling behind";
        if rekeyed is not None {
            assert rekeyed.exists() , "gc reclaimed the recomputed-key runtime";
        }
        (rc, out) = run_cache(env, action="purge", bucket="rt", dry_run=True);
        assert rc == 0 , out;
        assert f"would remove rt/{legacy.name}" not in out , f"a dry-run purge lists the running runtime for removal:\n{out}";
        assert f"kept rt/{legacy.name}" in out , f"a dry-run purge must report the running runtime as kept:\n{out}";
        (rc, out) = run_cache(env, action="purge", bucket="rt");
        assert rc == 0 , out;
        assert legacy.exists() , "purge removed the runtime this interpreter runs from";
        if rekeyed is not None {
            assert rekeyed.exists() , "purge removed the recomputed-key runtime";
        }
    }
}

"""An entry whose contents cannot be unlinked (a read-only subdirectory)."""
def stuck_entry(base: Path, rel: str, age_days: float) -> Path {
    d = seed_entry(base, rel, age_days);
    inner = d / "inner";
    inner.mkdir();
    (inner / "file").write_bytes(b"x");
    os.chmod(inner, 0o555);
    # Adding `inner` refreshed the entry's mtime; age it again.
    t = time.time() - age_days * DAY;
    os.utime(d / ".used", (t, t));
    os.utime(d, (t, t));
    return d;
}

def release(stuck: Path) {
    os.chmod(stuck / "inner", 0o755);
}

"""The explicit command answers for what it could not do: a removal that
fails must leave a nonzero exit while everything else is still reclaimed and
reported. (Opportunistic sweeps on write paths stay silent by design.)"""
test "cache gc exits nonzero when a removal fails and still reclaims the rest" {
    if os.name != "posix" or os.geteuid() == 0 {
        return;
    }
    (base, env) = private_env();
    stuck = stuck_entry(base, "rt/0123456789abcdef", 60.0);
    gone = seed_entry(base, "rt/fedcba9876543210", 60.0);
    try {
        (rc, out) = run_cache(env, action="gc");
    } finally {
        release(stuck);
    }
    assert rc != 0 , f"gc reported success with a removal error:\n{out}";
    assert not gone.exists() , "the deletable sibling must still be reclaimed";
    assert stuck.exists();
    assert "fedcba9876543210" in out , "what was removed must still be reported";
}

test "cache purge exits nonzero when a removal fails and still reports what it removed" {
    if os.name != "posix" or os.geteuid() == 0 {
        return;
    }
    (base, env) = private_env();
    stuck = stuck_entry(base, "apps/" + "a" * 20, 0.0);
    gone = seed_entry(base, "apps/" + "b" * 20, 0.0);
    try {
        (rc, out) = run_cache(env, action="purge", bucket="apps");
    } finally {
        release(stuck);
    }
    assert rc != 0 , f"purge reported success with a removal error:\n{out}";
    assert not gone.exists() , "the deletable sibling must still be removed";
    assert stuck.exists();
    assert "b" * 20 in out , "what was removed must still be reported";
}
