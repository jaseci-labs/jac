cl import from "class-variance-authority" { cva }
cl import from "radix-ui" { NavigationMenu as NavigationMenuPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowDownIcon }

glob _navigationMenuTriggerStyle: Any = cva(
    "bg-background hover:bg-muted focus:bg-muted data-open:hover:bg-muted data-open:focus:bg-muted data-open:bg-muted/50 focus-visible:ring-ring/50 data-popup-open:bg-muted/50 data-popup-open:hover:bg-muted rounded-lg px-2.5 py-1.5 text-sm font-medium transition-all focus-visible:ring-3 focus-visible:outline-1 disabled:opacity-50 group/navigation-menu-trigger inline-flex h-9 w-max items-center justify-center disabled:pointer-events-none outline-none"
);

cl {
    def:pub NavigationMenu(props: Any) -> JsxElement {
        viewport = props.viewport;
        if viewport == None {
            viewport = True;
        }
        return <NavigationMenuPrimitive.Root
            {...props}
            data-slot="navigation-menu"
            data-viewport={viewport}
            className={cn("max-w-max group/navigation-menu relative flex max-w-max flex-1 items-center justify-center", props.className)}
        >
            {props.children}
            {viewport and <NavigationMenuViewport />}
        </NavigationMenuPrimitive.Root>;
    }

    def:pub NavigationMenuList(props: Any) -> JsxElement {
        return <NavigationMenuPrimitive.List
            {...props}
            data-slot="navigation-menu-list"
            className={cn("gap-0 group flex flex-1 list-none items-center justify-center", props.className)}
        />;
    }

    def:pub NavigationMenuItem(props: Any) -> JsxElement {
        return <NavigationMenuPrimitive.Item
            {...props}
            data-slot="navigation-menu-item"
            className={cn("max-w-max-item relative", props.className)}
        />;
    }

    def:pub NavigationMenuTrigger(props: Any) -> JsxElement {
        triggerStyleFn = _navigationMenuTriggerStyle;
        computedClass = cn(triggerStyleFn.call(None, {"className": props.className}), "group");
        return <NavigationMenuPrimitive.Trigger
            {...props}
            data-slot="navigation-menu-trigger"
            className={computedClass}
        >
            {props.children}
            <HugeiconsIcon
                icon={ArrowDownIcon}
                strokeWidth={2}
                className="relative top-px ml-1 size-3 transition duration-300 group-data-open/navigation-menu-trigger:rotate-180 group-data-popup-open/navigation-menu-trigger:rotate-180"
                aria-hidden="true"
            />
        </NavigationMenuPrimitive.Trigger>;
    }

    def:pub NavigationMenuContent(props: Any) -> JsxElement {
        return <NavigationMenuPrimitive.Content
            {...props}
            data-slot="navigation-menu-content"
            className={cn("data-[motion^=from-]:animate-in data-[motion^=to-]:animate-out data-[motion^=from-]:fade-in data-[motion^=to-]:fade-out data-[motion=from-end]:slide-in-from-right-52 data-[motion=from-start]:slide-in-from-left-52 data-[motion=to-end]:slide-out-to-right-52 data-[motion=to-start]:slide-out-to-left-52 group-data-[viewport=false]/navigation-menu:bg-popover group-data-[viewport=false]/navigation-menu:text-popover-foreground group-data-[viewport=false]/navigation-menu:data-open:animate-in group-data-[viewport=false]/navigation-menu:data-closed:animate-out group-data-[viewport=false]/navigation-menu:data-closed:zoom-out-95 group-data-[viewport=false]/navigation-menu:data-open:zoom-in-95 group-data-[viewport=false]/navigation-menu:data-open:fade-in-0 group-data-[viewport=false]/navigation-menu:data-closed:fade-out-0 group-data-[viewport=false]/navigation-menu:ring-foreground/10 p-1 ease-[cubic-bezier(0.22,1,0.36,1)] group-data-[viewport=false]/navigation-menu:rounded-lg group-data-[viewport=false]/navigation-menu:shadow group-data-[viewport=false]/navigation-menu:ring-1 group-data-[viewport=false]/navigation-menu:duration-300 top-0 left-0 w-full group-data-[viewport=false]/navigation-menu:top-full group-data-[viewport=false]/navigation-menu:mt-1.5 group-data-[viewport=false]/navigation-menu:overflow-hidden md:absolute md:w-auto", props.className)}
        />;
    }

    def:pub NavigationMenuViewport(props: Any) -> JsxElement {
        return <div className="bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:zoom-out-95 data-open:zoom-in-90 ring-foreground/10 rounded-lg shadow ring-1 duration-100-wrapper absolute top-full left-0 isolate z-50 flex justify-center">
            <NavigationMenuPrimitive.Viewport
                {...props}
                data-slot="navigation-menu-viewport"
                className={cn("bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:zoom-out-95 data-open:zoom-in-90 ring-foreground/10 rounded-lg shadow ring-1 duration-100 origin-top-center relative mt-1.5 h-(--radix-navigation-menu-viewport-height) w-full overflow-hidden md:w-(--radix-navigation-menu-viewport-width)", props.className)}
            />
        </div>;
    }

    def:pub NavigationMenuLink(props: Any) -> JsxElement {
        return <NavigationMenuPrimitive.Link
            {...props}
            data-slot="navigation-menu-link"
            className={cn("data-active:focus:bg-muted data-active:hover:bg-muted data-active:bg-muted/50 focus-visible:ring-ring/50 hover:bg-muted focus:bg-muted flex items-center gap-2 rounded-lg p-2 text-sm transition-all outline-none focus-visible:ring-3 focus-visible:outline-1 in-data-[slot=navigation-menu-content]:rounded-md [&_svg:not([class*='size-'])]:size-4", props.className)}
        />;
    }

    def:pub NavigationMenuIndicator(props: Any) -> JsxElement {
        return <NavigationMenuPrimitive.Indicator
            {...props}
            data-slot="navigation-menu-indicator"
            className={cn("data-[state=visible]:animate-in data-[state=hidden]:animate-out data-[state=hidden]:fade-out data-[state=visible]:fade-in top-full z-1 flex h-1.5 items-end justify-center overflow-hidden", props.className)}
        >
            <div className="bg-border rounded-tl-sm shadow-md relative top-[60%] h-2 w-2 rotate-45" />
        </NavigationMenuPrimitive.Indicator>;
    }

    def:pub navigationMenuTriggerStyle() -> Any {
        return _navigationMenuTriggerStyle.call(None, {});
    }
}
