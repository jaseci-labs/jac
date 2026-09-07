import re;
import io;
import os;
import tarfile;
import time;
import urllib.error;
import urllib.request;

impl headers(agent: str, accept_json: bool = True) -> dict[str, str] {
    h: dict[str, str] = {"User-Agent": agent};
    if accept_json {
        h["Accept"] = "application/vnd.github+json";
    }
    tok = os.environ.get("GITHUB_TOKEN", "");
    if tok {
        h["Authorization"] = "Bearer " + tok;
    }
    return h;
}

impl fetch(
    url: str, agent: str, accept_json: bool = False, timeout: int = 10
) -> bytes | None {
    for attempt in range(3) {
        if attempt > 0 {
            time.sleep(0.5 * attempt);
        }
        try {
            req = urllib.request.Request(url, headers=headers(agent, accept_json));
            resp = urllib.request.urlopen(req, timeout=timeout);
            try {
                return resp.read();
            } finally {
                resp.close();
            }
        } except urllib.error.HTTPError as e {
            if e.code < 500 {
                return None;
            }
        } except Exception {}
    }
    return None;
}

impl parse_repo_url(url: str) -> tuple[str, str] | None {
    u = url.strip().rstrip("/");
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

def _api_bytes(url: str, agent: str) -> bytes {
    data = fetch(url, agent, accept_json=True);
    if data is None {
        raise RuntimeError("GitHub is unavailable or rate limited");
    }
    return data;
}

impl repo_meta(repo: str, agent: str) -> RepoMeta | None {
    raw = JsonEndpoint[GithubRepository](GithubRepository, API_ROOT + repo).read(
        lambda (url: str) -> bytes { return _api_bytes(url, agent); }
    );
    if raw.private {
        return None;
    }
    return RepoMeta(
        full_name=raw.full_name,
        owner=raw.owner.login,
        name=raw.name,
        description=(raw.description or "")[:220],
        avatar_url=raw.owner.avatar_url,
        html_url=raw.html_url,
        default_branch=raw.default_branch,
        stars=raw.stargazers_count,
        forks=raw.forks_count,
        size_kb=raw.size,
        topics=raw.topics[:6],
        pushed_at=raw.pushed_at or "",
        created_at=raw.created_at
    );
}

impl head_sha(repo: str, ref: str, agent: str) -> str {
    result = JsonEndpoint[GithubCommit](
        GithubCommit, API_ROOT + repo + "/commits/" + ref
    ).read(
        lambda (url: str) -> bytes { return _api_bytes(url, agent); }
    );
    return result.sha;
}

impl download_tarball(
    repo: str,
    ref: str,
    agent: str,
    max_bytes: int = 0,
    on_bytes: Callable[[int], None] | None = None
) -> bytes | None {
    url = CODELOAD_ROOT + repo + "/tar.gz/" + ref;
    for attempt in range(2) {
        if attempt > 0 {
            time.sleep(1.0);
        }
        try {
            req = urllib.request.Request(url, headers={"User-Agent": agent});
            resp = urllib.request.urlopen(req, timeout=60);
            chunks: list[bytes] = [];
            got = 0;
            try {
                while True {
                    chunk = resp.read(CHUNK_BYTES);
                    if not chunk {
                        break;
                    }
                    got += len(chunk);
                    if max_bytes > 0 and got > max_bytes {
                        return None;
                    }
                    chunks.append(chunk);
                    if on_bytes is not None {
                        on_bytes(got);
                    }
                }
            } finally {
                resp.close();
            }
            return bytes().join(chunks);
        } except urllib.error.HTTPError as e {
            if e.code < 500 {
                return None;
            }
        } except Exception {}
    }
    return None;
}

impl _wanted(
    rel: str,
    prefixes: list[str] | None,
    suffixes: list[str] | None,
    names: list[str] | None
) -> bool {
    if prefixes is None and suffixes is None and names is None {
        return True;
    }
    low = rel.lower();
    if prefixes is not None {
        for p in prefixes {
            if low.startswith(p) {
                return True;
            }
        }
    }
    if suffixes is not None {
        for s in suffixes {
            if low.endswith(s) {
                return True;
            }
        }
    }
    if names is not None {
        for n in names {
            if low == n {
                return True;
            }
        }
    }
    return False;
}

impl untar(
    data: bytes,
    prefixes: list[str] | None = None,
    suffixes: list[str] | None = None,
    names: list[str] | None = None,
    max_member_bytes: int = 0
) -> dict[str, bytes] {
    out: dict[str, bytes] = {};
    tf = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz");
    for m in tf.getmembers() {
        if not m.isfile() {
            continue;
        }
        if max_member_bytes > 0 and m.size > max_member_bytes {
            continue;
        }
        segs = m.name.split("/", 1);
        if len(segs) < 2 {
            continue;
        }
        rel = segs[1] as str;
        if not _wanted(rel, prefixes, suffixes, names) {
            continue;
        }
        fh = tf.extractfile(m);
        if fh is not None {
            out[rel] = fh.read();
        }
    }
    return out;
}

glob PROG_EXTS: set[str] = {
         ".py",
         ".ipynb",
         ".js",
         ".mjs",
         ".cjs",
         ".ts",
         ".tsx",
         ".jsx",
         ".java",
         ".c",
         ".cc",
         ".cpp",
         ".cxx",
         ".h",
         ".hh",
         ".hpp",
         ".go",
         ".rs",
         ".rb",
         ".php",
         ".swift",
         ".kt",
         ".kts",
         ".cs",
         ".scala",
         ".dart",
         ".lua",
         ".r",
         ".jl",
         ".zig",
         ".m",
         ".mm",
         ".pl",
         ".ex",
         ".exs",
         ".erl",
         ".hs",
         ".ml",
         ".clj",
         ".vue",
         ".svelte"
     },
     SKIP_SEGS: set[str] = {
         "node_modules",
         ".venv",
         "venv",
         "__pycache__",
         ".jac",
         "dist",
         "build",
         "vendor",
         "third_party"
     };

impl code_breakdown(data: bytes) -> tuple[int, int] {
    jac_bytes = 0;
    other_bytes = 0;
    tf = tarfile.open(fileobj=io.BytesIO(data), mode="r:gz");
    for m in tf.getmembers() {
        if not m.isfile() {
            continue;
        }
        segs = m.name.split("/");
        if len(segs) < 2 {
            continue;
        }
        rel_segs = segs[1:];
        skipped = False;
        for seg in rel_segs[:-1] {
            if seg.lower() in SKIP_SEGS {
                skipped = True;
                break;
            }
        }
        if skipped {
            continue;
        }
        low = rel_segs[-1].lower();
        dot = low.rfind(".");
        if dot < 0 {
            continue;
        }
        ext = low[dot:];
        if ext == ".jac" {
            jac_bytes += m.size;
        } elif ext in PROG_EXTS {
            other_bytes += m.size;
        }
    }
    return (jac_bytes, other_bytes);
}

impl text_of(blob: bytes) -> str {
    return blob.decode("utf-8", errors="replace");
}

impl mb_of(byte_count: int) -> str {
    return str(round(byte_count / 1048576.0, 1)) + " MB";
}
