"""Shared build constants and artifact helpers for client native targets."""

import from pathlib { Path }

glob SUBPROCESS_TIMEOUT_SHORT: int = 5,
     SUBPROCESS_TIMEOUT_BUILD_MOBILE: int = 600,
     SUBPROCESS_TIMEOUT_BUILD_NATIVE: int = 1200;

"""Return file mtime for sorting build artifacts newest-first."""
def artifact_mtime(path: Path) -> float {
    return float(path.stat().st_mtime);
}
