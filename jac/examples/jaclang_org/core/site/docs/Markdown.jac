import from "@jac/runtime" { Link }

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowRight01Icon,
    ArrowLeft01Icon,
    Link01Icon,
    HierarchyIcon,
    CheckmarkCircle01Icon,
    Alert01Icon
}

glob _ICON_MAP: dict[str, any] = {
         "octicons-arrow-right-24": ArrowRight01Icon,
         "octicons-arrow-left-24": ArrowLeft01Icon,
         "octicons-check-16": CheckmarkCircle01Icon,
         "octicons-alert-16": Alert01Icon,
         "material-vector-link": Link01Icon,
         "material-graph-outline": HierarchyIcon,
         "material-check": CheckmarkCircle01Icon,

     },
     _ADMON_STYLES: dict[str, any] = {
         "note": ["border-sky-500/50", "bg-sky-500/5", "text-sky-400"],
         "info": ["border-sky-500/50", "bg-sky-500/5", "text-sky-400"],
         "abstract": ["border-sky-500/50", "bg-sky-500/5", "text-sky-400"],
         "tip": ["border-emerald-500/50", "bg-emerald-500/5", "text-emerald-400"],
         "success": ["border-emerald-500/50", "bg-emerald-500/5", "text-emerald-400"],
         "example": ["border-violet-500/50", "bg-violet-500/5", "text-violet-400"],
         "warning": ["border-amber-500/50", "bg-amber-500/5", "text-amber-400"],
         "caution": ["border-amber-500/50", "bg-amber-500/5", "text-amber-400"],
         "danger": ["border-red-500/50", "bg-red-500/5", "text-red-400"],
         "bug": ["border-red-500/50", "bg-red-500/5", "text-red-400"],
         "quote": ["border-border", "bg-muted/30", "text-muted-foreground"],

     };

def _is_alnum(c: str) -> bool;

def _count_hashes(s: str) -> int;

def _leading_spaces(s: str) -> int;

def _is_list_line(s: str) -> bool;

def _is_table_sep(s: str) -> bool;

def _split_row(s: str) -> list[str];

def _parse_blocks(
    lines: list[str], anchors: list[str] | None = None
) -> list[dict[str, any]];

def _icon_name_ok(name: str) -> bool;

def _external_href(href: str) -> bool;

def _parse_inline(t: str) -> list[dict[str, any]];

def:pub MDLabel(text: str) -> JsxElement;

def:pub MDSpans(text: str) -> JsxElement;

def:pub MDBlocks(blocks: list[dict[str, any]]) -> JsxElement;

def:pub Markdown(
    lines: list[str], skip_title: str = "", anchors: list[str] | None = None
) -> JsxElement;
