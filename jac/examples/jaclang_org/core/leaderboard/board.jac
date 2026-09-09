import from core.github { parse_repo_url }
import from core.leaderboard.scoring { RepoFeatures, ScoreBreakdown }

node BoardHub {
    has created_at: str = "";
}

node RepoEntry {
    has full: str = "",
        owner: str = "",
        name: str = "",
        description: str = "",
        avatar_url: str = "",
        html_url: str = "",
        stars: int = 0,
        forks: int = 0,
        topics: list[str] = [],
        pushed_at: str = "",
        created_at: str = "",
        jac_files: int = 0,
        jac_lines: int = 0,
        jac_pct: int = 0,
        features: RepoFeatures = RepoFeatures(),
        score: int = 0,
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        belt: str = "white",
        scored_sha: str = "",
        scored_by_pid: int = 0,
        submitted_at: str = "",
        scored_at: str = "";
}

edge OnBoard {}
