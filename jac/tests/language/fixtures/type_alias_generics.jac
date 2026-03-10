type JsonPrimitive = str | int | float | bool | None;

type Json = JsonPrimitive | list[Json] | dict[str, Json];

obj Result[T, E = Exception] {
    has value: T | None = None,
        error: E | None = None;

    def is_ok -> bool {
        return self.error is None;
    }
}

with entry {
    r1 = Result[int, ValueError](value=42);
    print(r1.is_ok());
    print(r1.value);

    r2 = Result[str, Exception](value="ok");
    print(r2.value);
}
