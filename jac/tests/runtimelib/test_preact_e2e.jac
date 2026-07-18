"""E2E tests for the Preact framework backend (bundle + browser)."""

import os;
import re;
import shutil;
import socket;
import time;
import pytest;
import from pathlib { Path }
import from subprocess { Popen }
import from tempfile { TemporaryDirectory }

import from jaclang.project.config { JacConfig }
import from jaclang.runtimelib.testing { JacTestClient }

glob FIXTURES = str(Path(__file__).parent / "fixtures");

"""Skip unless the Vite/Bun client toolchain is available."""
def _require_client_integration {
    if not os.environ.get("JAC_CLIENT_INTEGRATION") {
        pytest.skip(
            "Preact E2E requires the Vite/Bun toolchain; "
            "set JAC_CLIENT_INTEGRATION=1 to run"
        );
    }
}

def _get_free_port -> int {
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s {
        s.bind(("", 0));
        s.listen(1);
        return s.getsockname()[1];
    }
}

def _wait_for_port(host: str, port: int, timeout: float = 120.0) -> None {
    deadline = time.time() + timeout;
    while time.time() < deadline {
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock {
            sock.settimeout(0.5);
            try {
                sock.connect((host, port));
                return;
            } except OSError {
                time.sleep(0.5);
            }
        }
    }
    raise TimeoutError(f"Timed out waiting for {host}:{port}");
}

"""Write a tiny project configured for framework = preact."""
def _write_preact_project(dest: Path) {
    dest.mkdir(parents=True, exist_ok=True);
    (dest / "jac.toml").write_text(
        '[project]\n'
        'name = "preact-e2e"\n'
        'entry-point = "main.jac"\n'
        '\n'
        '[client]\n'
        'framework = "preact"\n'
        '\n'
        '[dependencies.npm]\n'
        'preact = "^10.26.4"\n'
        'react-router-dom = "^6.22.0"\n'
        'react-error-boundary = "^5.0.0"\n'
        '\n'
        '[dev-dependencies.npm]\n'
        'vite = "^6.4.1"\n'
        '"@vitejs/plugin-react" = "^4.2.1"\n'
        'typescript = "^5.3.3"\n'
        '\n'
        '[client]\n',
        encoding="utf-8",
    );
    shutil.copy(Path(FIXTURES) / "preact_counter_app.jac", dest / "main.jac");
}

"""Start `jac start` for a temp preact project. Returns (process, port, url)."""
def _start_preact_server(project_dir: Path) -> tuple {
    import shutil as sh;
    import sys;
    jac_cmd = [sh.which("jac")]
        if sh.which("jac")
        else [sys.executable, "-m", "jaclang"];
    port = _get_free_port();
    env = os.environ.copy();
    repo_jac = str(Path(__file__).resolve().parents[2]);
    existing_path = env.get("PYTHONPATH", "");
    env["PYTHONPATH"] = (
        f"{repo_jac}{os.pathsep}{existing_path}" if existing_path else repo_jac
    );
    proc = Popen([*jac_cmd, "start", "-p", str(port)], cwd=str(project_dir), env=env,);
    _wait_for_port("127.0.0.1", port);
    # First client bundle can take a while (bun install + vite build).
    time.sleep(8);
    return (proc, port, f"http://127.0.0.1:{port}");
}

def _stop_server(proc: Popen) {
    proc.terminate();
    try {
        proc.wait(timeout=20);
    } except Exception {
        proc.kill();
        proc.wait(timeout=5);
    }
}

test "preact backend bundles client page with preact hooks" {
    _require_client_integration();
    with TemporaryDirectory() as tmpdir {
        project = Path(tmpdir) / "preact_bundle";
        _write_preact_project(project);
        client = JacTestClient.from_file(
            str(project / "main.jac"),
            base_path=str(project),
            module_name="main",
            config=JacConfig.load(project / "jac.toml"),
        );
        try {
            response = client.get("/cl/app");
            html = response.text;
            assert response.ok;
            assert "<!DOCTYPE html>" in html;
            assert "/static/client.js?hash=" in html;

            hash_match = re.search(r"/static/client\.js\?hash=([a-f0-9]+)", html);
            assert hash_match is not None;
            bundle = client.get(f"/static/client.js?hash={hash_match.group(1)}").text;
            assert bundle.strip();
            # Vite inlines dependencies, so assert on emitted/runtime shape
            # rather than bare import strings.
            assert "useState" in bundle;
            assert "Count:" in bundle;
            assert '"data-testid":"count"' in bundle;
            assert "createRoot" not in bundle;
            assert 'react-dom/client' not in bundle;
            compiled_dir = project / ".jac" / "client" / "compiled";
            entry_src = (compiled_dir / "_entry.js").read_text(encoding="utf-8");
            main_src = (compiled_dir / "main.js").read_text(encoding="utf-8");
            assert 'from "preact"' in entry_src;
            assert 'from "preact/hooks"' in main_src;
            assert 'from "react-dom/client"' not in entry_src;
            assert 'from "react-dom/client"' not in main_src;
        } finally {
            client.close();
        }
    }
}

test "preact counter increments in browser" {
    _require_client_integration();
    try {
        import from playwright.sync_api { sync_playwright }
    } except ImportError {
        pytest.skip("playwright not installed (pip install playwright)");
    }
    with TemporaryDirectory() as tmpdir {
        project = Path(tmpdir) / "preact_browser";
        _write_preact_project(project);
        started = _start_preact_server(project);
        proc = started[0];
        url = started[2];
        try {
            with sync_playwright() as p {
                browser = p.chromium.launch(headless=True);
                context = browser.new_context();
                page = context.new_page();
                try {
                    page.goto(f"{url}/cl/app", wait_until="load", timeout=120000);
                    page.wait_for_selector('[data-testid="count"]', timeout=60000);
                    assert "Count: 0" in page.locator(
                        '[data-testid="count"]'
                    ).inner_text();
                    page.locator('[data-testid="inc"]').click();
                    page.wait_for_function(
                        """() => {
                            const el = document.querySelector('[data-testid="count"]');
                            return el && el.textContent.includes('Count: 1');
                        }""",
                        timeout=15000,
                    );
                    assert "Count: 1" in page.locator(
                        '[data-testid="count"]'
                    ).inner_text();
                } finally {
                    context.close();
                    browser.close();
                }
            }
        } finally {
            _stop_server(proc);
        }
    }
}
