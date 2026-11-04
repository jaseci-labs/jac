"""A C struct's function-pointer field with no sized parameter or result."""
import from c {
    def table_answer -> int {
        return 42;
    }  def table_echo(value: int) -> int {
        return value;
    }  obj Table {
        has answer: Callable[[], int] = 0,
            echo: Callable[[int], int] = 0;
    }
}

obj Holder {
    has api: Table = Table();
}

def call_fields(n: int) -> int {
    h = Holder();
    h.api.answer = table_answer;
    h.api.echo = table_echo;
    a = h.api;
    got = a.answer();
    if got == 0 {
        return -1;
    }
    echoed = a.echo(n);
    return got + echoed;
}
