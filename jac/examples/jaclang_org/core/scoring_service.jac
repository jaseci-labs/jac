import os;
import from core.ai { optional_review }
import from core.github {
    RepoMeta,
    code_breakdown,
    download_tarball,
    head_sha,
    repo_meta,
    text_of,
    untar
}
import from core.leaderboard.scoring { RepoAnalysis, ScoreBreakdown, analyze, score }

glob USER_AGENT: str = "jaclang.org ninja leaderboard",
     MAX_TAR_BYTES: int = 52428800,
     MAX_MEMBER_BYTES: int = 2097152;

obj ScoredPayload {
    has ok: bool = False,
        error: str = "",
        meta: RepoMeta = RepoMeta(),
        an: RepoAnalysis = RepoAnalysis(),
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        sha: str = "",
        service_pid: int = 0;
}

def:pub fetch_and_score(owner: str, name: str) -> ScoredPayload {
    pid = os.getpid();
    meta = repo_meta(owner + "/" + name, USER_AGENT);
    if meta is None {
        return ScoredPayload(error="not_found", service_pid=pid);
    }
    real_owner = meta.owner or owner;
    real_name = meta.name or name;
    sha = head_sha(real_owner + "/" + real_name, meta.default_branch, USER_AGENT);
    ref = sha if sha != "" else meta.default_branch;
    blob = download_tarball(
        real_owner + "/" + real_name, ref, USER_AGENT, max_bytes=MAX_TAR_BYTES
    );
    if blob is None {
        return ScoredPayload(error="fetch_failed", meta=meta, service_pid=pid);
    }
    members = untar(
        blob,
        prefixes=[".github/workflows/", "docs/"],
        suffixes=[".jac", "jac.toml"],
        names=["readme.md", "license", "license.md", "license.txt"],
        max_member_bytes=MAX_MEMBER_BYTES
    );
    files: dict[str, str] = {};
    for rel in members.keys() {
        files[rel] = text_of(members[rel]);
    }
    an = analyze(files);
    stats = code_breakdown(blob);
    an.jac_bytes = stats[0];
    an.other_code_bytes = stats[1];
    if an.jac_files == 0 {
        return ScoredPayload(error="not_jac", meta=meta, service_pid=pid);
    }
    breakdown = score(meta, an);
    breakdown.ai_review = optional_review(files);
    return ScoredPayload(
        ok=True, meta=meta, an=an, breakdown=breakdown, sha=sha, service_pid=pid
    );
}
