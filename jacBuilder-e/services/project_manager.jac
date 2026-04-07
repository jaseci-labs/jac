"""Project manager for templates, persistent workspaces, git, and jacpack versions."""

import os;
import json;
import time;
import shutil;
import subprocess;
import from pathlib {Path}
import from datetime {datetime}
import from jaclang.project.template_loader {bundle_template}
import from zipfile {ZipFile, is_zipfile}

glob TEMPLATE_MANIFEST_PATH: str = os.path.join(
    getattr(__import__('sys'), '_MEIPASS', os.path.realpath(".")),
    "assets", "templates", "manifest.json"
);
glob DEFAULT_PROJECTS_ROOT: str = os.path.join(str(Path.home()), ".jac-ide", "projects");
glob USER_TEMPLATES_ROOT: str = os.path.join(str(Path.home()), ".jac-ide", "user-templates");
glob MAX_PROJECT_VERSIONS: int = 50;
glob _GITIGNORE_MANAGED_PATTERNS: list[str] = [
    ".jac-ide/",
    "export-*.jacpack",
    ".jac/",
    "__jac_gen__/",
    "node_modules/",
    "dist/",
    "__pycache__/",
    ".env",
    ".jac-preview.log",
    ".jac-ide-bashrc"
];

"""UTC timestamp for metadata."""
def _utc_now() -> str {
    return datetime.utcnow().isoformat() + "Z";
}

"""Run a jac CLI command. In frozen apps, calls jaclang directly in-process.
In normal installs, spawns a subprocess with the jac binary.
Returns dict with success, stdout, stderr.
"""
def _run_jac_command(args: list, cwd: str = "") -> dict {
    import sys;

    # Find jac command — uses --jac-cli for frozen sidecar, jac binary otherwise
    if getattr(sys, 'frozen', False) {
        jac_cmd = [sys.executable, "--jac-cli"];
    } else {
        jac_cmd = _find_jac_binary_list();
    }
    cmd = jac_cmd + args;
    try {
        result = subprocess.run(cmd, cwd=cwd or None, capture_output=True, text=True, encoding="utf-8");
        return {
            "success": result.returncode == 0,
            "stdout": (result.stdout or "").strip(),
            "stderr": (result.stderr or "").strip()
        };
    } except Exception as e {
        return {"success": False, "stdout": "", "stderr": str(e)};
    }
}

"""Find jac binary path. Returns a list for subprocess calls."""
def _find_jac_binary_list() -> list {
    import sys;
    is_windows = sys.platform == "win32";
    bin_dir = "Scripts" if is_windows else "bin";
    jac_name = "jac.exe" if is_windows else "jac";
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
    found = shutil.which("jac");
    if found {
        return [found];
    }
    raise FileNotFoundError("Could not find jac binary");
}

"""Filesystem-safe segment."""
def _safe_segment(value: str, fallback: str = "item") -> str {
    if not value {
        return fallback;
    }
    chars: list[str] = [];
    for ch in value {
        if ch.isalnum() or ch == "_" or ch == "-" {
            chars.append(ch);
        } else {
            chars.append("_");
        }
    }
    safe = "".join(chars).strip("_");
    return safe if safe else fallback;
}

"""Get projects root from env or default."""
def get_projects_root() -> str {
    configured = os.environ.get("JAC_IDE_PROJECTS_ROOT", "").strip();
    return configured if configured else DEFAULT_PROJECTS_ROOT;
}

"""Run a git command in a repository."""
def _run_git(repo_path: str, args: list[str], check: bool = True) -> dict {
    try {
        result = subprocess.run(
            ["git"] + args,
            cwd=repo_path,
            capture_output=True,
            text=True
        );
        ok = result.returncode == 0;
        if check and not ok {
            return {"success": False, "error": result.stderr.strip(), "stdout": result.stdout.strip()};
        }
        return {"success": ok, "stdout": result.stdout.strip(), "stderr": result.stderr.strip()};
    } except Exception as e {
        return {"success": False, "error": str(e), "stdout": ""};
    }
}

"""Git head commit."""
def _git_head(repo_path: str) -> str {
    res = _run_git(repo_path, ["rev-parse", "HEAD"], check=False);
    return res.get("stdout", "") if res.get("success", False) else "";
}

"""Git active branch."""
def _git_branch(repo_path: str) -> str {
    res = _run_git(repo_path, ["rev-parse", "--abbrev-ref", "HEAD"], check=False);
    return res.get("stdout", "") if res.get("success", False) else "";
}

"""Path to jac-ide metadata folder in repo."""
def _repo_meta_dir(repo_path: str) -> str {
    return os.path.join(repo_path, ".jac-ide");
}

"""Path to snapshots directory."""
def _repo_snapshots_dir(repo_path: str) -> str {
    return os.path.join(_repo_meta_dir(repo_path), "snapshots");
}

"""Path to versions file."""
def _repo_versions_file(repo_path: str) -> str {
    return os.path.join(_repo_meta_dir(repo_path), "versions.json");
}

"""Save a base64-encoded screenshot as the project thumbnail."""
def save_project_thumbnail(repo_path: str, image_base64: str) -> dict {
    try {
        import base64;
        meta_dir = _repo_meta_dir(repo_path);
        os.makedirs(meta_dir, exist_ok=True);
        thumb_path = os.path.join(meta_dir, "thumbnail.jpg");
        image_bytes = base64.b64decode(image_base64);
        with open(thumb_path, "wb") as f {
            f.write(image_bytes);
        }
        return {"success": True, "path": thumb_path};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Read the project thumbnail and return as base64."""
def get_project_thumbnail(repo_path: str) -> dict {
    try {
        import base64;
        thumb_path = os.path.join(_repo_meta_dir(repo_path), "thumbnail.jpg");
        if not os.path.exists(thumb_path) {
            return {"success": False, "error": "No thumbnail found"};
        }
        with open(thumb_path, "rb") as f {
            image_bytes = f.read();
        }
        return {
            "success": True,
            "image": base64.b64encode(image_bytes).decode("utf-8"),
            "mime_type": "image/jpeg"
        };
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Check if a project has a thumbnail."""
def has_project_thumbnail(repo_path: str) -> bool {
    thumb_path = os.path.join(_repo_meta_dir(repo_path), "thumbnail.jpg");
    return os.path.exists(thumb_path);
}

"""Ensure internal metadata files are not git-tracked."""
def _ensure_repo_metadata_ignored(repo_path: str) -> None {
    try {
        gitignore_path = os.path.join(repo_path, ".gitignore");
        existing_lines: list[str] = [];
        if os.path.exists(gitignore_path) {
            with open(gitignore_path, "r", encoding="utf-8") as f {
                existing_lines = [line.rstrip("\n") for line in f.readlines()];
            }
        }
        append_lines: list[str] = [];
        for pattern in _GITIGNORE_MANAGED_PATTERNS {
            if not (pattern in existing_lines) {
                append_lines.append(pattern);
            }
        }
        if len(append_lines) > 0 {
            with open(gitignore_path, "a", encoding="utf-8") as f {
                if len(existing_lines) > 0 and existing_lines[-1].strip() != "" {
                    f.write("\n");
                }
                for pattern in append_lines {
                    f.write(pattern + "\n");
                }
            }
        }
    } except Exception {
    }
    _run_git(repo_path, ["rm", "-r", "--cached", "--ignore-unmatch", ".jac-ide"], check=False);
}

"""Ensure jac.toml has [jacpack] section for bundling."""
def _ensure_jacpack_section(repo_path: str, name: str) -> None {
    toml_path = os.path.join(repo_path, "jac.toml");
    if not os.path.exists(toml_path) {
        return;
    }
    content = "";
    with open(toml_path, "r", encoding="utf-8") as f {
        content = f.read();
    }
    if "[jacpack]" in content {
        return;
    }
    with open(toml_path, "a", encoding="utf-8") as f {
        f.write("\n[jacpack]\n");
        f.write("name = '" + name + "'\n");
        f.write("description = 'Jac IDE snapshot for " + name + "'\n");
    }
}

"""Load version list from repo metadata."""
def _load_versions(repo_path: str) -> list[dict] {
    versions_file = _repo_versions_file(repo_path);
    if not os.path.exists(versions_file) {
        return [];
    }
    try {
        with open(versions_file, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
        if isinstance(data, list) {
            return data;
        }
    } except Exception {
    }
    return [];
}

"""Write version list to repo metadata."""
def _save_versions(repo_path: str, versions: list[dict]) -> None {
    os.makedirs(_repo_meta_dir(repo_path), exist_ok=True);
    versions_file = _repo_versions_file(repo_path);
    with open(versions_file, "w", encoding="utf-8") as f {
        json.dump(versions, f, indent=2);
    }
}

"""Create a snapshot from current repo tree."""
def create_project_snapshot(repo_path: str, commit_sha: str = "") -> dict {
    try {
        os.makedirs(_repo_snapshots_dir(repo_path), exist_ok=True);
        stamp = str(int(time.time() * 1000));
        short_sha = commit_sha[0:8] if commit_sha else "working";
        output = os.path.join(_repo_snapshots_dir(repo_path), f"{stamp}_{short_sha}.jacpack");
        _ensure_jacpack_section(repo_path, os.path.basename(repo_path));
        bundle_template(Path(repo_path), Path(output));
        return {"success": True, "jacpack_path": output};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Record one version and enforce rolling retention."""
def record_project_version(repo_path: str, commit_sha: str, jacpack_path: str, trigger: str = "autosave") -> dict {
    versions = _load_versions(repo_path);
    entry = {
        "id": "ver_" + str(int(time.time() * 1000)),
        "commit_sha": commit_sha,
        "jacpack_path": jacpack_path,
        "created_at": _utc_now(),
        "trigger": trigger
    };
    versions.append(entry);

    removed: list[dict] = [];
    if len(versions) > MAX_PROJECT_VERSIONS {
        drop_count = len(versions) - MAX_PROJECT_VERSIONS;
        removed = versions[0:drop_count];
        versions = versions[drop_count:];
        for old in removed {
            old_path = old.get("jacpack_path", "");
            if old_path and os.path.exists(old_path) {
                try {
                    os.remove(old_path);
                } except Exception {
                }
            }
        }
    }

    _save_versions(repo_path, versions);
    return {"success": True, "entry": entry, "removed": removed};
}

"""Commit current repo changes."""
def commit_all_changes(repo_path: str, message: str) -> dict {
    _ensure_repo_metadata_ignored(repo_path);
    status = _run_git(repo_path, ["status", "--porcelain"], check=False);
    if not status.get("success", False) {
        return {"success": False, "error": status.get("error", "git status failed")};
    }
    if not status.get("stdout", "").strip() {
        return {"success": True, "skipped": True, "commit": _git_head(repo_path)};
    }
    add = _run_git(repo_path, ["add", "-A"], check=True);
    if not add.get("success", False) {
        return {"success": False, "error": add.get("error", "git add failed")};
    }
    commit = _run_git(repo_path, ["commit", "-m", message], check=False);
    if not commit.get("success", False) {
        return {"success": False, "error": commit.get("stderr", "git commit failed")};
    }
    return {"success": True, "commit": _git_head(repo_path)};
}

glob _autosave_timestamps: dict = {};
glob _AUTOSAVE_DEBOUNCE_SECONDS: int = 10;

"""Autosave flow: commit + snapshot + version metadata.
Debounced: skips if last autosave for this repo was less than 10s ago,
unless the trigger is not 'autosave' (e.g. 'claude_chat', 'init')."""
def autosave_version(repo_path: str, trigger: str = "autosave", message: str = "chore: autosave") -> dict {
    import time as _time;
    now = _time.time();
    if trigger == "autosave" {
        last = _autosave_timestamps.get(repo_path, 0);
        if (now - last) < _AUTOSAVE_DEBOUNCE_SECONDS {
            return {"success": True, "skipped": True, "debounced": True, "commit_sha": "", "version": None};
        }
    }
    _autosave_timestamps[repo_path] = now;
    commit = commit_all_changes(repo_path, message);
    if not commit.get("success", False) {
        return commit;
    }
    if commit.get("skipped", False) {
        return {"success": True, "skipped": True, "commit_sha": commit.get("commit", ""), "version": None};
    }
    commit_sha = commit.get("commit", "");
    snap = create_project_snapshot(repo_path, commit_sha);
    if not snap.get("success", False) {
        return {"success": False, "error": snap.get("error", "snapshot failed")};
    }
    recorded = record_project_version(repo_path, commit_sha, snap.get("jacpack_path", ""), trigger);
    if not recorded.get("success", False) {
        return recorded;
    }
    return {
        "success": True,
        "commit_sha": commit_sha,
        "version": recorded.get("entry"),
        "removed_versions": recorded.get("removed", [])
    };
}

"""Get all versions for a project."""
def list_project_versions(repo_path: str) -> list[dict] {
    versions = _load_versions(repo_path);
    versions.sort(key=lambda item: item.get("created_at", ""), reverse=True);
    return versions;
}

"""Checkout one commit in a project."""
def checkout_project_commit(repo_path: str, commit_sha: str) -> dict {
    if not commit_sha {
        return {"success": False, "error": "commit_sha is required"};
    }
    versions_snapshot = _load_versions(repo_path);
    res = _run_git(repo_path, ["checkout", "-f", commit_sha], check=False);
    if not res.get("success", False) {
        return {"success": False, "error": res.get("stderr", "checkout failed")};
    }
    if versions_snapshot and len(versions_snapshot) > 0 {
        _save_versions(repo_path, versions_snapshot);
    }
    _ensure_repo_metadata_ignored(repo_path);
    return {"success": True, "commit_sha": _git_head(repo_path), "active_branch": _git_branch(repo_path)};
}

"""Export jacpack for a version or current workspace."""
def export_project_jacpack(repo_path: str, version_id: str = "", output_path: str = "") -> dict {
    target = output_path or os.path.join(repo_path, f"export-{int(time.time())}.jacpack");
    if version_id {
        versions = _load_versions(repo_path);
        for version in versions {
            if version.get("id", "") == version_id {
                source = version.get("jacpack_path", "");
                if source and os.path.exists(source) {
                    shutil.copy2(source, target);
                    return {"success": True, "output_path": target, "version_id": version_id};
                }
                return {"success": False, "error": "Snapshot file missing"};
            }
        }
        return {"success": False, "error": "Version not found"};
    }
    snap = create_project_snapshot(repo_path, _git_head(repo_path));
    if not snap.get("success", False) {
        return {"success": False, "error": snap.get("error", "snapshot failed")};
    }
    shutil.copy2(snap.get("jacpack_path", ""), target);
    return {"success": True, "output_path": target};
}

"""Delete project workspace from disk."""
def delete_project_workspace(repo_path: str) -> dict {
    try {
        if repo_path and os.path.exists(repo_path) {
            shutil.rmtree(repo_path, ignore_errors=True);
        }
        return {"success": True};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Load template manifest entries."""
def _load_template_manifest() -> list[dict] {
    if not os.path.exists(TEMPLATE_MANIFEST_PATH) {
        return [];
    }
    try {
        with open(TEMPLATE_MANIFEST_PATH, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
        templates = data.get("templates", []) if isinstance(data, dict) else [];
        result: list[dict] = [];
        base_dir = os.path.dirname(TEMPLATE_MANIFEST_PATH);
        for item in templates {
            if isinstance(item, dict) {
                rel_path = item.get("path", "");
                abs_path = os.path.realpath(os.path.join(base_dir, rel_path));
                if item.get("id", "") and item.get("name", "") and os.path.exists(abs_path) {
                    result.append(
                        {
                            "id": item.get("id", ""),
                            "name": item.get("name", ""),
                            "description": item.get("description", ""),
                            "path": rel_path,
                            "abs_path": abs_path
                        }
                    );
                }
            }
        }
        return result;
    } except Exception {
        return [];
    }
}

"""List curated templates."""
def list_templates() -> list[dict] {
    rows = _load_template_manifest();
    result: list[dict] = [];
    for row in rows {
        result.append(
            {
                "id": row.get("id", ""),
                "name": row.get("name", ""),
                "description": row.get("description", ""),
                "path": row.get("path", "")
            }
        );
    }
    return result;
}

"""Get one template by id."""
def get_template(template_id: str) -> dict {
    rows = _load_template_manifest();
    for row in rows {
        if row.get("id", "") == template_id {
            return {
                "success": True,
                "template": {
                    "id": row.get("id", ""),
                    "name": row.get("name", ""),
                    "description": row.get("description", ""),
                    "path": row.get("path", "")
                },
                "abs_path": row.get("abs_path", "")
            };
        }
    }
    return {"success": False, "error": "Template not found"};
}

"""Save an imported JacPack as a persistent user template."""
def save_user_template(user_id: str, name: str, jacpack_path: str) -> dict {
    try {
        user_dir = os.path.join(USER_TEMPLATES_ROOT, _safe_segment(user_id, "user"));
        os.makedirs(user_dir, exist_ok=True);
        manifest_path = os.path.join(user_dir, "manifest.json");

        existing: list[dict] = [];
        if os.path.exists(manifest_path) {
            try {
                with open(manifest_path, "r", encoding="utf-8") as f {
                    data = json.load(f);
                }
                existing = data if isinstance(data, list) else [];
            } except Exception {
                existing = [];
            }
        }

        template_id = "user_" + str(int(time.time() * 1000));
        dest_path = os.path.join(user_dir, template_id + ".jacpack");
        shutil.copy2(jacpack_path, dest_path);

        entry: dict = {
            "id": template_id,
            "name": name,
            "created_at": _utc_now(),
            "jacpack": template_id + ".jacpack"
        };
        existing.append(entry);

        with open(manifest_path, "w", encoding="utf-8") as f {
            json.dump(existing, f, indent=2);
        }

        return {"success": True, "template": entry};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""List user-uploaded templates."""
def list_user_templates(user_id: str) -> list[dict] {
    user_dir = os.path.join(USER_TEMPLATES_ROOT, _safe_segment(user_id, "user"));
    manifest_path = os.path.join(user_dir, "manifest.json");
    if not os.path.exists(manifest_path) {
        return [];
    }
    try {
        with open(manifest_path, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
        entries = data if isinstance(data, list) else [];
        result: list[dict] = [];
        for entry in entries {
            abs_path = os.path.join(user_dir, entry.get("jacpack", ""));
            if os.path.exists(abs_path) {
                result.append({
                    "id": entry.get("id", ""),
                    "name": entry.get("name", ""),
                    "description": "Uploaded template",
                    "created_at": entry.get("created_at", ""),
                    "type": "user"
                });
            }
        }
        return result;
    } except Exception {
        return [];
    }
}

"""Get a user template's abs_path for project creation."""
def get_user_template(user_id: str, template_id: str) -> dict {
    user_dir = os.path.join(USER_TEMPLATES_ROOT, _safe_segment(user_id, "user"));
    manifest_path = os.path.join(user_dir, "manifest.json");
    if not os.path.exists(manifest_path) {
        return {"success": False, "error": "No user templates found"};
    }
    try {
        with open(manifest_path, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
        entries = data if isinstance(data, list) else [];
        for entry in entries {
            if entry.get("id", "") == template_id {
                abs_path = os.path.join(user_dir, entry.get("jacpack", ""));
                if os.path.exists(abs_path) {
                    return {"success": True, "abs_path": abs_path, "name": entry.get("name", "")};
                }
            }
        }
        return {"success": False, "error": "User template not found"};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Create workspace from template using jac create and initialize git metadata."""
def create_project_workspace(user_id: str, project_name: str, template_id: str) -> dict {
    try {
        template_res = get_template(template_id);
        if not template_res.get("success", False) {
            return template_res;
        }
        template_path = template_res.get("abs_path", "");
        if not template_path or not os.path.exists(template_path) {
            return {"success": False, "error": "Template file not found"};
        }

        safe_user = _safe_segment(user_id, "user");
        projects_root = get_projects_root();
        user_root = os.path.join(projects_root, safe_user);
        os.makedirs(user_root, exist_ok=True);

        project_id = "prj_" + str(int(time.time() * 1000));
        create_res = _run_jac_command(["create", project_id, "--use", template_path, "--force", "--skip"], cwd=user_root);
        if not create_res.get("success") {
            create_res = _run_jac_command(["create", project_id, "--use", template_path, "--force"], cwd=user_root);
            if not create_res.get("success") {
                return {"success": False, "error": create_res.get("stderr", "") or "jac create failed"};
            }
        }

        repo_path = os.path.join(user_root, project_id);
        if not os.path.isdir(repo_path) {
            return {"success": False, "error": "Project directory was not created"};
        }

        _ensure_jacpack_section(repo_path, _safe_segment(project_name, "project"));
        init_res = _run_git(repo_path, ["init"], check=True);
        if not init_res.get("success", False) {
            return {"success": False, "error": init_res.get("error", "git init failed")};
        }
        _ensure_repo_metadata_ignored(repo_path);
        _run_git(repo_path, ["config", "user.name", "Jac IDE"], check=False);
        _run_git(repo_path, ["config", "user.email", "jac-ide@local"], check=False);
        _run_git(repo_path, ["checkout", "-B", "main"], check=False);
        add_res = _run_git(repo_path, ["add", "-A"], check=True);
        if not add_res.get("success", False) {
            return {"success": False, "error": add_res.get("error", "git add failed")};
        }
        commit_res = _run_git(
            repo_path,
            ["commit", "-m", f"chore: initialize project from template {template_id}"],
            check=False
        );
        if not commit_res.get("success", False) and "nothing to commit" not in commit_res.get("stderr", "") {
            return {"success": False, "error": commit_res.get("stderr", "git commit failed")};
        }

        head = _git_head(repo_path);
        branch = _git_branch(repo_path);
        init_snap = create_project_snapshot(repo_path, head);
        if init_snap.get("success", False) {
            record_project_version(repo_path, head, init_snap.get("jacpack_path", ""), "init");
        }

        now = _utc_now();
        return {
            "success": True,
            "project": {
                "id": project_id,
                "user_id": safe_user,
                "name": _safe_segment(project_name, "project"),
                "template_id": template_id,
                "repo_path": repo_path,
                "created_at": now,
                "updated_at": now,
                "active_branch": branch,
                "last_commit": head
            }
        };
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Sanitize a jacpack file by stripping dangerous fields like post_create_hook.
Returns the path to a safe copy (caller must clean up), or empty string on failure."""
def _sanitize_jacpack(jacpack_path: str) -> str {
    try {
        if is_zipfile(jacpack_path) {
            return jacpack_path;
        }
        with open(jacpack_path, "r", encoding="utf-8") as f {
            data = json.load(f);
        }
        if not isinstance(data, dict) {
            return jacpack_path;
        }
        dirty = False;
        for dangerous_key in ["post_create_hook", "pre_create_hook"] {
            if dangerous_key in data {
                del data[dangerous_key];
                dirty = True;
            }
        }
        if not dirty {
            return jacpack_path;
        }
        safe_path = jacpack_path + ".safe";
        with open(safe_path, "w", encoding="utf-8") as f {
            json.dump(data, f, indent=2);
        }
        return safe_path;
    } except Exception {
        return jacpack_path;
    }
}

"""Create workspace from an arbitrary jacpack file path (upload or URL download)."""
def create_project_from_jacpack(user_id: str, project_name: str, jacpack_path: str) -> dict {
    try {
        if not jacpack_path or not os.path.exists(jacpack_path) {
            return {"success": False, "error": "JacPack file not found"};
        }

        safe_jacpack = _sanitize_jacpack(jacpack_path);

        safe_user = _safe_segment(user_id, "user");
        projects_root = get_projects_root();
        user_root = os.path.join(projects_root, safe_user);
        os.makedirs(user_root, exist_ok=True);

        project_id = "prj_" + str(int(time.time() * 1000));
        create_res = _run_jac_command(["create", project_id, "--use", safe_jacpack, "--force", "--skip"], cwd=user_root);
        if not create_res.get("success") {
            create_res = _run_jac_command(["create", project_id, "--use", safe_jacpack, "--force"], cwd=user_root);
            if not create_res.get("success") {
                if safe_jacpack != jacpack_path and os.path.exists(safe_jacpack) {
                    try { os.remove(safe_jacpack); } except Exception { }
                }
                return {"success": False, "error": create_res.get("stderr", "") or "jac create failed"};
            }
        }
        if safe_jacpack != jacpack_path and os.path.exists(safe_jacpack) {
            try { os.remove(safe_jacpack); } except Exception { }
        }

        repo_path = os.path.join(user_root, project_id);
        if not os.path.isdir(repo_path) {
            return {"success": False, "error": "Project directory was not created"};
        }

        _ensure_jacpack_section(repo_path, _safe_segment(project_name, "project"));
        init_res = _run_git(repo_path, ["init"], check=True);
        if not init_res.get("success", False) {
            return {"success": False, "error": init_res.get("error", "git init failed")};
        }
        _ensure_repo_metadata_ignored(repo_path);
        _run_git(repo_path, ["config", "user.name", "Jac IDE"], check=False);
        _run_git(repo_path, ["config", "user.email", "jac-ide@local"], check=False);
        _run_git(repo_path, ["checkout", "-B", "main"], check=False);
        add_res = _run_git(repo_path, ["add", "-A"], check=True);
        if not add_res.get("success", False) {
            return {"success": False, "error": add_res.get("error", "git add failed")};
        }
        commit_res = _run_git(
            repo_path,
            ["commit", "-m", "chore: initialize project from uploaded jacpack"],
            check=False
        );
        if not commit_res.get("success", False) and "nothing to commit" not in commit_res.get("stderr", "") {
            return {"success": False, "error": commit_res.get("stderr", "git commit failed")};
        }

        head = _git_head(repo_path);
        branch = _git_branch(repo_path);
        init_snap = create_project_snapshot(repo_path, head);
        if init_snap.get("success", False) {
            record_project_version(repo_path, head, init_snap.get("jacpack_path", ""), "import");
        }

        now = _utc_now();
        return {
            "success": True,
            "project": {
                "id": project_id,
                "user_id": safe_user,
                "name": _safe_segment(project_name, "project"),
                "template_id": "uploaded",
                "repo_path": repo_path,
                "created_at": now,
                "updated_at": now,
                "active_branch": branch,
                "last_commit": head
            }
        };
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Read a .env file and return [{key, value}] list (skip blank lines and comments)."""
def read_project_env(env_path: str) -> list[dict] {
    if not os.path.exists(env_path) {
        return [];
    }
    try {
        result: list[dict] = [];
        with open(env_path, "r", encoding="utf-8") as f {
            for line in f {
                line = line.rstrip("\n").rstrip("\r");
                stripped = line.strip();
                if not stripped or stripped.startswith("#") {
                    continue;
                }
                if "=" in stripped {
                    idx = stripped.index("=");
                    key = stripped[0:idx].strip();
                    value = stripped[idx + 1:];
                    if key {
                        result.append({"key": key, "value": value});
                    }
                }
            }
        }
        return result;
    } except Exception {
        return [];
    }
}

"""Write [{key, value}] list to a .env file."""
def write_project_env(env_path: str, env_list: list[dict]) -> dict {
    try {
        parent = os.path.dirname(env_path);
        if parent and not os.path.exists(parent) {
            os.makedirs(parent, exist_ok=True);
        }
        with open(env_path, "w", encoding="utf-8") as f {
            for entry in env_list {
                key = entry.get("key", "").strip();
                value = entry.get("value", "");
                if key {
                    f.write(key + "=" + value + "\n");
                }
            }
        }
        return {"success": True};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}

"""Get git status metadata for a project."""
def get_project_status(repo_path: str) -> dict {
    if not repo_path or not os.path.isdir(repo_path) {
        return {"success": False, "error": "Project repo not found"};
    }
    status = _run_git(repo_path, ["status", "--porcelain"], check=False);
    return {
        "success": True,
        "active_branch": _git_branch(repo_path),
        "last_commit": _git_head(repo_path),
        "dirty": bool(status.get("stdout", "").strip())
    };
}
