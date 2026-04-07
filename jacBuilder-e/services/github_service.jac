import os;
import time;
import tempfile;
import subprocess;


# ===========================================================================
# Configuration
# ===========================================================================


# ===========================================================================
# Token Encryption (at-rest protection for stored OAuth tokens)
# ===========================================================================

"""Encrypt a token for storage. Returns the encrypted string or plaintext if no key configured."""
def encrypt_token(token: str) -> str {
    if not token {
        return "";
    }
    key = os.environ.get("GITHUB_TOKEN_ENCRYPTION_KEY", "");
    if not key {
        return token;
    }
    try {
        fernet_mod = __import__("cryptography.fernet", fromlist=["Fernet"]);
        f = fernet_mod.Fernet(key.encode());
        return "enc:" + f.encrypt(token.encode()).decode();
    } except Exception {
        return token;
    }
}


"""Decrypt a stored token. Handles both encrypted ('enc:' prefix) and legacy plaintext."""
def decrypt_token(stored: str) -> str {
    if not stored {
        return "";
    }
    if not stored.startswith("enc:") {
        return stored;
    }
    key = os.environ.get("GITHUB_TOKEN_ENCRYPTION_KEY", "");
    if not key {
        return "";
    }
    try {
        fernet_mod = __import__("cryptography.fernet", fromlist=["Fernet"]);
        f = fernet_mod.Fernet(key.encode());
        return f.decrypt(stored[4:].encode()).decode();
    } except Exception {
        return "";
    }
}


"""Get GitHub OAuth client credentials for repo operations from environment."""
def _get_github_credentials() -> dict {
    return {
        "client_id": os.environ.get("GITHUB_REPO_CLIENT_ID", ""),
        "client_secret": os.environ.get("GITHUB_REPO_CLIENT_SECRET", "")
    };
}


"""Sanitize exception messages to avoid leaking internal details."""
def _safe_error(e: Exception) -> str {
    msg = str(e);
    # Allow known GitHub API error messages through
    if "GitHub" in msg or "HTTP" in msg or "timeout" in msg or "timed out" in msg {
        return msg;
    }
    return "An internal error occurred during GitHub operation";
}


# ===========================================================================
# OAuth Token Exchange
# ===========================================================================

"""Exchange GitHub OAuth authorization code for an access token."""
def github_exchange_code(code: str) -> dict {
    creds = _get_github_credentials();
    if not creds["client_id"] or not creds["client_secret"] {
        return {"success": False, "error": "GitHub OAuth not configured"};
    }

    try {
        import httpx;
        with httpx.Client(timeout=15.0) as client {
            response = client.post(
                "https://github.com/login/oauth/access_token",
                headers={"Accept": "application/json"},
                data={
                    "client_id": creds["client_id"],
                    "client_secret": creds["client_secret"],
                    "code": code
                }
            );
        }

        if response.status_code != 200 {
            return {"success": False, "error": "GitHub returned status " + str(response.status_code)};
        }

        data = response.json();
        if "error" in data {
            return {"success": False, "error": data.get("error_description", data.get("error", "Unknown error"))};
        }

        result: dict = {
            "success": True,
            "access_token": data.get("access_token", ""),
            "scope": data.get("scope", ""),
            "token_type": data.get("token_type", "bearer")
        };
        # GitHub App tokens include refresh_token and expiry
        if data.get("refresh_token") {
            result["refresh_token"] = data.get("refresh_token", "");
        }
        if data.get("expires_in") {
            result["expires_at"] = time.time() + int(data.get("expires_in", 0));
        }
        return result;
    } except Exception as e {
        return {"success": False, "error": _safe_error(e)};
    }
}


"""Refresh an expired GitHub App user OAuth token using a refresh token."""
def github_refresh_user_token(refresh_token: str) -> dict {
    creds = _get_github_credentials();
    if not creds["client_id"] or not creds["client_secret"] {
        return {"success": False, "error": "GitHub OAuth not configured"};
    }
    if not refresh_token {
        return {"success": False, "error": "No refresh token available"};
    }

    try {
        import httpx;
        with httpx.Client(timeout=15.0) as client {
            response = client.post(
                "https://github.com/login/oauth/access_token",
                headers={"Accept": "application/json"},
                data={
                    "client_id": creds["client_id"],
                    "client_secret": creds["client_secret"],
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token
                }
            );
        }

        if response.status_code != 200 {
            return {"success": False, "error": "GitHub returned status " + str(response.status_code)};
        }

        data = response.json();
        if "error" in data {
            return {"success": False, "error": data.get("error_description", data.get("error", "Token refresh failed"))};
        }

        result: dict = {
            "success": True,
            "access_token": data.get("access_token", ""),
            "token_type": data.get("token_type", "bearer")
        };
        if data.get("refresh_token") {
            result["refresh_token"] = data.get("refresh_token", "");
        }
        if data.get("expires_in") {
            result["expires_at"] = time.time() + int(data.get("expires_in", 0));
        }
        return result;
    } except Exception as e {
        return {"success": False, "error": _safe_error(e)};
    }
}


"""Fetch GitHub user profile using an access token."""
def github_get_user(access_token: str) -> dict {
    try {
        import httpx;
        with httpx.Client(timeout=10.0) as client {
            response = client.get(
                "https://api.github.com/user",
                headers={
                    "Authorization": "Bearer " + access_token,
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28"
                }
            );
        }

        if response.status_code != 200 {
            return {"success": False, "error": "GitHub API returned " + str(response.status_code)};
        }

        data = response.json();
        return {
            "success": True,
            "login": data.get("login", ""),
            "id": data.get("id", 0),
            "name": data.get("name", ""),
            "email": data.get("email", ""),
            "avatar_url": data.get("avatar_url", "")
        };
    } except Exception as e {
        return {"success": False, "error": _safe_error(e)};
    }
}


# ===========================================================================
# GitHub API — Repository Operations
# ===========================================================================

"""Common headers for GitHub API calls."""
def _github_headers(access_token: str) -> dict {
    return {
        "Authorization": "Bearer " + access_token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28"
    };
}


"""List repositories for the authenticated user."""
def github_list_repos(access_token: str, page: int = 1, per_page: int = 30, sort: str = "updated") -> dict {
    try {
        import httpx;
        with httpx.Client(timeout=15.0) as client {
            response = client.get(
                "https://api.github.com/user/repos",
                headers=_github_headers(access_token),
                params={
                    "page": page,
                    "per_page": per_page,
                    "sort": sort,
                    "affiliation": "owner",
                    "direction": "desc"
                }
            );
        }

        if response.status_code != 200 {
            return {"success": False, "error": "GitHub API returned " + str(response.status_code)};
        }

        repos = [];
        for repo in response.json() {
            repos.append({
                "id": repo.get("id", 0),
                "name": repo.get("name", ""),
                "full_name": repo.get("full_name", ""),
                "private": repo.get("private", False),
                "html_url": repo.get("html_url", ""),
                "clone_url": repo.get("clone_url", ""),
                "description": repo.get("description", ""),
                "default_branch": repo.get("default_branch", "main"),
                "updated_at": repo.get("updated_at", ""),
                "language": repo.get("language", "")
            });
        }

        return {"success": True, "repos": repos};
    } except Exception as e {
        return {"success": False, "error": _safe_error(e)};
    }
}


"""Create a new GitHub repository."""
def github_create_repo(access_token: str, name: str, private: bool = True, description: str = "") -> dict {
    try {
        payload: dict = {
            "name": name,
            "private": private,
            "auto_init": False
        };
        if description {
            payload["description"] = description;
        }

        import httpx;
        with httpx.Client(timeout=15.0) as client {
            response = client.post(
                "https://api.github.com/user/repos",
                headers=_github_headers(access_token),
                json=payload
            );
        }

        if response.status_code != 200 and response.status_code != 201 {
            err_data = response.json();
            return {"success": False, "error": err_data.get("message", "Failed to create repo")};
        }

        repo = response.json();
        return {
            "success": True,
            "repo": {
                "id": repo.get("id", 0),
                "name": repo.get("name", ""),
                "full_name": repo.get("full_name", ""),
                "private": repo.get("private", False),
                "html_url": repo.get("html_url", ""),
                "clone_url": repo.get("clone_url", ""),
                "ssh_url": repo.get("ssh_url", ""),
                "default_branch": repo.get("default_branch", "main")
            }
        };
    } except Exception as e {
        return {"success": False, "error": _safe_error(e)};
    }
}


"""Create a pull request on a GitHub repository."""
def github_create_pr(
    access_token: str,
    owner: str,
    repo: str,
    title: str,
    head: str,
    base: str = "main",
    body: str = ""
) -> dict {
    try {
        import httpx;
        with httpx.Client(timeout=15.0) as client {
            response = client.post(
                "https://api.github.com/repos/" + owner + "/" + repo + "/pulls",
                headers=_github_headers(access_token),
                json={
                    "title": title,
                    "head": head,
                    "base": base,
                    "body": body
                }
            );
        }

        if response.status_code != 200 and response.status_code != 201 {
            err_data = response.json();
            return {"success": False, "error": err_data.get("message", "Failed to create PR")};
        }

        pr = response.json();
        return {
            "success": True,
            "pr": {
                "id": pr.get("id", 0),
                "number": pr.get("number", 0),
                "title": pr.get("title", ""),
                "html_url": pr.get("html_url", ""),
                "state": pr.get("state", ""),
                "head_branch": pr.get("head", {}).get("ref", ""),
                "base_branch": pr.get("base", {}).get("ref", "")
            }
        };
    } except Exception as e {
        return {"success": False, "error": _safe_error(e)};
    }
}


# ===========================================================================
# Token Revocation
# ===========================================================================

"""Revoke a GitHub OAuth token via the GitHub API.

Uses HTTP Basic auth with client_id:client_secret as required by GitHub's
DELETE /applications/{client_id}/grant endpoint.
"""
def github_revoke_token(access_token: str) -> dict {
    creds = _get_github_credentials();
    if not creds["client_id"] or not creds["client_secret"] {
        return {"success": False, "error": "GitHub OAuth not configured"};
    }

    try {
        import httpx;
        with httpx.Client(timeout=10.0) as client {
            response = client.request(
                "DELETE",
                "https://api.github.com/applications/" + creds["client_id"] + "/grant",
                auth=(creds["client_id"], creds["client_secret"]),
                json={"access_token": access_token},
                headers={
                    "Accept": "application/vnd.github+json",
                    "X-GitHub-Api-Version": "2022-11-28"
                }
            );
        }
        # 204 No Content = success
        if response.status_code == 204 {
            return {"success": True};
        }
        return {"success": False, "error": "GitHub returned status " + str(response.status_code)};
    } except Exception {
        # Token revocation failure is non-critical — don't block disconnect
        return {"success": False, "error": "Failed to revoke token on GitHub"};
    }
}


"""Check if a GitHub repository exists and is accessible by the authenticated user."""
def github_check_repo_exists(access_token: str, owner: str, repo_name: str) -> dict {
    try {
        import httpx;
        with httpx.Client(timeout=10.0) as client {
            response = client.get(
                "https://api.github.com/repos/" + owner + "/" + repo_name,
                headers=_github_headers(access_token)
            );
        }

        if response.status_code == 200 {
            data = response.json();
            return {
                "success": True,
                "exists": True,
                "permissions": data.get("permissions", {}),
                "clone_url": data.get("clone_url", "")
            };
        }
        if response.status_code == 404 {
            return {"success": True, "exists": False};
        }
        return {"success": False, "error": "GitHub API returned " + str(response.status_code)};
    } except Exception as e {
        return {"success": False, "error": _safe_error(e)};
    }
}


# ===========================================================================
# Git Credential Injection
# ===========================================================================

"""Run a git command with GitHub token authentication via GIT_ASKPASS.

Git asks for username then password separately via the askpass script.
For OAuth App tokens: token as username, 'x-oauth-basic' as password.
"""
def run_git_authenticated(repo_path: str, args: list, access_token: str, timeout: int = 60) -> dict {
    askpass_dir = tempfile.gettempdir();
    askpass_path = os.path.join(askpass_dir, "gh_askpass_" + str(int(time.time() * 1000)) + ".sh");

    # OAuth tokens: use token as username, 'x-oauth-basic' as password
    script_content = "#!/bin/sh\n";
    script_content = script_content + "case \"$1\" in\n";
    script_content = script_content + "  *sername*) echo \"" + access_token + "\" ;;\n";
    script_content = script_content + "  *) echo \"x-oauth-basic\" ;;\n";
    script_content = script_content + "esac\n";

    # Create file with restricted permissions atomically (owner-only rwx from the start)
    fd = os.open(askpass_path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o700);
    with os.fdopen(fd, "w") as f {
        f.write(script_content);
    }

    try {
        env = os.environ.copy();
        env["GIT_ASKPASS"] = askpass_path;
        env["GIT_TERMINAL_PROMPT"] = "0";

        # Disable system/global credential helpers (e.g. gh auth, osxkeychain)
        # so they don't intercept and use cached credentials instead of our token.
        # -c credential.helper= clears all helpers, forcing git to use GIT_ASKPASS.
        git_cmd = ["git", "-c", "credential.helper="] + args;

        result = subprocess.run(
            git_cmd,
            cwd=repo_path,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env
        );

        _cleanup_askpass(askpass_path);

        ok = result.returncode == 0;
        return {
            "success": ok,
            "stdout": result.stdout.strip(),
            "stderr": result.stderr.strip(),
            "error": (result.stderr.strip() if not ok else "")
        };
    } except subprocess.TimeoutExpired {
        _cleanup_askpass(askpass_path);
        return {"success": False, "error": "Git command timed out", "stdout": "", "stderr": ""};
    } except Exception as e {
        _cleanup_askpass(askpass_path);
        return {"success": False, "error": _safe_error(e), "stdout": "", "stderr": ""};
    }
}


"""Remove askpass script if it exists."""
def _cleanup_askpass(path: str) -> None {
    if path and os.path.exists(path) {
        os.remove(path);
    }
}


"""Push to GitHub remote with token authentication."""
def github_push(repo_path: str, access_token: str, remote: str = "origin", set_upstream: bool = True) -> dict {
    try {
        branch_result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=repo_path,
            capture_output=True,
            text=True,
            timeout=10
        );
        branch = branch_result.stdout.strip();
    } except Exception {
        branch = "main";
    }

    args = ["push"];
    if set_upstream {
        args.extend(["--set-upstream", remote, branch]);
    }

    return run_git_authenticated(repo_path, args, access_token, timeout=60);
}


"""Pull from GitHub remote with token authentication."""
def github_pull(repo_path: str, access_token: str, remote: str = "origin") -> dict {
    return run_git_authenticated(repo_path, ["pull", remote], access_token, timeout=60);
}


"""Clone a GitHub repository with token authentication.

Uses GIT_ASKPASS to avoid embedding tokens in the command line
(which would be visible in /proc/<pid>/cmdline).
"""
def github_clone(clone_url: str, dest_path: str, access_token: str) -> dict {
    # Use run_git_authenticated with a temporary parent dir as cwd
    # since the dest_path doesn't exist yet
    parent_dir = os.path.dirname(dest_path);
    if not os.path.exists(parent_dir) {
        os.makedirs(parent_dir, exist_ok=True);
    }

    result = run_git_authenticated(
        parent_dir,
        ["clone", clone_url, dest_path],
        access_token,
        timeout=120
    );

    if not result.get("success") {
        return result;
    }

    # Ensure remote URL is clean (no embedded credentials)
    try {
        subprocess.run(
            ["git", "remote", "set-url", "origin", clone_url],
            cwd=dest_path,
            capture_output=True,
            text=True,
            timeout=10
        );
    } except Exception {
    }

    return {"success": True};
}
