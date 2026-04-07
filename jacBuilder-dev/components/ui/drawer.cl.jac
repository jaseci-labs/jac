cl import from "vaul" { Drawer as DrawerPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub Drawer(props: Any) -> JsxElement {
        return <DrawerPrimitive.Root data-slot="drawer" {...props} />;
    }

    def:pub DrawerTrigger(props: Any) -> JsxElement {
        return <DrawerPrimitive.Trigger data-slot="drawer-trigger" {...props} />;
    }

    def:pub DrawerPortal(props: Any) -> JsxElement {
        return <DrawerPrimitive.Portal data-slot="drawer-portal" {...props} />;
    }

    def:pub DrawerClose(props: Any) -> JsxElement {
        return <DrawerPrimitive.Close data-slot="drawer-close" {...props} />;
    }

    def:pub DrawerOverlay(props: Any) -> JsxElement {
        return <DrawerPrimitive.Overlay
            {...props}
            data-slot="drawer-overlay"
            className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 z-50", props.className)}
        />;
    }

    def:pub DrawerContent(props: Any) -> JsxElement {
        return <DrawerPrimitive.Portal data-slot="drawer-portal">
            <DrawerPrimitive.Overlay
                data-slot="drawer-overlay"
                className="data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 bg-black/10 supports-backdrop-filter:backdrop-blur-xs fixed inset-0 z-50"
            />
            <DrawerPrimitive.Content
                {...props}
                data-slot="drawer-content"
                className={cn("bg-background flex h-auto flex-col text-sm data-[vaul-drawer-direction=bottom]:inset-x-0 data-[vaul-drawer-direction=bottom]:bottom-0 data-[vaul-drawer-direction=bottom]:mt-24 data-[vaul-drawer-direction=bottom]:max-h-[80vh] data-[vaul-drawer-direction=bottom]:rounded-t-xl data-[vaul-drawer-direction=bottom]:border-t data-[vaul-drawer-direction=left]:inset-y-0 data-[vaul-drawer-direction=left]:left-0 data-[vaul-drawer-direction=left]:w-3/4 data-[vaul-drawer-direction=left]:rounded-r-xl data-[vaul-drawer-direction=left]:border-r data-[vaul-drawer-direction=right]:inset-y-0 data-[vaul-drawer-direction=right]:right-0 data-[vaul-drawer-direction=right]:w-3/4 data-[vaul-drawer-direction=right]:rounded-l-xl data-[vaul-drawer-direction=right]:border-l data-[vaul-drawer-direction=top]:inset-x-0 data-[vaul-drawer-direction=top]:top-0 data-[vaul-drawer-direction=top]:mb-24 data-[vaul-drawer-direction=top]:max-h-[80vh] data-[vaul-drawer-direction=top]:rounded-b-xl data-[vaul-drawer-direction=top]:border-b data-[vaul-drawer-direction=left]:sm:max-w-sm data-[vaul-drawer-direction=right]:sm:max-w-sm group/drawer-content fixed z-50", props.className)}
            >
                <div className="bg-muted mx-auto mt-4 hidden h-1 w-[100px] shrink-0 rounded-full group-data-[vaul-drawer-direction=bottom]/drawer-content:block mx-auto hidden shrink-0 group-data-[vaul-drawer-direction=bottom]/drawer-content:block" />
                {props.children}
            </DrawerPrimitive.Content>
        </DrawerPrimitive.Portal>;
    }

    def:pub DrawerHeader(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="drawer-header"
            className={cn("gap-0.5 p-4 group-data-[vaul-drawer-direction=bottom]/drawer-content:text-center group-data-[vaul-drawer-direction=top]/drawer-content:text-center md:gap-0.5 md:text-left flex flex-col", props.className)}
        />;
    }

    def:pub DrawerFooter(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="drawer-footer"
            className={cn("gap-2 p-4 mt-auto flex flex-col", props.className)}
        />;
    }

    def:pub DrawerTitle(props: Any) -> JsxElement {
        return <DrawerPrimitive.Title
            {...props}
            data-slot="drawer-title"
            className={cn("text-foreground text-base font-medium", props.className)}
        />;
    }

    def:pub DrawerDescription(props: Any) -> JsxElement {
        return <DrawerPrimitive.Description
            {...props}
            data-slot="drawer-description"
            className={cn("text-muted-foreground text-sm", props.className)}
        />;
    }
}
