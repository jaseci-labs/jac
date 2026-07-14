import from ...lib.utils { cn }

def:pub Skeleton(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="skeleton"
            className={cn("cn-skeleton animate-pulse", props["className"])}
        />;
}
