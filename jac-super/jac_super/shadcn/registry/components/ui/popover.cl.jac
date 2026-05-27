cl import from "radix-ui" { Popover as PopoverPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub Popover(props: Any) -> JsxElement {
        return
            <PopoverPrimitive.Root data-slot="popover" {...props}/>;
    }

    def:pub PopoverTrigger(props: Any) -> JsxElement {
        return
            <PopoverPrimitive.Trigger data-slot="popover-trigger" {...props}/>;
    }

    def:pub PopoverAnchor(props: Any) -> JsxElement {
        return
            <PopoverPrimitive.Anchor data-slot="popover-anchor" {...props}/>;
    }

    def:pub PopoverContent(props: Any) -> JsxElement {
        align = props.align or "center";
        sideOffset = props.sideOffset or 4;
        return
            <PopoverPrimitive.Portal>
                <PopoverPrimitive.Content
                    {...props}
                    data-slot="popover-content"
                    align={align}
                    sideOffset={sideOffset}
                    className={cn(
                        "cn-popover-content z-50 w-72 origin-(--radix-popover-content-transform-origin) outline-hidden",
                        props.className
                    )}
                />
            </PopoverPrimitive.Portal>;
    }

    def:pub PopoverHeader(props: Any) -> JsxElement {
        return
            <div
                {...props}
                data-slot="popover-header"
                className={cn("cn-popover-header", props.className)}
            />;
    }

    def:pub PopoverTitle(props: Any) -> JsxElement {
        return
            <div
                {...props}
                data-slot="popover-title"
                className={cn("cn-popover-title", props.className)}
            />;
    }

    def:pub PopoverDescription(props: Any) -> JsxElement {
        return
            <p
                {...props}
                data-slot="popover-description"
                className={cn("cn-popover-description", props.className)}
            />;
    }
}
