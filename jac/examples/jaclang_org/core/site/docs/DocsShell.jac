import from core.docs.graph {
    DocPageView,
    DocsStatus,
    DocTree,
    TreeNode,
    VersionInfo,
    doc_page,
    doc_tree,
    docs_status
}
import from "@jac/runtime" { Navigate, useLocation, useNavigate }
import from core.site.ui.GraphBackdrop { GraphBackdrop }
import from .DocsArticle { DocsArticle, DocsArticleSkeleton }
import from .DocsSidebar { DocsSidebar }
import from .DocsTocRail { DocsTocRail }

glob NOT_READY_POLL_MS: int = 4000;

def:pub DocsShell -> JsxElement {
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
    parts = [
        p
        for p in (loc.pathname as str).split("/")
        if p
    ];
    version: str = (parts[1] if len(parts) > 1 else "latest") as str;
    cur_path: str = "/".join(parts[2:]) if len(parts) > 2 else "";
    shown: str = latest_label
        if version == "latest" and latest_label != ""
        else version;

    async def load(want_version: str, want_path: str) -> None;

    def toggle_dir(d: str) {
        if d in closed {
            closed = [
                x
                for x in closed
                if x != d
            ];
        } else {
            closed = closed + [d];
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

    can with [loc.pathname] entry {
        load(version, cur_path);
    }

    if len(parts) <= 1 {
        return <Navigate to="/docs/latest" replace={True}/>;
    }
    if waiting {
        return
            <div
                className="relative flex min-h-[80vh] items-center justify-center overflow-hidden"
            >
                <div className="hero-glow absolute inset-0"></div>
                <GraphBackdrop/>
                <div
                    className="relative flex w-full max-w-md flex-col items-center gap-6 pl-6 pr-6 text-center"
                >
                    <div className="relative flex size-24 items-center justify-center">
                        <span
                            className="pulse-ring absolute inset-0 rounded-full bg-primary/10"
                        ></span>
                        <img
                            src="/static/assets/jac-logo.svg"
                            alt=""
                            className="size-14"
                        />
                    </div>
                    <div>
                        <p
                            className="text-balance text-xl font-semibold tracking-tight sm:text-2xl"
                        >
                            The docs graph is still growing.
                        </p>
                        <p className="mt-2 text-balance text-sm text-muted-foreground">
                            The server is ingesting the docs bundled with its jac binary — this page takes over the moment it lands.
                        </p>
                    </div>
                    <p className="font-mono text-[11px] text-muted-foreground/70">
                        {"root.shared ++> DocsHub ++> DocVersion ++> DocDir ++> DocPage"}
                    </p>
                </div>
            </div>;
    }
    return
        <div
            className="mx-auto max-w-7xl pl-4 pr-4 pt-24 pb-16 sm:pl-6 sm:pr-6 lg:pl-8 lg:pr-8"
        >
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
                    onToggle={toggle_dir}
                    onGo={handle_go}
                />
                <article className="min-w-0">
                    {if page {
                        <DocsArticle page={page} version={shown} loading={loading}/>
                    } else {
                        <DocsArticleSkeleton/>
                    } }
                </article>
                <DocsTocRail toc={page.toc if page else []}/>
            </div>
        </div>;
}
