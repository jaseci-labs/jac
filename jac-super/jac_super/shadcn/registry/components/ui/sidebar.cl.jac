cl import from react { useState, useEffect, useCallback, createContext, useContext }
cl import from "class-variance-authority" { cva }
cl import from "@radix-ui/react-slot" { Slot }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { SidebarLeftIcon }
cl import from .button { Button }
cl import from .input { Input }
cl import from .separator { Separator }
cl import from .sheet { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle }
cl import from .skeleton { Skeleton }
cl import from .tooltip { Tooltip, TooltipContent, TooltipTrigger }
cl import from ...lib.utils { cn }

glob SIDEBAR_COOKIE_NAME: str = "sidebar_state",
     SIDEBAR_COOKIE_MAX_AGE: int = 604800,
     SIDEBAR_WIDTH: str = "16rem",
     SIDEBAR_WIDTH_MOBILE: str = "18rem",
     SIDEBAR_WIDTH_ICON: str = "3rem",
     SIDEBAR_KEYBOARD_SHORTCUT: str = "b",
     SidebarContext: any = createContext(None),
     _sidebarMenuButtonVariants: any = cva(
         "cn-sidebar-menu-button peer/menu-button flex w-full items-center overflow-hidden outline-hidden group/menu-button disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 [&>span:last-child]:truncate [&_svg]:size-4 [&_svg]:shrink-0",
         {
             "variants": {
                 "variant": {
                     "default": "cn-sidebar-menu-button-variant-default",
                     "outline": "cn-sidebar-menu-button-variant-outline"
                 },
                 "size": {
                     "default": "cn-sidebar-menu-button-size-default",
                     "sm": "cn-sidebar-menu-button-size-sm",
                     "lg": "cn-sidebar-menu-button-size-lg"
                 }
             },
             "defaultVariants": {"variant": "default", "size": "default"}
         }
     );

cl {
    def useIsMobile -> any {
        isMobileState = useState(False);
        isMobile = isMobileState[0];
        setIsMobile = isMobileState[1];
        useEffect(
            lambda -> any {
                mql: any = window.matchMedia("(max-width: 767px)");
                onChange = lambda -> any {
                    setIsMobile(window.innerWidth < 768);
                    return None;
                };
                mql.addEventListener("change", onChange);
                setIsMobile(window.innerWidth < 768);
                return lambda -> any {
                    mql.removeEventListener("change", onChange);
                    return None;
                };
            },
            []
        );
        return isMobile;
    }

    def:pub useSidebar -> any {
        ctx: any = useContext(SidebarContext);
        return ctx;
    }

    def:pub SidebarProvider(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        defaultOpen = props["defaultOpen"] or True;
        openProp = props["open"];
        setOpenProp = props["onOpenChange"];
        isMobile = useIsMobile();
        openMobileState = useState(False);
        openMobile = openMobileState[0];
        setOpenMobile = openMobileState[1];
        openState = useState(defaultOpen);
        _open = openState[0];
        _setOpen = openState[1];
        open = openProp or _open;
        setOpen = useCallback(
            lambda (value: any) -> any {
                nextState = value(open) if callable(value) else value;
                if setOpenProp {
                    setOpenProp(nextState);
                } else {
                    _setOpen(nextState);
                }
                document.cookie = f"{SIDEBAR_COOKIE_NAME}={nextState}; path=/; max-age={SIDEBAR_COOKIE_MAX_AGE}";  # jac:ignore[W6001]
            },
            [setOpenProp, open]
        );
        toggleSidebar = useCallback(
            lambda -> any {
                isMobile
                and setOpenMobile(lambda (prev: any) -> any { return not prev; });
                isMobile or setOpen(lambda (prev: any) -> any { return not prev; });
            },
            [isMobile, setOpen, setOpenMobile]
        );
        useEffect(
            lambda -> any {
                handleKeyDown = lambda (event: any) -> any { if event.key == SIDEBAR_KEYBOARD_SHORTCUT
                and (event.metaKey or event.ctrlKey) {
                    event.preventDefault();
                    toggleSidebar();
                }};
                window.addEventListener("keydown", handleKeyDown);
                return lambda -> any { window.removeEventListener(
                    "keydown", handleKeyDown
                ); };
            },
            [toggleSidebar]
        );
        state = "expanded" if open else "collapsed";
        ctxValue = {
            state: state,
            open: open,
            setOpen: setOpen,
            isMobile: isMobile,
            openMobile: openMobile,
            setOpenMobile: setOpenMobile,
            toggleSidebar: toggleSidebar
        };
        mergedStyle = {
            "--sidebar-width": SIDEBAR_WIDTH,
            "--sidebar-width-icon": SIDEBAR_WIDTH_ICON
        };
        return
            <SidebarContext.Provider value={ctxValue}>
                <div
                    data-slot="sidebar-wrapper"
                    style={mergedStyle}
                    className={cn(
                        "group/sidebar-wrapper has-data-[variant=inset]:bg-sidebar flex min-h-svh w-full",
                        props["className"]
                    )}
                    {**attrs}
                >
                    {props["children"]}
                </div>
            </SidebarContext.Provider>;
    }

    def:pub Sidebar(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        side = props["side"] or "left";
        variant = props["variant"] or "sidebar";
        collapsible = props["collapsible"] or "offcanvas";
        ctx: any = useContext(SidebarContext);
        isMobile = ctx.isMobile if ctx else False;
        state = ctx.state if ctx else "expanded";
        openMobile = ctx.openMobile if ctx else False;
        setOpenMobile = ctx.setOpenMobile if ctx else None;
        isFloating = variant == "floating" or variant == "inset";
        containerClass = "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4))+2px)]"
            if isFloating
            else "group-data-[collapsible=icon]:w-(--sidebar-width-icon) group-data-[side=left]:border-r group-data-[side=right]:border-l";
        if collapsible == "none" {
            return
                <div
                    data-slot="sidebar"
                    className={cn(
                        "bg-sidebar text-sidebar-foreground flex h-full w-(--sidebar-width) flex-col",
                        props["className"]
                    )}
                    {**attrs}
                >
                    {props["children"]}
                </div>;
        } elif isMobile {
            mobileStyle = {"--sidebar-width": SIDEBAR_WIDTH_MOBILE};
            return
                <Sheet open={openMobile} onOpenChange={setOpenMobile} {**props}>
                    <SheetContent
                        dir={props["dir"]}
                        data-sidebar="sidebar"
                        data-slot="sidebar"
                        data-mobile="true"
                        className="bg-sidebar text-sidebar-foreground w-(--sidebar-width) p-0 [&>button]:hidden"
                        style={mobileStyle}
                        side={side}
                    >
                        <SheetHeader className="sr-only">
                            <SheetTitle>Sidebar</SheetTitle>
                            <SheetDescription>
                                Displays the mobile sidebar.
                            </SheetDescription>
                        </SheetHeader>
                        <div className="flex h-full w-full flex-col">
                            {props["children"]}
                        </div>
                    </SheetContent>
                </Sheet>;
        } else {
            return
                <div
                    className="group peer text-sidebar-foreground hidden md:block"
                    data-state={state}
                    data-collapsible={collapsible if state == "collapsed" else ""}
                    data-variant={variant}
                    data-side={side}
                    data-slot="sidebar"
                >
                    <div
                        data-slot="sidebar-gap"
                        className={cn(
                            "cn-sidebar-gap relative w-(--sidebar-width) bg-transparent",
                            "group-data-[collapsible=offcanvas]:w-0",
                            "group-data-[side=right]:rotate-180",
                            "group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4)))]"
                                if isFloating
                                else "group-data-[collapsible=icon]:w-(--sidebar-width-icon)"
                        )}
                    />
                    <div
                        data-slot="sidebar-container"
                        data-side={side}
                        className={cn(
                            "fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) transition-[left,right,width] duration-200 ease-linear data-[side=left]:left-0 data-[side=left]:group-data-[collapsible=offcanvas]:left-[calc(var(--sidebar-width)*-1)] data-[side=right]:right-0 data-[side=right]:group-data-[collapsible=offcanvas]:right-[calc(var(--sidebar-width)*-1)] md:flex",
                            containerClass,
                            props["className"]
                        )}
                        {**attrs}
                    >
                        <div
                            data-sidebar="sidebar"
                            data-slot="sidebar-inner"
                            className="cn-sidebar-inner flex size-full flex-col"
                        >
                            {props["children"]}
                        </div>
                    </div>
                </div>;
        }
    }

    def:pub SidebarTrigger(props: any) -> JsxElement {
        ctx: any = useContext(SidebarContext);
        toggleSidebar: any = ctx.toggleSidebar if ctx else None;
        handleClick = lambda (event: any) -> any {
            props["onClick"] and props["onClick"](event);
            toggleSidebar and toggleSidebar();
        };
        return
            <Button
                data-sidebar="trigger"
                data-slot="sidebar-trigger"
                variant="ghost"
                size="icon-sm"
                className={cn("cn-sidebar-trigger", props["className"])}
                onClick={handleClick}
                {**props}
            >
                <HugeiconsIcon
                    icon={SidebarLeftIcon}
                    className="cn-rtl-flip"
                    size={16}
                />
                <span className="sr-only">Toggle Sidebar</span>
            </Button>;
    }

    def:pub SidebarRail(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        ctx: any = useContext(SidebarContext);
        toggleSidebar: any = ctx.toggleSidebar if ctx else None;
        return
            <button
                data-sidebar="rail"
                data-slot="sidebar-rail"
                aria-label="Toggle Sidebar"
                tabIndex={-1}
                onClick={toggleSidebar}
                title="Toggle Sidebar"
                className={cn(
                    "cn-sidebar-rail absolute inset-y-0 z-20 hidden w-4 transition-all ease-linear group-data-[side=left]:-right-4 group-data-[side=right]:left-0 after:absolute after:inset-y-0 after:start-1/2 after:w-[2px] sm:flex",
                    props["className"]
                )}
                {**attrs}
            />;
    }

    def:pub SidebarInset(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <main
                data-slot="sidebar-inset"
                className={cn(
                    "cn-sidebar-inset relative flex w-full flex-1 flex-col",
                    props["className"]
                )}
                {**attrs}
            />;
    }

    def:pub SidebarInput(props: any) -> JsxElement {
        return
            <Input
                data-slot="sidebar-input"
                data-sidebar="input"
                className={cn("cn-sidebar-input", props["className"])}
                {**props}
            />;
    }

    def:pub SidebarHeader(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                data-slot="sidebar-header"
                data-sidebar="header"
                className={cn("cn-sidebar-header flex flex-col", props["className"])}
                {**attrs}
            />;
    }

    def:pub SidebarFooter(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                data-slot="sidebar-footer"
                data-sidebar="footer"
                className={cn("cn-sidebar-footer flex flex-col", props["className"])}
                {**attrs}
            />;
    }

    def:pub SidebarSeparator(props: any) -> JsxElement {
        return
            <Separator
                data-slot="sidebar-separator"
                data-sidebar="separator"
                className={cn("cn-sidebar-separator w-auto", props["className"])}
                {**props}
            />;
    }

    def:pub SidebarContent(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                data-slot="sidebar-content"
                data-sidebar="content"
                className={cn(
                    "cn-sidebar-content flex min-h-0 flex-1 flex-col overflow-auto group-data-[collapsible=icon]:overflow-hidden",
                    props["className"]
                )}
                {**attrs}
            />;
    }

    def:pub SidebarGroup(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                data-slot="sidebar-group"
                data-sidebar="group"
                className={cn(
                    "cn-sidebar-group relative flex w-full min-w-0 flex-col",
                    props["className"]
                )}
                {**attrs}
            />;
    }

    def:pub SidebarGroupLabel(props: any) -> JsxElement {
        asChild = props["asChild"] or False;
        Comp = Slot if asChild else "div";
        return
            <Comp
                data-slot="sidebar-group-label"
                data-sidebar="group-label"
                className={cn(
                    "cn-sidebar-group-label flex shrink-0 items-center outline-hidden [&>svg]:shrink-0",
                    props["className"]
                )}
                {**props}
            />;
    }

    def:pub SidebarGroupAction(props: any) -> JsxElement {
        asChild = props["asChild"] or False;
        Comp = Slot if asChild else "button";
        return
            <Comp
                data-slot="sidebar-group-action"
                data-sidebar="group-action"
                className={cn(
                    "cn-sidebar-group-action flex aspect-square items-center justify-center outline-hidden transition-transform group-data-[collapsible=icon]:hidden [&>svg]:shrink-0",
                    props["className"]
                )}
                {**props}
            />;
    }

    def:pub SidebarGroupContent(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                data-slot="sidebar-group-content"
                data-sidebar="group-content"
                className={cn("cn-sidebar-group-content w-full", props["className"])}
                {**attrs}
            />;
    }

    def:pub SidebarMenu(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <ul
                data-slot="sidebar-menu"
                data-sidebar="menu"
                className={cn(
                    "cn-sidebar-menu flex w-full min-w-0 flex-col", props["className"]
                )}
                {**attrs}
            />;
    }

    def:pub SidebarMenuItem(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <li
                data-slot="sidebar-menu-item"
                data-sidebar="menu-item"
                className={cn("group/menu-item relative", props["className"])}
                {**attrs}
            />;
    }

    def:pub SidebarMenuButton(props: any) -> JsxElement {
        asChild = props["asChild"] or False;
        isActive = props["isActive"] or False;
        variant = props["variant"] or "default";
        size = props["size"] or "default";
        tooltip = props["tooltip"];
        ctx: any = useContext(SidebarContext);
        isMobile = ctx.isMobile if ctx else False;
        state = ctx.state if ctx else "expanded";
        Comp = Slot if asChild else "button";
        btnClass = _sidebarMenuButtonVariants.call(
            None, {variant: variant, size: size}
        );
        button = <Comp
            data-slot="sidebar-menu-button"
            data-sidebar="menu-button"
            data-size={size}
            data-active={isActive}
            className={cn(btnClass, props["className"])}
            {**props}
        />;
        if not tooltip {
            return button;
        }
        tooltipProps = {"children": tooltip} if isinstance(tooltip, str) else tooltip;
        isHidden = state != "collapsed" or isMobile;
        return
            <Tooltip>
                <TooltipTrigger asChild={True}>{button}</TooltipTrigger>
                <TooltipContent
                    side="right"
                    align="center"
                    hidden={isHidden}
                    {**tooltipProps}
                />
            </Tooltip>;
    }

    def:pub SidebarMenuAction(props: any) -> JsxElement {
        asChild = props["asChild"] or False;
        showOnHover = props["showOnHover"] or False;
        Comp = Slot if asChild else "button";
        hoverClass = "peer-data-active/menu-button:text-sidebar-accent-foreground group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100 aria-expanded:opacity-100 md:opacity-0"
            if showOnHover
            else "";
        return
            <Comp
                data-slot="sidebar-menu-action"
                data-sidebar="menu-action"
                className={cn(
                    "cn-sidebar-menu-action flex items-center justify-center outline-hidden transition-transform group-data-[collapsible=icon]:hidden [&>svg]:shrink-0",
                    hoverClass,
                    props["className"]
                )}
                {**props}
            />;
    }

    def:pub SidebarMenuBadge(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <div
                data-slot="sidebar-menu-badge"
                data-sidebar="menu-badge"
                className={cn(
                    "cn-sidebar-menu-badge flex items-center justify-center tabular-nums select-none group-data-[collapsible=icon]:hidden",
                    props["className"]
                )}
                {**attrs}
            />;
    }

    def:pub SidebarMenuSkeleton(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        showIcon = props["showIcon"] or False;
        widthState = useState(
            lambda -> any { return f"{int(
                Math.random() * 40 + 50
            )}%"; }  # jac:ignore[W6001]
        );
        width = widthState[0];
        skeletonStyle = {"--skeleton-width": width};
        return
            <div
                data-slot="sidebar-menu-skeleton"
                data-sidebar="menu-skeleton"
                className={cn(
                    "cn-sidebar-menu-skeleton flex items-center", props["className"]
                )}
                {**attrs}
            >
                {showIcon
                and (
                    <Skeleton
                        className="cn-sidebar-menu-skeleton-icon"
                        data-sidebar="menu-skeleton-icon"
                    />
                )}
                <Skeleton
                    className="cn-sidebar-menu-skeleton-text max-w-(--skeleton-width) flex-1"
                    data-sidebar="menu-skeleton-text"
                    style={skeletonStyle}
                />
            </div>;
    }

    def:pub SidebarMenuSub(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <ul
                data-slot="sidebar-menu-sub"
                data-sidebar="menu-sub"
                className={cn(
                    "cn-sidebar-menu-sub flex min-w-0 flex-col", props["className"]
                )}
                {**attrs}
            />;
    }

    def:pub SidebarMenuSubItem(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <li
                data-slot="sidebar-menu-sub-item"
                data-sidebar="menu-sub-item"
                className={cn("group/menu-sub-item relative", props["className"])}
                {**attrs}
            />;
    }

    def:pub SidebarMenuSubButton(props: any) -> JsxElement {
        asChild = props["asChild"] or False;
        size = props["size"] or "md";
        isActive = props["isActive"] or False;
        Comp = Slot if asChild else "a";
        return
            <Comp
                data-slot="sidebar-menu-sub-button"
                data-sidebar="menu-sub-button"
                data-size={size}
                data-active={isActive}
                className={cn(
                    "cn-sidebar-menu-sub-button flex min-w-0 -translate-x-px items-center overflow-hidden outline-hidden group-data-[collapsible=icon]:hidden disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 [&>span:last-child]:truncate [&>svg]:shrink-0",
                    props["className"]
                )}
                {**props}
            />;
    }
}
