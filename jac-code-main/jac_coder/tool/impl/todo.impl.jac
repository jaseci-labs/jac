impl update_todos(todos_json: str) -> str {
    tool_status("update_todos");
    global _todos;

    if not todos_json {
        return "Error: todos_json is required (JSON array of {content, status})";
    }

    try {
        todos = json.loads(todos_json);
    } except json.JSONDecodeError as e {
        return f"Error: invalid JSON — {e}";
    }

    if not isinstance(todos, list) {
        return "Error: todos_json must be a JSON array";
    }

    items = [];
    for item in todos {
        content = item.get("content", "") if isinstance(item, dict) else str(item);
        status = item.get("status", "pending") if isinstance(item, dict) else "pending";
        if status not in ["pending", "in_progress", "completed"] {
            status = "pending";
        }
        items.append({"content": content, "status": status});
    }

    _todos["default"] = items;
    done = len(
        [
            i
            for i in items
            if i["status"] == "completed"
        ]
    );
    tool_end(f"-> {done}/{len(items)} done");

    lines = [];
    for item in items {
        if item["status"] == "completed" {
            icon = "[x]";
        } elif item["status"] == "in_progress" {
            icon = "[>]";
        } else {
            icon = "[ ]";
        }
        lines.append(f"{icon} {item['content']}");
    }

    return "\n".join(lines) if lines else "Todo list cleared.";
}


impl get_todos(session_id: str = "default") -> list {
    global _todos;
    return _todos.get(session_id, []);
}
