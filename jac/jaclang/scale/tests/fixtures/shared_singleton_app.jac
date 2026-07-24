"""Fixture: concurrent find-or-create of a singleton anchored to root.shared."""

node Hub {
    has label: str = "community";
}

walker:pub touch_hub {
    can go with entry {
        hubs = [
            n
            for n in [root.shared-->]
            if isinstance(n, Hub)
        ];
        if not hubs {
            h = Hub(label="community");
            root.shared ++> h;
            hubs = [h];
        }
        report {"hubs": len(hubs)};
    }
}

walker:pub count_hubs {
    can go with entry {
        hubs = [
            n
            for n in [root.shared-->]
            if isinstance(n, Hub)
        ];
        report {"hubs": len(hubs)};
    }
}
