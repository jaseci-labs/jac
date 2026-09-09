obj GithubUser {
    has id: int,
        login: str,
        avatar_url: str = "";
}

obj GithubRepository {
    has full_name: str,
        name: str,
        owner: GithubUser,
        private: bool,
        description: str | None = None,
        html_url: str = "",
        default_branch: str = "main",
        stargazers_count: int = 0,
        forks_count: int = 0,
        size: int = 0,
        topics: list[str] = [],
        pushed_at: str | None = None,
        created_at: str = "";
}

obj GithubCommit {
    has sha: str;
}
