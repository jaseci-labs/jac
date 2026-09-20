"""The fused launcher's runtime cache is content-addressed and reclaimed.

A fused `jac` extracts its embedded runtime into `<cache>/rt/<key>/` before
CPython exists. The key used to fold in the executable's path, so every
location a binary ran from (zig-out, ~/.local/bin, each temp dir a test built
one in) extracted its own 500 MB copy of the same payload, and nothing but
same-path siblings was ever pruned. The key is now the payload hash alone;
each boot touches a last-use marker; runtimes unused past the TTL, and
extractions that crashed more than an hour ago, are reclaimed on a daily
sweep that never removes the running payload and never kills the process.

The launcher cannot import the Python-side authority (it runs first), so it
carries its own copy of the root rule. These tests run the real binary this
suite is executing under against private roots and check, through the
Python-side rule, that both resolvers agree on where the cache is and which
environment variable wins. A bare source install has no fused runtime; the
tests skip there.
"""

import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import time;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.cache.home { CACHEDIR_TAG, CACHEDIR_TAG_TEXT, cache_home }
import from jaclang.dist.fused.trailer { rt_key }
import from jaclang.dist.fused_binary { runtime_trailer }

glob DAY: float = 86400.0,
     _STATE: dict[str, any] = {};

"""The fused binary running this suite, or None under a bare source install."""
def fused_exe -> str | None {
    exe = os.environ.get("JAC_EXECUTABLE", "") or os.path.realpath(sys.executable);
    if not os.path.isfile(exe) {
        return None;
    }
    return exe if runtime_trailer(exe) is not None else None;
}

"""Place the binary at a fresh path without copying 150 MB when a link works."""
def place_binary(exe: str, dest: Path) -> str {
    try {
        os.link(exe, dest);
    } except OSError {
        shutil.copy2(exe, dest);
    }
    return str(dest);
}

def launcher_env(explicit: Path, xdg: Path) -> dict[str, str] {
    env: dict[str, str] = dict(os.environ);
    env["JAC_CACHE_HOME"] = str(explicit);
    env["XDG_CACHE_HOME"] = str(xdg);
    # The bundled compiler, not the checkout's: the probe must not compile.
    env["JAC_NO_DEV_SOURCE"] = "1";
    env.pop("JAC_DEV_SOURCE", None);
    env.pop("JAC_EXECUTABLE", None);
    env.pop("JAC_CACHE_TTL_DAYS", None);
    return env;
}

def run_launcher(exe: str, env: dict[str, str], cwd: str) -> any {
    return subprocess.run(
        [exe, "--version"],
        env=env,
        cwd=cwd,
        capture_output=True,
        text=True,
        timeout=900
    );
}

def backdate(path: Path, seconds_ago: float) {
    t = time.time() - seconds_ago;
    os.utime(path, (t, t));
}

"""One extraction for the whole file: the binary at two paths, one private root."""
def prepared -> dict[str, any] {
    if _STATE {
        return _STATE;
    }
    exe = fused_exe();
    if exe is None {
        testskip("not running under a fused jac binary (no runtime trailer)");
    }
    tmp = Path(tempfile.mkdtemp(prefix="jac-fused-cache-"));
    explicit = tmp / "explicit";
    xdg = tmp / "xdg";
    bins = tmp / "bin";
    bins.mkdir();
    one = place_binary(exe, bins / "jac-one");
    two = place_binary(exe, bins / "jac-two");
    env = launcher_env(explicit, xdg);
    first = run_launcher(one, env, str(tmp));
    assert first.returncode == 0 , f"launcher failed from {one}:\n{first.stdout}\n{first.stderr}";
    trailer = runtime_trailer(exe);
    assert trailer is not None;
    _STATE.update(
        {
            "tmp": tmp,
            "explicit": explicit,
            "xdg": xdg,
            "one": one,
            "two": two,
            "env": env,
            "key": rt_key(trailer.hash16()),
            "first": first
        }
    );
    return _STATE;
}

test "the launcher and the Python authority agree on the root and on JAC_CACHE_HOME precedence" {
    st = prepared();
    with patch.dict(
        os.environ,
        {"JAC_CACHE_HOME": str(st["explicit"]), "XDG_CACHE_HOME": str(st["xdg"])}
    ) {
        base = cache_home();
    }
    assert base == st["explicit"] , "the Python rule must prefer JAC_CACHE_HOME";
    rt = base / "rt" / st["key"];
    assert (rt / ".ok").is_file() , (
        f"the launcher extracted somewhere other than the authority's root:\n"
        f"expected {rt}\nstderr:\n{st['first'].stderr}"
    );
    assert not (st["xdg"] / "jac" / "rt").exists() , "XDG_CACHE_HOME must lose to JAC_CACHE_HOME in the launcher too";
    assert not (base / CACHEDIR_TAG).exists();
    assert (base / "rt" / CACHEDIR_TAG).is_file() , "the launcher must tag only the disposable runtime bucket";
}

test "one payload materializes once, whatever path the binary runs from" {
    st = prepared();
    key = st["key"];
    assert len(key) == 16 and "-" not in key , f"the runtime key must be the payload hash alone, got {key!r}";
    second = run_launcher(st["two"], st["env"], str(st["tmp"]));
    assert second.returncode == 0 , second.stderr;
    assert "one-time setup" not in second.stderr , "the second path re-extracted the same payload";
    rt = st["explicit"] / "rt";
    runtimes = sorted(
        [
            p.name
            for p in rt.iterdir()
            if p.is_dir()
        ]
    );
    assert runtimes == [key] , f"expected exactly one runtime directory, found {runtimes}";
    assert (rt / key / ".used").is_file() , "each boot must touch the last-use marker";
}

"""A fake runtime directory whose last use was `age` seconds ago."""
def seed(rt: Path, name: str, age: float, marker: str = ".used") -> Path {
    d = rt / name;
    d.mkdir(parents=True, exist_ok=True);
    (d / "blob").write_bytes(b"x" * 1024);
    (d / marker).write_bytes(b"");
    backdate(d / marker, age);
    backdate(d, age);
    return d;
}

test "the launcher reclaims runtimes unused past the TTL and stale temp extractions, never the running one" {
    st = prepared();
    rt = st["explicit"] / "rt";
    live = rt / st["key"];
    expired = seed(rt, "0123456789abcdef", 60.0 * DAY);
    legacy = seed(rt, "0123456789abcdef-89abcdef01234567", 60.0 * DAY, ".ok");
    fresh = seed(rt, "fedcba9876543210", 1.0 * DAY);
    old_tmp = seed(rt, "0123456789abcdef.tmp.4242", 2.0 * 3600.0, ".ok");
    new_tmp = seed(rt, "fedcba9876543210.tmp.4243", 60.0, ".ok");
    backdate(live / ".used", 60.0 * DAY);
    sentinel = rt / ".last-sweep";
    if sentinel.exists() {
        sentinel.unlink();
    }
    run = run_launcher(st["one"], st["env"], str(st["tmp"]));
    assert run.returncode == 0 , run.stderr;
    assert not expired.exists() , "a runtime unused past the TTL survived the sweep";
    assert not legacy.exists() , "a pre-rekey lineage must be reclaimed like any other stale runtime";
    assert not old_tmp.exists() , "a crashed extraction older than an hour survived";
    assert fresh.exists() , "a recently used runtime was reclaimed";
    assert new_tmp.exists() , "an extraction in progress was reclaimed";
    assert (live / ".ok").is_file() , "the running payload must never be reclaimed";
    assert sentinel.is_file() , "the sweep must leave its throttle sentinel";
}

"""A marker the launcher cannot refresh (a read-only cache, a chmod-ed file)
costs an earlier reclaim, never the boot: the bootstrap has no file write
that can raise before CPython exists."""
test "boot survives a last-use marker it cannot refresh" {
    if os.name != "posix" or os.geteuid() == 0 {
        return;
    }
    st = prepared();
    marker = st["explicit"] / "rt" / st["key"] / ".used";
    assert marker.is_file();
    backdate(marker, 3.0 * DAY);
    stamp = marker.stat().st_mtime;
    os.chmod(marker, 0o444);
    try {
        run = run_launcher(st["one"], st["env"], str(st["tmp"]));
    } finally {
        os.chmod(marker, 0o644);
    }
    assert run.returncode == 0 , f"a read-only marker aborted the boot (exit {run.returncode}):\n{run.stderr}";
    assert "Uncaught" not in run.stderr , run.stderr;
    assert marker.stat().st_mtime == stamp , "the marker cannot have been refreshed; the boot must simply carry on";
}

"""The temp-dir fallback the resolver was designed around: a cache root the
user cannot write must not abort the boot, it must send the runtime to
`$TMPDIR/jac-cache-<uid>` (a probe write that raises instead of answering
False defeated it on main)."""
test "an unwritable cache root falls back to the temp dir" {
    if os.name != "posix" or os.geteuid() == 0 {
        return;
    }
    st = prepared();
    tmp = Path(tempfile.mkdtemp(prefix="jac-fused-ro-"));
    xdg = tmp / "xdg";
    (xdg / "jac").mkdir(parents=True);
    os.chmod(xdg / "jac", 0o555);
    tmpdir = tmp / "tmpdir";
    tmpdir.mkdir();
    env = launcher_env(tmp / "unused", xdg);
    env["JAC_CACHE_HOME"] = "";
    env["TMPDIR"] = str(tmpdir);
    try {
        run = run_launcher(st["one"], env, str(tmp));
    } finally {
        os.chmod(xdg / "jac", 0o755);
    }
    assert run.returncode == 0 , f"an unwritable root aborted the boot (exit {run.returncode}):\n{run.stderr}";
    fallback = tmpdir / f"jac-cache-{os.getuid()}" / "rt" / st["key"];
    assert (fallback / ".ok").is_file() , f"the runtime did not land in the temp-dir fallback:\n{run.stderr}";
    assert not (xdg / "jac" / "rt").exists() , "nothing may be written under the unwritable root";
}


test "launcher upgrades the backup boundary without touching persistent data" {
    st = prepared();
    base = Path(st["explicit"]);
    pg = base / "pg" / "main";
    pg.mkdir(parents=True, exist_ok=True);
    (pg / "important").write_bytes(b"database");
    (base / CACHEDIR_TAG).write_text(CACHEDIR_TAG_TEXT);
    proc = run_launcher(st["one"], st["env"], str(st["tmp"]));
    assert proc.returncode == 0 , proc.stderr;
    assert not (base / CACHEDIR_TAG).exists();
    assert (base / "rt" / CACHEDIR_TAG).is_file();
    assert not (base / "pg" / CACHEDIR_TAG).exists();
    assert (pg / "important").read_bytes() == b"database";
}
