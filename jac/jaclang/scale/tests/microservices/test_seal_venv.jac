"""Seal-time venv staging: the .jab ships a prebuilt venv so pods skip the
boot-time `jac install` (#8695)."""

import io;
import os;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle {
    _strip_external_record_lines,
    pack_jab,
    staged_venv_files
}
import from jaclang.project.providers { write_venv_deps_marker }


def _pod_binary -> bytes | None {
    # The checkout's own binary stands in for the downloaded pod binary, same
    # as test_fat_bundle; skip when the toolchain has not been built.
    jac_bin = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";
    if not jac_bin.is_file() {
        return None;
    }
    return jac_bin.read_bytes();
}


def _app(toml: str) -> str {
    d = tempfile.mkdtemp(prefix="jac-sealvenv-app-");
    Path(d, "jac.toml").write_text(toml);
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    return d;
}


def _names(raw: bytes) -> list[str] {
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        return tar.getnames();
    }
}


def _member(raw: bytes, name: str) -> bytes {
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        member = tar.extractfile(name);
        assert member is not None , f"member {name} not extractable";
        return member.read();
    }
}


def _fake_staged_venv(stage: Path) -> Path {
    site = stage / ".jac" / "venv" / "lib" / "python3.14" / "site-packages";
    (site / "pkg").mkdir(parents=True);
    (site / "pkg" / "mod.py").write_text("x = 1\n");
    (site / "pkg" / "__pycache__").mkdir();
    (site / "pkg" / "__pycache__" / "mod.cpython-314.pyc").write_bytes(b"\x00");
    (site / "stray.pyc").write_bytes(b"\x00");
    bin_dir = stage / ".jac" / "venv" / "bin";
    bin_dir.mkdir(parents=True);
    (bin_dir / "python3").write_text("");
    return site;
}


test "staged_venv_files is empty without the seal marker" {
    stage = Path(tempfile.mkdtemp(prefix="jac-sealvenv-stage-"));
    _fake_staged_venv(stage);
    assert staged_venv_files(stage) == [];
}


test "staged_venv_files ships marker plus site-packages, never pyc or bin" {
    stage = Path(tempfile.mkdtemp(prefix="jac-sealvenv-stage-"));
    _fake_staged_venv(stage);
    write_venv_deps_marker(stage / ".jac" / "venv", ["pkg==1.0"]);
    rels = [p.relative_to(stage).as_posix() for p in staged_venv_files(stage)];
    assert ".jac/venv/.jac-deps-hash" in rels , rels;
    assert ".jac/venv/lib/python3.14/site-packages/pkg/mod.py" in rels , rels;
    assert not any([".pyc" in r for r in rels]) , rels;
    assert not any(["__pycache__" in r for r in rels]) , rels;
    assert not any([r.startswith(".jac/venv/bin/") for r in rels]) , rels;
}


test "RECORD lines pointing outside site-packages are stripped" {
    site = Path(tempfile.mkdtemp(prefix="jac-sealvenv-rec-"));
    info = site / "pkg-1.0.dist-info";
    info.mkdir(parents=True);
    record = info / "RECORD";
    record.write_text(
        "pkg/mod.py,sha256=abc,10\n"
        "../../../bin/pkg-cli,sha256=varies-per-stage,99\n"
        "pkg-1.0.dist-info/RECORD,,\n"
    );
    _strip_external_record_lines(site);
    kept = record.read_text();
    assert "pkg/mod.py" in kept;
    assert "pkg-1.0.dist-info/RECORD" in kept;
    assert "bin/pkg-cli" not in kept;
    before = kept;
    _strip_external_record_lines(site);
    assert record.read_text() == before;
}


test "pack_jab seals a prebuilt venv the pod can import from" {
    pod = _pod_binary();
    if pod is None {
        return;
    }
    toml = (
        "[project]\nname = \"mini\"\n\n[dependencies]\n"
        "python-dotenv = \"==1.2.1\"\n\n[scale]\nfat_bundle = true\n"
    );
    raw = pack_jab(_app(toml), "", pod);
    names = _names(raw);
    venv_names = [
        n
        for n in names
        if n.startswith(".jac/venv/")
    ];
    assert ".jac/venv/.jac-deps-hash" in venv_names , names[:40];
    dotenv_members = [
        n
        for n in venv_names
        if "/site-packages/dotenv/" in n and n.endswith(".py")
    ];
    assert dotenv_members , venv_names[:40];
    assert not any([n.endswith(".pyc") for n in venv_names]) , venv_names[:40];
    assert not any(["__pycache__" in n for n in venv_names]) , venv_names[:40];
    assert not any([n.startswith(".jac/venv/bin/") for n in venv_names]);
    seed_pip = [
        n
        for n in venv_names
        if "/site-packages/pip/" in n or "/site-packages/pip-" in n
    ];
    assert not seed_pip , seed_pip[:10];
    records = [
        n
        for n in venv_names
        if n.endswith(".dist-info/RECORD")
    ];
    assert records , venv_names[:40];
    for rec in records {
        assert "../" not in _member(raw, rec).decode("utf-8") , rec;
    }
}


test "JAC_SEAL_SKIP_VENV ships wheels but no venv" {
    pod = _pod_binary();
    if pod is None {
        return;
    }
    toml = (
        "[project]\nname = \"mini\"\n\n[dependencies]\n"
        "python-dotenv = \"==1.2.1\"\n\n[scale]\nfat_bundle = true\n"
    );
    os.environ["JAC_SEAL_SKIP_VENV"] = "1";
    try {
        names = _names(pack_jab(_app(toml), "", pod));
    } finally {
        del os.environ["JAC_SEAL_SKIP_VENV"];
    }
    assert any([n.startswith("_vendor/wheels/") for n in names]);
    assert not any([n.startswith(".jac/venv/") for n in names]) , names[:40];
}
