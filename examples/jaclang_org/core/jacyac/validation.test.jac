test "chars_left counts down from the post limit" {
    assert chars_left("") == post_limit();
    assert chars_left("hello") == post_limit() - 5;
    assert chars_left("x" * (post_limit() + 3)) == -3;
}

test "validation accepts the boundary and rejects empty or oversized drafts" {
    assert not valid_post(" \n ");
    assert valid_post("x" * post_limit());
    assert not valid_post("x" * (post_limit() + 1));
}
