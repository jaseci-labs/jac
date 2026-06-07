cl import from ...lib.utils { cn }

cl {
    def:pub Skeleton(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                {**attrs}
                data-slot="skeleton"
                className={cn("bg-muted rounded-md animate-pulse", props["className"])}
            />;
    }
}
