obj TranscriptMessage {
    has message_id: str,
        content: str = "",
        content_rev: int = 0,
        style_rev: int = 0,
        format: str = "auto";
}


obj MeasureCache {
    has entries: dict[str, int] = {},
        hits: int = 0,
        misses: int = 0;
}


obj VisibleWindow {
    has lines: list[str] = [],
        first_message_id: str = "",
        last_message_id: str = "",
        anchor_message_id: str = "",
        anchor_offset: int = 0,
        cells_would_damage: bool = False;
}


obj TranscriptProjection {
    has view: TranscriptView,
        measure_cache: MeasureCache,
        messages: list[TranscriptMessage] = [],
        overscan: int = 2,
        viewport_height: int = 10,
        viewport_width: int = 40,
        rev_snapshot: dict[str, str] = {},
        last_damage: bool = False,
        anchor_message_id: str = "",
        anchor_line_offset: int = 0;
}


def create_measure_cache -> MeasureCache;


def measure_cache_key(
    message_id: str, width: int, content_rev: int, style_rev: int,
) -> str;


def _snapshot_key(content_rev: int, style_rev: int) -> str;


def _use_markdown(message: TranscriptMessage) -> bool;


def _message_lines(message: TranscriptMessage, width: int) -> list[str];


def _total_height(proj: TranscriptProjection) -> int;


def _line_ranges(proj: TranscriptProjection) -> list[dict[str, any]];


def _visible_message_ids(proj: TranscriptProjection) -> list[str];


def _anchor_at_offset(proj: TranscriptProjection, offset: int) -> (str, int);


def _offset_for_anchor(
    proj: TranscriptProjection, message_id: str, line_off: int
) -> int;


def _compute_damage(
    proj: TranscriptProjection, new_messages: list[TranscriptMessage],
) -> bool;


def bind_transcript(
    view: TranscriptView, source_id: str, width: int = 40, height: int = 10,
) -> TranscriptProjection;


def apply_transcript_revision(
    proj: TranscriptProjection, revision: int, messages: list[TranscriptMessage],
);


def measure_message_height(
    proj: TranscriptProjection, message: TranscriptMessage, width: int,
) -> int;


def project_visible_spans(proj: TranscriptProjection) -> list[dict[str, any]];


def materialize_visible(proj: TranscriptProjection) -> VisibleWindow;


def transcript_needs_damage(
    proj: TranscriptProjection, prev_revision: int, next_revision: int,
) -> bool;


def set_follow_tail(proj: TranscriptProjection, follow: bool);

impl create_measure_cache -> MeasureCache {
    return MeasureCache();
}


impl measure_cache_key(
    message_id: str, width: int, content_rev: int, style_rev: int,
) -> str {
    return (
        message_id + "|" + str(width) + "|" + str(content_rev) + "|" + str(style_rev)
    );
}


impl _snapshot_key(content_rev: int, style_rev: int) -> str {
    return str(content_rev) + ":" + str(style_rev);
}


impl _use_markdown(message: TranscriptMessage) -> bool {
    if message.format == "markdown" {
        return True;
    }
    if message.format == "plain" {
        return False;
    }
    return looks_like_markdown(message.content);
}


impl _message_lines(message: TranscriptMessage, width: int) -> list[str] {
    if _use_markdown(message) {
        proj = project_markdown(message.content, width);
        dicts = proj_lines_to_span_dicts(proj);
        out: list[str] = [];
        for d in dicts {
            out.append(str(d["text"]));
        }
        if not out {
            return [""];
        }
        return out;
    }
    lines = wrap_words(message.content, width);
    if not lines {
        return [""];
    }
    return lines;
}


impl _total_height(proj: TranscriptProjection) -> int {
    total = 0;
    for message in proj.messages {
        total += measure_message_height(proj, message, proj.viewport_width);
    }
    return total;
}


impl _line_ranges(proj: TranscriptProjection) -> list[dict[str, any]] {
    ranges: list[dict[str, any]] = [];
    cursor = 0;
    for message in proj.messages {
        height = measure_message_height(proj, message, proj.viewport_width);
        ranges.append(
            {
                "message_id": message.message_id,
                "start": cursor,
                "height": height,
                "end": cursor + height,

            }
        );
        cursor += height;
    }
    return ranges;
}


impl _visible_message_ids(proj: TranscriptProjection) -> list[str] {
    if not proj.messages {
        return [];
    }
    ranges = _line_ranges(proj);
    total = 0;
    if ranges {
        total = int(ranges[len(ranges) - 1]["end"]);
    }
    vh = proj.viewport_height;
    if vh < 1 {
        vh = 1;
    }
    start = proj.view.scroll_offset;
    if proj.view.follow_tail {
        start = max(0, total - vh);
    }
    if start < 0 {
        start = 0;
    }
    end = start + vh;
    ids: list[str] = [];
    for row in ranges {
        rs = int(row["start"]);
        re = int(row["end"]);
        if re <= start or rs >= end {
            continue;
        }
        ids.append(str(row["message_id"]));
    }
    return ids;
}


impl _anchor_at_offset(proj: TranscriptProjection, offset: int) -> (str, int) {
    if not proj.messages {
        return ("", 0);
    }
    ranges = _line_ranges(proj);
    if offset < 0 {
        offset = 0;
    }
    for row in ranges {
        rs = int(row["start"]);
        re = int(row["end"]);
        if offset < re {
            return (str(row["message_id"]), offset - rs);
        }
    }
    last = ranges[len(ranges) - 1];
    return (str(last["message_id"]), max(0, int(last["height"]) - 1));
}


impl _offset_for_anchor(
    proj: TranscriptProjection, message_id: str, line_off: int
) -> int {
    ranges = _line_ranges(proj);
    for row in ranges {
        if str(row["message_id"]) == message_id {
            return int(row["start"]) + max(0, line_off);
        }
    }
    return proj.view.scroll_offset;
}


impl _compute_damage(
    proj: TranscriptProjection, new_messages: list[TranscriptMessage],
) -> bool {
    old_snap: dict[str, str] = dict(proj.rev_snapshot);
    new_snap: dict[str, str] = {};
    for message in new_messages {
        new_snap[message.message_id] = _snapshot_key(
            message.content_rev, message.style_rev,
        );
    }

    saved = proj.messages;
    proj.messages = new_messages;
    visible: list[str] = _visible_message_ids(proj);
    proj.messages = saved;

    if proj.view.follow_tail {
        old_ids = set(old_snap.keys());
        new_ids = set(new_snap.keys());
        if old_ids != new_ids {
            return True;
        }
    }
    for mid in visible {
        old_v = old_snap.get(mid, "");
        new_v = new_snap.get(mid, "");
        if old_v != new_v {
            return True;
        }
    }

    if len(old_snap) != len(new_snap) and proj.view.follow_tail {
        return True;
    }
    return False;
}


impl bind_transcript(
    view: TranscriptView, source_id: str, width: int = 40, height: int = 10,
) -> TranscriptProjection {
    view.source_id = source_id;
    return TranscriptProjection(
        view=view,
        measure_cache=create_measure_cache(),
        viewport_width=width,
        viewport_height=height,
    );
}


impl apply_transcript_revision(
    proj: TranscriptProjection, revision: int, messages: list[TranscriptMessage],
) {
    if not proj.view.follow_tail and proj.messages {
        (aid, aoff) = _anchor_at_offset(proj, proj.view.scroll_offset);
        proj.anchor_message_id = aid;
        proj.anchor_line_offset = aoff;
    }

    proj.last_damage = _compute_damage(proj, messages);

    copied: list[TranscriptMessage] = [];
    snap: dict[str, str] = {};
    for message in messages {
        copied.append(
            TranscriptMessage(
                message_id=message.message_id,
                content=message.content,
                content_rev=message.content_rev,
                style_rev=message.style_rev,
            )
        );
        snap[message.message_id] = _snapshot_key(
            message.content_rev, message.style_rev,
        );
    }
    proj.messages = copied;
    proj.rev_snapshot = snap;
    proj.view.observed_revision = revision;

    if proj.view.follow_tail {
        total = _total_height(proj);
        proj.view.scroll_offset = max(0, total - proj.viewport_height);
    } elif proj.anchor_message_id {
        proj.view.scroll_offset = _offset_for_anchor(
            proj, proj.anchor_message_id, proj.anchor_line_offset,
        );
    }
}


impl measure_message_height(
    proj: TranscriptProjection, message: TranscriptMessage, width: int,
) -> int {
    key = measure_cache_key(
        message.message_id, width, message.content_rev, message.style_rev,
    );
    if key in proj.measure_cache.entries {
        proj.measure_cache.hits += 1;
        return proj.measure_cache.entries[key];
    }
    proj.measure_cache.misses += 1;
    lines = _message_lines(message, width);
    height = len(lines);
    if height < 1 {
        height = 1;
    }
    proj.measure_cache.entries[key] = height;
    return height;
}


impl project_visible_spans(proj: TranscriptProjection) -> list[dict[str, any]] {
    win = materialize_visible(proj);

    rich: list[dict[str, any]] = [];
    if proj.messages {
        width = proj.viewport_width;
        vh = proj.viewport_height;
        if vh < 1 {
            vh = 1;
        }
        overscan = proj.overscan;
        ranges = _line_ranges(proj);
        if ranges {
            total = int(ranges[len(ranges) - 1]["end"]);
            start = proj.view.scroll_offset;
            if proj.view.follow_tail {
                start = max(0, total - vh);
            }
            win_start = max(0, start - overscan);
            win_end = min(total, start + vh + overscan);
            for message in proj.messages {
                msg_start = 0;
                for row in ranges {
                    if str(row["message_id"]) == message.message_id {
                        msg_start = int(row["start"]);
                        break;
                    }
                }
                if _use_markdown(message) {
                    md_lines = project_markdown(message.content, width);
                    dicts = proj_lines_to_span_dicts(md_lines);
                    for (i, d) in enumerate(dicts) {
                        abs_line = msg_start + i;
                        if abs_line < win_start or abs_line >= win_end {
                            continue;
                        }
                        rich.append(d);
                    }
                } else {
                    msg_lines = _message_lines(message, width);
                    for (i, line) in enumerate(msg_lines) {
                        abs_line = msg_start + i;
                        if abs_line < win_start or abs_line >= win_end {
                            continue;
                        }
                        rich.append({"text": line, "style_id": "default"});
                    }
                }
            }
            if rich {
                return rich;
            }
        }
    }
    spans: list[dict[str, any]] = [];
    for line in win.lines {
        spans.append({"text": line, "style_id": "default"});
    }
    return spans;
}


impl materialize_visible(proj: TranscriptProjection) -> VisibleWindow {
    win = VisibleWindow();
    if not proj.messages {
        return win;
    }
    width = proj.viewport_width;
    vh = proj.viewport_height;
    if vh < 1 {
        vh = 1;
    }
    overscan = proj.overscan;
    ranges = _line_ranges(proj);
    total = int(ranges[len(ranges) - 1]["end"]);

    start = proj.view.scroll_offset;
    if proj.view.follow_tail {
        start = max(0, total - vh);
        proj.view.scroll_offset = start;
    }
    if start < 0 {
        start = 0;
    }
    end = start + vh;
    win_start = max(0, start - overscan);
    win_end = min(total, end + overscan);

    (anchor_id, anchor_off) = _anchor_at_offset(proj, start);
    win.anchor_message_id = anchor_id;
    win.anchor_offset = anchor_off;
    proj.anchor_message_id = anchor_id;
    proj.anchor_line_offset = anchor_off;

    lines: list[str] = [];
    first_id = "";
    last_id = "";
    for message in proj.messages {
        msg_lines = _message_lines(message, width);

        msg_start = 0;
        for row in ranges {
            if str(row["message_id"]) == message.message_id {
                msg_start = int(row["start"]);
                break;
            }
        }
        for (i, line) in enumerate(msg_lines) {
            abs_line = msg_start + i;
            if abs_line < win_start or abs_line >= win_end {
                continue;
            }
            lines.append(line);
            if not first_id {
                first_id = message.message_id;
            }
            last_id = message.message_id;
        }
    }
    win.lines = lines;
    win.first_message_id = first_id;
    win.last_message_id = last_id;
    win.cells_would_damage = proj.last_damage;
    return win;
}


impl transcript_needs_damage(
    proj: TranscriptProjection, prev_revision: int, next_revision: int,
) -> bool {
    if prev_revision == next_revision {
        return False;
    }
    return proj.last_damage;
}


impl set_follow_tail(proj: TranscriptProjection, follow: bool) {
    proj.view.follow_tail = follow;
    if follow {
        total = _total_height(proj);
        proj.view.scroll_offset = max(0, total - proj.viewport_height);
    } else {
        (aid, aoff) = _anchor_at_offset(proj, proj.view.scroll_offset);
        proj.anchor_message_id = aid;
        proj.anchor_line_offset = aoff;
    }
}
