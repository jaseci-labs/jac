"""N6: a defensive copy taken only on one member of a union field.

`LambdaExpr.postinit` used to open with

    lam_body = self.body;
    if isinstance(lam_body, list) { self.body = `list(lam_body); }

so a lambda never aliases the caller's list. The workaround deleted the copy
outright and replaced it with a comment promising every constructor hands
over a fresh list -- the only one of the six that traded a safety property
for lowerability, so it is the one that has to be checked by *aliasing*, not
by whether it compiled.

`shared_list_is_not_aliased` mutates the caller's list after construction:
with the copy the object's view stays at two elements, without it the
mutation shows through. `expr_body_untouched` pins the other arm -- a
non-list body must survive the postinit unchanged.
"""

obj Ex {
    has v: int = 0;
}


obj Lam {
    has body: Ex | list[Ex];

    def postinit -> None;
    def size -> int;
    def first -> int;
}


impl Lam.postinit -> None {
    lam_body = self.body;
    if isinstance(lam_body, list) {
        self.body = `list(lam_body);
    }
}


impl Lam.size -> int {
    b = self.body;
    if isinstance(b, list) {
        return len(b);
    }
    return -1;
}


impl Lam.first -> int {
    b = self.body;
    if isinstance(b, list) {
        if not b {
            return -2;
        }
        return b[0].v;
    }
    return b.v;
}


"""The caller's list is mutated after the lambda is built."""
def shared_list_is_not_aliased(pick: int) -> int {
    shared: list[Ex] = [Ex(v=1), Ex(v=2)];
    lam = Lam(body=shared);
    if pick > 0 {
        shared.append(Ex(v=3));
    }
    if pick > 1 {
        shared.append(Ex(v=4));
    }
    return lam.size();
}


"""The un-copied member: an expression body must pass through untouched."""
def expr_body_untouched(pick: int) -> int {
    lam = Lam(body=Ex(v=41 + pick));
    return lam.first();
}


"""The list arm's payload has to survive the copy, not just its length."""
def copied_list_keeps_payload(pick: int) -> int {
    shared: list[Ex] = [Ex(v=7 + pick), Ex(v=8)];
    lam = Lam(body=shared);
    shared[0] = Ex(v=-100);
    return lam.first();
}
