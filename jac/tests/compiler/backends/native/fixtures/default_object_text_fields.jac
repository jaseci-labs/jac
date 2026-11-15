obj Base {
    has x: int = 1,
        y: int = 2;
}

obj Child(Base) {
    has x: int = 3;
}

obj Blob {
    has name: str,
        data: bytes | None = None;
}

with entry {
    print(Child());
    print(Base(), Child(x=5, y=6));
    blob = Blob(name="b");
    if blob.name == "never" {
        print(blob);
    }
    print(blob.name);
}
