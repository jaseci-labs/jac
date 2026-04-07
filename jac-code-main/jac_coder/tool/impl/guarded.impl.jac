impl _check_permission(tool_id: str, resource: str, content: str = "") -> str {
    action = permission_engine.check(tool_id, resource);

    if action == "deny" {
        return f"Permission denied: {tool_id} on {resource} is not allowed in this agent mode.";
    }

    if action == "ask" {
        decision = _ask_user(tool_id, resource, content);
        if decision == "deny" {
            return f"Permission denied by user: {tool_id} on {resource}";
        }
        if decision == "always" {
            permission_engine.remember_allow(tool_id, "*");
        }
    }

    return "allow";
}


impl _set_chat_session(session_id: str, edit_mode: str = "auto") -> None {
    tid = threading.current_thread().ident;
    _chat_contexts[tid] = session_id;
    _edit_mode_contexts[tid] = edit_mode;
}


impl _get_chat_session() -> str {
    tid = threading.current_thread().ident;
    return _chat_contexts.get(tid, "");
}


impl _get_edit_mode() -> str {
    tid = threading.current_thread().ident;
    return _edit_mode_contexts.get(tid, "auto");
}


impl _clear_chat_session() -> None {
    tid = threading.current_thread().ident;
    _chat_contexts.pop(tid, None);
    _edit_mode_contexts.pop(tid, None);
}


impl _ask_user(tool_id: str, resource: str, content: str = "") -> str {
    if os.environ.get("JACCODER_IDE_MODE", "") {
        edit_mode = _get_edit_mode();
        if edit_mode == "auto" { return "allow"; }
        if edit_mode == "plan" { return "deny"; }
        # edit_mode == "ask" → show UI permission prompt
        return _ask_ide(tool_id, resource, content);
    }
    if os.environ.get("JACCODER_WEB_MODE", "") {
        # JacBuilder / web platform — auto-allow, no prompts
        return "allow";
    }
    # CLI mode — interactive terminal prompt (existing behaviour)
    display = resource[:80] + "..." if len(resource) > 80 else resource;
    print(f"\n{YELLOW}[Permission]{RESET} {tool_id}: {display}");
    print(f"  {DIM}(y)es / (n)o / (a)lways allow {tool_id}{RESET}");
    try {
        answer = input("  Allow? ").strip().lower();
    } except (EOFError, KeyboardInterrupt) {
        return "deny";
    }
    if answer in ["a", "always"] {
        return "always";
    }
    if answer in ["y", "yes", ""] {
        return "allow";
    }
    return "deny";
}


impl _ask_ide(tool_id: str, resource: str, content: str = "") -> str {
    session_id = _get_chat_session();
    if not session_id {
        return "deny";
    }

    # Build a human-readable preview for the UI
    display = resource[:120] + "..." if len(resource) > 120 else resource;

    # Only send content for file ops — cap at 512 KB to keep the JSON pipe fast.
    # Bash commands pass resource=command so content stays empty for those.
    content_payload: str = "";
    if tool_id in ("write_file", "edit_file") and content {
        content_payload = content if len(content) <= 524288 else "";
    }

    # Emit the permission request — VS Code UI shows diff + Allow/Always/Deny buttons
    emit_event("permission_request", {
        "tool": tool_id,
        "resource": display,
        "content": content_payload
    });

    # Block this tool thread until the UI responds
    gate = threading.Event();
    _permission_events[session_id] = gate;
    gate.wait();
    _permission_events.pop(session_id, None);

    return _permission_decisions.pop(session_id, "deny");
}


impl write_file_guarded(file_path: str, content: str) -> str {
    # Pass full proposed content so the client can show a before/after diff.
    verdict = _check_permission("write_file", file_path, content);
    if verdict != "allow" {
        return verdict;
    }
    # Capture original before overwriting so the IDE can show red/green diff.
    original: str = "";
    try {
        with open(file_path, "r", encoding="utf-8") as _f {
            original = _f.read();
        }
    } except Exception { original = ""; }
    if original and os.environ.get("JACCODER_IDE_MODE", "") {
        emit_event("file_snapshot", {"file_path": file_path, "original": original});
    }
    return write_file(file_path, content);
}


impl edit_file_guarded(
    file_path: str, old_string: str, new_string: str, replace_all: bool = False
) -> str {
    # Pre-compute the proposed result so the IDE client can show a proper diff.
    # Only needed in IDE mode — skip the extra file read in web/CLI mode.
    proposed: str = "";
    if os.environ.get("JACCODER_IDE_MODE", "") {
        try {
            with open(file_path, "r", encoding="utf-8") as _f {
                _current = _f.read();
            }
            if replace_all {
                proposed = _current.replace(old_string, new_string);
            } else {
                proposed = _current.replace(old_string, new_string, 1);
            }
        } except Exception { proposed = ""; }
    }

    verdict = _check_permission("edit_file", file_path, proposed);
    if verdict != "allow" {
        return verdict;
    }
    return edit_file(file_path, old_string, new_string, replace_all);
}


impl run_command(
    command: str, workdir: str = ".", timeout: int = 120, background: bool = False
) -> str {
    loop_msg = check_tool_loop("run_command", command[:80]);
    if loop_msg { return loop_msg; }
    verdict = _check_permission("bash_exec", command);
    if verdict != "allow" {
        return verdict;
    }
    return bash_exec(command, workdir, timeout, background);
}
