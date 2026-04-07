def _run_git(args: list[str], cwd: str = "") -> tuple {
    work_dir = cwd or os.getcwd();
    (sandboxed, allowed) = sandbox_path(work_dir);
    if not allowed {
        return ("", f"Error: directory {work_dir} is outside sandbox.", 1);
    }
    try {
        result = subprocess.run(
            ["git"] + args, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=30, cwd=sandboxed
        );
        return (result.stdout.strip(), result.stderr.strip(), result.returncode);
    } except subprocess.TimeoutExpired {
        return ("", "Error: git command timed out after 30s.", 1);
    } except FileNotFoundError {
        return ("", "Error: git is not installed or not in PATH.", 1);
    } except Exception as e {
        return ("", f"Error: {str(e)}", 1);
    }
}


impl git_status() -> str {
    tool_status("git_status", "checking working tree");
    (out, err, code) = _run_git(["status", "--short"]);
    if code != 0 {
        tool_end("-> error", error=True);
        return f"Error: {err}";
    }
    if not out {
        tool_end("-> clean");
        return "Working tree clean - no changes.";
    }
    (out, _) = truncate_output(out);
    tool_end(f"-> {len(out.splitlines())} changes");
    return out;
}


impl git_diff(ref: str = "HEAD") -> str {
    tool_status("git_diff", f"diff against {ref}");
    (out, err, code) = _run_git(["diff", ref]);
    if code != 0 {
        # Try without ref (unstaged changes)
        (out, err, code) = _run_git(["diff"]);
        if code != 0 {
            tool_end("-> error", error=True);
            return f"Error: {err}";
        }
    }
    if not out {
        tool_end("-> no diff");
        return "No differences found.";
    }
    (out, _) = truncate_output(out);
    tool_end(f"-> {len(out.splitlines())} lines");
    return out;
}


impl git_commit(message: str, files: list[str] = []) -> str {
    tool_status("git_commit", message[:60]);
    if not message {
        tool_end("-> error", error=True);
        return "Error: commit message is required.";
    }

    # Stage files
    if files {
        for fp in files {
            (_, err, code) = _run_git(["add", fp]);
            if code != 0 {
                tool_end(f"-> stage error: {err}", error=True);
                return f"Error staging {fp}: {err}";
            }
        }
    } else {
        (_, err, code) = _run_git(["add", "-A"]);
        if code != 0 {
            tool_end(f"-> stage error: {err}", error=True);
            return f"Error staging files: {err}";
        }
    }

    # Commit
    (out, err, code) = _run_git(["commit", "-m", message]);
    if code != 0 {
        if "nothing to commit" in (out + err) {
            tool_end("-> nothing to commit");
            return "Nothing to commit - working tree clean.";
        }
        tool_end("-> commit error", error=True);
        return f"Error: {err or out}";
    }
    tool_end("-> committed");
    return out;
}


impl git_log(count: int = 10) -> str {
    tool_status("git_log", f"last {count} commits");
    (out, err, code) = _run_git(
        ["log", f"--max-count={count}", "--oneline", "--decorate"]
    );
    if code != 0 {
        tool_end("-> error", error=True);
        return f"Error: {err}";
    }
    if not out {
        tool_end("-> no commits");
        return "No commits found.";
    }
    tool_end(f"-> {len(out.splitlines())} commits");
    (out, _) = truncate_output(out);
    return out;
}
