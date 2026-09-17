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
