# Walker to create that graph under that user_root
walker update_graph {
    has user_jid: str;
    has date: str;
    has day_graph: dict;
    has buddy_schedule: dict = {};
    has user_level_buddy_schedule: dict = {};

    async can go_to_user with `root entry;
    async can go_to_day with user_root entry;
    async can update_day_graph with day entry;
}
