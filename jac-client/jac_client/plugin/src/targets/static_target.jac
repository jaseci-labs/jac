"""Static (client-only) build target.

A `client`-kind Jac project is a pure client app: it runs entirely in the
browser with no server surface. This target extends `WebTarget` but diverges
in two ways that matter for that use case:

1. **Portable dist** -- after the normal Vite build, `index.html` is rewritten
   to inline the JS bundle and CSS so the page is fully self-contained and
   opens directly from disk (`file://`). ES-module `<script src=...>` tags are
   CORS-blocked over `file://`, so inlining is what makes disk-open work.
2. **Minimal serve** -- `start()` serves the static dist with a tiny stdlib
   HTTP server instead of standing up the full API server (no walkers, auth,
   db, or scheduler), because a client-only app has no backend to run.

Dev mode is inherited unchanged from `WebTarget` (Vite dev server, no API).
"""
import from pathlib { Path }
import from typing { Optional }
import from jac_client.plugin.src.targets.web_target { WebTarget }

"""Rewrite `dist/index.html` to inline its JS bundle and CSS.

Makes the built page self-contained so it renders from `file://`. Returns True
when `index.html` existed and was rewritten, False otherwise (no-op).
"""
def inline_dist_assets(dist_dir: Path) -> bool;

"""Serve a static directory with a minimal threaded HTTP server (blocking).

Reuses Python's stdlib `http.server` -- the smallest correct static server for
a client-only app. Blocks until interrupted (Ctrl+C).
"""
def serve_static_dir(dist_dir: Path, host: str, port: int) -> None;

"""Static (client-only) build target - portable dist + minimal static serve."""
obj StaticTarget(WebTarget) {
    has name: str = "static",
        default: bool = False,
        requires_setup: bool = False,
        config_section: str = "plugin.client",
        output_dir: Path = Path(".jac/client/dist");

    """Build the client bundle, then inline assets into a portable index.html."""
    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    """Build the portable dist and serve it with a minimal static server."""
    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}
