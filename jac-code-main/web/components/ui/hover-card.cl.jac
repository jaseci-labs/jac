cl import from "radix-ui" { HoverCard as HoverCardPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub HoverCard(props: Any) -> JsxElement {
        return <HoverCardPrimitive.Root data-slot="hover-card" {...props} />;
    }

    def:pub HoverCardTrigger(props: Any) -> JsxElement {
        return <HoverCardPrimitive.Trigger data-slot="hover-card-trigger" {...props} />;
    }

    def:pub HoverCardContent(props: Any) -> JsxElement {
        align = props.align or "center";
        sideOffset = props.sideOffset or 4;
        return <HoverCardPrimitive.Portal data-slot="hover-card-portal">
            <HoverCardPrimitive.Content
                {...props}
                data-slot="hover-card-content"
                align={align}
                sideOffset={sideOffset}
                className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground w-64 rounded-lg p-2.5 text-sm shadow-md ring-1 duration-100 z-50 origin-(--radix-hover-card-content-transform-origin) outline-hidden", props.className)}
            />
        </HoverCardPrimitive.Portal>;
    }
}
