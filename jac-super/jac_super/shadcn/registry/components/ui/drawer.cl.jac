cl import from "vaul" { Drawer as DrawerPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub Drawer(props: any) -> JsxElement {
        return <DrawerPrimitive.Root data-slot="drawer" {**props}/>;
    }

    def:pub DrawerTrigger(props: any) -> JsxElement {
        return <DrawerPrimitive.Trigger data-slot="drawer-trigger" {**props}/>;
    }

    def:pub DrawerPortal(props: any) -> JsxElement {
        return <DrawerPrimitive.Portal data-slot="drawer-portal" {**props}/>;
    }

    def:pub DrawerClose(props: any) -> JsxElement {
        return <DrawerPrimitive.Close data-slot="drawer-close" {**props}/>;
    }

    def:pub DrawerOverlay(props: any) -> JsxElement {
        return
            <DrawerPrimitive.Overlay
                {**props}
                data-slot="drawer-overlay"
                className={cn(
                    "cn-drawer-overlay fixed inset-0 z-50", props["className"]
                )}
            />;
    }

    def:pub DrawerContent(props: any) -> JsxElement {
        return
            <DrawerPrimitive.Portal data-slot="drawer-portal">
                <DrawerPrimitive.Overlay
                    data-slot="drawer-overlay"
                    className="cn-drawer-overlay fixed inset-0 z-50"
                />
                <DrawerPrimitive.Content
                    {**props}
                    data-slot="drawer-content"
                    className={cn(
                        "cn-drawer-content group/drawer-content fixed z-50",
                        props["className"]
                    )}
                >
                    <div
                        className="cn-drawer-handle mx-auto hidden shrink-0 group-data-[vaul-drawer-direction=bottom]/drawer-content:block"
                    />
                    {props["children"]}
                </DrawerPrimitive.Content>
            </DrawerPrimitive.Portal>;
    }

    def:pub DrawerHeader(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                {**attrs}
                data-slot="drawer-header"
                className={cn("cn-drawer-header flex flex-col", props["className"])}
            />;
    }

    def:pub DrawerFooter(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                {**attrs}
                data-slot="drawer-footer"
                className={cn(
                    "cn-drawer-footer mt-auto flex flex-col", props["className"]
                )}
            />;
    }

    def:pub DrawerTitle(props: any) -> JsxElement {
        return
            <DrawerPrimitive.Title
                {**props}
                data-slot="drawer-title"
                className={cn("cn-drawer-title", props["className"])}
            />;
    }

    def:pub DrawerDescription(props: any) -> JsxElement {
        return
            <DrawerPrimitive.Description
                {**props}
                data-slot="drawer-description"
                className={cn("cn-drawer-description", props["className"])}
            />;
    }
}
