"""Incremental sealing: an artifact is reused only when its whole input set holds.

Sealing every native root from scratch costs minutes of LLVM per root, and the
overwhelming majority of seals re-link artifacts whose inputs did not move. The
seal now keys each artifact on its inputs and skips the compile when they are
provably unchanged. The danger of any such cache is the stale artifact, so the
rule is the one the module cache already runs on (#8180): the artifact's content
key is its source closure, and the compiler that built it gates whether the
recorded key may be trusted at all. Anything the seal cannot prove is a rebuild.

The tests below pin both halves:

1. the content key covers the whole recorded closure, the root, and the triple,
   so a change to any member moves it;
2. every kind of doubt -- no record, a different triple, a different compiler, a
   changed waiver table, a moved or vanished source, a missing or tampered
   output -- refuses reuse;
3. the demotion waiver table is a *gate*, not a content input: waiving a method
   cannot change the artifact bytes, but it decides whether the build is
   permitted, and that verdict can only be re-reached by recompiling;
4. end to end, an unchanged tree reuses its artifact without relinking, a
   touched closure member rebuilds exactly the roots that close over it, a
   different compiler rebuilds everything, and a planted artifact whose key does
   not match is never served.

The end-to-end tests seal tiny purpose-built packages written into a temp dir
rather than the shared fixtures, because they mutate their sources between runs
and the fixture tree is shared with the rest of this directory across workers.
"""

import contextlib;
import hashlib;
import io;
import json;
import os;
import shutil;
import tempfile;
import from pathlib { Path }
import jaclang.utils.precompile_bytecode as pb;

glob _ROOT_SRC: str = "\n".join(
         [
             "import from incr_dep { dep_scale }",
             "",
             "def root_total(n: int) -> int {",
             "    acc = 0;",
             "    i = 0;",
             "    while i < n {",
             "        acc += dep_scale(i);",
             "        i += 1;",
             "    }",
             "    return acc;",
             "}"
         ]
     ),
     _DEP_SRC: str = "\n".join(
         ["def dep_scale(x: int) -> int {", "    return x * 2;", "}"]
     ),
     _SOLO_SRC: str = "\n".join(
         [
             "def solo_total(n: int) -> int {",
             "    acc = 0;",
             "    i = 0;",
             "    while i < n {",
             "        acc += i;",
             "        i += 1;",
             "    }",
             "    return acc;",
             "}"
         ]
     );


"""A temp package holding the two-module closure plus a standalone root.

The directory is named, not randomized, because the seal derives each
artifact's module name from the package directory name.
"""
def _incr_pkg -> Path {
    pkg = Path(tempfile.mkdtemp(prefix="jac_seal_incr_")) / "incrpkg";
    pkg.mkdir(parents=True);
    (pkg / "incr_root.jac").write_text(_ROOT_SRC, encoding="utf-8");
    (pkg / "incr_dep.jac").write_text(_DEP_SRC, encoding="utf-8");
    (pkg / "incr_solo.jac").write_text(_SOLO_SRC, encoding="utf-8");
    return pkg;
}


"""Seal `modules` out of `pkg` into `out`, returning (artifacts, stderr)."""
def _seal(pkg: Path, out: Path, modules: tuple, canary_reused: bool = True) -> tuple {
    buf = io.StringIO();
    with contextlib.redirect_stderr(buf) {
        arts = pb.seal_native_artifacts(
            pkg, out, modules=modules, canary_reused=canary_reused
        );
    }
    return (arts, buf.getvalue(), );
}


"""(mtime_ns, sha256) of every artifact file named by `arts`."""
def _stamps(out: Path, arts: dict) -> dict[str, tuple] {
    marks: dict[str, tuple] = {};
    for (name, rec) in arts.items() {
        for key in ("lib", "layout") {
            f = out / rec[key];
            marks[f"{name}/{key}"] = (
                f.stat().st_mtime_ns,
                hashlib.sha256(f.read_bytes()).hexdigest(),

            );
        }
    }
    return marks;
}


def _index(out: Path, arts: dict) -> dict {
    triple = list(arts.values())[0]["triple"];
    return pb.read_seal_index(out, triple);
}


"""A record + output tree that `seal_reuse_decision` accepts, for perturbing."""
def _reusable_case(tmp: Path) -> tuple {
    pkg = tmp / "pkg";
    (pkg / "native" / "host").mkdir(parents=True, exist_ok=True);
    src = pkg / "a.jac";
    src.write_text("def a -> int { return 1; }", encoding="utf-8");
    lib = pkg / "native" / "host" / "libjac_a.so";
    layout = pkg / "native" / "host" / "a.layout.json";
    lib.write_bytes(b"artifact-bytes");
    layout.write_text("{}\n", encoding="utf-8");
    keys = pb.seal_source_keys(pkg, [str(src)]);
    record = {
        "key": pb.seal_artifact_key("a.jac", "host", keys),
        "compiler": "compiler-1",
        "waivers": pb.seal_waiver_digest("a.jac", {}),
        "triple": "host",
        "lib": "native/host/libjac_a.so",
        "layout": "native/host/a.layout.json",
        "lib_sha256": hashlib.sha256(lib.read_bytes()).hexdigest(),
        "layout_sha256": hashlib.sha256(layout.read_bytes()).hexdigest(),
        "module": "pkg.a",
        "clib_symbols": [],
        "sources": keys
    };
    return (pkg, src, record, keys, );
}


def _decide(pkg: Path, record: dict, keys: (dict | None)) -> str {
    return pb.seal_reuse_decision(
        record,
        pkg,
        "a.jac",
        "host",
        "compiler-1",
        pb.seal_waiver_digest("a.jac", {}),
        keys
    );
}


test "the content key covers the closure, the root and the triple" {
    base = {"a.jac": "key-a", "b.jac": "key-b"};
    key = pb.seal_artifact_key("a.jac", "host", base);

    assert key == pb.seal_artifact_key("a.jac", "host", dict(base)) , (
        "the input key is not a function of its inputs alone"
    );
    assert key != pb.seal_artifact_key("a.jac", "host", {"a.jac": "key-a"}) , (
        "dropping a closure member left the input key unchanged; a root would "
        "then reuse an artifact built against a closure it no longer has"
    );
    assert key
        != pb.seal_artifact_key(
            "a.jac", "host", {"a.jac": "key-a", "b.jac": "moved"}
        ) , (
        "changing a closure member left the input key unchanged; touching a "
        "dependency would not rebuild the roots that close over it"
    );
    assert key != pb.seal_artifact_key("b.jac", "host", base) , (
        "two roots over the same closure share an input key"
    );
    assert key != pb.seal_artifact_key("a.jac", "other-triple", base) , (
        "the target triple is not in the input key"
    );

    # The map is keyed by label, so a member that moved to a new path is a new
    # key even when its contents are identical.
    assert key
        != pb.seal_artifact_key(
            "a.jac", "host", {"a.jac": "key-a", "sub/b.jac": "key-b"}
        ) , "a closure member that moved did not move the input key";
}


test "the reuse decision refuses on every kind of doubt" {
    tmp = Path(tempfile.mkdtemp(prefix="jac_seal_decide_"));
    try {
        (pkg, src, record, keys) = _reusable_case(tmp);

        assert _decide(pkg, record, keys) == "" , (
            f"the happy path was refused: {_decide(pkg, record, keys)}"
        );
        assert "no artifact" in _decide(pkg, None, keys) , _decide(pkg, None, keys);

        for (field, value, expect) in [
            ("triple", "elsewhere", "not"),
            ("compiler", "compiler-2", "compiler"),
            ("waivers", "other-waivers", "waiver"),
            ("key", "0" * 64, "input key"),
            ("lib_sha256", "0" * 64, "sha256"),
            ("layout_sha256", "0" * 64, "sha256"),
            ("lib", "native/host/gone.so", "missing"),
            ("sources", {}, "closure")
        ] {
            perturbed = dict(record);
            perturbed[field] = value;
            why = _decide(pkg, perturbed, keys);
            assert why , f"a record with a wrong {field} was accepted for reuse";
            assert expect in why , f"unhelpful refusal for {field}: {why}";
        }

        assert "gone or unreadable" in _decide(pkg, record, None) , (
            "a vanished closure source did not refuse reuse"
        );

        # A real edit to a real closure member, measured the way the seal does.
        src.write_text("def a -> int { return 2; }", encoding="utf-8");
        moved = pb.seal_source_keys(pkg, [str(src)]);
        why = _decide(pkg, record, moved);
        assert "closure source(s) changed" in why , why;
        assert "a.jac" in why , f"the refusal does not name what changed: {why}";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "the waiver table gates the build, it is not part of the content key" {
    tmp = Path(tempfile.mkdtemp(prefix="jac_seal_waiver_key_"));
    try {
        (pkg, _src, record, keys) = _reusable_case(tmp);

        # A waiver decides whether a demotion is *permitted*, never what the
        # backend emits, so it is deliberately absent from the content key: the
        # key is the source closure and nothing else.
        wide = pb.seal_artifact_key("a.jac", "host", keys);
        assert record["key"] == wide , (
            "the content key moved without a source change"
        );

        # But it must still force a rebuild, because the only way to re-reach
        # the demotion verdict is to recompile under the coverage. Reuse would
        # skip the gate and let a build through that the new table forbids.
        assert pb.seal_waiver_digest("a.jac", {})
            != pb.seal_waiver_digest("a.jac", {"a.jac": ("a.jac::A.method", )}) , "the waiver digest does not distinguish two different waiver tables";
        why = pb.seal_reuse_decision(
            record,
            pkg,
            "a.jac",
            "host",
            "compiler-1",
            pb.seal_waiver_digest("a.jac", {"a.jac": ("a.jac::A.method", )}),
            keys
        );
        assert "waiver" in why , (
            f"a changed waiver table did not force the seal gate to re-run: {why}"
        );

        # Reordering the same names is the same table.
        assert pb.seal_waiver_digest("a.jac", {"a.jac": ("x::A.m", "x::B.m")})
            == pb.seal_waiver_digest("a.jac", {"a.jac": ("x::B.m", "x::A.m")}) , (
            "the waiver digest depends on the order of the waiver tuple"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "an unchanged tree reuses its artifact instead of relinking it" {
    pkg = _incr_pkg();
    out = Path(tempfile.mkdtemp(prefix="jac_seal_incr_out_"));
    try {
        (first, err1) = _seal(pkg, out, ("incr_root.jac", ));
        assert first is not None , f"the first seal failed:\n{err1}";
        before = _stamps(out, first);

        (second, err2) = _seal(pkg, out, ("incr_root.jac", ));
        assert second is not None , f"the second seal failed:\n{err2}";
        assert second == first , (
            "a reused artifact must produce the same manifest record as the "
            f"build it replaced:\n{first}\n{second}"
        );
        assert _stamps(out, second) == before , (
            "the seal relinked an artifact whose whole input set was unchanged"
        );
        assert "canary" in err2.lower() , (
            f"the seal served a reused artifact without a canary:\n{err2}"
        );
        assert _index(out, second) == _index(out, first) , (
            "reuse rewrote the seal index"
        );
    } finally {
        shutil.rmtree(pkg.parent, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}


test "a planted artifact whose key does not match is never reused" {
    pkg = _incr_pkg();
    out = Path(tempfile.mkdtemp(prefix="jac_seal_plant_out_"));
    try {
        (first, err1) = _seal(pkg, out, ("incr_root.jac", ));
        assert first is not None , f"the first seal failed:\n{err1}";
        rec = first["incrpkg.incr_root"];
        lib = out / rec["lib"];
        good_sha = rec["lib_sha256"];

        # Plant a stale artifact the way a botched cache restore would: the
        # bytes on disk are junk, and the index is doctored to *agree* with
        # them, so the sha check alone cannot catch it. Only the input key,
        # which the plant leaves stale, stands between the seal and shipping
        # this file.
        triple = rec["triple"];
        index = pb.read_seal_index(out, triple);
        planted = b"stale artifact from another build";
        # A fresh inode, not an in-place overwrite: the canary that just ran
        # has this artifact mapped, and truncating a mapped ELF would take the
        # next dlopen in this process down inside glibc rather than testing
        # anything about the seal.
        lib.unlink();
        lib.write_bytes(planted);
        index["incr_root.jac"]["lib_sha256"] = hashlib.sha256(planted).hexdigest();
        index["incr_root.jac"]["key"] = "0" * 64;
        pb.write_seal_index(out, triple, index);

        (second, err2) = _seal(pkg, out, ("incr_root.jac", ));
        assert second is not None , f"the re-seal failed:\n{err2}";
        assert lib.read_bytes() != planted , (
            "the seal served a planted artifact whose recorded input key did "
            "not match its sources; a stale binary would have shipped"
        );
        assert second["incrpkg.incr_root"]["lib_sha256"]
            == hashlib.sha256(lib.read_bytes()).hexdigest() , "the manifest record does not describe the file on disk";
        assert pb.seal_native_canary(str(lib), []) == "" , (
            "the rebuilt artifact does not load"
        );
        assert good_sha == hashlib.sha256(lib.read_bytes()).hexdigest() , (
            "the rebuild of an unchanged closure did not reproduce the "
            "artifact byte for byte"
        );

        # And the sha gate holds on its own: an untouched key with tampered
        # bytes is equally not reusable.
        truncated = lib.read_bytes()[:256];
        lib.unlink();
        lib.write_bytes(truncated);
        (third, err3) = _seal(pkg, out, ("incr_root.jac", ));
        assert third is not None , f"the third seal failed:\n{err3}";
        assert lib.stat().st_size > 256 , (
            "the seal served an artifact whose bytes no longer match its "
            "recorded sha256"
        );
        assert third["incrpkg.incr_root"]["lib_sha256"]
            == hashlib.sha256(lib.read_bytes()).hexdigest() , "the manifest record does not describe the file on disk";
    } finally {
        shutil.rmtree(pkg.parent, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}


test "touching a closure member rebuilds exactly the roots that close over it" {
    pkg = _incr_pkg();
    out = Path(tempfile.mkdtemp(prefix="jac_seal_gran_out_"));
    roots = ("incr_root.jac", "incr_solo.jac", );
    try {
        (first, err1) = _seal(pkg, out, roots);
        assert first is not None , f"the first seal failed:\n{err1}";
        assert sorted(first) == ["incrpkg.incr_root", "incrpkg.incr_solo"] , sorted(
            first
        );
        before = _stamps(out, first);

        index = pb.read_seal_index(out, first["incrpkg.incr_root"]["triple"]);
        assert "incr_dep.jac" in index["incr_root.jac"]["sources"] , (
            "the root's recorded closure does not name the dependency it "
            f"imports: {sorted(index['incr_root.jac']['sources'])}"
        );
        assert "incr_dep.jac" not in index["incr_solo.jac"]["sources"] , (
            "the standalone root recorded a closure member it does not import"
        );

        # Touch the shared dependency, not either root.
        (pkg / "incr_dep.jac").write_text(
            _DEP_SRC.replace("x * 2", "x * 3"), encoding="utf-8"
        );
        (second, err2) = _seal(pkg, out, roots);
        assert second is not None , f"the second seal failed:\n{err2}";
        after = _stamps(out, second);

        assert after["incrpkg.incr_root/lib"] != before["incrpkg.incr_root/lib"] , (
            "a root whose closure member changed was reused; it would ship "
            "code built against the old dependency"
        );
        assert after["incrpkg.incr_solo/lib"] == before["incrpkg.incr_solo/lib"] , (
            "a root that does not close over the touched file was rebuilt; "
            "the rebuild is not scoped to the closure"
        );

        # Touching the root's own source rebuilds only that root.
        mid = _stamps(out, second);
        (pkg / "incr_solo.jac").write_text(
            _SOLO_SRC.replace("acc += i", "acc += i + 1"), encoding="utf-8"
        );
        (third, err3) = _seal(pkg, out, roots);
        assert third is not None , f"the third seal failed:\n{err3}";
        last = _stamps(out, third);
        assert last["incrpkg.incr_solo/lib"] != mid["incrpkg.incr_solo/lib"] , (
            "a root whose own source changed was reused"
        );
        assert last["incrpkg.incr_root/lib"] == mid["incrpkg.incr_root/lib"] , (
            "an untouched root was rebuilt when a sibling root changed"
        );
    } finally {
        shutil.rmtree(pkg.parent, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}


test "a different compiler rebuilds every artifact" {
    pkg = _incr_pkg();
    out = Path(tempfile.mkdtemp(prefix="jac_seal_compiler_out_"));
    roots = ("incr_root.jac", "incr_solo.jac", );
    real_identity = pb.compiler_identity;
    try {
        (first, err1) = _seal(pkg, out, roots);
        assert first is not None , f"the first seal failed:\n{err1}";
        before = _stamps(out, first);

        # Compiler identity is the validity gate: the sources did not move, so
        # every content key is unchanged, and reuse must still be refused.
        def _other_compiler -> str {
            return f"{real_identity()}-not";
        }
        pb.compiler_identity = _other_compiler;
        try {
            (second, err2) = _seal(pkg, out, roots);
        } finally {
            pb.compiler_identity = real_identity;
        }
        assert second is not None , f"the second seal failed:\n{err2}";
        after = _stamps(out, second);
        for name in ["incrpkg.incr_root", "incrpkg.incr_solo"] {
            assert after[f"{name}/lib"] != before[f"{name}/lib"] , (
                f"{name} was reused across a compiler change; an artifact this "
                "compiler did not build would have shipped as its own"
            );
        }

        index = pb.read_seal_index(out, second["incrpkg.incr_root"]["triple"]);
        assert index["incr_root.jac"]["compiler"] == _other_compiler() , (
            "the seal index does not record the compiler that built the artifact"
        );
    } finally {
        pb.compiler_identity = real_identity;
        shutil.rmtree(pkg.parent, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}


test "the reused-canary flag skips the canary only on reuse" {
    pkg = _incr_pkg();
    out = Path(tempfile.mkdtemp(prefix="jac_seal_canary_flag_"));
    try {
        (first, err1) = _seal(pkg, out, ("incr_root.jac", ), canary_reused=False);
        assert first is not None , f"the first seal failed:\n{err1}";
        assert "canary" in err1.lower() , (
            f"the flag suppressed the canary on a real build:\n{err1}"
        );

        (second, err2) = _seal(pkg, out, ("incr_root.jac", ), canary_reused=False);
        assert second == first , "the reuse path changed the manifest record";
        assert "canary" not in err2.lower() , (
            f"--seal-skip-reused-canary still ran the canary on reuse:\n{err2}"
        );

        (third, err3) = _seal(pkg, out, ("incr_root.jac", ));
        assert third == first , "the reuse path changed the manifest record";
        assert "canary" in err3.lower() , (
            f"the default reuse path skipped the canary:\n{err3}"
        );
    } finally {
        shutil.rmtree(pkg.parent, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}


test "the precompile sweep drops stale python trees and spares the native cache" {
    # The `--seal` path precompiles and finalizes in one run, and the compile
    # half sweeps every directory beside the current python tag out of
    # _precompiled. That sweep used to take `native/` with it, which would
    # delete the seal index and its artifacts before the native seal ever got
    # to consult them, so reuse could never fire in the build that needs it.
    tmp = Path(tempfile.mkdtemp(prefix="jac_seal_sweep_"));
    try {
        pre = tmp / "_precompiled";
        for name in ["cpython-314", "cpython-313", "bootstrap", "native"] {
            (pre / name).mkdir(parents=True);
            (pre / name / "marker").write_text(name, encoding="utf-8");
        }
        (pre / "MANIFEST.json").write_text("{}", encoding="utf-8");

        removed = pb.prune_stale_precompiled_dirs(pre, "cpython-314");

        assert (pre / "native" / "marker").is_file() , (
            "the sweep deleted the native artifact cache; the seal that runs "
            "right after it would have nothing left to reuse"
        );
        assert (pre / "cpython-314" / "marker").is_file() , (
            "the sweep deleted the tree it is building into"
        );
        assert not (pre / "cpython-313").exists() , (
            "a stale python tree survived the sweep"
        );
        assert not (pre / "bootstrap").exists() , (
            "the frozen bootstrap tree is rebuilt by every seal and must not "
            "survive the sweep"
        );
        assert (pre / "MANIFEST.json").is_file() , "the sweep removed a file";
        assert removed == 2 , removed;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "the seal prunes artifacts no longer covered by the index" {
    pkg = _incr_pkg();
    out = Path(tempfile.mkdtemp(prefix="jac_seal_prune_out_"));
    try {
        (first, err1) = _seal(pkg, out, ("incr_root.jac", "incr_solo.jac", ));
        assert first is not None , f"the first seal failed:\n{err1}";
        solo_lib = out / first["incrpkg.incr_solo"]["lib"];
        assert solo_lib.is_file();

        (second, err2) = _seal(pkg, out, ("incr_root.jac", ));
        assert second is not None , f"the second seal failed:\n{err2}";
        assert sorted(second) == ["incrpkg.incr_root"] , sorted(second);
        assert not solo_lib.exists() , (
            "an artifact this seal did not produce was left in the output "
            "tree; the seal used to wipe the native dir before every build and "
            "must not start leaking artifacts now that it does not"
        );
        index = pb.read_seal_index(out, second["incrpkg.incr_root"]["triple"]);
        assert sorted(index) == ["incr_root.jac"] , sorted(index);
        assert (out / second["incrpkg.incr_root"]["lib"]).is_file() , (
            "the pruner removed the artifact this seal just served"
        );
    } finally {
        shutil.rmtree(pkg.parent, ignore_errors=True);
        shutil.rmtree(out, ignore_errors=True);
    }
}
