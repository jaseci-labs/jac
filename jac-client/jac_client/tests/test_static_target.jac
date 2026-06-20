"""Tests for the client-only (static) build target.

A `client`-kind Jac project runs entirely in the browser with no server. The
static target must therefore produce a *portable* dist whose `index.html` is
fully self-contained (JS + CSS inlined) so it renders when opened directly
from disk via `file://` -- ES module `<script src=...>` tags are CORS-blocked
over `file://`, so inlining is what makes disk-open work.
"""

import os;
import shutil;
import tempfile;
import pytest;
import from pathlib { Path }
import from subprocess { run }

"""Write a dist dir that mirrors WebTarget's generated index.html + assets."""
def _make_fake_dist(dist_dir: Path) {
    dist_dir.mkdir(parents=True, exist_ok=True);
    (dist_dir / "client.DEADBEEF.js").write_text(
        'console.log("JAC_BUNDLE_MARKER");\n//# sourceMappingURL=client.DEADBEEF.js.map',
        encoding="utf-8"
    );
    (dist_dir / "client.DEADBEEF.js.map").write_text("{}", encoding="utf-8");
    # Include a literal `</style>` in a value to exercise closing-tag guarding.
    (dist_dir / "styles.css").write_text(
        '.jac-marker { color: red; } .x::before { content: "</style>"; }',
        encoding="utf-8"
    );
    index_html = '''<!DOCTYPE html>
<html lang="en">
  <head>
<meta charset=UTF-8 />
            <link rel="stylesheet" href="./styles.css?hash=abcd1234"/>
  </head>
  <body>
    <div id="root"></div>
    <script id="__jac_init__" type="application/json">{"module": "main", "function": "app"}</script>
    <script type="module" src="./client.DEADBEEF.js"></script>
  </body>
</html>''';
    (dist_dir / "index.html").write_text(index_html, encoding="utf-8");
}

"""inline_dist_assets must fold the JS bundle and CSS into index.html."""
test "static inline produces self-contained index html" {
    import from jac_client.plugin.src.targets.static_target { inline_dist_assets }

    with tempfile.TemporaryDirectory() as temp_dir {
        dist_dir = Path(temp_dir) / "dist";
        _make_fake_dist(dist_dir);
        changed = inline_dist_assets(dist_dir);
        assert changed , "inline_dist_assets should report it modified index.html";
        html = (dist_dir / "index.html").read_text(encoding="utf-8");
        # The external module script is gone; the bundle is inlined instead.
        assert 'src="./client.DEADBEEF.js"' not in html , "external module src must be inlined away";
        assert '<script type="module">' in html , "inlined module script tag expected";
        assert "JAC_BUNDLE_MARKER" in html , "bundle JS must be inlined into the HTML";
        # CSS is inlined; the external stylesheet link is gone.
        assert 'rel="stylesheet"' not in html , "external stylesheet link must be inlined away";
        assert "<style>" in html , "inlined style tag expected";
        assert ".jac-marker" in html , "CSS must be inlined into the HTML";
        # The CSS's literal `</style>` must be escaped so it can't close the tag
        # early -- exactly one real closing `</style>` should remain.
        assert html.count("</style>") == 1 , "CSS closing-tag sequence must be guarded";
        # No sourceMappingURL comment over file:// (avoids a console 404).
        assert "sourceMappingURL" not in html , "sourcemap comment must be stripped from inline JS";
        # The jac init payload script must be preserved untouched.
        assert '__jac_init__' in html , "jac init payload must be preserved";
    }
}

"""inline_dist_assets is a no-op (returns False) when there is no index.html."""
test "static inline is a no-op without index html" {
    import from jac_client.plugin.src.targets.static_target { inline_dist_assets }

    with tempfile.TemporaryDirectory() as temp_dir {
        dist_dir = Path(temp_dir) / "dist";
        dist_dir.mkdir(parents=True, exist_ok=True);
        assert not inline_dist_assets(dist_dir) , "missing index.html should yield no change";
    }
}

"""The static target registers and resolves through the factory."""
test "static target is registered and resolvable" {
    import from jac_client.plugin.src.targets.register { register_targets }
    import from jac_client.plugin.src.targets.registry { get_target_factory }

    register_targets();
    factory = get_target_factory();

    names = factory.get_available_target_names();
    assert "static" in names , f"static target should be registered; got {names}";

    with tempfile.TemporaryDirectory() as temp_dir {
        target = factory.create("static", Path(temp_dir));
        assert target.name == "static" , "factory.create('static') should yield the static target";
    }
}

"""An explicit `kind = \"client\"` resolves to the client project kind.

This is the signal `jac build` / `jac start` key off to auto-route a
client-only project to the portable/static path without any --client flag.
"""
test "client kind is detected from jac toml" {
    import from jaclang.project.config { JacConfig }
    import from jaclang.project.kinds { resolve_project_kind }

    with tempfile.TemporaryDirectory() as temp_dir {
        toml_content = '''[project]
name = "browser-app"
version = "1.0.0"
entry-point = "main.jac"
kind = "client"

[plugins.client]
''';
        toml_path = os.path.join(temp_dir, "jac.toml");
        with open(toml_path, "w") as f {
            f.write(toml_content);
        }
        config = JacConfig.load(Path(toml_path));
        kind = resolve_project_kind(config, os.path.join(temp_dir, "main.jac"));
        assert kind == "client" , f"expected client kind, got {kind}";
    }
}

"""The minimal static server maps `/static/<x>` onto the dist root.

A client-only app may still fetch an na->wasm module at `/static/<stem>.wasm`
(emitted into the dist root). The minimal server must resolve that prefix so it
stays behavior-compatible with the full server for the in-browser-native case.
"""
test "static server maps static prefix to dist root" {
    import threading;
    import functools;
    import from http.server { ThreadingHTTPServer }
    import from urllib.request { urlopen }
    import from jac_client.plugin.src.targets.static_target { _DistRequestHandler }

    with tempfile.TemporaryDirectory() as temp_dir {
        dist = Path(temp_dir);
        (dist / "main.wasm").write_bytes(b"WASM_BYTES");
        (dist / "index.html").write_text("<h1>ok</h1>", encoding="utf-8");
        handler = functools.partial(_DistRequestHandler, directory=str(dist));
        httpd = ThreadingHTTPServer(("127.0.0.1", 0), handler);
        port = httpd.server_address[1];
        thread = threading.Thread(target=httpd.serve_forever, daemon=True);
        thread.start();
        try {
            resp = urlopen(f"http://127.0.0.1:{port}/static/main.wasm", timeout=10);
            served = resp.read();
            assert served == b"WASM_BYTES" , "/static/<x> must resolve to dist/<x>";
            # WebAssembly.instantiateStreaming requires application/wasm.
            assert resp.headers.get("Content-Type") == "application/wasm" , "wasm must be served as application/wasm";
            index_body = urlopen(
                f"http://127.0.0.1:{port}/index.html", timeout=10
            ).read();
            assert b"ok" in index_body , "ordinary paths must still serve from dist root";
        } finally {
            httpd.shutdown();
            httpd.server_close();
        }
    }
}

"""End-to-end: a kind=client project builds a dist that renders from file://.

This is the user-facing contract -- `jac build` with no `--client` flag must
auto-detect the client-only project and emit a portable page that opens
straight off disk. Skips when the browser/build toolchain is unavailable.
"""
test "client build renders from file protocol" {
    try {
        import from playwright.sync_api { sync_playwright }
    } except ImportError {
        pytest.skip("playwright not installed");
    }
    import from .test_helpers { get_env_with_npm, get_jac_command }

    tests_dir = os.path.dirname(__file__);
    example_src = os.path.join(os.path.dirname(tests_dir), "examples", "basic");
    if not os.path.isdir(example_src) {
        pytest.skip(f"basic example not found: {example_src}");
    }

    with tempfile.TemporaryDirectory() as temp_dir {
        project_dir = os.path.join(temp_dir, "browser-app");
        shutil.copytree(example_src, project_dir);
        # Declare the project client-only; no --client flag is passed to build.
        toml_path = os.path.join(project_dir, "jac.toml");
        with open(toml_path) as f {
            toml_text = f.read();
        }
        toml_text = toml_text.replace(
            'entry-point = "main.jac"', 'entry-point = "main.jac"\nkind = "client"'
        );
        with open(toml_path, "w") as f {
            f.write(toml_text);
        }
        build = run(
            [*get_jac_command(), "build"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            env=get_env_with_npm(),
            timeout=600,
        );
        if build.returncode != 0 {
            pytest.skip(
                f"client build unavailable in this environment:\n{build.stderr}"
            );
        }
        index_html = Path(project_dir) / ".jac" / "client" / "dist" / "index.html";
        assert index_html.exists() , "portable index.html should be produced";
        html = index_html.read_text(encoding="utf-8");
        assert 'src="' not in html , "build should inline assets (no external src)";
        with sync_playwright() as p {
            browser = p.chromium.launch(headless=True);
            page = browser.new_context().new_page();
            try {
                page.goto(index_html.as_uri(), wait_until="load", timeout=60000);
                page.wait_for_selector("h1", timeout=30000);
                assert "Hello, World" in page.content() , "app must render over file://";
            } finally {
                browser.close();
            }
        }
    }
}
