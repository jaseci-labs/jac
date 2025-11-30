node user_root {}
node day {}

walker update_graph {
    has user_jid: str;
    has date: str;

    can go_to_user with `root entry;
}

impl update_graph.go_to_user{
    visit [-->(`?user_root)](?jid==self.user_jid);
    next = [-->];
    visit [
        i
        for i in next
        if isinstance(i, day) and i.date == self.date
    ];
}
