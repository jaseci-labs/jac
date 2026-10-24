import from "@jac/runtime" { Link }

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowRight01Icon, BookOpen01Icon }

def _title_matches(title: str, q: str) -> bool;

def:pub DocTreeLevel(
    items: list[TreeNode],
    depth: int,
    version: str,
    cur: str,
    closedList: list[str],
    onToggle: Callable[[str], None],
    q: str
) -> JsxElement;

def:pub DocsSidebar(
    versions: list[VersionInfo],
    tree: list[TreeNode],
    version: str,
    cur_path: str,
    q: str,
    closed: list[str],
    onVersionChange: Callable[[str], None],
    onFilter: Callable[[any], None],
    onToggle: Callable[[str], None],
    onGo: Callable[[str], None]
) -> JsxElement;

impl _title_matches(title: str, q: str) -> bool {
    return q == "" or q.lower() in title.lower();
}
