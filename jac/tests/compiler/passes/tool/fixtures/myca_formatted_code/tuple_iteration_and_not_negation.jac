node n {}

walker test {
    can c with n entry {
        self.user_level_buddy_schedule = {};
        # Update any new user level buddy schedule
        for (k, v) in self.user_level_buddy_schedule.items() {
            if k not in here.user_level_buddy_schedule {
                here.user_level_buddy_schedule[k] = v;
            } else {
                # update one lever deeper, for new fields in each buddy schedule
                for (bk, bv) in v.items() {
                    if bk not in here.user_level_buddy_schedule[k] {
                        here.user_level_buddy_schedule[k][bk] = bv;
                    }
                }
            }
        }
    }
}
