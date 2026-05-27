cl import from "radix-ui" { Tooltip as TooltipPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub TooltipProvider(props: Any) -> JsxElement {
        delayDuration = props.delayDuration;
        if delayDuration == None or delayDuration == undefined {
            delayDuration = 0;
        }
        return
            <TooltipPrimitive.Provider
                {...props}
                data-slot="tooltip-provider"
                delayDuration={delayDuration}
            />;
    }

    def:pub Tooltip(props: Any) -> JsxElement {
        return
            <TooltipPrimitive.Root data-slot="tooltip" {...props}/>;
    }

    def:pub TooltipTrigger(props: Any) -> JsxElement {
        return
            <TooltipPrimitive.Trigger data-slot="tooltip-trigger" {...props}/>;
    }

    def:pub TooltipContent(props: Any) -> JsxElement {
        sideOffset = props.sideOffset;
        if sideOffset == None or sideOffset == undefined {
            sideOffset = 0;
        }
        return
            <TooltipPrimitive.Portal>
                <TooltipPrimitive.Content
                    {...props}
                    data-slot="tooltip-content"
                    sideOffset={sideOffset}
                    className={cn(
                        "cn-tooltip-content bg-foreground text-background z-50 w-fit max-w-xs origin-(--radix-tooltip-content-transform-origin)",
                        props.className
                    )}
                >
                    {props.children}
                    <TooltipPrimitive.Arrow
                        className="cn-tooltip-arrow bg-foreground fill-foreground z-50 translate-y-[calc(-50%_-_2px)]"
                    />
                </TooltipPrimitive.Content>
            </TooltipPrimitive.Portal>;
    }
}
