impl Empty(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="empty"
        className={cn("gap-4 rounded-xl border-dashed p-6 flex w-full min-w-0 flex-1 flex-col items-center justify-center text-center text-balance", kwargs.get("className"))}
    >{kwargs.get("children")}</div>;
}

impl EmptyHeader(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="empty-header"
        className={cn("gap-2 flex max-w-sm flex-col items-center", kwargs.get("className"))}
    >{kwargs.get("children")}</div>;
}

impl EmptyMedia(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    variant = kwargs.get("variant") or "default";
    computedClass = cn(
        _emptyMediaVariants.call(None, {"variant": variant, "className": kwargs.get("className")})
    );
    return <div {...attrs} data-slot="empty-icon" data-variant={variant} className={computedClass}>
        {kwargs.get("children")}
    </div>;
}

impl EmptyTitle(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="empty-title"
        className={cn("text-sm font-medium tracking-tight", kwargs.get("className"))}
    >{kwargs.get("children")}</div>;
}

impl EmptyDescription(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="empty-description"
        className={cn("text-sm/relaxed text-muted-foreground [&>a:hover]:text-primary [&>a]:underline [&>a]:underline-offset-4", kwargs.get("className"))}
    >{kwargs.get("children")}</div>;
}

impl EmptyContent(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="empty-content"
        className={cn("gap-2.5 text-sm flex w-full max-w-sm min-w-0 flex-col items-center text-balance", kwargs.get("className"))}
    >{kwargs.get("children")}</div>;
}
