with entry {
    user_level_buddy_schedule = {};
    user_root_node_messages = {};
    if last_run is None {
        user_level_buddy_schedule["d1_reminder"]["last_run"] = "2021-06-01T00:00:00Z";
        user_root_node_messages["web"].append(
            {"type": "mid_day_nudge", "message": res["response"]}
        );
    }
}
