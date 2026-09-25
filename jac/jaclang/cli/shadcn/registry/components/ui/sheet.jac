import from "radix-ui" { Dialog as SheetPrimitive }
import from ...lib.utils { cn }
import from ".button" { Button }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Cancel01Icon }

def:pub Sheet(props: any) -> JsxElement {
    <SheetPrimitive.Root data-slot="sheet" {**props}/>
}

def:pub SheetTrigger(props: any) -> JsxElement {
    <SheetPrimitive.Trigger data-slot="sheet-trigger" {**props}/>
}

def:pub SheetClose(props: any) -> JsxElement {
    <SheetPrimitive.Close data-slot="sheet-close" {**props}/>
}

def:pub SheetPortal(props: any) -> JsxElement {
    <SheetPrimitive.Portal data-slot="sheet-portal" {**props}/>
}

def:pub SheetOverlay(props: any) -> JsxElement {
    <SheetPrimitive.Overlay
        {**props}
        data-slot="sheet-overlay"
        className={cn(
            "cn-sheet-overlay fixed inset-0 z-50 duration-100 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0",
            props["className"]
        )}
    />
}

def:pub SheetContent(props: any) -> JsxElement {
    side = props["side"] or "right";
    showCloseButton = props["showCloseButton"];
    if showCloseButton is None {
        showCloseButton = True;
    }
    <SheetPortal>
        <SheetOverlay/>
        <SheetPrimitive.Content
            {**props}
            data-slot="sheet-content"
            data-side={side}
            className={cn(
                "cn-sheet-content data-open:animate-in data-open:fade-in-0 data-[side=bottom]:data-open:slide-in-from-bottom-10 data-[side=left]:data-open:slide-in-from-left-10 data-[side=right]:data-open:slide-in-from-right-10 data-[side=top]:data-open:slide-in-from-top-10 data-closed:animate-out data-closed:fade-out-0 data-[side=bottom]:data-closed:slide-out-to-bottom-10 data-[side=left]:data-closed:slide-out-to-left-10 data-[side=right]:data-closed:slide-out-to-right-10 data-[side=top]:data-closed:slide-out-to-top-10",
                props["className"]
            )}
        >
            {props["children"]}{showCloseButton
                and <SheetPrimitive.Close data-slot="sheet-close" asChild={True}>
                    <Button variant="ghost" className="cn-sheet-close" size="icon-sm">
                        <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2}/>
                        <span className="sr-only">Close</span>
                    </Button>
                </SheetPrimitive.Close>}
        </SheetPrimitive.Content>
    </SheetPortal>
}

def:pub SheetHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="sheet-header"
        className={cn("cn-sheet-header flex flex-col", props["className"])}
    />
}

def:pub SheetFooter(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="sheet-footer"
        className={cn("cn-sheet-footer mt-auto flex flex-col", props["className"])}
    />
}

def:pub SheetTitle(props: any) -> JsxElement {
    <SheetPrimitive.Title
        {**props}
        data-slot="sheet-title"
        className={cn("cn-sheet-title", props["className"])}
    />
}

def:pub SheetDescription(props: any) -> JsxElement {
    <SheetPrimitive.Description
        {**props}
        data-slot="sheet-description"
        className={cn("cn-sheet-description", props["className"])}
    />
}
