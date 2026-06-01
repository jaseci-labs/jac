cl import from "radix-ui" { HoverCard as HoverCardPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub HoverCard(props: any) -> JsxElement {
        return <HoverCardPrimitive.Root data-slot="hover-card" {**props}/>;
    }

    def:pub HoverCardTrigger(props: any) -> JsxElement {
        return <HoverCardPrimitive.Trigger data-slot="hover-card-trigger" {**props}/>;
    }

    def:pub HoverCardContent(props: any) -> JsxElement {
        align = props["align"] or "center";
        sideOffset = props["sideOffset"] or 4;
        return
            <HoverCardPrimitive.Portal data-slot="hover-card-portal">
                <HoverCardPrimitive.Content
                    {**props}
                    data-slot="hover-card-content"
                    align={align}
                    sideOffset={sideOffset}
                    className={cn(
                        "cn-hover-card-content z-50 origin-(--radix-hover-card-content-transform-origin) outline-hidden",
                        props["className"]
                    )}
                />
            </HoverCardPrimitive.Portal>;
    }
}
