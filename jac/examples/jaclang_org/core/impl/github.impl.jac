import re;

import os;

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
