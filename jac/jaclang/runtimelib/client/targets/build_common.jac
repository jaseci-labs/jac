import from pathlib { Path }

glob SUBPROCESS_TIMEOUT_SHORT: int = 5,
     SUBPROCESS_TIMEOUT_BUILD_MOBILE: int = 600,
     SUBPROCESS_TIMEOUT_BUILD_NATIVE: int = 1200;

def artifact_mtime(path: Path) -> float {
    return float(path.stat().st_mtime);
}
