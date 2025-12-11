node user_root {}
walker update_graph {}

walker cycle {
    can cycle with user_root entry {
        self.jaseci_sdk = {};
        res = f"> Processing for {here.name} {here.jid}";
        try {
            user_jid = here.jid;
            day_graph = self.jaseci_sdk.fetch_graph(user_jid=user_jid, date=self.today);
            here spawn update_graph(
                user_jid=user_jid,
                date=self.today,
                day_graph=day_graph,
                buddy_schedule=self.buddy_schedule,
                user_level_buddy_schedule=self.user_level_buddy_schedule
            );
            here spawn push_to_mobile(user_jid=user_jid, date=self.today);
        } except Exception as e {
            print(f"Error processing for {here.name} {here.jid}: {e}");
        }
    }
}
