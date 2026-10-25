import from "@jac/runtime" { Link }

glob _ECOSYSTEMS: list[dict[str, str]] = [
         {
             "name": "PyPI",
             "href": "https://pypi.org",
             "link": "pypi.org",
             "body": "Every Python package works unmodified in server code.",
             "code": "import numpy as np;",
             "cmd": "jac install numpy"
         },
         {
             "name": "npm",
             "href": "https://www.npmjs.com",
             "link": "npmjs.com",
             "body": "Every npm package works in client code, React components included.",
             "code": "import from \"date-fns\" { format }",
             "cmd": "jac install --npm date-fns"
         },
         {
             "name": "Native libraries",
             "href": "https://www.raylib.com",
             "link": "raylib.com",
             "body": "Link any C-ABI shared library, like raylib, by declaring the functions you call.",
             "code": "import from raylib { def InitWindow(w: i32, h: i32, title: str) -> None; }",
             "cmd": ""
         },

     ];

def matches(p: PackageSummary, q: str) -> bool;

def:pub Ecosystems -> JsxElement;

def:pub PackageCard(pkg: PackageSummary) -> JsxElement;

def:pub PackagesIndex(
    catalog: PackageCatalog | None, loading: bool, q: str, onFilter: any
) -> JsxElement;

impl matches(p: PackageSummary, q: str) -> bool {
    needle = q.strip().lower();
    if needle == "" {
        return True;
    }
    hay = [p.name, p.description, *p.exports, *p.symbols];
    for text in hay {
        if needle in text.lower() {
            return True;
        }
    }
    return False;
}
