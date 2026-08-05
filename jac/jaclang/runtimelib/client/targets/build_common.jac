import os;
import shutil;
import subprocess;
import from pathlib { Path }

glob SUBPROCESS_TIMEOUT_SHORT: int = 5,
     SUBPROCESS_TIMEOUT_BUILD_MOBILE: int = 600,
     SUBPROCESS_TIMEOUT_BUILD_NATIVE: int = 1200;

def artifact_mtime(path: Path) -> float {
    return float(path.stat().st_mtime);
}

def select_newest_artifact(candidates: list[Path]) -> Path {
    if not candidates {
        raise ValueError("select_newest_artifact requires at least one candidate");
    }
    return sorted(candidates, key=artifact_mtime, reverse=True)[0];
}

def ensure_gradle_wrapper(android_dir: Path) -> None {
    gradlew = android_dir / ("gradlew.bat" if os.name == "nt" else "gradlew");
    if gradlew.exists() {
        return;
    }
    gradle = shutil.which("gradle");
    if not gradle {
        return;
    }
    subprocess.run(
        [gradle, "wrapper", "--gradle-version", "8.13"],
        cwd=str(android_dir),
        check=False
    );
    if os.name != "nt" and gradlew.exists() {
        try {
            os.chmod(gradlew, 0o755);
        } except Exception { }
    }
}
