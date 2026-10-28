import os;

node Room {
    has name: str;
}

walker Tour {
    has seen: list[str] = [];

    can start with Root entry {
        visit [-->];
    }

    can at_room with Room entry {
        self.seen.append(here.name);
        visit [-->];
    }
}

obj Stamp {
    has hash: int = 0;

    def stamp(text: str) -> int {
        self.hash = hash(text) % 7;
        return self.hash;
    }
}

def last_key(scores: dict[str, int]) -> str {
    for (key, score) in scores.items() {
        if score {
            break;
        }
    }
    return key;
}

def pick_first[T](items: list[T]) -> T {
    return items[0];
}

def env_flag(name: str) -> bool {
    return os.environ.get(name, "") == "1";
}

with entry {
    root ++> Room(name="a") ++> Room(name="b");
    print(
        (root spawn Tour()).seen,
        env_flag("PARITY_UNSET"),
        last_key({"a": 0, "b": 1}),
        pick_first(["p", "q"]),
        Stamp().stamp("x") >= 0
    );
}
