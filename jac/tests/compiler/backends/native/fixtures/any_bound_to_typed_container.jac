import json;

node Item {
    has n: int = 0;
}

obj Holder {
    has eff: dict[str, dict[str, any]] = {};
}

def typed_back(raw: any) -> int {
    held: dict[str, int] = raw;
    return held.get("k", -1);
}

def json_empty -> int {
    counts: dict[str, int] = json.loads("{}");
    counts["n"] = 4;
    return counts.get("n", 0);
}

def json_ints(text: str) -> str {
    try {
        counts: dict[str, int] = json.loads(text);
        return str(counts.get("x"));
    } except TypeError {
        return "TypeError";
    }
}

def json_field(text: str) -> str {
    holder = Holder();
    try {
        holder.eff = json.loads(text);
        return str(len(holder.eff));
    } except TypeError {
        return "TypeError";
    }
}

def floats_from_ints(raw: any) -> str {
    try {
        held: list[float] = raw;
        return str(held[0]);
    } except TypeError {
        return "TypeError";
    }
}

def walked(raw: any) -> int {
    items: list[Item] = raw;
    return len(items) + items[0].n;
}

glob held: dict[str, int] = {"k": 7};

with entry {
    print("typed", typed_back(held));
    print("empty", json_empty());
    print("ints", json_ints("{\"x\": 3}"));
    print("field", json_field("{\"a.b\": {\"w\": 1}}"));
    print("floats", floats_from_ints([3]));
    hub = Item();
    hub ++> Item(n=5);
    print("walked", walked([hub-->]));
}
