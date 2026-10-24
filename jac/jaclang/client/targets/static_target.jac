import from pathlib { Path }
import from typing { Optional }

def inline_dist_assets(dist_dir: Path) -> bool;

def serve_static_dir(dist_dir: Path, host: str, port: int) -> None;

obj StaticTarget(WebTarget) {
    has name: str = "static",
        requires_setup: bool = False,
        config_section: str = "plugin.client",
        output_dir: Path = Path(".jac/client/dist");

    override def build(
        entry_file: Path, project_dir: Path, platform: Optional[str] = None
    ) -> Path;

    override def start(
        entry_file: Path, project_dir: Path, api_port: int = 8000
    ) -> None;
}

impl _DistRequestHandler.translate_path(self: _DistRequestHandler, path: str) -> str {
    if path.startswith("/static/") {
        path = path[len("/static"):];
    }
    return super.translate_path(path);
}

impl _DistRequestHandler.guess_type(self: _DistRequestHandler, path: str) -> str {
    if str(path).endswith(".wasm") {
        return "application/wasm";
    }
    return super.guess_type(path);
}
