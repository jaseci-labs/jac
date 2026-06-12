---
name: jac-shadcn-blocks-empty
description: 3 empty state blocks for jac-shadcn (no projects, no search results, error/retry). Load when a page or section needs a feedback state for empty or failed data. Always load jac-shadcn-blocks first for design system constants and anti-patterns.
---

All examples assume `components/pages/MyPage.cl.jac`. `..ui.X` = `components/ui/X`.

---

### `empty_state`

**Use for:** Zero-item list views, first-run experiences, failed network requests.

```jac
cl import from ..ui.empty { Empty, EmptyHeader, EmptyMedia, EmptyTitle, EmptyDescription, EmptyContent }
cl import from ..ui.button { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { FolderIcon, PlusSignIcon, Search01Icon, Alert02Icon, RefreshIcon }

cl {
    def:pub ProjectsEmpty(onCreate: any = None) -> JsxElement {
        return <div className="flex min-h-[400px] items-center justify-center">
            <Empty>
                <EmptyHeader>
                    <EmptyMedia variant="icon">
                        <HugeiconsIcon icon={FolderIcon} strokeWidth={2} />
                    </EmptyMedia>
                    <EmptyTitle>No projects yet</EmptyTitle>
                    <EmptyDescription>
                        Get started by creating your first project.
                    </EmptyDescription>
                </EmptyHeader>
                <EmptyContent>
                    <Button onClick={onCreate}>
                        <HugeiconsIcon icon={PlusSignIcon} strokeWidth={2} className="size-4" />
                        Create project
                    </Button>
                </EmptyContent>
            </Empty>
        </div>;
    }

    def:pub SearchEmpty(searchTerm: str = "", onClear: any = None) -> JsxElement {
        return <div className="flex min-h-[320px] items-center justify-center">
            <Empty>
                <EmptyHeader>
                    <EmptyMedia variant="icon">
                        <HugeiconsIcon icon={Search01Icon} strokeWidth={2} />
                    </EmptyMedia>
                    <EmptyTitle>No results found</EmptyTitle>
                    <EmptyDescription>
                        {"We couldn't find anything matching "}
                        <span className="font-medium text-foreground">{searchTerm}</span>
                        {". Try a different search term."}
                    </EmptyDescription>
                </EmptyHeader>
                <EmptyContent>
                    <Button variant="outline" onClick={onClear}>
                        Clear search
                    </Button>
                </EmptyContent>
            </Empty>
        </div>;
    }

    def:pub ErrorEmpty(onRetry: any = None) -> JsxElement {
        return <div className="flex min-h-[400px] items-center justify-center">
            <Empty>
                <EmptyHeader>
                    <EmptyMedia variant="icon">
                        <HugeiconsIcon icon={Alert02Icon} strokeWidth={2} className="text-destructive" />
                    </EmptyMedia>
                    <EmptyTitle>Something went wrong</EmptyTitle>
                    <EmptyDescription>
                        {"We couldn't load your data. Check your connection and try again."}
                    </EmptyDescription>
                </EmptyHeader>
                <EmptyContent>
                    <div className="flex flex-wrap items-center justify-center gap-3">
                        <Button onClick={onRetry}>
                            <HugeiconsIcon icon={RefreshIcon} strokeWidth={2} className="size-4" />
                            Retry
                        </Button>
                        <Button variant="ghost" asChild={True}>
                            <a href="/support">Contact support</a>
                        </Button>
                    </div>
                </EmptyContent>
            </Empty>
        </div>;
    }
}
```

- Always use the full `Empty` > `EmptyHeader` > `EmptyMedia` > `EmptyTitle` > `EmptyDescription` > `EmptyContent` hierarchy - never raw `<div>`.
- `EmptyMedia variant="icon"` handles size and muted ring - do NOT pass `className="size-16"` to the inner icon.
- Error state: `text-destructive` not `text-red-500`.
- Page-level empty states: `min-h-[400px]` wrapper. When embedded inside an existing `Card`, skip the min-h wrapper and use `CardContent className="pt-12 pb-12"` instead.
- Import path: `..ui.empty` (2 dots = `components/ui/` from `components/pages/`). Never 3 dots.
