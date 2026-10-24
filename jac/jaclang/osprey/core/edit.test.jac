test "apply_edit success replaces the unique occurrence" {
    src = "def foo():\n    pass\n";
    out = apply_edit(src, "pass", "return 1");
    assert out == "def foo():\n    return 1\n";
}

test "apply_edit not-found and ambiguous return ERROR strings" {
    r = apply_edit("abc", "zzz", "q");
    assert isinstance(r, str);
    assert r.startswith("ERROR:");
    assert "not found" in r;
    amb = apply_edit("aXbXc", "X", "Y");
    assert amb.startswith("ERROR:");
    assert "more than once" in amb;
}

test "apply_edit rejects empty old_text without raising" {
    assert apply_edit("abc", "", "x").startswith("ERROR:");
}

test "multi-edit applies all pairs in order" {
    src = "alpha beta gamma";
    edits = [["beta", "BETA"], ["gamma", "GAMMA"], ["alpha BETA GAMMA", "done"]];
    assert apply_multi_edit(src, edits) == "done";
}

test "multi-edit is atomic: failure names the pair index and yields no partial result" {
    src = "one two three";

    edits = [["two", "TWO"], ["four", "FOUR"]];
    r = apply_multi_edit(src, edits);
    assert r.startswith("ERROR:");
    assert "2 of 2" in r;
    assert src == "one two three";

    edits2 = [["nope", "x"], ["two", "TWO"]];
    r2 = apply_multi_edit(src, edits2);
    assert r2.startswith("ERROR:");
    assert "1 of 2" in r2;
    assert apply_multi_edit(src, []) == src;
}

test "replace_lines swaps a 1-based inclusive range" {
    src = "l1\nl2\nl3\nl4\n";
    assert replace_lines(src, 2, 3, "L2'\nL3'") == "l1\nL2'\nL3'\nl4\n";
}

test "replace_lines handles a single line and adds newline when needed" {
    src = "a\nb\nc\n";
    assert replace_lines(src, 2, 2, "B") == "a\nB\nc\n";
    assert replace_lines(src, 3, 3, "C") == "a\nb\nC\n";
}

test "replace_lines full-file range works" {
    src = "x\ny\n";
    assert replace_lines(src, 1, 2, "all\nnew") == "all\nnew\n";

    assert replace_lines(src, 1, 2, "") == "";
}

test "replace_lines bounds violations return ERROR strings" {
    src = "a\nb\n";
    assert replace_lines(src, 0, 1, "z").startswith("ERROR:");
    assert replace_lines(src, 1, 5, "z").startswith("ERROR:");
    assert replace_lines(src, 3, 4, "z").startswith("ERROR:");
    assert replace_lines(src, 2, 1, "z").startswith("ERROR:");
    assert replace_lines("", 1, 1, "z").startswith("ERROR:");
}

test "count_matches is non-overlapping" {
    assert count_matches("aaaa", "aa") == 2;
    assert count_matches("aaa", "aa") == 1;
    assert count_matches("abcabc", "abc") == 2;
    assert count_matches("abc", "xyz") == 0;
    assert count_matches("abc", "") == 0;
    assert count_matches("", "a") == 0;
}

test "unified diff addition-only change produces @@ hunk with + lines" {
    old_t = "a\nb\n";
    new_t = "a\nb\nc\n";
    d = compute_unified_diff(old_t, new_t);
    assert d.startswith("@@");
    assert "+c" in d;
    assert "-b" not in d;
}

test "unified diff of identical inputs is empty" {
    assert compute_unified_diff("same\n", "same\n") == "";
    assert compute_unified_diff("", "") == "";
}

test "unified diff respects context window" {
    old_t = "l1\nl2\nl3\nl4\nl5\nl6\nl7\nl8\nl9\nl10\n";
    new_t = "l1\nl2\nl3\nl4\nl5\nCHANGED\nl7\nl8\nl9\nl10\n";
    with_ctx3 = compute_unified_diff(old_t, new_t, context=3);
    assert "@@ -3,7 +3,7 @@" in with_ctx3;
    assert " l1" not in with_ctx3;
    assert " l3" in with_ctx3;
    assert "-l6" in with_ctx3;
    assert "+CHANGED" in with_ctx3;
    with_ctx1 = compute_unified_diff(old_t, new_t, context=1);
    assert "@@ -5,3 +5,3 @@" in with_ctx1;
    assert " l4" not in with_ctx1;
    assert " l5" in with_ctx1;
    assert compute_unified_diff(old_t, new_t, context=-1).startswith("ERROR:");
}

test "guess_indentation prefers spaces on majority and tabs on majority" {
    spaces_src = "def f():\n    a = 1\n    b = 2\n";
    assert guess_indentation(spaces_src) == "    ";
    two_space_src = "if x:\n  y\n  z\n";
    assert guess_indentation(two_space_src) == "  ";
    tabs_src = "def f():\n\ta = 1\n\tb = 2\n";
    assert guess_indentation(tabs_src) == "\t";

    tie_src = "def f():\n    a\n\tb\n";
    assert guess_indentation(tie_src) == "    ";
    assert guess_indentation("no indent here") == "";
}
