"""JacCoder adapter — clean interface between JacBuilder and JacCoder.

Uses jac-coder's public API + get_agent_prefix for SubAgent event labeling.
"""

import os;
import time;
import shutil;
import threading;
import from pathlib { Path }
import from concurrent.futures { ThreadPoolExecutor }
import from .event_bus { EventBus }

import from jac_coder.events { get_agent_prefix }
import from jac_coder.api {
    initialize,
    create_session,
    chat,
    list_sessions,
    get_session,
    close_session,
    set_sandbox_root,
    abort_session
}
import from jac_coder.events { request_abort_thread, clear_abort }
import from jac_coder.tool.preview { set_preview_url }
import from jac_coder.util.sandbox { set_browser_exec }
import subprocess as _subprocess;
import from functools { partial as _partial }
import re as _re;

glob _max_workers: int = int(os.environ.get("JACCODER_MAX_WORKERS", "20")),
     _pool = ThreadPoolExecutor(max_workers=_max_workers),
     _session_map: dict = {},
     _event_queues: dict = {},
     _ai_processing: dict = {},
     _agent_threads: dict = {},
     _agent_gen: dict = {},
     _tail_threads: dict = {},
     _processing_lock = threading.Lock(),
     _MAX_PREVIEW_LOG_LINES: int = 500;


# ===========================================================================
# Preview Log Tailing (K8s sandbox mode)
# ===========================================================================
"""Tail K8s sandbox pod logs into .jac-preview.log so JacCoder can detect runtime errors.

Polls sandbox.logs() every 2s and appends new output to {preview_dir}/.jac-preview.log.
The file is bounded to _MAX_PREVIEW_LOG_LINES lines to avoid unbounded growth.
Runs as a daemon thread for the duration of a JacCoder session.
"""
def _tail_sandbox_log(sandbox: Any, sid: str, log_file: str, stop: Any) -> None {
    offset = 0;
    while not stop.is_set() {
        try {
            result = sandbox.logs(sid, offset);
            content = result.get("content", "");
            new_offset = result.get("offset", offset);
            if content {
                with open(log_file, "a", encoding="utf-8") as f {
                    f.write(content);
                }
                with open(log_file, "r", encoding="utf-8") as f {
                    lines = f.readlines();
                }
                if len(lines) > _MAX_PREVIEW_LOG_LINES {
                    with open(log_file, "w", encoding="utf-8") as f {
                        f.writelines(lines[-_MAX_PREVIEW_LOG_LINES:]);
                    }
                }
                offset = new_offset;
            }
        } except Exception {
            ;
        }
        stop.wait(2.0);
    }
    try {
        os.remove(log_file);
    } except Exception {
        ;
    }
}


# ===========================================================================
# Initialization
# ===========================================================================
"""Initialize jac-coder for web mode (no stdin prompts, auto-allow writes)."""
def init_jaccoder_web_mode -> None {
    # Set JACCODER_ROOT so jac-coder can find its data files from any CWD
    if not os.environ.get("JACCODER_ROOT") {
        import sys as _sys;
        for p in _sys.path {
            if os.path.isdir(os.path.join(p, "jac_coder", "data", "rules")) {
                os.environ["JACCODER_ROOT"] = p;
                print(f"[jaccoder_adapter] JACCODER_ROOT={p}");
                break;
            }
        }
    }
    initialize("web");
    print("[jaccoder_adapter] JacCoder initialized in web mode.");
}


# ===========================================================================
# Session Management
# ===========================================================================
"""Get or create a JacCoder session for a project."""
def get_or_create_session(user_id: str, project_id: str, directory: str) -> str {
    key = f"{user_id}::{project_id}";
    if key in _session_map {
        return _session_map[key];
    }

    # Check existing sessions — title scoped to (user_id, project_id) to prevent
    # cross-user session sharing when project IDs collide (e.g. cloned templates).
    session_title = f"JacBuilder:{user_id}:{project_id}";
    for s in list_sessions() {
        if s.get("title") == session_title {
            _session_map[key] = s["id"];
            print(f"[jaccoder_adapter] Found existing session: {s['id']}");
            return s["id"];
        }
    }

    # Create new session
    result = create_session(
        directory=directory, title=session_title, agent="build"
    );
    session_id = result.get("session_id", "");
    if session_id {
        _session_map[key] = session_id;
        print(f"[jaccoder_adapter] Created session: {session_id} (dir: {directory})");
    } else {
        print(f"[jaccoder_adapter] Failed to create session: {result}");
    }
    return session_id;
}


"""Clear session mapping for a project."""
def clear_session(user_id: str, project_id: str, project_node: Any = None) -> None {
    key = f"{user_id}::{project_id}";
    sid = _session_map.pop(key, "");
    _event_queues.pop(key, None);
    _ai_processing.pop(key, None);
    tail = _tail_threads.pop(key, None);
    if tail {
        (t, stop_event) = tail;
        stop_event.set();
    }
    if sid {
        close_session(sid);
    }
    if project_node is not None {
        try {
            project_node.ai_processing = False;
        } except Exception { }
    }
}


# ===========================================================================
# Event Queue
# ===========================================================================
"""Drain all pending events from the queue (non-blocking)."""
def drain_events(user_id: str, project_id: str, project_node: Any = None, connection_id: str = "") -> list {
    bus = _event_queues.get(f"{user_id}::{project_id}");
    if not bus {
        if project_node is not None and project_node.ai_processing {
            return [
                {
                    "type": "agent_activity",
                    "tool": "processing",
                    "detail": "Agent running on another instance",
                    "timestamp": time.time()
                }
            ];
        }
        return [];
    }
    cid = connection_id if connection_id else f"{user_id}::{project_id}::default";
    return bus.drain(cid);
}


"""Check if AI is currently processing for a project."""
def is_ai_processing(user_id: str, project_id: str, project_node: Any = None) -> bool {
    local = _ai_processing.get(f"{user_id}::{project_id}");
    if local is not None {
        return local;
    }
    if project_node is not None {
        return project_node.ai_processing;
    }
    return False;
}


# ===========================================================================
# Event Handler (bridges jac-coder events → jacBuilder event queue)
# ===========================================================================

"""Strip temp dir prefix from a path, returning a clean relative path."""
def _clean_path(path_str: str) -> str {
    if not path_str {
        return "";
    }
    import tempfile;
    # Strip <tempdir>/jac-preview-<uuid>-prj_<id>/ prefix (cross-platform)
    tmp = _re.escape(tempfile.gettempdir().replace("\\", "/"));
    cleaned = _re.sub(tmp + r'/jac-preview-[a-f0-9\-]+-prj_\d+/', '', path_str.replace("\\", "/"));
    if cleaned != path_str.replace("\\", "/") {
        return cleaned;
    }
    # Also strip generic temp dirs
    cleaned = _re.sub(tmp + r'/[^/]+/', '', path_str.replace("\\", "/"));
    return cleaned;
}


"""Build a human-readable category + label from a tool name and its args dict."""
def _categorize_tool(tool_name: str, args: dict) -> tuple {
    if not tool_name {
        return ("Tool", "");
    }
    name = tool_name.lower().strip();
    if name in ["read_file", "read"] {
        fp = _clean_path(str(args.get("file_path", args.get("path", ""))));
        return ("Read", os.path.basename(fp) if fp else "");
    }
    if name in ["edit_code", "edit"] {
        fp = _clean_path(str(args.get("file_path", args.get("path", ""))));
        return ("Edit", os.path.basename(fp) if fp else "");
    }
    if name in ["write_code", "write"] {
        fp = _clean_path(str(args.get("file_path", args.get("path", ""))));
        return ("Write", os.path.basename(fp) if fp else "");
    }
    if name in ["run_command", "bash"] {
        cmd = str(args.get("command", ""))[:100];
        return ("Bash", cmd);
    }
    if name == "jac_docs" {
        q = str(args.get("query", ""))[:80];
        return ("Jac docs", q);
    }
    if name == "jac_check" {
        fp = _clean_path(str(args.get("file_path", args.get("path", ""))));
        return ("Check", os.path.basename(fp) if fp else "");
    }
    if name == "jac_run" {
        fp = _clean_path(str(args.get("file_path", args.get("path", ""))));
        return ("Run", os.path.basename(fp) if fp else "");
    }
    if name == "grep_search" {
        pat = str(args.get("pattern", args.get("query", "")))[:60];
        return ("Search", pat);
    }
    if name == "find_files" {
        pat = str(args.get("pattern", args.get("glob", "")))[:60];
        return ("Find", pat);
    }
    if name == "list_files" {
        d = _clean_path(str(args.get("directory", args.get("path", ""))));
        return ("List", os.path.basename(d) if d else "");
    }
    if name.startswith("git_") {
        sub = name.replace("git_", "");
        return ("Git", sub);
    }
    if name == "spawn_agent" {
        task = str(args.get("task", ""))[:60];
        mode = str(args.get("mode", "worker"));
        return ("Agent", f"[{mode}] {task}" if task else mode);
    }
    if name == "think" {
        thought = str(args.get("thought", ""))[:80];
        return ("Think", thought);
    }
    if name == "web_search" {
        q = str(args.get("query", ""))[:60];
        return ("Web search", q);
    }
    if name == "web_fetch" {
        url = str(args.get("url", ""))[:60];
        return ("Web fetch", url);
    }
    if name == "validate_project" {
        return ("Validate", "project");
    }
    if name == "analyze_project" {
        return ("Analyze", "project");
    }
    if name == "find_symbol" {
        sym = str(args.get("symbol", args.get("name", "")))[:40];
        return ("Symbol", sym);
    }
    if name == "scaffold_project" {
        tpl = str(args.get("template", ""))[:40];
        return ("Scaffold", tpl);
    }
    if name == "update_todos" {
        return ("Todos", "update plan");
    }
    if name == "ask_question" {
        q = str(args.get("question", ""))[:60];
        return ("Question", q);
    }
    if name == "browser_open" {
        url = str(args.get("url", ""))[:60];
        return ("Browser", f"open {url}" if url else "open preview");
    }
    if name == "browser_do" {
        cmd = str(args.get("command", ""))[:60];
        return ("Browser", cmd);
    }
    if name == "browser_state" {
        return ("Browser", "get page state");
    }
    if name == "browser_close" {
        return ("Browser", "close session");
    }
    # Fallback: capitalize tool name
    return (tool_name.replace("_", " ").title(), "");
}


# Human-readable labels for raw arg keys
glob _ARG_LABELS: dict = {
    "file_path": "FILE",
    "path": "PATH",
    "command": "COMMAND",
    "query": "QUERY",
    "pattern": "PATTERN",
    "directory": "DIR",
    "old_string": "OLD",
    "new_string": "NEW",
    "replace_all": "REPLACE ALL",
    "content": "CONTENT",
    "thought": "THOUGHT",
    "task": "TASK",
    "mode": "MODE",
    "url": "URL",
    "template": "TEMPLATE",
    "symbol": "SYMBOL",
    "file_pattern": "FILE PATTERN",
    "max_results": "MAX RESULTS",
    "glob": "GLOB"
};


"""Create event handler that syncs files to repo and pushes events to frontend queue."""
def _make_event_handler(
    preview_dir: str,
    event_queue: EventBus,
    repo_path: str = "",
    sandbox_write_fn: Any = None
) -> Any {
    # Track whether we've seen llm_tool_call events — if so, suppress
    # the lower-level tool_start/tool_end to avoid duplicate timeline entries.
    has_llm_events = [False];

    def handler(event_type: str, data: dict) -> None {
        if event_type == "file_written" or event_type == "file_edited" {
            file_path = data.get("path", "");
            if not file_path or not file_path.startswith(preview_dir) {
                return;
            }
            rel_path = os.path.relpath(file_path, preview_dir);
            # Single-dir: skip copy if preview_dir IS the repo dir
            if repo_path and os.path.realpath(preview_dir) != os.path.realpath(repo_path) {
                repo_file = os.path.join(repo_path, rel_path);
                Path(repo_file).parent.mkdir(parents=True, exist_ok=True);
                shutil.copy2(file_path, repo_file);
            }

            # Sync to sandbox pod for live HMR
            if sandbox_write_fn {
                try {
                    with open(file_path, "r", encoding="utf-8") as f {
                        content = f.read();
                    }
                    sandbox_write_fn(rel_path, content);
                } except Exception as e {
                    print(f"[jaccoder_adapter] Sandbox sync failed: {e}");
                }
            }

            event_queue.publish(
                {"type": "file_promoted", "path": rel_path, "timestamp": time.time()}
            );
        } elif event_type == "tool_start" {
            # Suppress when llm-level events are active (avoids duplicates)
            if has_llm_events[0] {
                return;
            }
            prefix = "";
            try {
                prefix = get_agent_prefix();
            } except Exception { }
            event_queue.publish(
                {
                    "type": "agent_activity",
                    "tool": data.get("tool", ""),
                    "detail": data.get("detail", ""),
                    "message": data.get("message", ""),
                    "step": data.get("step", 0),
                    "agent_prefix": prefix,
                    "timestamp": time.time()
                }
            );
        } elif event_type == "tool_end" {
            # Suppress when llm-level events are active (avoids duplicates)
            if has_llm_events[0] {
                return;
            }
            prefix = "";
            try {
                prefix = get_agent_prefix();
            } except Exception { }
            event_queue.publish(
                {
                    "type": "agent_tool_done",
                    "tool": data.get("tool", ""),
                    "step": data.get("step", 0),
                    "status": data.get("status", "done"),
                    "duration_ms": data.get("duration_ms", 0),
                    "message": data.get("message", ""),
                    "agent_prefix": prefix,
                    "timestamp": time.time()
                }
            );
        } elif event_type == "turn_summary" {
            event_queue.publish(
                {
                    "type": "turn_summary",
                    "tools_count": data.get("tools_count", 0),
                    "files_modified": data.get("files_modified", []),
                    "errors": data.get("errors", 0),
                    "duration_s": data.get("duration_s", 0.0),
                    "timestamp": time.time()
                }
            );
        } elif event_type == "context_compaction" {
            status = data.get("status", "");
            if status == "started" {
                turns = data.get("turns_to_summarize", 0);
                event_queue.publish({
                    "type": "agent_activity",
                    "tool": "context",
                    "detail": f"Summarizing {turns} earlier turns...",
                    "timestamp": time.time()
                });
            }
        } elif event_type == "llm_thought" {
            has_llm_events[0] = True;
            content = data.get("content", "");
            if content {
                event_queue.publish({
                    "type": "llm_thought",
                    "content": content[:1000],
                    "iteration": data.get("iteration", 0),
                    "timestamp": time.time()
                });
            }
        } elif event_type == "llm_tool_call" {
            has_llm_events[0] = True;
            tool = data.get("tool", "");
            args = data.get("args", {});
            if not isinstance(args, dict) {
                args = {};
            }
            call_id = data.get("call_id", "");
            cat_label = _categorize_tool(tool, args);
            category = cat_label[0];
            label = cat_label[1];

            # Build clean args summary for IN display
            args_summary = {};
            for k in args {
                # Skip internal/noisy keys
                if k in ["call_id", "iteration"] {
                    continue;
                }
                val = str(args[k]);
                # Clean preview dir paths from values
                val = _clean_path(val);
                # Keep old/new strings larger for diff rendering; keep thought full for narration
                max_len = 5000 if k in ["old_string", "new_string", "content", "thought"] else 200;
                if len(val) > max_len {
                    val = val[:max_len] + "...";
                }
                # Use human-readable label for key
                display_key = _ARG_LABELS.get(k, k.upper());
                args_summary[display_key] = val;
            }

            # Compute edit summary for Edit/Write categories
            edit_summary = "";
            if category == "Edit" {
                old_str = str(args.get("old_string", ""));
                new_str = str(args.get("new_string", ""));
                if old_str and new_str {
                    old_lines = len(old_str.strip().split("\n"));
                    new_lines = len(new_str.strip().split("\n"));
                    diff = new_lines - old_lines;
                    if diff > 0 {
                        edit_summary = f"+{diff} lines";
                    } elif diff < 0 {
                        edit_summary = f"{diff} lines";
                    } else {
                        edit_summary = f"changed {old_lines} lines";
                    }
                } elif new_str {
                    new_lines = len(new_str.strip().split("\n"));
                    edit_summary = f"+{new_lines} lines";
                }
            } elif category == "Write" {
                content = str(args.get("content", ""));
                if content {
                    wlines = len(content.strip().split("\n"));
                    edit_summary = f"{wlines} lines";
                }
            }

            event_queue.publish({
                "type": "llm_tool_call",
                "tool": tool,
                "category": category,
                "label": label,
                "call_id": call_id,
                "args": args_summary,
                "summary": edit_summary,
                "iteration": data.get("iteration", 0),
                "timestamp": time.time()
            });
        } elif event_type == "llm_tool_result" {
            has_llm_events[0] = True;
            event_queue.publish({
                "type": "llm_tool_result",
                "tool": data.get("tool", ""),
                "call_id": data.get("call_id", ""),
                "result_preview": str(data.get("result", ""))[:500],
                "iteration": data.get("iteration", 0),
                "timestamp": time.time()
            });
        } elif event_type == "llm_steps_done" {
            event_queue.publish(
                {
                    "type": "llm_steps_done",
                    "iterations": data.get("iterations", 0),
                    "timestamp": time.time()
                }
            );
        }
    }
    return handler;
}


# ===========================================================================
# Browser Exec via Sandbox Pod
# ===========================================================================
"""Run an agent-browser command inside a K8s sandbox pod via kubectl exec."""
def _sandbox_browser_exec(pod_name: str, namespace: str, args: list, timeout: int = 30) -> tuple {
    cmd = [
        "kubectl", "exec", pod_name, "-c", "sandbox", "-n", namespace, "--",
        "agent-browser"
    ] + args;
    try {
        result = _subprocess.run(
            cmd,
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
    } except _subprocess.TimeoutExpired {
        return (False, "", f"Command timed out after {timeout}s");
    } except Exception as e {
        return (False, "", str(e));
    }
}


"""Build a callable that resolves the sandbox pod name on each call (avoids stale refs)."""
def _make_sandbox_browser_exec(sandbox_id: str, namespace: str, sandbox_obj: Any) -> object {
    return _partial(_sandbox_browser_exec_dynamic, sandbox_id, namespace, sandbox_obj);
}


"""Resolve pod name dynamically then run agent-browser."""
def _sandbox_browser_exec_dynamic(sandbox_id: str, namespace: str, sandbox_obj: Any, args: list, timeout: int = 30) -> tuple {
    # Resolve current pod name (warm-start pods get recycled)
    pod_name = sandbox_id;
    rec = sandbox_obj._registry.get(sandbox_id);
    if rec {
        pod_name = str(dict(rec).get("pod_name", sandbox_id));
    }
    return _sandbox_browser_exec(pod_name, namespace, args, timeout);
}


# ===========================================================================
# Agent Execution (non-blocking)
# ===========================================================================
"""Run agent in background thread via jac-coder public API."""
def _run_agent(
    session_id: str,
    message: str,
    key: str,
    preview_dir: str,
    event_queue: EventBus,
    repo_path: str = "",
    agent_context: str = "",
    sandbox_write_fn: Any = None,
    project_node: Any = None,
    exec_root: Any = None,
    preview_url: str = "",
    images: list = [],
    browser_exec_fn: Any = None
) -> dict | None {
    print(f"[jaccoder_adapter] Agent START key={key}");

    # Register thread ID so stop_jaccoder can interrupt it
    _agent_threads[key] = threading.current_thread().ident;

    # Capture generation counter — if stop_jaccoder increments this,
    # we know we've been superseded and should not push events
    my_gen = _agent_gen.get(key, 0);

    # NOTE: Do NOT call JacRuntime.create_j_context() here.
    # Since jaclang fe79f751e (2026-03-05), SqliteMemory.put() does immediate
    # write-through (INSERT OR REPLACE + commit). Creating a separate execution
    # context gives the background thread its own SqliteMemory connection, and
    # every Jac.save() immediately overwrites the user root in the database —
    # destroying the UserProfile edge. jac-coder finds sessions via the
    # in-memory _session_registry, so a graph context is not needed here.

    set_sandbox_root(preview_dir);

    # Set preview URL thread-local so visual tools pick it up in this
    # worker thread instead of relying on process-global os.environ.
    # When browser exec is routed to sandbox, use localhost (agent-browser
    # runs inside the same pod as the preview server, avoiding hairpin routing).
    if browser_exec_fn and preview_url {
        set_preview_url("http://localhost:8000");
    } elif preview_url {
        set_preview_url(preview_url);
    }

    # Route agent-browser commands to sandbox pod (Chrome runs there)
    if browser_exec_fn {
        set_browser_exec(browser_exec_fn);
    }

    evt_handler = _make_event_handler(
        preview_dir, event_queue, repo_path, sandbox_write_fn
    );

    try {
        result = chat(
            session_id=session_id,
            message=message,
            directory=preview_dir,
            on_event=evt_handler,
            agent_context=agent_context,
            images=images
        );

        # Only push events if we haven't been superseded by stop_jaccoder
        if _agent_gen.get(key, 0) == my_gen {
            event_queue.publish(
                {
                    "type": "agent_done",
                    "response": result.get("response", ""),
                    "agent": result.get("agent", ""),
                    "tools_used": result.get("tools_used", []),
                    "files_modified": result.get("files_modified", []),
                    "has_errors": result.get("has_errors", False),
                    "next_steps": result.get("next_steps", []),
                    "timestamp": time.time()
                }
            );
            print(f"[jaccoder_adapter] Agent done ({result.get('agent', 'unknown')})");
        } else {
            print(f"[jaccoder_adapter] Agent finished after interrupt — suppressed events key={key}");
        }
        return result;
    } except Exception as e {
        if _agent_gen.get(key, 0) != my_gen {
            # Interrupted — suppress error event
            print(f"[jaccoder_adapter] Agent error after interrupt (suppressed) key={key}");
        } else {
            print(f"[jaccoder_adapter] Error: {e}");
            import traceback;
            traceback.print_exc();
            event_queue.publish(
                {"type": "agent_error", "error": str(e), "timestamp": time.time()}
            );
        }
    } finally {
        # Clean up our abort flag (prevents stale entries in _abort_flags)
        clear_abort();

        # Only clean up shared state if we're still the active agent.
        # If stop_jaccoder ran, it incremented _agent_gen and a new thread
        # may already be running. Don't clobber the new thread's state.
        if _agent_gen.get(key, 0) == my_gen {
            _ai_processing[key] = False;
            _agent_threads.pop(key, None);
            if project_node is not None {
                try {
                    project_node.ai_processing = False;
                } except Exception { }
            }
        }
    }
    return None;
}


"""Start JacCoder agent processing in background (non-blocking).
Returns immediately. Frontend polls drain_events() for updates."""
def start_jaccoder_async(
    session_id: str,
    message: str,
    user_id: str,
    project_id: str,
    preview_dir: str,
    repo_path: str = "",
    exec_root: Any = None,
    project_node: Any = None,
    agent_context: str = "",
    preview_url: str = "",
    images: list = []
) -> dict {
    key = f"{user_id}::{project_id}";

    with _processing_lock {
        if _ai_processing.get(key, False) {
            return {
                "success": False,
                "error": "AI is already processing for this project"
            };
        }
        if project_node is not None and project_node.ai_processing {
            return {
                "success": False,
                "error": "AI is already processing for this project"
            };
        }
        _event_queues[key] = EventBus();
        _ai_processing[key] = True;
    }
    if project_node is not None {
        try {
            project_node.ai_processing = True;
        } except Exception { }
    }

    # Wire up K8s sandbox: file sync (HMR) + preview log tailing (runtime error detection)
    # + browser exec routing (agent-browser runs inside sandbox pod)
    sandbox_write_fn = None;
    browser_exec_fn = None;
    try {
        import from services.preview_manager { _sandbox_id_map, _get_sandbox, _is_k8s_sandbox }
        sid = _sandbox_id_map.get(key);
        if sid {
            sandbox = _get_sandbox();
            if sandbox {
                sandbox_write_fn = lambda rel_path: str , content: str  -> None { sandbox.write_file(
                    sid, rel_path, content
                );};
                # Route agent-browser to sandbox pod (Chrome + agent-browser preinstalled)
                # Pod name resolved dynamically at call time to avoid stale refs
                if _is_k8s_sandbox {
                    sandbox_ns = os.environ.get("SANDBOX_NAMESPACE", "jac-sandboxes");
                    browser_exec_fn = _make_sandbox_browser_exec(sid, sandbox_ns, sandbox);
                    print(f"[jaccoder_adapter] Browser exec routed via sandbox sid={sid} ns={sandbox_ns}");
                }
                # Only tail logs in K8s mode. In local mode, LocalSandbox.logs() reads
                # from the same .jac-preview.log file we would write to, creating a
                # feedback loop. Local mode gets its log file from subprocess stdout directly.
                if _is_k8s_sandbox and key not in _tail_threads {
                    log_file = os.path.join(preview_dir, ".jac-preview.log");
                    stop_event = threading.Event();
                    t = threading.Thread(
                        target=_tail_sandbox_log,
                        args=(sandbox, sid, log_file, stop_event),
                        daemon=True
                    );
                    t.start();
                    _tail_threads[key] = (t, stop_event);
                    print(f"[jaccoder_adapter] Preview log tail started for sid={sid}");
                }
            }
        }
    } except Exception as e {
        print(f"[jaccoder_adapter] Sandbox sync setup skipped: {e}");
    }

    _pool.submit(
        _run_agent,
        session_id,
        message,
        key,
        preview_dir,
        _event_queues[
            key
        ],
        repo_path,
        agent_context,
        sandbox_write_fn,
        project_node,
        exec_root,
        preview_url,
        images,
        browser_exec_fn
    );

    return {"success": True, "status": "processing"};
}


"""Stop the currently running JacCoder agent.

1. Signals the worker thread to stop (abort flag → stream breaks quickly)
2. Pushes agent_done so UI stops immediately
3. Session is KEPT — old thread persists abort note to chat_history,
   so the next message has context about what was interrupted."""
def stop_jaccoder(user_id: str, project_id: str) -> dict {
    # Find the matching key — user_id may be empty from stop action,
    # so match any key ending with ::{project_id}
    key = "";
    if user_id {
        key = f"{user_id}::{project_id}";
    } else {
        for k in list(_ai_processing.keys()) {
            if k.endswith(f"::{project_id}") and _ai_processing.get(k, False) {
                key = k;
                break;
            }
        }
    }

    if not key or not _ai_processing.get(key, False) {
        return {"success": False, "error": "No agent running for this project"};
    }

    # 1. Signal the worker thread to stop via abort flag
    tid = _agent_threads.get(key);
    if tid {
        request_abort_thread(tid);
    }

    # 2. Persist abort note to chat_history SYNCHRONOUSLY — before allowing
    #    new messages, so the next turn's LLM has context about what was interrupted.
    #    This eliminates the race condition with the old thread.
    sid = _session_map.get(key, "");
    if sid {
        abort_session(sid);
    }

    # 3. Increment generation so old thread suppresses its events + persistence
    _agent_gen[key] = _agent_gen.get(key, 0) + 1;

    # 4. NOW allow new messages (abort note is already in chat_history)
    _ai_processing[key] = False;
    _agent_threads.pop(key, None);

    # 4. Push agent_done so frontend stops loading spinner
    q = _event_queues.get(key);
    if q {
        q.publish({
            "type": "agent_done",
            "response": "Interrupted by user.",
            "agent": "main",
            "tools_used": [],
            "files_modified": [],
            "has_errors": False,
            "next_steps": [],
            "timestamp": time.time()
        });
    }

    print(f"[jaccoder_adapter] Agent interrupted key={key}");
    return {"success": True, "status": "interrupted"};
}
