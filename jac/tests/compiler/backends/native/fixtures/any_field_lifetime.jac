glob dropped: int = 0;

obj Link {
    has next: any = None;

    def drop {
        dropped += 1;
    }
}

def release_field {
    parent = Link(next=Link());
}

def replace_borrowed(value: any) {
    holder = Link();
    holder.next = value;
    holder.next = holder.next;
    holder.next = None;
}

def borrowed_field -> int {
    value = Link();
    before = dropped;
    replace_borrowed(value);
    return dropped - before;
}

def make_cycle {
    first = Link();
    second = Link();
    first.next = second;
    second.next = first;
}

def drop_count -> int {
    return dropped;
}

def collect {
    __rc_collect_cycles();
}
