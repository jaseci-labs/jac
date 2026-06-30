import os;
import io;
import tarfile;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.injector.binary { pack_toolchain, host_repo_root }
import from jaclang.scale.injector.binary_injector { BinaryInjector }
import from jaclang.scale.injector.bundle { TOOLCHAIN_SUBDIR }
import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
    build_runtime_install_commands
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}


test "host_repo_root resolves to the buildable jac source tree" {
    # The repo root must be the jaclang package dir's grandparent; a wrong
    # parent count makes host_repo_root land on <root>/jac instead.
    import jaclang;
    repo_root = Path(str(host_repo_root()));
    pkg = Path(str(jaclang.__file__)).resolve().parent;
    assert repo_root == pkg.parent.parent;
    if (repo_root / "jac").is_dir() {
        assert (repo_root / "jac" / "build.zig").is_file();
    }
}


test "ship_binary bootstrap installs the shipped binary, never builds in-pod" {
    cmds = build_runtime_install_commands(KubernetesConfig(), False, True);
    joined = " && ".join(cmds);

    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in joined;
    assert "jac install -e" in joined;
    assert "jac-scale" in joined;

    assert "zig build" not in joined;
    assert "git clone" not in joined;
    assert "build-essential" not in joined;
    assert "install.sh" not in joined;
}


test "experimental still builds in-pod (ship_binary defaults off, no regression)" {
    cmds = build_runtime_install_commands(KubernetesConfig(), True);
    joined = " && ".join(cmds);
    assert "zig build" in joined;
    assert f"{TOOLCHAIN_SUBDIR}/bin/jac" not in joined;
}


test "pack_toolchain ships the binary + plugin source, drops build artifacts" {
    with tempfile.TemporaryDirectory() as repo {
        os.makedirs(os.path.join(repo, "jac", ".ship-out", "bin"));
        binary = os.path.join(repo, "jac", ".ship-out", "bin", "jac");
        with open(binary, "wb") as handle {
            handle.write(b"ELF-binary");
        }
        os.makedirs(os.path.join(repo, "jac-scale", "jaclang.scale"));
        with open(
            os.path.join(repo, "jac-scale", "jaclang.scale", "x.py"), "w"
        ) as handle {
            handle.write("x = 1");
        }
        with open(os.path.join(repo, "jac-scale", "jac.toml"), "w") as handle {
            handle.write("[project]\nname = \"jac-scale\"\n");
        }
        os.makedirs(os.path.join(repo, "jac-scale", "node_modules"));
        with open(
            os.path.join(repo, "jac-scale", "node_modules", "junk.js"), "w"
        ) as handle {
            handle.write("junk");
        }
        raw = pack_toolchain(Path(repo), Path(binary));
        names: list[str] = [];
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r:gz") as tar {
            names = tar.getnames();
        }
        assert f"{TOOLCHAIN_SUBDIR}/bin/jac" in names;
        assert f"{TOOLCHAIN_SUBDIR}/jac-scale/jaclang.scale/x.py" in names;
        assert f"{TOOLCHAIN_SUBDIR}/jac-scale/jac.toml" in names;
        assert not any(["node_modules" in name for name in names]);
    }
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
