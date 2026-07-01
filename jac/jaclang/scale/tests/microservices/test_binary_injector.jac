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
    host_arch,
    resolve_overlay_source,
    precompile_overlay,
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


# ---- channel resolution -----------------------------------------------------
test "no [dev] stanza resolves to the stable channel (no source overlay)" {
    d = _write_toml("[project]\nname = \"app\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_STABLE;
    assert not dev.overlays_source();
}


test "bare [dev] resolves to the dev channel and overlays source" {
    d = _write_toml("[project]\nname = \"app\"\n\n[dev]\ntest_jobs = \"auto\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
    assert dev.overlays_source();
    assert dev.repo == "";
    assert dev.jaclang_source == "";
}


test "whitespace [ dev ] table still resolves to the dev channel" {
    d = _write_toml("[ dev ]\ntest_jobs = \"auto\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
}


test "[dev] repo/branch is carried on the dev channel" {
    d = _write_toml(
        "[dev]\nrepo = \"https://github.com/jaseci-labs/jaseci\"\nbranch = \"wip\"\n"
    );
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
    assert dev.repo == "https://github.com/jaseci-labs/jaseci";
    assert dev.branch == "wip";
}


test "[dev] repo without branch defaults the branch to main" {
    d = _write_toml("[dev]\nrepo = \"https://github.com/x/y\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.branch == "main";
}


test "[dev] jaclang_source is carried on the dev channel" {
    d = _write_toml("[dev]\njaclang_source = \"jac\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
    assert dev.jaclang_source == "jac";
}


# ---- bootstrap command wiring -----------------------------------------------
test "stable bootstrap installs the shipped binary, no overlay, no build" {
    cmds = build_runtime_install_commands(KubernetesConfig(), False, False);
    joined = " && ".join(cmds);
    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in joined;
    assert "[dev]" not in joined;
    assert "zig build" not in joined;
    assert "git clone" not in joined;
    assert "install.sh" not in joined;
}


test "dev bootstrap injects [dev] jaclang_source; compiles on boot without A" {
    cmds = build_runtime_install_commands(KubernetesConfig(), True, False);
    joined = " && ".join(cmds);
    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in joined;
    assert "[dev]" in joined;
    assert overlay_pod_path() in joined;
    assert "JAC_NO_PRECOMPILE=0" not in joined;
}


test "dev bootstrap with A sets JAC_NO_PRECOMPILE=0 to use the shipped jir" {
    cmds = build_runtime_install_commands(KubernetesConfig(), True, True);
    joined = " && ".join(cmds);
    assert "[dev]" in joined;
    assert "JAC_NO_PRECOMPILE=0" in joined;
}


test "runtime_container_env exposes JAC_NO_PRECOMPILE only when precompiled" {
    plain = runtime_container_env(False);
    names_plain = [e["name"] for e in plain];
    assert "JAC_NO_PRECOMPILE" not in names_plain;

    precompiled = runtime_container_env(True);
    names_pc = [e["name"] for e in precompiled];
    assert "JAC_NO_PRECOMPILE" in names_pc;
}


# ---- packing + arch ---------------------------------------------------------
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


test "pack_binary_bytes tars only the binary (stable channel)" {
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


test "resolve_overlay_source prefers an existing local jaclang_source dir" {
    proj = Path(tempfile.mkdtemp());
    (proj / "jac" / "jaclang").mkdir(parents=True);
    resolved = resolve_overlay_source("", "", "jac", str(proj));
    assert resolved == (proj / "jac").resolve();
}


test "precompile_overlay is a no-op (False) on an arch mismatch" {
    src_root = Path(tempfile.mkdtemp());
    (src_root / "jaclang" / "utils").mkdir(parents=True);
    (src_root / "jaclang" / "utils" / "precompile_bytecode.jac").write_text("");
    other = "aarch64" if host_arch() == "x86_64" else "x86_64";
    assert precompile_overlay(b"ELF", src_root, other) == False;
}


# ---- injector seeding -------------------------------------------------------
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
