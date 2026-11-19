"""`:=` field defaults, built directly and through `super.init()`, leave nothing alive."""

obj Walrused {
    has items: list[str] = (saved := ["w"]);
}

obj WalrusedChild(Walrused) {
    def init {
        super.init();
    }
}

def run -> int {
    total = 0;
    for i in range(50) {
        wd = Walrused();
        wc = WalrusedChild();
        wd.items.append(f"d{i}");
        total += len(wd.items) + len(wc.items);
    }
    return total;
}

with entry {
    print(run());
    __rc_collect_cycles();
    __rc_debug_enable();
}
