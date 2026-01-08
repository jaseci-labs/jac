"""HMR (Hot Module Replacement) implementation for jac-client.

This module provides development server capabilities with hot module replacement
using Vite's dev server. .jac files are pre-compiled to .js and Vite handles HMR.
"""

import subprocess;
import from pathlib { Path }

glob JS_EXTENSIONS: tuple = ('.js', '.jsx', '.ts', '.tsx');

"""Get client directory from config or fallback to default."""
def get_client_dir(project_dir: Path) -> Path {
    import from jaclang.project.config { get_config }
    config = get_config();
    return config.get_client_dir() if config else (project_dir / '.jac' / 'client');
}

"""Calculate output path preserving relative structure."""
def calc_output_path(
    file_path: Path,
    source_root: Path,
    client_dir: Path,
    new_suffix: (str | None) = None
) -> Path {
    out: Path;
    try {
        relative = file_path.relative_to(source_root);
        out = client_dir / (
            relative.with_suffix(new_suffix) if new_suffix else relative
        );
    } except ValueError {
        name = file_path.with_suffix(new_suffix).name if new_suffix else file_path.name;
        out = client_dir / name;
    }
    return out;
}

"""Write content to file, creating parent dirs if needed."""
def write_file(path: Path, content: str) -> None {
    path.parent.mkdir(parents=True, exist_ok=True);
    path.write_text(content, encoding='utf-8');
}

"""Vite development server manager."""
obj ViteDevServer {
    has project_dir: Path,
        module_path: Path,
        vite_process: (subprocess.Popen | None) = None,
        compiled_modules: set[Path] = set(),
        host: str = 'localhost',
        port: int = 3000,
        be_port: int = 8000,
        verbose: bool = False;

    def start -> None;  # Start Vite dev server (core handles file watching via plugin hooks)
    def stop -> None;
    def create_vite_config -> None;
    def compile_all_jac_files -> None;
    def is_vite_available -> bool;
    def _create_runtime_stub(runtime_path: Path) -> None;
}

"""Handles .jac file compilation."""
obj HMRCompiler {
    has project_dir: Path,
        verbose: bool = False;

    def compile_recursively(
        module_path: Path,
        client_dir: Path,
        visited: (set[Path] | None) = None,
        source_root: (Path | None) = None
    ) -> set[Path];

    def _compile_to_js(module_path: Path) -> tuple[str, Any];
    def compile_module(module_path: Path, output_path: Path) -> None;
}
