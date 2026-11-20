import base64;
import json;
import from datetime { datetime, UTC, timedelta }

obj FakeGithub {
    has calls: list[tuple[str, str]] = [],
        puts: dict[str, str] = {},
        ref_exists: bool = False,
        open_prs: list[dict[str, any]] = [],
        fail_fragment: bool = False;

    def call(
        method: str, path: str, token: str, payload: dict[str, any] | None = None
    ) -> any;
}

impl FakeGithub.call(
    method: str, path: str, token: str, payload: dict[str, any] | None = None
) -> any {
    self.calls.append((method, path));
    if method == "GET" and "/pulls?state=open" in path {
        return self.open_prs;
    }
    if method == "PUT" and "release_notes/" in path and self.fail_fragment {
        raise RuntimeError("PUT " + path + " failed: 500 boom");
    }
    if method == "POST" and path.endswith("/git/refs") and self.ref_exists {
        raise RuntimeError("POST " + path + " failed: 422 Reference already exists");
    }
    if method == "GET" and "/git/ref/heads/" in path {
        return {"object": {"sha": "abc123"}};
    }
    if method == "GET" and "nav.json" in path {
        nav = {"nav": [{"title": "Reference", "items": []}]};
        return {
            "sha": "navsha",
            "content": base64.b64encode(json.dumps(nav).encode("utf-8")).decode("ascii")
        };
    }
    if method == "PUT" and payload is not None {
        self.puts[path] = base64.b64decode(payload["content"]).decode("utf-8");
    }
    if method == "POST" and path.endswith("/pulls") {
        return {"number": 9001, "html_url": "https://github.com/up/jac/pull/9001"};
    }
    return {};
}

def _old -> str;

def _candidate(slug: str, askers: int, pr_state: str = "") -> PromoteCandidate;

impl _old -> str {
    return (datetime.now(UTC) - timedelta(days=30)).replace(tzinfo=None).isoformat()
        + "Z";
}

impl _candidate(slug: str, askers: int, pr_state: str = "") -> PromoteCandidate {
    return PromoteCandidate(
        slug=slug,
        title="Title " + slug,
        summary="Summary.",
        body="```jac\nwith entry { print(1); }\n```",
        askers=askers,
        created_at=_old(),
        verified_version="0.38.0",
        status="published",
        pr_state=pr_state
    );
}

test "only well-asked, aged, verified tutorials without a PR are eligible" {
    config = PromoteConfig(min_askers=3, min_age_days=7);
    now = datetime.now(UTC);
    fresh = _candidate("fresh", 9);
    fresh.created_at = now.replace(tzinfo=None).isoformat() + "Z";
    stale = _candidate("stale", 9);
    stale.status = "stale";
    old_version = _candidate("older", 9);
    old_version.verified_version = "0.37.0";
    pool = [
        _candidate("few", 2),
        fresh,
        stale,
        old_version,
        _candidate("rejected", 9, "closed"),
        _candidate("good", 4),
        _candidate("better", 6)
    ];
    pick = eligible(pool, "0.38.0", config, now);
    assert pick is not None and pick.slug == "better";
    assert eligible(pool[:5], "0.38.0", config, now) is None;
}

test "nav gains one tutorials section entry, idempotently" {
    nav = {"nav": [{"title": "Reference", "items": []}]};
    once = nav_with_page(nav, "tutorials/jacyac/x.md", "X");
    twice = nav_with_page(once, "tutorials/jacyac/x.md", "X");
    assert once == twice;
    assert nav == {"nav": [{"title": "Reference", "items": []}]};
    section = twice["nav"][-1];
    assert section["title"] == SECTION_TITLE;
    assert section["items"] == [{"title": "X", "page": "tutorials/jacyac/x.md"}];
}

test "dry run touches nothing" {
    fake = FakeGithub();
    out = open_docs_pr(
        _candidate("dry", 5), PromoteConfig(dry_run=True, upstream="up/jac"), fake.call
    );
    assert out.state == "dry-run" and "dry" in out.note;
    assert fake.calls == [];
}

test "a docs PR adds the page, the nav entry and a release fragment" {
    fake = FakeGithub();
    config = PromoteConfig(upstream="up/jac", fork="me/jac", token="t");
    out = open_docs_pr(_candidate("walkers", 5), config, fake.call);
    assert out.state == "open" and out.number == 9001;
    page = "/repos/me/jac/contents/" + DOCS_ROOT + "/tutorials/jacyac/walkers.md";
    assert page in fake.puts and fake.puts[page].startswith("# Title walkers");
    nav = json.loads(fake.puts["/repos/me/jac/contents/" + DOCS_ROOT + "/nav.json"]);
    assert nav["nav"][-1]["items"][0]["page"] == "tutorials/jacyac/walkers.md";
    assert "/repos/me/jac/contents/release_notes/unreleased/jaclang/9001.docs.md"
        in fake.puts;
    assert ("POST", "/repos/up/jac/pulls") in fake.calls;
}

test "a leftover branch from a failed attempt is reset, not an error" {
    fake = FakeGithub(ref_exists=True);
    config = PromoteConfig(upstream="up/jac", token="t");
    out = open_docs_pr(_candidate("again", 5), config, fake.call);
    assert out.state == "open";
    assert ("PATCH", "/repos/up/jac/git/refs/heads/ninjaclaw/again") in fake.calls;
}

test "merged and closed PRs are told apart" {
    config = PromoteConfig(upstream="up/jac", token="t");
    assert pr_state(
        1, config, lambda (m: str, p: str, t: str, b: any) { {"merged": True}; }
    )
        == "merged";
    assert pr_state(
        1,
        config,
        lambda (m: str, p: str, t: str, b: any) { {
            "merged": False,
            "state": "closed"
        }; }
    )
        == "closed";
}

test "an open PR from an earlier attempt is picked up instead of opened again" {
    fake = FakeGithub(
        open_prs=[{"number": 77, "html_url": "https://github.com/up/jac/pull/77"}]
    );
    out = open_docs_pr(
        _candidate("again", 5), PromoteConfig(upstream="up/jac", token="t"), fake.call
    );
    assert out.state == "open" and out.number == 77;
    assert not any([m == "POST" for (m, p) in fake.calls]);
}

test "a failed release fragment keeps the PR that was opened" {
    fake = FakeGithub(fail_fragment=True);
    out = open_docs_pr(
        _candidate("frag", 5), PromoteConfig(upstream="up/jac", token="t"), fake.call
    );
    assert out.state == "open" and out.number == 9001;
    assert "release fragment" in out.note;
}
