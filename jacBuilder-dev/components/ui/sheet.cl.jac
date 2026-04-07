cl import from "radix-ui" { Dialog as SheetPrimitive }
cl import from ...lib.utils { cn }
cl import from ".button" { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Cancel01Icon }

cl {
    def:pub Sheet(props: Any) -> JsxElement {
        return <SheetPrimitive.Root data-slot="sheet" {...props} />;
    }

    def:pub SheetTrigger(props: Any) -> JsxElement {
        return <SheetPrimitive.Trigger data-slot="sheet-trigger" {...props} />;
    }

    def:pub SheetClose(props: Any) -> JsxElement {
        return <SheetPrimitive.Close data-slot="sheet-close" {...props} />;
    }

    def:pub SheetPortal(props: Any) -> JsxElement {
        return <SheetPrimitive.Portal data-slot="sheet-portal" {...props} />;
    }

    def:pub SheetOverlay(props: Any) -> JsxElement {
        return <SheetPrimitive.Overlay
            {...props}
            data-slot="sheet-overlay"
            className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 duration-100 data-ending-style:opacity-0 data-starting-style:opacity-0 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 z-50", props.className)}
        />;
    }

    def:pub SheetContent(props: Any) -> JsxElement {
        side = props.side or "right";
        showCloseButton = props.showCloseButton;
        if showCloseButton == None {
            showCloseButton = True;
        }
        return <SheetPortal>
            <SheetOverlay />
            <SheetPrimitive.Content
                {...props}
                data-slot="sheet-content"
                data-side={side}
                className={cn("bg-background data-open:animate-in data-closed:animate-out data-[side=right]:data-closed:slide-out-to-right-10 data-[side=right]:data-open:slide-in-from-right-10 data-[side=left]:data-closed:slide-out-to-left-10 data-[side=left]:data-open:slide-in-from-left-10 data-[side=top]:data-closed:slide-out-to-top-10 data-[side=top]:data-open:slide-in-from-top-10 data-closed:fade-out-0 data-open:fade-in-0 data-[side=bottom]:data-closed:slide-out-to-bottom-10 data-[side=bottom]:data-open:slide-in-from-bottom-10 fixed z-50 flex flex-col gap-4 bg-clip-padding text-sm shadow-lg transition duration-200 ease-in-out data-[side=bottom]:inset-x-0 data-[side=bottom]:bottom-0 data-[side=bottom]:h-auto data-[side=bottom]:border-t data-[side=left]:inset-y-0 data-[side=left]:left-0 data-[side=left]:h-full data-[side=left]:w-3/4 data-[side=left]:border-r data-[side=right]:inset-y-0 data-[side=right]:right-0 data-[side=right]:h-full data-[side=right]:w-3/4 data-[side=right]:border-l data-[side=top]:inset-x-0 data-[side=top]:top-0 data-[side=top]:h-auto data-[side=top]:border-b data-[side=left]:sm:max-w-sm data-[side=right]:sm:max-w-sm", props.className)}
            >
                {props.children}
                {showCloseButton and <SheetPrimitive.Close data-slot="sheet-close" asChild={True}>
                    <Button variant="ghost" className="absolute top-3 right-3" size="icon-sm">
                        <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} />
                        <span className="sr-only">Close</span>
                    </Button>
                </SheetPrimitive.Close>}
            </SheetPrimitive.Content>
        </SheetPortal>;
    }

    def:pub SheetHeader(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="sheet-header"
            className={cn("gap-0.5 p-4 flex flex-col", props.className)}
        />;
    }

    def:pub SheetFooter(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="sheet-footer"
            className={cn("gap-2 p-4 mt-auto flex flex-col", props.className)}
        />;
    }

    def:pub SheetTitle(props: Any) -> JsxElement {
        return <SheetPrimitive.Title
            {...props}
            data-slot="sheet-title"
            className={cn("text-foreground text-base font-medium", props.className)}
        />;
    }

    def:pub SheetDescription(props: Any) -> JsxElement {
        return <SheetPrimitive.Description
            {...props}
            data-slot="sheet-description"
            className={cn("text-muted-foreground text-sm", props.className)}
        />;
    }
}
