obj ApiParam {
    has name: str = "",
        kind: str = "normal",
        `type: str = "any",
        optional: bool = False,
        value: str = "";
}

obj ApiMember {
    has name: str = "",
        kind: str = "",
        `type: str = "",
        doc: str = "",
        value: str = "",
        params: list[ApiParam] = [],
        returns: str = "";
}

obj ApiSymbol {
    has name: str = "",
        kind: str = "",
        doc: str = "",
        `type: str = "",
        returns: str = "",
        params: list[ApiParam] = [],
        bases: list[str] = [],
        members: list[ApiMember] = [];
}

obj ApiModule {
    has name: str = "",
        doc: str = "",
        symbols: list[ApiSymbol] = [];
}

obj PackageVersion {
    has version: str = "",
        published: str = "",
        yanked: bool = False,
        jac_version: str = "",
        deps: list[str] = [],
        pypi: list[str] = [],
        npm: list[str] = [];
}

obj PackageSummary {
    has name: str = "",
        org: str = "",
        short: str = "",
        role: str = "lib",
        description: str = "",
        latest: str = "",
        published: str = "",
        source: str = "",
        install: str = "",
        versions: int = 0,
        exports: list[str] = [],
        symbols: list[str] = [];
}

obj PackageCatalog {
    has ready: bool = False,
        error: str = "",
        fetched_at: str = "",
        packages: list[PackageSummary] = [];
}

obj PackageDetail {
    has found: bool = False,
        error: str = "",
        summary: PackageSummary | None = None,
        version: str = "",
        versions: list[PackageVersion] = [],
        modules: list[ApiModule] = [],
        readme_lines: list[str] = [],
        stars: int = 0,
        topics: list[str] = [];
}

obj RepoReadme {
    has lines: list[str] = [],
        stars: int = 0,
        topics: list[str] = [];
}
