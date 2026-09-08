import json;
import from core.ai { CodeReview, CodeInsight, NextStep }

test "AI review appears in text and JSON without changing score" {
    res = sample_result();
    total = res.breakdown.total;
    res.breakdown.ai_review = CodeReview(
        summary="A typed task graph.",
        strength=CodeInsight(observation="Typed state.", evidence="app.jac: Task"),
        opportunity=NextStep(action="Test traversal.", reason="Protect behavior.")
    );
    assert "A typed task graph." in render(res);
    assert as_dict(res)["ai_review"]["strength"]["evidence"] == "app.jac: Task";
    assert as_dict(res)["total"] == total;
}

import from core.github { RepoMeta }
import from core.leaderboard.scoring { analyze, score }
import from core.timefmt { now_iso }

glob SAMPLE: dict[str, str] = {
         "app.jac": "node Task { has title: str; }\nwalker:pub add { can go with Root entry { root ++> Task(); } }\n",
         "ui.jac": "def:pub app -> JsxElement { return <div>hi</div>; }\n",
         "app.test.jac": "test \"adds\" { assert True; }\n",
         "jac.toml": "[project]\nname = \"dojo\"\n",
         "readme.md": "# dojo\n\nA sample.\n",
         "license": "MIT\n"
     };

def sample_result -> ScoreResult {
    meta = RepoMeta(
        full_name="acme/dojo",
        owner="acme",
        name="dojo",
        html_url="https://github.com/acme/dojo",
        stars=12,
        forks=3,
        topics=["jac"],
        pushed_at=now_iso()
    );
    an = analyze(SAMPLE);
    an.jac_bytes = 4000;
    an.other_code_bytes = 1000;
    return ScoreResult(
        ok=True, meta=meta, an=an, breakdown=score(meta, an), sha="abc123def456789"
    );
}

test "parse repo ref accepts slugs and github urls" {
    assert parse_repo_ref("jaseci-labs/jac") == ("jaseci-labs", "jac");
    assert parse_repo_ref("https://github.com/jaseci-labs/jac.git")
        == ("jaseci-labs", "jac");
    assert parse_repo_ref("github.com/jaseci-labs/jac/") == ("jaseci-labs", "jac");
    assert parse_repo_ref("  Jaseci-Labs/jac  ") == ("Jaseci-Labs", "jac");
}

test "parse repo ref rejects everything else" {
    assert parse_repo_ref("jac") is None;
    assert parse_repo_ref("https://gitlab.com/a/b") is None;
    assert parse_repo_ref("a/b/c") is None;
    assert parse_repo_ref("") is None;
}

test "as dict is json and mirrors the breakdown row for row" {
    res = sample_result();
    back = json.loads(json.dumps(as_dict(res)));
    assert back["repo"] == "acme/dojo";
    assert back["sha"] == "abc123def456789";
    assert back["total"] == res.breakdown.total;
    assert back["belt"] == res.breakdown.belt;
    assert back["jac_pct"] == 80;
    assert back["jac_files"] == res.an.jac_files;
    assert back["features"]["osp"];
    assert back["features"]["cl"];
    assert not back["features"]["na"];
    assert len(back["details"]) == len(res.breakdown.details);
    assert back["details"][0]["label"] == res.breakdown.details[0].label;
}

test "render names the repo the total the belt and every rubric line" {
    res = sample_result();
    out = render(res);
    assert out.startswith("acme/dojo  " + str(res.breakdown.total) + "/100  ");
    assert res.breakdown.belt + " belt" in out;
    assert "https://github.com/acme/dojo/tree/abc123def456789" in out;
    for p in res.breakdown.details {
        assert p.label in out;
    }
}

test "run score refuses a bad ref before touching the network" {
    assert run_score("not a repo", False) == EXIT_USAGE;
    assert run_score("", True) == EXIT_USAGE;
}

test "every scorer failure has a human hint" {
    for key in ["bad_ref", "not_found", "fetch_failed", "not_jac"] {
        assert len(ERROR_TEXT[key]) > 20;
    }
}
