import hashlib;
import os;
import platform;
import shlex;
import sys;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }

glob WEBVIEW_HEADER: Artifact = Artifact(
         "webview-header",
         "0.12.0",
         "source",
         "https://raw.githubusercontent.com/webview/webview/0.12.0/core/include/webview/webview.h",
         "b1ff6e11431d031e5f7917e5301f4bcdf3910a2763a0720abfd291994eee7f7b"
     ),
     MACOS_DESKTOP_MIN_VERSION: str = "12.0";

def module_files(module: Path) -> list[Path];

def stage_module(module: Path, dst_dir: Path) -> None;

def source_workspace(source: Path, name: str) -> Path;

def webview_library_name -> str;

obj WebviewBuild {
    has label: str,
        library: str,
        identity: str,
        compile_args: list[str],
        link_args: list[str] = [],
        webkit_module: str = "";

    def command(source: Path, output: Path) -> list[str];
}

def linux_webview_build(module: str, version: str, flags: list[str]) -> WebviewBuild;

def mac_webview_build(macos_version: str, machine: str) -> WebviewBuild;

def _webview_build_for_host(host: str) -> WebviewBuild;

def ensure_webview(directory: Path) -> Path;

def build_webview(directory: Path, build: WebviewBuild) -> Path;
