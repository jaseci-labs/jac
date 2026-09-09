import from core.docs.graph { DocPageView }
import from "@jac/runtime" { Link }
import from core.site.ui.skeleton { Skeleton }
import from .Markdown { Markdown }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" {
    Alert01Icon,
    ArrowLeft01Icon,
    ArrowRight01Icon
}

def:pub DocsArticleSkeleton -> JsxElement {
    return
        <div className="flex flex-col gap-4 pt-2">
            <Skeleton className="h-9 w-2/3"/>
            <Skeleton className="h-5 w-full"/>
            <Skeleton className="h-5 w-5/6"/>
            <Skeleton className="h-40 w-full"/>
            <Skeleton className="h-5 w-4/6"/>
        </div>;
}

def:pub DocsArticle(page: DocPageView, version: str, loading: bool) -> JsxElement {
    anchors = [t.anchor for t in page.toc];
    return
        <div className={"transition-opacity" + (" opacity-50" if loading else "")}>
            <div
                className="mb-2 flex flex-wrap items-center gap-1.5 font-mono text-xs text-muted-foreground"
            >
                <Link to={"/docs/" + version} className="hover:text-foreground">
                    docs
                </Link>
                <span className="text-border">/</span>
                <span className="text-primary">{version}</span>
                {for (ci, c) in enumerate(page.crumbs) {
                    <span key={str(ci)} className="flex items-center gap-1.5">
                        <span className="text-border">/</span>
                        <span>{c.title}</span>
                    </span>
                }}
            </div>
            {if page.missing {
                <div
                    className="mb-6 flex items-start gap-3 rounded-lg border border-amber-500/40 bg-amber-500/5 pt-3 pb-3 pl-4 pr-4 text-sm text-amber-500"
                >
                    <HugeiconsIcon
                        icon={Alert01Icon}
                        strokeWidth={2}
                        className="mt-0.5 size-4 shrink-0"
                    />
                    <span>
                        That page doesn't exist in{" "}
                        <b>{version}</b>{" "}
                        — showing the nearest section instead.
                    </span>
                </div>
            }}
            <h1
                className="mb-6 text-balance text-3xl font-bold tracking-tight sm:text-4xl"
            >
                {page.title}
            </h1>
            <Markdown lines={page.md_lines} skip_title={page.title} anchors={anchors}/>
            <div
                className="mt-12 grid grid-cols-1 gap-4 border-t border-border/60 pt-8 sm:grid-cols-2"
            >
                {if page.prev_page {
                    <Link
                        to={"/docs/" + version + "/" + page.prev_page.path}
                        className="group flex items-center gap-3 rounded-xl border border-border/70 pt-4 pb-4 pl-5 pr-5 transition-colors hover:border-primary/40"
                    >
                        <HugeiconsIcon
                            icon={ArrowLeft01Icon}
                            strokeWidth={2}
                            className="size-4 shrink-0 text-muted-foreground transition-colors group-hover:text-primary"
                        />
                        <span className="min-w-0">
                            <span className="block text-xs text-muted-foreground">
                                Previous
                            </span>
                            <span className="block truncate text-sm font-medium">
                                {page.prev_page.title}
                            </span>
                        </span>
                    </Link>
                } else {
                    <span></span>
                } }
                {if page.next_page {
                    <Link
                        to={"/docs/" + version + "/" + page.next_page.path}
                        className="group flex items-center justify-end gap-3 rounded-xl border border-border/70 pt-4 pb-4 pl-5 pr-5 text-right transition-colors hover:border-primary/40"
                    >
                        <span className="min-w-0">
                            <span className="block text-xs text-muted-foreground">
                                Next
                            </span>
                            <span className="block truncate text-sm font-medium">
                                {page.next_page.title}
                            </span>
                        </span>
                        <HugeiconsIcon
                            icon={ArrowRight01Icon}
                            strokeWidth={2}
                            className="size-4 shrink-0 text-muted-foreground transition-colors group-hover:text-primary"
                        />
                    </Link>
                }}
            </div>
        </div>;
}
