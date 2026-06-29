import re;
import os;
import functools;
import from http.server { SimpleHTTPRequestHandler }
import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
import from jaclang.cli.console { console }

glob _MODULE_SCRIPT_RE = re.compile(
         r'<script type="module" src="([^"]*)"></script>'
     ),
     _STYLESHEET_LINK_RE = re.compile(r'<link rel="stylesheet" href="([^"]*)"\s*/?>');

def _asset_in_dist(dist_dir: Path, url: str) -> (Path | None) {
    name = os.path.basename(url.split("?", 1)[0]);
    if not name {
        return None;
    }
    candidate = dist_dir / name;
    return candidate if candidate.exists() else None;
}

def _strip_sourcemap_comment(js: str) -> str {
    return re.sub(r'\n?//# sourceMappingURL=\S+\s*$', '', js);
}

def _guard_closing_tag(text: str, tag: str) -> str {
    return text.replace(f'</{tag}', f'<\\/{tag}');
}

def _warn_if_split(dist_dir: Path) {
    chunks = [
        p
        for p in dist_dir.glob("*.js")
        if not p.name.endswith(".map") and p.name != "sw.js"
    ];
    if len(chunks) > 1 {
        console.warning(
            "  Multiple JS chunks detected (code-splitting); the inlined "
            "index.html may need an HTTP server rather than file:// for "
            "dynamically-imported chunks."
        );
    }
}

impl inline_dist_assets(dist_dir: Path) -> bool {
    index_path = dist_dir / "index.html";
    if not index_path.exists() {
        return False;
    }

    html = index_path.read_text(encoding="utf-8");
    changed = False;

    script_match = _MODULE_SCRIPT_RE.search(html);
    if script_match {
        js_file = _asset_in_dist(dist_dir, script_match.group(1));
        if js_file {
            js = _strip_sourcemap_comment(js_file.read_text(encoding="utf-8"));
            js = _guard_closing_tag(js, "script");
            inline_script = f'<script type="module">\n{js}\n</script>';
            html = html.replace(script_match.group(0), inline_script, 1);
            changed = True;
        }
    }

    link_match = _STYLESHEET_LINK_RE.search(html);
    if link_match {
        css_file = _asset_in_dist(dist_dir, link_match.group(1));
        if css_file {
            css = css_file.read_text(encoding="utf-8");
            css = _guard_closing_tag(css, "style");
            inline_style = f'<style>\n{css}\n</style>';
            html = html.replace(link_match.group(0), inline_style, 1);
            changed = True;
        }
    }

    if changed {
        index_path.write_text(html, encoding="utf-8");
        _warn_if_split(dist_dir);
    }
    return changed;
}

class _DistRequestHandler(SimpleHTTPRequestHandler) {
    def translate_path(self: _DistRequestHandler, path: str) -> str {
        if path.startswith("/static/") {
            path = path[len("/static"):];
        }
        return super.translate_path(path);
    }

    def guess_type(self: _DistRequestHandler, path: str) -> str {
        if str(path).endswith(".wasm") {
            return "application/wasm";
        }
        return super.guess_type(path);
    }
}

impl serve_static_dir(dist_dir: Path, host: str, port: int) -> None {
    import from http.server { ThreadingHTTPServer }

    handler = functools.partial(_DistRequestHandler, directory=str(dist_dir));
    httpd = ThreadingHTTPServer((host, port), handler);
    shown_host = "localhost" if host in ("", "0.0.0.0", "127.0.0.1") else host;
    console.print(
        f"\n🚀 Serving client-only app at http://{shown_host}:{port}/",
        style="bold green"
    );
    console.print("  Press Ctrl+C to stop\n", style="muted");
    try {
        httpd.serve_forever();
    } except KeyboardInterrupt {
        console.print("\n  Stopping server...", style="muted");
    } finally {
        httpd.shutdown();
        httpd.server_close();
    }
}

impl StaticTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    console.print("\n🌐 Building client-only (static) target", style="bold");

    bundle_path = super.build(entry_file, project_dir, platform);
    bundler = ViteBundler(project_dir=project_dir);
    dist_dir = bundler.output_dir;
    if inline_dist_assets(dist_dir) {
        console.print(
            "  ✔ Inlined bundle into a portable index.html (opens from file://)",
            style="success"
        );
    }
    console.print("\n✅ Client-only build complete!", style="bold green");
    console.print(f"  Output: {dist_dir}", style="muted");
    return bundle_path;
}

impl StaticTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    self.build(entry_file, project_dir, None);
    bundler = ViteBundler(project_dir=project_dir);
    dist_dir = bundler.output_dir;
    if not dist_dir or not dist_dir.exists() {
        raise RuntimeError(f"Build output not found: {dist_dir}");
    }
    serve_static_dir(dist_dir, "127.0.0.1", api_port);
}
