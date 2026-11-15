impl knowledge_dir -> Path {
    configured = os.environ.get(DIR_ENV, "").strip();
    base = (
        Path(configured) if configured else Path.cwd() / ".jac" / "data" / "knowledge"
    ).resolve();
    base.mkdir(parents=True, exist_ok=True);
    return base;
}

impl repo_dir -> Path {
    return knowledge_dir() / "jac";
}

impl repo_url -> str {
    return os.environ.get(REPO_URL_ENV, "").strip() or DEFAULT_REPO_URL;
}

impl git(
    args: list[str], cwd: Path | None = None, extra_env: dict[str, str] | None = None
) -> str {
    env = dict(os.environ);
    env["GIT_TERMINAL_PROMPT"] = "0";
    env["GIT_ADVICE"] = "0";
    if extra_env {
        env.update(extra_env);
    }
    done = subprocess.run(
        ["git", "-c", "advice.detachedHead=false"] + args,
        cwd=str(cwd) if cwd else None,
        capture_output=True,
        text=True,
        timeout=GIT_TIMEOUT_S,
        env=env
    );
    if done.returncode != 0 {
        tail = (done.stderr or done.stdout or "").strip().splitlines()[-3:];
        raise RuntimeError("git " + args[0] + " failed: " + " / ".join(tail));
    }
    return done.stdout;
}

impl git_available -> bool {
    return shutil.which("git") is not None;
}

impl version_of(tag: str) -> tuple[int, int, int] | None {
    m = re.`match(r"^v?(\d+)\.(\d+)\.(\d+)$", tag.strip());
    if not m {
        return None;
    }
    return (int(m.group(1)), int(m.group(2)), int(m.group(3)));
}

impl label_of_version(version: str) -> str {
    m = re.`match(r"^v?(\d+)\.(\d+)", version.strip());
    if not m {
        return "dev";
    }
    return "v" + (m.group(1) as str) + "." + (m.group(2) as str);
}

impl release_tags -> list[str] {
    raw = git(["tag", "-l", "v*"], cwd=repo_dir());
    tags = [
        t.strip()
        for t in raw.splitlines()
        if version_of(t.strip()) is not None
    ];
    tags.sort(key=lambda (t: str) { version_of(t) or (0, 0, 0); }, reverse=True);
    return tags;
}

impl older_lines(
    serving: str, tags: list[str], count: int = OLDER_LINES
) -> list[ReleaseLine] {
    current = version_of(serving);
    newest: dict[tuple[int, int], str] = {};
    for t in tags {
        v = version_of(t);
        if v is None {
            continue;
        }
        line = (v[0], v[1]);
        if current is not None
            and (v[0] != current[0] or line >= (current[0], current[1])) {
            continue;
        }
        prior = newest.get(line);
        if prior is None or v > (version_of(prior) or (0, 0, 0)) {
            newest[line] = t;
        }
    }
    picked = sorted(newest.keys(), reverse=True)[:count];
    return [
        ReleaseLine(
            label="v" + str(line[0]) + "." + str(line[1]),
            tag=newest[line],
            version=newest[line].lstrip("v")
        ) for line in picked
    ];
}

impl checkout_target(serving: str, tags: list[str]) -> str {
    current = version_of(serving);
    if current is None {
        return "origin/HEAD";
    }
    for t in tags {
        v = version_of(t);
        if v is not None and v[0] == current[0] and v <= current {
            return t;
        }
    }
    return "origin/HEAD";
}

impl read_status -> RepoStatus {
    path = knowledge_dir() / "status.json";
    if not path.is_file() {
        return RepoStatus();
    }
    try {
        raw = json.loads(path.read_text(encoding="utf-8"));
    } except Exception {
        return RepoStatus();
    }
    return RepoStatus(
        phase=str(raw.get("phase", "idle")),
        detail=str(raw.get("detail", "")),
        serving_version=str(raw.get("serving_version", "")),
        checked_out=str(raw.get("checked_out", "")),
        lines=[
            ReleaseLine(
                label=str(l.get("label", "")),
                tag=str(l.get("tag", "")),
                version=str(l.get("version", ""))
            ) for l in raw.get("lines", [])
        ],
        fetched_at=str(raw.get("fetched_at", "")),
        updated_at=str(raw.get("updated_at", ""))
    );
}

impl write_status(status: RepoStatus) {
    status.updated_at = datetime.now(UTC).isoformat();
    path = knowledge_dir() / "status.json";
    tmp = path.with_suffix(".tmp");
    tmp.write_text(
        json.dumps(
            {
                "phase": status.phase,
                "detail": status.detail,
                "serving_version": status.serving_version,
                "checked_out": status.checked_out,
                "lines": [
                    {"label": l.label, "tag": l.tag, "version": l.version}
                    for l in status.lines
                ],
                "fetched_at": status.fetched_at,
                "updated_at": status.updated_at
            }
        ),
        encoding="utf-8"
    );
    os.replace(tmp, path);
}

impl exported_docs(line: ReleaseLine) -> Path {
    return knowledge_dir() / "releases" / line.tag / DOCS_PATH;
}

impl export_docs(line: ReleaseLine) -> Path {
    target = exported_docs(line);
    marker = target.parent / ".complete";
    if marker.is_file() {
        return target;
    }
    work = knowledge_dir() / "releases" / line.tag;
    if work.exists() {
        shutil.rmtree(work);
    }
    work.mkdir(parents=True);
    index = knowledge_dir() / ("export-" + line.tag + ".idx");
    try {
        git(
            ["--work-tree=" + str(work), "checkout", line.tag, "--", DOCS_PATH],
            cwd=repo_dir(),
            extra_env={"GIT_INDEX_FILE": str(index)}
        );
    } finally {
        if index.exists() {
            index.unlink();
        }
    }
    marker.write_text(line.tag, encoding="utf-8");
    return target;
}

impl checkout_root -> Path | None {
    status = read_status();
    if status.phase != "ready" {
        return None;
    }
    root_dir = repo_dir();
    return root_dir if (root_dir / DOCS_PATH).is_dir() else None;
}

impl ensure_repo(serving: str) -> RepoStatus {
    import fcntl;
    if not git_available() {
        status = RepoStatus(
            phase="unavailable",
            detail="git is not installed on this server",
            serving_version=serving
        );
        write_status(status);
        return status;
    }
    if not _PROCESS_LOCK.acquire(blocking=False) {
        return read_status();
    }
    lock_file = open(knowledge_dir() / "repo.lock", "w");
    try {
        try {
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB);
        } except OSError {
            return read_status();
        }
        status = read_status();
        same_release = status.serving_version == serving;
        status.serving_version = serving;
        target = repo_dir();
        fresh = not (target / ".git").is_dir();
        stale = True;
        if status.fetched_at {
            try {
                age = (
                    datetime.now(UTC) - datetime.fromisoformat(status.fetched_at)
                ).total_seconds();
                stale = age >= FETCH_EVERY_S;
            } except ValueError {
                stale = True;
            }
        }
        if not fresh
            and not stale
            and same_release
            and status.phase == "ready"
            and status.checked_out {
            return status;
        }
        try {
            if fresh {
                status.phase = "cloning";
                status.detail = "cloning " + repo_url();
                write_status(status);
                staging = knowledge_dir() / "jac.partial";
                if staging.exists() {
                    shutil.rmtree(staging);
                }
                git(
                    [
                        "clone",
                        "--filter=tree:0",
                        "--no-checkout",
                        "--sparse",
                        repo_url(),
                        str(staging)
                    ]
                );
                git(["sparse-checkout", "set"] + SPARSE_PATHS, cwd=staging);
                os.replace(staging, target);
            } else {
                status.phase = "fetching" if status.phase != "ready" else "ready";
                status.detail = "fetching new tags";
                write_status(status);
                git(["fetch", "--quiet", "--tags", "--force", "origin"], cwd=target);
            }
            tags = release_tags();
            wanted = checkout_target(serving, tags);
            if wanted != status.checked_out or fresh {
                git(["checkout", "--quiet", "--detach", wanted], cwd=target);
            }
            status.checked_out = wanted;
            status.lines = older_lines(serving, tags);
            for line in status.lines {
                export_docs(line);
            }
            status.fetched_at = datetime.now(UTC).isoformat();
            status.phase = "ready";
            status.detail = "";
        } except Exception as e {
            status.phase = "failed" if fresh or status.phase != "ready" else "ready";
            status.detail = str(e)[:400];
        }
        write_status(status);
        return status;
    } finally {
        try {
            fcntl.flock(lock_file.fileno(), fcntl.LOCK_UN);
        } except OSError {}
        lock_file.close();
        _PROCESS_LOCK.release();
    }
}
