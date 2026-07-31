import io;
import os;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.binary { ResolvedToolchain }
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


def _local_toolchain(binary_path: str) -> ResolvedToolchain {
    return ResolvedToolchain(channel="local", local_path=binary_path);
}


test "pack_jab without a toolchain is a hard error (a .jab requires a seal)" {
    caught = False;
    try {
        pack_jab(_mini_app(), "", None);
    } except ValueError {
        caught = True;
    }
    assert caught;
}


test "an unrunnable toolchain binary fails the seal instead of shipping unsealed" {
    with tempfile.NamedTemporaryFile(suffix="-jac", delete=False) as tmp {
        tmp.write(b"not-an-elf");
        bogus = tmp.name;
    }
    os.chmod(bogus, 0o755);
    caught = False;
    try {
        pack_jab(_mini_app(), "", _local_toolchain(bogus));
    } except Exception {
        caught = True;
    } finally {
        os.unlink(bogus);
    }
    assert caught;
}


test "a real toolchain binary seals the app into a .jab (source + _precompiled + manifest)" {
    # The checkout's own binary stands in for the downloaded toolchain binary;
    # the mechanism (stage -> shim-import its own sealer --seal -> pack
    # _precompiled/**) is identical for release binaries.
    jac_bin = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";
    if not jac_bin.is_file() {
        return;
    }
    names = _names(pack_jab(_mini_app(), "", _local_toolchain(str(jac_bin))));
    assert "svc.jac" in names;
    # The sealed manifest sits at the tar root, which is what makes this a .jab.
    assert "_precompiled/MANIFEST.json" in names;
    pre = [
        n
        for n in names
        if n.startswith("_precompiled/")
    ];
    assert any([n.endswith("svc.jir") for n in pre]) , pre;
    # The seal shim never leaks into the packed bundle.
    assert not any(["_shim.jac" in n for n in names]) , names;
}
