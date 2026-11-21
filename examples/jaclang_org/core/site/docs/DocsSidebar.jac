import from "@jac/runtime" { Link }

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowRight01Icon, BookOpen01Icon }

def _title_matches(title: str, q: str) -> bool;

"""What names a section among the sidebar's closed ones: the titles of the
sections from the outermost down to it."""
def:pub section_key(titles: list[str]) -> str;

"""The items of a section of the tree, or of the top: `trail` is the titles of
the sections they are in."""
def:pub DocTreeLevel(
    items: list[TreeNode],
    trail: list[str],
    depth: int,
    version: str,
    cur: str,
    closedList: list[str],
    onToggle: Callable[[str], None],
    q: str,
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
    onGo: Callable[[str], None],
) -> JsxElement;
