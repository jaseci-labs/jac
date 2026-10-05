"""A collection must not start while a destructor is running. Each case
drops a container of 3000 boxes, each box the last owner of nothing but
holding one of 3000 shared anchors, so releasing the boxes decrements 3000
distinct anchors -- enough possible roots to trigger a collection in the
middle of the teardown -- while the holder that owned the container is
itself a buffered root the collection would trace. Collecting then would
trace the half-destroyed container and read the boxes it already freed."""

obj Anchor {
    has value: int = 0,
        next: Anchor | None = None;
}

obj Box {
    has anchor: Anchor | None = None,
        label: str = "";
}

obj Holder {
    has items: list[Box] = [],
        index: dict[str, Box] = {},
        peer: Holder | None = None;
}

def filled(anchors: list[Anchor]) -> Holder {
    holder = Holder();
    for i in range(len(anchors)) {
        box = Box(anchor=anchors[i], label="box" + str(i));
        holder.items.append(box);
        holder.index[box.label] = box;
    }
    holder.items.append(Box(label="spare"));
    return holder;
}

def buffered(holder: Holder) -> Holder {
    alias = holder;
    alias = Holder();
    return holder;
}

def replace_field(anchors: list[Anchor]) -> int {
    holder = filled(anchors);
    holder.index = {};
    buffered(holder);
    holder.items = [];
    return len(holder.items);
}

def clear_list(anchors: list[Anchor]) -> int {
    holder = filled(anchors);
    holder.index = {};
    buffered(holder);
    holder.items.clear();
    return len(holder.items);
}

def clear_dict(anchors: list[Anchor]) -> int {
    holder = filled(anchors);
    holder.items = [];
    buffered(holder);
    holder.index.clear();
    return len(holder.index);
}

def run_cases {
    anchors: list[Anchor] = [];
    for i in range(3000) {
        anchors.append(Anchor(value=i));
    }
    left = [0, 0, 0];
    for round in range(3) {
        left[0] += replace_field(anchors);
        left[1] += clear_list(anchors);
        left[2] += clear_dict(anchors);
    }
    print("replace_field", left[0], len(anchors));
    print("clear_list", left[1], len(anchors));
    print("clear_dict", left[2], len(anchors));
}

with entry {
    run_cases();
}
