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
import from jaclang.scale.injector.binary { pack_binary_bytes, node_arch }
import from jaclang.scale.injector.binary_injector { BinaryInjector }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }
import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_runtime_install_commands,
    runtime_container_env,
    build_service_apt_prefix,
    build_bootstrap_init_container
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.config_loader { JacScaleConfig }


def _write_toml(body: str) -> str {
    d = tempfile.mkdtemp();
    with open(os.path.join(d, "jac.toml"), "w") as handle {
        handle.write(body);
    }
    return d;
}


test "no [dev] stanza resolves to the stable channel" {
    d = _write_toml("[project]\nname = \"app\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_STABLE;
}


test "bare [dev] is the dev channel, shipped bare (it IS main HEAD)" {
    d = _write_toml("[project]\nname = \"app\"\n\n[dev]\ntest_jobs = \"auto\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
}


test "whitespace [ dev ] table still resolves to the dev channel" {
    d = _write_toml("[ dev ]\ntest_jobs = \"auto\"\n");
    dev = resolve_dev_deploy(d);
    assert dev.channel == CHANNEL_DEV;
}


test "bootstrap installs the shipped binary; no [dev], no source build" {
    cmds = build_runtime_install_commands(KubernetesConfig());
    joined = " && ".join(cmds);
    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in joined;
    assert "[dev]" not in joined;
    assert "zig build" not in joined;
    assert "git clone" not in joined;
    assert "install.sh" not in joined;
}


test "first-boot install only runs jac install (no jir-seed adoption)" {
    script = str(
        build_bootstrap_init_container(KubernetesConfig(), "python:3.12-slim")["args"][
            0
        ]
    );
    assert "jac install" in script;
    assert "jir-seed" not in script;
    assert "_adopt.py" not in script;
}


test "runtime_container_env exposes HOME + PATH, no JAC_NO_PRECOMPILE" {
    names = [e["name"] for e in runtime_container_env()];
    assert "HOME" in names;
    assert "PATH" in names;
    assert "JAC_NO_PRECOMPILE" not in names;
}


test "[dependencies.system] in jac.toml installs into the service container" {
    with tempfile.TemporaryDirectory() as project {
        Path(project, "jac.toml").write_text(
            "[project]\nname = \"sysdep-app\"\n\n"
            "[dependencies.system]\ngit = \"*\"\nffmpeg = \"*\"\n"
        );
        k8s = JacScaleConfig(project_dir=Path(project)).get_kubernetes_config();
        assert sorted(k8s["service_dependencies"]) == ["ffmpeg", "git"];
        cfg = KubernetesConfig.from_dict(KubernetesConfig, k8s);
        prefix = build_service_apt_prefix(cfg);
        assert "apt-get install -y" in prefix;
        assert "git" in prefix;
        assert "ffmpeg" in prefix;
        # Chains into app-start so a failed apt aborts the boot (no silent start).
        assert prefix.endswith("&& ");
    }
}


test "no [dependencies.system] means no apt install in the service container" {
    with tempfile.TemporaryDirectory() as project {
        Path(project, "jac.toml").write_text("[project]\nname = \"plain-app\"\n");
        k8s = JacScaleConfig(project_dir=Path(project)).get_kubernetes_config();
        assert k8s["service_dependencies"] == [];
        assert build_service_apt_prefix(
            KubernetesConfig.from_dict(KubernetesConfig, k8s)
        ) == "";
    }
}


test "invalid system package name is rejected (no shell injection)" {
    cfg = KubernetesConfig(service_dependencies=["git; rm -rf /"]);
    caught = False;
    try {
        build_service_apt_prefix(cfg);
    } except ValueError {
        caught = True;
    }
    assert caught;
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


test "pack_binary_bytes tars only the binary" {
    raw = pack_binary_bytes(b"ELF-binary");
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
