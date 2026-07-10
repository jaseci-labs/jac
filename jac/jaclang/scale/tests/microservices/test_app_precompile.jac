import io;
import os;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { pack_jab }


def _mini_app -> str {
    d = tempfile.mkdtemp(prefix="jac-app-");
    Path(d, "jac.toml").write_text("[project]\nname = \"mini\"\n");
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    return d;
}


def _names(raw: bytes) -> list[str] {
    # A .jab is a gzip tar, so r:gz opens it like any bundle.
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        return tar.getnames();
    }
}


test "pack_jab without a pod binary is a hard error (a .jab requires a seal)" {
    caught = False;
    try {
        pack_jab(_mini_app(), "", b"");
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "an unrunnable pod binary fails the seal instead of shipping unsealed" {
    caught = False;
    try {
        pack_jab(_mini_app(), "", b"not-an-elf");
    } except Exception {
        caught = True;
    }
    assert caught;
}


test "a real pod binary seals the app into a .jab (source + _precompiled + manifest)" {
    # The checkout's own binary stands in for the downloaded pod binary; the
    # mechanism (stage -> precompile_bytecode.jac --seal -> pack _precompiled/**)
    # is identical for release binaries.
    jac_bin = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";
    if not jac_bin.is_file() {
        return;
    }
    names = _names(pack_jab(_mini_app(), "", jac_bin.read_bytes()));
    assert "svc.jac" in names;
    # The sealed manifest sits at the tar root, which is what makes this a .jab.
    assert "_precompiled/MANIFEST.json" in names;
    pre = [
        n
        for n in names
        if n.startswith("_precompiled/")
    ];
    assert any([n.endswith("svc.jir") for n in pre]) , pre;
}


test "pre_tar hook output lands in the .jab (join point precedes the tar)" {
    # The host client build overlaps the seal and is joined via pre_tar; files
    # it writes must be read by the tar that follows.
    jac_bin = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";
    if not jac_bin.is_file() {
        return;
    }
    d = _mini_app();
    def write_dist {
        dist = Path(d, ".jac", "client", "dist");
        dist.mkdir(parents=True, exist_ok=True);
        (dist / "index.html").write_text("<html></html>");
    }
    raw = pack_jab(d, "", jac_bin.read_bytes(), pre_tar=write_dist);
    assert ".jac/client/dist/index.html" in _names(raw);
}
