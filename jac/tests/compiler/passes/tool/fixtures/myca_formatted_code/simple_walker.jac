node day {}
edge future {}
edge parent {}

walker get_last_active_day {
    def post_init() {
        self.last_active_day: day | None = None;
    }
    # has last_active_day: day | None by postinit;
    can go_back with day entry {
        items = [->:parent:->];
        if items == [] {
            old_day = [<-:future:<-];
            if len(old_day) == 0 {
                self.last_active_day = here;
                return;
            } else {
                visit old_day[0];
            }
        } else {
            self.last_active_day = here;
            return;
        }
    }
}
