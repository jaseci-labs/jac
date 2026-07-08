import os;
import io;
import tarfile;
import tempfile;
import unittest.mock;
import from pathlib { Path }
import from types { SimpleNamespace }
import from jaclang.scale.config.dev_config {
    resolve_dev_deploy,
    DevDeploy,
    CHANNEL_STABLE,
    CHANNEL_DEV
}
import from jaclang.scale.injector.binary {
    pack_binary_bytes,
    pack_overlay,
    cluster_node_archs,
    node_arch,
    release_arch,
    resolve_overlay_source,
    overlay_pod_path,
    OVERLAY_SUBDIR
}
import from jaclang.scale.injector.binary_injector { BinaryInjector }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }
import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_runtime_install_commands,
    runtime_container_env,
    build_service_apt_prefix,
    _first_boot_install
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
            import from jaclang.scale.injector.binary { host_arch }
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
    assert release_arch("Windows-ARM64") == "windows-arm64";
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


test "pack_overlay ships the host's compiled .jir as a re-homeable seed (#7138)" {
    import from jaclang.jac0core.jir { get_module_cache_path }
    import from jaclang.scale.injector.binary { JIR_SEED_SUBDIR }

    src_root = Path(tempfile.mkdtemp());
    (src_root / "jaclang").mkdir();
    src = src_root / "jaclang" / "x.jac";
    src.write_text("x = 1;");
    # Plant a fake host-side compiled cache exactly where the compiler would.
    cache = get_module_cache_path(str(src));
    cache.parent.mkdir(parents=True, exist_ok=True);
    cache.write_bytes(b"JIRC-fake");

    raw = pack_overlay(b"ELF", src_root);
    with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
        names = tar.getnames();
        manifest = tar.extractfile(
            f"{TOOLCHAIN_SUBDIR}/{JIR_SEED_SUBDIR}/_manifest.tsv"
        ).read().decode(
            "utf-8"
        );
    }
    assert f"{TOOLCHAIN_SUBDIR}/{JIR_SEED_SUBDIR}/jaclang/x.jac.jir" in names;
    # The pure-stdlib adoption script + its baked destination manifest ship
    # with the seeds (pods must not invoke jac before adoption - that compiles
    # the overlay eagerly, defeating the seeds).
    assert f"{TOOLCHAIN_SUBDIR}/{JIR_SEED_SUBDIR}/_adopt.py" in names;
    (seed_rel, dest_name) = manifest.strip().split("\t");
    assert seed_rel == "jaclang/x.jac.jir";
    # dest is the pod-side cache filename: stem.<8-hex path hash>.cpython-XY.jir
    import re;
    assert re.fullmatch(r"x\.[0-9a-f]{8}\.cpython-\d+\.jir", dest_name) , dest_name;
}


test "bootstrap adopts jir seeds before jac install (pods validate, not compile)" {
    cmds = build_runtime_install_commands(KubernetesConfig(), True);
    cmds.append(_first_boot_install());
    joined = " && ".join(cmds);
    assert "jir-seed/_adopt.py" in joined;
    # System python3 runs the adoption: any jac invocation before `jac install`
    # would itself eagerly compile the overlay, defeating the seeds.
    assert 'python3 "' in joined;
    # Adoption strictly precedes the install so its caches are seen.
    assert joined.index("_adopt.py") < joined.index("jac install");
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
