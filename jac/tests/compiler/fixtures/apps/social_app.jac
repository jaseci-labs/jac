"""File-rooted `social` service app: the provider side of every bridge below."""

import from typing { Generator }

obj Profile {
    has name: str,
        score: int = 0;
}

walker Greet {
    has name: str;

    can go with Root entry {
        report Profile(name=self.name);
    }
}

def:pub greet(name: str) -> Profile {
    return Profile(name=name);
}

def hidden(name: str) -> str {
    return name;
}

node Post {
    has text: str = "";
}

def:pub narrate(n: int) -> Generator[str, None, None] {
    for i in range(n) {
        yield f"chunk {i}";
    }
}
