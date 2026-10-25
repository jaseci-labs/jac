impl Ecosystems -> JsxElement {
    return
        <section className="mb-10" aria-labelledby="ecosystems-heading">
            <h2
                id="ecosystems-heading"
                className="text-lg font-semibold tracking-tight"
            >
                Beyond the jac-index
            </h2>
            <p className="mt-1 max-w-2xl text-sm text-muted-foreground">
                Jac imports straight from the ecosystems you already use, with no wrappers or bindings.
            </p>
            <div className="mt-4 grid grid-cols-1 gap-3 md:grid-cols-3">
                {for e in _ECOSYSTEMS {
                    <div
                        key={e["name"]}
                        className="flex min-w-0 flex-col gap-2 rounded-xl border border-border/60 bg-card/60 p-4"
                    >
                        <div className="flex items-baseline justify-between gap-2">
                            <span className="font-semibold">{e["name"]}</span>
                            <a
                                href={e["href"]}
                                target="_blank"
                                rel="noreferrer"
                                className="text-xs text-primary hover:underline"
                            >
                                {e["link"] + " ↗"}
                            </a>
                        </div>
                        <p className="text-sm text-muted-foreground">{e["body"]}</p>
                        <code
                            className="mt-auto block whitespace-pre-wrap break-words rounded-md bg-muted/60 px-2.5 py-1.5 font-mono text-xs text-foreground"
                        >
                            {e["code"]}
                        </code>
                        {if e["cmd"] != "" {
                            <CopyCommand command={e["cmd"]} className="w-full text-xs"/>
                        } else {
                            <a
                                href="https://github.com/jaseci-labs/jac/tree/main/jac/examples/raylib_shooter"
                                target="_blank"
                                rel="noreferrer"
                                className="text-xs text-primary hover:underline"
                            >
                                See a raylib game in Jac ↗
                            </a>
                        } }
                    </div>
                }}
            </div>
        </section>;
}

impl PackageCard(pkg: PackageSummary) -> JsxElement {
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

impl PackagesIndex(
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
            <Ecosystems/>
            <h2 className="mb-3 text-lg font-semibold tracking-tight">The jac-index</h2>
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
