"""Browser-global seeding looks at references, not member names.

Every def below spells a field `window`, `performance` or `fetch`: as a keyword
argument, a connect or assign-comprehension field, a class-pattern field, a
filter field or an ordering term. None of them references the browser global,
so none may seed client. `uses_window` and `filter_by_performance` do reference
browser globals and must still seed client.
"""

node Room {
    has id: int = 0,
        fetch: int = 0;
}

edge Passage: Room --> Room {
    has window: bool = False;
}

obj Opts {
    has performance: float = 0.0;
}

def connect_window(a: Room, b: Room) {
    a +>:Passage(window=True):+> b;
}

def build_opts -> Opts {
    return Opts(performance=1.0);
}

def filter_window(a: Room) -> list[Room] {
    return [a->:Passage:window==True:->];
}

def filter_fetch(a: Room) -> list[Room] {
    return [a-->][?:Room, fetch==1];
}

def order_fetch(a: Room) -> list[Room] {
    return [a-->][?:Room, -fetch];
}

def assign_fetch(a: Room) {
    [a->:Passage:->](=fetch=3);
}

def match_performance(o: Opts) -> int {
    match o {
        case Opts(performance = 1.0):
            return 1;

        case _:
            return 0;

    }
}

def takes_window(window: int) -> int {
    return window;
}

def pass_window -> int {
    return takes_window(window=3);
}

def uses_window -> int {
    return len(window.location.href);
}

def filter_by_performance(a: Room) -> list[Room] {
    return [a-->][?:Room, id==performance.now()];
}
