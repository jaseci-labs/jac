import from pathlib { Path }
import from jaclang.project.config { JacConfig }

class NpmBoundaryError(RuntimeError) {}

obj NpmSourceFile {
    has npm_path: str = "",
        source_path: Path | None = None,
        js: str = "",
        dts: str = "",
        external_imports: list[str] = [];
}

def npm_js_path(rel_path: str) -> str;

def runtime_pkg_name(config: JacConfig) -> str;

def collect_npm_sources(
    config: JacConfig, project_root: Path | None = None,
) -> list[NpmSourceFile];

def resolve_npm_entry(config: JacConfig, files: list[NpmSourceFile],) -> str | None;
