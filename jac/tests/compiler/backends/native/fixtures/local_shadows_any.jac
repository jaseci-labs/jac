"""A local named `any` shadows the builtin: reads see the local's value."""

def joined(groups: list[list[int]]) -> str {
    out: list[str] = [];
    any: bool = False;
    for group in groups {
        if len(group) == 0 {
            continue;
        }
        if any {
            out.append(",");
        }
        out.append(str(sum(group)));
        any = True;
    }
    return "".join(out) + (" seen" if any else " empty");
}

with entry {
    print(joined([[1, 2], [], [3]]));
    print(joined([[], []]));
}
