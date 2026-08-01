import from ...lib.utils { cn }

def:pub Skeleton(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="skeleton"
        className={cn("bg-muted rounded-md animate-pulse", props["className"])}
    />
}
