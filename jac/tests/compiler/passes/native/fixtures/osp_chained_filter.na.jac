"""Chained node-type filters: `[node-ref][?:Type]`.

The census probe over real projects showed this as the top any-receiver
source: the E5090 guidance says to narrow untyped adjacency with a
`[?:Type]` filter, and real code overwhelmingly writes that filter in the
chained form (`[origin-->][?:Task]`), which previously fell through the
atom-trailer path as an unlowerable subscript. The chained form now
applies the same OSP tag-filter kernel as the inline form, and the
filtered elements carry their narrowed type (field access lowers against
the concrete node layout). Origins are local nodes: `root` is the
persistent graph and stays a server signal by design.
"""

node Bucket {
    has label: str = "";
}

node Task {
    has title: str = "",
        done: bool = False;
}

node Note {
    has body: str = "";
}

def build_bucket -> Bucket {
    b = Bucket(label="work");
    b ++> Task(title="alpha");
    b ++> Note(body="noise");
    b ++> Task(title="be");
    return b;
}

def:pub count_tasks -> int {
    b = build_bucket();
    n = 0;
    for t in [b-->][?:Task] {
        n = n + 1;
    }
    return n;
}

def:pub title_len_total -> int {
    b = build_bucket();
    s = 0;
    for t in [b-->][?:Task] {
        s = s + len(t.title);
    }
    return s;
}

def:pub count_all -> int {
    b = build_bucket();
    n = 0;
    for t in [b-->] {
        n = n + 1;
    }
    return n;
}
