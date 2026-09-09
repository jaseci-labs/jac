import from core.github { RepoMeta }
import from core.timefmt { now_iso }

glob SAMPLE: dict[str, str] = {
         "app.jac": "node Task { has title: str; }\nwalker:pub add { can go with Root entry { root ++> Task(); } }\n",
         "ui.jac": "def:pub app -> JsxElement { return <div>hi</div>; }\n",
         "brain.jac": "def rank(t: str) -> int by llm();\n",
         "fast.na.jac": "def hot(n: i32) -> i32 { return n * 2; }\n",
         "app.test.jac": "test \"adds two numbers\" { assert True; }\n",
         "jac.toml": "[project]\nname = \"x\"\n",
         "readme.md": "# x\n",
         "license": "MIT\n",
         ".github/workflows/ci.yml": "on: push\n",
         "docs/index.md": "# docs\n"
     };

test "analyze_detects_every_codespace" {
    an = analyze(SAMPLE);
    assert an.jac_files == 5;
    assert an.features.osp;
    assert an.features.ai;
    assert an.features.cl;
    assert an.features.sv;
    assert an.features.na;
    assert an.features.tests;
    assert an.toml;
    assert an.readme;
    assert an.license;
    assert an.ci;
    assert an.docs;
}

test "analyze_ignores_non_jac_for_line_counts" {
    an = analyze({"readme.md": "a\nb\nc\n"});
    assert an.jac_files == 0;
    assert an.jac_lines == 0;
    assert an.readme;
    assert not an.features.osp;
}

test "belt_thresholds_are_monotonic" {
    assert belt_for(0) == "white";
    assert belt_for(19) == "white";
    assert belt_for(20) == "yellow";
    assert belt_for(35) == "orange";
    assert belt_for(50) == "green";
    assert belt_for(65) == "brown";
    assert belt_for(80) == "black";
    assert belt_for(100) == "black";
}

test "score_is_bounded_by_the_rubric" {
    meta = RepoMeta(
        full_name="a/b",
        stars=100000,
        forks=100000,
        size_kb=1,
        topics=["jac"],
        pushed_at=now_iso()
    );
    an = analyze(SAMPLE);
    an.jac_bytes = 100000;
    an.other_code_bytes = 0;
    sc = score(meta, an);
    assert sc.substance <= 30;
    assert sc.breadth <= 30;
    assert sc.craft <= 20;
    assert sc.community <= 20;
    assert sc.total <= 100;
    assert sc.belt == belt_for(sc.total);
}

test "jac_share_is_a_major_substance_factor" {
    meta = RepoMeta(full_name="a/b", size_kb=100);
    pure = analyze(SAMPLE);
    pure.jac_bytes = 9000;
    pure.other_code_bytes = 0;
    wrapper = analyze(SAMPLE);
    wrapper.jac_bytes = 900;
    wrapper.other_code_bytes = 8100;
    assert pure.jac_pct() == 100;
    assert wrapper.jac_pct() == 10;
    gap = score(meta, pure).substance - score(meta, wrapper).substance;
    assert gap >= 10;
}

test "jac_pct_handles_empty_and_jac_only" {
    empty = RepoAnalysis();
    assert empty.jac_pct() == 0;
    jac_only = RepoAnalysis(jac_files=3, jac_bytes=0, other_code_bytes=0);
    assert jac_only.jac_pct() == 100;
}

test "score_details_cover_every_category_and_sum_up" {
    meta = RepoMeta(
        full_name="a/b",
        stars=50,
        forks=5,
        size_kb=10,
        topics=["jac"],
        pushed_at=now_iso()
    );
    an = analyze(SAMPLE);
    an.jac_bytes = 5000;
    an.other_code_bytes = 5000;
    sc = score(meta, an);
    assert len(sc.details) >= 14;
    for cat in ["substance", "breadth", "craft", "community"] {
        parts = [
            p
            for p in sc.details
            if p.category == cat
        ];
        assert len(parts) > 0;
        got = sum([p.pts for p in parts]);
        want = {
            "substance": sc.substance,
            "breadth": sc.breadth,
            "craft": sc.craft,
            "community": sc.community
        }[cat];
        assert got + 0.6 >= want;
        assert got - want <= 2.5;
        for p in parts {
            assert p.pts <= p.max + 0.001;
        }
    }
}

test "score_rewards_codespace_breadth" {
    meta = RepoMeta(full_name="a/b", size_kb=10);
    lean = analyze({"a.jac": "def f -> int { return 1; }\n"});
    rich = analyze(SAMPLE);
    assert score(meta, rich).breadth > score(meta, lean).breadth;
}

test "empty_repo_scores_zero_jac" {
    an = analyze({});
    assert an.jac_files == 0;
    assert score(RepoMeta(full_name="a/b"), an).total >= 0;
}
