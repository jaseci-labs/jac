import from "radix-ui" { AlertDialog as AlertDialogPrimitive }
import from ...lib.utils { cn }
import from .button { Button }

def:pub AlertDialog(props: any) -> JsxElement {
    return <AlertDialogPrimitive.Root data-slot="alert-dialog" {**props}/>;
}

def:pub AlertDialogTrigger(props: any) -> JsxElement {
    return <AlertDialogPrimitive.Trigger data-slot="alert-dialog-trigger" {**props}/>;
}

def:pub AlertDialogPortal(props: any) -> JsxElement {
    return <AlertDialogPrimitive.Portal data-slot="alert-dialog-portal" {**props}/>;
}

def:pub AlertDialogOverlay(props: any) -> JsxElement {
    return
        <AlertDialogPrimitive.Overlay
            {**props}
            data-slot="alert-dialog-overlay"
            className={cn(
                "cn-alert-dialog-overlay data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 isolate z-50",
                props["className"]
            )}
        />;
}

def:pub AlertDialogContent(props: any) -> JsxElement {
    size = props["size"] or "default";
    return
        <AlertDialogPortal>
            <AlertDialogOverlay/>
            <AlertDialogPrimitive.Content
                {**props}
                data-slot="alert-dialog-content"
                data-size={size}
                className={cn(
                    "cn-alert-dialog-content data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 bg-background ring-foreground/10 gap-4 rounded-xl p-4 ring-1 duration-100 data-[size=default]:max-w-xs data-[size=sm]:max-w-xs data-[size=default]:sm:max-w-sm group/alert-dialog-content fixed top-1/2 left-1/2 z-50 grid w-full -translate-x-1/2 -translate-y-1/2 outline-none",
                    props["className"]
                )}
            />
        </AlertDialogPortal>;
}

def:pub AlertDialogHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="alert-dialog-header"
            className={cn(
                "cn-alert-dialog-header grid grid-rows-[auto_1fr] place-items-center gap-1.5 text-center has-data-[slot=alert-dialog-media]:grid-rows-[auto_auto_1fr] has-data-[slot=alert-dialog-media]:gap-x-4 sm:group-data-[size=default]/alert-dialog-content:place-items-start sm:group-data-[size=default]/alert-dialog-content:text-left sm:group-data-[size=default]/alert-dialog-content:has-data-[slot=alert-dialog-media]:grid-rows-[auto_1fr]",
                props["className"]
            )}
        />;
}

def:pub AlertDialogFooter(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="alert-dialog-footer"
            className={cn(
                "cn-alert-dialog-footer bg-muted/50 -mx-4 -mb-4 rounded-b-xl border-t p-4 flex flex-col-reverse gap-2 group-data-[size=sm]/alert-dialog-content:grid group-data-[size=sm]/alert-dialog-content:grid-cols-2 sm:flex-row sm:justify-end",
                props["className"]
            )}
        />;
}

def:pub AlertDialogMedia(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="alert-dialog-media"
            className={cn(
                "cn-alert-dialog-media bg-muted mb-2 inline-flex size-10 items-center justify-center rounded-md sm:group-data-[size=default]/alert-dialog-content:row-span-2 *:[svg:not([class*='size-'])]:size-6",
                props["className"]
            )}
        />;
}

def:pub AlertDialogTitle(props: any) -> JsxElement {
    return
        <AlertDialogPrimitive.Title
            {**props}
            data-slot="alert-dialog-title"
            className={cn(
                "cn-alert-dialog-title text-base font-medium sm:group-data-[size=default]/alert-dialog-content:group-has-data-[slot=alert-dialog-media]/alert-dialog-content:col-start-2",
                props["className"]
            )}
        />;
}

def:pub AlertDialogDescription(props: any) -> JsxElement {
    return
        <AlertDialogPrimitive.Description
            {**props}
            data-slot="alert-dialog-description"
            className={cn(
                "cn-alert-dialog-description text-muted-foreground *:[a]:hover:text-foreground text-sm text-balance md:text-pretty *:[a]:underline *:[a]:underline-offset-3",
                props["className"]
            )}
        />;
}

def:pub AlertDialogAction(props: any) -> JsxElement {
    variant = props["variant"] or "default";
    size = props["size"] or "default";
    return
        <Button variant={variant} size={size} asChild={True}>
            <AlertDialogPrimitive.Action
                {**props}
                data-slot="alert-dialog-action"
                className={cn("cn-alert-dialog-action", props["className"])}
            />
        </Button>;
}

def:pub AlertDialogCancel(props: any) -> JsxElement {
    variant = props["variant"] or "outline";
    size = props["size"] or "default";
    return
        <Button variant={variant} size={size} asChild={True}>
            <AlertDialogPrimitive.Cancel
                {**props}
                data-slot="alert-dialog-cancel"
                className={cn("cn-alert-dialog-cancel", props["className"])}
            />
        </Button>;
}
