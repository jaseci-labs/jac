"""Git service — enhanced git operations for IDE integration.

Provides branch management, status, diff, commit, push, pull operations.
Extracted from project_manager.jac's _run_git helper and extended with
full git workflow support.
"""

import os;
import subprocess;
import re;

# Maximum number of commits to return from git_log
glob _MAX_LOG_LIMIT: int = 100;

# Protected branch names that cannot be force-deleted by worktree cleanup
glob _PROTECTED_BRANCHES: list[str] = ["main", "master", "dev", "develop", "staging", "production"];


# ===========================================================================
# Core Git Runner
# ===========================================================================

"""Run a git command and return structured result."""
def _run_git(repo_path: str, args: list, check: bool = True, timeout: int = 30) -> dict {
    try {
        result = subprocess.run(
            ["git"] + args,
            cwd=repo_path,
            capture_output=True,
            text=True,
            timeout=timeout
        );
        ok = result.returncode == 0;
        if check and not ok {
            return {"success": False, "error": result.stderr.strip(), "stdout": result.stdout.strip()};
        }
        return {"success": ok, "stdout": result.stdout.strip(), "stderr": result.stderr.strip()};
    } except subprocess.TimeoutExpired {
        return {"success": False, "error": "Git command timed out", "stdout": ""};
    } except Exception as e {
        return {"success": False, "error": str(e), "stdout": ""};
    }
}


"""Check if path is a git repository."""
def is_git_repo(repo_path: str) -> bool {
    res = _run_git(repo_path, ["rev-parse", "--is-inside-work-tree"], check=False);
    return res.get("success", False) and res.get("stdout", "") == "true";
}


# ===========================================================================
# Status
# ===========================================================================

"""Get comprehensive git status."""
def git_status(repo_path: str) -> dict {
    if not is_git_repo(repo_path) {
        return {"success": False, "error": "Not a git repository", "is_repo": False};
    }

    # Current branch
    branch_res = _run_git(repo_path, ["rev-parse", "--abbrev-ref", "HEAD"], check=False);
    branch = branch_res.get("stdout", "HEAD") if branch_res.get("success") else "HEAD";

    # Porcelain status — parse XY columns separately to distinguish staged vs unstaged
    # Run git status --porcelain directly (not via _run_git) to avoid .strip()
    # stripping the leading space from the first line — porcelain format needs
    # exact column positions: XY<space>PATH where X/Y can be space.
    import subprocess as _sp;
    try {
        _status_proc = _sp.run(["git", "status", "--porcelain"], cwd=repo_path, capture_output=True, text=True, timeout=30);
        status_lines = _status_proc.stdout.split("\n") if _status_proc.stdout else [];
    } except Exception {
        status_lines = [];
    }
    files: list = [];
    for line in status_lines {
        if line.strip() {
            x_col = line[0] if len(line) > 0 else " ";
            y_col = line[1] if len(line) > 1 else " ";
            file_path = line[3:];
            status_code = line[:2];
            is_staged = x_col != " " and x_col != "?";
            is_unstaged = y_col != " " or x_col == "?";
            files.append({
                "status": status_code.strip(),
                "path": file_path,
                "staged": is_staged,
                "unstaged": is_unstaged,
                "x": x_col,
                "y": y_col
            });
        }
    }
    dirty = len(files) > 0;

    # Ahead/behind
    ahead = 0;
    behind = 0;
    upstream_res = _run_git(
        repo_path,
        ["rev-list", "--left-right", "--count", f"{branch}...@{{u}}"],
        check=False
    );
    if upstream_res.get("success") {
        parts = upstream_res.get("stdout", "").split();
        if len(parts) == 2 {
            try {
                ahead = int(parts[0]);
                behind = int(parts[1]);
            } except ValueError { }
        }
    }

    # Has remote
    has_remote = False;
    remote_res = _run_git(repo_path, ["remote"], check=False);
    if remote_res.get("success") and remote_res.get("stdout", "").strip() {
        has_remote = True;
    }

    # Last commit (use null-byte delimiter to handle | in messages/authors)
    log_res = _run_git(repo_path, ["log", "-1", "--format=%H%x00%s%x00%an%x00%aI"], check=False);
    last_commit = None;
    if log_res.get("success") and log_res.get("stdout") {
        parts = log_res.get("stdout", "").split("\x00", 3);
        if len(parts) >= 4 {
            last_commit = {
                "sha": parts[0],
                "message": parts[1],
                "author": parts[2],
                "date": parts[3]
            };
        }
    }

    # Files changed in last commit (for display when working tree is clean)
    # Use diff-tree --root so it works even for the initial commit (HEAD~1 doesn't exist)
    last_commit_files: list = [];
    if last_commit {
        lc_numstat = _run_git(repo_path, ["diff-tree", "--root", "--numstat", "-r", "HEAD"], check=False, timeout=10);
        if lc_numstat.get("success") and lc_numstat.get("stdout") {
            for lc_line in lc_numstat.get("stdout", "").split("\n") {
                lc_line = lc_line.strip();
                if not lc_line { continue; }
                lc_parts = lc_line.split("\t");
                if len(lc_parts) >= 3 {
                    lc_add = lc_parts[0].strip();
                    lc_del = lc_parts[1].strip();
                    last_commit_files.append({
                        "status": "M",
                        "path": lc_parts[2].strip(),
                        "additions": int(lc_add) if lc_add != "-" else 0,
                        "deletions": int(lc_del) if lc_del != "-" else 0
                    });
                }
            }
        }
    }

    return {
        "success": True,
        "is_repo": True,
        "branch": branch,
        "dirty": dirty,
        "ahead": ahead,
        "behind": behind,
        "has_remote": has_remote,
        "files": files,
        "last_commit": last_commit,
        "last_commit_files": last_commit_files
    };
}


# ===========================================================================
# Branches
# ===========================================================================

"""List all local branches."""
def git_branches(repo_path: str) -> dict {
    res = _run_git(repo_path, ["branch", "--list", "--format=%(refname:short)|%(HEAD)"], check=False);
    if not res.get("success") {
        return {"success": False, "error": res.get("error", ""), "branches": [], "current": ""};
    }

    branches: list = [];
    current = "";
    for line in res.get("stdout", "").split("\n") {
        line = line.strip();
        if not line { continue; }
        parts = line.split("|", 1);
        name = parts[0].strip();
        is_current = len(parts) > 1 and parts[1].strip() == "*";
        if is_current { current = name; }
        branches.append({"name": name, "current": is_current});
    }

    return {"success": True, "branches": branches, "current": current};
}


"""Create a new branch and optionally check it out."""
def git_create_branch(repo_path: str, name: str, checkout: bool = True) -> dict {
    if not name or not name.strip() {
        return {"success": False, "error": "Branch name is required"};
    }
    name = name.strip();

    if checkout {
        res = _run_git(repo_path, ["checkout", "-b", name]);
    } else {
        res = _run_git(repo_path, ["branch", name]);
    }
    return res;
}


"""Checkout an existing branch."""
def git_checkout(repo_path: str, branch: str) -> dict {
    if not branch or not branch.strip() {
        return {"success": False, "error": "Branch name is required"};
    }
    return _run_git(repo_path, ["checkout", branch.strip()]);
}


"""Delete a local branch."""
def git_delete_branch(repo_path: str, branch: str, force: bool = False) -> dict {
    if not branch or not branch.strip() {
        return {"success": False, "error": "Branch name is required"};
    }
    flag = "-D" if force else "-d";
    return _run_git(repo_path, ["branch", flag, branch.strip()], check=False);
}


"""Get the current HEAD commit SHA."""
def git_head_sha(repo_path: str) -> str {
    res = _run_git(repo_path, ["rev-parse", "HEAD"], check=False);
    return res.get("stdout", "") if res.get("success") else "";
}


# ===========================================================================
# Diff
# ===========================================================================

"""Get diff between two refs (or working tree)."""
def git_diff(repo_path: str, from_ref: str = "", to_ref: str = "") -> dict {
    # Build ref args once
    ref_args: list = [];
    if from_ref and to_ref {
        ref_args = [from_ref, to_ref];
    } elif from_ref {
        ref_args = [from_ref];
    }

    # Get numstat for accurate addition/deletion counts
    numstat_res = _run_git(repo_path, ["diff"] + ref_args + ["--numstat"], check=False, timeout=15);

    # Get full diff text
    diff_res = _run_git(repo_path, ["diff"] + ref_args, check=False, timeout=15);

    # Parse numstat: "additions\tdeletions\tfilename"
    files: list = [];
    if numstat_res.get("success") and numstat_res.get("stdout") {
        for line in numstat_res.get("stdout", "").split("\n") {
            line = line.strip();
            if not line { continue; }
            parts = line.split("\t");
            if len(parts) >= 3 {
                add_str = parts[0].strip();
                del_str = parts[1].strip();
                file_path = parts[2].strip();
                additions = 0;
                deletions = 0;
                try {
                    additions = int(add_str) if add_str != "-" else 0;
                    deletions = int(del_str) if del_str != "-" else 0;
                } except ValueError { }
                files.append({
                    "path": file_path,
                    "additions": additions,
                    "deletions": deletions
                });
            }
        }
    }

    return {
        "success": True,
        "diff_text": diff_res.get("stdout", ""),
        "files": files
    };
}


"""Get working tree diff (unstaged changes)."""
def git_diff_working(repo_path: str) -> dict {
    return git_diff(repo_path);
}


"""Get diff of the last commit (HEAD~1..HEAD)."""
def git_diff_last_commit(repo_path: str) -> dict {
    return git_diff(repo_path, "HEAD~1", "HEAD");
}


"""Get staged diff."""
def git_diff_staged(repo_path: str) -> dict {
    numstat_res = _run_git(repo_path, ["diff", "--cached", "--numstat"], check=False, timeout=15);

    diff_res = _run_git(repo_path, ["diff", "--cached"], check=False, timeout=15);

    files: list = [];
    if numstat_res.get("success") and numstat_res.get("stdout") {
        for line in numstat_res.get("stdout", "").split("\n") {
            line = line.strip();
            if not line { continue; }
            parts = line.split("\t");
            if len(parts) >= 3 {
                add_str = parts[0].strip();
                del_str = parts[1].strip();
                file_path = parts[2].strip();
                additions = 0;
                deletions = 0;
                try {
                    additions = int(add_str) if add_str != "-" else 0;
                    deletions = int(del_str) if del_str != "-" else 0;
                } except ValueError { }
                files.append({
                    "path": file_path,
                    "additions": additions,
                    "deletions": deletions
                });
            }
        }
    }

    return {
        "success": True,
        "diff_text": diff_res.get("stdout", ""),
        "files": files
    };
}


"""Get file content at a specific git ref (e.g. HEAD, HEAD~1, : for index)."""
def git_show_file(repo_path: str, ref: str, file_path: str) -> dict {
    if not ref or not file_path {
        return {"success": False, "content": "", "error": "ref and file_path are required"};
    }
    cmd = ref + ":" + file_path;
    result = _run_git(repo_path, ["show", cmd], check=False, timeout=15);
    if not result.get("success", False) {
        return {"success": False, "content": "", "error": result.get("error", result.get("stderr", ""))};
    }
    return {"success": True, "content": result.get("stdout", "")};
}

"""Read file content from disk (working tree)."""
def git_read_working_file(repo_path: str, file_path: str) -> dict {
    full_path = os.path.join(repo_path, file_path);
    try {
        if not os.path.isfile(full_path) {
            return {"success": False, "content": "", "error": "File not found: " + file_path};
        }
        with open(full_path, "r", encoding="utf-8") as f {
            content = f.read();
        }
        return {"success": True, "content": content};
    } except Exception as e {
        return {"success": False, "content": "", "error": str(e)};
    }
}


# ===========================================================================
# Commit / Push / Pull
# ===========================================================================

"""Ensure .env is in .gitignore before committing."""
def _ensure_env_gitignored(repo_path: str) -> None {
    gitignore_path = os.path.join(repo_path, ".gitignore");
    existing_lines: list[str] = [];
    try {
        if os.path.exists(gitignore_path) {
            with open(gitignore_path, "r", encoding="utf-8") as f {
                existing_lines = [line.rstrip("\n") for line in f.readlines()];
            }
        }
        if ".env" not in existing_lines {
            with open(gitignore_path, "a", encoding="utf-8") as f {
                if len(existing_lines) > 0 and existing_lines[-1].strip() != "" {
                    f.write("\n");
                }
                f.write(".env\n");
            }
        }
    } except Exception { }
}


"""Stage all and commit."""
def git_commit(repo_path: str, message: str) -> dict {
    if not message or not message.strip() {
        return {"success": False, "error": "Commit message is required"};
    }

    # Stage all changes
    add_res = _run_git(repo_path, ["add", "-A"]);
    if not add_res.get("success") {
        return add_res;
    }

    # Check if there's anything to commit
    status = _run_git(repo_path, ["status", "--porcelain"], check=False);
    if not status.get("stdout", "").strip() {
        return {"success": False, "error": "Nothing to commit"};
    }

    # Ensure .env is gitignored before committing (after "nothing to commit" check
    # so we don't create .gitignore changes in empty commits)
    _ensure_env_gitignored(repo_path);
    # Re-stage in case .gitignore was created/modified
    _run_git(repo_path, ["add", "-A"], check=False);

    # Commit
    commit_res = _run_git(repo_path, ["commit", "-m", message.strip()]);
    if not commit_res.get("success") {
        return commit_res;
    }

    # Get commit SHA
    sha_res = _run_git(repo_path, ["rev-parse", "HEAD"], check=False);
    sha = sha_res.get("stdout", "");

    return {"success": True, "sha": sha, "message": message.strip()};
}


"""Stage a single file."""
def git_stage_file(repo_path: str, file_path: str) -> dict {
    if not file_path or not file_path.strip() {
        return {"success": False, "error": "file_path is required"};
    }
    return _run_git(repo_path, ["add", "--", file_path.strip()]);
}


"""Unstage a single file (reset from index)."""
def git_unstage_file(repo_path: str, file_path: str) -> dict {
    if not file_path or not file_path.strip() {
        return {"success": False, "error": "file_path is required"};
    }
    return _run_git(repo_path, ["reset", "HEAD", "--", file_path.strip()], check=False);
}


"""Commit only already-staged files (no git add -A)."""
def git_commit_staged(repo_path: str, message: str) -> dict {
    if not message or not message.strip() {
        return {"success": False, "error": "Commit message is required"};
    }

    # Check if there's anything staged BEFORE env gitignore (which may stage .gitignore)
    status = _run_git(repo_path, ["diff", "--cached", "--quiet"], check=False);
    if status.get("success") {
        return {"success": False, "error": "Nothing staged to commit"};
    }

    # Ensure .env is gitignored and stage .gitignore if modified
    _ensure_env_gitignored(repo_path);
    _run_git(repo_path, ["add", "--", ".gitignore"], check=False);

    # Commit staged only
    commit_res = _run_git(repo_path, ["commit", "-m", message.strip()]);
    if not commit_res.get("success") {
        return commit_res;
    }

    # Get commit SHA
    sha_res = _run_git(repo_path, ["rev-parse", "HEAD"], check=False);
    sha = sha_res.get("stdout", "");

    return {"success": True, "sha": sha, "message": message.strip()};
}


"""Push current branch to remote."""
def git_push(repo_path: str, set_upstream: bool = True) -> dict {
    # Get current branch
    branch_res = _run_git(repo_path, ["rev-parse", "--abbrev-ref", "HEAD"], check=False);
    branch = branch_res.get("stdout", "").strip();

    args = ["push"];
    if set_upstream {
        args.extend(["--set-upstream", "origin", branch]);
    }

    return _run_git(repo_path, args, timeout=60);
}


"""Pull current branch from remote."""
def git_pull(repo_path: str) -> dict {
    return _run_git(repo_path, ["pull"], timeout=60);
}


"""Get recent commit log."""
def git_log(repo_path: str, limit: int = 20) -> dict {
    # Cap limit to prevent unbounded queries
    if limit < 1 { limit = 1; }
    if limit > _MAX_LOG_LIMIT { limit = _MAX_LOG_LIMIT; }

    # Use null-byte delimiter to handle | in commit messages/author names
    res = _run_git(
        repo_path,
        ["log", f"-{limit}", "--format=%H%x00%s%x00%an%x00%aI"],
        check=False
    );
    if not res.get("success") {
        return {"success": False, "error": res.get("error", ""), "commits": []};
    }

    commits: list = [];
    for line in res.get("stdout", "").split("\n") {
        line = line.strip();
        if not line { continue; }
        parts = line.split("\x00", 3);
        if len(parts) >= 4 {
            commits.append({
                "sha": parts[0],
                "message": parts[1],
                "author": parts[2],
                "date": parts[3]
            });
        }
    }

    return {"success": True, "commits": commits};
}


# ===========================================================================
# Remote
# ===========================================================================

"""Add a remote origin."""
def git_remote_add(repo_path: str, url: str, name: str = "origin") -> dict {
    if not url or not url.strip() {
        return {"success": False, "error": "Remote URL is required"};
    }

    # Check if remote already exists
    check = _run_git(repo_path, ["remote", "get-url", name], check=False);
    if check.get("success") {
        # Remote exists — update it
        return _run_git(repo_path, ["remote", "set-url", name, url.strip()]);
    }

    return _run_git(repo_path, ["remote", "add", name, url.strip()]);
}


"""Remove a remote."""
def git_remote_remove(repo_path: str, name: str = "origin") -> dict {
    return _run_git(repo_path, ["remote", "remove", name]);
}


"""List remotes."""
def git_remotes(repo_path: str) -> dict {
    res = _run_git(repo_path, ["remote", "-v"], check=False);
    if not res.get("success") {
        return {"success": False, "remotes": []};
    }

    remotes: list = [];
    seen: set = set();
    for line in res.get("stdout", "").split("\n") {
        line = line.strip();
        if not line { continue; }
        parts = line.split();
        if len(parts) >= 2 {
            name = parts[0];
            url = parts[1];
            entry_key = f"{name}:{url}";
            if entry_key not in seen {
                seen.add(entry_key);
                remotes.append({"name": name, "url": url});
            }
        }
    }

    return {"success": True, "remotes": remotes};
}


# ===========================================================================
# Worktrees
# ===========================================================================

"""Create a git worktree on a new branch.
Places worktrees in ~/.jac-ide/worktrees/{repo_name}/{sanitized_branch}."""
def git_create_worktree(repo_path: str, base_branch: str, new_branch: str) -> dict {
    if not base_branch or not base_branch.strip() {
        return {"success": False, "error": "Base branch is required"};
    }
    if not new_branch or not new_branch.strip() {
        return {"success": False, "error": "New branch name is required"};
    }

    base_branch = base_branch.strip();
    new_branch = new_branch.strip();

    # Sanitize branch for filesystem path (replace / with -)
    sanitized = re.sub(r"[^a-zA-Z0-9_-]", "-", new_branch);
    # Build worktree path: ~/.jac-ide/worktrees/{repo_name}/{sanitized_branch}
    repo_name = repo_path.rstrip("/").split("/")[-1] if "/" in repo_path else repo_path;
    home_dir = os.environ.get("HOME", "/tmp");
    worktree_root = home_dir + "/.jac-ide/worktrees/" + repo_name;
    worktree_path = worktree_root + "/" + sanitized;

    # If worktree path already exists, remove it first
    if os.path.exists(worktree_path) {
        rm_res = _run_git(repo_path, ["worktree", "remove", "--force", worktree_path], check=False);
        if not rm_res.get("success") {
            # Try filesystem cleanup as fallback
            try {
                import shutil;
                shutil.rmtree(worktree_path);
                _run_git(repo_path, ["worktree", "prune"], check=False);
            } except Exception { }
        }
    }

    # Delete branch if it already exists (from a previous failed attempt)
    # but NEVER delete protected branches (main, master, dev, etc.)
    if new_branch.lower() not in _PROTECTED_BRANCHES {
        _run_git(repo_path, ["branch", "-D", new_branch], check=False);
    } else {
        return {"success": False, "error": "Cannot use protected branch name: " + new_branch};
    }

    # Create worktree: git worktree add -b <new_branch> <path> <base_branch>
    res = _run_git(
        repo_path,
        ["worktree", "add", "-b", new_branch, worktree_path, base_branch],
        timeout=30
    );

    if not res.get("success") {
        return {"success": False, "error": res.get("error", "Failed to create worktree")};
    }

    return {
        "success": True,
        "worktree_path": worktree_path,
        "branch": new_branch,
        "base_branch": base_branch
    };
}


"""Remove a git worktree."""
def git_remove_worktree(repo_path: str, worktree_path: str, force: bool = False) -> dict {
    if not worktree_path or not worktree_path.strip() {
        return {"success": False, "error": "Worktree path is required"};
    }

    args = ["worktree", "remove"];
    if force {
        args.append("--force");
    }
    args.append(worktree_path.strip());

    res = _run_git(repo_path, args, timeout=15);

    # Prune stale worktree entries
    _run_git(repo_path, ["worktree", "prune"], check=False);

    return res;
}


"""List all git worktrees with branch info."""
def git_list_worktrees(repo_path: str) -> dict {
    res = _run_git(repo_path, ["worktree", "list", "--porcelain"], check=False);
    if not res.get("success") {
        return {"success": False, "error": res.get("error", ""), "worktrees": []};
    }

    worktrees: list = [];
    current_path = "";
    current_branch = "";
    current_head = "";
    is_bare = False;

    for line in res.get("stdout", "").split("\n") {
        if line.startswith("worktree ") {
            # Save previous entry
            if current_path {
                worktrees.append({
                    "path": current_path,
                    "branch": current_branch,
                    "head": current_head,
                    "bare": is_bare
                });
            }
            current_path = line[len("worktree "):].strip();
            current_branch = "";
            current_head = "";
            is_bare = False;
        } elif line.startswith("HEAD ") {
            current_head = line[len("HEAD "):].strip();
        } elif line.startswith("branch refs/heads/") {
            current_branch = line[len("branch refs/heads/"):].strip();
        } elif line.strip() == "bare" {
            is_bare = True;
        }
    }

    # Don't forget last entry
    if current_path {
        worktrees.append({
            "path": current_path,
            "branch": current_branch,
            "head": current_head,
            "bare": is_bare
        });
    }

    return {"success": True, "worktrees": worktrees};
}


# ===========================================================================
# Checkpoints (for Claude turn rollback)
# ===========================================================================

"""Create a lightweight checkpoint before a Claude turn.
Uses git stash to save uncommitted changes without polluting commit history."""
def git_create_checkpoint(repo_path: str) -> dict {
    head_res = _run_git(repo_path, ["rev-parse", "HEAD"], check=False);
    if not head_res.get("success") {
        return {"success": False, "error": "No commits in repository"};
    }

    checkpoint_ref = head_res.get("stdout", "").strip();

    # Stash uncommitted changes (if any) instead of creating checkpoint commits
    status = _run_git(repo_path, ["status", "--porcelain"], check=False);
    has_uncommitted = bool(status.get("stdout", "").strip());
    stash_ref = "";

    if has_uncommitted {
        stash_res = _run_git(
            repo_path,
            ["stash", "push", "-u", "-m", "pre-claude-turn"],
            check=False
        );
        if stash_res.get("success") {
            # Capture the actual stash commit SHA instead of positional stash@{0}
            # This avoids race conditions if another stash is pushed concurrently
            sha_res = _run_git(repo_path, ["stash", "list", "--format=%H", "-1"], check=False);
            stash_ref = sha_res.get("stdout", "").strip() if sha_res.get("success") else "stash@{0}";
        }
    }

    return {"success": True, "checkpoint_ref": checkpoint_ref, "stash_ref": stash_ref};
}


"""Restore to a checkpoint ref. Uses checkout for safety instead of reset --hard."""
def git_restore_checkpoint(repo_path: str, checkpoint_ref: str) -> dict {
    if not checkpoint_ref {
        return {"success": False, "error": "Checkpoint ref is required"};
    }

    # Validate that checkpoint_ref is a valid commit SHA (not an arbitrary ref like a branch name)
    # This prevents abuse of the restore function to checkout arbitrary branches/tags
    if not re.match(r"^[0-9a-f]{7,40}$", checkpoint_ref.strip()) {
        return {"success": False, "error": "Invalid checkpoint ref — must be a commit SHA"};
    }

    # Verify the ref exists in this repo
    verify = _run_git(repo_path, ["cat-file", "-t", checkpoint_ref.strip()], check=False);
    if not verify.get("success") or verify.get("stdout", "").strip() != "commit" {
        return {"success": False, "error": "Checkpoint ref not found or not a commit"};
    }

    # Discard any uncommitted changes first
    _run_git(repo_path, ["checkout", "--", "."], check=False);
    _run_git(repo_path, ["clean", "-fd"], check=False);

    # Revert to checkpoint commit
    res = _run_git(repo_path, ["checkout", checkpoint_ref.strip()]);
    return res;
}


"""Non-destructive revert to a previous commit.
Replaces working tree + index with target state and creates a new commit
on the current branch. History is linear — no detached HEAD."""
def git_revert_to_commit(repo_path: str, target_sha: str) -> dict {
    if not target_sha or not target_sha.strip() {
        return {"success": False, "error": "Target SHA is required"};
    }
    target_sha = target_sha.strip();

    # Validate SHA format
    if not re.match(r"^[0-9a-f]{7,40}$", target_sha) {
        return {"success": False, "error": "Invalid SHA format — must be a hex commit SHA"};
    }

    # Verify it's a commit
    verify = _run_git(repo_path, ["cat-file", "-t", target_sha], check=False);
    if not verify.get("success") or verify.get("stdout", "").strip() != "commit" {
        return {"success": False, "error": "Target ref not found or not a commit"};
    }

    # Save any pending changes (ignore failure if nothing to commit)
    _run_git(repo_path, ["add", "-A"], check=False);
    _run_git(repo_path, ["commit", "-m", "chore: save pending changes before revert"], check=False);

    # Check if we're already at the target state
    current_head = _run_git(repo_path, ["rev-parse", "HEAD"], check=False);
    current_sha = current_head.get("stdout", "").strip() if current_head.get("success") else "";

    # Replace working tree + index with target state
    read_tree = _run_git(repo_path, ["read-tree", "--reset", "-u", target_sha]);
    if not read_tree.get("success") {
        return {"success": False, "error": "Failed to restore tree: " + read_tree.get("error", "")};
    }

    # Check if there are actual changes to commit
    diff_check = _run_git(repo_path, ["diff", "--cached", "--quiet", "HEAD"], check=False);
    if diff_check.get("success") {
        # No changes — already at target state
        return {"success": True, "no_changes": True, "message": "Already at target state"};
    }

    # Create a new commit on the current branch
    short_sha = target_sha[:7];
    commit_res = _run_git(repo_path, ["commit", "-m", "revert: restore to " + short_sha]);
    if not commit_res.get("success") {
        return {"success": False, "error": "Failed to create revert commit: " + commit_res.get("error", "")};
    }

    # Get new commit SHA
    new_sha = _run_git(repo_path, ["rev-parse", "HEAD"], check=False);
    return {
        "success": True,
        "commit_sha": new_sha.get("stdout", "").strip() if new_sha.get("success") else ""
    };
}


"""Get diff from checkpoint to current state."""
def git_checkpoint_diff(repo_path: str, checkpoint_ref: str) -> dict {
    if not checkpoint_ref {
        return git_diff_working(repo_path);
    }
    return git_diff(repo_path, checkpoint_ref, "HEAD");
}


"""Merge a branch into the current branch."""
def git_merge(repo_path: str, branch: str) -> dict {
    if not branch {
        return {"success": False, "error": "branch name is required"};
    }
    result = _run_git(repo_path, ["merge", branch], check=False);
    if not result["success"] {
        stderr = result.get("error", "");
        stdout = result.get("stdout", "");
        if "CONFLICT" in stderr or "CONFLICT" in stdout {
            # Abort the merge so the working tree is clean
            _run_git(repo_path, ["merge", "--abort"], check=False);
            return {"success": False, "error": "Merge conflict", "conflicts": True, "details": stdout};
        }
        return result;
    }
    return {"success": True, "message": "Merged " + branch + " successfully"};
}
