import from "radix-ui" { Dialog as SheetPrimitive }
import from ...lib.utils { cn }
import from ".button" { Button }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Cancel01Icon }

def:pub Sheet(props: any) -> JsxElement {
    return <SheetPrimitive.Root data-slot="sheet" {**props}/>;
}

def:pub SheetTrigger(props: any) -> JsxElement {
    return <SheetPrimitive.Trigger data-slot="sheet-trigger" {**props}/>;
}

def:pub SheetClose(props: any) -> JsxElement {
    return <SheetPrimitive.Close data-slot="sheet-close" {**props}/>;
}

def:pub SheetPortal(props: any) -> JsxElement {
    return <SheetPrimitive.Portal data-slot="sheet-portal" {**props}/>;
}

def:pub SheetOverlay(props: any) -> JsxElement {
    return
        <SheetPrimitive.Overlay
            {**props}
            data-slot="sheet-overlay"
            className={cn("cn-sheet-overlay fixed inset-0 z-50", props["className"])}
        />;
}

def:pub SheetContent(props: any) -> JsxElement {
    side = props["side"] or "right";
    showCloseButton = props["showCloseButton"];
    if showCloseButton is None {
        showCloseButton = True;
    }
    return
        <SheetPortal>
            <SheetOverlay/>
            <SheetPrimitive.Content
                {**props}
                data-slot="sheet-content"
                data-side={side}
                className={cn("cn-sheet-content", props["className"])}
            >
                {props["children"]}{showCloseButton
                and <SheetPrimitive.Close data-slot="sheet-close" asChild={True}>
                    <Button variant="ghost" className="cn-sheet-close" size="icon-sm">
                        <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2}/>
                        <span className="sr-only">Close</span>
                    </Button>
                </SheetPrimitive.Close>}
            </SheetPrimitive.Content>
        </SheetPortal>;
}

def:pub SheetHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="sheet-header"
            className={cn("cn-sheet-header flex flex-col", props["className"])}
        />;
}

def:pub SheetFooter(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="sheet-footer"
            className={cn("cn-sheet-footer mt-auto flex flex-col", props["className"])}
        />;
}

def:pub SheetTitle(props: any) -> JsxElement {
    return
        <SheetPrimitive.Title
            {**props}
            data-slot="sheet-title"
            className={cn("cn-sheet-title", props["className"])}
        />;
}

def:pub SheetDescription(props: any) -> JsxElement {
    return
        <SheetPrimitive.Description
            {**props}
            data-slot="sheet-description"
            className={cn("cn-sheet-description", props["className"])}
        />;
}
