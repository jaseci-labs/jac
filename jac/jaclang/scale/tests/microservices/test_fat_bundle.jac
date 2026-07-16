import io;
import tarfile;
import tempfile;
import json;
import from pathlib { Path }
import from jaclang.scale.injector.bundle {
    content_address,
    fat_bundle_enabled,
    fat_bundle_setting,
    pack_jab
}


def _app(toml: str) -> str {
    d = tempfile.mkdtemp(prefix="jac-fat-app-");
    Path(d, "jac.toml").write_text(toml);
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    return d;
}


def _pod_binary -> bytes | None {
    # The checkout's own binary stands in for the downloaded pod binary, same
    # as test_app_precompile; skip when the toolchain has not been built.
    jac_bin = Path(__file__).parents[4] / "zig-out" / "bin" / "jac";
    if not jac_bin.is_file() {
        return None;
    }
    return jac_bin.read_bytes();
}


def _names(raw: bytes) -> list[str] {
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        return tar.getnames();
    }
}


def _member(raw: bytes, name: str) -> bytes {
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        return tar.extractfile(name).read();
    }
}


test "fat bundles default ON; [scale] fat_bundle=false opts out" {
    assert fat_bundle_setting(_app("[project]\nname = \"a\"\n")) == (True, False);
    assert fat_bundle_setting(
        _app("[project]\nname = \"a\"\n\n[scale]\nreplicas = 1\n")
    ) == (True, False);
    assert fat_bundle_setting(
        _app("[project]\nname = \"a\"\n\n[scale]\nfat_bundle = false\n")
    ) == (False, True);
    assert fat_bundle_setting(
        _app("[project]\nname = \"a\"\n\n[scale]\nfat_bundle = true\n")
    ) == (True, True);
    assert fat_bundle_enabled(_app("[project]\nname = \"a\"\n"));
}


test "fat_bundle=false ships no _vendor tree" {
    pod = _pod_binary();
    if pod is None {
        return;
    }
    toml = "[project]\nname = \"mini\"\n\n[scale]\nfat_bundle = false\n";
    names = _names(pack_jab(_app(toml), "", pod));
    assert not any([n.startswith("_vendor") for n in names]) , names;
}


test "default-on: a bare project ships a _vendor manifest for its closure" {
    pod = _pod_binary();
    if pod is None {
        return;
    }
    names = _names(pack_jab(_app("[project]\nname = \"mini\"\n"), "", pod));
    assert "_vendor/VENDOR.json" in names , names;
}


test "fat_bundle=true stages _vendor/wheels resolved by the seal binary" {
    pod = _pod_binary();
    if pod is None {
        return;
    }
    toml = "[project]\nname = \"mini\"\n\n[scale]\nfat_bundle = true\n";
    raw = pack_jab(_app(toml), "", pod);
    names = _names(raw);
    assert "_vendor/VENDOR.json" in names , names;
    wheels = [
        n
        for n in names
        if n.startswith("_vendor/wheels/") and n.endswith(".whl")
    ];
    # A [scale] project closes over the serve capability, so the vendored
    # closure is never empty.
    assert wheels , names;
    vendor = json.loads(_member(raw, "_vendor/VENDOR.json"));
    manifest = json.loads(_member(raw, "_precompiled/MANIFEST.json"));
    # The wheels must be resolved by the SAME binary that sealed the app and
    # that pods run; both stamps come from that one interpreter.
    assert vendor["python_tag"] == manifest["python_tag"] , (vendor, manifest);
    assert sorted(vendor["wheels"]) == sorted([n.split("/")[-1] for n in wheels]);
}


test "the bundle digest is deterministic and moves when a wheel changes" {
    pod = _pod_binary();
    if pod is None {
        return;
    }
    pinned = (
        "[project]\nname = \"mini\"\n\n[dependencies]\n"
        "python-dotenv = \"{}\"\n\n[scale]\nfat_bundle = true\n"
    );
    app = _app(pinned.format("==1.2.1"));
    first = content_address(pack_jab(app, "", pod));
    again = content_address(pack_jab(app, "", pod));
    assert first == again;
    bumped = content_address(pack_jab(_app(pinned.format("==1.2.2")), "", pod));
    assert bumped != first;
}
