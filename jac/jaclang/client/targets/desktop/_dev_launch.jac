import os;
import sys;
import sysconfig;
import site;
import from pathlib { Path }

glob DESKTOP_WEBKIT_ENV: list[tuple[str, str]] = [
         ("GDK_BACKEND", "x11"),
         ("WEBKIT_DISABLE_DMABUF_RENDERER", "1"),
         ("WEBKIT_DISABLE_COMPOSITING_MODE", "1"),

     ];


def _project_venv_site_packages -> str;


def desktop_host_env -> list[tuple[str, str]];


def jac_desktop_webkit_shell_export -> str;


def jac_desktop_deps_shell_export(venv_rel: str = "../../venv") -> str;


def _prepend_env_path(env: dict[str, str], key: str, path: str) -> None;


def _dev_roots_from_env -> dict[str, str];


def _editable_roots_from_site -> dict[str, str];


def ensure_dev_build_env;


def desktop_app_runtime_env(base: any = None) -> dict[str, str];


def desktop_launch_env(base: any = None) -> dict[str, str];
