"""Test typed context block (-> Type { ... }) parsing."""

node Item {
    has name: str;
}

walker Collector {
    has items: list[any] = [];

    can collect with Root entry {
        visit [-->];
        ->Item{self.items.append(here);}
    }
}
