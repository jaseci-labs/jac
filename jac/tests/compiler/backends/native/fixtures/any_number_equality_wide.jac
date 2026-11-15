"""Untyped numbers compare by value past the range a float holds exactly."""

def same(a: any, b: any) -> bool {
    return a == b;
}

with entry {
    print(same(9007199254740993, 9007199254740992.0), same(9007199254740992, 9007199254740992.0));
    print(same(3, 3.0), same(-1, -1.0), same(2, 2.5), same(9223372036854775807, 9223372036854775808.0));
}
