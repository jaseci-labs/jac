impl PermissionEngine.init_defaults() -> None {
    for tool in [
        "read_file",
        "list_files",
        "grep_search",
        "find_files",
        "web_fetch",
        "web_search",
        "ask_question",
        "update_todos",
        "jac_check",
        "jac_run",
        "spawn_task"
    ] {
        self.rules.append(PermissionRule(tool=tool, action="allow"));
    }
    for tool in ["write_file", "edit_file", "bash_exec"] {
        self.rules.append(PermissionRule(tool=tool, action="ask"));
    }
}


impl PermissionEngine.check(tool_id: str, resource: str = "") -> str {
    if tool_id in self.always_allowed {
        for pattern in self.always_allowed[tool_id] {
            if pattern == "*" or fnmatch.fnmatch(resource, pattern) {
                return "allow";
            }
        }
    }

    matched_rule: PermissionRule | None = None;
    for rule in self.rules {
        if rule.tool == "*" or rule.tool == tool_id {
            if rule.pattern == "*" or fnmatch.fnmatch(resource, rule.pattern) {
                matched_rule = rule;
            }
        }
    }

    if matched_rule is None {
        return "ask";
    }
    return matched_rule.action;
}


impl PermissionEngine.remember_allow(tool_id: str, pattern: str = "*") -> None {
    if tool_id not in self.always_allowed {
        self.always_allowed[tool_id] = [];
    }
    if pattern not in self.always_allowed[tool_id] {
        self.always_allowed[tool_id].append(pattern);
    }
}


impl PermissionEngine.enable_web_mode() -> None {
    self.remember_allow("write_file", "*");
    self.remember_allow("edit_file", "*");
    self.remember_allow("bash_exec", "*");
}
