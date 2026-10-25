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
