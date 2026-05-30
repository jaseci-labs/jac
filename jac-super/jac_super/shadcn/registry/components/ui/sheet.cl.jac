cl import from "radix-ui" { Dialog as SheetPrimitive }
cl import from ...lib.utils { cn }
cl import from ".button" { Button }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Cancel01Icon }

cl {
    def:pub Sheet(props: Any) -> JsxElement {
        return
            <SheetPrimitive.Root data-slot="sheet" {...props}/>;
    }

    def:pub SheetTrigger(props: Any) -> JsxElement {
        return
            <SheetPrimitive.Trigger data-slot="sheet-trigger" {...props}/>;
    }

    def:pub SheetClose(props: Any) -> JsxElement {
        return
            <SheetPrimitive.Close data-slot="sheet-close" {...props}/>;
    }

    def:pub SheetPortal(props: Any) -> JsxElement {
        return
            <SheetPrimitive.Portal data-slot="sheet-portal" {...props}/>;
    }

    def:pub SheetOverlay(props: Any) -> JsxElement {
        return
            <SheetPrimitive.Overlay
                {...props}
                data-slot="sheet-overlay"
                className={cn("cn-sheet-overlay fixed inset-0 z-50", props.className)}
            />;
    }

    def:pub SheetContent(props: Any) -> JsxElement {
        side = props.side or "right";
        showCloseButton = props.showCloseButton;
        if showCloseButton == None {
            showCloseButton = True;
        }
        return
            <SheetPortal>
                <SheetOverlay/>
                <SheetPrimitive.Content
                    {...props}
                    data-slot="sheet-content"
                    data-side={side}
                    className={cn("cn-sheet-content", props.className)}
                >
                    {props.children}{showCloseButton
                    and <SheetPrimitive.Close data-slot="sheet-close" asChild={True}>
                        <Button
                            variant="ghost"
                            className="cn-sheet-close"
                            size="icon-sm"
                        >
                            <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2}/>
                            <span className="sr-only">Close</span>
                        </Button>
                    </SheetPrimitive.Close>}
                </SheetPrimitive.Content>
            </SheetPortal>;
    }

    def:pub SheetHeader(props: Any) -> JsxElement {
        return
            <div
                {...props}
                data-slot="sheet-header"
                className={cn("cn-sheet-header flex flex-col", props.className)}
            />;
    }

    def:pub SheetFooter(props: Any) -> JsxElement {
        return
            <div
                {...props}
                data-slot="sheet-footer"
                className={cn("cn-sheet-footer mt-auto flex flex-col", props.className)}
            />;
    }

    def:pub SheetTitle(props: Any) -> JsxElement {
        return
            <SheetPrimitive.Title
                {...props}
                data-slot="sheet-title"
                className={cn("cn-sheet-title", props.className)}
            />;
    }

    def:pub SheetDescription(props: Any) -> JsxElement {
        return
            <SheetPrimitive.Description
                {...props}
                data-slot="sheet-description"
                className={cn("cn-sheet-description", props.className)}
            />;
    }
}
