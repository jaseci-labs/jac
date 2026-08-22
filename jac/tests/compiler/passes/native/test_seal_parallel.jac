"""The seal's worker pool: same artifacts, same refusals, one process per root.

Sealing thirteen native roots in one process cost both time and memory: the
roots are independent (the single ordering edge is that the materializer root is
generated from unitree's layout), so a sequential seal left every core but one
idle, and each root's materializer crossings strand their native trees in the
process that built them, so a single-process seal accumulated every root's
high-water mark at once. Sealing each root in its own worker process fixes both
halves with one mechanism -- and moves the whole seal across a process boundary,
which is exactly the kind of change that can quietly alter what gets sealed.

So these tests pin that it does not:

1. **The artifacts are the same bytes.** A pooled seal and a sequential seal of
   the same roots agree on every artifact record -- library and layout sha256
   included -- and on the seal index the parent writes. Byte-determinism of the
   emitted artifact is a maintained invariant (`test_seal_incremental.jac` keys
   reuse on it); the pool must not be the thing that breaks it.
2. **The ordering edge still refuses.** The materializer root without unitree's
   layout is refused with the same named mechanism it always was, now raised
   inside a worker and replayed by the parent.
3. **A refusing root fails the whole seal, out loud.** The refusal diagnostics
   are the product of this seal, not incidental logging, so a worker's text must
   reach the operator verbatim and the seal must return None -- the sequential
   failure contract, unchanged by the process boundary.
4. **The job count is decided, not guessed.** `JAC_SEAL_JOBS` is the documented
   override in both directions, and `JAC_SEAL_JOBS=1` is the escape back to the
   original single-process seal.
5. **One job is not one meaning.** Asking for one job is that escape; being
   auto-sized down to one is the opposite request -- it is what a host too small
   to hold two workers looks like, and the single-process seal is the one path
   whose peak is the SUM over every root rather than one root's high-water mark.
   Routing the smallest host to the hungriest strategy is how the macOS release
   legs died: silently, three roots in, with no diagnostic at all. The probe
   underneath is why they were sized that way -- it read `/proc/meminfo` and
   `SC_AVPHYS_PAGES`, neither of which exists on Darwin, so every Mac measured
   as a machine with no memory. Both halves are pinned below, the probe with a
   faked platform, since neither can be reproduced on the Linux host that runs
   this file.

The byte-identity case builds a purpose-built two-root package rather than real
seal roots. A real root costs minutes of LLVM and gigabytes of resident memory
apiece, and this file proves the pool's mechanism, not the compiler's output; an
earlier draft that sealed real roots here took a CI runner down with it, which is
the same failure the pool exists to remove. Everything else below refuses or
exits before a compiler runs.
"""

import contextlib;
import io;
import json;
import os;
import shutil;
import subprocess;
import sys;
import tempfile;
import jaclang;
import from pathlib { Path }
import jaclang.utils.precompile_bytecode as pb;

glob PKG_PATH = Path(jaclang.__file__).parent,
     POOL_ROOTS: tuple = ("pool_alpha.jac", "pool_beta.jac"),
     ABSENT_ROOTS: tuple = (
         "compiler/native_materialize.jac",
         "jac0core/passes/no_such_seal_root.jac"
     ),
     _ALPHA_SRC: str = "\n".join(
         [
             "import from pool_shared { shared_step }",
             "",
             "def alpha_total(n: int) -> int {",
             "    acc = 0;",
             "    i = 0;",
             "    while i < n {",
             "        acc += shared_step(i);",
             "        i += 1;",
             "    }",
             "    return acc;",
             "}"
         ]
     ),
     _BETA_SRC: str = "\n".join(
         [
             "import from pool_shared { shared_step }",
             "",
             "def beta_total(n: int) -> int {",
             "    return shared_step(n) + n;",
             "}"
         ]
     ),
     _SHARED_SRC: str = "\n".join(
         ["def shared_step(x: int) -> int {", "    return x * 3;", "}"]
     );

def _triple -> str {
    import jaclang.compiler.passes.native.llvm.binding as llvm;
    return llvm.get_default_triple();
}

"""Two roots over one shared dependency, in a named temp package.

Purpose-built rather than real seal roots: this file proves the pool's
mechanism, and a real root costs minutes of LLVM and gigabytes of resident
memory apiece. Two roots is the smallest package that puts two workers in flight
at once over a closure they both pull in. The directory is named, not
randomized, because the seal derives each artifact's module name from it.
"""
def _pool_pkg -> Path {
    pkg = Path(tempfile.mkdtemp(prefix="jac_seal_pool_pkg_")) / "poolpkg";
    pkg.mkdir(parents=True);
    (pkg / "pool_alpha.jac").write_text(_ALPHA_SRC, encoding="utf-8");
    (pkg / "pool_beta.jac").write_text(_BETA_SRC, encoding="utf-8");
    (pkg / "pool_shared.jac").write_text(_SHARED_SRC, encoding="utf-8");
    return pkg;
}

"""Seal `modules` out of `pkg` into a fresh tree at `jobs`."""
def _seal_pkg(pkg: Path, modules: tuple, jobs: int) -> tuple {
    out = tempfile.mkdtemp(prefix=f"jac_seal_pool_out{jobs}_");
    buf = io.StringIO();
    with contextlib.redirect_stderr(buf) {
        arts = pb.seal_native_artifacts(pkg, Path(out), modules=modules, jobs=jobs);
    }
    return (arts, out, buf.getvalue(), );
}

"""Seal `modules` out of the real jaclang package at `jobs`."""
def _seal(modules: tuple, jobs: int) -> tuple {
    return _seal_pkg(PKG_PATH, modules, jobs);
}

test "a pooled seal and a sequential seal agree byte for byte" {
    pkg = _pool_pkg();
    (seq, seq_out, _seq_err) = _seal_pkg(pkg, POOL_ROOTS, 1);
    (par, par_out, _par_err) = _seal_pkg(pkg, POOL_ROOTS, 2);
    try {
        assert seq is not None , "the sequential seal refused; nothing to compare";
        assert par is not None , "the pooled seal refused where the sequential one did not";
        assert sorted(seq.keys()) == sorted(par.keys()) , (
            f"the pool sealed a different module set: {sorted(par.keys())} "
            f"vs {sorted(seq.keys())}"
        );
        for name in sorted(seq.keys()) {
            assert seq[name] == par[name] , (
                f"{name} differs between the pooled and sequential seals -- the "
                f"artifact record is not the same: {par[name]} vs {seq[name]}"
            );
        }
        triple = _triple();
        seq_index = pb.read_seal_index(Path(seq_out), triple);
        par_index = pb.read_seal_index(Path(par_out), triple);
        assert seq_index , "the sequential seal wrote no index to compare against";
        assert seq_index == par_index , (
            "the parent's seal index differs after a pooled seal; the workers' "
            "records did not aggregate to the same thing the loop recorded"
        );
    } finally {
        shutil.rmtree(seq_out, ignore_errors=True);
        shutil.rmtree(par_out, ignore_errors=True);
        shutil.rmtree(pkg.parent, ignore_errors=True);
    }
}

test "the pool still refuses the materializer without unitree's layout" {
    (arts, out, err) = _seal(ABSENT_ROOTS, 2);
    try {
        assert arts is None , "the pool sealed a materializer root it cannot generate";
        assert "the materializer root is generated from the unitree layout" in err , (
            f"the ordering refusal did not survive the worker boundary: {err}"
        );
        assert "seal jac0core/unitree.jac first" in err , (
            f"the refusal lost the instruction that makes it actionable: {err}"
        );
    } finally {
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "a refusing root fails the whole pooled seal and replays its worker's text" {
    (arts, out, err) = _seal(ABSENT_ROOTS, 2);
    try {
        assert arts is None , "a refused root did not fail the seal";
        assert "NATIVE SEAL: missing source" in err , (
            f"the missing-source refusal never reached the parent: {err}"
        );
        assert "no_such_seal_root.jac" in err , (
            f"the refusal did not name the root it refused: {err}"
        );
        for rel in ABSENT_ROOTS {
            assert f"the worker sealing {rel} refused it" in err , (
                f"the parent did not attribute {rel}'s refusal to its worker: {err}"
            );
        }
    } finally {
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "JAC_SEAL_JOBS decides the pool size, and 1 means the sequential seal" {
    prior = os.environ.get(pb.NATIVE_SEAL_JOBS_ENV);
    try {
        os.environ[pb.NATIVE_SEAL_JOBS_ENV] = "1";
        assert pb.seal_jobs() == 1 , "JAC_SEAL_JOBS=1 must resolve to one job";
        os.environ[pb.NATIVE_SEAL_JOBS_ENV] = "5";
        assert pb.seal_jobs() == 5 , "JAC_SEAL_JOBS must win over the auto-size";
        os.environ[pb.NATIVE_SEAL_JOBS_ENV] = "not-a-number";
        assert pb.seal_jobs() >= 1 , "an unparsable JAC_SEAL_JOBS must fall back, not raise";
        assert pb.seal_jobs(3) == 3 , "an explicit request must be honoured";
        assert pb.seal_jobs(0) == 1 , "a nonsense request must clamp to one job";
    } finally {
        if prior is None {
            os.environ.pop(pb.NATIVE_SEAL_JOBS_ENV, None);
        } else {
            os.environ[pb.NATIVE_SEAL_JOBS_ENV] = prior;
        }
    }
}

"""The import path the pool hands a worker, as the sealer itself computes it."""
def _worker_paths -> list[str] {
    return json.loads(pb.seal_worker_env("unused")[pb.NATIVE_SEAL_WORKER_PATH_ENV]);
}

"""Run one worker by hand from `cwd`, with `rel` as its root; return the process."""
def _worker_from(cwd: str, out: str, rel: str) -> any {
    request = os.path.join(out, "request.json");
    payload = dict(
        pb.seal_worker_spec(PKG_PATH, Path(out), None, True, pb.compiler_identity())
    );
    payload["rel"] = rel;
    payload["unitree_layout"] = None;
    payload["result"] = os.path.join(out, "result.json");
    Path(request).write_text(json.dumps(payload), encoding="utf-8");
    env = pb.seal_worker_env(request);
    # The payload build hands its worker a PYTHONPATH that already names every
    # path the parent is running on, which is the arrangement that let a boot
    # inserting only "the entries that are missing" insert nothing at all.
    env["PYTHONPATH"] = os.pathsep.join(_worker_paths());
    return subprocess.run(
        pb.seal_worker_argv(),
        env=env,
        cwd=cwd,
        capture_output=True,
        text=True,
        errors="replace"
    );
}

test "a worker's import path leads with the parent's own jaclang" {
    want = _worker_paths();
    assert want , "the sealer handed its worker no import path at all";
    assert want[0] == os.path.dirname(str(PKG_PATH)) , (
        "the worker's import path does not lead with the directory the parent's "
        f"own jaclang lives in: {want[:3]}"
    );
    assert "" not in want , (
        f"the worker's import path carries an implicit cwd entry: {want[:3]}"
    );
}

test "a worker takes that path ahead of its own cwd" {
    decoy = tempfile.mkdtemp(prefix="jac_seal_decoy_");
    try {
        # Only the path prologue, so this costs a bare interpreter start and
        # asserts the contract directly rather than through an import that the
        # host's finders may resolve some other way.
        prologue = pb._SEAL_WORKER_BOOT.split("try:")[0];
        code = prologue + "print(json.dumps(sys.path))";
        want = _worker_paths();
        env = pb.seal_worker_env("unused");
        # The payload build hands its worker a PYTHONPATH that already names
        # every path the parent is running on. That is what let a boot which
        # only inserted "the entries that are missing" insert nothing at all and
        # leave the interpreter's implicit cwd entry in front -- so the worker
        # imported whatever tree it happened to be standing in. Reproduce that
        # arrangement, or the regression cannot arise here.
        env["PYTHONPATH"] = os.pathsep.join(want);
        proc = subprocess.run(
            [sys.executable, "-c", code],
            env=env,
            cwd=decoy,
            capture_output=True,
            text=True,
            errors="replace"
        );
        assert proc.returncode == 0 , f"the worker prologue failed: {proc.stderr}";
        child = json.loads(proc.stdout);
        assert child[:len(want)] == want , (
            "the worker's import path does not begin with what the sealer sent, "
            f"in order: {child[:4]} vs {want[:4]}"
        );
        assert decoy not in child , (
            f"the worker kept its own cwd on the import path: {child[:4]}"
        );
        assert "" not in child , (
            f"the worker kept the interpreter's implicit cwd entry: {child[:4]}"
        );
    } finally {
        shutil.rmtree(decoy, ignore_errors=True);
    }
}

test "a worker reaches the seal from a cwd that has nothing to do with it" {
    decoy = tempfile.mkdtemp(prefix="jac_seal_foreign_");
    out = tempfile.mkdtemp(prefix="jac_seal_foreign_out_");
    try {
        os.makedirs(os.path.join(decoy, "jaclang"), exist_ok=True);
        Path(os.path.join(decoy, "jaclang", "__init__.jac")).write_text(
            "glob DECOY_JACLANG_BESIDE_THE_CWD: int = 1;\n", encoding="utf-8"
        );
        proc = _worker_from(decoy, out, "jac0core/passes/no_such_seal_root.jac");
        err = proc.stderr or "";
        assert "imported jaclang from" not in err , (
            f"the worker resolved a different jaclang tree than its parent: {err}"
        );
        assert "NATIVE SEAL: missing source" in err , (
            "the worker did not reach the seal with the parent's jaclang: "
            f"rc={proc.returncode} {err}"
        );
        landed = json.loads(
            Path(os.path.join(out, "result.json")).read_text(encoding="utf-8")
        );
        assert landed["ok"] is False , "a missing root must not report success";
    } finally {
        shutil.rmtree(decoy, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}

test "the auto-size is bounded by memory and cores, never zero" {
    jobs = pb.seal_jobs(None) if not os.environ.get(pb.NATIVE_SEAL_JOBS_ENV) else 1;
    assert jobs >= 1 , "the auto-size must never return a job count below one";
    assert jobs <= (os.cpu_count() or 1) , (
        "the auto-size must not oversubscribe the machine's cores"
    );
    assert pb.seal_mem_available_gib() >= 0.0 , (
        "the memory probe must answer a number even where it cannot read one"
    );
}

test "a worker that dies on a signal is reported by that signal's name" {
    # A worker writes its result after every failure it can catch, so a missing
    # result means it died in native code. The bare number that used to be
    # printed ("exited -6") said nothing: the reader had to know that -6 is
    # SIGABRT before the line meant anything at all.
    import signal;

    assert pb._seal_exit_reason(-int(signal.SIGABRT)) == "on SIGABRT" , (
        "an aborting worker must be reported as SIGABRT, not as a number"
    );
    assert pb._seal_exit_reason(-int(signal.SIGKILL)) == "on SIGKILL" , (
        "a killed worker -- the out-of-memory signature -- must name SIGKILL"
    );
    assert pb._seal_exit_reason(1) == "with status 1" , (
        "an ordinary nonzero exit is a status, not a signal"
    );
    assert pb._seal_exit_reason(0) == "with status 0" , "zero is still a status";
    assert "9999" in pb._seal_exit_reason(-9999) , (
        "an unrecognizable signal number must still be reported, not raise"
    );
}

"""A `sysconf` that answers the way Darwin's does: no SC_AVPHYS_PAGES at all."""
def _darwin_sysconf(name: str) -> int {
    if name == "SC_PHYS_PAGES" {
        return 4194304;
    }
    if name == "SC_PAGE_SIZE" {
        return 4096;
    }
    raise ValueError(f"unrecognized configuration name: {name}");
}

"""A `Path` whose `read_text` always fails, the way /proc/meminfo does off Linux."""
obj _NoProcPath {
    has target: str;

    def read_text(encoding: str = "utf-8") -> str {
        raise FileNotFoundError(self.target);
    }
}

test "the memory probe answers on a host with no /proc and no SC_AVPHYS_PAGES" {
    import from unittest.mock { patch }

    # Darwin is that host: /proc is not mounted and its unistd.h never defined
    # _SC_AVPHYS_PAGES, so both of the probe's Linux arms raise and it used to
    # answer 0.0 -- reading every Mac as a machine with no memory at all.
    with patch.object(pb, "Path", _NoProcPath) {
        with patch.object(pb.os, "sysconf", _darwin_sysconf) {
            with patch.object(pb.sys, "platform", "darwin") {
                got = pb.seal_mem_available_gib();
            }
        }
    }
    want = 16.0 - pb.NATIVE_SEAL_DARWIN_RESERVE_GIB;
    assert got == want , (
        f"a 16 GiB Darwin host probed as {got} GiB, want {want}: the seal's "
        "auto-size cannot see the memory it is sizing against"
    );
}

test "an auto-sized single job still pools, and only an asked-for 1 is sequential" {
    import from unittest.mock { MagicMock, patch }

    if sys.platform.startswith("win") {
        return;
    }
    prior = os.environ.get(pb.NATIVE_SEAL_JOBS_ENV);
    os.environ.pop(pb.NATIVE_SEAL_JOBS_ENV, None);
    out = Path(tempfile.mkdtemp(prefix="jac-seal-route-"));
    try {
        # A host whose memory the probe cannot read auto-sizes to one job. That
        # must still be a pool of one worker process: the sequential seal is the
        # single path whose peak is the SUM over all thirteen roots rather than
        # one root's high-water mark, so handing it to the smallest host is
        # exactly backwards -- and is how the macOS release legs died.
        with patch.object(pb, "seal_mem_available_gib", return_value=0.0) {
            with patch.object(
                pb, "seal_native_pool", MagicMock(return_value={})
            ) as pool {
                with patch.object(
                    pb, "seal_native_roots", MagicMock(return_value={})
                ) as seq {
                    pb.seal_native_artifacts(PKG_PATH, out);
                    assert pool.call_count == 1 , (
                        "an auto-sized single job took the in-process seal, whose "
                        "peak is the sum over every root"
                    );
                    assert seq.call_count == 0 , (
                        "the in-process sequential seal ran without being asked for"
                    );
                    assert pool.call_args[0][5] == 1 , (
                        f"the pool was sized {pool.call_args[0][5]}, want one worker"
                    );
                }
            }
        }

        # Asking for one is the other request, and still means what it says.
        os.environ[pb.NATIVE_SEAL_JOBS_ENV] = "1";
        with patch.object(
            pb, "seal_native_pool", MagicMock(return_value={})
        ) as pool2 {
            with patch.object(
                pb, "seal_native_roots", MagicMock(return_value={})
            ) as seq2 {
                pb.seal_native_artifacts(PKG_PATH, out);
                assert seq2.call_count == 1 , (
                    "JAC_SEAL_JOBS=1 no longer selects the sequential seal it "
                    "documents"
                );
                assert pool2.call_count == 0 , (
                    "JAC_SEAL_JOBS=1 started a worker pool anyway"
                );
            }
        }
        assert pb.seal_jobs_override() == 1 , (
            "JAC_SEAL_JOBS=1 must read back as an override, not as an auto-size"
        );
        os.environ.pop(pb.NATIVE_SEAL_JOBS_ENV, None);
        assert pb.seal_jobs_override() is None , (
            "an unset JAC_SEAL_JOBS must read back as no override at all"
        );
        os.environ[pb.NATIVE_SEAL_JOBS_ENV] = "not-a-number";
        assert pb.seal_jobs_override() is None , (
            "an unparsable JAC_SEAL_JOBS is not an override; it must auto-size"
        );
    } finally {
        shutil.rmtree(str(out), ignore_errors=True);
        if prior is None {
            os.environ.pop(pb.NATIVE_SEAL_JOBS_ENV, None);
        } else {
            os.environ[pb.NATIVE_SEAL_JOBS_ENV] = prior;
        }
    }
}
