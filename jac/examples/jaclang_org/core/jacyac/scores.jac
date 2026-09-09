import from core.social_graph { Project }
import from core.jacyac.state { JacYacState }
import from core.jacyac.github.repos { GithubRepo, github_repositories }
import from "@jac/runtime" { __getLocalStorage }

obj Scores {
    has query: str,
        sort: str,
        projects: list[Project],
        repos: list[GithubRepo],
        githubLogin: str,
        githubLinked: bool,
        reposLoading: bool,
        reposError: str,
        nextPage: int,
        setQuery: Callable[[str], None],
        setSort: Callable[[str], None],
        loadRepos: Callable[[int], None];
}

def sorted_projects(projects: list[Project], query: str, sort: str) -> list[Project] {
    q = query.strip().lower();
    result = [
        p
        for p in projects
        if not q or q in (p.full + " " + p.description + " " + p.owner_username).lower()
    ];
    if sort == "stars" {
        result.sort(key=lambda (p: Project) { -p.stars; });
    } elif sort == "newest" {
        result.sort(key=lambda (p: Project) { p.added_at; }, reverse=True);
    } else {
        result.sort(key=lambda (p: Project) { (-p.score, p.full); });
    }
    return result;
}

def:pub useScores(model: JacYacState) -> Scores {
    has query: str = "",
        sort: str = "score",
        repos: list[GithubRepo] = [],
        githubLogin: str = "",
        githubLinked: bool = False,
        reposLoading: bool = False,
        reposError: str = "",
        nextPage: int = 0;
    async def loadRepos(page: int) -> None {
        if reposLoading {
            return;
        }
        reposLoading = True;
        reposError = "";
        try {
            result = await github_repositories(
                session_token=__getLocalStorage("jac_token"), page=page
            );
            githubLinked = result.linked;
            githubLogin = result.login;
            repos = repos + result.repos if page > 1 else result.repos;
            nextPage = result.next_page;
            reposError = result.error;
        } except Exception {
            reposError = "Could not load repositories. Please try again.";
        } finally {
            reposLoading = False;
        }
    }
    can with [model.session.loggedIn, model.session.busy] entry {
        if model.session.loggedIn {
            if not model.session.busy {
                loadRepos(1);
            }
        } else {
            repos = [];
            githubLogin = "";
            githubLinked = False;
        }
    }
    return Scores(
        query=query,
        sort=sort,
        projects=sorted_projects(model.allProjects, query, sort),
        repos=repos,
        githubLogin=githubLogin,
        githubLinked=githubLinked,
        reposLoading=reposLoading,
        reposError=reposError,
        nextPage=nextPage,
        setQuery=lambda (v: str) { query = v; },
        setSort=lambda (v: str) { sort = v; },
        loadRepos=loadRepos
    );
}
