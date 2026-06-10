import from "class-variance-authority" { cva }
import from "radix-ui" { NavigationMenu as NavigationMenuPrimitive }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowDownIcon }

glob _navigationMenuTriggerStyle: any = cva(
         "cn-navigation-menu-trigger group/navigation-menu-trigger inline-flex h-9 w-max items-center justify-center disabled:pointer-events-none outline-none"
     );

def:pub NavigationMenu(props: any) -> JsxElement {
    viewport = props["viewport"];
    if viewport is None {
        viewport = True;
    }
    return
        <NavigationMenuPrimitive.Root
            {**props}
            data-slot="navigation-menu"
            data-viewport={viewport}
            className={cn(
                "cn-navigation-menu group/navigation-menu relative flex max-w-max flex-1 items-center justify-center",
                props["className"]
            )}
        >
            {props["children"]}{viewport and <NavigationMenuViewport/>}
        </NavigationMenuPrimitive.Root>;
}

def:pub NavigationMenuList(props: any) -> JsxElement {
    return
        <NavigationMenuPrimitive.List
            {**props}
            data-slot="navigation-menu-list"
            className={cn(
                "cn-navigation-menu-list group flex flex-1 list-none items-center justify-center",
                props["className"]
            )}
        />;
}

def:pub NavigationMenuItem(props: any) -> JsxElement {
    return
        <NavigationMenuPrimitive.Item
            {**props}
            data-slot="navigation-menu-item"
            className={cn("cn-navigation-menu-item relative", props["className"])}
        />;
}

def:pub NavigationMenuTrigger(props: any) -> JsxElement {
    triggerStyleFn = _navigationMenuTriggerStyle;
    computedClass = cn(
        triggerStyleFn.call(None, {"className": props["className"]}), "group"
    );
    return
        <NavigationMenuPrimitive.Trigger
            {**props}
            data-slot="navigation-menu-trigger"
            className={computedClass}
        >
            {props["children"]}
            <HugeiconsIcon
                icon={ArrowDownIcon}
                strokeWidth={2}
                className="cn-navigation-menu-trigger-icon"
                aria-hidden="true"
            />
        </NavigationMenuPrimitive.Trigger>;
}

def:pub NavigationMenuContent(props: any) -> JsxElement {
    return
        <NavigationMenuPrimitive.Content
            {**props}
            data-slot="navigation-menu-content"
            className={cn(
                "cn-navigation-menu-content top-0 left-0 w-full group-data-[viewport=false]/navigation-menu:top-full group-data-[viewport=false]/navigation-menu:mt-1.5 group-data-[viewport=false]/navigation-menu:overflow-hidden md:absolute md:w-auto",
                props["className"]
            )}
        />;
}

def:pub NavigationMenuViewport(props: any) -> JsxElement {
    return
        <div
            className="cn-navigation-menu-viewport-wrapper absolute top-full left-0 isolate z-50 flex justify-center"
        >
            <NavigationMenuPrimitive.Viewport
                {**props}
                data-slot="navigation-menu-viewport"
                className={cn(
                    "cn-navigation-menu-viewport origin-top-center relative mt-1.5 h-(--radix-navigation-menu-viewport-height) w-full overflow-hidden md:w-(--radix-navigation-menu-viewport-width)",
                    props["className"]
                )}
            />
        </div>;
}

def:pub NavigationMenuLink(props: any) -> JsxElement {
    return
        <NavigationMenuPrimitive.Link
            {**props}
            data-slot="navigation-menu-link"
            className={cn("cn-navigation-menu-link", props["className"])}
        />;
}

def:pub NavigationMenuIndicator(props: any) -> JsxElement {
    return
        <NavigationMenuPrimitive.Indicator
            {**props}
            data-slot="navigation-menu-indicator"
            className={cn(
                "cn-navigation-menu-indicator top-full z-1 flex h-1.5 items-end justify-center overflow-hidden",
                props["className"]
            )}
        >
            <div
                className="cn-navigation-menu-indicator-arrow relative top-[60%] size-2 rotate-45"
            />
        </NavigationMenuPrimitive.Indicator>;
}

def:pub navigationMenuTriggerStyle -> any {
    return _navigationMenuTriggerStyle.call(None, {});
}
