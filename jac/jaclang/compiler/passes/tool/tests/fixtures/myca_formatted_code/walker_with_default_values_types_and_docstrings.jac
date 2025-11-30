"""
The cycle walker
"""

walker cycle {
    has buddy_schedule: dict = {};
    has user_level_buddy_schedule: dict = {
        "d1_reminder": {"status": "pending", "last_run": None, "walker": "d1_reminder"}
    };

    has use_fixture: bool = False;
    has user_list: list = [];
    has today: str = "";
    has force: bool = False;
}
