import from jaclang.data.contracts { JsonEndpoint }
import from core.github_contracts { GithubRepository, GithubUser }
import from urllib.parse { quote }
import from core.github { fetch }
import from .auth { github_id }

obj GithubRepo {
    has full: str,
        url: str,
        description: str = "",
        stars: int = 0;
}

obj GithubRepos {
    has linked: bool = False,
        login: str = "",
        repos: list[GithubRepo] = [],
        next_page: int = 0,
        error: str = "";
}

def public_api(path: str) -> bytes {
    data = fetch("https://api.github.com" + path, "JacYac", accept_json=True);
    if data is None {
        raise RuntimeError("GitHub is unavailable or rate limited.");
    }
    return data;
}

def:pub github_repositories(session_token: str, page: int = 1) -> GithubRepos {
    external_id = github_id(session_token);
    if not external_id {
        return GithubRepos();
    }
    try {
        info = JsonEndpoint[GithubUser](GithubUser, "/user/" + external_id).read(
            public_api
        );
        login = info.login;
        if str(info.id) != external_id or not login {
            return GithubRepos(
                linked=True, error="Could not verify your GitHub account."
            );
        }
        current = max(1, min(page, 100));
        raw = JsonEndpoint[list[GithubRepository]](
            list[GithubRepository],
            "/users/"
                + quote(login, safe="")
                + "/repos?type=owner&sort=updated&per_page=30&page="
                + str(current)
        ).read(
            public_api
        );
        repos: list[GithubRepo] = [];
        for repo in raw {
            if not repo.private and str(repo.owner.id) == external_id {
                full = repo.full_name;
                repos.append(
                    GithubRepo(
                        full=full,
                        url="https://github.com/" + full,
                        description=repo.description or "",
                        stars=repo.stargazers_count
                    )
                );
            }
        }
        return GithubRepos(
            linked=True,
            login=login,
            repos=repos,
            next_page=current + 1 if len(raw) == 30 else 0
        );
    } except Exception {
        return GithubRepos(
            linked=True, error="Could not load GitHub repositories. Please try again."
        );
    }
}

def verified_owner(full: str, session_token: str) -> bool {
    external_id = github_id(session_token);
    if not external_id {
        return False;
    }
    try {
        repo = JsonEndpoint[GithubRepository](GithubRepository, "/repos/" + full).read(
            public_api
        );
        return not repo.private and str(repo.owner.id) == external_id;
    } except Exception {
        return False;
    }
}
