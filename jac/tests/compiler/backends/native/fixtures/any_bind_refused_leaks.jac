import json;

def refused(text: str) -> int {
    try {
        counts: dict[str, int] = json.loads(text);
        return len(counts);
    } except TypeError {
        return 1;
    }
}

def run_all -> int {
    total = 0;
    for i in range(10) {
        total = total + refused("{\"x\": " + str(i) + "}");
    }
    return total;
}

with entry {
    print(run_all());
    __rc_collect_cycles();
    __rc_debug_enable();
}
