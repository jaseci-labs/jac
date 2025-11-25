"""
MkDocs development server with file watching, automatic rebuilds, and custom headers.

Uses Starlette + Uvicorn to serve files with security headers,
and watchdog to watch file changes and rebuild MkDocs site.
"""

import asyncio
import os
import subprocess
import threading
from typing import Awaitable, Callable, Optional

from starlette.applications import Starlette
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response, StreamingResponse
from starlette.staticfiles import StaticFiles

import uvicorn

from watchdog.events import FileSystemEvent, FileSystemEventHandler
from watchdog.observers import Observer

# Global queue for live reload events
reload_queue = asyncio.Queue()

# Script to inject into HTML pages for live reload
LIVE_RELOAD_SCRIPT = """
<script>
const evtSource = new EventSource('/events');
evtSource.onmessage = function(event) {
    if (event.data === 'reload') {
        location.reload();
    }
};
</script>
"""


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    """Middleware to add security headers for COOP and COEP."""

    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        """Add security headers to the response."""
        response: Response = await call_next(request)
        response.headers["Cross-Origin-Opener-Policy"] = "same-origin"
        response.headers["Cross-Origin-Embedder-Policy"] = "require-corp"
        return response


class LiveReloadMiddleware(BaseHTTPMiddleware):
    """Middleware to inject live reload script into HTML pages."""

    async def dispatch(
        self, request: Request, call_next: Callable[[Request], Awaitable[Response]]
    ) -> Response:
        """Inject live reload script into HTML responses."""
        response = await call_next(request)
        if response.media_type == "text/html":
            body = b""
            async for chunk in response.body_iterator:
                body += chunk
            html = body.decode("utf-8")
            # Inject the script before </body>
            if "</body>" in html:
                html = html.replace("</body>", LIVE_RELOAD_SCRIPT + "</body>")
            else:
                html += LIVE_RELOAD_SCRIPT
            response = Response(html, media_type="text/html")
        return response


class DebouncedRebuildHandler(FileSystemEventHandler):
    """File system event handler for debounced MkDocs site rebuilding."""

    def __init__(
        self,
        root_dir: str,
        debounce_seconds: int = 10,
        ignore_paths: Optional[list] = None,
    ) -> None:
        """Initialize the handler with root directory, debounce time, and ignore paths."""
        self.root_dir = root_dir
        self.debounce_seconds = debounce_seconds
        self.ignore_paths = ignore_paths or []
        self._timer: Optional[threading.Timer] = None
        self._debounce_lock = threading.Lock()
        self._rebuild_lock = threading.Lock()

    def _should_ignore(self, path: str) -> bool:
        """Check if the path should be ignored."""
        return any(
            os.path.commonpath([os.path.abspath(path), os.path.abspath(ignore)])
            == os.path.abspath(ignore)
            for ignore in self.ignore_paths
        )

    def debounced_rebuild(self, event_type: str, path: str) -> None:
        """Schedule a debounced rebuild on file system events."""
        print(f"Change detected: {event_type} — {path}")
        with self._debounce_lock:
            if self._timer:
                self._timer.cancel()
            self._timer = threading.Timer(self.debounce_seconds, self.rebuild)
            self._timer.start()

    def on_modified(self, event: FileSystemEvent) -> None:
        """Handle file modification events."""
        if (
            not event.is_directory
            and "site" not in event.src_path
            and not self._should_ignore(event.src_path)
        ):
            self.debounced_rebuild("modified", str(event.src_path))

    def on_created(self, event: FileSystemEvent) -> None:
        """Handle file creation events."""
        if (
            not event.is_directory
            and "site" not in event.src_path
            and not self._should_ignore(event.src_path)
        ):
            self.debounced_rebuild("created", str(event.src_path))

    def on_deleted(self, event: FileSystemEvent) -> None:
        """Handle file deletion events."""
        if (
            not event.is_directory
            and "site" not in event.src_path
            and not self._should_ignore(event.src_path)
        ):
            self.debounced_rebuild("deleted", str(event.src_path))

    def rebuild(self) -> None:
        """Rebuild the MkDocs site."""
        if not self._rebuild_lock.acquire(blocking=False):
            print("Rebuild already in progress. Skipping.")
            return

        try:
            print("\nRebuilding MkDocs site...")
            subprocess.run(["mkdocs", "build"], check=True, cwd=self.root_dir)
            print("Rebuild complete.")
            reload_queue.put_nowait("reload")
        except subprocess.CalledProcessError as e:
            print(f"Rebuild failed: {e}")
        except FileNotFoundError:
            print(
                "Error: mkdocs not found. Please install it via `pip install mkdocs`."
            )
        finally:
            self._rebuild_lock.release()


def run_periodic_rebuilds(
    rebuild_handler: DebouncedRebuildHandler, interval_seconds: int
) -> None:
    """Run periodic rebuilds in a loop."""
    import time

    while True:
        time.sleep(interval_seconds)
        print("\nPerforming scheduled 24-hour rebuild...")
        rebuild_handler.rebuild()


def serve_with_watch() -> None:
    """Serve MkDocs site and watch for file changes to trigger rebuilds."""
    port = 8000
    root_dir = os.path.dirname(os.path.dirname(__file__))
    site_dir = os.path.join(root_dir, "site")
    ignore_paths = [
        os.path.join(root_dir, "docs", "assets"),
        os.path.join(root_dir, "docs", "playground", "jaclang.zip"),
    ]

    print("Initial build of MkDocs site...")
    subprocess.run(["mkdocs", "build"], check=True, cwd=root_dir)
    reload_queue.put_nowait("reload")

    # Set up file watcher
    event_handler = DebouncedRebuildHandler(
        root_dir=root_dir, debounce_seconds=1, ignore_paths=ignore_paths
    )
    observer = Observer()
    observer.schedule(event_handler, root_dir, recursive=True)
    observer.start()

    # Set up periodic 12-hour rebuild
    rebuild_interval_seconds = 12 * 60 * 60
    periodic_thread = threading.Thread(
        target=run_periodic_rebuilds,
        args=(event_handler, rebuild_interval_seconds),
        daemon=True,
    )
    periodic_thread.start()
    print("Scheduled rebuilds will run every 24 hours.")

    # Create Starlette app and add middleware + static files
    app = Starlette()
    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(LiveReloadMiddleware)

    # Add health check endpoint
    @app.route("/health")
    async def health_check(request: Request) -> Response:
        return Response("healthy\n", media_type="text/plain")

    # Add Server-Sent Events endpoint for live reload
    @app.route("/events")
    async def events(request: Request) -> StreamingResponse:
        async def event_generator():
            yield "data: connected\n\n"
            while True:
                try:
                    message = await asyncio.wait_for(reload_queue.get(), timeout=30)
                    yield f"data: {message}\n\n"
                except asyncio.TimeoutError:
                    yield "data: ping\n\n"

        return StreamingResponse(event_generator(), media_type="text/event-stream")

    app.mount("/", StaticFiles(directory=site_dir, html=True), name="static")

    print(f"Serving at http://localhost:{port}")

    try:
        uvicorn.run(app, host="0.0.0.0", port=port)
    except KeyboardInterrupt:
        print("Stopping server...")
    finally:
        observer.stop()
        observer.join()


if __name__ == "__main__":
    serve_with_watch()
