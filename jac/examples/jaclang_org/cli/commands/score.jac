import json;
import re;
import from core.ai { optional_review }
import from core.github {
    RepoMeta,
    code_breakdown,
    download_tarball,
    head_sha,
    mb_of,
    repo_meta,
    text_of,
    untar
}
import from core.leaderboard.scoring { RepoAnalysis, ScoreBreakdown, analyze, score }
import from .common { EXIT_FAILURE, EXIT_OK, EXIT_USAGE, warn }

glob USER_AGENT: str = "jaclang.org cli scorer",
     MAX_TAR_BYTES: int = 52428800,
     MAX_MEMBER_BYTES: int = 2097152;

glob ERROR_TEXT: dict[str, str] = {
         "bad_ref": "expected owner/name or a github.com URL",
         "not_found": "GitHub knows no such repo (a private repo and a rate limit look the same; set GITHUB_TOKEN)",
         "fetch_failed": "could not download the default-branch tarball (over 50 MB, or GitHub is unreachable)",
         "not_jac": "no .jac files on the default branch, so there is nothing to score"
     };

obj ScoreResult {
    has ok: bool = False,
        error: str = "",
        meta: RepoMeta = RepoMeta(),
        an: RepoAnalysis = RepoAnalysis(),
        breakdown: ScoreBreakdown = ScoreBreakdown(),
        sha: str = "";
}

def parse_repo_ref(text: str) -> tuple[str, str] | None {
    u = text.strip().rstrip("/");
    m = re.`match(
        r"^(?:https?://)?(?:www\.)?github\.com/([\w.\-]+)/([\w.\-]+?)(?:\.git)?$", u
    );
    if m is None {
        m = re.`match(r"^([\w.\-]+)/([\w.\-]+)$", u);
    }
    if m is None {
        return None;
    }
    return (m.group(1) as str, m.group(2) as str);
}

def score_repo(owner: str, name: str, quiet: bool = False) -> ScoreResult {
    def say(note: str) {
        if not quiet {
            warn(note);
        }
    }
    meta = repo_meta(owner + "/" + name, USER_AGENT);
    if meta is None {
        return ScoreResult(error="not_found");
    }
    full = (meta.owner or owner) + "/" + (meta.name or name);
    sha = head_sha(full, meta.default_branch, USER_AGENT);
    ref = sha if sha != "" else meta.default_branch;
    say("fetching " + full + " @ " + ref[:12]);
    blob = download_tarball(full, ref, USER_AGENT, max_bytes=MAX_TAR_BYTES);
    if blob is None {
        return ScoreResult(error="fetch_failed", meta=meta);
    }
    say("unpacked " + mb_of(len(blob)) + ", analyzing");
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
        return ScoreResult(error="not_jac", meta=meta);
    }
    breakdown = score(meta, an);
    breakdown.ai_review = optional_review(files);
    return ScoreResult(ok=True, meta=meta, an=an, breakdown=breakdown, sha=sha);
}

def as_dict(res: ScoreResult) -> dict[str, object] {
    sc = res.breakdown;
    an = res.an;
    meta = res.meta;
    return {
        "repo": meta.full_name,
        "url": meta.html_url,
        "sha": res.sha,
        "stars": meta.stars,
        "forks": meta.forks,
        "topics": meta.topics,
        "pushed_at": meta.pushed_at,
        "jac_files": an.jac_files,
        "jac_lines": an.jac_lines,
        "jac_pct": an.jac_pct(),
        "features": {
            "osp": an.features.osp,
            "ai": an.features.ai,
            "cl": an.features.cl,
            "sv": an.features.sv,
            "na": an.features.na,
            "tests": an.features.tests
        },
        "readme": an.readme,
        "toml": an.toml,
        "license": an.license,
        "ci": an.ci,
        "docs": an.docs,
        "total": sc.total,
        "belt": sc.belt,
        "substance": sc.substance,
        "breadth": sc.breadth,
        "craft": sc.craft,
        "community": sc.community,
        "ai_review": {
            "summary": sc.ai_review.summary,
            "strength": {
                "observation": sc.ai_review.strength.observation,
                "evidence": sc.ai_review.strength.evidence
            },
            "opportunity": {
                "action": sc.ai_review.opportunity.action,
                "reason": sc.ai_review.opportunity.reason
            }
        }
            if sc.ai_review
            else None,
        "details": [
            {
                "category": p.category,
                "label": p.label,
                "pts": p.pts,
                "max": p.max,
                "note": p.note
            } for p in sc.details
        ]
    };
}

def render(res: ScoreResult) -> str {
    sc = res.breakdown;
    an = res.an;
    meta = res.meta;
    lines: list[str] = [
        meta.full_name + "  " + str(sc.total) + "/100  " + sc.belt + " belt",
        "  substance "
            + str(sc.substance)
            + "/30 · breadth "
            + str(sc.breadth)
            + "/30 · craft "
            + str(sc.craft)
            + "/20 · community "
            + str(sc.community)
            + "/20",
        "  "
            + str(an.jac_files)
            + " jac files · "
            + str(an.jac_lines)
            + " lines · "
            + str(an.jac_pct())
            + "% jac · "
            + str(meta.stars)
            + " stars · "
            + str(meta.forks)
            + " forks"
    ];
    if res.sha and meta.html_url {
        lines.append("  scored at " + meta.html_url + "/tree/" + res.sha);
    }
    lines.append("");
    for p in sc.details {
        lines.append(
            f"  {p.category:<10} {p.label:<26} {p.pts:>5.1f} / {p.max:<4.0f} {p.note}"
        );
    }
    if sc.ai_review {
        lines.append("\n  AI code review · sampled files");
        lines.append("  " + sc.ai_review.summary);
        lines.append("  Strength: " + sc.ai_review.strength.observation);
        lines.append("  Evidence: " + sc.ai_review.strength.evidence);
        lines.append("  Next step: " + sc.ai_review.opportunity.action);
        lines.append("  " + sc.ai_review.opportunity.reason);
    }
    return "\n".join(lines);
}

def run_score(repo: str, as_json: bool) -> int {
    parsed = parse_repo_ref(repo);
    if parsed is None {
        warn("jacorg score: " + ERROR_TEXT["bad_ref"] + ": " + repo);
        return EXIT_USAGE;
    }
    res = score_repo(parsed[0], parsed[1], quiet=as_json);
    if not res.ok {
        hint = ERROR_TEXT.get(res.error, res.error);
        if as_json {
            print(json.dumps({"ok": False, "error": res.error, "hint": hint}));
        } else {
            warn("jacorg score: " + hint);
        }
        return EXIT_FAILURE;
    }
    if as_json {
        print(json.dumps(as_dict(res), indent=2));
    } else {
        print(render(res));
    }
    return EXIT_OK;
}
