"""Production client builds finish before initialization and can recover on retry."""

import os;
import socket;
import subprocess;
import time;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

test "a failed production client build prevents initialization and a corrected run succeeds" {
    import from jaclang.testing.requires { require_tool }
    import from jaclang.scale.runtime.context.util { jac_executable }
    import from urllib.request { urlopen }
    require_tool('bun');
    with TemporaryDirectory(prefix='jac-bundle-preparation-') as tmp {
        project = Path(tmp);
        (project / 'jac.toml').write_text(
            '[project]\nname="bundleretry"\nkind="web-app"\nentry-point="main"\n'
        );
        source = project / 'main.jac';
        source.write_text(
            'import from pathlib { Path }\n'
                + 'with entry { Path("initialized").write_text("yes"); }\n'
                + 'import from "totally-not-a-real-package-7998" { boom }\n'
                + 'def:pub app -> JsxElement { return <div>{boom()}</div>; }\n'
        );
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock {
            sock.bind(('127.0.0.1', 0));
            port = sock.getsockname()[1];
        }
        command = [jac_executable(), 'run', '--no-dev', '--port', str(port)];
        failed = subprocess.run(
            command, cwd=tmp, capture_output=True, text=True, timeout=300
        );
        assert failed.returncode != 0;
        assert 'Preparing application' in failed.stdout;
        assert not (project / 'initialized').exists();
        assert 'Initializing application' not in failed.stdout;
        assert 'totally-not-a-real-package-7998' in failed.stdout + failed.stderr;
        source.write_text(
            'import from pathlib { Path }\n'
                + 'with entry { Path("initialized").write_text("yes"); }\n'
                + 'def:pub app -> JsxElement { return <div>recovered</div>; }\n'
        );
        log = project / 'server.log';
        with log.open('w') as output {
            server = subprocess.Popen(
                command, cwd=tmp, stdout=output, stderr=subprocess.STDOUT
            );
        }
        try {
            ready = False;
            deadline = time.monotonic() + 300;
            while time.monotonic() < deadline {
                assert server.poll() is None , log.read_text(errors='replace');
                try {
                    with urlopen(f'http://127.0.0.1:{port}/', timeout=2) as response {
                        ready = response.status == 200;
                    }
                    if ready {
                        break;
                    }
                } except OSError {
                    time.sleep(0.5);
                }
            }
            assert ready , log.read_text(errors='replace');
            assert (project / 'initialized').read_text() == 'yes';
        } finally {
            server.terminate();
            try {
                server.`wait(timeout=15);
            } except subprocess.TimeoutExpired {
                server.kill();
                server.`wait();
            }
        }
    }
}
