import from "@jac/runtime" { Link }

import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    ArrowDown01Icon,
    GithubIcon,
    Moon01Icon,
    Sun01Icon
}

glob _EXPLORE: list[dict[str, str]] = [
         {
             "to": "/tech-demo",
             "label": "Tech Demo",
             "note": "The full tour, game included"
         },
         {
             "to": "/wait-wuuut",
             "label": "Wait, Wuuut?!",
             "note": "How this site is built, line by line"
         },
         {
             "to": "/packages",
             "label": "Packages",
             "note": "Libraries and templates for Jac"
         },

     ];

def:pub Navbar -> JsxElement;
