"""Implementation of JacCoder CLI."""

impl print_banner{
    info = get_model();
    print(f"{CYAN}{BOLD}");
    print("    ╔══════════════════════════════════════╗");
    print("    ║         JacCoder CLI v0.2.0          ║");
    print("    ║   AI Coding Agent powered by Jac     ║");
    print("    ╚══════════════════════════════════════╝");
    print(f"{RESET}");
    print(f"  {DIM}Model: {info['model']}  |  /help{RESET}");
    print("");
}


impl print_help{
    print(f"\n{BOLD}Available commands:{RESET}");
    print(f"  {YELLOW}/help{RESET}              Show this help message");
    print(f"  {YELLOW}/quit{RESET}, {YELLOW}/exit{RESET}       Exit the CLI");
    print(f"  {YELLOW}/new{RESET}               Start a new session");
    print(f"  {YELLOW}/sessions{RESET}          List all active sessions");
    print(f"  {YELLOW}/switch <id>{RESET}       Switch to a session by ID prefix");
    print(f"  {YELLOW}/clear{RESET}             Clear the terminal screen");
    print(f"  {YELLOW}/agent{RESET}             Show agent info");
    print(f"  {YELLOW}/history{RESET}           Show chat history");
    print(f"  {YELLOW}/model{RESET}             Show current model");
    print(f"  {YELLOW}/model <name>{RESET}      Switch model (e.g. /model gpt-4o)");
    print(f"  {YELLOW}/config{RESET}            Show current configuration");
    print(f"  {YELLOW}/todo{RESET}              Show current task list");
    print("");
}


impl print_error(msg: str) {
    print(f"{RED}Error: {msg}{RESET}");
}


impl print_info(msg: str) {
    print(f"{DIM}{msg}{RESET}");
}


impl print_success(msg: str) {
    print(f"{GREEN}{msg}{RESET}");
}


impl find_session(session_id: str) -> Session | None {
    for s in [root()-->][?:Session] {
        if s.id == session_id {
            return s;
        }
    }
    return None;
}


impl create_new_session(directory: str) -> str {
    root() spawn new_session(title="CLI Session", directory=directory);
    sessions = [root()-->][?:Session];
    sessions.sort(key=lambda s : s.created_at, reverse=True);
    return sessions[0].id;
}


impl find_session_by_prefix(prefix: str) -> Session | None {
    matches = [];
    for s in [root()-->][?:Session] {
        if s.id.startswith(prefix) and s.status == "active" {
            matches.append(s);
        }
    }
    if len(matches) == 1 {
        return matches[0];
    }
    if len(matches) > 1 {
        print_error(f"Ambiguous prefix '{prefix}' — matches {len(matches)} sessions");
    }
    return None;
}


impl cmd_sessions{
    sessions = [root()-->][?:Session];
    active = [
        s
        for s in sessions
        if s.status == "active"
    ];
    if not active {
        print_info("  No active sessions.");
        return;
    }
    print(f"\n{BOLD}Active sessions:{RESET}");
    active.sort(key=lambda s : s.updated_at, reverse=True);
    for s in active {
        user_msgs = len(
            [
                m
                for m in s.chat_history
                if m["role"] == "user"
            ]
        );
        color = AGENT_COLORS.get(s.agent, WHITE);
        print(
            f"  {DIM}{s.id[:8]}...{RESET}  {s.title}  " + f"[{color}{s.agent}{RESET}]  " + f"{DIM}{user_msgs} msgs{RESET}"
        );
    }
    print("");
}


impl cmd_history(session_id: str) {
    session = find_session(session_id);
    if not session or not session.chat_history {
        print_info("  No messages yet.");
        return;
    }
    print(f"\n{BOLD}Chat history:{RESET}");
    for msg in session.chat_history {
        role = msg["role"];
        content = str(msg["content"]);
        if role == "user" {
            print(f"\n  {BOLD}{CYAN}You:{RESET} {content}");
        } else {
            preview = content[:200] + "..." if len(content) > 200 else content;
            print(f"\n  {BOLD}{GREEN}Agent:{RESET} {preview}");
        }
    }
    print("");
}


impl cmd_agent_switch(mode: str, session_id: str) {
    mode = mode.strip().lower();
    print_info(
        "  Agent mode switching is no longer needed. MainAgent handles all tasks autonomously."
    );
    print_info("  It will delegate to focused SubAgents when needed.");
}


impl cmd_config{
    config = get_config();
    print(f"\n{BOLD}Configuration:{RESET}");
    print(f"  {YELLOW}Model{RESET}              {config.default_model}");
    print(f"  {YELLOW}Default Agent{RESET}      {config.default_agent}");
    print(f"  {YELLOW}Temperature{RESET}        {config.temperature}");
    print(f"  {YELLOW}Max Tokens{RESET}         {config.max_tokens}");
    print(f"  {YELLOW}Max ReAct Iters{RESET}    {config.max_react_iterations}");
    print(f"  {YELLOW}Max Turns{RESET}          {config.max_turns}");
    print(f"  {YELLOW}Project Dir{RESET}        {config.project_dir}");
    print("");
}


impl cmd_todo{
    todos = get_todos();
    if not todos {
        print_info("  No tasks.");
        return;
    }
    print(f"\n{BOLD}Tasks:{RESET}");
    for item in todos {
        status = item.get("status", "pending") if isinstance(item, dict) else "pending";
        content = item.get("content", str(item))
            if isinstance(item, dict)
            else str(item);
        if status == "completed" {
            print(f"  {GREEN}[x]{RESET} {DIM}{content}{RESET}");
        } elif status == "in_progress" {
            print(f"  {YELLOW}[>]{RESET} {content}");
        } else {
            print(f"  [ ] {content}");
        }
    }
    print("");
}


impl run_noninteractive(prompt: str) {
    directory = os.getcwd();

    ensure_main_agent();
    permission_engine.init_defaults();

    session_id = create_new_session(directory);
    session = find_session(session_id);
    pre_msg_count = len(session.chat_history) if session else 0;

    try {
        msg: str = str(prompt);
        sid: str = str(session_id);
        root() spawn interact(message=msg, session_id=sid);
    } except Exception as e {
        print_error(f"Agent failed: {str(e)}");
        return;
    }

    session = find_session(session_id);
    if not session {
        print_error("No response received.");
        return;
    }

    new_messages = session.chat_history[pre_msg_count:];
    displayed = False;
    for msg in new_messages {
        if msg["role"] == "assistant" {
            agent_used = msg.get("agent", "main");
            print(f"[{agent_used.upper()}] {msg['content']}\n");
            displayed = True;
        }
    }
    if not displayed {
        print_error("No response received.");
    }
}


impl show_sessions{
    ensure_main_agent();
    sessions = [root()-->][?:Session];
    active = [
        s
        for s in sessions
        if s.status == "active"
    ];
    if not active {
        print("No active sessions.");
        return;
    }
    print(f"{'ID':<10} {'Title':<20} {'Agent':<8} {'Messages':<10} {'Updated'}");
    print("-" * 70);
    active.sort(key=lambda s : s.updated_at, reverse=True);
    for s in active {
        user_msgs = len(
            [
                m
                for m in s.chat_history
                if m["role"] == "user"
            ]
        );
        print(
            f"{s.id[:8]:<10} {s.title[:20]:<20} {s.agent:<8} {user_msgs:<10} {s.updated_at[:19]}"
        );
    }
}


impl start_repl(session_id: str) {
    directory = os.getcwd();
    session = find_session(session_id);
    if not session {
        print_error(f"Session {session_id} not found.");
        return;
    }

    print_banner();

    msg_count = len(
        [
            m
            for m in session.chat_history
            if m["role"] == "user"
        ]
    );
    if msg_count > 0 {
        print_success(f"  Resumed session: {session_id[:8]}...");
        print(f"  {DIM}{msg_count} previous messages | Agent: {session.agent}{RESET}");
        print(f"  {DIM}Working directory: {directory}{RESET}\n");
    } else {
        print_success(f"  Session started: {session_id[:8]}...");
        print(f"  {DIM}Working directory: {directory}{RESET}\n");
    }

    while True {
        agent = session.agent if session else "main";
        color = AGENT_COLORS.get(agent, WHITE);
        prompt_str = f"{BOLD}{color}[{agent}]{RESET} {BOLD}>{RESET} ";

        try {
            user_input = input(prompt_str);
        } except (EOFError, KeyboardInterrupt) {
            print(f"\n{DIM}Goodbye!{RESET}");
            break;
        }

        user_input = user_input.strip();
        if not user_input {
            continue;
        }

        if user_input.startswith("/") {
            parts = user_input.split(" ", 1);
            cmd = str(parts[0]).lower();
            args: str = str(parts[1]) if len(parts) > 1 else "";

            if cmd in ["/quit", "/exit", "/q"] {
                print(f"{DIM}Goodbye!{RESET}");
                break;
            }
            if cmd == "/help" {
                print_help();
                continue;
            }
            if cmd == "/new" {
                session_id = create_new_session(directory);
                session = find_session(session_id);
                print_success(f"  New session: {session_id[:8]}...");
                continue;
            }
            if cmd == "/sessions" {
                cmd_sessions();
                continue;
            }
            if cmd == "/switch" {
                if not args {
                    print_error("Usage: /switch <session-id-prefix>");
                    continue;
                }
                target = find_session_by_prefix(args.strip());
                if target {
                    session_id = target.id;
                    session = target;
                    msg_count = len(
                        [
                            m
                            for m in session.chat_history
                            if m["role"] == "user"
                        ]
                    );
                    print_success(
                        f"  Switched to: {session_id[:8]}... ({msg_count} messages)"
                    );
                }
                continue;
            }
            if cmd == "/clear" {
                os.system("clear");
                continue;
            }
            if cmd == "/agent" {
                if not args {
                    print_info(
                        "  MainAgent handles all tasks autonomously. No mode switching needed."
                    );
                    continue;
                }
                cmd_agent_switch(str(args), session_id);
                session = find_session(session_id);
                continue;
            }
            if cmd == "/history" {
                cmd_history(session_id);
                continue;
            }
            if cmd == "/model" {
                if args {
                    result = set_model(args.strip());
                    if "error" in result {
                        print_error(result["error"]);
                    } else {
                        print_success(f"  Model switched to: {result['model']}");
                    }
                } else {
                    info = get_model();
                    print_info(f"  Model: {info['model']}");
                }
                continue;
            }
            if cmd == "/config" {
                cmd_config();
                continue;
            }
            if cmd == "/todo" {
                cmd_todo();
                continue;
            }
            print_error(f"Unknown command: {cmd}. Type /help for options.");
            continue;
        }

        print(f"{DIM}  Thinking...{RESET}");

        pre_msg_count = len(session.chat_history) if session else 0;

        try {
            msg: str = str(user_input);
            sid: str = str(session_id);
            root() spawn interact(message=msg, session_id=sid);
        } except Exception as e {
            print_error(f"Agent failed: {str(e)}");
            continue;
        }

        session = find_session(session_id);
        if not session {
            print_error("Session lost. Creating new one...");
            session_id = create_new_session(directory);
            session = find_session(session_id);
            continue;
        }

        new_messages = session.chat_history[pre_msg_count:];
        displayed = False;
        for msg in new_messages {
            if msg["role"] == "assistant" {
                agent_used = msg.get("agent", "main");
                badge_color = AGENT_COLORS.get(agent_used, WHITE);
                print(
                    f"\n  {DIM}[{badge_color}{agent_used.upper()}{RESET}{DIM}]{RESET}"
                );
                print(f"{WHITE}{msg['content']}{RESET}\n");
                displayed = True;
            }
        }
        if not displayed {
            print_error("No response received.");
        }
    }
}


impl _cli_event_handler(event_type: str, data: dict) -> None {
    if event_type == "llm_thought" {
        content = data.get("content", "");
        if content {
            prefix = get_agent_prefix();
            prefix_display = f"[{prefix}] " if prefix else "";
            display = content[:200] + "..." if len(content) > 200 else content;
            sys.stderr.write(f"  {MAGENTA}{prefix_display}💭 {display}{RESET}\n");
            sys.stderr.flush();
        }
    } elif event_type == "llm_tool_call" {
        tool_name = data.get("tool", "");
        args = data.get("args", {});
        if tool_name and tool_name != "finish_tool" {
            prefix = get_agent_prefix();
            prefix_display = f"[{prefix}] " if prefix else "";
            args_short = str(args)[:120] + "..." if len(str(args)) > 120 else str(args);
            sys.stderr.write(f"  {DIM}{CYAN}{prefix_display}🔧 {tool_name}({args_short}){RESET}\n");
            sys.stderr.flush();
        }
    } elif event_type == "llm_tool_result" {
        tool_name = data.get("tool", "");
        result = data.get("result", "");
        if tool_name and tool_name != "finish_tool" {
            prefix = get_agent_prefix();
            prefix_display = f"[{prefix}] " if prefix else "";
            result_clean = result.replace("\n", " ");
            result_short = result_clean[:150] + "..." if len(result_clean) > 150 else result_clean;
            sys.stderr.write(f"  {DIM}{prefix_display}📄 → {result_short}{RESET}\n");
            sys.stderr.flush();
        }
    } elif event_type == "llm_steps_done" {
        iterations = data.get("iterations", 0);
        reason = data.get("reason", "");
        prefix = get_agent_prefix();
        prefix_display = f"[{prefix}] " if prefix else "";
        iter_label = f"{iterations} iteration{'s' if iterations != 1 else ''}";
        if reason {
            sys.stderr.write(f"  {GREEN}{prefix_display}✅ {iter_label} ({reason}){RESET}\n");
        } else {
            sys.stderr.write(f"  {GREEN}{prefix_display}✅ {iter_label}{RESET}\n");
        }
        sys.stderr.flush();
    } elif event_type == "turn_summary" {
        tools_count = data.get("tools_count", 0);
        files = data.get("files_modified", []);
        errors = data.get("errors", 0);
        duration = data.get("duration_s", 0.0);

        if tools_count == 0 {
            return;
        }

        parts: list = [];
        parts.append(f"{tools_count} tool{'s' if tools_count != 1 else ''}");
        if files {
            parts.append(f"{len(files)} file{'s' if len(files) != 1 else ''} modified");
        }
        if errors > 0 {
            parts.append(
                f"{RED}{errors} error{'s' if errors != 1 else ''}{RESET}{DIM}"
            );
        }
        parts.append(f"{duration}s");

        summary_text = ", ".join(parts);
        sys.stderr.write(f"\n  {DIM}-- {summary_text} --{RESET}\n\n");
        sys.stderr.flush();
    }
}
