"""Identity tests against booleans over dynamically typed values are
discriminators, not redundancy: replacing `v is True` with `v` changes
behavior for truthy non-bool values (1, "yes", [1])."""

def check(v: any) -> bool {
    return v is True;
}

def check_eq(v: any) -> bool {
    return v == True;
}

with entry {
    print(check(1));
    print(check_eq("yes"));
}
