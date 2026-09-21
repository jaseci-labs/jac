import io;
import os;
import re;
import sys;
import tarfile;
import tempfile;
import json;
import from pathlib { Path }
import from jaclang.testing.requires { require_network }
import from jaclang.scale.tests.support { require_pod_binary }
import from jaclang.project.providers { write_venv_deps_marker }
import from jaclang.dist.jab_vendor { WheelTarget, download_wheels }
import from jaclang.scale.utils.vendor_wheels {
    POD_GLIBC,
    pod_arch_from_argv,
    pod_wheel_target
}
import from jaclang.scale.injector.bundle {
    _strip_external_record_lines,
    staged_venv_files,
    content_address,
    fat_bundle_enabled,
    fat_bundle_setting,
    pack_jab
}


glob _MANYLINUX_X86_64 = re.compile(r"manylinux(2014|_2_\d+)_x86_64"),
     _MANYLINUX_AARCH64 = re.compile(r"manylinux(2014|_2_\d+)_aarch64");


def _app(toml: str) -> str {
    d = tempfile.mkdtemp(prefix="jac-fat-app-");
    Path(d, "jac.toml").write_text(toml);
    Path(d, "svc.jac").write_text("def:pub ping -> str { return \"pong\"; }\n");
    return d;
}


def _pod_binary -> bytes {
    return require_pod_binary().read_bytes();
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


test "a deploy targets the node arch, the pod glibc floor and the seal binary's python" {
    assert pod_wheel_target("") is None;
    target = pod_wheel_target("x86_64");
    assert target is not None;
    assert target.arch == "x86_64";
    assert POD_GLIBC == (2, 36);
    assert target.glibc == POD_GLIBC;
    assert target.python_version
        == f"{sys.version_info.major}.{sys.version_info.minor}";
    assert target.platform_tag() == "manylinux_2_36_x86_64";
    tags = target.platform_tags();
    assert tags[0] == "manylinux_2_36_x86_64" , tags;
    assert "manylinux2014_x86_64" in tags and "manylinux_2_17_x86_64" in tags , tags;
    assert "manylinux_2_28_x86_64" in tags , tags;
    assert "--implementation" in target.pip_args() and "cp" in target.pip_args();
    arm = pod_wheel_target("arm64");
    assert arm is not None and arm.arch == "aarch64";
    assert "manylinux2014_aarch64" in arm.platform_tags();
}


test "the vendor script still understands the platform tag older deploy hosts pass" {
    assert pod_arch_from_argv("x86_64") == "x86_64";
    assert pod_arch_from_argv("manylinux_2_36_aarch64") == "aarch64";
    assert pod_arch_from_argv("manylinux2014_x86_64") == "x86_64";
    assert pod_arch_from_argv("") == "";
}


test "a pod target downloads real manylinux2014-only wheels from PyPI" {
    require_network();
    target = WheelTarget(arch="x86_64", python_version="3.12", glibc=POD_GLIBC);
    with tempfile.TemporaryDirectory(prefix="jac-pod-wheels-") as tmp {
        result = download_wheels(
            ["watchdog==6.0.0", "bcrypt==5.0.0"], Path(tmp), target=target
        );
        assert result.ok , result.detail;
        wheels = sorted([p.name for p in Path(tmp).`glob("*.whl")]);
    }
    assert "watchdog-6.0.0-py3-none-manylinux2014_x86_64.whl" in wheels , wheels;
    bcrypt = [
        w
        for w in wheels
        if w.startswith("bcrypt-5.0.0-cp39-abi3-")
    ];
    assert len(bcrypt) == 1 and _MANYLINUX_X86_64.search(bcrypt[0]) , wheels;
    assert not any(["macosx" in w or "aarch64" in w for w in wheels]) , wheels;
}


test "a parent version range vendors its sdist-only dependency for the pod" {
    require_network();
    target = WheelTarget(arch="aarch64", python_version="3.12", glibc=POD_GLIBC);
    with tempfile.TemporaryDirectory(prefix="jac-pod-sdist-") as tmp {
        saved_cache = os.environ.get("PIP_CACHE_DIR");
        os.environ["PIP_CACHE_DIR"] = str(Path(tmp) / "pip-cache");
        try {
            result = download_wheels(
                ["pywebpush>=2.0.0"], Path(tmp) / "wheels", target=target
            );
        } finally {
            if saved_cache is None {
                del os.environ["PIP_CACHE_DIR"];
            } else {
                os.environ["PIP_CACHE_DIR"] = saved_cache;
            }
        }
        assert result.ok , result.detail;
        wheels = sorted([p.name for p in (Path(tmp) / "wheels").`glob("*.whl")]);
    }
    assert "http_ece-1.2.1-py2.py3-none-any.whl" in wheels , wheels;
    assert any([w.startswith("pywebpush-") for w in wheels]) , wheels;
    crypto = [
        w
        for w in wheels
        if w.startswith("cryptography-")
    ];
    assert len(crypto) == 1 and _MANYLINUX_AARCH64.search(crypto[0]) , wheels;
    assert not any(["macosx" in w or "x86_64" in w for w in wheels]) , wheels;
}


test "fat bundles default ON; [scale] fat_bundle=false opts out" {
    assert fat_bundle_setting(_app("[project]\nname = \"a\"\n")) == (True, False);
    assert fat_bundle_setting(
        _app("[project]\nname = \"a\"\n\n[scale]\nreplicas = 1\n")
    )
        == (True, False);
    assert fat_bundle_setting(
        _app("[project]\nname = \"a\"\n\n[scale]\nfat_bundle = false\n")
    )
        == (False, True);
    assert fat_bundle_setting(
        _app("[project]\nname = \"a\"\n\n[scale]\nfat_bundle = true\n")
    )
        == (True, True);
    assert fat_bundle_enabled(_app("[project]\nname = \"a\"\n"));
}


test "fat_bundle=false ships no _vendor tree" {
    pod = _pod_binary();
    toml = "[project]\nname = \"mini\"\n\n[scale]\nfat_bundle = false\n";
    names = _names(pack_jab(_app(toml), pod));
    assert not any([n.startswith("_vendor") for n in names]) , names;
}


test "default-on: a bare project ships a _vendor manifest for its closure" {
    pod = _pod_binary();
    names = _names(pack_jab(_app("[project]\nname = \"mini\"\n"), pod));
    assert "_vendor/VENDOR.json" in names , names;
}


test "fat_bundle=true stages _vendor/wheels resolved by the seal binary" {
    pod = _pod_binary();
    toml = "[project]\nname = \"mini\"\n\n[scale]\nfat_bundle = true\n";
    raw = pack_jab(_app(toml), pod);
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
    pinned = (
        "[project]\nname = \"mini\"\n\n[dependencies]\n"
        "python-dotenv = \"{}\"\n\n[scale]\nfat_bundle = true\n"
    );
    app = _app(pinned.format("==1.2.1"));
    first = content_address(pack_jab(app, pod));
    again = content_address(pack_jab(app, pod));
    assert first == again;
    bumped = content_address(pack_jab(_app(pinned.format("==1.2.2")), pod));
    assert bumped != first;
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


test "staged_venv_files ships marker plus site-packages, never pyc or bin" {
    stage = Path(tempfile.mkdtemp(prefix="jac-sealvenv-stage-"));
    _fake_staged_venv(stage);
    assert staged_venv_files(stage) == [] , "no marker means nothing ships";
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


test "pack_jab seals a prebuilt venv unless JAC_SEAL_SKIP_VENV opts out" {
    pod = _pod_binary();
    toml = (
        "[project]\nname = \"mini\"\n\n[dependencies]\n"
        "python-dotenv = \"==1.2.1\"\n\n[scale]\nfat_bundle = true\n"
    );
    os.environ["JAC_SEAL_SKIP_VENV"] = "1";
    try {
        skipped = _names(pack_jab(_app(toml), pod));
    } finally {
        del os.environ["JAC_SEAL_SKIP_VENV"];
    }
    assert any([n.startswith("_vendor/wheels/") for n in skipped]);
    assert not any([n.startswith(".jac/venv/") for n in skipped]) , skipped[:40];

    raw = pack_jab(_app(toml), pod);
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


test "vendoring passes a platform tag understood by older seal scripts" {
    import from unittest.mock { patch }
    import jaclang.scale.injector.bundle as bundle;
    with tempfile.TemporaryDirectory() as tmp {
        stage = Path(tmp) / "app";
        (stage / "_vendor").mkdir(parents=True);
        (stage / "_vendor" / "VENDOR.json").write_text("{}");
        old_script = Path(tmp) / "old-vendor.jac";
        with patch.object(bundle, "_child_tree_script", return_value=old_script), patch(
            "subprocess.run"
        ) as mock_run {
            mock_run.return_value.returncode = 0;
            mock_run.return_value.stdout = "";
            mock_run.return_value.stderr = "";
            bundle._vendor_stage(stage, b"binary", "arm64");
            argv = mock_run.call_args[0][0];
            assert argv[-1] == "manylinux_2_36_aarch64" , argv;
            assert argv[2] == str(old_script);
            assert pod_arch_from_argv(argv[-1]) == "aarch64";
        }
    }
}
