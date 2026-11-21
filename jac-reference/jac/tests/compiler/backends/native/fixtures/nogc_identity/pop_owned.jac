"""`pop()` on a `list[own T]` hands the element to the receiver, which drops
it once; the emptied list drops nothing (#8984 A2)."""

obj Job {
    has id: int = 0;

    def drop { print("drop " + str(self.id)); }
}

def run -> int {
    q: list[own Job] = [];
    q.append(Job(id=1));
    q.append(Job(id=2));
    q.append(Job(id=3));
    n = 0;
    while len(q) > 0 {
        j: own Job = q.pop();
        n += j.id;
    }
    return n;
}

with entry { print(run()); print("done"); }
