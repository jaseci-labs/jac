import os;
import socket;
import tempfile;
import time;

import from subprocess { Popen, DEVNULL, run }
import from playwright.sync_api { sync_playwright }

glob HEADLESS: bool = not os.environ.get("HEADED", ""),
     MONACO_TIMEOUT: int = 30_000,
     PYODIDE_TIMEOUT: int = 120_000,
     DOCS_DIR: str = os.path.abspath(
         os.path.join(os.path.dirname(__file__), "..", "..")
     ),
     SITE_DIR: str = os.path.join(DOCS_DIR, "site"),
     TEST_HTML: str = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Code Block Test Fixture</title>
    <link rel="stylesheet" href="/extra.css">
</head>
<body>
    <div class="code-block" id="block-plain">
with entry {
    x = 15;
    if 0 <= x <= 5 {
        print("Not Bad");
    } elif 6 <= x <= 10 {
        print("Average");
    } else {
        print("Good Enough");
    }
}
    </div>

    <div class="code-block run-dot" id="block-run-dot">
node City { has name: str; }
walker traveler {
    can roam with Root entry {
        here ++> City(name="Colombo");
        visit [-->];
    }
    can greet with City entry {
        print("Visiting " + here.name);
    }
}
with entry { traveler() spawn root; }
    </div>

    <div class="code-block" id="block-error">
with entry { this is invalid ||| }
    </div>

    <script src="https://unpkg.com/viz.js@2.1.2/viz.js"></script>
    <script src="https://unpkg.com/viz.js@2.1.2/full.render.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/requirejs@2.3.6/require.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.52.2/min/vs/loader.min.js"></script>
    <script src="/js/jac.monarch.js"></script>
    <script src="/js/run-code.js"></script>
</body>
</html>
""",
     SERVER_SCRIPT: str = """
import http.server, sys

class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=sys.argv[1], **kw)
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()
    def log_message(self, *_):
        pass

http.server.ThreadingHTTPServer(('127.0.0.1', int(sys.argv[2])), H).serve_forever()
""";

def _get_free_port -> int {
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    s.bind(("127.0.0.1", 0));
    port: int = s.getsockname()[1];
    s.close();
    return port;
}

def _wait_for_port(port: int, timeout: float = 10.0) -> None {
    deadline = time.time() + timeout;
    while time.time() < deadline {
        try {
            s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
            s.connect(("127.0.0.1", port));
            s.close();
            return;
        } except Exception {
            time.sleep(0.1);
        }
    }
}

def _start_server -> tuple {
    if not os.path.isdir(SITE_DIR) {
        run(["mkdocs", "build"], cwd=DOCS_DIR, check=True);
    }

    (fd, abs_path) = tempfile.mkstemp(
        dir=SITE_DIR, suffix=".html", prefix="_jac_test_"
    );

    try {
        fh = os.fdopen(fd, "w");
    } except Exception {
        os.close(fd);
        raise;
    }
    try {
        with fh as f {
            f.write(TEST_HTML);
        }
        page_path = "/" + os.path.basename(abs_path);
        port = _get_free_port();
        server = Popen(
            ["python", "-c", SERVER_SCRIPT, SITE_DIR, str(port)],
            stdout=DEVNULL,
            stderr=DEVNULL
        );
        _wait_for_port(port);
        return (server, f"http://127.0.0.1:{port}", page_path, abs_path);
    } except Exception {
        try {
            os.remove(abs_path);
        } except OSError {
            pass;
        }
        raise;
    }
}

def _stop_server(server: any, abs_path: str) {
    server.terminate();
    try {
        server.wait(timeout=5);
    } except Exception {
        server.kill();
    }
    try {
        os.remove(abs_path);
    } except OSError {
        pass;
    }
}

def _with_page(callback: any, wait_until: str = "domcontentloaded") {
    (server, base_url, page_path, abs_path) = _start_server();
    try {
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=HEADLESS);
            page = browser.new_page();
            try {
                resp = page.goto(f"{base_url}{page_path}", wait_until=wait_until);
                callback(page, resp);
            } finally {
                browser.close();
            }
        }
    } finally {
        _stop_server(server, abs_path);
    }
}

def _scroll_to(page: any, block_id: str) {
    page.wait_for_selector(block_id, state="attached", timeout=MONACO_TIMEOUT);
    page.evaluate(f"document.querySelector('{block_id}')?.scrollIntoView()");
}

def _click_run(page: any, block_id: str) {
    _scroll_to(page, block_id);
    selector = f"{block_id} .jcb-btn--run";
    page.wait_for_selector(selector, state="visible", timeout=MONACO_TIMEOUT);
    page.locator(selector).click();
}

def _click_graph(page: any, block_id: str) {
    _scroll_to(page, block_id);
    selector = f"{block_id} .jcb-btn--graph";
    page.wait_for_selector(selector, state="visible", timeout=MONACO_TIMEOUT);
    page.locator(selector).click();
}

test "rendering: plain block buttons" {
    def check(page: any, resp: any) {
        _scroll_to(page, "#block-plain");
        page.wait_for_selector(
            "#block-plain .jcb-btn--run", state="visible", timeout=MONACO_TIMEOUT
        );
        assert page.locator("#block-plain .jcb-btn--graph").is_hidden();
    }
    _with_page(check);
}

test "rendering: run-dot block buttons" {
    def check(page: any, resp: any) {
        _scroll_to(page, "#block-run-dot");
        page.wait_for_selector(
            "#block-run-dot .jcb-btn--run", state="visible", timeout=MONACO_TIMEOUT
        );
        assert page.locator("#block-run-dot .jcb-btn--graph").is_visible();
    }
    _with_page(check);
}

test "rendering: monaco editor with code" {
    def check(page: any, resp: any) {
        _scroll_to(page, "#block-plain");
        page.wait_for_selector(
            "#block-plain .monaco-editor", state="visible", timeout=MONACO_TIMEOUT
        );
        page.wait_for_function(
            "typeof monaco !== 'undefined' && "
            "monaco.editor.getModels().some(m => m.getValue().includes('Good Enough'))",
            timeout=MONACO_TIMEOUT
        );
        assert page.locator("#block-plain .jcb-output-wrap").is_hidden();
    }
    _with_page(check);
}

test "headers: cross-origin isolation" {
    def check(page: any, resp: any) {
        assert resp.headers.get("cross-origin-opener-policy") == "same-origin";
        assert resp.headers.get("cross-origin-embedder-policy") == "require-corp";
        assert page.evaluate("typeof SharedArrayBuffer !== 'undefined'");
    }
    _with_page(check);
}

test "execution: run produces output" {
    def check(page: any, resp: any) {
        _click_run(page, "#block-plain");
        page.wait_for_selector(
            "#block-plain .jcb-output-wrap", state="visible", timeout=PYODIDE_TIMEOUT
        );

        page.wait_for_function(
            "!document.querySelector('#block-plain').classList.contains('jcb-running')",
            timeout=PYODIDE_TIMEOUT
        );
        output = page.text_content("#block-plain .code-output");
        assert "Good Enough" in output , f"Expected 'Good Enough' in output, got: {output}";
    }
    _with_page(check);
}

test "execution: button disabled during run" {
    def check(page: any, resp: any) {
        _click_run(page, "#block-plain");
        page.wait_for_function(
            "document.querySelector('#block-plain .jcb-btn--run')?.disabled === true",
            timeout=5_000
        );
    }
    _with_page(check);
}

test "execution: syntax error shows error" {
    def check(page: any, resp: any) {
        _click_run(page, "#block-error");
        page.wait_for_function(
            "!document.querySelector('#block-error').classList.contains('jcb-running')",
            timeout=PYODIDE_TIMEOUT
        );
        output = page.text_content("#block-error .code-output");
        assert "error" in output.lower() , f"Expected 'error' in output, got: {output}";
    }
    _with_page(check);
}

test "execution: graph renders svg" {
    def check(page: any, resp: any) {
        _click_graph(page, "#block-run-dot");
        page.wait_for_selector(
            "#block-run-dot .graph-container", state="visible", timeout=PYODIDE_TIMEOUT
        );
        page.wait_for_selector(
            "#block-run-dot .graph-container .viz-viewport svg",
            state="visible",
            timeout=10_000
        );
    }
    _with_page(check);
}

test "execution: graph dot format" {
    def check(page: any, resp: any) {
        page.evaluate(
            "document.addEventListener('jacDotOutput', e => "
            "{ window.__capturedDot = e.detail.dot; })"
        );
        _click_graph(page, "#block-run-dot");
        page.wait_for_function(
            "window.__capturedDot !== undefined", timeout=PYODIDE_TIMEOUT
        );
        dot = page.evaluate("window.__capturedDot");
        assert "digraph" in dot , "DOT output must be a directed graph";
        assert "->" in dot , "DOT output must contain edges";
        assert "Colombo" in dot , "DOT output must contain City node data";
    }
    _with_page(check);
}
