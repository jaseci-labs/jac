import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Copy01Icon, CheckmarkCircle01Icon }

def:pub CopyCommandBlock(lines: list[str], className: str = "") -> JsxElement;

def:pub CopyCommand(
    command: str, display: str = "", className: str = "", prefix: str = "$"
) -> JsxElement;
