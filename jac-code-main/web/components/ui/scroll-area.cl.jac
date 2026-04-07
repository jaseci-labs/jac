cl import from "radix-ui" { ScrollArea as ScrollAreaPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub ScrollArea(props: Any) -> JsxElement {
        return <ScrollAreaPrimitive.Root
            {...props}
            data-slot="scroll-area"
            className={cn("cn-scroll-area relative", props.className)}
        >
            <ScrollAreaPrimitive.Viewport
                data-slot="scroll-area-viewport"
                className="cn-scroll-area-viewport focus-visible:ring-ring/50 size-full rounded-[inherit] transition-[color,box-shadow] outline-none focus-visible:ring-[3px] focus-visible:outline-1"
            >
                {props.children}
            </ScrollAreaPrimitive.Viewport>
            <ScrollAreaPrimitive.ScrollAreaScrollbar
                data-slot="scroll-area-scrollbar"
                data-orientation="vertical"
                orientation="vertical"
                className="data-horizontal:h-2.5 data-horizontal:flex-col data-horizontal:border-t data-horizontal:border-t-transparent data-vertical:h-full data-vertical:w-2.5 data-vertical:border-l data-vertical:border-l-transparent flex touch-none pt-px pb-px transition-colors select-none"
            >
                <ScrollAreaPrimitive.ScrollAreaThumb
                    data-slot="scroll-area-thumb"
                    className="rounded-full bg-border relative flex-1"
                />
            </ScrollAreaPrimitive.ScrollAreaScrollbar>
            <ScrollAreaPrimitive.Corner />
        </ScrollAreaPrimitive.Root>;
    }

    def:pub ScrollBar(props: Any) -> JsxElement {
        orientation = props.orientation or "vertical";
        return <ScrollAreaPrimitive.ScrollAreaScrollbar
            {...props}
            data-slot="scroll-area-scrollbar"
            data-orientation={orientation}
            orientation={orientation}
            className={cn("data-horizontal:h-2.5 data-horizontal:flex-col data-horizontal:border-t data-horizontal:border-t-transparent data-vertical:h-full data-vertical:w-2.5 data-vertical:border-l data-vertical:border-l-transparent flex touch-none pt-px pb-px transition-colors select-none", props.className)}
        >
            <ScrollAreaPrimitive.ScrollAreaThumb
                data-slot="scroll-area-thumb"
                className="rounded-full bg-border relative flex-1"
            />
        </ScrollAreaPrimitive.ScrollAreaScrollbar>;
    }
}
