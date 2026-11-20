"""A typed list reached through `any` and returned as a `list[any]`."""
obj Box {
    has v: int = 0;
}

obj Holder {
    has keys: list[str],
        vals: list[any];

    def get(key: str) -> any {
        i = 0;
        while i < len(self.keys) {
            if self.keys[i] == key {
                return self.vals[i];
            }
            i += 1;
        }
        return None;
    }

    def items(key: str) -> list[any] {
        value: list[any] = self.get(key);
        return value;
    }
}

with entry {
    h = Holder(keys=["args"], vals=[[Box(v=1), Box(v=2), Box(v=3)]]);
    viewed = h.items("args");
    churn: list[list[int]] = [];
    for i in range(200) {
        churn.append([i, i + 1, i + 2, i + 3]);
    }
    viewed[0] = Box(v=9);
    print(len(viewed), len(churn), len(h.items("args")));
}
