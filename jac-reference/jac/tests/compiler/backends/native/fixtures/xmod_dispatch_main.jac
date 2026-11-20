import from xmod_dispatch_base { Driver }

class Consumer(Driver) {
    has mark: int = 0;

    def hook(self: Consumer) {
        self.mark = 7;
    }

    def label(self: Consumer) -> str {
        return "consumer";
    }
}

with entry {
    c = Consumer();
    c.drive();
    print(f"consumer_mark={c.mark}");
    print(f"consumer_tick={c.tick}");
    print(f"consumer_label={c.label()}");
    d = Driver();
    d.drive();
    print(f"base_tick={d.tick}");
    print(f"base_label={d.label()}");
}
