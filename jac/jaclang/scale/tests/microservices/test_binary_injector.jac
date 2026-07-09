import os;
import io;
import tarfile;
import tempfile;
import unittest.mock;
import from pathlib { Path }
import from types { SimpleNamespace }
import from jaclang.scale.config.dev_config {
    resolve_dev_channel,
    Channel,
    BINARY_PATH_ENV
}
import from jaclang.scale.injector.binary {
    pack_binary_bytes,
    cluster_node_archs,
    node_arch,
    download_release_binary
}
import from jaclang.runtimelib.utils { host_arch }
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
    assert resolve_dev_channel(d) == Channel.STABLE;
}


test "bare [dev] is the dev channel, shipped bare (it IS main HEAD)" {
    d = _write_toml("[project]\nname = \"app\"\n\n[dev]\ntest_jobs = \"auto\"\n");
    assert resolve_dev_channel(d) == Channel.DEV;
}


test "whitespace [ dev ] table still resolves to the dev channel" {
    d = _write_toml("[ dev ]\ntest_jobs = \"auto\"\n");
    assert resolve_dev_channel(d) == Channel.DEV;
}


test "JAC_SCALE_BINARY_PATH forces the LOCAL channel over any [dev] stanza" {
    d = _write_toml("[dev]\ntest_jobs = \"auto\"\n");
    saved = os.environ.get(BINARY_PATH_ENV);
    try {
        os.environ[BINARY_PATH_ENV] = "/some/jac";
        assert resolve_dev_channel(d) == Channel.LOCAL;
    } finally {
        os.environ.pop(BINARY_PATH_ENV, None);
        if saved is not None {
            os.environ[BINARY_PATH_ENV] = saved;
        }
    }
}


test "LOCAL channel ships the binary at JAC_SCALE_BINARY_PATH, no download" {
    with tempfile.NamedTemporaryFile(suffix="-jac", delete=False) as tmp {
        tmp.write(b"ELF-local-binary");
        tmp_path = tmp.name;
    }
    saved = os.environ.get(BINARY_PATH_ENV);
    try {
        os.environ[BINARY_PATH_ENV] = tmp_path;
        assert download_release_binary("local", node_arch()) == b"ELF-local-binary";
    } finally {
        os.environ.pop(BINARY_PATH_ENV, None);
        if saved is not None {
            os.environ[BINARY_PATH_ENV] = saved;
        }
        os.unlink(tmp_path);
    }
}


test "LOCAL channel without JAC_SCALE_BINARY_PATH is a loud error" {
    saved = os.environ.pop(BINARY_PATH_ENV, None);
    caught = False;
    try {
        download_release_binary("local", node_arch());
    } except RuntimeError {
        caught = True;
    } finally {
        if saved is not None {
            os.environ[BINARY_PATH_ENV] = saved;
        }
    }
    assert caught;
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


def _fake_node(arch: str) -> SimpleNamespace {
    return SimpleNamespace(
        status=SimpleNamespace(node_info=SimpleNamespace(architecture=arch))
    );
}


def _core_api_with_nodes(archs: list[str]) -> unittest.mock.MagicMock {
    api = unittest.mock.MagicMock();
    api.list_node.return_value = SimpleNamespace(items=[_fake_node(a) for a in archs]);
    return api;
}


def _without_node_arch_env(check: any) {
    saved = os.environ.pop("JAC_NODE_ARCH", None);
    try {
        check();
    } finally {
        os.environ.pop("JAC_NODE_ARCH", None);
        if saved is not None {
            os.environ["JAC_NODE_ARCH"] = saved;
        }
    }
}


test "node_arch uses the cluster's node arch, not the host arch" {
    def check {
        with unittest.mock.patch(
            "kubernetes.client.CoreV1Api",
            return_value=_core_api_with_nodes(["amd64", "amd64"])
        ) {
            assert node_arch() == "x86_64";
        }
        with unittest.mock.patch(
            "kubernetes.client.CoreV1Api", return_value=_core_api_with_nodes(["arm64"])
        ) {
            assert node_arch() == "aarch64";
        }
    }
    _without_node_arch_env(check);
}


test "node_arch falls back to the host arch when the cluster is unreachable" {
    def check {
        with unittest.mock.patch(
            "kubernetes.client.CoreV1Api", side_effect=Exception("no cluster")
        ) {
            assert node_arch() in ("x86_64", "aarch64");
        }
    }
    _without_node_arch_env(check);
}


test "node_arch falls back to the host arch on a mixed-arch cluster" {
    def check {
        with unittest.mock.patch(
            "kubernetes.client.CoreV1Api",
            return_value=_core_api_with_nodes(["amd64", "arm64"])
        ) {
            assert node_arch() == host_arch();
        }
    }
    _without_node_arch_env(check);
}


test "JAC_NODE_ARCH overrides cluster detection and is normalized" {
    saved = os.environ.pop("JAC_NODE_ARCH", None);
    try {
        os.environ["JAC_NODE_ARCH"] = "arm64";
        with unittest.mock.patch(
            "kubernetes.client.CoreV1Api", return_value=_core_api_with_nodes(["amd64"])
        ) as api {
            assert node_arch() == "aarch64";
            api.assert_not_called();
        }
    } finally {
        os.environ.pop("JAC_NODE_ARCH", None);
        if saved is not None {
            os.environ["JAC_NODE_ARCH"] = saved;
        }
    }
}


test "cluster_node_archs dedupes and maps GOARCH to release arch names" {
    with unittest.mock.patch(
        "kubernetes.client.CoreV1Api",
        return_value=_core_api_with_nodes(["amd64", "x86_64", "arm64"])
    ) {
        assert cluster_node_archs() == ["aarch64", "x86_64"];
    }
}


test "blank node architectures are ignored" {
    with unittest.mock.patch(
        "kubernetes.client.CoreV1Api",
        return_value=_core_api_with_nodes(["  ", "", "amd64"])
    ) {
        assert cluster_node_archs() == ["x86_64"];
    }
}


test "node listing is bounded by a request timeout" {
    api = _core_api_with_nodes(["amd64"]);
    with unittest.mock.patch("kubernetes.client.CoreV1Api", return_value=api) {
        cluster_node_archs();
    }
    kwargs = api.list_node.call_args.kwargs;
    assert kwargs["_request_timeout"] == 10;
}


test "pack_binary_bytes tars only the binary" {
    raw = pack_binary_bytes(b"ELF-binary");
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
    }
    assert names == [f"{TOOLCHAIN_SUBDIR}/bin/jac"];
}


test "BinaryInjector unpacks AND seeds both the app .jab and the toolchain bundle" {
    injector = BinaryInjector();
    # App bundle is a .jab; the toolchain bundle stays a plain .tar.gz.
    injector._object_key = "bundles/orders/aaa.jab";
    injector._toolchain_object_key = "toolchain/orders/bbb.tar.gz";
    injector._bundle_bytes = b"src";
    injector._toolchain_bytes = b"tool";

    paths = injector._unpack_bundle_paths();
    assert any(["aaa.jab" in path for path in paths]);
    assert any(["bbb.tar.gz" in path for path in paths]);

    keys = [key for (key, _) in injector._seed_artifacts()];
    assert "bundles/orders/aaa.jab" in keys;
    assert "toolchain/orders/bbb.tar.gz" in keys;
}
