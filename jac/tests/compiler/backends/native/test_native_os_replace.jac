"""Atomic replacement must have identical observable effects in both backends."""
import os;
import subprocess;
import tempfile;
import from pathlib { Path }
import from tests.support { jac_command }

test "native os replace preserves replacement and error semantics" {
    fixture = str(Path(__file__).resolve().parent / "fixtures" / "os_replace.jac");
    with tempfile.TemporaryDirectory() as directory {
        binary = os.path.join(directory, "replace.bin");
        build = subprocess.run(
            jac_command("build", "--native", fixture, "-o", binary),
            capture_output=True,
            text=True,
            timeout=900
        );
        assert build.returncode == 0 , build.stdout + build.stderr;
        os.mkdir(os.path.join(directory, "src-dir"));
        os.mkdir(os.path.join(directory, "dst-dir"));
        src_fd = os.open(os.path.join(directory, "src-dir"), os.O_RDONLY);
        dst_fd = os.open(os.path.join(directory, "dst-dir"), os.O_RDONLY);
        env = dict(os.environ);
        env["REPLACE_SOURCE_FD"] = str(src_fd);
        env["REPLACE_TARGET_FD"] = str(dst_fd);
        try {
            native = subprocess.run(
                [binary],
                cwd=directory,
                env=env,
                pass_fds=(src_fd, dst_fd),
                capture_output=True,
                text=True,
                timeout=60
            );
            server = subprocess.run(
                jac_command("run", "--backend", "python", fixture),
                cwd=directory,
                env=env,
                pass_fds=(src_fd, dst_fd),
                capture_output=True,
                text=True,
                timeout=900
            );
        } finally {
            os.close(src_fd);
            os.close(dst_fd);
        }
        assert native.returncode == 0 , native.stdout + native.stderr;
        assert server.returncode == 0 , server.stdout + server.stderr;
        assert "replace success and errors pass" in native.stdout;
        assert "replace success and errors pass" in server.stdout;
    }
}

test "unsupported native os calls cannot silently disappear" {
    for code in [
        "import os; with entry { os.fsync(1); }",
        "import os as files; with entry { files.fsync(1); }",
        "import from os { fsync as sync }; with entry { sync(1); }"
    ] {
        with tempfile.TemporaryDirectory() as directory {
            source = os.path.join(directory, "unsupported.jac");
            Path(source).write_text(code);
            build = subprocess.run(
                jac_command(
                    "build",
                    "--native",
                    source,
                    "-o",
                    os.path.join(directory, "bad.bin")
                ),
                capture_output=True,
                text=True,
                timeout=900
            );
            assert build.returncode != 0 , "unsupported fsync was silently accepted";
            assert "fsync" in build.stdout + build.stderr;
        }
    }
}
