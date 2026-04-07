cl import from ...lib.utils { cn }

cl {
    def:pub Card(props: Any) -> JsxElement {
        size = props.size or "default";
        return <div {...props} data-slot="card" data-size={size} className={cn("ring-foreground/10 bg-card text-card-foreground gap-4 overflow-hidden rounded-xl pb-4 pt-4 text-sm ring-1 has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:gap-3 data-[size=sm]:py-3 data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl ring-foreground/10 bg-card text-card-foreground gap-4 overflow-hidden rounded-xl pt-4 pb-4 text-sm ring-1 has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:gap-3 data-[size=sm]:pt-3 data-[size=sm]:pb-3 data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl group/card flex flex-col", props.className)} />;
    }

    def:pub CardHeader(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-header" className={cn("gap-1 rounded-t-xl px-4 group-data-[size=sm]/card:px-3 [.border-b]:pb-4 group-data-[size=sm]/card:[.border-b]:pb-3 gap-1 rounded-t-xl px-4 group-data-[size=sm]/card:px-3 [.border-b]:pb-4 group-data-[size=sm]/card:[.border-b]:pb-3 group/card-header @container/card-header grid auto-rows-min items-start has-data-[slot=card-action]:grid-cols-[1fr_auto] has-data-[slot=card-description]:grid-rows-[auto_auto]", props.className)} />;
    }

    def:pub CardTitle(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-title" className={cn("text-base leading-snug font-medium group-data-[size=sm]/card:text-sm text-base leading-snug font-medium group-data-[size=sm]/card:text-sm", props.className)} />;
    }

    def:pub CardDescription(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-description" className={cn("text-muted-foreground text-sm text-muted-foreground text-sm", props.className)} />;
    }

    def:pub CardAction(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-action" className={cn("ring-foreground/10 bg-card text-card-foreground gap-4 overflow-hidden rounded-xl pb-4 pt-4 text-sm ring-1 has-data-[slot=card-footer]:pb-0 has-[>img:first-child]:pt-0 data-[size=sm]:gap-3 data-[size=sm]:py-3 data-[size=sm]:has-data-[slot=card-footer]:pb-0 *:[img:first-child]:rounded-t-xl *:[img:last-child]:rounded-b-xl-action col-start-2 row-span-2 row-start-1 self-start justify-self-end", props.className)} />;
    }

    def:pub CardContent(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-content" className={cn("px-4 group-data-[size=sm]/card:px-3 px-4 group-data-[size=sm]/card:px-3", props.className)} />;
    }

    def:pub CardFooter(props: Any) -> JsxElement {
        return <div {...props} data-slot="card-footer" className={cn("bg-muted/50 rounded-b-xl border-t p-4 group-data-[size=sm]/card:p-3 bg-muted/50 rounded-b-xl border-t p-4 group-data-[size=sm]/card:p-3 flex items-center", props.className)} />;
    }
}
