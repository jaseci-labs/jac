"""Fixture for W3022: Nested if can be collapsed into elif."""

with entry {
    x = 5;

    # Bad: nested if inside else
    if x > 10 {
        print("big");
    } else {
        if x > 5 {          # <-- Warning W3022: collapse to elif
            print("medium");
        }
    }

    # Good: uses elif
    if x > 10 {
        print("big");
    } elif x > 5 {           # <-- Ok
        print("medium");
    }
}
