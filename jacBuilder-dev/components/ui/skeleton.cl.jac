cl import from ...lib.utils { cn }

cl {
    def:pub Skeleton(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="skeleton"
            className={cn("bg-muted rounded-md animate-pulse", props.className)}
        />;
    }
}
