"""Claude Code CLI adapter — spawn claude -p as subprocess, parse NDJSON events.

Uses the user's existing Claude Pro/Max subscription via OAuth credentials
stored in ~/.claude/. No API key needed.

Architecture mirrors jaccoder_adapter.jac:
  - Session lifecycle (create, resume, stop)
  - Non-blocking execution in background threads
  - Event streaming (text deltas, tool calls, completion)
  - Git checkpoint before each turn
  - Jac workspace setup (CLAUDE.md, .mcp.json, jac check feedback loop)
"""

import os;
import sys;
import json;
import signal;
import shutil;
import time;
import subprocess;
import from concurrent.futures {ThreadPoolExecutor}
import from pathlib {Path}
import from threading {Lock, Timer}
import from .project_manager {autosave_version}
import from .event_bus {EventBus}

glob _claude_pool = ThreadPoolExecutor(max_workers=8);
glob _claude_sessions: dict = {};       # key -> session_id
glob _claude_event_queues: dict = {};   # key -> EventBus
glob _claude_processing: dict = {};     # key -> bool
glob _claude_processes: dict = {};      # key -> subprocess.Popen
glob _claude_cancelled: dict = {};      # key -> bool (skip post-processing when stopped)
glob _claude_lock = Lock();
glob _autosave_lock = Lock();

glob CLAUDE_TURN_TIMEOUT: int = 300;    # 5 minutes max per turn
glob CLAUDE_MAX_QUEUE_SIZE: int = 2000;

# Directories to exclude from file sync (build artifacts, deps)
glob _EXCLUDED_DIRS: set = {"node_modules", "__pycache__", "dist", "build", "__jac_gen__"};

# Allowed Claude CLI tools whitelist — user-supplied values are validated against this
glob ALLOWED_TOOLS_WHITELIST: set = {
    "Read", "Edit", "Bash", "Glob", "Grep", "Write",
    "WebSearch", "WebFetch", "Agent", "Skill"
};


"""Find jac command. Returns a string for shell commands.
For PyInstaller frozen apps, uses sidecar's --jac-cli mode.
"""
def _find_jac_binary() -> str {
    # PyInstaller frozen app — use sidecar's multi-mode CLI
    if getattr(sys, 'frozen', False) {
        return sys.executable + " --jac-cli";
    }
    # Same venv as the running process
    bin_dir = os.path.dirname(sys.executable);
    jac_name = "jac.exe" if sys.platform == "win32" else "jac";
    jac_in_venv = os.path.join(bin_dir, jac_name);
    if os.path.isfile(jac_in_venv) {
        return jac_in_venv;
    }
    found = shutil.which("jac");
    if found {
        return found;
    }
    return "jac";
}


# ===========================================================================
# Helpers
# ===========================================================================

"""Build session key from user + project."""
def _claude_key(user_id: str, project_id: str) -> str {
    return f"{user_id}::{project_id}";
}


"""Find claude CLI binary."""
def _find_claude_binary() -> str {
    # Check common locations
    custom = os.environ.get("CLAUDE_BINARY_PATH", "");
    if custom and os.path.isfile(custom) {
        return custom;
    }

    found = shutil.which("claude");
    if found {
        return found;
    }

    # npm global installs
    import sys;
    bin_dir = "Scripts" if sys.platform == "win32" else "bin";
    claude_name = "claude.exe" if sys.platform == "win32" else "claude";
    candidates = [
        os.path.join(str(Path.home()), ".npm-global", bin_dir, claude_name),
        os.path.join(str(Path.home()), ".bun", bin_dir, claude_name),
    ];
    if sys.platform != "win32" {
        candidates.append("/usr/local/bin/claude");
    }
    for path in candidates {
        if os.path.isfile(path) {
            return path;
        }
    }
    return "";
}


"""Check if Claude CLI is available and authenticated."""
def check_claude_availability() -> dict {
    binary = _find_claude_binary();
    if not binary {
        return {
            "available": False,
            "error": "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
        };
    }

    # Quick check: run claude --version
    try {
        result = subprocess.run(
            [binary, "--version"],
            capture_output=True, text=True, timeout=10
        );
        if result.returncode != 0 {
            return {"available": False, "error": "Claude CLI found but failed version check"};
        }
        version = result.stdout.strip();
        return {"available": True, "binary": binary, "version": version};
    } except subprocess.TimeoutExpired {
        return {"available": False, "error": "Claude CLI timed out on version check"};
    } except Exception as e {
        return {"available": False, "error": str(e)};
    }
}


# ===========================================================================
# Jac Workspace Setup — CLAUDE.md + .mcp.json + jac check
# ===========================================================================


"""Resolve the templates directory path (same pattern as project_manager.jac)."""
def _templates_dir() -> str {
    return os.path.join(os.path.realpath("."), "assets", "templates");
}

"""Build CLAUDE.md content by loading template file and replacing placeholders."""
def _build_claude_md() -> str {
    jac_bin = _find_jac_binary();
    template_path = os.path.join(_templates_dir(), "CLAUDE.md.template");
    try {
        with open(template_path, "r", encoding="utf-8") as f {
            template = f.read();
        }
        return template.replace("{{JAC_BINARY}}", jac_bin);
    } except Exception as e {
        print(f"[claude_adapter] Failed to load CLAUDE.md template: {e}");
        return "# CLAUDE.md\nRun `jac check main.jac` after every code change.\n";
    }
}

"""Build .mcp.json content with dynamic jac binary path."""
def _build_mcp_json() -> str {
    jac_bin = _find_jac_binary();
    mcp_config = {
        "mcpServers": {
            "jac": {
                "command": jac_bin,
                "args": ["mcp"],
                "type": "stdio"
            }
        }
    };
    return json.dumps(mcp_config, indent=2);
}




"""Set up CLAUDE.md and .mcp.json in the workspace so Claude CLI can use Jac tools."""
def _setup_jac_workspace(cwd: str) -> None {
    try {
        claude_md_path = os.path.join(cwd, "CLAUDE.md");
        if not os.path.exists(claude_md_path) {
            with open(claude_md_path, "w", encoding="utf-8") as f {
                f.write(_build_claude_md());
            }
            print(f"[claude_adapter] Created CLAUDE.md in {cwd}");
        }

        mcp_json_path = os.path.join(cwd, ".mcp.json");
        if not os.path.exists(mcp_json_path) {
            with open(mcp_json_path, "w", encoding="utf-8") as f {
                f.write(_build_mcp_json());
            }
            print(f"[claude_adapter] Created .mcp.json in {cwd}");
        }
    } except Exception as e {
        print(f"[claude_adapter] workspace setup error: {e}");
    }
}


"""Run jac check on the workspace and return errors as a string."""
def _run_jac_check(cwd: str) -> str {
    try {
        main_jac = os.path.join(cwd, "main.jac");
        if not os.path.isfile(main_jac) {
            return "";
        }

        jac_bin = _find_jac_binary();
        result = subprocess.run(
            [jac_bin, "check", "main.jac"],
            capture_output=True, text=True, timeout=30, cwd=cwd
        );

        output = "";
        if result.stdout and result.stdout.strip() {
            output = result.stdout.strip();
        }
        if result.stderr and result.stderr.strip() {
            stderr_text = result.stderr.strip();
            if output {
                output = output + "\n" + stderr_text;
            } else {
                output = stderr_text;
            }
        }

        if result.returncode != 0 {
            return output if output else "jac check failed (exit code " + str(result.returncode) + ")";
        }

        return "";
    } except subprocess.TimeoutExpired {
        return "jac check timed out after 30 seconds";
    } except Exception as e {
        print(f"[claude_adapter] jac check error: {e}");
        return "";
    }
}


"""Read the preview log file for recent HMR/compilation errors."""
def _read_preview_errors(cwd: str) -> str {
    log_path = os.path.join(cwd, ".jac-preview.log");
    if not os.path.isfile(log_path) {
        return "";
    }
    try {
        with open(log_path, "r", encoding="utf-8", errors="replace") as f {
            lines = f.readlines();
        }
        if not lines {
            return "";
        }
        # Get last 50 lines and look for errors
        recent = lines[-50:] if len(lines) > 50 else lines;
        error_lines: list = [];
        for line in recent {
            lower_line = line.lower();
            if "error" in lower_line or "failed" in lower_line or "traceback" in lower_line {
                error_lines.append(line.rstrip());
            }
        }
        if error_lines {
            return "\n".join(error_lines[-20:]);
        }
        return "";
    } except Exception as e {
        print(f"[claude_adapter] log read error: {e}");
        return "";
    }
}


glob CLAUDE_MAX_CHECK_RETRIES: int = 2;


# ===========================================================================
# NDJSON Event Parsing
# ===========================================================================

"""Parse a single NDJSON line from claude -p --output-format stream-json.
Normalizes into jac-ide event format."""
def _parse_claude_event(raw: dict, event_queue: EventBus, accumulated_text: list) -> None {
    msg_type = raw.get("type", "");

    if msg_type == "system" {
        # Session init event
        session_id = raw.get("session_id", "");
        subtype = raw.get("subtype", "");
        if subtype == "init" and session_id {
            _safe_put(event_queue, {
                "type": "claude_session_started",
                "session_id": session_id,
                "timestamp": time.time()
            });
        }

    } elif msg_type == "stream_event" {
        event = raw.get("event", {});
        event_type = event.get("type", "");

        if event_type == "content_block_start" {
            cb = event.get("content_block", {});
            if cb.get("type") == "tool_use" {
                _safe_put(event_queue, {
                    "type": "claude_tool_start",
                    "tool_name": cb.get("name", ""),
                    "tool_id": cb.get("id", ""),
                    "timestamp": time.time()
                });
            }

        } elif event_type == "content_block_delta" {
            delta = event.get("delta", {});
            delta_type = delta.get("type", "");

            if delta_type == "text_delta" {
                text = delta.get("text", "");
                if text {
                    accumulated_text.append(text);
                    _safe_put(event_queue, {
                        "type": "claude_text_delta",
                        "text": text,
                        "timestamp": time.time()
                    });
                }

            } elif delta_type == "input_json_delta" {
                _safe_put(event_queue, {
                    "type": "claude_tool_input_delta",
                    "partial_json": delta.get("partial_json", ""),
                    "timestamp": time.time()
                });
            } elif delta_type == "thinking_delta" {
                _safe_put(event_queue, {
                    "type": "claude_thinking_delta",
                    "text": delta.get("thinking", ""),
                    "timestamp": time.time()
                });
            }

        } elif event_type == "content_block_stop" {
            index = event.get("index", 0);
            _safe_put(event_queue, {
                "type": "claude_tool_end",
                "index": index,
                "timestamp": time.time()
            });

        } elif event_type == "message_stop" {
            _safe_put(event_queue, {
                "type": "claude_message_stop",
                "timestamp": time.time()
            });
        }

    } elif msg_type == "assistant" {
        # Complete assistant message (after tool loop resolves)
        message = raw.get("message", {});
        content_blocks = message.get("content", []);

        # Extract text content
        text_parts: list = [];
        tool_results: list = [];
        for block in content_blocks {
            if block.get("type") == "text" {
                text_parts.append(block.get("text", ""));
            } elif block.get("type") == "tool_result" {
                tool_results.append({
                    "tool_use_id": block.get("tool_use_id", ""),
                    "content": str(block.get("content", ""))[:500]
                });
            }
        }

        full_text = "\n".join(text_parts) if text_parts else "";
        _safe_put(event_queue, {
            "type": "claude_message_complete",
            "content": full_text,
            "tool_results": tool_results,
            "timestamp": time.time()
        });

    } elif msg_type == "result" {
        # Do NOT emit claude_done here — _run_claude emits it AFTER
        # file sync + autosave so the frontend doesn't stop polling early.
    }
}


"""Put event on EventBus (size is managed by EventBus max_size)."""
def _safe_put(bus: EventBus, event: dict) -> None {
    bus.publish(event);
}


# ===========================================================================
# Background Execution
# ===========================================================================

"""Check if a path contains hidden directory segments."""
def _has_hidden_segment(rel_path: str) -> bool {
    parts = rel_path.split(os.sep);
    for p in parts {
        if p.startswith(".") {
            return True;
        }
    }
    return False;
}


"""Check if src file is newer than dst or dst doesn't exist."""
def _needs_sync(src: str, dst: str) -> bool {
    if not os.path.exists(dst) {
        return True;
    }
    try {
        return os.path.getmtime(src) > os.path.getmtime(dst);
    } except Exception {
        return True;
    }
}


"""Sync changed files from preview_dir to repo_path after Claude edits.
Returns list of relative paths that were synced."""
def _sync_preview_to_repo(preview_dir: str, repo_path: str, event_queue: EventBus) -> list {
    synced_files: list = [];
    if not preview_dir or not repo_path or preview_dir == repo_path {
        return synced_files;
    }
    try {
        walk_entries = list(os.walk(preview_dir));
        for entry in walk_entries {
            root_dir = entry[0];
            files = entry[2];

            rel_root = os.path.relpath(root_dir, preview_dir);
            if rel_root != "." {
                if _has_hidden_segment(rel_root) {
                    continue;
                }
                top_dir = rel_root.split(os.sep)[0];
                if top_dir in _EXCLUDED_DIRS {
                    continue;
                }
            }

            for fname in files {
                if fname.startswith(".") { continue; }
                src = os.path.join(root_dir, fname);
                rel_path = os.path.relpath(src, preview_dir);
                dst = os.path.join(repo_path, rel_path);

                if _needs_sync(src, dst) {
                    Path(dst).parent.mkdir(parents=True, exist_ok=True);
                    shutil.copy2(src, dst);
                    synced_files.append(rel_path);
                    _safe_put(event_queue, {
                        "type": "claude_file_synced",
                        "path": rel_path,
                        "timestamp": time.time()
                    });
                }
            }
        }
    } except Exception as e {
        print(f"[claude_adapter] sync error: {e}");
    }
    return synced_files;
}


"""Re-write synced files in the preview dir using standard open(w).write() pattern.
Claude CLI may use atomic writes (temp file + rename) that some file watchers miss.
Re-writing forces the same write event as manual editor saves (write_preview_file),
which the jac start --dev watchdog reliably detects for HMR."""
def _touch_preview_files(preview_dir: str, synced_files: list) -> None {
    for rel_path in synced_files {
        full_path = os.path.join(preview_dir, rel_path);
        try {
            if os.path.isfile(full_path) {
                with open(full_path, "rb") as f {
                    content = f.read();
                }
                with open(full_path, "wb") as f {
                    f.write(content);
                }
            }
        } except Exception as e {
            print(f"[claude_adapter] touch error for {rel_path}: {e}");
        }
    }
}


"""Detect recently-modified files in a directory (for worktree mode where cwd == repo_path).
Uses since_time (turn start timestamp) to find files Claude modified during this turn.
Falls back to 120-second window if since_time is not provided.
Emits claude_file_synced events and returns list of relative paths."""
def _detect_changed_files(cwd: str, event_queue: EventBus, since_time: float = 0) -> list {
    changed: list = [];
    if not cwd or not os.path.isdir(cwd) {
        return changed;
    }
    cutoff = (since_time - 2) if since_time > 0 else (time.time() - 120);
    try {
        walk_entries = list(os.walk(cwd));
        for entry in walk_entries {
            root_dir = entry[0];
            files = entry[2];
            rel_root = os.path.relpath(root_dir, cwd);
            if rel_root != "." {
                if _has_hidden_segment(rel_root) {
                    continue;
                }
                top_dir = rel_root.split(os.sep)[0];
                if top_dir in _EXCLUDED_DIRS {
                    continue;
                }
            }
            for fname in files {
                if fname.startswith(".") { continue; }
                src = os.path.join(root_dir, fname);
                try {
                    mtime = os.path.getmtime(src);
                } except Exception {
                    continue;
                }
                if mtime >= cutoff {
                    rel_path = os.path.relpath(src, cwd);
                    changed.append(rel_path);
                    _safe_put(event_queue, {
                        "type": "claude_file_synced",
                        "path": rel_path,
                        "timestamp": time.time()
                    });
                }
            }
        }
    } except Exception as e {
        print("[claude_adapter] detect changed files error: " + str(e));
    }
    return changed;
}


"""Kill a timed-out Claude process from a Timer thread."""
def _kill_timed_out_process(key: str, event_queue: EventBus) -> None {
    with _claude_lock {
        proc = _claude_processes.get(key);
    }
    if proc {
        try { proc.kill(); } except Exception { }
        _safe_put(event_queue, {
            "type": "claude_error",
            "error": "Claude turn timed out after " + str(CLAUDE_TURN_TIMEOUT) + " seconds",
            "timestamp": time.time()
        });
    }
}


"""Run a single Claude CLI subprocess turn. Returns dict with session_id and result metadata."""
def _run_single_turn(
    key: str,
    args: list,
    message: str,
    cwd: str,
    event_queue: EventBus,
    accumulated_text: list
) -> dict {
    proc = subprocess.Popen(
        args,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        cwd=cwd,
        env=dict(os.environ)
    );

    with _claude_lock {
        _claude_processes[key] = proc;
    }

    if message {
        proc.stdin.write(message.encode("utf-8"));
    }
    proc.stdin.close();

    captured_sid = "";
    result_meta: dict = {};

    for raw_line in proc.stdout {
        line = raw_line.decode("utf-8", errors="replace").strip();
        if not line {
            continue;
        }
        try {
            parsed = json.loads(line);
            _parse_claude_event(parsed, event_queue, accumulated_text);

            if parsed.get("type") == "system" and parsed.get("subtype") == "init" {
                sid = parsed.get("session_id", "");
                if sid {
                    _claude_sessions[key] = sid;
                    captured_sid = sid;
                }
            }
            if parsed.get("type") == "result" {
                sid = parsed.get("session_id", "");
                if sid {
                    _claude_sessions[key] = sid;
                    captured_sid = sid;
                }
                result_meta = {
                    "session_id": parsed.get("session_id", ""),
                    "cost": parsed.get("cost_usd", parsed.get("cost", 0)),
                    "duration_ms": parsed.get("duration_ms", 0),
                    "usage": parsed.get("usage", {}),
                    "is_error": parsed.get("is_error", False)
                };
            }
        } except json.JSONDecodeError as e {
            print(f"[claude_adapter] JSON parse error: {e} line={line[:200]}");
        }
    }

    proc.wait(timeout=30);
    exit_code = proc.returncode;

    stderr_text = "";
    try { stderr_text = proc.stderr.read().decode("utf-8", errors="replace").strip(); }
    except Exception { }

    if exit_code != 0 and stderr_text {
        _safe_put(event_queue, {
            "type": "claude_error",
            "error": stderr_text[:1000],
            "exit_code": exit_code,
            "timestamp": time.time()
        });
    }

    with _claude_lock {
        _claude_processes.pop(key, None);
    }

    return {"session_id": captured_sid, "result_meta": result_meta};
}


"""Run claude -p in background thread. Parse NDJSON stdout, push events.
After Claude finishes, runs jac check and feeds errors back for auto-fix.
Checks _claude_cancelled before post-processing to support clean stop."""
def _run_claude(
    key: str,
    args: list,
    message: str,
    cwd: str,
    event_queue: EventBus,
    repo_path: str = ""
) -> None {
    print(f"[claude_adapter] START key={key} cwd={cwd}");
    accumulated_text: list = [];
    final_result_meta: dict = {};
    captured_sid = "";
    turn_start = time.time();

    try {
        # Set up Jac workspace (CLAUDE.md + .mcp.json) on first turn
        _setup_jac_workspace(cwd);

        # Run the main Claude turn with timeout protection
        timeout_timer = Timer(float(CLAUDE_TURN_TIMEOUT), _kill_timed_out_process, args=[key, event_queue]);
        timeout_timer.start();
        try {
            turn_result = _run_single_turn(key, args, message, cwd, event_queue, accumulated_text);
        } finally {
            timeout_timer.cancel();
        }
        captured_sid = turn_result.get("session_id", "");
        final_result_meta = turn_result.get("result_meta", {});

        # If we got text but no explicit done event, synthesize one
        if accumulated_text {
            full_text = "".join(accumulated_text);
            if full_text.strip() {
                _safe_put(event_queue, {
                    "type": "claude_message_complete",
                    "content": full_text,
                    "tool_results": [],
                    "timestamp": time.time()
                });
            }
        }

        # Check cancellation before post-processing
        if _claude_cancelled.get(key, False) {
            print(f"[claude_adapter] Cancelled before jac check: key={key}");
            return;
        }

        # === Jac Check + Error Feedback Loop ===
        check_errors = _run_jac_check(cwd);
        preview_errors = _read_preview_errors(cwd);

        all_errors = "";
        if check_errors {
            all_errors = "jac check errors:\n" + check_errors;
        }
        if preview_errors {
            if all_errors {
                all_errors = all_errors + "\n\nPreview/HMR errors:\n" + preview_errors;
            } else {
                all_errors = "Preview/HMR errors:\n" + preview_errors;
            }
        }

        retry_count = 0;
        while all_errors and retry_count < CLAUDE_MAX_CHECK_RETRIES {
            if _claude_cancelled.get(key, False) {
                print(f"[claude_adapter] Cancelled during retry loop: key={key}");
                return;
            }

            retry_count = retry_count + 1;
            print(f"[claude_adapter] jac check failed (attempt {retry_count}), feeding errors back to Claude");

            _safe_put(event_queue, {
                "type": "claude_check_retry",
                "attempt": retry_count,
                "errors": all_errors[:500],
                "timestamp": time.time()
            });

            # Build retry args using session resume
            session_id = _claude_sessions.get(key, captured_sid);
            binary = args[0];
            retry_args = [
                binary, "-p",
                "--output-format", "stream-json",
                "--verbose",
                "--include-partial-messages",
            ];
            if session_id {
                retry_args.extend(["--resume", session_id]);
            }

            # Feed errors back as the next message
            error_msg = "The code you wrote has errors. Please fix them:\n\n" + all_errors + "\n\nRun `jac check main.jac` after fixing to verify.";

            retry_text: list = [];
            retry_timeout = Timer(float(CLAUDE_TURN_TIMEOUT), _kill_timed_out_process, args=[key, event_queue]);
            retry_timeout.start();
            try {
                retry_result = _run_single_turn(key, retry_args, error_msg, cwd, event_queue, retry_text);
            } finally {
                retry_timeout.cancel();
            }

            if retry_text {
                accumulated_text.extend(retry_text);
            }
            # Update result meta from retry if available
            retry_meta = retry_result.get("result_meta", {});
            if retry_meta {
                final_result_meta = retry_meta;
            }

            # Re-check
            check_errors = _run_jac_check(cwd);
            preview_errors = _read_preview_errors(cwd);

            all_errors = "";
            if check_errors {
                all_errors = "jac check errors:\n" + check_errors;
            }
            if preview_errors {
                if all_errors {
                    all_errors = all_errors + "\n\nPreview/HMR errors:\n" + preview_errors;
                } else {
                    all_errors = "Preview/HMR errors:\n" + preview_errors;
                }
            }
        }

        if all_errors {
            _safe_put(event_queue, {
                "type": "claude_check_failed",
                "errors": all_errors[:1000],
                "timestamp": time.time()
            });
        } else {
            if retry_count > 0 {
                _safe_put(event_queue, {
                    "type": "claude_check_passed",
                    "attempts": retry_count + 1,
                    "timestamp": time.time()
                });
            }
        }

        # Check cancellation before file sync + autosave
        if _claude_cancelled.get(key, False) {
            print(f"[claude_adapter] Cancelled before file sync: key={key}");
            return;
        }

        # Single-dir architecture: cwd IS the repo dir. No sync needed.
        # Just touch changed files for HMR + autosave version.
        if repo_path and cwd != repo_path {
            # Legacy two-dir fallback (K8s mode may still use separate dirs)
            synced = _sync_preview_to_repo(cwd, repo_path, event_queue);
            if synced {
                _touch_preview_files(cwd, synced);
            }
            with _autosave_lock {
                version_res = autosave_version(
                    repo_path,
                    "claude_chat",
                    "chore: Claude Code changes"
                );
            }
            if version_res.get("success", False) {
                _safe_put(event_queue, {
                    "type": "claude_version_saved",
                    "commit_sha": version_res.get("commit_sha", ""),
                    "timestamp": time.time()
                });
                print(f"[claude_adapter] Version saved: {version_res.get('commit_sha', '')[:8]}");
            }
        } elif repo_path and cwd == repo_path {
            # Worktree mode: cwd IS the repo — no sync needed, but still
            # touch recently-changed files for HMR + autosave version.
            changed = _detect_changed_files(cwd, event_queue, turn_start);
            if changed {
                _touch_preview_files(cwd, changed);
            }
            with _autosave_lock {
                version_res = autosave_version(
                    repo_path,
                    "claude_chat",
                    "chore: Claude Code changes"
                );
            }
            if version_res.get("success", False) {
                _safe_put(event_queue, {
                    "type": "claude_version_saved",
                    "commit_sha": version_res.get("commit_sha", ""),
                    "timestamp": time.time()
                });
                print(f"[claude_adapter] Version saved (worktree): {version_res.get('commit_sha', '')[:8]}");
            }
        }

        # Emit claude_done LAST — after sync + autosave so frontend
        # receives all file_synced/version_saved events before stopping poll.
        _safe_put(event_queue, {
            "type": "claude_done",
            "session_id": final_result_meta.get("session_id", captured_sid),
            "cost": final_result_meta.get("cost", 0),
            "duration_ms": final_result_meta.get("duration_ms", 0),
            "usage": final_result_meta.get("usage", {}),
            "is_error": final_result_meta.get("is_error", False),
            "timestamp": time.time()
        });

        print(f"[claude_adapter] DONE key={key} retries={retry_count}");

    } except subprocess.TimeoutExpired {
        _safe_put(event_queue, {
            "type": "claude_error",
            "error": "Claude turn timed out",
            "timestamp": time.time()
        });
        try {
            with _claude_lock {
                proc = _claude_processes.pop(key, None);
            }
            if proc { proc.kill(); }
        } except Exception { }

    } except Exception as e {
        print(f"[claude_adapter] Error: {e}");
        import traceback;
        traceback.print_exc();
        _safe_put(event_queue, {
            "type": "claude_error",
            "error": str(e),
            "timestamp": time.time()
        });

    } finally {
        with _claude_lock {
            _claude_processing[key] = False;
            _claude_processes.pop(key, None);
        }
    }
}


# ===========================================================================
# Public API
# ===========================================================================

"""Send a turn to Claude Code CLI. Spawns a new process per turn.
First turn creates a session; subsequent turns use --resume."""
def send_claude_turn(
    user_id: str,
    project_id: str,
    message: str,
    cwd: str,
    model: str = "",
    allowed_tools: str = "",
    repo_path: str = "",
    persisted_session_id: str = "",
    force_new_session: bool = False,
    images: list = []
) -> dict {
    key = _claude_key(user_id, project_id);

    # Atomically check + set processing flag under lock to prevent double-start race
    with _claude_lock {
        if _claude_processing.get(key, False) {
            return {"success": False, "error": "Claude is already processing for this project"};
        }
        _claude_processing[key] = True;
        _claude_cancelled[key] = False;
        _claude_event_queues[key] = EventBus(max_size=CLAUDE_MAX_QUEUE_SIZE);
    }

    binary = _find_claude_binary();
    if not binary {
        with _claude_lock {
            _claude_processing[key] = False;
        }
        return {
            "success": False,
            "error": "Claude CLI not found. Install with: npm install -g @anthropic-ai/claude-code"
        };
    }

    # Validate allowed_tools against whitelist
    validated_tools = "";
    if allowed_tools {
        requested = [t.strip() for t in allowed_tools.split(",") if t.strip()];
        safe_tools: list = [];
        for t in requested {
            if t in ALLOWED_TOOLS_WHITELIST {
                safe_tools.append(t);
            }
        }
        validated_tools = ",".join(safe_tools) if safe_tools else "Read,Edit,Bash,Glob,Grep,Write";
    }

    # Build command args
    args = [
        binary, "-p",
        "--output-format", "stream-json",
        "--verbose",
        "--include-partial-messages",
    ];

    # Resolve session ID for --resume.
    # force_new_session: don't resume any session (used for new worktree threads
    #   to prevent cross-thread session contamination — each worktree thread needs
    #   its own session since Claude CLI sessions are scoped by working directory).
    # persisted_session_id: thread-specific session from graph (takes priority over
    #   in-memory project-global session to avoid resuming wrong thread's session).
    session_id = "";
    if force_new_session {
        _claude_sessions.pop(key, None);
    } elif persisted_session_id {
        session_id = persisted_session_id;
        _claude_sessions[key] = session_id;
    } else {
        session_id = _claude_sessions.get(key, "");
    }
    if session_id {
        args.extend(["--resume", session_id]);
    }

    if model {
        args.extend(["--model", model]);
    }

    if validated_tools {
        args.extend(["--allowedTools", validated_tools]);
    }

    # If images attached, save to disk and prepend file paths to message
    actual_message = message;
    if images and len(images) > 0 {
        try {
            import base64;
            img_dir = os.path.join(cwd, ".jac-ide", "chat-images");
            os.makedirs(img_dir, exist_ok=True);
            img_paths: list = [];
            for (idx, img) in enumerate(images) {
                data_url = img.get("data_url", "") if isinstance(img, dict) else str(img);
                if not data_url or not data_url.startswith("data:") { continue; }
                # Parse data URL: data:image/png;base64,AAAA...
                header_end = data_url.index(",");
                header = data_url[:header_end];
                b64_data = data_url[header_end + 1:];
                ext = "png";
                if "image/jpeg" in header { ext = "jpg"; }
                elif "image/gif" in header { ext = "gif"; }
                elif "image/webp" in header { ext = "webp"; }
                img_path = os.path.join(img_dir, "img_" + str(int(time.time() * 1000)) + "_" + str(idx) + "." + ext);
                with open(img_path, "wb") as f {
                    f.write(base64.b64decode(b64_data));
                }
                img_paths.append(img_path);
            }
            if img_paths {
                prefix = "[User attached image(s). Read these files to see them: " + ", ".join(img_paths) + "]\n\n";
                actual_message = prefix + message;
            }
        } except Exception as img_err {
            print("[claude_adapter] Failed to save images: " + str(img_err));
        }
    }

    # Submit to thread pool
    _claude_pool.submit(
        _run_claude,
        key, args, actual_message, cwd,
        _claude_event_queues[key], repo_path
    );

    return {"success": True, "status": "processing", "session_id": session_id};
}


"""Drain all pending events for a subscriber (non-destructive fan-out)."""
def drain_claude_events(user_id: str, project_id: str, connection_id: str = "") -> list {
    bus = _claude_event_queues.get(_claude_key(user_id, project_id));
    if not bus {
        return [];
    }
    cid = connection_id if connection_id else _claude_key(user_id, project_id) + "::default";
    return bus.drain(cid);
}


"""Check if Claude is currently processing for a project."""
def is_claude_processing(user_id: str, project_id: str) -> bool {
    return _claude_processing.get(_claude_key(user_id, project_id), False);
}


"""Interrupt a running Claude turn by sending SIGINT."""
def interrupt_claude(user_id: str, project_id: str) -> dict {
    key = _claude_key(user_id, project_id);
    with _claude_lock {
        proc = _claude_processes.get(key);
    }
    if not proc {
        return {"success": False, "error": "No running Claude process"};
    }
    try {
        proc.send_signal(signal.SIGINT);
        return {"success": True};
    } except Exception as e {
        return {"success": False, "error": str(e)};
    }
}


"""Stop Claude session entirely — kill process, set cancelled flag, and clear state."""
def stop_claude_session(user_id: str, project_id: str) -> dict {
    key = _claude_key(user_id, project_id);

    # Set cancelled flag FIRST so background thread skips post-processing
    _claude_cancelled[key] = True;

    with _claude_lock {
        proc = _claude_processes.pop(key, None);
        _claude_processing[key] = False;
    }
    if proc {
        try { proc.kill(); } except Exception { }
    }

    _claude_sessions.pop(key, None);
    _claude_event_queues.pop(key, None);

    return {"success": True};
}


"""Clear session for a project (e.g. on project delete)."""
def clear_claude_session(user_id: str, project_id: str) -> None {
    stop_claude_session(user_id, project_id);
}


"""Get Claude session info for a project."""
def get_claude_session_info(user_id: str, project_id: str) -> dict {
    key = _claude_key(user_id, project_id);
    return {
        "session_id": _claude_sessions.get(key, ""),
        "processing": _claude_processing.get(key, False),
        "has_session": key in _claude_sessions
    };
}
