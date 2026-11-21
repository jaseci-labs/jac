impl AlertDialog(**kwargs: any) -> JsxElement {
    return <AlertDialogPrimitive.Root data-slot="alert-dialog" {...kwargs} />;
}

impl AlertDialogTrigger(**kwargs: any) -> JsxElement {
    return <AlertDialogPrimitive.Trigger data-slot="alert-dialog-trigger" {...kwargs} />;
}

impl AlertDialogPortal(**kwargs: any) -> JsxElement {
    return <AlertDialogPrimitive.Portal data-slot="alert-dialog-portal" {...kwargs} />;
}

impl AlertDialogOverlay(**kwargs: any) -> JsxElement {
    return <AlertDialogPrimitive.Overlay
        {...kwargs}
        data-slot="alert-dialog-overlay"
        className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 isolate z-50", kwargs.get("className"))}
    />;
}

impl AlertDialogContent(**kwargs: any) -> JsxElement {
    size = kwargs.get("size") or "default";
    return <AlertDialogPortal>
        <AlertDialogOverlay />
        <AlertDialogPrimitive.Content
            {...kwargs}
            data-slot="alert-dialog-content"
            data-size={size}
            className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 bg-background ring-foreground/10 gap-4 rounded-xl p-4 ring-1 duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-xs data-[size=default]:sm:max-w-sm data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 bg-background ring-foreground/10 gap-4 rounded-xl p-4 ring-1 duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-xs data-[size=default]:sm:max-w-sm group/alert-dialog-content fixed top-1/2 left-1/2 z-50 grid w-full -translate-x-1/2 -translate-y-1/2 outline-none", kwargs.get("className"))}
        />
    </AlertDialogPortal>;
}

impl AlertDialogHeader(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="alert-dialog-header"
        className={cn("grid grid-rows-[auto_1fr] place-items-center gap-1.5 text-center has-data-[slot=alert-dialog-media]:grid-rows-[auto_auto_1fr] has-data-[slot=alert-dialog-media]:gap-x-4 sm:group-data-[size=default]/alert-dialog-content:place-items-start sm:group-data-[size=default]/alert-dialog-content:text-left sm:group-data-[size=default]/alert-dialog-content:has-data-[slot=alert-dialog-media]:grid-rows-[auto_1fr] grid grid-rows-[auto_1fr] place-items-center gap-1.5 text-center has-data-[slot=alert-dialog-media]:grid-rows-[auto_auto_1fr] has-data-[slot=alert-dialog-media]:gap-x-4 sm:group-data-[size=default]/alert-dialog-content:place-items-start sm:group-data-[size=default]/alert-dialog-content:text-left sm:group-data-[size=default]/alert-dialog-content:has-data-[slot=alert-dialog-media]:grid-rows-[auto_1fr]", kwargs.get("className"))}
    />;
}

impl AlertDialogFooter(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="alert-dialog-footer"
        className={cn("bg-muted/50 -mx-4 -mb-4 rounded-b-xl border-t p-4 bg-muted/50 -mx-4 -mb-4 rounded-b-xl border-t p-4 flex flex-col-reverse gap-2 group-data-[size=sm]/alert-dialog-content:grid group-data-[size=sm]/alert-dialog-content:grid-cols-2 sm:flex-row sm:justify-end", kwargs.get("className"))}
    />;
}

impl AlertDialogMedia(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <div
        {...attrs}
        data-slot="alert-dialog-media"
        className={cn("bg-muted mb-2 inline-flex size-10 items-center justify-center rounded-md sm:group-data-[size=default]/alert-dialog-content:row-span-2 *:[svg:not([class*='size-'])]:size-6 bg-muted mb-2 inline-flex size-10 items-center justify-center rounded-md sm:group-data-[size=default]/alert-dialog-content:row-span-2 *:[svg:not([class*='size-'])]:size-6", kwargs.get("className"))}
    />;
}

impl AlertDialogTitle(**kwargs: any) -> JsxElement {
    return <AlertDialogPrimitive.Title
        {...kwargs}
        data-slot="alert-dialog-title"
        className={cn("text-base font-medium sm:group-data-[size=default]/alert-dialog-content:group-has-data-[slot=alert-dialog-media]/alert-dialog-content:col-start-2 text-base font-medium sm:group-data-[size=default]/alert-dialog-content:group-has-data-[slot=alert-dialog-media]/alert-dialog-content:col-start-2", kwargs.get("className"))}
    />;
}

impl AlertDialogDescription(**kwargs: any) -> JsxElement {
    return <AlertDialogPrimitive.Description
        {...kwargs}
        data-slot="alert-dialog-description"
        className={cn("text-muted-foreground *:[a]:hover:text-foreground text-sm text-balance md:text-pretty *:[a]:underline *:[a]:underline-offset-3 text-muted-foreground *:[a]:hover:text-foreground text-sm text-balance md:text-pretty *:[a]:underline *:[a]:underline-offset-3", kwargs.get("className"))}
    />;
}

impl AlertDialogAction(**kwargs: any) -> JsxElement {
    variant = kwargs.get("variant") or "default";
    size = kwargs.get("size") or "default";
    return <Button variant={variant} size={size} asChild={True}>
        <AlertDialogPrimitive.Action
            {...kwargs}
            data-slot="alert-dialog-action"
            className={cn("grid gap-0.5 rounded-lg border px-2.5 py-2 text-left text-sm has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2 *:[svg]:row-span-2 *:[svg]:translate-y-0.5 *:[svg]:text-current *:[svg:not([class*='size-'])]:size-4-dialog-action", kwargs.get("className"))}
        />
    </Button>;
}

impl AlertDialogCancel(**kwargs: any) -> JsxElement {
    variant = kwargs.get("variant") or "outline";
    size = kwargs.get("size") or "default";
    return <Button variant={variant} size={size} asChild={True}>
        <AlertDialogPrimitive.Cancel
            {...kwargs}
            data-slot="alert-dialog-cancel"
            className={cn("grid gap-0.5 rounded-lg border px-2.5 py-2 text-left text-sm has-data-[slot=alert-action]:relative has-data-[slot=alert-action]:pr-18 has-[>svg]:grid-cols-[auto_1fr] has-[>svg]:gap-x-2 *:[svg]:row-span-2 *:[svg]:translate-y-0.5 *:[svg]:text-current *:[svg:not([class*='size-'])]:size-4-dialog-cancel", kwargs.get("className"))}
        />
    </Button>;
}
