import from core.docs.graph { TreeNode, VersionInfo }
import from "@jac/runtime" { Link }
import from core.utils { cn }
import from .DocsGraphFloat { DocsGraphFloat }
import from core.site.ui.select {
    Select,
    SelectContent,
    SelectGroup,
    SelectItem,
    SelectTrigger,
    SelectValue
}
import from core.site.ui.skeleton { Skeleton }
import from core.site.ui.input { Input }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowRight01Icon, BookOpen01Icon }

def _title_matches(title: str, q: str) -> bool {
    return q == "" or q.lower() in title.lower();
}

def:pub DocTreeLevel(
    items: list[TreeNode],
    depth: int,
    version: str,
    cur: str,
    closedList: list[str],
    onToggle: Callable[[str], None],
    q: str
) -> JsxElement {
    return
        <div className="flex flex-col">
            {for (i, it) in enumerate(items) {
                if it.kind == "dir" {
                    <div key={str(i)}>
                        {if q == "" {
                            <button
                                onClick={lambda { onToggle(it.path); }}
                                className="flex w-full cursor-pointer items-center gap-1.5 rounded-md pt-1.5 pb-1.5 pr-2 text-[13px] font-semibold text-foreground/80 transition-colors hover:bg-accent hover:text-foreground"
                                style={{"paddingLeft": str(8 + depth * 12) + "px"}}
                            >
                                <HugeiconsIcon
                                    icon={ArrowRight01Icon}
                                    strokeWidth={2}
                                    className={"size-3 shrink-0 text-muted-foreground transition-transform"
                                        + (
                                            ""
                                                if it.path in closedList
                                                else " rotate-90"
                                        )}
                                />
                                <span className="truncate">{it.title}</span>
                            </button>
                        }}
                        {if q != "" or it.path not in closedList {
                            <DocTreeLevel
                                items={it.children}
                                depth={depth + 1}
                                version={version}
                                cur={cur}
                                closedList={closedList}
                                onToggle={onToggle}
                                q={q}
                            />
                        }}
                    </div>
                } elif _title_matches(it.title, q) {
                    <Link
                        key={str(i)}
                        to={"/docs/" + version + "/" + it.path}
                        className={cn(
                            "block truncate rounded-md pt-1.5 pb-1.5 pr-2 text-[13px] transition-colors",
                            "bg-primary/10 font-medium text-primary"
                                if it.path == cur
                                else "text-muted-foreground hover:bg-accent hover:text-foreground"
                        )}
                        style={{"paddingLeft": str(22 + depth * 12) + "px"}}
                    >
                        {it.title}
                    </Link>
                }
            }}
        </div>;
}

def:pub DocsSidebar(
    versions: list[VersionInfo],
    tree: list[TreeNode],
    version: str,
    cur_path: str,
    q: str,
    closed: list[str],
    onVersionChange: Callable[[str], None],
    onFilter: Callable[[any], None],
    onToggle: Callable[[str], None],
    onGo: Callable[[str], None]
) -> JsxElement {
    return
        <aside
            className="lg:sticky lg:top-20 lg:flex lg:h-[calc(100vh-6rem)] lg:flex-col lg:pr-2"
        >
            <div className="no-scrollbar lg:min-h-0 lg:flex-1 lg:overflow-y-auto">
                <div className="mb-3 flex items-center gap-2">
                    <HugeiconsIcon
                        icon={BookOpen01Icon}
                        strokeWidth={2}
                        className="size-4 text-primary"
                    />
                    <span className="text-sm font-semibold">Jac Docs</span>
                </div>
                {if len(versions) > 1 {
                    <Select value={version} onValueChange={onVersionChange}>
                        <SelectTrigger className="mb-3 w-full">
                            <SelectValue placeholder="Version"/>
                        </SelectTrigger>
                        <SelectContent>
                            <SelectGroup>
                                {for (i, v) in enumerate(versions) {
                                    <SelectItem key={str(i)} value={v.label}>
                                        {v.label}{" · "}{str(v.pages)}{" pages"}
                                    </SelectItem>
                                }}
                            </SelectGroup>
                        </SelectContent>
                    </Select>
                } else {
                    <div
                        className="mb-3 flex items-center justify-between rounded-md border border-border/60 bg-muted/30 pl-3 pr-3 pt-1.5 pb-1.5 text-[12px]"
                    >
                        <span className="font-mono font-semibold">
                            {"jac " + version}
                        </span>
                        {if len(versions) == 1 {
                            <span className="text-muted-foreground">
                                {str(versions[0].pages)}{" pages"}
                            </span>
                        }}
                    </div>
                } }
                <Input
                    value={q}
                    onChange={onFilter}
                    placeholder="Filter pages…"
                    className="mb-3 h-8 text-[13px]"
                />
                {if len(tree) == 0 {
                    <div className="flex flex-col gap-2 pt-2">
                        <Skeleton className="h-5 w-3/4"/>
                        <Skeleton className="h-5 w-2/3"/>
                        <Skeleton className="h-5 w-4/5"/>
                        <Skeleton className="h-5 w-1/2"/>
                    </div>
                } else {
                    <nav className="pb-4">
                        <DocTreeLevel
                            items={tree}
                            depth={0}
                            version={version}
                            cur={cur_path}
                            closedList={closed}
                            onToggle={onToggle}
                            q={q}
                        />
                    </nav>
                } }
            </div>
            {if len(tree) > 0 {
                <div className="mt-3 border-t border-border/60 pt-3 lg:shrink-0">
                    <DocsGraphFloat
                        tree={tree}
                        version={version}
                        cur_path={cur_path}
                        on_go={onGo}
                    />
                </div>
            }}
        </aside>;
}
