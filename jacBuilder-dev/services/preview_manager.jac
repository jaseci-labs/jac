"""Preview Manager - Manages per-session isolated preview sandboxes.

Delegates to SandboxFactory for the actual isolation backend:
- "local"      → subprocess on host (backward compatible, default)
- "docker"     → Docker container per preview
- "kubernetes" → K8s ephemeral pod per preview (production)

The backend is selected via JAC_SANDBOX_TYPE env var or jac.toml config.
"""

import os;
import re;
import shutil;
import base64;
import from pathlib { Path }
import from typing { Any }
import from urllib.parse { quote }

glob _IMAGE_MIME_TYPES: dict = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".ico": "image/x-icon",
    ".bmp": "image/bmp",
    ".tiff": "image/tiff",
    ".tif": "image/tiff",
    ".svg": "image/svg+xml"
};

glob PREVIEW_BASE_PORT: int = 5180;
glob PREVIEW_PORT_COUNT: int = 10;
glob PREVIEW_TEMPLATE_DIR: str = os.path.join(os.path.realpath("."), "assets", "preview-template");
glob PROTECTED_FILES: list = ["jac.toml"];
glob _WRITE_ALLOWED_PROTECTED: list = ["jac.toml"];

# Lazy-initialized sandbox instance
glob _sandbox: Any = None;
glob _sandbox_id_map: dict = {};  # Maps "user_id::project_id" -> sandbox_id
glob _staging_dirs: dict = {};    # Maps "user_id::project_id" -> local staging dir path
glob _is_k8s_sandbox: bool = False;
glob _k8s_domain_template: str = "";  # domain_template from jac.toml sandbox config
glob _preview_registry: dict = {};  # Compatibility shim for dev branch worktree features

# Sandbox deploy: separate instance with 1-week TTL (604800s)
glob _sandbox_deploy: Any = None;
glob _sandbox_deploy_id_map: dict = {};  # Maps "user_id::project_id" -> sandbox_id
glob _sandbox_deploy_staging: dict = {};  # Maps "user_id::project_id" -> staging dir

def _get_sandbox() -> Any {
    global _sandbox;
    global _is_k8s_sandbox;
    global _k8s_domain_template;
    if _sandbox is None {
        try {
            import from jac_scale.factories.sandbox_factory { SandboxFactory }
            import from jac_scale.config_loader { get_scale_config }
            scale_config = get_scale_config();
            cfg = scale_config._config if hasattr(scale_config, "_config") else scale_config;
            sandbox_cfg = cfg.get("sandbox", {}) if isinstance(cfg, dict) else {};
            if sandbox_cfg and sandbox_cfg.get("enabled", False) {
                sandbox_type = sandbox_cfg.get("type", "local");
                env_type = str(os.environ.get("JAC_SANDBOX_TYPE", "")).strip();
                if env_type {
                    sandbox_type = env_type;
                }
                _sandbox = SandboxFactory.create(sandbox_type, sandbox_cfg);
                _is_k8s_sandbox = sandbox_type in ("kubernetes", "docker");
                _k8s_domain_template = sandbox_cfg.get("domain_template", "");
            } else {
                _sandbox = SandboxFactory.create("local", {});
            }
        } except (ImportError, Exception) as e {
            print(f"[preview_manager] Sandbox import failed: {e}, using local fallback");
            try {
                import from jac_scale.providers.sandbox.local_sandbox { LocalSandbox }
                import from jac_scale.abstractions.models.sandbox_config { SandboxConfig }
                _sandbox = LocalSandbox(config=SandboxConfig());
            } except (ImportError, Exception) as e2 {
                print(f"[preview_manager] Local fallback also failed: {e2}, sandbox disabled");
                _sandbox = None;
            }
        }
    }
    return _sandbox;
}

"""Build K8s sandbox URL from domain_template config (e.g. '{sandbox_id}.mars.ninja').
Falls back to empty string if template is not configured."""
def _build_k8s_url(sandbox_id: str) -> str {
    if not _k8s_domain_template {
        return "";
    }
    url = _k8s_domain_template.replace("{sandbox_id}", sandbox_id);
    if not url.startswith("http") {
        url = f"https://{url}";
    }
    return url;
}

"""Background task that initializes K8s and fills the warm pool.

Waits for the SA token to be mounted before attempting K8s init,
because the deployment patch step adds automountServiceAccountToken
AFTER the app starts.
"""
def _warmpool_startup_task(sandbox: Any) -> None {
    import time as _time;
    # Wait for SA token — mounted by deployment patch step after app starts
    token_path = "/var/run/secrets/kubernetes.io/serviceaccount/token";
    kubeconfig_path = "/root/.kube/config";
    max_wait = 300;
    waited = 0;
    while waited < max_wait {
        if os.path.exists(token_path) or os.path.exists(kubeconfig_path) {
            break;
        }
        _time.sleep(5);
        waited = waited + 5;
    }
    if waited >= max_wait {
        print("[preview_manager] Warm pool skipped — no K8s credentials found");
        return;
    }
    try {
        if hasattr(sandbox, "_init_k8s") {
            sandbox._init_k8s();
        }
        if hasattr(sandbox, "_ensure_namespace") {
            sandbox._ensure_namespace();
        }
        if hasattr(sandbox, "_ensure_warm_pool") {
            sandbox._ensure_warm_pool();
        }
        print("[preview_manager] K8s warm pool initialized successfully");
    } except Exception as e {
        print(f"[preview_manager] Warm pool init failed: {e}");
    }
}

"""Eagerly initialize the K8s sandbox and trigger warm pool prefill at server startup.

Called once from main.jac entry block so warm pods are ready before the first
user requests a preview, instead of paying the cold-start cost on demand.
"""
def init_preview_warmpool() -> None {
    import threading;
    sandbox = _get_sandbox();
    if sandbox is None {
        return;
    }
    if hasattr(sandbox, "_ensure_warm_pool") {
        t = threading.Thread(target=_warmpool_startup_task, args=(sandbox,), daemon=True);
        t.start();
        print("[preview_manager] K8s warm pool prefill started");
    }
}

def _preview_key(user_id: str, project_id: str = "") -> str {
    safe_user = user_id or "session";
    safe_project = project_id or "__default__";
    return f"{safe_user}::{safe_project}";
}

"""Get the local staging dir for a user/project. Used for file ops before sandbox starts."""
def _get_staging_dir(user_id: str, project_id: str = "") -> (str | None) {
    key = _preview_key(user_id, project_id);
    return _staging_dirs.get(key);
}

"""Resolve a path inside a local directory with sandbox escape check."""
def _resolve_local_path(base_dir: str, path: str) -> str {
    candidate = path if path else ".";
    real_base = os.path.realpath(base_dir);
    full = os.path.realpath(
        candidate if os.path.isabs(candidate) else os.path.join(real_base, candidate)
    );
    if os.path.commonpath([real_base, full]) != real_base {
        raise ValueError("Path is outside preview directory");
    }
    return full;
}

"""Build preview URL for browser access.

Use JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE in deployment to avoid localhost URLs.
Supported placeholders: {user_id}, {port}, {api_port}
"""
def _build_preview_url(user_id: str, port: int, api_port: int = 0) -> str {
    template = os.environ.get("JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE", "").strip();
    if not template {
        return f"http://localhost:{port}";
    }
    safe_user = quote(user_id or "", safe="");
    resolved = template.replace("{user_id}", safe_user);
    resolved = resolved.replace("{session_id}", safe_user);
    resolved = resolved.replace("{port}", str(port));
    resolved = resolved.replace("{api_port}", str(api_port if api_port else port + 1));
    return resolved;
}

"""Find jac command. Returns a list for subprocess calls.
For PyInstaller frozen apps, uses sidecar's --jac-cli mode.
"""
def _find_jac_cmd() -> list {
    import sys;
    # PyInstaller frozen app — use sidecar's multi-mode CLI
    if getattr(sys, 'frozen', False) {
        return [sys.executable, "--jac-cli"];
    }
    bin_dir = "Scripts" if sys.platform == "win32" else "bin";
    jac_name = "jac.exe" if sys.platform == "win32" else "jac";
    candidates = [
        str(Path.home() / ".jacvenv" / bin_dir / jac_name)
    ];
    venv = os.environ.get("VIRTUAL_ENV", "");
    if venv {
        candidates.append(os.path.join(venv, bin_dir, jac_name));
    }
    for path in candidates {
        if os.path.exists(path) {
            return [path];
        }
    }
    result = shutil.which("jac");
    if result {
        return [result];
    }
    raise FileNotFoundError("Could not find 'jac' binary.");
}

"""Find the activate script for the virtualenv containing jac.

Returns empty string when jac is installed system-wide (no venv).
"""
def _find_activate_script() -> str {
    import sys;
    bin_dir = "Scripts" if sys.platform == "win32" else "bin";
    activate_name = "activate.bat" if sys.platform == "win32" else "activate";
    # Check ~/.jacvenv first
    jacvenv_activate = str(Path.home() / ".jacvenv" / bin_dir / activate_name);
    if os.path.exists(jacvenv_activate) {
        return jacvenv_activate;
    }
    # Check VIRTUAL_ENV
    venv = os.environ.get("VIRTUAL_ENV", "");
    if venv {
        activate = os.path.join(venv, bin_dir, activate_name);
        if os.path.exists(activate) {
            return activate;
        }
    }
    # Fallback: derive from jac binary path
    jac_cmd = _find_jac_cmd();
    activate = os.path.join(os.path.dirname(jac_cmd[0]), "activate");
    if os.path.exists(activate) {
        return activate;
    }
    # No venv — jac is installed system-wide
    return "";
}

"""Resolve path inside preview dir with sandbox check."""
def _resolve_preview_path(preview_dir: str, path: str) -> str {
    candidate = path if path else ".";
    real_preview = os.path.realpath(preview_dir);
    full = os.path.realpath(
        candidate if os.path.isabs(candidate) else os.path.join(real_preview, candidate)
    );
    if os.path.commonpath([real_preview, full]) != real_preview {
        raise ValueError("Path is outside preview directory");
    }
    return full;
}

"""Run jac install in a directory (for background thread use)."""
def _bg_jac_install(work_dir: str) -> None {
    try {
        activate = _find_activate_script();
        if activate {
            cmd = "source " + activate + " && jac install";
        } else {
            cmd = " ".join(_find_jac_cmd()) + " install";
        }
        import subprocess;
        import sys;
        subprocess.run(cmd, shell=True,
                      executable=None if sys.platform == "win32" else "/bin/bash",
                      cwd=work_dir, capture_output=True, text=True, timeout=300);
        print(f"[preview_manager] Background jac install completed for {work_dir}");
    } except Exception as e {
        print(f"[preview_manager] Background jac install failed (non-fatal): {e}");
    }
}

"""Prepare preview workspace for a session + project."""
def setup_preview(user_id: str, project_id: str = "", source_dir: str = "", worktree_path: str = "") -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);

    # Check if already set up
    sid = _sandbox_id_map.get(key);
    if sid and sandbox is not None {
        status = sandbox.status(sid);
        state_str = status.state.value if hasattr(status.state, "value") else str(status.state);
        # If sandbox is dead/errored, clear stale entry and re-setup
        if state_str in ("stopped", "error") {
            _sandbox_id_map.pop(key, None);
            sid = None;
        } else {
            sandbox_dir = _staging_dirs.get(key, "");
            if not sandbox_dir and hasattr(sandbox, "get_sandbox_dir") {
                sandbox_dir = sandbox.get_sandbox_dir(sid) or "";
            }
            return {
                "success": True,
                "dir": sandbox_dir,
                "status": state_str
            };
        }
    }

    # Single-directory architecture: use the source dir directly instead of copying.
    # For local mode, jac start --dev runs in the repo dir.
    # For K8s mode, the sandbox still copies code into the pod at creation time.
    source_path = source_dir if source_dir and os.path.isdir(source_dir) else PREVIEW_TEMPLATE_DIR;

    if _is_k8s_sandbox {
        # K8s mode: still needs a staging dir for sandbox.create() to upload from.
        # Use the source dir directly as the staging reference — sandbox.create()
        # will copy files into the pod via ConfigMap or init container.
        preview_dir = source_path;
    } else {
        # Local mode: run directly in the source dir (repo dir). No /tmp copy.
        preview_dir = source_path;
    }
    _staging_dirs[key] = preview_dir;

    # Do NOT pre-register in the sandbox._registry for local mode.
    # LocalSandbox.create() builds its own /tmp preview dir and manages it.
    # We keep _staging_dirs pointing to the repo dir for direct file I/O
    # (read/write/list/delete go to repo), while the sandbox's /tmp copy
    # is used only for the running jac start process.
    # For K8s/Docker sandbox: sandbox_id will be set in start_preview()

    # Run jac install in repo dir (background) so terminal has deps available
    import from threading { Thread }
    install_thread = Thread(target=_bg_jac_install, args=(preview_dir,), daemon=True);
    install_thread.start();

    # Start filesystem watcher for real-time IDE sync
    try {
        import from services.file_watcher { start_watcher }
        start_watcher(user_id, project_id, preview_dir);
    } except Exception as e {
        print(f"[preview_manager] File watcher start failed (non-fatal): {e}");
    }

    return {"success": True, "dir": preview_dir, "status": "ready"};
}

"""Mark that jac install must run before next preview start."""
def mark_needs_install(user_id: str, project_id: str = "") -> None {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if sid and hasattr(sandbox, "_registry") {
        entry = sandbox._registry.get(
            sandbox._sandbox_key(user_id, project_id) if hasattr(sandbox, "_sandbox_key") else key
        );
        if entry {
            entry["needs_install"] = True;
        }
    }
}

"""Write a file in the preview directory."""
def write_preview_file(user_id: str, project_id: str, path: str, content: str) -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    basename = os.path.basename(path);
    if basename in PROTECTED_FILES and basename not in _WRITE_ALLOWED_PROTECTED {
        return {"success": True, "skipped": True, "reason": f"Protected file: {basename}"};
    }
    # Always write to staging dir first
    staging = _staging_dirs.get(key);
    if staging and os.path.isdir(staging) {
        try {
            full_path = _resolve_local_path(staging, path);
            parent = os.path.dirname(full_path);
            if parent and not os.path.exists(parent) {
                os.makedirs(parent, exist_ok=True);
            }
            with open(full_path, "w", encoding="utf-8") as f {
                f.write(content);
            }
        } except Exception {
            ;
        }
    }
    # If sandbox is running, also write to it
    if sid {
        sandbox.write_file(sid, path, content);
        return {"success": True, "path": path};
    }
    # No sandbox yet — staging write above is sufficient
    staging = _staging_dirs.get(key);
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    try {
        full_path = _resolve_local_path(staging, path);
        parent = os.path.dirname(full_path);
        if parent and not os.path.exists(parent) {
            os.makedirs(parent, exist_ok=True);
        }
        with open(full_path, "w", encoding="utf-8") as f {
            f.write(content);
        }
        return {"success": True, "path": path};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Write binary data to a file in the preview directory."""
def write_preview_file_binary(user_id: str, project_id: str, path: str, data: bytes) -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    basename = os.path.basename(path);
    if basename in PROTECTED_FILES and basename not in _WRITE_ALLOWED_PROTECTED {
        return {"success": True, "skipped": True, "reason": f"Protected file: {basename}"};
    }
    staging = _staging_dirs.get(key);
    if staging and os.path.isdir(staging) {
        try {
            full_path = _resolve_local_path(staging, path);
            parent = os.path.dirname(full_path);
            if parent and not os.path.exists(parent) {
                os.makedirs(parent, exist_ok=True);
            }
            with open(full_path, "wb") as f {
                f.write(data);
            }
        } except Exception {
            ;
        }
    }
    if sid {
        # For sandbox, write base64-encoded content as text (sandbox API is text-based)
        b64 = base64.b64encode(data).decode("utf-8");
        sandbox.write_file(sid, path, b64);
        return {"success": True, "path": path};
    }
    staging = _staging_dirs.get(key);
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    try {
        full_path = _resolve_local_path(staging, path);
        parent = os.path.dirname(full_path);
        if parent and not os.path.exists(parent) {
            os.makedirs(parent, exist_ok=True);
        }
        with open(full_path, "wb") as f {
            f.write(data);
        }
        return {"success": True, "path": path};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Apply a string patch to a file in the preview directory."""
def apply_preview_patch(user_id: str, project_id: str, path: str, search: str, replace: str, replace_all: bool = False) -> dict {
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    basename = os.path.basename(path);
    if basename in PROTECTED_FILES {
        return {"success": True, "skipped": True, "reason": f"Protected file: {basename}"};
    }
    # Read current content
    read_result = read_preview_file(user_id, project_id, path);
    if not read_result.get("success") {
        return read_result;
    }
    original = read_result.get("content", "");
    if search not in original {
        return {"success": False, "error": "Search text not found"};
    }
    if replace_all {
        count = original.count(search);
        updated = original.replace(search, replace);
    } else {
        count = 1;
        updated = original.replace(search, replace, 1);
    }
    write_result = write_preview_file(user_id, project_id, path, updated);
    if write_result.get("success") {
        write_result["replacements"] = count;
    }
    return write_result;
}
"""Create a directory in the preview directory."""
def preview_mkdir(user_id: str, project_id: str, path: str) -> dict {
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if sid {
        sandbox = _get_sandbox();
        sandbox_dir = sandbox.get_sandbox_dir(sid) if hasattr(sandbox, "get_sandbox_dir") else None;
        if sandbox_dir {
            target = os.path.join(sandbox_dir, path);
            os.makedirs(target, exist_ok=True);
            return {"success": True, "path": path};
        }
        return sandbox.exec_command(sid, f"mkdir -p /app/{path}", timeout=10);
    }
    staging = _staging_dirs.get(key);
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    try {
        target = _resolve_local_path(staging, path);
        os.makedirs(target, exist_ok=True);
        return {"success": True, "path": path};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Run a command with cwd=preview_dir."""
def preview_run_cmd(user_id: str, project_id: str, command: str, timeout: int = 120) -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if not sid {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    return sandbox.exec_command(sid, command, timeout=timeout);
}

"""Run jac js main.jac in the preview directory."""
def preview_jac_check(user_id: str, project_id: str) -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if not sid {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    result = sandbox.exec_command(sid, "jac js main.jac", timeout=120);
    if result.get("success") {
        stdout = result.get("stdout", "");
        stderr = result.get("stderr", "");
        setup_ok = "Jac setup complete" in stdout or "Jac setup complete" in stderr;
        return {
            "command": "jac js main.jac",
            "exit_code": result.get("exit_code", -1),
            "stdout": stdout[:4000],
            "stderr": stderr[:4000],
            "setup_complete": setup_ok
        };
    }
    return {"command": "preview-verify", "error": result.get("error", "Unknown error")};
}

"""Allocate port, start preview subprocess, return immediately (non-blocking).

Idempotent: if a sandbox already exists and is not in a terminal state,
returns its current status without creating a new sandbox. This prevents
duplicate sandbox creation when multiple code paths (preview_control HTTP
walker + ide_preview_stream WebSocket) both call start_preview for the
same project, which would exhaust the per-user sandbox limit and cause
concurrent preview starts to fail.
"""
def start_preview(user_id: str, project_id: str = "") -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);

    # Idempotency check: return existing sandbox state if still alive
    existing_sid = _sandbox_id_map.get(key);
    if existing_sid and sandbox is not None {
        try {
            status = sandbox.status(existing_sid);
            state_str = status.state.value if hasattr(status.state, "value") else str(status.state);
            if state_str not in ("stopped", "error") {
                url = status.url;
                if not url and _is_k8s_sandbox {
                    url = _build_k8s_url(existing_sid);
                }
                return {
                    "success": True,
                    "url": url,
                    "port": status.port,
                    "api_port": getattr(status, "api_port", 0),
                    "status": state_str
                };
            }
        } except Exception { }
        # Terminal or unknown state — clear entry and recreate
        _sandbox_id_map.pop(key, None);
    }

    # Use staging dir as code path
    staging = _staging_dirs.get(key);
    if not staging {
        preview_suffix = f"-{project_id}" if project_id else "";
        import tempfile;
        staging = os.path.join(tempfile.gettempdir(), f"jac-preview-{user_id}{preview_suffix}");
    }
    staging_exists = os.path.isdir(staging);
    print(f"[start_preview] key={key} staging={staging} exists={staging_exists}");

    # Create sandbox
    result = sandbox.create(user_id, project_id, staging);
    if result.is_successful() {
        _sandbox_id_map[key] = result.sandbox_id;

        # For K8s/Docker sandbox, use the sandbox-provided URL directly
        # (it uses domain_template from jac.toml, e.g. {sandbox_id}.mars.ninja)
        # Only use JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE for local sandbox
        if _is_k8s_sandbox {
            url = result.url;
            if not url {
                url = _build_k8s_url(result.sandbox_id);
            }
        } else {
            url = result.url;
            template = os.environ.get("JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE", "").strip();
            if template and result.port {
                url = _build_preview_url(user_id, result.port, result.api_port);
            }
        }

        return {
            "success": True,
            "url": url,
            "port": result.port,
            "api_port": result.api_port,
            "status": "starting"
        };
    }
    print(f"[start_preview] FAILED key={key} reason={result.message}");
    return {"success": False, "error": result.message or "Failed to create sandbox"};
}

"""Stop preview subprocess and return port to pool."""
def stop_preview(user_id: str, project_id: str = "") -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if not sid {
        return {"success": False, "error": "No preview found for this user"};
    }
    sandbox.stop(sid);
    return {"success": True, "status": "stopped"};
}

"""Get current preview status."""
def get_preview_status(user_id: str, project_id: str = "") -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if not sid {
        return {"running": False, "url": None, "port": 0, "api_port": 0, "status": "none"};
    }
    try {
        status = sandbox.status(sid);
    } except Exception as e {
        print(f"[get_preview_status] Sandbox {sid} is dead (pod not found), cleaning up: {e}");
        _sandbox_id_map.pop(key, None);
        return {"running": False, "url": None, "port": 0, "api_port": 0, "status": "none"};
    }
    state_str = status.state.value if hasattr(status.state, "value") else str(status.state);
    if state_str in ("stopped", "error") {
        print(f"[get_preview_status] Sandbox {sid} is {state_str}, cleaning up stale entry");
        _sandbox_id_map.pop(key, None);
        return {"running": False, "url": None, "port": 0, "api_port": 0, "status": "none"};
    }
    is_running = state_str == "running";
    url = status.url;
    if is_running {
        if _is_k8s_sandbox {
            if not url {
                url = _build_k8s_url(str(sid));
            }
        } else {
            template = os.environ.get("JAC_IDE_PREVIEW_PUBLIC_URL_TEMPLATE", "").strip();
            if template and status.port {
                url = _build_preview_url(user_id, status.port, 0);
            }
        }
    }
    return {
        "running": is_running,
        "url": url if is_running else None,
        "port": status.port,
        "api_port": getattr(status, "api_port", 0) or (status.port + 1 if status.port else 0),
        "status": state_str
    };
}

"""List all files in the preview directory, skipping build artifacts."""
def list_preview_files(user_id: str, project_id: str = "", path: str = ".") -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    # If sandbox is running, list from it — fall back to staging on failure
    skip_dirs = [".jac", "node_modules", "__pycache__", "dist", ".git", ".jac-ide"];
    if sid and sandbox is not None {
        result = sandbox.list_files(sid, path);
        if result.get("success") {
            raw = result.get("files", []);
            filtered = [
                f for f in raw
                if not any(f == d or f.startswith(d + "/") for d in skip_dirs)
            ];
            result["files"] = filtered;
            return result;
        }
    }
    # List from local staging dir
    staging = _staging_dirs.get(key);
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    try {
        base = _resolve_local_path(staging, path);
        real_staging = os.path.realpath(staging);
        skip_dirs = [".jac", "node_modules", "__pycache__", "dist", ".git", ".jac-ide"];
        file_list = [];
        for entry in os.walk(base) {
            dirpath = entry[0];
            dirnames = entry[1];
            filenames = entry[2];
            kept = [d for d in dirnames if d not in skip_dirs];
            dirnames.clear();
            for d in kept {
                dirnames.append(d);
            }
            for fname in filenames {
                full = os.path.join(dirpath, fname);
                rel = os.path.relpath(full, real_staging);
                file_list.append(rel);
            }
        }
        file_list.sort();
        return {"success": True, "files": file_list};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Search file contents in the preview directory."""
def search_preview_files(user_id: str, project_id: str = "", query: str = "", case_sensitive: bool = False, max_results: int = 200) -> dict {
    staging = _staging_dirs.get(_preview_key(user_id, project_id));
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    if not query.strip() {
        return {"success": True, "results": [], "total": 0};
    }
    try {
        preview_dir = staging;
        real_preview = os.path.realpath(preview_dir);
        skip_dirs = [".jac", "node_modules", "__pycache__", "dist", ".git", ".jac-ide"];
        binary_exts = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".bmp", ".tiff",
                       ".tif", ".svg", ".woff", ".woff2", ".ttf", ".eot", ".mp3", ".mp4",
                       ".wav", ".ogg", ".pdf", ".zip", ".tar", ".gz", ".wasm", ".jacpack"];
        flags = 0 if case_sensitive else re.IGNORECASE;
        pattern = re.compile(re.escape(query), flags);
        results = [];
        total = 0;
        for entry in os.walk(real_preview) {
            dirpath = entry[0];
            dirnames = entry[1];
            filenames = entry[2];
            kept = [d for d in dirnames if d not in skip_dirs];
            dirnames.clear();
            for d in kept {
                dirnames.append(d);
            }
            for fname in filenames {
                ext = os.path.splitext(fname)[1].lower();
                if ext in binary_exts {
                    continue;
                }
                full = os.path.join(dirpath, fname);
                rel = os.path.relpath(full, real_preview);
                try {
                    with open(full, "r", encoding="utf-8", errors="ignore") as f {
                        lines = f.readlines();
                    }
                    line_num = 0;
                    for line in lines {
                        line_num += 1;
                        if pattern.search(line) {
                            total += 1;
                            if len(results) < max_results {
                                results.append({
                                    "file": rel,
                                    "line": line_num,
                                    "content": line.rstrip("\n\r")[:500]
                                });
                            }
                        }
                    }
                } except Exception {
                    _ = 0;
                }
            }
        }
        return {"success": True, "results": results, "total": total};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Replace all occurrences of a string in preview files, sync to repo, and autosave."""
def replace_in_preview_files(user_id: str, project_id: str, query: str, replace_text: str, case_sensitive: bool = False, file_filter: str = "") -> dict {
    staging = _staging_dirs.get(_preview_key(user_id, project_id));
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    if not query.strip() {
        return {"success": False, "error": "Search query is required"};
    }
    try {
        preview_dir = staging;
        real_preview = os.path.realpath(preview_dir);
        skip_dirs = [".jac", "node_modules", "__pycache__", "dist", ".git", ".jac-ide"];
        binary_exts = [".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico", ".bmp", ".tiff",
                       ".tif", ".svg", ".woff", ".woff2", ".ttf", ".eot", ".mp3", ".mp4",
                       ".wav", ".ogg", ".pdf", ".zip", ".tar", ".gz", ".wasm", ".jacpack"];
        flags = 0 if case_sensitive else re.IGNORECASE;
        pattern = re.compile(re.escape(query), flags);
        replaced_files = [];
        total_replacements = 0;
        for entry in os.walk(real_preview) {
            dirpath = entry[0];
            dirnames = entry[1];
            filenames = entry[2];
            kept = [d for d in dirnames if d not in skip_dirs];
            dirnames.clear();
            for d in kept {
                dirnames.append(d);
            }
            for fname in filenames {
                ext = os.path.splitext(fname)[1].lower();
                if ext in binary_exts {
                    continue;
                }
                full = os.path.join(dirpath, fname);
                rel = os.path.relpath(full, real_preview);
                if file_filter and rel != file_filter {
                    continue;
                }
                try {
                    with open(full, "r", encoding="utf-8", errors="ignore") as f {
                        content = f.read();
                    }
                    new_content = pattern.sub(replace_text, content);
                    if new_content != content {
                        count = len(pattern.findall(content));
                        with open(full, "w", encoding="utf-8") as f {
                            f.write(new_content);
                        }
                        total_replacements += count;
                        replaced_files.append({"file": rel, "count": count});
                    }
                } except Exception {
                    _ = 0;
                }
            }
        }
        return {"success": True, "replaced_files": replaced_files, "total_replacements": total_replacements};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Read a file from the preview directory."""
def read_preview_file(user_id: str, project_id: str = "", path: str = "") -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    # If sandbox is running, read from it — fall back to staging on failure
    if sid {
        result = sandbox.read_file(sid, path);
        if result.get("success") {
            return result;
        }
    }
    # Read from local staging dir
    staging = _staging_dirs.get(key);
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    try {
        full_path = _resolve_local_path(staging, path);
        if not os.path.isfile(full_path) {
            return {"success": False, "error": "File not found"};
        }
        ext = os.path.splitext(path)[1].lower();
        if ext in _IMAGE_MIME_TYPES {
            with open(full_path, "rb") as f {
                raw = f.read();
            }
            b64 = base64.b64encode(raw).decode("utf-8");
            mime = _IMAGE_MIME_TYPES[ext];
            return {"success": True, "path": path, "content": b64, "is_binary": True, "mime_type": mime};
        }
        with open(full_path, "r", encoding="utf-8") as f {
            content = f.read();
        }
        return {"success": True, "path": path, "content": content};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Delete a file or directory from the preview directory."""
def delete_preview_file(user_id: str, project_id: str = "", path: str = "") -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    basename = os.path.basename(path);
    if basename in PROTECTED_FILES {
        return {"success": False, "error": f"Cannot delete protected file: {basename}"};
    }
    if sid {
        return sandbox.delete_file(sid, path);
    }
    staging = _staging_dirs.get(key);
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    try {
        full_path = _resolve_local_path(staging, path);
        if os.path.isfile(full_path) {
            os.remove(full_path);
        } elif os.path.isdir(full_path) {
            shutil.rmtree(full_path);
        } else {
            return {"success": False, "error": "Path not found"};
        }
        return {"success": True, "path": path};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Rename or move a file or directory within the preview directory."""
def rename_preview_item(user_id: str, project_id: str = "", old_path: str = "", new_path: str = "") -> dict {
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if sid {
        sandbox = _get_sandbox();
        read_result = sandbox.read_file(sid, old_path);
        if not read_result.get("success") {
            return {"success": False, "error": "Source path not found"};
        }
        content = read_result.get("content", "");
        write_result = sandbox.write_file(sid, new_path, content);
        if not write_result.get("success") {
            return write_result;
        }
        sandbox.delete_file(sid, old_path);
        return {"success": True, "old_path": old_path, "new_path": new_path, "is_dir": False};
    }
    staging = _staging_dirs.get(key);
    if not staging {
        return {"success": False, "error": "Preview not set up for this user"};
    }
    try {
        full_old = _resolve_local_path(staging, old_path);
        full_new = _resolve_local_path(staging, new_path);
        if not os.path.exists(full_old) {
            return {"success": False, "error": "Source path not found"};
        }
        parent = os.path.dirname(full_new);
        if not os.path.exists(parent) {
            os.makedirs(parent, exist_ok=True);
        }
        is_dir = os.path.isdir(full_old);
        os.rename(full_old, full_new);
        return {"success": True, "old_path": old_path, "new_path": new_path, "is_dir": is_dir};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Read preview log from offset for incremental polling."""
def get_preview_log(user_id: str, project_id: str = "", offset: int = 0) -> dict {
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if not sid {
        return {"success": True, "content": "", "offset": 0};
    }
    return sandbox.logs(sid, offset);
}

"""Get the preview workspace directory for a session."""
def get_preview_dir(user_id: str, project_id: str = "") -> (str | None) {
    key = _preview_key(user_id, project_id);
    # Check staging dir first
    staging = _staging_dirs.get(key);
    if staging {
        return staging;
    }
    sandbox = _get_sandbox();
    sid = _sandbox_id_map.get(key);
    if not sid {
        return None;
    }
    if hasattr(sandbox, "get_sandbox_dir") {
        return sandbox.get_sandbox_dir(sid);
    }
    preview_suffix = f"-{project_id}" if project_id else "";
    import tempfile;
    return os.path.join(tempfile.gettempdir(), f"jac-preview-{user_id}{preview_suffix}");
}

"""Stop preview process and clean up registry entries.
Single-directory architecture: does NOT delete the project directory.
Only removes /tmp dirs if they were created by the old two-dir approach."""
def cleanup_preview(user_id: str, project_id: str = "") -> dict {
    # Stop filesystem watcher
    try {
        import from services.file_watcher { stop_watcher }
        stop_watcher(user_id, project_id);
    } except Exception {
        ;
    }
    sandbox = _get_sandbox();
    key = _preview_key(user_id, project_id);
    sid = _sandbox_id_map.get(key);
    if sid {
        # Use stop() not destroy() — destroy() rmtrees the dir, which in
        # single-dir mode would delete the actual project repo.
        # For K8s, destroy() is safe (deletes ephemeral pod), so use it there.
        if _is_k8s_sandbox {
            sandbox.destroy(sid);
        } else {
            sandbox.stop(sid);
        }
        _sandbox_id_map.pop(key, None);
    }
    # Remove staging dir reference. Only rmtree if it's a /tmp ephemeral dir,
    # never delete the actual project repo directory.
    staging = _staging_dirs.pop(key, None);
    import tempfile;
    tmp_prefix = os.path.join(tempfile.gettempdir(), "jac-preview-");
    if staging and staging.startswith(tmp_prefix) and os.path.exists(staging) {
        shutil.rmtree(staging, ignore_errors=True);
    }
    return {"success": True};
}


# ---------------------------------------------------------------------------
# Sandbox Deploy — lightweight K8s sandbox with 1-week TTL
# Uses a separate SandboxFactory instance so the long TTL doesn't affect
# the normal 30-minute preview sandboxes.
# ---------------------------------------------------------------------------

"""Get or create the long-lived sandbox deploy factory (1-week TTL)."""
def _get_sandbox_deploy() -> Any {
    global _sandbox_deploy;
    if _sandbox_deploy is None {
        try {
            import from jac_scale.factories.sandbox_factory { SandboxFactory }
            import from jac_scale.config_loader { get_scale_config }
            scale_config = get_scale_config();
            cfg = scale_config._config if hasattr(scale_config, "_config") else scale_config;
            sandbox_cfg = cfg.get("sandbox", {}) if isinstance(cfg, dict) else {};
            if sandbox_cfg and sandbox_cfg.get("enabled", False) {
                deploy_cfg = dict(sandbox_cfg);
                deploy_cfg["ttl_seconds"] = 604800;  # 1 week
                deploy_cfg["max_per_user"] = 5;
                sandbox_type = deploy_cfg.get("type", "local");
                env_type = str(os.environ.get("JAC_SANDBOX_TYPE", "")).strip();
                if env_type {
                    sandbox_type = env_type;
                }
                _sandbox_deploy = SandboxFactory.create(sandbox_type, deploy_cfg);
            } else {
                _sandbox_deploy = SandboxFactory.create("local", {"ttl_seconds": 604800});
            }
        } except (ImportError, Exception) as e {
            print(f"[preview_manager] Sandbox deploy init failed: {e}");
            _sandbox_deploy = None;
        }
    }
    return _sandbox_deploy;
}

"""Start a sandbox deployment (lightweight K8s pod with 1-week TTL)."""
def start_sandbox_deploy(user_id: str, project_id: str, source_dir: str) -> dict {
    sandbox = _get_sandbox_deploy();
    if sandbox is None {
        return {"success": False, "error": "Sandbox deploy not available"};
    }
    key = _preview_key(user_id, project_id);

    # Check for existing sandbox
    existing_sid = _sandbox_deploy_id_map.get(key);
    if existing_sid {
        try {
            status = sandbox.status(existing_sid);
            state_str = status.state.value if hasattr(status.state, "value") else str(status.state);
            if state_str not in ("stopped", "error") {
                url = status.url;
                if not url and _is_k8s_sandbox {
                    url = _build_k8s_url(existing_sid);
                }
                return {"success": True, "url": url, "status": state_str};
            }
        } except Exception { _ = 0; }
        _sandbox_deploy_id_map.pop(key, None);
    }

    # Copy project to staging dir
    import tempfile;
    staging = os.path.join(tempfile.gettempdir(), f"jac-sandbox-deploy-{user_id}-{project_id}");
    if os.path.exists(staging) {
        shutil.rmtree(staging, ignore_errors=True);
    }
    shutil.copytree(source_dir, staging,
        ignore=shutil.ignore_patterns('.git', '.jac-ide', '__pycache__', '.jac'));
    _sandbox_deploy_staging[key] = staging;

    # Create sandbox
    result = sandbox.create(user_id, project_id, staging);
    if result.is_successful() {
        _sandbox_deploy_id_map[key] = result.sandbox_id;
        url = result.url;
        if not url and _is_k8s_sandbox {
            url = _build_k8s_url(result.sandbox_id);
        }
        return {"success": True, "url": url or "", "status": "starting", "sandbox_id": result.sandbox_id};
    }
    return {"success": False, "error": result.message or "Failed to create sandbox deploy"};
}

"""Get status of a sandbox deployment."""
def get_sandbox_deploy_status(user_id: str, project_id: str) -> dict {
    sandbox = _get_sandbox_deploy();
    if sandbox is None {
        return {"success": False, "status": "unknown"};
    }
    key = _preview_key(user_id, project_id);
    sid = _sandbox_deploy_id_map.get(key);
    if not sid {
        return {"success": False, "status": "unknown", "error": "No sandbox deploy found"};
    }
    try {
        status = sandbox.status(sid);
        state_str = status.state.value if hasattr(status.state, "value") else str(status.state);
        url = status.url;
        if not url and _is_k8s_sandbox {
            url = _build_k8s_url(sid);
        }
        return {"success": True, "status": state_str, "url": url or ""};
    } except Exception as e {
        return {"success": False, "status": "unknown", "error": str(e)};
    }
}

"""Destroy a sandbox deployment."""
def destroy_sandbox_deploy(user_id: str, project_id: str) -> dict {
    sandbox = _get_sandbox_deploy();
    if sandbox is None {
        return {"success": False, "error": "Sandbox deploy not available"};
    }
    key = _preview_key(user_id, project_id);
    sid = _sandbox_deploy_id_map.get(key);
    if not sid {
        return {"success": False, "error": "No sandbox deploy found"};
    }
    try {
        sandbox.destroy(sid);
        _sandbox_deploy_id_map.pop(key, None);
        staging = _sandbox_deploy_staging.pop(key, None);
        if staging and os.path.exists(staging) {
            shutil.rmtree(staging, ignore_errors=True);
        }
        return {"success": True, "message": "Sandbox deploy destroyed"};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}
