"""Brand violations: raw base into a distinct dest, cross-brand assign."""

type UserId := int;
type GroupId := int;

with entry {
    u: UserId = 5;
    g: GroupId = UserId(1);
    ok: int = UserId(2);
    print(u, g, ok);
}
