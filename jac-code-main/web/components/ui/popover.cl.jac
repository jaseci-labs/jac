cl import from "radix-ui" { Popover as PopoverPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub Popover(props: Any) -> JsxElement {
        return <PopoverPrimitive.Root data-slot="popover" {...props} />;
    }

    def:pub PopoverTrigger(props: Any) -> JsxElement {
        return <PopoverPrimitive.Trigger data-slot="popover-trigger" {...props} />;
    }

    def:pub PopoverAnchor(props: Any) -> JsxElement {
        return <PopoverPrimitive.Anchor data-slot="popover-anchor" {...props} />;
    }

    def:pub PopoverContent(props: Any) -> JsxElement {
        align = props.align or "center";
        sideOffset = props.sideOffset or 4;
        return <PopoverPrimitive.Portal>
            <PopoverPrimitive.Content
                {...props}
                data-slot="popover-content"
                align={align}
                sideOffset={sideOffset}
                className={cn("bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 flex flex-col gap-2.5 rounded-lg p-2.5 text-sm shadow-md ring-1 duration-100 z-50 w-72 origin-(--radix-popover-content-transform-origin) outline-hidden", props.className)}
            />
        </PopoverPrimitive.Portal>;
    }

    def:pub PopoverHeader(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="popover-header"
            className={cn("flex flex-col gap-0.5 text-sm", props.className)}
        />;
    }

    def:pub PopoverTitle(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="popover-title"
            className={cn("font-medium", props.className)}
        />;
    }

    def:pub PopoverDescription(props: Any) -> JsxElement {
        return <p
            {...props}
            data-slot="popover-description"
            className={cn("text-muted-foreground", props.className)}
        />;
    }
}
