"""Implementation of StaticTarget (client-only) methods."""
import re;
import os;
import functools;
import from http.server { SimpleHTTPRequestHandler }
import from pathlib { Path }
import from typing { Optional }
import from jaclang.runtimelib.client.vite_bundler { ViteBundler }
import from jaclang.cli.console { console }

# index.html tags emitted by WebTarget._generate_index_html that we fold inline.
# The capture group is the asset URL (possibly base-prefixed and ?hash=...).
glob _MODULE_SCRIPT_RE = re.compile(
         r'<script type="module" src="([^"]*)"></script>'
     ),
     _STYLESHEET_LINK_RE = re.compile(r'<link rel="stylesheet" href="([^"]*)"\s*/?>');

"""Resolve an index.html asset URL to a file inside the dist dir.

Strips any base prefix and `?hash=` query, then anchors the bare filename in
`dist_dir`. Returns None when the file is absent.
"""
def _asset_in_dist(dist_dir: Path, url: str) -> (Path | None) {
    name = os.path.basename(url.split("?", 1)[0]);
    if not name {
        return None;
    }
    candidate = dist_dir / name;
    return candidate if candidate.exists() else None;
}

"""Strip a trailing `//# sourceMappingURL=...` comment from bundle JS.

Over `file://` the browser would 404 on the map; the on-disk `.js.map` is left
untouched so source maps still work when the dist is served over HTTP.
"""
def _strip_sourcemap_comment(js: str) -> str {
    return re.sub(r'\n?//# sourceMappingURL=\S+\s*$', '', js);
}

"""Make inlined content safe inside a `<script>`/`<style>` element.

A literal closing tag in a JS/CSS string would end the element early; the
backslash-escaped form is equivalent in both languages' string contexts.
"""
def _guard_closing_tag(text: str, tag: str) -> str {
    return text.replace(f'</{tag}', f'<\\/{tag}');
}

"""Warn when code-splitting leaves chunks the inline page cannot absorb.

Inlining folds the entry bundle into index.html, but dynamically-imported
chunks remain as sibling `.js` files that an ES module fetches at runtime --
which fails over `file://`. Surface that instead of silently shipping a dist
that only works over HTTP.
"""
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

"""Rewrite dist/index.html to inline its JS bundle and CSS."""
impl inline_dist_assets(dist_dir: Path) -> bool {
    index_path = dist_dir / "index.html";
    if not index_path.exists() {
        return False;
    }

    html = index_path.read_text(encoding="utf-8");
    changed = False;

    # Inline the entry bundle in place of the external module script. Use a
    # literal replace (not re.sub) so the minified JS -- full of backslashes --
    # is never interpreted as a regex replacement template.
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

    # Inline the stylesheet in place of the external <link>.
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

"""Static handler that maps the conventional `/static/<x>` mount onto dist root.

A client-only app may still fetch an `na {}`-compiled module at
`/static/<stem>.wasm` (emitted into the dist root by the client compiler).
Honoring that prefix keeps the minimal server behavior-compatible with the
full server for the in-browser-native case, without any extra machinery.
"""
class _DistRequestHandler(SimpleHTTPRequestHandler) {
    def translate_path(self: _DistRequestHandler, path: str) -> str {
        if path.startswith("/static/") {
            path = path[len("/static"):];
        }
        return super.translate_path(path);
    }

    def guess_type(self: _DistRequestHandler, path: str) -> str {
        # `WebAssembly.instantiateStreaming` requires `application/wasm`;
        # mimetypes.guess_type() does not map `.wasm` on every platform, so
        # pin it here rather than relying on the OS MIME database.
        if str(path).endswith(".wasm") {
            return "application/wasm";
        }
        return super.guess_type(path);
    }
}

"""Serve a static directory with a minimal threaded stdlib HTTP server."""
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

"""Build the client bundle, then inline assets into a portable index.html."""
impl StaticTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    console.print("\n🌐 Building client-only (static) target", style="bold");
    # Reuse the full WebTarget Vite pipeline for the bundle + base index.html.
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

"""Build the portable dist and serve it with a minimal static server."""
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
