import os;
import io;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.config.dev_config {
    resolve_dev_deploy,
    DevDeploy,
    CHANNEL_STABLE,
    CHANNEL_DEV
}
import from jaclang.scale.injector.binary {
    pack_binary_bytes,
    pack_overlay,
    node_arch,
    resolve_overlay_source,
    overlay_pod_path,
    OVERLAY_SUBDIR
}
import from jaclang.scale.injector.binary_injector { BinaryInjector }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }
import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_runtime_install_commands,
    runtime_container_env
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


def _write_toml(body: str) -> str {
    d = tempfile.mkdtemp();
    with open(os.path.join(d, "jac.toml"), "w") as handle {
        handle.write(body);
    }
    return d;
}


test "no [dev] stanza resolves to the stable channel, no overlay" {
    d = _write_toml("[project]\nname = \"app\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_STABLE;
    assert not dev.overlays_source();
}


test "bare [dev] is the dev channel but ships bare (no redundant main overlay)" {
    d = _write_toml("[project]\nname = \"app\"\n\n[dev]\ntest_jobs = \"auto\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
    assert dev.repo == "";
    assert dev.jaclang_source == "";
    assert not dev.overlays_source();
}


test "whitespace [ dev ] table still resolves to the dev channel" {
    d = _write_toml("[ dev ]\ntest_jobs = \"auto\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
}


test "[dev] repo/branch overlays that source" {
    d = _write_toml(
        "[dev]\nrepo = \"https://github.com/jaseci-labs/jaseci\"\nbranch = \"wip\"\n"
    );
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
    assert dev.overlays_source();
    assert dev.repo == "https://github.com/jaseci-labs/jaseci";
    assert dev.branch == "wip";
}


test "[dev] repo without branch defaults the branch to main" {
    d = _write_toml("[dev]\nrepo = \"https://github.com/x/y\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.branch == "main";
}


test "[dev] jaclang_source overlays the local checkout" {
    d = _write_toml("[dev]\njaclang_source = \"jac\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
    assert dev.overlays_source();
    assert dev.jaclang_source == "jac";
}


test "no-overlay bootstrap installs the shipped binary; no [dev], no build" {
    cmds = build_runtime_install_commands(KubernetesConfig(), False);
    joined = " && ".join(cmds);
    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in joined;
    assert "[dev]" not in joined;
    assert "zig build" not in joined;
    assert "git clone" not in joined;
    assert "install.sh" not in joined;
}


test "overlay bootstrap injects [dev] jaclang_source; pod compiles on boot" {
    cmds = build_runtime_install_commands(KubernetesConfig(), True);
    joined = " && ".join(cmds);
    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in joined;
    assert "[dev]" in joined;
    assert overlay_pod_path() in joined;
    assert "grep -q" in joined and r"[dev\]" in joined;
    assert "JAC_NO_PRECOMPILE" not in joined;
}


test "runtime_container_env exposes HOME + PATH, no JAC_NO_PRECOMPILE" {
    names = [e["name"] for e in runtime_container_env()];
    assert "HOME" in names;
    assert "PATH" in names;
    assert "JAC_NO_PRECOMPILE" not in names;
}


test "node_arch defaults to the host arch and honors JAC_NODE_ARCH" {
    saved = os.environ.pop("JAC_NODE_ARCH", None);
    try {
        assert node_arch() in ("x86_64", "aarch64");
        os.environ["JAC_NODE_ARCH"] = "aarch64";
        assert node_arch() == "aarch64";
    } finally {
        os.environ.pop("JAC_NODE_ARCH", None);
        if saved is not None {
            os.environ["JAC_NODE_ARCH"] = saved;
        }
    }
}


test "pack_binary_bytes tars only the binary (no-overlay channel)" {
    raw = pack_binary_bytes(b"ELF-binary");
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
    }
    assert names == [f"{TOOLCHAIN_SUBDIR}/bin/jac"];
}


test "pack_overlay tars the binary plus the jaclang source tree" {
    src_root = Path(tempfile.mkdtemp());
    (src_root / "jaclang").mkdir();
    (src_root / "jaclang" / "x.jac").write_text("x = 1;");
    (src_root / "jaclang" / "__pycache__").mkdir();
    (src_root / "jaclang" / "__pycache__" / "junk.pyc").write_text("junk");

    raw = pack_overlay(b"ELF", src_root);
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
    }
    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in names;
    assert f"{TOOLCHAIN_SUBDIR}/{OVERLAY_SUBDIR}/jaclang/x.jac" in names;
    assert not any(["__pycache__" in n for n in names]);
}


test "resolve_overlay_source prefers a local jaclang_source dir, no cleanup" {
    proj = Path(tempfile.mkdtemp());
    (proj / "jac" / "jaclang").mkdir(parents=True);
    (resolved, cleanup) = resolve_overlay_source("", "", "jac", str(proj));
    assert resolved == (proj / "jac").resolve();
    assert cleanup is None;
}


test "BinaryInjector unpacks AND seeds both the source and the toolchain bundle" {
    injector = BinaryInjector();
    injector._object_key = "bundles/orders/aaa.tar.gz";
    injector._toolchain_object_key = "toolchain/orders/bbb.tar.gz";
    injector._bundle_bytes = b"src";
    injector._toolchain_bytes = b"tool";

    paths = injector._unpack_bundle_paths();
    assert any(["aaa.tar.gz" in path for path in paths]);
    assert any(["bbb.tar.gz" in path for path in paths]);

    keys = [key for (key, _) in injector._seed_artifacts()];
    assert "bundles/orders/aaa.tar.gz" in keys;
    assert "toolchain/orders/bbb.tar.gz" in keys;
}
