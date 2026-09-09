import from unittest.mock { patch }

test "Repository picker exposes only public repositories owned by the linked identity" {
    with patch(github_repositories.__module__ + ".github_id", return_value="123"), patch(
        github_repositories.__module__ + ".public_api",
        side_effect=[
            {"id": 123, "login": "renamed"},
            [
                {"full_name": "renamed/public", "private": False, "owner": {"id": 123}},
                {"full_name": "renamed/private", "private": True, "owner": {"id": 123}},
                {"full_name": "someone/other", "private": False, "owner": {"id": 999}}
            ]
        ]
    ) {
        result = github_repositories("session");
        assert result.linked and result.login == "renamed" , (
            result,
            github_repositories.__module__
        );
        assert [r.full for r in result.repos] == ["renamed/public"];
    }
}

test "Repository owner verification uses immutable IDs and rejects private repositories" {
    with patch(github_repositories.__module__ + ".github_id", return_value="123"), patch(
        github_repositories.__module__ + ".public_api",
        side_effect=[
            {"private": False, "owner": {"id": 123}},
            {"private": True, "owner": {"id": 123}},
            {"private": False, "owner": {"id": 999}}
        ]
    ) {
        assert verified_owner("owner/repo", "session");
        assert not verified_owner("owner/repo", "session");
        assert not verified_owner("owner/repo", "session");
    }
}

test "Unlinked visitors do not trigger GitHub API requests" {
    with patch(github_repositories.__module__ + ".github_id", return_value=""), patch(
        github_repositories.__module__ + ".public_api"
    ) as api {
        assert not github_repositories("").linked;
        assert not verified_owner("owner/repo", "");
        api.assert_not_called();
    }
}
