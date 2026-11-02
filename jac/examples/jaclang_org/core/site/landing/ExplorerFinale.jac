import from "@jac/runtime" { Link }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    GlobeIcon,
    SmartPhone01Icon,
    ComputerIcon,
    CommandLineIcon,
    UserGroupIcon,
    LibraryIcon,
    StarIcon,
    Book02Icon,
    BookOpen01Icon,
    DiscordIcon
}

glob BOOK_URL: str = "https://doi.org/10.5281/zenodo.21464040",
     RUN_LINES: list[str] = ["jac create mysite --awesome", "cd mysite", "jac run"];

def:pub WorkspaceAppCard(icon: any, tag: str, title: str, body: str) -> JsxElement;

def:pub ExplorerFinale -> JsxElement;
