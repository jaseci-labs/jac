import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowRight01Icon, Folder01Icon }

glob _DOT_COLORS: dict[str, any] = {
         "jac": "bg-orange-400",
         "toml": "bg-sky-400",
         "css": "bg-purple-400",
         "markdown": "bg-zinc-400",

     };

def _ancestors_of(d: str) -> list[str];

def _dir_paths(rows: list[dict[str, any]]) -> list[str];

def _build_rows(tree: list[SourceFile]) -> list[dict[str, any]];

def:pub SourceBrowser(
    className: str = "", initial_path: str = "web.jac"
) -> JsxElement;
