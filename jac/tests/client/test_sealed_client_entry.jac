"""A sealed web app boots when its entry holds only client code (#10307).

An entry may render the client and reach its server modules through client
components, or the app may have no server modules at all. Both run under
`jac run --dev`, so the sealed image has to serve them too."""

import os;
import shutil;
import signal;
import socket;
import subprocess;
import tempfile;
import time;
import from pathlib { Path }
import from jaclang.scale.runtime.context.util { jac_executable }

"""Create a web app named `name` under `parent` and return its directory."""
def _create_web_app(parent: Path, name: str) -> Path {
    created = subprocess.run(
        [jac_executable(), "create", "--kind", "web-app", name],
        cwd=parent,
        capture_output=True,
        text=True,
        timeout=300
    );
    assert created.returncode == 0 , created.stdout + created.stderr;
    return parent / name;
}

def _free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock {
        sock.bind(("127.0.0.1", 0));
        return sock.getsockname()[1];
    }
}

"""Seal `project` into `out`, boot the image with `jac run --no-dev`, and return
the server's output once it is ready or has exited."""
def _seal_and_boot(project: Path, out: Path) -> str {
    executable = jac_executable();
    sealed = subprocess.run(
        [executable, "build", "--as", "sealed", "-o", str(out), "main.jac"],
        cwd=project,
        capture_output=True,
        text=True,
        timeout=900
    );
    assert sealed.returncode == 0 , sealed.stdout[-2000:] + sealed.stderr[-2000:];
    image = out / f"{project.name}-sealed";
    log = out / "server.log";
    with log.open("w") as stream {
        process = subprocess.Popen(
            [
                executable,
                "run",
                "--no-dev",
                "--workers",
                "1",
                "--port",
                str(_free_port()),
                "--api-port",
                str(_free_port()),
                "main.jac"
            ],
            cwd=image,
            stdout=stream,
            stderr=subprocess.STDOUT,
            start_new_session=os.name != "nt"
        );
    }
    try {
        deadline = time.monotonic() + 300;
        while time.monotonic() < deadline {
            exited = process.poll() is not None;
            output = log.read_text(errors="replace");
            if exited or "Server ready" in output {
                return output;
            }
            time.sleep(0.1);
        }
        return log.read_text(errors="replace");
    } finally {
        if os.name != "nt" {
            try {
                os.killpg(process.pid, int(signal.SIGINT));
            } except ProcessLookupError {}
        } else {
            process.send_signal(signal.SIGINT);
        }
        try {
            process.`wait(timeout=45);
        } except subprocess.TimeoutExpired {
            if os.name != "nt" {
                try {
                    os.killpg(process.pid, int(signal.SIGKILL));
                } except ProcessLookupError {}
            } else {
                process.kill();
            }
            process.`wait();
        }
    }
}

test "a sealed web app boots when only a client component imports its endpoints" {
    with tempfile.TemporaryDirectory() as temp_dir {
        project = _create_web_app(Path(temp_dir), "client-entry");
        main = project / "main.jac";
        source = main.read_text();
        endpoints_import = "import from endpoints { Message, PostMessage, ListMessages }\n";
        assert endpoints_import in source , source;
        main.write_text(source.replace(endpoints_import, ""));
        output = _seal_and_boot(project, Path(temp_dir) / "out");
        assert "Server ready" in output , output;
    }
}

test "a sealed web app with no server code boots" {
    with tempfile.TemporaryDirectory() as temp_dir {
        project = _create_web_app(Path(temp_dir), "client-only");
        for name in ["endpoints.jac", "frontend.jac", "frontend.impl.jac"] {
            (project / name).unlink();
        }
        shutil.rmtree(project / "components");
        (project / "main.jac").write_text(
            "def:pub app -> JsxElement {\n    <div>sealed</div>\n}\n"
        );
        output = _seal_and_boot(project, Path(temp_dir) / "out");
        assert "Server ready" in output , output;
    }
}
