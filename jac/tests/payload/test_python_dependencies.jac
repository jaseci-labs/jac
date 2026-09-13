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
            dependencies, "interpreter_identity", return_value={"version": "test"}
        ), patch.object(dependencies.subprocess, "run", side_effect=run) {
            assert not dependencies.install_dependencies(
                "python", str(base / "first"), str(base / "cache")
            );
            assert dependencies.install_dependencies(
                "python", str(base / "second"), str(base / "cache")
            );
            assert len(installs) == 1;
            assert "--require-hashes" in installs[0];
            assert "--no-compile" in installs[0];
            assert "--only-binary=:all:" in installs[0];
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
        }
    }
}
