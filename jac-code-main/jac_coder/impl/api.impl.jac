# ---------------------------------------------------------------------------
# init
# ---------------------------------------------------------------------------
impl initialize(mode: str = "web") -> None {
    if mode == "web" {
        # JacBuilder / web platform — auto-allow everything, no prompts
        os.environ["JACCODER_WEB_MODE"] = "1";
        permission_engine.init_defaults();
        permission_engine.enable_web_mode();
    } elif mode == "ide" {
        # VS Code extension — ask for write/edit/bash via UI permission prompts
        os.environ["JACCODER_IDE_MODE"] = "1";
        permission_engine.init_defaults();
        # NOTE: enable_web_mode() intentionally NOT called here so that
        # write_file, edit_file and bash_exec remain as "ask" in the engine.
    } else {
        # CLI mode — ask via interactive terminal prompts
        permission_engine.init_defaults();
    }
    # Register jac-mcp using the `jac` binary from the same venv (installed as a dep).
    import sys as _sys;
    try {
        jac_bin = os.path.join(os.path.dirname(_sys.executable), "jac");
        if os.name == "nt" { jac_bin = f"{jac_bin}.exe"; }
        if os.path.exists(jac_bin) {
            mcp_register_builtin("jac-mcp", {"type": "stdio", "command": [jac_bin, "mcp"]});
        }
    } except Exception as e {
        _sys.stderr.write(f"[mcp] jac-mcp not available: {e}\n");
    }
}


# ---------------------------------------------------------------------------
# Session lifecycle
# ---------------------------------------------------------------------------
impl create_session(directory: str, title: str = "", agent: str = "main") -> dict {
    session_title = title if title else f"Session-{datetime.now().strftime('%H%M%S')}";
    try {
        before_ids = set([s.id for s in [root()-->][?:Session]]);
    } except Exception {
        before_ids = set();
    }

    root() spawn new_session(title=session_title, directory=directory);

    session_id = "";
    session_obj = None;
    for s in [root()-->][?:Session] {
        if s.id not in before_ids {
            session_id = s.id;
            session_obj = s;
            break;
        }
    }
    if not session_id {
        return {"error": "Failed to create session"};
    }

    # Store in registry so background threads can find it
    _session_registry[session_id] = session_obj;

    return {"session_id": session_id, "title": session_title, "status": "created"};
}


impl list_sessions() -> list {
    result: list = [];
    try {
        sessions = [root()-->][?:Session][?status=="active"];
    } except Exception {
        return [];
    }
    for s in sessions {
        try {
            user_msgs = len([m for m in s.chat_history if m.get("role") == "user"]);
            result.append(
                {
                    "id": s.id,
                    "title": s.title,
                    "message_count": user_msgs,
                    "updated_at": s.updated_at
                }
            );
        } except Exception {
            continue;
        }
    }
    result.sort(key=lambda x : x["updated_at"], reverse=True);
    return result;
}


impl get_session(session_id: str) -> dict {
    matches = [root()-->][?:Session][?id==session_id];
    if not matches {
        return {"error": "Session not found"};
    }
    s = matches[0];
    return {
        "id": s.id,
        "title": s.title,
        "status": s.status,
        "directory": s.directory,
        "chat_history": s.chat_history,
        "created_at": s.created_at,
        "updated_at": s.updated_at
    };
}


impl close_session(session_id: str) -> dict {
    matches = [root()-->][?:Session][?id==session_id];
    if not matches {
        return {"error": "Session not found"};
    }
    matches[0].status = "closed";
    matches[0].updated_at = datetime.now().isoformat();
    _session_registry.pop(session_id, None);
    return {"status": "closed", "id": matches[0].id};
}


# ---------------------------------------------------------------------------
# chat — the main entry point
# ---------------------------------------------------------------------------
impl chat(
    session_id: str,
    message: str,
    directory: str = "",
    on_event: Any = None,
    mode: str = "full",
    agent_context: str = "",
    images: list = [],
    edit_mode: str = "auto"
) -> dict {
    # Find session — try registry first (works across threads), then graph
    session = _session_registry.get(session_id);
    if not session {
        matches = [root()-->][?:Session][?id==session_id];
        if matches {
            session = matches[0];
            _session_registry[session_id] = session;
        }
    }
    if not session {
        return {"error": "Session not found", "agent": "error"};
    }

    # Override directory if provided
    if directory {
        session.directory = directory;
    }
    work_dir = session.directory;

    # Bind session_id + edit_mode to this thread so guarded tools know
    # whether to auto-allow, prompt, or deny write/edit/bash operations.
    _set_chat_session(session_id, edit_mode);

    # Setup
    clear_abort();
    reset_steps();
    start_turn();
    if work_dir {
        set_sandbox_root(work_dir);
    }
    if on_event {
        register_event_callback(on_event);
    }

    try {
        # Memory initialization
        _ensure_memory(session, work_dir);

        # Add user message
        user_msg_record: dict = {"role": "user", "content": message};
        if images and len(images) > 0 {
            user_msg_record["has_images"] = True;
            user_msg_record["image_count"] = len(images);
        }
        session.chat_history.append(user_msg_record);
        session.updated_at = datetime.now().isoformat();

        # Get MainAgent — always resolve fresh (cached refs go stale in jac start)
        main_agent = ensure_main_agent();

        # Initialize shared budget for SubAgents
        config = get_config();
        _init_spawn_budget(config.max_react_iterations * 3);

        # Build context
        ctx_history = build_context(
            session.chat_history,
            session.active_files,
            session.pending_errors,
            project_summary=session.project_summary or ""
        );

        # Inject agent_context if provided (e.g. from JacBuilder)
        if agent_context {
            ctx_history.insert(0, {"role": "system", "content": agent_context});
        }

        # Inject available MCP tools into context (cached to avoid rebuilding every turn)
        mcp_msg = _get_mcp_context_msg();
        if mcp_msg {
            ctx_history.insert(0, mcp_msg);
        }

        # Early exit if already aborted before LLM starts
        if is_abort_requested() {
            tool_end();
            summary = emit_turn_summary();
            return {
                "response": "[Interrupted]",
                "agent": "main",
                "tools_used": [],
                "files_modified": [],
                "has_errors": False,
                "next_steps": [],
                "turn_summary": summary
            };
        }

        # Plan mode — inject instruction to write a plan only, no file writes.
        # The UI will show "Execute Plan" when done; execution reruns with edit_mode="auto".
        if edit_mode == "plan" {
            plan_msg: dict = {
                "role": "system",
                "content": (
                    "You are in PLAN MODE. Your task is to produce a detailed, step-by-step plan "
                    "for the user's request. Do NOT write, edit, or run any files. "
                    "Describe every file you would create or modify, what changes you would make, "
                    "and why. The user will review your plan and click 'Execute Plan' to apply it."
                )
            };
            ctx_with_plan: list[dict] = [plan_msg];
            ctx_with_plan.extend(ctx_history);
            ctx_history = ctx_with_plan;
        }

        # Call MainAgent — returns StreamEvent generator with logging enabled
        # If user attached images, convert to byllm Image object and pass as user_image
        user_image = None;
        if images and len(images) > 0 {
            try {
                import from byllm.lib { Image }
                ;
                first_img = images[0];
                data_url = first_img.get("data_url", "") if isinstance(first_img, dict) else str(first_img);
                if data_url {
                    user_image = Image(data_url);
                }
            } except Exception as img_err {
                sys.stderr.write(f"[api] Failed to create Image from user attachment: {img_err}\n");
            }
        }
        event_stream = main_agent.respond(message=message, chat_history=ctx_history, user_image=user_image);
        stream_result = _consume_llm_stream(event_stream);

        response_text = stream_result["content"];
        tools_used = stream_result["tools_used"];

        # Finalize turn — get accumulated file/error data from tool internals
        tool_end();
        summary = emit_turn_summary();

        files_modified = summary.get("files_modified", []);
        has_errors = summary.get("errors", 0) > 0;

        # Update session state
        if files_modified {
            for f in files_modified {
                if f not in session.active_files {
                    session.active_files.append(f);
                }
            }
            if len(session.active_files) > 10 {
                session.active_files = session.active_files[-10:];
            }
        }
        if has_errors {
            files_str = ", ".join(files_modified) if files_modified else "unknown";
            session.pending_errors = [f"Errors in previous turn (files: {files_str})"];
        } else {
            session.pending_errors = [];
        }
        if files_modified and session.directory {
            memory = find_or_create_memory(session.directory);
            if memory {
                update_memory_from_session(
                    memory, files_modified, response_text[:500]
                );
                session.project_summary = memory.summarize();
            }
        }

        # Persist response — skip if aborted (abort note already in chat_history)
        if not is_abort_requested() {
            record: dict = {"role": "assistant", "content": response_text, "agent": "main"};
            if tools_used {
                record["tools_used"] = tools_used;
            }
            if files_modified {
                record["files_modified"] = files_modified;
            }
            session.chat_history.append(record);
        }
        session.last_agent = "main";
        session.updated_at = datetime.now().isoformat();

        return {
            "response": response_text,
            "agent": "main",
            "tools_used": tools_used,
            "files_modified": files_modified,
            "has_errors": has_errors,
            "next_steps": [],
            "turn_summary": summary
        };
    } except Exception as e {
        sys.stderr.write(f"[api] chat error: {e}\n");
        return {"error": str(e), "agent": "error"};
    } finally {
        if on_event {
            clear_event_callbacks();
        }
        # Clean up thread context (session_id + edit_mode)
        _clear_chat_session();
    }
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
def _ensure_memory(session: Session, work_dir: str) -> None {
    if not work_dir or session.project_summary {
        return;
    }
    memory = find_or_create_memory(work_dir);
    if not memory {
        return;
    }
    has_project = (
        os.path.exists(os.path.join(work_dir, "jac.toml"))
        or os.path.exists(os.path.join(work_dir, "main.jac"))
    );
    if not memory.architecture and not memory.scan_attempted and has_project {
        _init_memory(memory, work_dir);
    }
    summary = memory.summarize();
    if summary {
        session.project_summary = summary;
    }
}


def _post_process(session: Session, response_obj: Any) -> None {
    # Track files
    if response_obj.files_modified {
        for f in response_obj.files_modified {
            if f not in session.active_files {
                session.active_files.append(f);
            }
        }
        if len(session.active_files) > 10 {
            session.active_files = session.active_files[-10:];
        }
    }

    # Track errors
    if response_obj.has_errors {
        files_str = ", ".join(response_obj.files_modified)
            if response_obj.files_modified
            else "unknown";
        session.pending_errors = [f"Errors in previous turn (files: {files_str})"];
    } else {
        session.pending_errors = [];
    }

    # Update memory
    if response_obj.files_modified and session.directory {
        memory = find_or_create_memory(session.directory);
        if memory {
            update_memory_from_session(
                memory, response_obj.files_modified, response_obj.content[:500]
            );
            session.project_summary = memory.summarize();
        }
    }

    # Persist response
    record: dict = {
        "role": "assistant",
        "content": response_obj.content,
        "agent": "main"
    };
    if response_obj.tools_used {
        record["tools_used"] = response_obj.tools_used;
    }
    if response_obj.files_modified {
        record["files_modified"] = response_obj.files_modified;
    }
    session.chat_history.append(record);
    session.last_agent = "main";
    session.updated_at = datetime.now().isoformat();
}


# ---------------------------------------------------------------------------
# Model management API
# ---------------------------------------------------------------------------
impl api_set_model(model: str) -> dict {
    return _set_model(model);
}

impl api_get_model() -> dict {
    return _get_model();
}


# ---------------------------------------------------------------------------
# MCP management API
# ---------------------------------------------------------------------------
impl api_mcp_add(name: str, config: dict) -> dict {
    raw = mcp_add_server(name, config);
    result: dict = {**raw};
    return result;
}

impl api_mcp_disconnect(name: str) -> dict {
    raw = mcp_disconnect_server(name);
    result: dict = {**raw};
    return result;
}

impl api_mcp_reconnect(name: str) -> dict {
    raw = mcp_reconnect_server(name);
    result: dict = {**raw};
    return result;
}

impl api_mcp_delete(name: str) -> dict {
    raw = mcp_delete_server(name);
    result: dict = {**raw};
    return result;
}

impl api_mcp_list() -> list {
    raw = mcp_list_servers();
    result: list = [*raw];
    return result;
}


impl abort_session(session_id: str) -> None {
    session = _session_registry.get(session_id);
    if session {
        session.chat_history.append({
            "role": "assistant",
            "content": "[INTERRUPTED — task was NOT completed. When the user sends the next message, you MUST use tools to complete the task. Do NOT just describe what you would do — actually DO it by calling read_file, write_code, etc.]"
        });
    }
}


glob _mcp_ctx_cache: dict = {};  # {"msg": dict, "tool_names": set}

"""Build MCP tools context message, cached by tool names."""
def _get_mcp_context_msg() -> dict | None {
    try {
        mcp_tools = mcp_get_tools();
    } except Exception {
        return None;
    }
    if not mcp_tools {
        return None;
    }
    # Check if tools changed since last call
    current_names = frozenset(f"{t['server']}::{t['name']}" for t in mcp_tools);
    if _mcp_ctx_cache.get("tool_names") == current_names {
        return _mcp_ctx_cache.get("msg");
    }
    # Rebuild
    lines: list = [
        "Available MCP tools — call via mcp_call(server_name, tool_name, arguments_json):",
        "Check each tool's inputSchema for required arguments before calling."
    ];
    for t in mcp_tools {
        schema_hint = "";
        input_schema = t.get("inputSchema", {});
        if input_schema {
            required = input_schema.get("required", []);
            if required {
                schema_hint = f"  required: {', '.join(required)}";
            }
        }
        lines.append(f"  - server={t['server']}  tool={t['name']}  {t['description']}{schema_hint}");
    }
    msg: dict = {"role": "system", "content": "\n".join(lines)};
    _mcp_ctx_cache["msg"] = msg;
    _mcp_ctx_cache["tool_names"] = current_names;
    return msg;
}


def _init_spawn_budget(total: int) -> None {
    try {
        import from jac_coder.tool.delegation { init_budget }
        ;
        init_budget(total);
    } except Exception { }
}
