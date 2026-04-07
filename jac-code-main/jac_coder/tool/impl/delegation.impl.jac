impl init_budget(total: int = 90) -> None {
    _tl.budget = total;
    _tl.budget_initialized = True;
    _tl.recent_results = [];
}


impl get_remaining_budget() -> int {
    return getattr(_tl, "budget", 0);
}


impl consume_budget(used: int) -> None {
    _tl.budget = max(0, getattr(_tl, "budget", 0) - used);
}


impl get_recent_results_summary() -> str {
    results = getattr(_tl, "recent_results", []);
    if not results {
        return "";
    }
    parts: list = [];
    for r in results[-3:] {
        line = f"- [{r.get('mode', 'worker')}] {r.get('task_preview', '')[:100]}";
        fmod = r.get("files_modified", []);
        if fmod {
            line += f" -> modified: {', '.join(fmod)}";
        }
        errs = r.get("errors", []);
        if errs {
            line += f" -> errors: {', '.join(errs[:2])}";
        }
        parts.append(line);
    }
    return "Previous SubAgent results:\n" + "\n".join(parts);
}


impl get_project_summary_for_subagent() -> str {
    try {
        import jac_coder.nodes as _nodes;
        sessions = [root()-->(?:(_nodes.Session))](?status=="active");
        if sessions {
            sessions.sort(key=lambda s : s.updated_at, reverse=True);
            proj_summary = sessions[0].project_summary;
            if proj_summary {
                return proj_summary;
            }
        }
    } except Exception { }
    return "";
}


impl spawn_agent(task: str, mode: str = "worker") -> str {
    tool_status("spawn_agent", f"[{mode}] {task[:80]}...");

    if not task {
        tool_end("-> no task", error=True);
        return "Error: task description is required.";
    }

    if mode not in ["worker", "explorer"] {
        mode = "worker";
    }

    # Initialize per-thread budget on first SubAgent call in this chat() turn
    if not getattr(_tl, "budget_initialized", False) {
        cfg = get_config();
        init_budget(cfg.max_react_iterations * 3);
    }
    remaining = get_remaining_budget();
    if remaining <= 0 {
        tool_end("-> budget exhausted", error=True);
        return "Error: Iteration budget exhausted. Cannot spawn more SubAgents.";
    }

    # Enrich task with session context
    project_ctx = get_project_summary_for_subagent();
    recent_work = get_recent_results_summary();

    enriched_parts: list = [task];
    if project_ctx {
        enriched_parts.append(f"\n\n--- Project Context ---\n{project_ctx}");
    }
    if recent_work {
        enriched_parts.append(f"\n\n--- Recent SubAgent Work ---\n{recent_work}");
    }
    enriched_task = "".join(enriched_parts);

    # Spawn SubAgent walker on the MainAgent node
    import from jac_coder.nodes { WorkerAgent, ExplorerAgent }
    import from jac_coder.walkers { ensure_main_agent }
    ;

    try {
        main_agent = ensure_main_agent();

        # Spawn the walker on MainAgent — entry ability handles streaming + event forwarding
        if mode == "worker" {
            result = main_agent spawn WorkerAgent(task=enriched_task);
        } else {
            result = main_agent spawn ExplorerAgent(task=enriched_task);
        }

        # Extract result from walker's has fields
        content = result.result_content;
        used_tools = result.result_tools;
        fmod = result.result_files;

        has_errs = False;
        iters_used = len(used_tools) if used_tools else 5;

        # Track budget and state
        consume_budget(iters_used);
        for fp in fmod {
            track_file(fp);
        }
        if has_errs {
            track_error();
        }

        # Record result for subsequent SubAgents in this turn
        _tl.recent_results.append(
            {
                "mode": mode,
                "task_preview": task[:200],
                "files_modified": fmod,
                "errors": ["error"] if has_errs else [],
                "content_preview": content[:300] if content else ""
            }
        );

        # Build result string
        result_parts: list = [];
        if content {
            result_parts.append(content);
        }
        if fmod {
            result_parts.append(f"\nFiles modified: {', '.join(fmod)}");
        }
        if has_errs {
            result_parts.append(
                "\nNote: Some errors were encountered during execution."
            );
        }

        tool_end(f"-> {mode} done, {len(fmod)} files");
        return "\n".join(result_parts) if result_parts else "SubAgent completed.";
    } except Exception as e {
        consume_budget(5);
        tool_end(f"-> error: {e}", error=True);
        track_error();
        return f"Error: SubAgent failed - {str(e)}";
    }
}
