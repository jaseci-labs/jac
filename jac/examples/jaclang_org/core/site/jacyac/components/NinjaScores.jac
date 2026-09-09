import from core.jacyac.state { JacYacState }
import from core.jacyac.scores { useScores }
import from core.site.ui.button { Button }
import from core.site.ui.input { Input }
import from .ProjectCard { ProjectCard }
import from core.site.leaderboard.Methodology { Methodology }

def:pub NinjaScores(model: JacYacState) -> JsxElement {
    scores = useScores(model);
    has url: str = "";
    async def submit(e: FormEvent) {
        e.preventDefault();
        if await model.handleAddProject(url) {
            url = "";
        }
    }
    return
        <section aria-label="Ninja Scores">
            <div className="border-b border-border p-5">
                <p className="mt-2 text-muted-foreground">
                    Discover what the JacYac community is building. Public repositories, scored from their code.
                </p>
                {if model.session.loggedIn {
                    <div>
                        <form onSubmit={submit} className="mt-5 flex gap-2">
                            <Input
                                aria-label="GitHub repository URL"
                                placeholder="github.com/owner/repo"
                                value={url}
                                disabled={model.projectBusy}
                                onChange={lambda (e: ChangeEvent) { url = e.target.value; }}
                            />
                            <Button
                                type="submit"
                                disabled={model.projectBusy or not url.strip()}
                            >
                                {"Scoring…" if model.projectBusy else "Add project"}
                            </Button>
                        </form>
                        <p className="mt-2 text-xs text-muted-foreground">
                            Added projects appear publicly under your JacYac profile.
                        </p>
                        {if model.session.githubEnabled and not scores.githubLinked {
                            <Button
                                className="mt-4"
                                variant="outline"
                                onClick={model.session.githubLogin}
                                disabled={model.session.busy}
                            >
                                Connect GitHub to choose your repositories
                            </Button>
                        }}
                        {if scores.githubLinked {
                            <details
                                className="mt-4 rounded-lg border border-border p-3"
                            >
                                <summary className="cursor-pointer font-semibold">
                                    Choose a public repository {"· @"
                                        + scores.githubLogin
                                        if scores.githubLogin
                                        else ""}
                                </summary>
                                {for repo in scores.repos {
                                    <div
                                        key={repo.full}
                                        className="flex items-center justify-between gap-3 border-b border-border py-3"
                                    >
                                        <span className="min-w-0 truncate text-sm">
                                            {repo.full}
                                        </span>
                                        <Button
                                            size="sm"
                                            variant="outline"
                                            disabled={model.projectBusy}
                                            onClick={lambda { model.handleAddProject(
                                                repo.url
                                            ); }}
                                        >
                                            Add
                                        </Button>
                                    </div>
                                }}
                                {if scores.nextPage {
                                    <Button
                                        variant="ghost"
                                        disabled={scores.reposLoading}
                                        onClick={lambda { scores.loadRepos(
                                            scores.nextPage
                                        ); }}
                                    >
                                        Load more
                                    </Button>
                                }}
                                {if not scores.reposLoading
                                    and not scores.repos
                                    and not scores.reposError {
                                    <p className="py-3 text-sm text-muted-foreground">
                                        No public repositories found.
                                    </p>
                                }}
                            </details>
                        }}
                        {if scores.reposError {
                            <p role="alert" className="mt-3 text-sm text-destructive">
                                {scores.reposError}
                                <Button
                                    variant="ghost"
                                    onClick={lambda { scores.loadRepos(1); }}
                                >
                                    Retry
                                </Button>
                            </p>
                        }}
                        {if model.projectError or model.session.error {
                            <p role="alert" className="mt-3 text-sm text-destructive">
                                {model.projectError or model.session.error}
                            </p>
                        }}
                        {if model.projectNotice {
                            <p role="status" className="mt-3 text-sm">
                                {model.projectNotice}
                            </p>
                        }}
                    </div>
                } else {
                    <Button
                        className="mt-4"
                        onClick={lambda { model.navigate("feed"); }}
                    >
                        Sign in to add your project
                    </Button>
                } }
            </div>
            <div className="flex flex-wrap gap-2 p-4">
                <Input
                    className="min-w-40 flex-1"
                    aria-label="Search Ninja Scores"
                    placeholder="Search repositories or people"
                    value={scores.query}
                    onChange={lambda (e: ChangeEvent) { scores.setQuery(
                        e.target.value
                    ); }}
                />
                {for option in [
                    ["score", "Top"],
                    ["newest", "New"],
                    ["stars", "Stars"]
                ] {
                    <Button
                        key={option[0]}
                        variant={"default" if scores.sort == option[0] else "outline"}
                        onClick={lambda { scores.setSort(option[0]); }}
                    >
                        {option[1]}
                    </Button>
                }}
            </div>
            {if model.projectsLoading {
                <p role="status" className="p-6 text-muted-foreground">
                    Loading projects…
                </p>
            } elif not scores.projects {
                <p className="p-6 text-muted-foreground">
                    {"No matching projects."
                        if scores.query
                        else "Be the first to add a project to JacYac."}
                </p>
            } }
            {for project in scores.projects {
                <ProjectCard
                    key={jid(project)}
                    project={project}
                    isMine={bool(
                        model.myProfile
                            and project.owner_username
                                == model.myProfile.profile.username
                    )}
                    showOwner={True}
                    avatars={model.avatars}
                    busy={model.projectBusy}
                    onRemove={model.handleRemoveProject}
                    onRescore={model.handleRescoreProject}
                    onViewOwner={model.handleViewProfile}
                />
            }}
            <details className="m-5 rounded-lg border border-border p-4">
                <summary className="cursor-pointer font-semibold">
                    How Ninja Scores are calculated
                </summary>
                <Methodology/>
            </details>
        </section>;
}
