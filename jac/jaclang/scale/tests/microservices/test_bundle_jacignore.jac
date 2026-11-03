import io;
import os;
import tarfile;
import tempfile;
import unittest.mock;
import from pathlib { Path }


glob _JAC_BIN: Path = pod_binary(),
     _PARKED: str = "# parked for the deploy\ndocsite/\nevaluation/\n";


def _app(jacignore: (str | None)) -> Path {
    # The issue-8044 shape: two standalone trees a project parks with
    # .jacignore. docsite/ is a nested project that no longer compiles
    # (pre-0.35 `cl {}` markers); evaluation/ is loose source the seal would
    # compile, so shipping it crash-loops the fleet.
    d = Path(tempfile.mkdtemp(prefix="jac-jacignore-"));
    (d / "jac.toml").write_text("[project]\nname = \"mini\"\n");
    (d / "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    (d / "docsite").mkdir();
    (d / "docsite" / "jac.toml").write_text("[project]\nname = \"docs\"\n");
    (d / "docsite" / "main.jac").write_text(
        "cl {\n    def page -> str { return \"x\"; }\n}\n"
    );
    (d / "evaluation").mkdir();
    (d / "evaluation" / "broken.jac").write_text("this is not valid jac\n");
    if jacignore is not None {
        (d / ".jacignore").write_text(jacignore);
    }
    return d;
}


def _rels(base: Path) -> list[str] {
    return sorted([p.relative_to(base).as_posix() for p in bundle_source_files(base)]);
}


def _source_digest(base: Path) -> str {
    # The re-ship decision is the content address of the .jab, and every
    # source member in it comes from add_source_members.
    buf = io.BytesIO();
    (tar, gz) = open_det_tar(buf);
    try {
        with tar {
            add_source_members(tar, base);
        }
    } finally {
        gz.close();
    }
    return content_address(buf.getvalue());
}


test "the seal stage drops the trees .jacignore parks" {
    base = _app(_PARKED);
    stage = _stage_app(base, sanitized_jac_toml(base)) / "app";
    staged = sorted([p.relative_to(stage).as_posix() for p in stage.rglob("*")]);
    assert "svc.jac" in staged , staged;
    assert not (stage / "docsite").exists() , staged;
    assert not (stage / "evaluation").exists() , staged;
}


test "a nested jac.toml inside a parked tree never reaches the bundle" {
    nested = nested_sanitized_tomls(_app(_PARKED));
    assert nested == {} , nested;
    # Without the parking, the same nested project still ships.
    assert list(nested_sanitized_tomls(_app(None)).keys()) == ["docsite/jac.toml"];
}


test "the bundle source set honors .jacignore and ships the file itself" {
    rels = _rels(_app(_PARKED));
    assert "svc.jac" in rels , rels;
    assert ".jacignore" in rels , rels;
    assert not any([r.startswith("docsite/") for r in rels]) , rels;
    assert not any([r.startswith("evaluation/") for r in rels]) , rels;
    unparked = _rels(_app(None));
    assert "docsite/main.jac" in unparked , unparked;
    assert "evaluation/broken.jac" in unparked , unparked;
}


test "editing .jacignore alone moves the content-addressed bundle digest" {
    parked = _source_digest(_app(_PARKED));
    assert parked == _source_digest(_app(_PARKED));
    assert parked != _source_digest(_app(None));
    assert parked != _source_digest(_app("docsite/\n"));
    # Same exclusions, different bytes: .jacignore ships verbatim, so the
    # digest still moves and the deploy re-ships instead of hitting the
    # content-addressed skip.
    assert parked != _source_digest(_app("docsite/\nevaluation/\n"));
}


test "parking the entry module fails the pack, not the fleet" {
    # The one failure mode honoring .jacignore introduces: a project that
    # parks its own entry point would ship a bundle with nothing to boot.
    base = _app("main.jac\n");
    (base / "main.jac").write_text("with entry { print(\"hi\"); }\n");
    caught = "";
    try {
        pack_jab(str(base), b"binary");
    } except ValueError as e {
        caught = str(e);
    }
    assert "entry module" in caught , caught;
    assert ".jacignore" in caught , caught;
    # An entry module the bundle ships is not flagged.
    ok = _app(_PARKED);
    (ok / "main.jac").write_text("with entry { print(\"hi\"); }\n");
    assert "main.jac" in _rels(ok);
}


test "a sealed .jab carries no tree that .jacignore parks" {
    # Unfixed, this seal dies on evaluation/broken.jac, which is the crash the
    # in-pod boot compile hits.
    require_pod_binary();
    base = _app(_PARKED);
    (base / "main.jac").write_text("with entry { print(\"hi\"); }\n");
    raw = pack_jab(str(base), _JAC_BIN.read_bytes());
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
    }
    assert "svc.jac" in names , names;
    assert ".jacignore" in names , names;
    assert not any([n.startswith("docsite/") for n in names]) , names;
    assert not any([n.startswith("evaluation/") for n in names]) , names;
}


def _tree_with_build_dirs -> Path {
    d = Path(tempfile.mkdtemp(prefix="jac-prunelog-"));
    (d / "jac.toml").write_text("[project]\nname = \"mini\"\n");
    (d / "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    (d / "dist").mkdir();
    (d / "dist" / "handler.jac").write_text("def:pub go -> str { return \"x\"; }\n");
    (d / "svc").mkdir();
    (d / "svc" / "build").mkdir();
    (d / "svc" / "build" / "gen.jac").write_text("def gen -> str { return \"y\"; }\n");
    (d / "node_modules").mkdir();
    (d / "node_modules" / "pkg.js").write_text("//\n");
    return d;
}


test "a source directory the build-output heuristic eats is named at deploy time" {
    base = _tree_with_build_dirs();

    (kept, pruned) = partition_bundle_sources(base);

    rels = sorted([p.relative_to(base).as_posix() for p in kept]);
    assert "dist/handler.jac" not in rels , rels;
    assert "svc/build/gen.jac" not in rels , rels;
    assert "svc.jac" in rels , rels;
    assert pruned == ["dist", "node_modules", "svc/build"] , (
        f"every directory the heuristic drops has to be reportable, nested ones "
        f"at their full path: {pruned}"
    );
}


test "a directory the bundle requires is never reported as pruned" {
    # .jac and dist are both in the exclude set, but .jac/client/dist is force
    # included, so reporting it would tell an operator their client build was
    # dropped when it shipped.
    base = _tree_with_build_dirs();
    ((base / ".jac") / "client" / "dist").mkdir(parents=True);
    ((base / ".jac") / "client" / "dist" / "app.js").write_text("//\n");

    (kept, pruned) = partition_bundle_sources(base);

    rels = [p.relative_to(base).as_posix() for p in kept];
    assert ".jac/client/dist/app.js" in rels , rels;
    assert ".jac" not in pruned , pruned;
    assert ".jac/client/dist" not in pruned , pruned;
}


test "a tree with no build-output directories reports nothing" {
    d = Path(tempfile.mkdtemp(prefix="jac-prunelog-clean-"));
    (d / "jac.toml").write_text("[project]\nname = \"clean\"\n");
    (d / "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");

    (kept, pruned) = partition_bundle_sources(d);

    assert pruned == [] , pruned;
    assert sorted([p.relative_to(d).as_posix() for p in kept]) == ["svc.jac"];
}


test "the reported set does not change which files ship" {
    base = _tree_with_build_dirs();

    (kept, _pruned) = partition_bundle_sources(base);

    assert sorted([p.relative_to(base).as_posix() for p in kept])
        == sorted(
            [p.relative_to(base).as_posix() for p in bundle_source_files(base)]
        ) , "reporting is observation only";
}


def _write_files(base: Path, rels: list[str]) {
    for rel in rels {
        path = base / rel;
        path.parent.mkdir(parents=True, exist_ok=True);
        path.write_text("x\n");
    }
}


test "the bundle walk never lists a build tree it cannot ship from" {
    # Listing node_modules or .jac/venv only to drop every path in it kept the
    # client-bundle thread busy long enough to starve a deploy's GitHub requests.
    base = Path(tempfile.mkdtemp(prefix="jac-prunewalk-"));
    skipped = [
        "node_modules",
        ".jac/venv",
        ".jac/client/node_modules",
        "apps/web/node_modules"
    ];
    _write_files(
        base,
        [
            "main.jac",
            "apps/web/main.jac",
            ".jac/client/dist/index.js",
            ".jac/admin/index.html"
        ]
    );
    for tree in skipped {
        _write_files(base, [f"{tree}/pkg{i}/lib/mod{i}.js" for i in range(40)]);
    }
    real_scandir = os.scandir;
    listed: list[str] = [];
    def recording(path: any = ".") -> any {
        listed.append(os.path.relpath(os.fspath(path), str(base)).replace(os.sep, "/"));
        return real_scandir(path);
    }
    with unittest.mock.patch.object(os, "scandir", recording) {
        (kept, _pruned) = partition_bundle_sources(base);
    }
    rels = [p.relative_to(base).as_posix() for p in kept];
    assert rels
        == [
            ".jac/admin/index.html",
            ".jac/client/dist/index.js",
            "apps/web/main.jac",
            "main.jac"
        ] , rels;
    entered = sorted(
        {
            d for d in listed
            for tree in skipped
            if d == tree or d.startswith(tree + "/")
        }
    );
    assert entered == [] , f"the walk listed build trees it cannot ship from: {entered}";
}


def _mixed_tree -> Path {
    base = Path(tempfile.mkdtemp(prefix="jac-prunewalk-mixed-"));
    _write_files(
        base,
        [
            "main.jac",
            "src/app.jac",
            "src-gen/a.jac",
            "src/__pycache__/app.cpython-314.pyc",
            "notes.txt",
            "scratch/draft.jac",
            "scratch/node_modules/x.js",
            ".env",
            "keys/id_rsa",
            "dist/bundle.js",
            "build/out.txt",
            "tools/build",
            "node_modules/pkg/index.js",
            "node_modules/pkg/node_modules/dep/index.js",
            "apps/web/main.jac",
            "apps/web/node_modules/dep/index.js",
            "apps/web/dist/app.js",
            ".jac/venv/lib/site.py",
            ".jac/cache/blob.bin",
            ".jac/client/node_modules/react/index.js",
            ".jac/client/dist/index.js",
            ".jac/client/dist/assets/app.js",
            ".jac/admin/index.html",
            ".git/HEAD"
        ]
    );
    (base / "jac.toml").write_text("[project]\nname = \"mixed\"\n");
    (base / ".jacignore").write_text("scratch/\nnotes.txt\n");
    (base / "linked_src").symlink_to(base / "src", target_is_directory=True);
    (base / "linked_nm").symlink_to(base / "node_modules", target_is_directory=True);
    (base / "linked_main.jac").symlink_to(base / "main.jac");
    return base;
}


test "the bundle walk ships and reports the same paths on a mixed tree" {
    # Pinned before the walk learned to skip build trees: required console
    # files, nested build trees, .jacignore, jac.toml, a secret and symlinks.
    base = _mixed_tree();

    (kept, pruned) = partition_bundle_sources(base);

    expected = [
        ".jac/admin/index.html",
        ".jac/client/dist/assets/app.js",
        ".jac/client/dist/index.js",
        ".jacignore",
        "apps/web/main.jac",
        "linked_main.jac",
        "main.jac",
        "src/app.jac",
        "src-gen/a.jac"
    ];
    assert kept == [base / rel for rel in expected] , [
        p.relative_to(base).as_posix() for p in kept
    ];
    assert pruned
        == [
            ".git",
            "apps/web/dist",
            "apps/web/node_modules",
            "build",
            "dist",
            "node_modules",
            "scratch/node_modules",
            "src/__pycache__",
            "tools/build"
        ] , pruned;
}
