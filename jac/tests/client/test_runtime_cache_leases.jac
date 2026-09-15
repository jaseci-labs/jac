import hashlib;
import io;
import os;
import select;
import subprocess;
import sys;
import tarfile;
import time;
import from compression.zstd { compress }
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import jaclang.client.targets.desktop.desktop_build as desktop;
import from jaclang.dist.fused.trailer { MAGIC, build_trailer }
import from tests.support { JAC_ROOT }

def _payload(marker: str) -> bytes {
    stream = io.BytesIO();
    with tarfile.open(fileobj=stream, mode="w") as archive {
        data = marker.encode();
        info = tarfile.TarInfo("marker");
        info.size = len(data);
        archive.addfile(info, io.BytesIO(data));
    }
    return compress(stream.getvalue());
}

def _generation(binary: Path, stub: bytes, marker: str) {
    payload = _payload(marker);
    replacement = binary.with_suffix(".new");
    replacement.write_bytes(
        stub
            + payload
            + build_trailer(MAGIC, len(payload), hashlib.sha256(payload).hexdigest())
    );
    replacement.chmod(0o755);
    os.replace(replacement, binary);
}

test "runtime upgrades retain live generations and collect them after exit" {
    with TemporaryDirectory() as directory {
        work_dir = Path(directory);
        with patch.object(
            desktop,
            "_fused_runtime_dir",
            return_value=Path(JAC_ROOT) / "jaclang" / "dist" / "fused"
        ) {
            desktop._stage_fused_runtime(work_dir);
        }
        source = work_dir / "host.jac";
        source.write_text(
            "import sys;\n"
            "import from fused.materialize { materialize }\n"
            "import from _exec_native { executable_path }\n"
            "import from c { def getchar -> i32; def fflush(stream: int) -> i32; }\n"
            "with entry { print(\"LEASE_READY:\" + materialize(executable_path())); fflush(0); "
            "if len(sys.argv) > 1 { getchar(); } }\n"
        );
        binary = work_dir / "host";
        built = subprocess.run(
            [sys.executable, "build", "--native", str(source), "-o", str(binary)],
            capture_output=True,
            text=True,
            timeout=300
        );
        assert built.returncode == 0 , built.stdout + built.stderr;
        stub = binary.read_bytes();
        _generation(binary, stub, "first");
        env = dict(os.environ, XDG_CACHE_HOME=str(work_dir / "cache"));
        first = subprocess.Popen(
            [str(binary), "hold"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            env=env
        );
        try {
            assert first.stdout is not None;
            observed = b"";
            ready_path = "";
            deadline = time.monotonic() + 60;
            while not ready_path {
                remaining = deadline - time.monotonic();
                assert remaining > 0;
                assert select.select([first.stdout], [], [], remaining)[0] , "host did not become ready";
                chunk = os.read(first.stdout.fileno(), 4096);
                assert chunk , "host exited before publishing its runtime path";
                observed += chunk;
                for line in observed.splitlines() {
                    if line.startswith(b"LEASE_READY:") and observed.endswith(b"\n") {
                        ready_path = line.decode().removeprefix("LEASE_READY:");
                    }
                }
            }
            first_runtime = Path(ready_path);
            assert (first_runtime / "marker").read_text() == "first";
            _generation(binary, stub, "second");
            second = subprocess.run(
                [str(binary)], capture_output=True, text=True, env=env, timeout=60
            );
            assert second.returncode == 0 , second.stderr;
            assert (
                Path(second.stdout.splitlines()[-1].removeprefix("LEASE_READY:"))
                / "marker"
            ).read_text()
                == "second";
            assert (first_runtime / "marker").read_text() == "first";
            first.communicate(input="\n", timeout=30);
            assert first.returncode == 0;
            _generation(binary, stub, "third");
            third = subprocess.run(
                [str(binary)], capture_output=True, text=True, env=env, timeout=60
            );
            assert third.returncode == 0 , third.stderr;
            assert not first_runtime.exists();
        } finally {
            if first.poll() is None {
                first.kill();
                first.communicate(timeout=30);
            }
        }
    }
}
