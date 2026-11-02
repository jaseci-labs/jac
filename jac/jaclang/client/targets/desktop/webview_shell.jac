import os;
import shutil;
import subprocess;
import from pathlib { Path }
import from typing { Optional }

def _assemble_native_host(
    entry_file: Path,
    project_dir: Path,
    output_dir: Path,
    dist_dir: Optional[Path],
    vendor: bool = True
) -> Path;

def webview_build(
    entry_file: Path, project_dir: Path, out_dir: Path, web_bundle: Path
) -> Path;

def webview_start(binary: Path);

def webview_dev(
    entry_file: Path,
    project_dir: Path,
    out_dir: Path,
    port: int = 8000,
    api_port: int = 0
);
