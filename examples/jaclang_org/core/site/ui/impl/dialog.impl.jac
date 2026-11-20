impl Dialog(**kwargs: any) -> JsxElement {
    return <DialogPrimitive.Root data-slot="dialog" {...kwargs} />;
}

impl DialogTrigger(**kwargs: any) -> JsxElement {
    return <DialogPrimitive.Trigger data-slot="dialog-trigger" {...kwargs} />;
}

impl DialogPortal(**kwargs: any) -> JsxElement {
    return <DialogPrimitive.Portal data-slot="dialog-portal" {...kwargs} />;
}

impl DialogClose(**kwargs: any) -> JsxElement {
    return <DialogPrimitive.Close data-slot="dialog-close" {...kwargs} />;
}

impl DialogOverlay(**kwargs: any) -> JsxElement {
    return <DialogPrimitive.Overlay
        {...kwargs}
        data-slot="dialog-overlay"
        className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 isolate z-50", kwargs.get("className"))}
    />;
}

impl DialogContent(**kwargs: any) -> JsxElement {
    showCloseButton = kwargs.get("showCloseButton") is not False;  # jac:ignore[W2075]
    return <DialogPortal>
        <DialogOverlay />
        <DialogPrimitive.Content
            {...kwargs}
            data-slot="dialog-content"
            className={cn("bg-background data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 ring-foreground/10 grid max-w-[calc(100%-2rem)] gap-4 rounded-xl p-4 text-sm ring-1 duration-100 sm:max-w-sm data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 bg-background ring-foreground/10 grid max-w-[calc(100%-2rem)] gap-4 rounded-xl p-4 text-sm ring-1 duration-100 sm:max-w-sm fixed top-1/2 left-1/2 z-50 w-full -translate-x-1/2 -translate-y-1/2 outline-none", kwargs.get("className"))}
        >
            {kwargs.get("children")}
            {showCloseButton
                and <DialogPrimitive.Close data-slot="dialog-close" asChild={True}>
                    <button
                        className={cn(buttonVariants().call(None, {"variant": "ghost", "size": "icon-sm"}), "absolute top-2 right-2")}
                    >
                        <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} />
                        <span className="sr-only">Close</span>
                    </button>
                </DialogPrimitive.Close>}
        </DialogPrimitive.Content>
    </DialogPortal>;
}

impl DialogHeader(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="dialog-header"
        className={cn("gap-2 flex flex-col gap-2", kwargs.get("className"))}
    />;
}

impl DialogFooter(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    showCloseButton = kwargs.get("showCloseButton") or False;
    return <div
        {...attrs}
        data-slot="dialog-footer"
        className={cn("bg-muted/50 -mx-4 -mb-4 rounded-b-xl border-t p-4 flex flex-col-reverse gap-2 sm:flex-row sm:justify-end", kwargs.get("className"))}
    >
        {kwargs.get("children")}
        {showCloseButton
            and <DialogPrimitive.Close asChild={True}>
                <button className={cn(buttonVariants().call(None, {"variant": "outline"}))}>
                    Close
                </button>
            </DialogPrimitive.Close>}
    </div>;
}

impl DialogTitle(**kwargs: any) -> JsxElement {
    return <DialogPrimitive.Title
        {...kwargs}
        data-slot="dialog-title"
        className={cn("text-base leading-none font-medium text-base leading-none font-medium", kwargs.get("className"))}
    />;
}

impl DialogDescription(**kwargs: any) -> JsxElement {
    return <DialogPrimitive.Description
        {...kwargs}
        data-slot="dialog-description"
        className={cn("text-muted-foreground *:[a]:hover:text-foreground text-sm *:[a]:underline *:[a]:underline-offset-3 text-muted-foreground text-sm", kwargs.get("className"))}
    />;
}
