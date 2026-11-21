obj TocEntry {
    has level: int = 2,
        text: str = "",
        anchor: str = "";
}

obj PageRef {
    has title: str = "",
        path: str = "";
}

"""A node of the docs' tree: a page (`kind` "page"), served at `path` below its
version, or a section ("section"), holding its `children` in order."""
obj TreeNode {
    has kind: str = "page",
        title: str = "",
        path: str = "",
        children: list[TreeNode] = [];
}

obj VersionInfo {
    has label: str = "",
        version: str = "",
        pages: int = 0,
        fetched_at: str = "";
}

obj DocsStatus {
    has ready: bool = False,
        built_at: str = "",
        latest_label: str = "",
        versions: list[VersionInfo] = [];
}

obj DocTree {
    has version: str = "",
        tree: list[TreeNode] = [];
}

obj DocPageView {
    has version: str = "",
        path: str = "",
        title: str = "",
        md_lines: list[str] = [],
        toc: list[TocEntry] = [],
        sections: list[str] = [],
        missing: bool = False,
        prev_page: PageRef | None = None,
        next_page: PageRef | None = None;
}
