impl Card(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    size = kwargs.get("size") or "default";
    return <div
        {...attrs}
        data-slot="card"
        data-size={size}
        className={cn("ring-foreground/10 bg-card text-card-foreground gap-4 overflow-hidden rounded-xl pb-4 pt-4 text-sm ring-1 has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:gap-3 data-[size=sm]:py-3 data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl ring-foreground/10 bg-card text-card-foreground gap-4 overflow-hidden rounded-xl pt-4 pb-4 text-sm ring-1 has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:gap-3 data-[size=sm]:pt-3 data-[size=sm]:pb-3 data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl group/card flex flex-col", kwargs.get("className"))}
    />;
}

impl CardHeader(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="card-header"
        className={cn("gap-1 rounded-t-xl px-4 group-data-[size=sm]/card:px-3 [.border-b]:pb-4 group-data-[size=sm]/card:[.border-b]:pb-3 gap-1 rounded-t-xl px-4 group-data-[size=sm]/card:px-3 [.border-b]:pb-4 group-data-[size=sm]/card:[.border-b]:pb-3 group/card-header @container/card-header grid auto-rows-min items-start has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto]", kwargs.get("className"))}
    />;
}

impl CardTitle(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="card-title"
        className={cn("text-base leading-snug font-medium group-data-[size=sm]/card:text-sm text-base leading-snug font-medium group-data-[size=sm]/card:text-sm", kwargs.get("className"))}
    />;
}

impl CardDescription(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="card-description"
        className={cn("text-muted-foreground text-sm text-muted-foreground text-sm", kwargs.get("className"))}
    />;
}

impl CardAction(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="card-action"
        className={cn("ring-foreground/10 bg-card text-card-foreground gap-4 overflow-hidden rounded-xl pb-4 pt-4 text-sm ring-1 has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:gap-3 data-[size=sm]:py-3 data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl-action col-start-2 row-span-2 row-start-1 self-start justify-self-end", kwargs.get("className"))}
    />;
}

impl CardContent(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="card-content"
        className={cn("px-4 group-data-[size=sm]/card:px-3 px-4 group-data-[size=sm]/card:px-3", kwargs.get("className"))}
    />;
}

impl CardFooter(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="card-footer"
        className={cn("bg-muted/50 rounded-b-xl border-t p-4 group-data-[size=sm]/card:p-3 bg-muted/50 rounded-b-xl border-t p-4 group-data-[size=sm]/card:p-3 flex items-center", kwargs.get("className"))}
    />;
}
