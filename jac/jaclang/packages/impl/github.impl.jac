impl find_token -> str {
    for name in TOKEN_ENVS {
        value = os.environ.get(name, "").strip();
        if value {
            return value;
        }
    }
    try {
        done = subprocess.run(
            ["gh", "auth", "token"], capture_output=True, text=True, check=False
        );
        if done.returncode == 0 and done.stdout.strip() {
            return done.stdout.strip();
        }
    } except FileNotFoundError {}
    return "";
}

impl GitHub.from_env -> GitHub {
    token = find_token();
    if not token {
        raise GitHubError(
            "publishing needs a GitHub token: set GITHUB_TOKEN (or GH_TOKEN), "
            "or sign in with 'gh auth login'"
        );
    }
    return GitHub(token=token);
}

impl GitHub.call(
    method: str,
    url: str,
    body: dict[str, any] | None = None,
    data: bytes | None = None,
    content_type: str = "application/json",
    allow_missing: bool = False
) -> any {
    payload = data
        if data is not None
        else (json.dumps(body).encode("utf-8") if body is not None else None);
    request = urllib.request.Request(
        url if url.startswith("http") else self.api + url,
        data=payload,
        method=method,
        headers={
            "Authorization": f"Bearer {self.token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "jac-publish",
            "Content-Type": content_type
        }
    );
    try {
        with urllib.request.urlopen(request, timeout=120) as response {
            raw = response.read();
        }
    } except urllib.error.HTTPError as e {
        if allow_missing and e.code == 404 {
            return None;
        }
        detail = e.read().decode("utf-8", errors="replace")[:500];
        raise GitHubError(f"GitHub {method} {url} failed ({e.code}): {detail}");
    } except urllib.error.URLError as e {
        raise GitHubError(f"GitHub {method} {url} failed: {e.reason}");
    }
    return json.loads(raw.decode("utf-8")) if raw else {};
}

impl GitHub.login -> str {
    return str(self.call("GET", "/user")["login"]);
}

impl GitHub.ensure_fork(repo: str, login: str) -> str {
    name = repo.split("/", 1)[1];
    fork = f"{login}/{name}";
    if self.call("GET", f"/repos/{fork}", allow_missing=True) is not None {
        return fork;
    }
    self.call("POST", f"/repos/{repo}/forks", body={});
    for _ in range(30) {
        if self.call("GET", f"/repos/{fork}", allow_missing=True) is not None {
            return fork;
        }
        time.sleep(2);
    }
    raise GitHubError(f"GitHub did not finish forking {repo} into {fork}");
}

impl GitHub.branch_sha(repo: str, branch: str) -> str {
    ref = self.call("GET", f"/repos/{repo}/git/ref/heads/{quote(branch)}");
    return str(ref["object"]["sha"]);
}

impl GitHub.create_branch(repo: str, branch: str, sha: str) {
    existing = self.call(
        "GET", f"/repos/{repo}/git/ref/heads/{quote(branch)}", allow_missing=True
    );
    if existing is not None {
        self.call(
            "PATCH",
            f"/repos/{repo}/git/refs/heads/{quote(branch)}",
            body={"sha": sha, "force": True}
        );
        return;
    }
    self.call(
        "POST",
        f"/repos/{repo}/git/refs",
        body={"ref": f"refs/heads/{branch}", "sha": sha}
    );
}

impl GitHub.read_file(repo: str, path: str, ref: str) -> tuple[str | None, str | None] {
    found = self.call(
        "GET", f"/repos/{repo}/contents/{path}?ref={quote(ref)}", allow_missing=True
    );
    if found is None {
        return (None, None);
    }
    text = base64.b64decode(str(found.get("content", ""))).decode("utf-8");
    return (text, str(found.get("sha", "")));
}

impl GitHub.write_file(
    repo: str, path: str, branch: str, text: str, message: str, sha: str | None
) {
    body: dict[str, any] = {
        "message": message,
        "content": base64.b64encode(text.encode("utf-8")).decode("ascii"),
        "branch": branch
    };
    if sha {
        body["sha"] = sha;
    }
    self.call("PUT", f"/repos/{repo}/contents/{path}", body=body);
}

impl GitHub.release_for(repo: str, tag: str, target: str) -> dict[str, any] {
    found = self.call(
        "GET", f"/repos/{repo}/releases/tags/{quote(tag)}", allow_missing=True
    );
    if found is not None {
        return found;
    }
    return self.call(
        "POST",
        f"/repos/{repo}/releases",
        body={"tag_name": tag, "name": tag, "target_commitish": target}
    );
}

impl GitHub.upload_asset(release: dict[str, any], name: str, data: bytes) -> str {
    for asset in release.get("assets", []) {
        if asset.get("name") == name {
            return str(asset["browser_download_url"]);
        }
    }
    rel_id = release["id"];
    repo_url = str(release["url"]).split("/releases/")[0].replace(self.api, "");
    uploaded = self.call(
        "POST",
        f"{self.uploads}{repo_url}/releases/{rel_id}/assets?name={quote(name)}",
        data=data,
        content_type="application/octet-stream"
    );
    return str(uploaded["browser_download_url"]);
}

impl GitHub.open_pull(repo: str, head: str, base: str, title: str, body: str) -> str {
    pr = self.call(
        "POST",
        f"/repos/{repo}/pulls",
        body={"title": title, "head": head, "base": base, "body": body}
    );
    return str(pr["html_url"]);
}
