import io;
import os;
import tarfile;
import tempfile;
import unittest.mock as mock;
import from pathlib { Path }
import from jaclang.scale.injector.bundle { pack_source, _precompile_app }


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


test "precompile runs from the staging dir with dev sourcing off" {
    # Inheriting the driver's CWD lets the pod binary pick up a [dev]
    # jaclang_source from the driver's jac.toml and recompile all of jaclang.
    seen = {};

    def fake_run(cmd: list, **kwargs: dict) -> object {
        seen.update(kwargs);
        seen["cmd"] = cmd;
        done = mock.MagicMock();
        done.returncode = 1;
        done.stdout = "";
        done.stderr = "stub";
        return done;
    }
    # The driver's own dev override exports these (see _jac_finder); they must
    # not leak into the pod binary or it recompiles jaclang from source.
    dev_markers = {"JAC_DEV_SOURCE": "/driver/checkout/jac", "JAC_NO_PRECOMPILE": "1"};
    with mock.patch("jaclang.scale.injector.bundle.subprocess.run", fake_run), mock.patch.dict(
        os.environ, dev_markers
    ) {
        assert _precompile_app(Path(_mini_app()), b"fake-binary") is None;
    }
    stage_root = seen["cmd"][3];
    assert seen["cwd"] == stage_root , seen;
    assert seen["env"]["JAC_NO_DEV_SOURCE"] == "1" , seen;
    assert "JAC_DEV_SOURCE" not in seen["env"] , seen;
    assert "JAC_NO_PRECOMPILE" not in seen["env"] , seen;
    # The rest of the driver's environment still flows through.
    assert "PATH" in seen["env"];
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
