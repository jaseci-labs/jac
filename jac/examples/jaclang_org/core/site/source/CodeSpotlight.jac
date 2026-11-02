import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowUpRight01Icon }

glob CONTEXT_PAD: int = 60,
     RETURN_DELAY_MS: int = 1400;

def:pub CodeSpotlight(
    path: str,
    needle: str,
    hl_lines: int = 1,
    before: int = 3,
    after: int = 12,
    className: str = "",
    on_pop: any = None,
    compact: bool = False
) -> JsxElement;
