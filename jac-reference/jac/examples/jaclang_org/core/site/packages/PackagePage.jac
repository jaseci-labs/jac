import from "@jac/runtime" { Link }

glob TABS: list[list[str]] = [
         ["readme", "README"],
         ["api", "API"],
         ["versions", "Versions"]
     ];

def:pub PackageVersions(
    name: str, versions: list[PackageVersion], current: str
) -> JsxElement;

def:pub PackageDeps(version: PackageVersion | None) -> JsxElement;

def:pub PackagePage(
    name: str, detail: PackageDetail | None, loading: bool
) -> JsxElement;
