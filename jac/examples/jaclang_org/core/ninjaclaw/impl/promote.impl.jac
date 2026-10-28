impl promote_config -> PromoteConfig {
    return PromoteConfig(
        upstream=os.environ.get("NINJACLAW_DOCS_REPO", "").strip(),
        fork=os.environ.get("NINJACLAW_DOCS_FORK", "").strip(),
        token=os.environ.get("NINJACLAW_GITHUB_TOKEN", "").strip(),
        base=os.environ.get("NINJACLAW_DOCS_BASE", "main").strip() or "main",
        dry_run=os.environ.get("NINJACLAW_DOCS_DRY_RUN", "").strip().lower()
            in ("1", "true", "yes"),
        min_askers=int(os.environ.get("NINJACLAW_PROMOTE_ASKERS", "3") or 3),
        min_age_days=int(os.environ.get("NINJACLAW_PROMOTE_AGE_DAYS", "7") or 7)
    );
}

impl eligible(
    candidates: list[PromoteCandidate],
    version: str,
    config: PromoteConfig,
    now: datetime
) -> PromoteCandidate | None {
    cutoff = (now - timedelta(days=config.min_age_days)).replace(
        tzinfo=None
    ).isoformat()
        + "Z";
    best: PromoteCandidate | None = None;
    for c in candidates {
        if c.status != "published" or c.pr_state or c.verified_version != version {
            continue;
        }
        if c.askers < config.min_askers or c.created_at > cutoff {
            continue;
        }
        if best is None or c.askers > best.askers {
            best = c;
        }
    }
    return best;
}

impl docs_page(c: PromoteCandidate) -> str {
    return (
        "# "
        + c.title
        + "\n\n"
        + c.summary
        + "\n\n"
        + c.body.strip()
        + "\n\n---\n\n*Written by ninjaclaw on JacYac in answer to "
        + str(c.askers)
        + " people's questions. Every example was checked on jac "
        + c.verified_version
        + ".*\n"
    );
}

impl nav_with_page(nav: dict[str, any], page: str, title: str) -> dict[str, any] {
    out = json.loads(json.dumps(nav));
    items: list[any] = out.setdefault("nav", []);
    section: dict[str, any] | None = None;
    for item in items {
        if isinstance(item, dict) and item.get("title") == SECTION_TITLE {
            section = item;
        }
    }
    if section is None {
        section = {"title": SECTION_TITLE, "items": []};
        items.append(section);
    }
    pages: list[any] = section.setdefault("items", []);
    if not any([isinstance(p, dict) and p.get("page") == page for p in pages]) {
        pages.append({"title": title, "page": page});
    }
    return out;
}

impl github(
    method: str, path: str, token: str, payload: dict[str, any] | None = None
) -> any {
    data = json.dumps(payload).encode("utf-8") if payload is not None else None;
    req = urllib.request.Request(
        API + path,
        data=data,
        method=method,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": "Bearer " + token,
            "User-Agent": "jaclang.org ninjaclaw",
            "Content-Type": "application/json"
        }
    );
    try {
        resp = urllib.request.urlopen(req, timeout=30);
        try {
            raw = resp.read();
        } finally {
            resp.close();
        }
    } except urllib.error.HTTPError as e {
        raise RuntimeError(
            method
                + " "
                + path
                + " failed: "
                + str(e.code)
                + " "
                + e.read().decode("utf-8", "replace")[:300]
        );
    }
    return json.loads(raw) if raw else {};
}

impl open_docs_pr(
    c: PromoteCandidate, config: PromoteConfig, http: Callable
) -> PrResult {
    page = "tutorials/jacyac/" + c.slug + ".md";
    if config.dry_run {
        return PrResult(
            state="dry-run",
            note="would open a docs PR adding "
                + DOCS_ROOT
                + "/"
                + page
                + " for "
                + c.slug
        );
    }
    head_repo = config.fork or config.upstream;
    head_owner = head_repo.split("/")[0];
    branch = "ninjaclaw/" + c.slug;
    existing: any = http(
        "GET",
        "/repos/"
            + config.upstream
            + "/pulls?state=open&head="
            + head_owner
            + ":"
            + branch,
        config.token,
        None
    );
    if isinstance(existing, list) and existing {
        return PrResult(
            state="open",
            url=str(existing[0]["html_url"]),
            number=int(existing[0]["number"]),
            note="picked up the docs PR an earlier attempt opened"
        );
    }
    if config.fork {
        http(
            "POST",
            "/repos/" + config.fork + "/merge-upstream",
            config.token,
            {"branch": config.base}
        );
    }
    base_ref = http(
        "GET",
        "/repos/" + config.upstream + "/git/ref/heads/" + config.base,
        config.token,
        None
    );
    base_sha = str(base_ref["object"]["sha"]);
    try {
        http(
            "POST",
            "/repos/" + head_repo + "/git/refs",
            config.token,
            {"ref": "refs/heads/" + branch, "sha": base_sha}
        );
    } except RuntimeError as e {
        if " 422 " not in str(e) {
            raise e;
        }
        http(
            "PATCH",
            "/repos/" + head_repo + "/git/refs/heads/" + branch,
            config.token,
            {"sha": base_sha, "force": True}
        );
    }

    def put(path: str, text: str, message: str, sha: str = "") {
        body: dict[str, any] = {
            "message": message,
            "content": base64.b64encode(text.encode("utf-8")).decode("ascii"),
            "branch": branch
        };
        if sha {
            body["sha"] = sha;
        }
        http("PUT", "/repos/" + head_repo + "/contents/" + path, config.token, body);
    }
    put(DOCS_ROOT + "/" + page, docs_page(c), "docs: " + c.title + " (from JacYac)");
    nav_file = http(
        "GET",
        "/repos/" + head_repo + "/contents/" + DOCS_ROOT + "/nav.json?ref=" + branch,
        config.token,
        None
    );
    nav = json.loads(base64.b64decode(nav_file["content"]).decode("utf-8"));
    put(
        DOCS_ROOT + "/nav.json",
        json.dumps(nav_with_page(nav, page, c.title), indent=2) + "\n",
        "docs: list " + c.slug + " in the nav",
        nav_file["sha"]
    );
    pr = http(
        "POST",
        "/repos/" + config.upstream + "/pulls",
        config.token,
        {
            "title": "docs: " + c.title + " (from JacYac)",
            "head": head_owner + ":" + branch,
            "base": config.base,
            "body": (
                "ninjaclaw wrote this tutorial on JacYac when no existing page answered a question, and it has since answered "
                + str(c.askers)
                + " people. Every example was compiled and run on jac "
                + c.verified_version
                + " before it was published.\n\nSource: https://jaclang.org/jacyac/tutorials/"
                + c.slug
            )
        }
    );
    number = int(pr["number"]);
    opened = PrResult(state="open", url=str(pr["html_url"]), number=number);
    try {
        put(
            "release_notes/unreleased/jaclang/" + str(number) + ".docs.md",
            "- **New tutorial, " + c.title + "**: " + c.summary + "\n",
            "release notes: " + str(number) + " docs fragment"
        );
    } except RuntimeError as e {
        opened.note = "the release fragment was not added: " + str(e)[:200];
    }
    return opened;
}

impl promote_ready(config: PromoteConfig) -> bool {
    return config.dry_run or bool(config.upstream and config.token);
}

impl pr_state(number: int, config: PromoteConfig, http: Callable) -> str {
    pr = http(
        "GET", "/repos/" + config.upstream + "/pulls/" + str(number), config.token, None
    );
    if pr.get("merged") {
        return "merged";
    }
    return "closed" if pr.get("state") == "closed" else "open";
}
