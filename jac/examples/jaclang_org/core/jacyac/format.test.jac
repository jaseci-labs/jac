test "handle_of drops an email domain and leaves plain names alone" {
    assert handle_of("ada@example.com") == "ada";
    assert handle_of("ada") == "ada";
    assert handle_of("") == "";
}

test "initial_of upper-cases the first letter and is safe on empty" {
    assert initial_of("grace") == "G";
    assert initial_of("Linus") == "L";
    assert initial_of("") == "?";
}


test "count_label picks the singular form only for one" {
    assert count_label(0, "member", "members") == "0 members";
    assert count_label(1, "member", "members") == "1 member";
    assert count_label(2, "member", "members") == "2 members";
}
