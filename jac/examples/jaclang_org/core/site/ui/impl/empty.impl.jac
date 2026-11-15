impl Empty(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty"
        className={cn(
            "gap-4 rounded-xl border-dashed p-6 flex w-full min-w-0 flex-1 flex-col items-center justify-center text-center text-balance",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}

impl EmptyHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty-header"
        className={cn("gap-2 flex max-w-sm flex-col items-center", props["className"])}
    >
        {props["children"]}
    </div>
}

impl EmptyMedia(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    variant = props["variant"] or "default";
    computedClass = cn(
        _emptyMediaVariants.call(
            None, {"variant": variant, "className": props["className"]}
        )
    );
    <div
        {**attrs}
        data-slot="empty-icon"
        data-variant={variant}
        className={computedClass}
    >
        {props["children"]}
    </div>
}

impl EmptyTitle(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty-title"
        className={cn("text-sm font-medium tracking-tight", props["className"])}
    >
        {props["children"]}
    </div>
}

impl EmptyDescription(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty-description"
        className={cn(
            "text-sm/relaxed text-muted-foreground [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}

impl EmptyContent(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="empty-content"
        className={cn(
            "gap-2.5 text-sm flex w-full max-w-sm min-w-0 flex-col items-center text-balance",
            props["className"]
        )}
    >
        {props["children"]}
    </div>
}
