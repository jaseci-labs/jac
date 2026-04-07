impl ensure_main_agent() -> MainAgent {
    agents = [root()-->][?:MainAgent];
    if agents {
        return agents[0];
    }
    agent = MainAgent();
    root() ++> agent;
    return agent;
}


impl new_session.create with Root entry {
    session = Session(title=self.title, directory=self.directory);
    here ++> session;
    agent = ensure_main_agent();
    session ++> agent;
    report {"session_id": session.id, "title": session.title, "status": "created"};
}


impl list_sessions.list with Root entry {
    active = [-->][?:Session][?status=="active"];
    result = [];
    for s in active {
        user_msgs = len(
            [
                m
                for m in s.chat_history
                if m["role"] == "user"
            ]
        );
        result.append(
            {
                "id": s.id,
                "title": s.title,
                "message_count": user_msgs,
                "updated_at": s.updated_at
            }
        );
    }
    result.sort(key=lambda x : x["updated_at"], reverse=True);
    report {"sessions": result};
}


impl get_session.fetch with Root entry {
    matches = [-->][?:Session][?id==self.session_id];
    if matches {
        session = matches[0];
        report {
            "id": session.id,
            "title": session.title,
            "status": session.status,
            "directory": session.directory,
            "chat_history": session.chat_history,
            "created_at": session.created_at,
            "updated_at": session.updated_at
        };
    } else {
        report {"error": "Session not found"};
    }
}


impl close_session.close with Root entry {
    matches = [-->][?:Session][?id==self.session_id];
    if matches {
        matches[0].status = "closed";
        matches[0].updated_at = datetime.now().isoformat();
        report {"status": "closed", "id": matches[0].id};
    } else {
        report {"error": "Session not found"};
    }
}


# ---------------------------------------------------------------------------
# Step 1: init_session @ Root — find or create session, visit it
# ---------------------------------------------------------------------------
impl interact.init_session with Root entry {
    agent = ensure_main_agent();
    matches = [-->][?:Session][?id==self.session_id];
    if matches {
        session = matches[0];
        if not [session-->[?:MainAgent]] {
            session ++> agent;
        }
        visit session;
    } else {
        now = datetime.now().isoformat();
        session_node = here ++> Session(
            id=self.session_id, chat_history=[], created_at=now, updated_at=now
        );
        session_node ++> agent;
        visit session_node;
    }
}


# ---------------------------------------------------------------------------
# Step 2: enter_session @ Session — load memory, append message, visit agent
# ---------------------------------------------------------------------------
impl interact.enter_session with Session entry {
    tool_end();
    reset_steps();
    start_turn();
    clear_abort();

    # Sandbox only enforced in web/API mode (JacBuilder sets it via api.chat).
    # CLI mode leaves sandbox open so the agent can access any path.

    # Only load project memory for existing sessions — new sessions start fresh.
    is_continuation = len(here.chat_history) > 0;
    if here.directory and not here.project_summary and is_continuation {
        import os as _os;
        memory = find_or_create_memory(here.directory);
        if memory {
            has_project = (
                _os.path.exists(_os.path.join(here.directory, "jac.toml"))
                or _os.path.exists(_os.path.join(here.directory, "main.jac"))
            );
            if not memory.architecture and not memory.scan_attempted and has_project {
                _init_memory(memory, here.directory);
            }
            summary = memory.summarize();
            if summary {
                here.project_summary = summary;
            }
        }
    }

    # Append user message and update
    here.chat_history.append({"role": "user", "content": self.message});
    here.updated_at = datetime.now().isoformat();
    self.chat_history = here.chat_history;

    # Visit MainAgent
    visit [-->][?:MainAgent] else {
        agent = ensure_main_agent();
        here ++> agent;
        visit agent;
    }
}


# ---------------------------------------------------------------------------
# Step 3: respond @ MainAgent — the agent handles everything
# ---------------------------------------------------------------------------
impl interact.respond with MainAgent entry {
    _respond_and_persist(here, self);
}


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------
impl _find_session(session_id: str) -> Session | None {
    matches = [root()-->][?:Session][?id==session_id];
    return matches[0] if matches else None;
}


impl _persist_response(
    session_id: str,
    response: str,
    agent_mode: str,
    tools_used: list[str] = [],
    files_modified: list[str] = []
) -> None {
    session = _find_session(session_id);
    if session {
        record: dict = {"role": "assistant", "content": response, "agent": agent_mode};
        if tools_used {
            record["tools_used"] = tools_used;
        }
        if files_modified {
            record["files_modified"] = files_modified;
        }
        session.chat_history.append(record);
        session.last_agent = agent_mode;
        session.updated_at = datetime.now().isoformat();
    }
}


impl _consume_llm_stream(event_stream: Any) -> dict {
    response_text = "";
    tools_used: list = [];

    for event in event_stream {
        if event.event_type == "thought" {
            emit_event("llm_thought", dict(event.data));
        } elif event.event_type == "tool_call" {
            tool_name = event.data.get("tool", "");
            if tool_name and tool_name != "finish_tool" {
                tools_used.append(tool_name);
            }
            emit_event("llm_tool_call", dict(event.data));
        } elif event.event_type == "tool_result" {
            emit_event("llm_tool_result", dict(event.data));
        } elif event.event_type == "steps_done" {
            emit_event("llm_steps_done", dict(event.data));
        } elif event.event_type == "chunk" {
            chunk_content = event.data.get("content", "");
            response_text += chunk_content;
            if chunk_content {
                emit_event("llm_chunk", {"content": chunk_content});
            }
        } elif event.event_type == "usage" {
            emit_event("llm_usage", dict(event.data));
        }
    }

    return {
        "content": response_text,
        "tools_used": tools_used
    };
}


impl _respond_and_persist(agent: MainAgent, ctx: interact) -> None {
    # Early exit if aborted — abort note already persisted by stop_jaccoder
    if is_abort_requested() {
        report {
            "response": "[Interrupted]",
            "agent": "main",
            "tools_used": [],
            "files_modified": [],
            "has_errors": False,
            "next_steps": []
        };
        return;
    }

    session = _find_session(ctx.session_id);
    active_files = session.active_files if session else [];
    pending_errors = session.pending_errors if session else [];
    project_summary = session.project_summary if session else "";

    # Build compacted context
    ctx_history = build_context(
        ctx.chat_history, active_files, pending_errors, project_summary=project_summary
    );

    # If agent_context was provided (e.g. from JacBuilder), inject it
    if ctx.agent_context {
        ctx_history.insert(0, {"role": "system", "content": ctx.agent_context});
    }

    # Initialize shared budget for SubAgents
    import from jac_coder.tool.delegation { init_budget }
    config = get_config();
    init_budget(config.max_react_iterations * 3);

    # Call MainAgent — returns StreamEvent generator with logging enabled
    event_stream = agent.respond(message=ctx.message, chat_history=ctx_history);
    stream_result = _consume_llm_stream(event_stream);

    response_text = stream_result["content"];
    tools_used = stream_result["tools_used"];

    # Finalize turn — get accumulated file/error data from tool internals
    tool_end();
    summary = emit_turn_summary();

    files_modified = summary.get("files_modified", []);
    has_errors = summary.get("errors", 0) > 0;

    # Post-process: update session state
    if session {
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
            files_str = ", ".join(files_modified)
                if files_modified
                else "unknown";
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
    }

    # If aborted, skip persistence — abort note already persisted by stop_jaccoder
    if not is_abort_requested() {
        _persist_response(
            ctx.session_id,
            response_text,
            "main",
            tools_used,
            files_modified
        );
    }

    report {
        "response": response_text,
        "agent": "main",
        "tools_used": tools_used,
        "files_modified": files_modified,
        "has_errors": has_errors,
        "next_steps": [],
        "turn_summary": summary
    };
}
