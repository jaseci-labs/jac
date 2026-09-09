import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.toolchains.android { AndroidEnvironment, compatible_jdk }
import from jaclang.toolchains.desktop { source_workspace }
import from jaclang.toolchains.cef { cef_artifact }
import from jaclang.toolchains.pins {
    JDK_ARTIFACTS,
    ANDROID_ARTIFACTS,
    PATCHELF_ARTIFACTS,
    RUBY_ARTIFACTS
}

test "every pinned artifact has a valid immutable identity" {
    for collection in [
        JDK_ARTIFACTS,
        ANDROID_ARTIFACTS,
        PATCHELF_ARTIFACTS,
        RUBY_ARTIFACTS
    ] {
        for artifact in collection.values() {
            assert artifact.key();
            assert artifact.url.startswith("https://");
            assert artifact.algorithm == "sha256";
        }
    }
}

test "native build environments do not mutate the shell" {
    with patch.dict(
        os.environ,
        {
            "JAVA_HOME": "/original-java",
            "ANDROID_HOME": "/original-sdk",
            "PATH": "/original-bin"
        }
    ) {
        env = AndroidEnvironment(Path("/managed-java"), Path("/managed-sdk")).env();
        assert env["JAVA_HOME"] == str(Path("/managed-java"));
        assert env["ANDROID_HOME"] == str(Path("/managed-sdk"));
        assert env["ANDROID_SDK_ROOT"] == env["ANDROID_HOME"];
        assert env["PATH"].endswith("/original-bin");
        assert os.environ["JAVA_HOME"] == "/original-java";
        assert os.environ["ANDROID_HOME"] == "/original-sdk";
        assert os.environ["PATH"] == "/original-bin";
    }
}

test "missing JDK is rejected without invoking subprocesses" {
    with TemporaryDirectory() as tmp {
        with patch("jaclang.toolchains.android.subprocess.run") as process {
            assert not compatible_jdk(Path(tmp));
            process.assert_not_called();
        }
    }
}

test "native source workspaces never write into installed package assets" {
    with TemporaryDirectory() as tmp {
        base = Path(tmp);
        source = base / "package";
        source.mkdir();
        (source / "binding.jac").write_text("glob value = 1;");
        with patch.dict(os.environ, {"JAC_TOOLCHAIN_DIR": str(base / "cache")}) {
            first = source_workspace(source, "binding");
            assert first != source;
            (first / ".native-build.lock").touch();
            assert source_workspace(source, "binding") == first;
            assert source_workspace(first, "binding") == first;
            assert (first / "binding.jac").read_text() == "glob value = 1;";
            assert sorted(p.name for p in source.iterdir()) == ["binding.jac"];
            (source / "binding.jac").write_text("glob value = 2;");
            second = source_workspace(source, "binding");
            assert second != first;
            assert (first / "binding.jac").read_text() == "glob value = 1;";
        }
    }
}

test "CEF refuses unsupported hosts instead of selecting Linux archives" {
    with TemporaryDirectory() as tmp {
        sums = Path(tmp) / "cef_sums.lock";
        sums.write_text("# version: 1.0\n");
        with patch(
            "jaclang.toolchains.cef.host_platform", return_value="mac-aarch64"
        ) {
            failed = False;
            try {
                cef_artifact(sums);
            } except RuntimeError as error {
                failed = "not supported" in str(error);
            }
            assert failed;
        }
    }
}


test "desktop package installation does not require system patchelf" {
    import from jaclang.toolchains.system { ensure_linux_desktop }
    with patch("jaclang.toolchains.host.host_platform", return_value="linux-x64") {
        with patch(
            "jaclang.toolchains.system.webkit_module",
            side_effect=["", "webkit2gtk-4.1"]
        ) {
            with patch(
                "jaclang.toolchains.system.shutil.which",
                side_effect=lambda (name: str) { "/usr/bin/g++"
                    if name == "g++"
                    else None; }
            ) {
                with patch(
                    "jaclang.toolchains.system.install_linux_packages"
                ) as installer {
                    ensure_linux_desktop();
                    installer.assert_called_once();
                }
            }
        }
    }
}
