impl spawn_task(description: str, prompt: str, agent_type: str = "explore") -> str {
    tool_status("spawn_task", f"[{agent_type}] {description}");
    if not prompt {
        return "Error: prompt is required";
    }

    # Delegate to the new spawn_agent tool
    import from jac_coder.tool.delegation { spawn_agent }

    mode = "explorer" if agent_type == "explore" else "worker";
    return spawn_agent(task=prompt, mode=mode);
}
