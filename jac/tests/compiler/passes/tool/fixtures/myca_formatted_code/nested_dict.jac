walker test {
    has user_level_buddy_schedule: dict = {
        "d1_reminder": {"status": "pending", "walker": "d1_reminder"},
        "inactive_user": {
            "status": "pending",
            "last_run": None,
            "walker": "inactive_user"
        },
        "morning_greeting": {
            "status": "pending",
            "last_run": None,
            "walker": "morning_greeting"
        }
    };
}
