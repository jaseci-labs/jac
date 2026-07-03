"""pytest configuration for jac-bridge-loader tests."""

import pathlib
import subprocess
import sys
import types
from collections.abc import Iterator

import pytest

# Make jac_bridge_loader importable when pytest is run from the repo root.
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent))


# Override the autouse isolate_jac_context from the repo-root conftest —
# this package has no jaclang dependency.
@pytest.fixture(autouse=True)
def isolate_jac_context(tmp_path: pathlib.Path) -> Iterator[pathlib.Path]:
    yield tmp_path


def pytest_configure(config: pytest.Config) -> None:
    ws = pathlib.Path(__file__).resolve().parent.parent.parent
    subprocess.run(
        ["cargo", "build", "--release", "-p", "jac-bridge-regex"],
        cwd=ws,
        check=True,
        capture_output=True,
    )


@pytest.fixture(scope="session")
def regex_so() -> str:
    ws = pathlib.Path(__file__).resolve().parent.parent.parent
    for stem in (
        "libjac_bridge_regex.so",
        "libjac_bridge_regex.dylib",
        "jac_bridge_regex.dll",
    ):
        p = ws / "target" / "release" / stem
        if p.exists():
            return str(p)
    raise FileNotFoundError("libjac_bridge_regex not found; run: cargo build --release")


@pytest.fixture(scope="session")
def regex_mod(regex_so: str) -> types.ModuleType:
    from jac_bridge_loader import load_bridge

    return load_bridge(regex_so)
