import from "@jac/runtime" { Link }

def matches(p: PackageSummary, q: str) -> bool {
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

def:pub PackageCard(pkg: PackageSummary) -> JsxElement {
    return
        <li
            className="flex flex-col gap-3 rounded-xl border border-border/60 bg-card/60 p-5 transition-colors hover:border-primary/40"
        >
            <div className="flex flex-wrap items-center gap-2">
                <Link
                    to={"/packages/" + pkg.name}
                    className="font-mono text-base font-semibold hover:text-primary"
                >
                    {pkg.name}
                </Link>
                <Badge variant="secondary">{pkg.latest}</Badge>
                <Badge variant="outline">{pkg.role}</Badge>
            </div>
            {if pkg.description {
                <p className="text-sm text-muted-foreground">{pkg.description}</p>
            }}
            <CopyCommand command={pkg.install} className="w-full sm:w-auto"/>
        </li>;
}

def:pub PackagesIndex(
    catalog: PackageCatalog | None, loading: bool, q: str, onFilter: any
) -> JsxElement {
    shown = [
        p
        for p in (catalog.packages if catalog else [])
        if matches(p, q)
    ];
    return
        <div>
            <header className="mb-8">
                <h1 className="text-3xl font-bold tracking-tight sm:text-4xl">
                    Packages
                </h1>
                <p className="mt-3 max-w-2xl text-muted-foreground">
                    Jac libraries and project templates published to the jac-index. Libraries install with jac install org/name; templates start a project with jac create --use org/name.
                </p>
            </header>
            <Input
                className="mb-6"
                aria-label="Search packages"
                placeholder="Search by name, description, module or symbol"
                value={q}
                onChange={onFilter}
            />
            {if loading and catalog is None {
                <p role="status" className="text-muted-foreground">
                    Loading the package index…
                </p>
            } elif catalog and catalog.error {
                <p role="alert" className="text-destructive">{catalog.error}</p>
            } elif len(shown) == 0 {
                <p className="text-muted-foreground">
                    {"No package matches that search."
                        if q
                        else "No packages have been published yet."}
                </p>
            } else {
                <ul className="flex flex-col gap-4">
                    {for pkg in shown {
                        <PackageCard key={pkg.name} pkg={pkg}/>
                    }}
                </ul>
            }   }
        </div>;
}
