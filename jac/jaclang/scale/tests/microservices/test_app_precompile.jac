import io;
import os;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { pack_source }


def _mini_app -> str {
    d = tempfile.mkdtemp(prefix="jac-app-");
    Path(d, "jac.toml").write_text("[project]\nname = \"mini\"\n");
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    return d;
}


def _names(raw: bytes) -> list[str] {
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        return tar.getnames();
    }
}


test "pack_source without a pod binary packs source only (no _precompiled)" {
    names = _names(pack_source(_mini_app()));
    assert "svc.jac" in names;
    assert not any(["_precompiled" in n for n in names]);
}


test "an unrunnable pod binary degrades gracefully to a source-only bundle" {
    names = _names(pack_source(_mini_app(), "", b"not-an-elf"));
    assert "svc.jac" in names;
    assert not any(["_precompiled" in n for n in names]);
}


test "a real pod binary seeds _precompiled app modules into the bundle (#7179)" {
    # The checkout's own binary stands in for the downloaded pod binary; the
    # mechanism (stage -> precompile_bytecode.jac -> pack _precompiled/**) is
    # identical for release binaries.
    jac_bin = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";
    if not jac_bin.is_file() {
        return;
    }
    names = _names(pack_source(_mini_app(), "", jac_bin.read_bytes()));
    assert "svc.jac" in names;
    pre = [
        n
        for n in names
        if n.startswith("_precompiled/")
    ];
    assert any([n.endswith("svc.jir") for n in pre]) , pre;
}
