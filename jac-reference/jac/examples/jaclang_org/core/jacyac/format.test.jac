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

test "text_segments links urls and site paths and marks mentions" {
    segs = text_segments(
        "Walkers covers this: /docs/latest/walkers. Ask @ninjaclaw or see https://jaclang.org!"
    );
    kinds = [s["k"] for s in segs];
    assert kinds == ["t", "link", "t", "mention", "t", "link", "t"];
    assert segs[1]["t"] == "/docs/latest/walkers";
    assert segs[2]["t"].startswith(".");
    assert segs[3]["t"] == "@ninjaclaw";
    assert segs[5]["t"] == "https://jaclang.org";
    assert segs[6]["t"] == "!";
    assert text_segments("plain words only") == [{"k": "t", "t": "plain words only"}];
    assert text_segments("") == [];
}
