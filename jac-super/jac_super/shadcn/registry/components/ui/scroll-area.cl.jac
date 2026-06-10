import from "radix-ui" { ScrollArea as ScrollAreaPrimitive }
import from ...lib.utils { cn }

def:pub ScrollArea(props: any) -> JsxElement {
    return
        <ScrollAreaPrimitive.Root
            {**props}
            data-slot="scroll-area"
            className={cn("cn-scroll-area relative", props["className"])}
        >
            <ScrollAreaPrimitive.Viewport
                data-slot="scroll-area-viewport"
                className="cn-scroll-area-viewport focus-visible:ring-ring/50 size-full rounded-[inherit] transition-[color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:outline-1"
            >
                {props["children"]}
            </ScrollAreaPrimitive.Viewport>
            <ScrollAreaPrimitive.ScrollAreaScrollbar
                data-slot="scroll-area-scrollbar"
                data-orientation="vertical"
                orientation="vertical"
                className="cn-scroll-area-scrollbar flex touch-none pt-px pb-px transition-colors select-none"
            >
                <ScrollAreaPrimitive.ScrollAreaThumb
                    data-slot="scroll-area-thumb"
                    className="cn-scroll-area-thumb bg-border relative flex-1"
                />
            </ScrollAreaPrimitive.ScrollAreaScrollbar>
            <ScrollAreaPrimitive.Corner/>
        </ScrollAreaPrimitive.Root>;
}

def:pub ScrollBar(props: any) -> JsxElement {
    orientation = props["orientation"] or "vertical";
    return
        <ScrollAreaPrimitive.ScrollAreaScrollbar
            {**props}
            data-slot="scroll-area-scrollbar"
            data-orientation={orientation}
            orientation={orientation}
            className={cn(
                "cn-scroll-area-scrollbar flex touch-none pt-px pb-px transition-colors select-none",
                props["className"]
            )}
        >
            <ScrollAreaPrimitive.ScrollAreaThumb
                data-slot="scroll-area-thumb"
                className="cn-scroll-area-thumb bg-border relative flex-1"
            />
        </ScrollAreaPrimitive.ScrollAreaScrollbar>;
}
