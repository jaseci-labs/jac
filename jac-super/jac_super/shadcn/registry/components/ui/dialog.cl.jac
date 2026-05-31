cl import from "radix-ui" { Dialog as DialogPrimitive }
cl import from ...lib.utils { cn }
cl import from .button { buttonVariants }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Cancel01Icon }

cl {
    def:pub Dialog(props: any) -> JsxElement {
        return <DialogPrimitive.Root data-slot="dialog" {**props}/>;
    }

    def:pub DialogTrigger(props: any) -> JsxElement {
        return <DialogPrimitive.Trigger data-slot="dialog-trigger" {**props}/>;
    }

    def:pub DialogPortal(props: any) -> JsxElement {
        return <DialogPrimitive.Portal data-slot="dialog-portal" {**props}/>;
    }

    def:pub DialogClose(props: any) -> JsxElement {
        return <DialogPrimitive.Close data-slot="dialog-close" {**props}/>;
    }

    def:pub DialogOverlay(props: any) -> JsxElement {
        return
            <DialogPrimitive.Overlay
                {**props}
                data-slot="dialog-overlay"
                className={cn(
                    "cn-dialog-overlay data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 duration-100 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 isolate z-50",
                    props["className"]
                )}
            />;
    }

    def:pub DialogContent(props: any) -> JsxElement {
        # default to shown; only an explicit False hides the close button
        showCloseButton = props["showCloseButton"] is not False;  # jac:ignore[W2075]
        return
            <DialogPortal>
                <DialogOverlay/>
                <DialogPrimitive.Content
                    {**props}
                    data-slot="dialog-content"
                    className={cn(
                        "cn-dialog-content data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 bg-background ring-foreground/10 grid max-w-[calc(100%-2rem)] gap-4 rounded-xl p-4 text-sm ring-1 duration-100 sm:max-w-sm fixed top-1/2 left-1/2 z-50 w-full -translate-x-1/2 -translate-y-1/2 outline-none",
                        props["className"]
                    )}
                >
                    {props["children"]}{showCloseButton
                    and <DialogPrimitive.Close data-slot="dialog-close" asChild={True}>
                        <button
                            className={cn(
                                buttonVariants().call(
                                    None, {"variant": "ghost", "size": "icon-sm"}
                                ),
                                "cn-dialog-close"
                            )}
                        >
                            <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2}/>
                            <span className="sr-only">Close</span>
                        </button>
                    </DialogPrimitive.Close>}
                </DialogPrimitive.Content>
            </DialogPortal>;
    }

    def:pub DialogHeader(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                {**attrs}
                data-slot="dialog-header"
                className={cn(
                    "cn-dialog-header flex flex-col gap-2", props["className"]
                )}
            />;
    }

    def:pub DialogFooter(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        showCloseButton = props["showCloseButton"] or False;
        return
            <div
                {**attrs}
                data-slot="dialog-footer"
                className={cn(
                    "cn-dialog-footer flex flex-col-reverse gap-2 sm:flex-row sm:justify-end",
                    props["className"]
                )}
            >
                {props["children"]}{showCloseButton
                and <DialogPrimitive.Close asChild={True}>
                    <button
                        className={cn(
                            buttonVariants().call(None, {"variant": "outline"})
                        )}
                    >
                        Close
                    </button>
                </DialogPrimitive.Close>}
            </div>;
    }

    def:pub DialogTitle(props: any) -> JsxElement {
        return
            <DialogPrimitive.Title
                {**props}
                data-slot="dialog-title"
                className={cn(
                    "cn-dialog-title text-base leading-none font-medium",
                    props["className"]
                )}
            />;
    }

    def:pub DialogDescription(props: any) -> JsxElement {
        return
            <DialogPrimitive.Description
                {**props}
                data-slot="dialog-description"
                className={cn(
                    "cn-dialog-description text-muted-foreground text-sm",
                    props["className"]
                )}
            />;
    }
}
