import from "vaul" { Drawer as DrawerPrimitive }
import from ...lib.utils { cn }

def:pub Drawer(props: any) -> JsxElement {
    <DrawerPrimitive.Root data-slot="drawer" {**props}/>
}

def:pub DrawerTrigger(props: any) -> JsxElement {
    <DrawerPrimitive.Trigger data-slot="drawer-trigger" {**props}/>
}

def:pub DrawerPortal(props: any) -> JsxElement {
    <DrawerPrimitive.Portal data-slot="drawer-portal" {**props}/>
}

def:pub DrawerClose(props: any) -> JsxElement {
    <DrawerPrimitive.Close data-slot="drawer-close" {**props}/>
}

def:pub DrawerOverlay(props: any) -> JsxElement {
    <DrawerPrimitive.Overlay
        {**props}
        data-slot="drawer-overlay"
        className={cn(
            "cn-drawer-overlay fixed inset-0 z-50 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0",
            props["className"]
        )}
    />
}

def:pub DrawerContent(props: any) -> JsxElement {
    <DrawerPrimitive.Portal data-slot="drawer-portal">
        <DrawerPrimitive.Overlay
            data-slot="drawer-overlay"
            className="cn-drawer-overlay fixed inset-0 z-50 data-open:animate-in data-open:fade-in-0 data-closed:animate-out data-closed:fade-out-0"
        />
        <DrawerPrimitive.Content
            {**props}
            data-slot="drawer-content"
            className={cn(
                "cn-drawer-content group/drawer-content fixed z-50 data-[vaul-drawer-direction=bottom]:inset-x-0 data-[vaul-drawer-direction=bottom]:bottom-0 data-[vaul-drawer-direction=bottom]:mt-24 data-[vaul-drawer-direction=bottom]:max-h-[80vh] data-[vaul-drawer-direction=left]:inset-y-0 data-[vaul-drawer-direction=left]:left-0 data-[vaul-drawer-direction=left]:w-3/4 data-[vaul-drawer-direction=right]:inset-y-0 data-[vaul-drawer-direction=right]:right-0 data-[vaul-drawer-direction=right]:w-3/4 data-[vaul-drawer-direction=top]:inset-x-0 data-[vaul-drawer-direction=top]:top-0 data-[vaul-drawer-direction=top]:mb-24 data-[vaul-drawer-direction=top]:max-h-[80vh] data-[vaul-drawer-direction=left]:sm:max-w-sm data-[vaul-drawer-direction=right]:sm:max-w-sm",
                props["className"]
            )}
        >
            <div
                className="cn-drawer-handle mx-auto hidden shrink-0 group-data-[vaul-drawer-direction=bottom]/drawer-content:block"
            />
            {props["children"]}
        </DrawerPrimitive.Content>
    </DrawerPrimitive.Portal>
}

def:pub DrawerHeader(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="drawer-header"
        className={cn(
            "cn-drawer-header flex flex-col group-data-[vaul-drawer-direction=bottom]/drawer-content:text-center group-data-[vaul-drawer-direction=top]/drawer-content:text-center",
            props["className"]
        )}
    />
}

def:pub DrawerFooter(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <div
        {**attrs}
        data-slot="drawer-footer"
        className={cn("cn-drawer-footer mt-auto flex flex-col", props["className"])}
    />
}

def:pub DrawerTitle(props: any) -> JsxElement {
    <DrawerPrimitive.Title
        {**props}
        data-slot="drawer-title"
        className={cn("cn-drawer-title", props["className"])}
    />
}

def:pub DrawerDescription(props: any) -> JsxElement {
    <DrawerPrimitive.Description
        {**props}
        data-slot="drawer-description"
        className={cn("cn-drawer-description", props["className"])}
    />
}
