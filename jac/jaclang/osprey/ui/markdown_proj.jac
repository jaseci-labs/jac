import re;


obj ProjSpan {
    has text: str = "",
        style_id: str = "default",
        attrs: StyleAttrs = StyleAttrs();
}


obj ProjLine {
    has spans: list[ProjSpan] = [];
}


glob _HEADING_RE = re.compile(r"^(#{1,6})\s+(.*)$"),
     _FENCE_RE = re.compile(r"^(`{3,}|~{3,})(.*)$"),
     _HR_RE = re.compile(r"^(\s*([-*_]\s*){3,})$"),
     _UL_RE = re.compile(r"^(\s*)([-*+])\s+(.*)$"),
     _OL_RE = re.compile(r"^(\s*)(\d{1,9})[.)]\s+(.*)$"),
     _INLINE_RE = re.compile(r"(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|~~[^~]+~~)");


def style_attrs_for(style_id: str) -> StyleAttrs;


def _span(text: str, style_id: str = "default") -> ProjSpan;


def project_inline_spans(text: str) -> list[ProjSpan];


def _line_plain(text: str, style_id: str = "default") -> ProjLine;


def _line_inline(text: str) -> ProjLine;


def wrap_inline(text: str, width: int) -> list[list[ProjSpan]];


def _split_long(word: list[ProjSpan], width: int) -> list[list[ProjSpan]];


def _spans_width(spans: list[ProjSpan]) -> int;


def project_markdown(source: str, width: int = 80) -> list[ProjLine];


def proj_lines_to_span_dicts(lines: list[ProjLine]) -> list[dict[str, any]];


def looks_like_markdown(text: str) -> bool;
