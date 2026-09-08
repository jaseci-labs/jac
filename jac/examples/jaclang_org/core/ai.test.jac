import from unittest.mock { patch }
import from jaclang.byllm.lib { MockLLM, MockRawResponse }

test "byLLM converts JSON into nested review types in one call" {
    model = MockLLM(
        model_name="mockllm",
        config={
            "outputs": [
                MockRawResponse(
                    content='{"summary":"Task graph","strength":{"observation":"Typed state","evidence":"app.jac: Task"},"opportunity":{"action":"Test traversal","reason":"Protect behavior"}}'
                )
            ]
        }
    );
    with patch(review_sample.__module__ + ".llm", model) {
        review = optional_review({"app.jac": "node Task {}"});
        assert isinstance(review, CodeReview);
        assert isinstance(review.strength, CodeInsight);
        assert isinstance(review.opportunity, NextStep);
        assert review.strength.evidence == "app.jac: Task";
        assert len(model.seen_prompts) == 1;
    }
}

test "byLLM malformed output skips review without retry" {
    model = MockLLM(
        model_name="mockllm", config={"outputs": [MockRawResponse(content="not JSON")]}
    );
    with patch(review_sample.__module__ + ".llm", model) {
        assert optional_review({"app.jac": "node Task {}"}) is None;
        assert len(model.seen_prompts) == 1;
    }
}

test "review input is bounded and prioritizes Jac" {
    files = {"readme.md": "r" * 50000};
    for i in range(20) {
        files[str(i) + ".jac"] = "x" * 50000;
    }
    sample = code_sample(files);
    assert len(sample) <= 6000;
    assert sample.startswith("0.jac\n");
    assert code_sample({}) == "";
}

test "review errors skip optional analysis" {
    with patch(
        optional_review.__module__ + ".review_sample",
        side_effect=RuntimeError("no key")
    ) {
        assert optional_review({"app.jac": "node Task {}"}) is None;
    }
}

test "review hydrates nested report" {
    expected = CodeReview(
        summary="A small task graph.",
        strength=CodeInsight(observation="Uses typed nodes.", evidence="app.jac: Task"),
        opportunity=NextStep(
            action="Add a traversal test.", reason="Protect graph behavior."
        )
    );
    with patch(optional_review.__module__ + ".review_sample", return_value=expected) {
        assert optional_review({"app.jac": "node Task {}"}) == expected;
    }
}
