import re;
import from pathlib { Path }


def pip_command(python: str, args: list[str]) -> list[str];


def venv_python(venv_dir: Path) -> str;


def make_pip_spec(name: str, version: str) -> str;


def make_git_spec(git_url: str, branch: str = "") -> str;


def _seed_build_backend(target: Path, verbose: bool = False);


def _raise_ensurepip_unavailable(err: str);


def _maybe_raise_ensurepip(err: str);


def _raise_venv_subprocess_failure(result: any, fallback: str);


def _run_venv_subprocess(cmd: list[str], fallback: str);


def _bootstrap_venv_pip(target: Path);


def _create_venv_with_interpreter(interpreter: str, target: Path);


def _bundled_runtime_python -> str | None;


def pip_python -> str;


def pip_env -> dict[str, str];


def _is_fused_venv(venv_dir: Path) -> bool;


def _venv_needs_recreate(venv_dir: Path) -> bool;


def ensure_venv(venv_dir: Path, verbose: bool = False);


def run_pip(
    venv_dir: Path, args: list[str], verbose: bool = False
) -> tuple[int, str, str];


def _spec_base_name(spec: str) -> str;


def _extract_terminal_error(stderr: str) -> str;


def _identify_failed_package(specs: list[str], stderr: str) -> str | None;


def summarize_pip_failure(specs: list[str], stderr: str) -> tuple[str | None, str];


def _venv_python_version_tag(venv_dir: Path) -> str;


def _discover_venv_site_packages(venv_dir: Path) -> Path | None;


def get_venv_site_packages(venv_dir: Path) -> Path;


def add_venv_to_path(config: JacConfig | None = None) -> None;


def remove_venv_from_path(config: JacConfig | None = None) -> None;


def is_venv_in_path(config: JacConfig | None = None) -> bool;
