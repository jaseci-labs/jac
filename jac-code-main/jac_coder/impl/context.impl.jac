sem summarize_turns = """Summarize the conversation history for a coding agent.
Given the older messages and the session goal, produce a concise summary that captures:
1. What the user asked for in each turn (key requests)
2. What files were created or modified
3. What errors were encountered and how they were fixed
4. Key decisions made (e.g. "chose nodes over dicts", "used auth guards for protected routes")
5. Current state of the project (what's built, what's working, what's broken)

Format: Write 3-8 bullet points. Each bullet should be one sentence.
Do NOT include code snippets. Do NOT repeat the session goal.
Focus on WHAT happened and WHY, not HOW (no tool names or technical details).
Keep the total summary under 300 words.""";

sem summarize_turns.older_messages = "The older conversation messages (user + assistant pairs) that need to be summarized";
sem summarize_turns.session_goal = "The original user request that started this session";


def _build_prefix(
    active_files: list[str], pending_errors: list[str], project_summary: str = ""
) -> list[dict] {
    parts = [];
    if project_summary {
        parts.append("Project context:\n" + project_summary);
    }
    if active_files {
        parts.append("Active files: " + ", ".join(active_files));
    }
    if pending_errors {
        parts.append("Pending errors:\n" + "\n".join(pending_errors));
    }
    if parts {
        return [{"role": "system", "content": "\n\n".join(parts)}];
    }
    return [];
}


"""Format older messages into a text block for the summarization LLM."""
def _format_for_summary(messages: list[dict]) -> str {
    lines: list = [];
    for msg in messages {
        role = msg.get("role", "");
        content = msg.get("content", "")[:200];
        files = msg.get("files_modified", []);
        if role == "user" {
            lines.append(f"User: {content}");
        } elif role == "assistant" {
            files_str = f" [files: {', '.join(files[:5])}]" if files else "";
            lines.append(f"Assistant: {content}{files_str}");
        }
    }
    return "\n".join(lines);
}


impl estimate_tokens(messages: list[dict]) -> int {
    total = 0;
    for msg in messages {
        total += len(msg.get("content", ""));
    }
    return total // 4;
}


impl needs_compaction(messages: list[dict], budget: int = 20000) -> bool {
    return estimate_tokens(messages) > int(budget * 0.8);
}


impl build_context(
    chat_history: list[dict],
    active_files: list[str] = [],
    pending_errors: list[str] = [],
    config: ContextConfig | None = None,
    project_summary: str = ""
) -> list[dict] {
    cfg = config if config else ContextConfig();
    prefix = _build_prefix(active_files, pending_errors, project_summary);

    if not needs_compaction(chat_history, cfg.token_budget) {
        return prefix + list(chat_history);
    }

    recent_msg_count = cfg.recent_window * 2;
    if len(chat_history) <= recent_msg_count {
        return prefix + list(chat_history);
    }

    recent = chat_history[-recent_msg_count:];
    older = chat_history[:-recent_msg_count];

    # Layer 1: Extract the session goal (first user message — always preserved)
    session_goal = "";
    for msg in older {
        if msg.get("role") == "user" {
            session_goal = msg.get("content", "");
            break;
        }
    }

    # Layer 2: LLM-based summarization of older turns
    summary_text = "";
    older_text = _format_for_summary(older);
    if older_text {
        try {
            import from jac_coder.events { emit_event }
            ;
            emit_event("context_compaction", {
                "status": "started",
                "turns_to_summarize": len([m for m in older if m.get("role") == "user"])
            });
            summary_text = summarize_turns(
                older_messages=older,
                session_goal=session_goal
            );
            emit_event("context_compaction", {
                "status": "done",
                "summary_length": len(summary_text)
            });
        } except Exception as e {
            # Fallback: extract key info without LLM
            import sys;
            sys.stderr.write(f"[context] Summarization failed, using fallback: {e}\n");
            files: list = [];
            user_requests: list = [];
            for msg in older {
                if msg.get("role") == "user" {
                    req = msg.get("content", "")[:80];
                    if req {
                        user_requests.append(req);
                    }
                }
                for f in msg.get("files_modified", []) {
                    if f not in files {
                        files.append(f);
                    }
                }
            }
            parts: list = [];
            parts.append(f"{len(user_requests)} earlier turns.");
            if user_requests {
                parts.append("User asked: " + " → ".join(user_requests[:5]));
            }
            if files {
                parts.append(f"Files modified: {', '.join(files[:8])}.");
            }
            summary_text = " ".join(parts);
        }
    }

    # Build the compacted context
    result = list(prefix);

    # Session goal — always present
    if session_goal {
        result.append({
            "role": "system",
            "content": f"Session goal (original request): {session_goal}"
        });
    }

    # LLM summary of older turns
    if summary_text {
        result.append({
            "role": "system",
            "content": f"Summary of previous work:\n{summary_text}"
        });
    }

    # Layer 3: Recent exchanges verbatim
    result.extend(recent);
    return result;
}
