import type from "react" { ChangeEvent }

impl DocsShell -> JsxElement {
    has versions: list[VersionInfo] = [],
        latest_label: str = "",
        tree: list[TreeNode] = [],
        tree_version: str = "",
        page: DocPageView | None = None,
        loading: bool = True,
        waiting: bool = False,
        q: str = "",
        closed: list[str] = [];

    loc = useLocation();
    nav = useNavigate();
    parts = [p for p in (loc.pathname as str).split("/") if p];
    version: str = (parts[1] if len(parts) > 1 else "latest") as str;
    cur_path: str = "/".join(parts[2:]) if len(parts) > 2 else "";
    shown: str = latest_label if version == "latest" and latest_label != "" else version;

    async def load(want_version: str, want_path: str) {
        loading = True;
        if len(versions) == 0 {
            st = await docs_status();
            while not st.ready {
                waiting = True;
                await sleep(NOT_READY_POLL_MS);
                st = await docs_status();
            }
            waiting = False;
            versions = st.versions;
            latest_label = st.latest_label;
        }
        if tree_version != want_version {
            branch = await doc_tree(version=want_version);
            if branch is not None {
                tree = branch.tree;
                tree_version = want_version;
            }
        }
        p = await (root spawn doc_page(version=want_version, path=want_path));
        # What the walk reported: `page` is read as this render has it, the page before.
        landed = (p.reports[0] if p.reports else None) as DocPageView | None;
        page = landed;
        if landed is not None {
            # The sections holding the page are open, whatever was closed.
            holding = [section_key(landed.sections[:k + 1]) for k in range(len(landed.sections))];
            closed = [c for c in closed if c not in holding];
        }
        loading = False;
    }

    def toggle_section(key: str) {
        if key in closed {
            closed = [x for x in closed if x != key];
        } else {
            closed = closed + [key];
        }
    }

    def handle_filter(e: ChangeEvent) {
        q = e.target.value;
    }

    def handle_version(v: str) {
        nav("/docs/" + v + "/" + cur_path);
    }

    def handle_go(p: str) {
        nav("/docs/" + shown + "/" + p);
    }

    async can with [loc.pathname] entry {
        await load(version, cur_path);
    }

    if len(parts) <= 1 {
        return <Navigate to="/docs/latest" replace={True} />;
    }
    if waiting {
        return <div
            className="relative flex min-h-[80vh] items-center justify-center overflow-hidden"
        >
            <div className="hero-glow absolute inset-0"></div>
            <GraphBackdrop />
            <div
                className="relative flex w-full max-w-md flex-col items-center gap-6 pl-6 pr-6 text-center"
            >
                <div className="relative flex size-24 items-center justify-center">
                    <span className="pulse-ring absolute inset-0 rounded-full bg-primary/10"></span>
                    <img src="/static/assets/jac-logo.svg" alt="" className="size-14" />
                </div>
                <div><p className="text-balance text-xl font-semibold tracking-tight sm:text-2xl">
                            The docs graph is still growing.
                        </p><p className="mt-2 text-balance text-sm text-muted-foreground">
                            The server is ingesting jac's docs — this page takes over the moment they land.
                        </p></div>
                <p className="font-mono text-[11px] text-muted-foreground/70">
                    {"root.shared ++> DocsHub ++> DocVersion ++> DocSection ++> DocPage"}
                </p>
            </div>
        </div>;
    }
    return <div className="mx-auto max-w-7xl pl-4 pr-4 pt-24 pb-16 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8">
        <div
            className="grid grid-cols-1 gap-10 lg:grid-cols-[250px_minmax(0,1fr)] xl:grid-cols-[250px_minmax(0,1fr)_200px]"
        >
            <DocsSidebar
                versions={versions}
                tree={tree}
                version={shown}
                cur_path={cur_path}
                q={q}
                closed={closed}
                onVersionChange={handle_version}
                onFilter={handle_filter}
                onToggle={toggle_section}
                onGo={handle_go}
            />
            <article className="min-w-0">
                {
                    if page {
                        <DocsArticle page={page} version={shown} loading={loading} />
                    } else {
                        <DocsArticleSkeleton />
                    }
                }
            </article>
            <DocsTocRail toc={page.toc if page else []} />
        </div>
    </div>;
}
