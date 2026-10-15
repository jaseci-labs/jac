import hashlib;
import os;
import shutil;
import sys;
import json;
import logging;
import time;
import from pathlib { Path }
import from jaclang.cache.locking { FileLock }

glob _logger: logging.Logger = logging.getLogger("byllm.model_cache"),
     _STAGING_DIR: str = ".jac_partial",
     _STAMP_FILE: str = ".jac_verified",
     _LOCK_DIR: str = ".locks";

def _is_interactive -> bool {
    try {
        return os.isatty(0) and os.isatty(2);
    } except Exception {
        return False;
    }
}

def _emit(msg: str) {
    import from jaclang.cli.console { console }
    console.print(msg, end="");
}

def get_cache_dir -> Path {
    import from jaclang.cache.registry { bucket }
    return bucket("models").ensure();
}

def alias_dir(alias: str) -> Path {
    return get_cache_dir() / alias;
}

def gguf_path(alias: str, spec: dict[str, any]) -> Path {
    fname: str = str(spec["file"]);
    return alias_dir(alias) / fname;
}

def _consent_marker(alias: str) -> Path {
    return alias_dir(alias) / ".jac_download_consent";
}

def _staging_dir(alias: str) -> Path {
    return alias_dir(alias) / _STAGING_DIR;
}

def _file_sha256(path: Path) -> str {
    digest = hashlib.sha256();
    with open(path, "rb") as source {
        chunk = source.read(1 << 20);
        while chunk {
            digest.update(chunk);
            chunk = source.read(1 << 20);
        }
    }
    return digest.hexdigest();
}

def _verify(path: Path, spec: dict[str, any]) -> str {
    size = path.stat().st_size;
    expected_size = spec.get("size_bytes");
    if expected_size is not None and size != int(expected_size) {
        return f"expected {int(expected_size)} bytes, found {size}";
    }
    if size == 0 {
        return "the file is empty";
    }
    expected_sha = spec.get("sha256");
    if expected_sha and _file_sha256(path) != str(expected_sha) {
        return "its sha256 does not match the pinned digest";
    }
    return "";
}

def _stamp_for(spec: dict[str, any], path: Path) -> dict[str, any] {
    stat = path.stat();
    return {
        "file": path.name,
        "sha256": str(spec.get("sha256", "")),
        "size": stat.st_size,
        "mtime_ns": stat.st_mtime_ns
    };
}

def _stamp_matches(alias: str, spec: dict[str, any], path: Path) -> bool {
    try {
        stamp = json.loads((alias_dir(alias) / _STAMP_FILE).read_text());
    } except (OSError, ValueError) {
        return False;
    }
    return stamp == _stamp_for(spec, path);
}

def _write_stamp(alias: str, spec: dict[str, any], path: Path) {
    try {
        (alias_dir(alias) / _STAMP_FILE).write_text(json.dumps(_stamp_for(spec, path)));
    } except OSError {}
}

def _has_partial(alias: str) -> bool {
    staging = _staging_dir(alias);
    return staging.is_dir() and any(f.is_file() for f in staging.rglob("*"));
}

def weight_status(alias: str, spec: dict[str, any]) -> str {
    path = gguf_path(alias, spec);
    if not path.is_file() {
        return "incomplete" if _has_partial(alias) else "missing";
    }
    if _stamp_matches(alias, spec, path) {
        return "valid";
    }
    if _verify(path, spec) {
        return "invalid";
    }
    _write_stamp(alias, spec, path);
    return "valid";
}

def is_downloaded(alias: str, spec: dict[str, any]) -> bool {
    return weight_status(alias, spec) == "valid";
}

def _fmt_size(mb: int) -> str {
    if mb >= 1024 {
        return f"{mb / 1024:.1f} GB";
    }
    return f"{mb} MB";
}

def _resolve_consent(
    alias: str, spec: dict[str, any], auto_download: bool, status: str = "missing"
) -> bool {
    env = os.environ.get("BYLLM_AUTO_DOWNLOAD");
    if env is not None {
        if env.strip().lower() in ("1", "true", "yes", "y") {
            return True;
        }
        if env.strip().lower() in ("0", "false", "no", "n") {
            return False;
        }
    }
    if auto_download {
        return True;
    }
    if _consent_marker(alias).exists() {
        return True;
    }
    if not _is_interactive() {
        return False;
    }
    size = _fmt_size(int(spec.get("size_mb", 0)));
    target = alias_dir(alias);
    headline = (
        f"\n[byllm] Cached weights for local model '{alias}' failed verification.\n"
            if status == "invalid"
            else f"\n[byllm] Local model '{alias}' is not downloaded.\n"
    );
    _emit(
        headline
            + f"        repo: {spec['repo']}\n"
            f"        file: {spec['file']}\n"
            f"        size: ~{size}\n"
            f"        path: {target}\n"
            "        Download now? [Y/n] "
    );
    try {
        answer = input().strip().lower();
    } except EOFError {
        return False;
    }
    if answer in ("", "y", "yes") {
        target.mkdir(parents=True, exist_ok=True);
        try {
            _consent_marker(alias).write_text("1\n");
        } except OSError {}
        return True;
    }
    return False;
}

def _download(alias: str, spec: dict[str, any]) -> Path {
    try {
        import from huggingface_hub { hf_hub_download }
    } except ImportError {
        raise ImportError(
            "huggingface_hub is required to download local model weights. "
            "Install with: pip install 'byllm[local]'"
        );
    }
    target_dir = _staging_dir(alias);
    target_dir.mkdir(parents=True, exist_ok=True);
    _logger.info(f"Downloading {spec['repo']}/{spec['file']} -> {target_dir}");
    _emit(
        f"[byllm] Downloading {spec['repo']}/{spec['file']} (~{_fmt_size(
            int(spec.get('size_mb', 0))
        )})...\n"
    );
    path = hf_hub_download(
        repo_id=spec["repo"],
        filename=spec["file"],
        revision=spec.get("revision"),
        local_dir=str(target_dir),
    );
    return Path(path);
}

def _check_alias_name(alias: str) {
    if (
        not alias
        or alias.startswith(".")
        or "/" in alias
        or "\\" in alias
        or Path(alias).name != alias
    ) {
        raise ValueError(f"'{alias}' is not a local model alias");
    }
}

def _alias_lock(alias: str) -> FileLock {
    lock = FileLock(path=get_cache_dir() / _LOCK_DIR / f"{alias}.lock");
    if not lock.acquire() {
        _emit(f"[byllm] Waiting for another process using '{alias}' to finish...\n");
        while not lock.acquire() {
            time.sleep(0.2);
        }
    }
    return lock;
}

def _install(alias: str, spec: dict[str, any]) -> Path {
    target = gguf_path(alias, spec);
    lock = _alias_lock(alias);
    try {
        if weight_status(alias, spec) == "valid" {
            return target;
        }
        staged = _download(alias, spec);
        problem = _verify(staged, spec);
        if problem {
            staged.unlink(missing_ok=True);
            raise RuntimeError(
                f"Downloaded weights for '{alias}' failed verification ({problem}); "
                f"nothing was installed. Retry with: jac model pull {alias}"
            );
        }
        os.replace(staged, target);
        _write_stamp(alias, spec, target);
        shutil.rmtree(_staging_dir(alias), ignore_errors=True);
        return target;
    } finally {
        lock.release();
    }
}

def ensure_model(alias: str, spec: dict[str, any], auto_download: bool = False) -> str {
    status = weight_status(alias, spec);
    if status == "valid" {
        return str(gguf_path(alias, spec));
    }
    if not _resolve_consent(alias, spec, auto_download, status) {
        if status == "invalid" {
            raise RuntimeError(
                f"Cached weights for local model '{alias}' at {gguf_path(alias, spec)} "
                "failed verification and auto-download is disabled in this context. "
                f"Replace them with: jac model pull {alias}"
            );
        }
        raise RuntimeError(
            f"Local model '{alias}' is not downloaded and auto-download is disabled "
            f"in this context (no TTY). Run: jac model pull {alias}"
        );
    }
    return str(_install(alias, spec));
}

def force_pull(alias: str, spec: dict[str, any]) -> str {
    return ensure_model(alias, spec, auto_download=True);
}

def remove_alias(alias: str) -> bool {
    _check_alias_name(alias);
    lock = _alias_lock(alias);
    try {
        d = alias_dir(alias);
        if not d.exists() {
            return False;
        }
        shutil.rmtree(d);
        return True;
    } finally {
        lock.release();
    }
}

def list_downloaded -> list[dict[str, any]] {
    cache_root = get_cache_dir();
    if not cache_root.exists() {
        return [];
    }
    out: list[dict[str, any]] = [];
    for child in cache_root.iterdir() {
        if not child.is_dir() or child.name.startswith(".") {
            continue;
        }
        total = 0;
        files: list[str] = [];
        for f in child.rglob("*") {
            hidden = any(part.startswith(".") for part in f.relative_to(child).parts);
            if f.is_file() and not hidden {
                total += f.stat().st_size;
                files.append(f.name);
            }
        }
        if files {
            out.append({"alias": child.name, "size_bytes": total, "files": files});
        }
    }
    return out;
}
