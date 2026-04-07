"""Browser testing via agent-browser CLI.

Uses Vercel's agent-browser (Rust CLI) for fast, token-efficient browser
automation.  All browser operations are subprocess calls — no Python browser
deps required.  The daemon starts on first use and persists across commands
for <50ms latency after the initial boot.

Install:  npm install -g agent-browser && agent-browser install
"""

import os;
import shutil;
import subprocess;
import threading;

import from jac_coder.util.tool_output { truncate_output, tool_status, tool_end }
import from jac_coder.util.sandbox { get_browser_exec }

# Thread-local storage for per-request state (preview URL, session).
glob _tl = threading.local();

# Subprocess timeout for agent-browser commands (seconds).
glob _CMD_TIMEOUT: int = 30;
glob _OPEN_TIMEOUT: int = 45;


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

"""Find the agent-browser binary, checking common locations."""
def _find_binary() -> str {
    # Allow explicit override via env var
    override = os.environ.get("AGENT_BROWSER_BIN", "");
    if override and shutil.which(override) {
        return override;
    }
    # Check PATH
    found = shutil.which("agent-browser");
    if found {
        return found;
    }
    # Common npm global install locations
    for candidate in [
        os.path.expanduser("~/.npm-global/bin/agent-browser"),
        "/usr/local/bin/agent-browser",
        os.path.expanduser("~/.local/bin/agent-browser")
    ] {
        if os.path.isfile(candidate) and os.access(candidate, os.X_OK) {
            return candidate;
        }
    }
    return "";
}


"""Run an agent-browser CLI command and return (success, stdout, stderr).

If a remote browser exec function is set (via set_browser_exec), routes the
command to the sandbox pod. Otherwise falls back to local subprocess."""
def _run_cmd(args: list, timeout: int = _CMD_TIMEOUT) -> tuple {
    # Check for remote exec (sandbox pod)
    remote_exec = get_browser_exec();
    if remote_exec {
        try {
            return remote_exec(args, timeout);
        } except Exception as e {
            return (False, "", f"Remote browser exec failed: {str(e)}");
        }
    }

    # Local fallback
    binary = _find_binary();
    if not binary {
        return (
            False,
            "",
            "agent-browser not found. Install: npm install -g agent-browser && agent-browser install"
        );
    }
    cmd = [binary] + args;
    try {
        result = subprocess.run(
            cmd,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=timeout
        );
        if result.returncode == 0 {
            return (True, result.stdout.strip(), "");
        } else {
            err = result.stderr.strip() or result.stdout.strip() or f"exit code {result.returncode}";
            return (False, "", err);
        }
    } except subprocess.TimeoutExpired {
        return (False, "", f"Command timed out after {timeout}s");
    } except Exception as e {
        return (False, "", str(e));
    }
}


"""Get the preview URL from thread-local or env var fallback."""
def _get_preview_url() -> str {
    return getattr(_tl, "preview_url", "") or os.environ.get("JACCODER_PREVIEW_URL", "");
}


# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------

impl set_preview_url(url: str) -> None {
    _tl.preview_url = url;
}


impl browser_open(url: str = "") -> str {
    target_url = url or _get_preview_url();
    tool_status("browser_open", target_url or "(no url)");

    if not target_url {
        tool_end("-> no URL", error=True);
        return (
            "Error: No URL provided and no preview URL set. "
            "Pass a URL or set JACCODER_PREVIEW_URL."
        );
    }

    # Open the page — daemon starts automatically on first command
    (ok, stdout, stderr) = _run_cmd(["open", target_url], timeout=_OPEN_TIMEOUT);
    if not ok {
        tool_end(f"-> failed: {stderr}", error=True);
        return f"Error: Failed to open browser — {stderr}";
    }

    # Wait for page to settle, then get snapshot with interactive elements
    (ok2, snapshot, stderr2) = _run_cmd(["snapshot", "-i"]);
    if not ok2 {
        # Page opened but snapshot failed — return what we have
        tool_end("-> opened, snapshot unavailable");
        return f"Browser opened: {target_url}\n\n(Page snapshot unavailable: {stderr2})";
    }

    # Mark session as active in thread-local
    _tl.browser_active = True;

    (output, _) = truncate_output(snapshot);
    tool_end(f"-> opened {target_url}");
    return f"Browser opened: {target_url}\n\nPage snapshot:\n{output}";
}


impl browser_do(command: str) -> str {
    tool_status("browser_do", command[:80] + "..." if len(command) > 80 else command);

    if not command or not command.strip() {
        tool_end("-> empty command", error=True);
        return "Error: command is required. Example: 'click @e1'";
    }

    # Split command string into args for subprocess
    import shlex;
    try {
        args = shlex.split(command.strip());
    } except ValueError as e {
        tool_end(f"-> parse error: {e}", error=True);
        return f"Error: Failed to parse command — {e}";
    }

    (ok, stdout, stderr) = _run_cmd(args);
    if not ok {
        tool_end(f"-> failed: {stderr}", error=True);
        return f"Error: {stderr}";
    }

    (output, _) = truncate_output(stdout) if stdout else ("Done.", False);
    tool_end(f"-> {args[0] if args else 'done'}");
    return output;
}


impl browser_state() -> str {
    tool_status("browser_state");

    # snapshot -i returns interactive elements only (token-efficient)
    (ok, stdout, stderr) = _run_cmd(["snapshot", "-i"]);
    if not ok {
        tool_end(f"-> failed: {stderr}", error=True);
        return f"Error: {stderr}";
    }

    (output, _) = truncate_output(stdout);
    tool_end("-> got page snapshot");
    return output;
}


impl browser_close() -> str {
    tool_status("browser_close");

    (ok, stdout, stderr) = _run_cmd(["close"]);
    _tl.browser_active = False;

    if not ok {
        tool_end(f"-> failed: {stderr}", error=True);
        return f"Error: {stderr}";
    }

    tool_end("-> closed");
    return "Browser session closed.";
}
