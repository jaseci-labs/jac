import os;
import io;
import tarfile;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
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
    # host_repo_root must land on a checkout we can host-build from - one whose
    # jac/build.zig exists - rather than tracking the running module's __file__,
    # which is in the bundled runtime cache (not the checkout) under the jac
    # binary. The CI runner runs the suite with the checkout as cwd, so the
    # build.zig marker is found there.
    repo_root = Path(str(host_repo_root()));
    assert (repo_root / "jac" / "build.zig").is_file();
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


test "host_repo_root prefers JAC_REPO_ROOT, then the jac/build.zig marker" {
    # The --experimental host build resolves the source checkout from here. Under
    # the jac binary, __file__ lives in the runtime cache (not the checkout), so a
    # fixed __file__-relative guess mis-resolves; an explicit override and an
    # upward search for jac/build.zig must win instead.
    with tempfile.TemporaryDirectory() as d {
        repo = Path(d).resolve();
        (repo / "jac").mkdir();
        (repo / "jac" / "build.zig").write_text("");
        nested = repo / "a" / "b";
        nested.mkdir(parents=True);
        # explicit override wins
        with patch.dict(os.environ, {"JAC_REPO_ROOT": str(repo)}) {
            assert host_repo_root() == repo;
        }
        # with no override, the upward search from cwd finds the build.zig marker
        old_cwd = os.getcwd();
        saved = os.environ.pop("JAC_REPO_ROOT", None);
        try {
            os.chdir(str(nested));
            assert host_repo_root() == repo;
        } finally {
            os.chdir(old_cwd);
            if saved is not None {
                os.environ["JAC_REPO_ROOT"] = saved;
            }
        }
    }
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
