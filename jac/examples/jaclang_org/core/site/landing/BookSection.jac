import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowUpRight01Icon,
    Infinity01Icon,
    HierarchyIcon,
    CpuIcon,
    LockIcon,
    StarIcon
}

glob BOOK_URL: str = "https://doi.org/10.5281/zenodo.21464040";

def:pub ConceptCard(icon: any, name: str, line: str) -> JsxElement;

def:pub BookSection -> JsxElement;
