import from unittest.mock { patch }

test "fact failures and oversized output are skipped" {
    sample = GuideSample(
        title="osp",
        body="Walkers visit nodes.",
        url="https://jaclang.org/docs/latest/osp"
    );
    with patch(
        optional_fact.__module__ + ".write_fact", side_effect=RuntimeError("no key")
    ) {
        assert optional_fact(sample) == "";
    }
    with patch(
        optional_fact.__module__ + ".write_fact", return_value=JacFact(text="x" * 161)
    ) {
        assert optional_fact(sample) == "";
    }
    with patch(
        optional_fact.__module__ + ".write_fact",
        return_value=JacFact(
            text="Walkers take your code for a stroll through a graph!"
        )
    ) {
        content = optional_fact(sample);
        assert content.endswith(sample.url);
        assert len(content) <= 280;
    }
}

test "guide interface supplies a bounded source" {
    sample = random_guide("");
    assert sample is not None;
    assert len(sample.body) <= 2400;
    assert sample.url.startswith("https://jaclang.org/docs/latest/");
    other = random_guide(sample.title);
    assert other is not None;
    assert other.title != sample.title;
}
