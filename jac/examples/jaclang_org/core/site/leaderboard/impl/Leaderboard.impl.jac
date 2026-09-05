import from core.async_utils { sleep }

impl Leaderboard.load -> None {
    view = await leaderboard();
    entries = view.entries;
    loading = False;
}

impl Leaderboard.poll_progress -> None {
    seen_active = False;
    for i in range(POLL_TRIES) {
        await sleep(POLL_MS);
        st = await board_status();
        progress = st.progress;
        if st.scoring {
            seen_active = True;
        } elif seen_active or i > WARMUP_TRIES {
            return;
        }
    }
}

impl Leaderboard.do_submit -> None {
    if url.strip() == "" or submitting {
        return;
    }
    submitting = True;
    sub_error = "";
    sub_note = "";
    reveal = None;
    progress = None;
    _ = poll_progress();
    res = await submit_repo(url=url);
    submitting = False;
    if not res.ok {
        sub_error = error_text(res.error);
        return;
    }
    entries = res.board;
    got = res.`entry;
    if got is None {
        return;
    }
    reveal = got;
    url = "";
    if res.cooldown {
        sub_note = COOLDOWN_NOTE;
        reveal_score = got.score;
    } else {
        start_countup(got.score);
    }
}
