import subprocess;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.dist.payload.python_dependencies as dependencies;

test "pinned dependency installs reuse validated products and omit temporary script paths" {
    with TemporaryDirectory() as directory {
        base = Path(directory);
        installs: list[list[str]] = [];
        def run(argv: list[str], **kwargs: any) -> subprocess.CompletedProcess {
            if "--target" in argv {
                assert kwargs["env"]["SOURCE_DATE_EPOCH"] == "0";
                assert kwargs["env"]["CFLAGS"].endswith(" -g0");
                installs.append(argv);
                target = Path(argv[argv.index("--target") + 1]);
                (target / "bin").mkdir(parents=True);
                (target / "example.dist-info").mkdir();
                (target / "example.py").write_text("answer = 42\n");
                (target / "bin/example").write_text(str(target));
                (target / "example.dist-info/RECORD").write_text(
                    "example.py,,\nbin/example,temporary-script-hash,100\nexample.dist-info/RECORD,,\n"
                );
            }
            return subprocess.CompletedProcess(argv, 0, stdout="installer-hash\n");
        }
        with patch.object(
            dependencies,
            "interpreter_identity",
            return_value={"version": "test", "platform": "macosx-test"}
        ), patch.object(
            dependencies,
            "interpreter_build_identity",
            return_value={"compiler_version": "first", "sdk_version": "one"}
        ) as build_inputs, patch.object(
            dependencies.subprocess, "run", side_effect=run
        ) {
            assert not dependencies.install_dependencies(
                "python", str(base / "first"), str(base / "cache")
            );
            assert dependencies.install_dependencies(
                "python", str(base / "second"), str(base / "cache")
            );
            assert len(installs) == 1;
            assert "--require-hashes" in installs[0];
            assert "--no-compile" in installs[0];
            assert "--only-binary=pip,tomlkit,setuptools,wheel" in installs[0];
            assert "--build-constraint" in installs[0];
            assert "--no-cache-dir" in installs[0];
            assert (base / "second/example.py").read_text() == "answer = 42\n";
            assert not (base / "second/bin").exists();
            assert "bin/example"
                not in (base / "second/example.dist-info/RECORD").read_text();
            assert not dependencies.install_dependencies(
                "python", str(base / "third"), str(base / "other-cache")
            );
            first = next((base / "cache").rglob("dependencies.tar")).read_bytes();
            second = next(
                (base / "other-cache").rglob("dependencies.tar")
            ).read_bytes();
            assert first == second;
            next((base / "cache").rglob("dependencies.tar")).write_bytes(b"corrupt");
            assert not dependencies.install_dependencies(
                "python", str(base / "fourth"), str(base / "cache")
            );
            assert len(installs) == 3;
            build_inputs.return_value = {
                "compiler_version": "second",
                "sdk_version": "two"
            };
            assert not dependencies.install_dependencies(
                "python", str(base / "fifth"), str(base / "cache")
            );
            assert len(installs) == 4;
        }
    }
}
