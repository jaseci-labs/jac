import os;
import io;
import tarfile;
import tempfile;
import from jaclang.scale.config.dev_config {
    resolve_dev_deploy,
    CHANNEL_STABLE,
    CHANNEL_DEV,
    CHANNEL_BRANCH,
    CHANNEL_LOCAL
}
import from jaclang.scale.injector.binary { pack_binary_bytes, node_arch }
import from jaclang.scale.injector.binary_injector { BinaryInjector }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }
import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_runtime_install_commands
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


test "no [dev] stanza resolves to the stable release channel" {
    d = _write_toml("[project]\nname = \"app\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_STABLE;
    assert dev.ships_binary();
    assert not dev.builds_in_pod();
}


test "bare [dev] resolves to the rolling dev prerelease channel" {
    d = _write_toml("[project]\nname = \"app\"\n\n[dev]\ntest_jobs = \"auto\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
    assert dev.ships_binary();
}


test "[dev] repo/branch resolves to the in-pod build-from-branch channel" {
    d = _write_toml(
        "[dev]\nrepo = \"https://github.com/jaseci-labs/jaseci\"\nbranch = \"wip\"\n"
    );
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_BRANCH;
    assert dev.builds_in_pod();
    assert not dev.ships_binary();
    assert dev.repo == "https://github.com/jaseci-labs/jaseci";
    assert dev.branch == "wip";
}


test "[dev] repo without branch defaults the branch to main" {
    d = _write_toml("[dev]\nrepo = \"https://github.com/x/y\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_BRANCH;
    assert dev.branch == "main";
}


test "[dev] jaclang_source resolves to the local host-build channel" {
    d = _write_toml("[dev]\njaclang_source = \"jac\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_LOCAL;
    assert dev.ships_binary();
}


test "ship-binary bootstrap installs the shipped binary, never builds in-pod" {
    cmds = build_runtime_install_commands(KubernetesConfig(), False);
    joined = " && ".join(cmds);

    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in joined;
    assert "zig build" not in joined;
    assert "git clone" not in joined;
    assert "build-essential" not in joined;
    assert "install.sh" not in joined;
}


test "branch bootstrap clones + builds in-pod, ships no prebuilt binary" {
    cmds = build_runtime_install_commands(KubernetesConfig(), True);
    joined = " && ".join(cmds);
    assert "zig build" in joined;
    assert "git clone" in joined;
    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" not in joined;
}


test "node_arch defaults to the host arch and honors JAC_NODE_ARCH" {
    saved = os.environ.pop("JAC_NODE_ARCH", None);
    try {
        default_arch = node_arch();
        assert default_arch in ("x86_64", "aarch64");
        os.environ["JAC_NODE_ARCH"] = "aarch64";
        assert node_arch() == "aarch64";
    } finally {
        os.environ.pop("JAC_NODE_ARCH", None);
        if saved is not None {
            os.environ["JAC_NODE_ARCH"] = saved;
        }
    }
}


test "pack_binary_bytes tars the binary into the toolchain layout, nothing else" {
    raw = pack_binary_bytes(b"ELF-binary");
    names: list[str] = [];
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
    }
    assert names == [f"{TOOLCHAIN_SUBDIR}/bin/jac"];
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
