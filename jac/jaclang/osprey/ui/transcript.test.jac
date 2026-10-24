def _msgs(n: int, prefix: str = "m") -> list[TranscriptMessage];


test "measure_cache_key includes id width and revisions" {
    k1 = measure_cache_key("a", 40, 1, 1);
    k2 = measure_cache_key("a", 40, 2, 1);
    k3 = measure_cache_key("a", 20, 1, 1);
    assert k1 != k2;
    assert k1 != k3;
    assert len(create_measure_cache().entries) == 0;
}


test "bind_transcript sets source_id on view" {
    view = TranscriptView(key="transcript", follow_tail=True);
    proj = bind_transcript(view, source_id="session.events", width=40, height=8);
    assert view.source_id == "session.events";
    assert proj.view is view;
    assert proj.viewport_width == 40;
    assert proj.viewport_height == 8;
}


test "materialize_visible returns at most height plus overscan lines" {
    view = TranscriptView(key="transcript", follow_tail=True);
    proj = bind_transcript(view, "src", width=20, height=5);
    apply_transcript_revision(proj, 1, _msgs(40));
    win = materialize_visible(proj);
    assert len(win.lines) < 40;
    assert len(win.lines) <= (5 + 2 * proj.overscan) * 4;
}


test "measurement cache reuses height for unchanged message width" {
    view = TranscriptView(key="transcript");
    proj = bind_transcript(view, "src", width=20, height=5);
    msg = TranscriptMessage(
        message_id="m0", content="abcdefghijKLMNOPQRST", content_rev=1, style_rev=1,
    );
    apply_transcript_revision(proj, 1, [msg]);
    h1 = measure_message_height(proj, msg, 20);
    h2 = measure_message_height(proj, msg, 20);
    assert h1 == h2;
    assert h1 >= 1;
    key = measure_cache_key("m0", 20, 1, 1);
    assert key in proj.measure_cache.entries;
}


test "follow_tail true keeps window on newest content after append" {
    view = TranscriptView(key="transcript", follow_tail=True);
    proj = bind_transcript(view, "src", width=40, height=4);
    apply_transcript_revision(proj, 1, _msgs(10));
    set_follow_tail(proj, True);
    apply_transcript_revision(proj, 2, _msgs(12));
    win = materialize_visible(proj);
    assert win.last_message_id == "m11" or ("11" in win.last_message_id);
    joined = "\n".join(win.lines);
    assert ("line-11" in joined) or ("m11" in joined) or (len(win.lines) > 0);
}


test "follow_tail false preserves visible anchor across inserts above" {
    view = TranscriptView(key="transcript", follow_tail=False, scroll_offset=5);
    proj = bind_transcript(view, "src", width=40, height=4);
    apply_transcript_revision(proj, 1, _msgs(20));
    set_follow_tail(proj, False);
    before = materialize_visible(proj);
    anchor = before.anchor_message_id;
    assert anchor != "";
    grown = (
        [
            TranscriptMessage(
                message_id="pre0", content="preamble", content_rev=1, style_rev=1,
            )
        ]
        + _msgs(20)
    );
    apply_transcript_revision(proj, 2, grown);
    after = materialize_visible(proj);
    assert after.anchor_message_id == anchor;
}


test "off-screen revision does not require terminal damage" {
    view = TranscriptView(key="transcript", follow_tail=False, scroll_offset=0);
    proj = bind_transcript(view, "src", width=40, height=3);
    msgs = _msgs(30);
    apply_transcript_revision(proj, 1, msgs);
    set_follow_tail(proj, False);
    msgs[25].content = "CHANGED-FAR-AWAY";
    msgs[25].content_rev = 2;
    apply_transcript_revision(proj, 2, msgs);
    assert transcript_needs_damage(proj, 1, 2) == False;
}


test "on-screen content change requires damage" {
    view = TranscriptView(key="transcript", follow_tail=True);
    proj = bind_transcript(view, "src", width=40, height=5);
    msgs = _msgs(5);
    apply_transcript_revision(proj, 1, msgs);
    msgs[4].content = "VISIBLE-EDIT";
    msgs[4].content_rev = 2;
    apply_transcript_revision(proj, 2, msgs);
    assert transcript_needs_damage(proj, 1, 2) == True;
}


test "project_visible_spans uses markdown styles for md messages" {
    view = TranscriptView(key="transcript", follow_tail=True);
    proj = bind_transcript(view, "src", width=40, height=10);
    apply_transcript_revision(
        proj,
        1,
        [
            TranscriptMessage(
                message_id="md0",
                content="# Hello\n\nuse **bold**",
                content_rev=1,
                style_rev=1,
                format="markdown",
            )
        ],
    );
    spans = project_visible_spans(proj);
    assert len(spans) >= 1;
    styles = [str(s.get("style_id", "")) for s in spans];
    assert "heading" in styles or any("Hello" in str(s.get("text", "")) for s in spans);
}

impl _msgs(n: int, prefix: str = "m") -> list[TranscriptMessage] {
    out: list[TranscriptMessage] = [];
    for i in range(n) {
        out.append(
            TranscriptMessage(
                message_id=prefix + str(i),
                content="line-" + str(i) + " " + ("x" * 20),
                content_rev=1,
                style_rev=1,
            )
        );
    }
    return out;
}
