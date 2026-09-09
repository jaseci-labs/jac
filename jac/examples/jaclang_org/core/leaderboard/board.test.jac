test "parse_repo_url_accepts_every_shape" {
    assert parse_repo_url("https://github.com/jaseci-labs/jac")
        == ("jaseci-labs", "jac");
    assert parse_repo_url("github.com/jaseci-labs/jac.git") == ("jaseci-labs", "jac");
    assert parse_repo_url("jaseci-labs/jac") == ("jaseci-labs", "jac");
    assert parse_repo_url("  github.com/jaseci-labs/jac/  ") == ("jaseci-labs", "jac");
}

test "parse_repo_url_rejects_non_github" {
    assert parse_repo_url("https://gitlab.com/a/b") is None;
    assert parse_repo_url("not a url") is None;
    assert parse_repo_url("") is None;
}
