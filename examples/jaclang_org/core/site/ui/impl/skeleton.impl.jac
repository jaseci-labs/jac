impl Skeleton(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="skeleton"
        className={cn("bg-muted rounded-md animate-pulse", kwargs.get("className"))}
    />;
}
