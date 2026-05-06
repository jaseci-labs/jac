"""Local model weight cache for byllm.

Stores GGUF weights under ~/.cache/jac/models/<alias>/ and downloads
them lazily on first use via huggingface_hub. In a TTY, prompts the
user once before downloading (caching their answer per alias). In
non-TTY contexts (CI, Docker, daemons), refuses to download silently
and instructs the caller to run `jac model pull <alias>` first.
"""

import os;
import sys;
import json;
import logging;
import from pathlib { Path }
import from typing { Any }

glob _logger: logging.Logger = logging.getLogger("byllm.model_cache");

"""True if both stdin and stderr are interactive ttys."""
def _is_interactive -> bool {
    try {
        return os.isatty(0) and os.isatty(2);
    } except Exception {
        return False;
    }
}

"""Write a message without trailing newline (used for the Y/n prompt)."""
def _emit(msg: str) {
    import from jaclang.cli.console { console }
    console.print(msg, end="");
}

"""Resolve the on-disk cache directory for byllm-managed models.

Honours $JAC_MODELS_DIR; otherwise uses ~/.cache/jac/models, mirroring
the existing ~/.cache/jac/bytecode convention.
"""
def get_cache_dir -> Path {
    override = os.environ.get("JAC_MODELS_DIR");
    if override {
        return Path(override).expanduser();
    }
    home = Path(os.path.expanduser("~"));
    return home / ".cache" / "jac" / "models";
}

"""Directory holding all artifacts for a single alias."""
def alias_dir(alias: str) -> Path {
    return get_cache_dir() / alias;
}

"""Path to the GGUF file for a given alias + spec."""
def gguf_path(alias: str, spec: dict) -> Path {
    fname: str = str(spec["file"]);
    return alias_dir(alias) / fname;
}

"""Sidecar file recording a confirmed-download decision so we don't re-prompt."""
def _consent_marker(alias: str) -> Path {
    return alias_dir(alias) / ".jac_download_consent";
}

"""True if the alias has been downloaded and verified on disk."""
def is_downloaded(alias: str, spec: dict) -> bool {
    p = gguf_path(alias, spec);
    return p.exists() and p.stat().st_size > 0;
}

"""Format a size in MB as a human-friendly string."""
def _fmt_size(mb: int) -> str {
    if mb >= 1024 {
        return f"{mb / 1024:.1f} GB";
    }
    return f"{mb} MB";
}

"""Decide whether we may download without explicit user opt-in.

Priority:
  1. $BYLLM_AUTO_DOWNLOAD=1 / 0 — explicit env override
  2. cached consent marker — user said yes once for this alias
  3. interactive TTY — prompt the user
  4. non-TTY — refuse
"""
def _resolve_consent(alias: str, spec: dict, auto_download: bool) -> bool {
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
    _emit(
        f"\n[byllm] Local model '{alias}' is not downloaded.\n"
        f"        repo: {spec['repo']}\n"
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
        } except OSError { }
        return True;
    }
    return False;
}

"""Run the actual HF download into the alias cache directory.

Uses huggingface_hub.hf_hub_download for resumable, hash-checked transfer.
"""
def _download(alias: str, spec: dict) -> Path {
    try {
        import from huggingface_hub { hf_hub_download }
    } except ImportError {
        raise ImportError(
            "huggingface_hub is required to download local model weights. "
            "Install with: pip install 'byllm[local]'"
        );
    }
    target_dir = alias_dir(alias);
    target_dir.mkdir(parents=True, exist_ok=True);
    _logger.info(f"Downloading {spec['repo']}/{spec['file']} -> {target_dir}");
    _emit(
        f"[byllm] Downloading {spec['repo']}/{spec['file']} (~{_fmt_size(
            int(spec.get('size_mb', 0))
        )})...\n"
    );
    path = hf_hub_download(
        repo_id=spec["repo"], filename=spec["file"], local_dir=str(target_dir),
    );
    return Path(path);
}

"""Ensure the model file for `alias` is present locally; download if needed.

Returns the absolute path to the GGUF file. Raises RuntimeError when
download is needed but disallowed (non-TTY without consent).
"""
def ensure_model(alias: str, spec: dict, auto_download: bool = False) -> str {
    if is_downloaded(alias, spec) {
        return str(gguf_path(alias, spec));
    }
    if not _resolve_consent(alias, spec, auto_download) {
        raise RuntimeError(
            f"Local model '{alias}' is not downloaded and auto-download is disabled "
            f"in this context (no TTY). Run: jac model pull {alias}"
        );
    }
    _download(alias, spec);
    if not is_downloaded(alias, spec) {
        raise RuntimeError(
            f"Download for '{alias}' completed but file is missing or empty: "
            f"{gguf_path(alias, spec)}"
        );
    }
    return str(gguf_path(alias, spec));
}

"""Force download regardless of TTY/consent state. Used by `jac model pull`."""
def force_pull(alias: str, spec: dict) -> str {
    return ensure_model(alias, spec, auto_download=True);
}

"""Remove all cached artifacts for an alias. Used by `jac model rm`."""
def remove_alias(alias: str) -> bool {
    import shutil;
    d = alias_dir(alias);
    if not d.exists() {
        return False;
    }
    shutil.rmtree(d);
    return True;
}

"""List which aliases have downloaded weights and how big they are."""
def list_downloaded -> list[dict] {
    cache_root = get_cache_dir();
    if not cache_root.exists() {
        return [];
    }
    out: list[dict] = [];
    for child in cache_root.iterdir() {
        if not child.is_dir() {
            continue;
        }
        total = 0;
        files: list[str] = [];
        for f in child.rglob("*") {
            if f.is_file() and not f.name.startswith(".jac_") {
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
