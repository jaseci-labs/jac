import from "@jac/runtime" { Link }

glob TABS: list[list[str]] = [
         ["readme", "README"],
         ["api", "API"],
         ["versions", "Versions"]
     ];

def:pub PackageVersions(
    name: str, versions: list[PackageVersion], current: str
) -> JsxElement {
    return
        <ul className="flex flex-col divide-y divide-border/60">
            {for v in versions {
                <li
                    key={v.version}
                    className="flex flex-wrap items-center gap-3 pt-3 pb-3"
                >
                    <Link
                        to={"/packages/" + name + "/" + v.version}
                        className={"font-mono text-sm hover:text-primary "
                            + (
                                "font-semibold text-primary"
                                    if v.version == current
                                    else ""
                            )}
                    >
                        {v.version}
                    </Link>
                    {if v.yanked {
                        <Badge variant="destructive">yanked</Badge>
                    }}
                    <span className="text-xs text-muted-foreground">
                        {v.published[:10]}
                    </span>
                    {if v.jac_version {
                        <span className="font-mono text-xs text-muted-foreground">
                            {"jac " + v.jac_version}
                        </span>
                    }}
                </li>
            }}
        </ul>;
}

def:pub PackageDeps(version: PackageVersion | None) -> JsxElement {
    if version is None {
        return <span></span>;
    }
    groups = [
        ["Jac packages", version.deps],
        ["PyPI", version.pypi],
        ["npm", version.npm]
    ];
    return
        <div className="flex flex-col gap-4">
            {for g in groups {
                if len(g[1]) > 0 {
                    <div key={g[0]}>
                        <h4
                            className="text-xs font-semibold uppercase tracking-wide text-muted-foreground"
                        >
                            {g[0]}
                        </h4>
                        <ul className="mt-1 flex flex-col gap-1">
                            {for d in g[1] {
                                <li key={d} className="font-mono text-xs">{d}</li>
                            }}
                        </ul>
                    </div>
                }
            }}
        </div>;
}

def:pub PackagePage(
    name: str, detail: PackageDetail | None, loading: bool
) -> JsxElement {
    has tab: str = "readme";

    def pick(t: str) {
        tab = t;
    }

    if loading or detail is None {
        return
            <p role="status" className="text-muted-foreground">
                {"Loading " + name + "…"}
            </p>;
    }
    if not detail.found or detail.summary is None {
        return
            <div>
                <Link to="/packages" className="text-sm text-primary hover:underline">
                    All packages
                </Link>
                <p role="alert" className="mt-4 text-destructive">
                    {detail.error or (name + " is not in the index.")}
                </p>
            </div>;
    }
    pkg = detail.summary;
    current = [
        v
        for v in detail.versions
        if v.version == detail.version
    ];
    shown = current[0] if len(current) > 0 else None;
    return
        <div>
            <Link to="/packages" className="text-sm text-primary hover:underline">
                All packages
            </Link>
            <header className="mt-4 mb-6">
                <div className="flex flex-wrap items-center gap-3">
                    <h1
                        className="font-mono text-2xl font-bold tracking-tight sm:text-3xl"
                    >
                        {pkg.name}
                    </h1>
                    <Badge variant="secondary">{detail.version}</Badge>
                    <Badge variant="outline">{pkg.role}</Badge>
                    {if shown and shown.yanked {
                        <Badge variant="destructive">yanked</Badge>
                    }}
                </div>
                {if pkg.description {
                    <p className="mt-3 text-muted-foreground">{pkg.description}</p>
                }}
                <div className="mt-4 flex flex-wrap items-center gap-4 text-sm">
                    <CopyCommand
                        command={pkg.install
                            + (
                                ("@" + detail.version)
                                    if detail.version != pkg.latest
                                    else ""
                            )}
                    />
                    {if pkg.source {
                        <a
                            href={pkg.source}
                            target="_blank"
                            rel="noreferrer"
                            className="text-primary hover:underline"
                        >
                            Source
                        </a>
                    }}
                    {if detail.stars > 0 {
                        <span className="text-muted-foreground">
                            {str(detail.stars) + " stars"}
                        </span>
                    }}
                </div>
            </header>
            <div className="grid grid-cols-1 gap-10 lg:grid-cols-[minmax(0,1fr)_220px]">
                <div className="min-w-0">
                    <nav
                        className="mb-6 flex gap-2 border-b border-border/60"
                        role="tablist"
                    >
                        {for t in TABS {
                            <button
                                key={t[0]}
                                role="tab"
                                aria-selected={tab == t[0]}
                                onClick={lambda { pick(t[0]); }}
                                className={"border-b-2 pl-3 pr-3 pt-2 pb-2 text-sm "
                                    + (
                                        "border-primary font-semibold"
                                            if tab == t[0]
                                            else "border-transparent text-muted-foreground hover:text-foreground"
                                    )}
                            >
                                {t[1]}
                            </button>
                        }}
                    </nav>
                    {if tab == "api" {
                        <ApiDocs modules={detail.modules}/>
                    } elif tab == "versions" {
                        <PackageVersions
                            name={pkg.name}
                            versions={detail.versions}
                            current={detail.version}
                        />
                    } elif len(detail.readme_lines) > 0 {
                        <Markdown lines={detail.readme_lines}/>
                    } else {
                        <p className="text-muted-foreground">
                            This package's repository has no README.
                        </p>
                    }   }
                </div>
                <aside className="flex flex-col gap-6">
                    {if len(pkg.exports) > 0 {
                        <div>
                            <h4
                                className="text-xs font-semibold uppercase tracking-wide text-muted-foreground"
                            >
                                Modules
                            </h4>
                            <ul className="mt-1 flex flex-col gap-1">
                                {for m in pkg.exports {
                                    <li key={m} className="font-mono text-xs">
                                        {pkg.org + "." + pkg.short + "." + m}
                                    </li>
                                }}
                            </ul>
                        </div>
                    }}
                    <PackageDeps version={shown}/>
                    {if len(detail.topics) > 0 {
                        <div className="flex flex-wrap gap-1">
                            {for topic in detail.topics {
                                <Badge key={topic} variant="outline">{topic}</Badge>
                            }}
                        </div>
                    }}
                </aside>
            </div>
        </div>;
}
