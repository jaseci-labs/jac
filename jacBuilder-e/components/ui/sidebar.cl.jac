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

glob SIDEBAR_COOKIE_NAME: Any = "sidebar_state";
glob SIDEBAR_COOKIE_MAX_AGE: Any = 604800;
glob SIDEBAR_WIDTH: Any = "16rem";
glob SIDEBAR_WIDTH_MOBILE: Any = "18rem";
glob SIDEBAR_WIDTH_ICON: Any = "3rem";
glob SIDEBAR_KEYBOARD_SHORTCUT: Any = "b";

glob SidebarContext: Any = createContext(null);

glob _sidebarMenuButtonVariants: Any = cva.call(None, [
    "ring-sidebar-ring hover:bg-sidebar-accent hover:text-sidebar-accent-foreground active:bg-sidebar-accent active:text-sidebar-accent-foreground data-active:bg-sidebar-accent data-active:text-sidebar-accent-foreground data-open:hover:bg-sidebar-accent data-open:hover:text-sidebar-accent-foreground gap-2 rounded-md p-2 text-left text-sm transition-[width,height,padding] group-has-data-[sidebar=menu-action]/menu-item:pr-8 group-data-[collapsible=icon]:size-8! group-data-[collapsible=icon]:p-2! focus-visible:ring-2 data-active:font-medium peer/menu-button flex w-full items-center overflow-hidden outline-hidden group/menu-button disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 [&>span:last-child]:truncate [&_svg]:size-4 [&_svg]:shrink-0",
    {
        variants: {
            variant: {
                default: "hover:bg-sidebar-accent hover:text-sidebar-accent-foreground",
                outline: "bg-background hover:bg-sidebar-accent hover:text-sidebar-accent-foreground shadow-[0_0_0_1px_hsl(var(--sidebar-border))] hover:shadow-[0_0_0_1px_hsl(var(--sidebar-accent))]"
            },
            size: {
                default: "h-8 text-sm",
                sm: "h-7 text-xs",
                lg: "h-12 text-sm group-data-[collapsible=icon]:p-0!"
            }
        },
        defaultVariants: {variant: "default", size: "default"}
    }
]);

cl {
    def useIsMobile() -> Any {
        isMobileState = useState(false);
        isMobile = isMobileState[0];
        setIsMobile = isMobileState[1];
        useEffect(lambda -> Any {
            mql = window.matchMedia("(max-width: 767px)");
            onChange = lambda -> Any { setIsMobile(window.innerWidth < 768); return None; };
            mql.addEventListener("change", onChange);
            setIsMobile(window.innerWidth < 768);
            return lambda -> Any { mql.removeEventListener("change", onChange); return None; };
        }, []);
        return isMobile;
    }

    def:pub useSidebar() -> Any {
        ctx = useContext(SidebarContext);
        return ctx;
    }

    def:pub SidebarProvider(props: Any) -> JsxElement {
        defaultOpen = props.defaultOpen or true;
        openProp = props.open;
        setOpenProp = props.onOpenChange;
        isMobile = useIsMobile();
        openMobileState = useState(false);
        openMobile = openMobileState[0];
        setOpenMobile = openMobileState[1];
        openState = useState(defaultOpen);
        _open = openState[0];
        _setOpen = openState[1];
        open = openProp or _open;
        setOpen = useCallback(lambda(value: Any) -> Any {
            nextState = value(open) if callable(value) else value;
            if setOpenProp { setOpenProp(nextState); } else { _setOpen(nextState); }
            document.cookie = SIDEBAR_COOKIE_NAME + "=" + nextState + "; path=/; max-age=" + SIDEBAR_COOKIE_MAX_AGE;
        }, [setOpenProp, open]);
        toggleSidebar = useCallback(lambda -> Any {
            isMobile and setOpenMobile(lambda(prev: Any) -> Any { return not prev; });
            isMobile or setOpen(lambda(prev: Any) -> Any { return not prev; });
        }, [isMobile, setOpen, setOpenMobile]);
        useEffect(lambda -> Any {
            handleKeyDown = lambda(event: Any) -> Any {
                if event.key == SIDEBAR_KEYBOARD_SHORTCUT and (event.metaKey or event.ctrlKey) {
                    event.preventDefault();
                    toggleSidebar();
                }
            };
            window.addEventListener("keydown", handleKeyDown);
            return lambda -> Any { window.removeEventListener("keydown", handleKeyDown); };
        }, [toggleSidebar]);
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
        mergedStyle = {"--sidebar-width": SIDEBAR_WIDTH, "--sidebar-width-icon": SIDEBAR_WIDTH_ICON};
        return <SidebarContext.Provider value={ctxValue}>
            <div
                data-slot="sidebar-wrapper"
                style={mergedStyle}
                className={cn("group/sidebar-wrapper has-data-[variant=inset]:bg-sidebar flex min-h-svh w-full", props.className)}
                {...props}
            >
                {props.children}
            </div>
        </SidebarContext.Provider>;
    }

    def:pub Sidebar(props: Any) -> JsxElement {
        side = props.side or "left";
        variant = props.variant or "sidebar";
        collapsible = props.collapsible or "offcanvas";
        ctx = useContext(SidebarContext);
        isMobile = ctx.isMobile if ctx else false;
        state = ctx.state if ctx else "expanded";
        openMobile = ctx.openMobile if ctx else false;
        setOpenMobile = ctx.setOpenMobile if ctx else None;
        isFloating = variant == "floating" or variant == "inset";
        containerClass = "p-2 group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4))+2px)]" if isFloating else "group-data-[collapsible=icon]:w-(--sidebar-width-icon) group-data-[side=left]:border-r group-data-[side=right]:border-l";
        if collapsible == "none" {
            return <div
                data-slot="sidebar"
                className={cn("bg-sidebar text-sidebar-foreground flex h-full w-(--sidebar-width) flex-col", props.className)}
                {...props}
            >
                {props.children}
            </div>;
        } elif isMobile {
            mobileStyle = {"--sidebar-width": SIDEBAR_WIDTH_MOBILE};
            return <Sheet open={openMobile} onOpenChange={setOpenMobile} {...props}>
                <SheetContent
                    dir={props.dir}
                    data-sidebar="sidebar"
                    data-slot="sidebar"
                    data-mobile="true"
                    className="bg-sidebar text-sidebar-foreground w-(--sidebar-width) p-0 [&>button]:hidden"
                    style={mobileStyle}
                    side={side}
                >
                    <SheetHeader className="sr-only">
                        <SheetTitle>Sidebar</SheetTitle>
                        <SheetDescription>Displays the mobile sidebar.</SheetDescription>
                    </SheetHeader>
                    <div className="flex h-full w-full flex-col">{props.children}</div>
                </SheetContent>
            </Sheet>;
        } else {
            return <div
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
                        "transition-[width] duration-200 ease-linear relative w-(--sidebar-width) bg-transparent",
                        "group-data-[collapsible=offcanvas]:w-0",
                        "group-data-[side=right]:rotate-180",
                        "group-data-[collapsible=icon]:w-[calc(var(--sidebar-width-icon)+(--spacing(4)))]" if isFloating else "group-data-[collapsible=icon]:w-(--sidebar-width-icon)"
                    )}
                />
                <div
                    data-slot="sidebar-container"
                    data-side={side}
                    className={cn(
                        "fixed inset-y-0 z-10 hidden h-svh w-(--sidebar-width) transition-[left,right,width] duration-200 ease-linear data-[side=left]:left-0 data-[side=left]:group-data-[collapsible=offcanvas]:left-[calc(var(--sidebar-width)*-1)] data-[side=right]:right-0 data-[side=right]:group-data-[collapsible=offcanvas]:right-[calc(var(--sidebar-width)*-1)] md:flex",
                        containerClass,
                        props.className
                    )}
                    {...props}
                >
                    <div data-sidebar="sidebar" data-slot="sidebar-inner" className="bg-sidebar group-data-[variant=floating]:ring-sidebar-border group-data-[variant=floating]:rounded-lg group-data-[variant=floating]:shadow-sm group-data-[variant=floating]:ring-1 flex size-full flex-col">
                        {props.children}
                    </div>
                </div>
            </div>;
        }
    }

    def:pub SidebarTrigger(props: Any) -> JsxElement {
        ctx = useContext(SidebarContext);
        toggleSidebar = ctx.toggleSidebar if ctx else None;
        handleClick = lambda(event: Any) -> Any {
            props.onClick and props.onClick(event);
            toggleSidebar and toggleSidebar();
        };
        return <Button
            data-sidebar="trigger"
            data-slot="sidebar-trigger"
            variant="ghost"
            size="icon-sm"
            className={cn("cn-sidebar-trigger", props.className)}
            onClick={handleClick}
            {...props}
        >
            <HugeiconsIcon icon={SidebarLeftIcon} className="cn-rtl-flip" size={16} />
            <span className="sr-only">Toggle Sidebar</span>
        </Button>;
    }

    def:pub SidebarRail(props: Any) -> JsxElement {
        ctx = useContext(SidebarContext);
        toggleSidebar = ctx.toggleSidebar if ctx else None;
        return <button
            data-sidebar="rail"
            data-slot="sidebar-rail"
            aria-label="Toggle Sidebar"
            tabIndex={-1}
            onClick={toggleSidebar}
            title="Toggle Sidebar"
            className={cn(
                "hover:after:bg-sidebar-border absolute inset-y-0 z-20 hidden w-4 transition-all ease-linear group-data-[side=left]:-right-4 group-data-[side=right]:left-0 after:absolute after:inset-y-0 after:start-1/2 after:w-[2px] sm:flex",
                props.className
            )}
            {...props}
        />;
    }

    def:pub SidebarInset(props: Any) -> JsxElement {
        return <main
            data-slot="sidebar-inset"
            className={cn("bg-background md:peer-data-[variant=inset]:m-2 md:peer-data-[variant=inset]:ml-0 md:peer-data-[variant=inset]:rounded-xl md:peer-data-[variant=inset]:shadow-sm md:peer-data-[variant=inset]:peer-data-[state=collapsed]:ml-2 relative flex w-full flex-1 flex-col", props.className)}
            {...props}
        />;
    }

    def:pub SidebarInput(props: Any) -> JsxElement {
        return <Input
            data-slot="sidebar-input"
            data-sidebar="input"
            className={cn("bg-background h-8 w-full shadow-none", props.className)}
            {...props}
        />;
    }

    def:pub SidebarHeader(props: Any) -> JsxElement {
        return <div
            data-slot="sidebar-header"
            data-sidebar="header"
            className={cn("gap-2 p-2 flex flex-col", props.className)}
            {...props}
        />;
    }

    def:pub SidebarFooter(props: Any) -> JsxElement {
        return <div
            data-slot="sidebar-footer"
            data-sidebar="footer"
            className={cn("gap-2 p-2 flex flex-col", props.className)}
            {...props}
        />;
    }

    def:pub SidebarSeparator(props: Any) -> JsxElement {
        return <Separator
            data-slot="sidebar-separator"
            data-sidebar="separator"
            className={cn("bg-sidebar-border mx-2 w-auto", props.className)}
            {...props}
        />;
    }

    def:pub SidebarContent(props: Any) -> JsxElement {
        return <div
            data-slot="sidebar-content"
            data-sidebar="content"
            className={cn("no-scrollbar gap-0 flex min-h-0 flex-1 flex-col overflow-auto group-data-[collapsible=icon]:overflow-hidden", props.className)}
            {...props}
        />;
    }

    def:pub SidebarGroup(props: Any) -> JsxElement {
        return <div
            data-slot="sidebar-group"
            data-sidebar="group"
            className={cn("p-2 relative flex w-full min-w-0 flex-col", props.className)}
            {...props}
        />;
    }

    def:pub SidebarGroupLabel(props: Any) -> JsxElement {
        asChild = props.asChild or false;
        Comp = Slot if asChild else "div";
        return <Comp
            data-slot="sidebar-group-label"
            data-sidebar="group-label"
            className={cn("text-sidebar-foreground/70 ring-sidebar-ring h-8 rounded-md px-2 text-xs font-medium transition-[margin,opacity] duration-200 ease-linear group-data-[collapsible=icon]:-mt-8 group-data-[collapsible=icon]:opacity-0 focus-visible:ring-2 [&>svg]:size-4 flex shrink-0 items-center outline-hidden [&>svg]:shrink-0", props.className)}
            {...props}
        />;
    }

    def:pub SidebarGroupAction(props: Any) -> JsxElement {
        asChild = props.asChild or false;
        Comp = Slot if asChild else "button";
        return <Comp
            data-slot="sidebar-group-action"
            data-sidebar="group-action"
            className={cn("text-sidebar-foreground ring-sidebar-ring hover:bg-sidebar-accent hover:text-sidebar-accent-foreground absolute top-3.5 right-3 w-5 rounded-md p-0 focus-visible:ring-2 [&>svg]:size-4 flex aspect-square items-center justify-center outline-hidden transition-transform group-data-[collapsible=icon]:hidden [&>svg]:shrink-0", props.className)}
            {...props}
        />;
    }

    def:pub SidebarGroupContent(props: Any) -> JsxElement {
        return <div
            data-slot="sidebar-group-content"
            data-sidebar="group-content"
            className={cn("text-sm w-full", props.className)}
            {...props}
        />;
    }

    def:pub SidebarMenu(props: Any) -> JsxElement {
        return <ul
            data-slot="sidebar-menu"
            data-sidebar="menu"
            className={cn("gap-0 flex w-full min-w-0 flex-col", props.className)}
            {...props}
        />;
    }

    def:pub SidebarMenuItem(props: Any) -> JsxElement {
        return <li
            data-slot="sidebar-menu-item"
            data-sidebar="menu-item"
            className={cn("group/menu-item relative", props.className)}
            {...props}
        />;
    }

    def:pub SidebarMenuButton(props: Any) -> JsxElement {
        asChild = props.asChild or false;
        isActive = props.isActive or false;
        variant = props.variant or "default";
        size = props.size or "default";
        tooltip = props.tooltip;
        ctx = useContext(SidebarContext);
        isMobile = ctx.isMobile if ctx else false;
        state = ctx.state if ctx else "expanded";
        Comp = Slot if asChild else "button";
        btnClass = _sidebarMenuButtonVariants.call(None, {variant: variant, size: size});
        button = <Comp
            data-slot="sidebar-menu-button"
            data-sidebar="menu-button"
            data-size={size}
            data-active={isActive}
            className={cn(btnClass, props.className)}
            {...props}
        />;
        if not tooltip { return button; }
        tooltipProps = {children: tooltip} if (tooltip + "") == tooltip else tooltip;
        isHidden = state != "collapsed" or isMobile;
        return <Tooltip>
            <TooltipTrigger asChild={true}>{button}</TooltipTrigger>
            <TooltipContent side="right" align="center" hidden={isHidden} {...tooltipProps} />
        </Tooltip>;
    }

    def:pub SidebarMenuAction(props: Any) -> JsxElement {
        asChild = props.asChild or false;
        showOnHover = props.showOnHover or false;
        Comp = Slot if asChild else "button";
        hoverClass = "peer-data-active/menu-button:text-sidebar-accent-foreground group-focus-within/menu-item:opacity-100 group-hover/menu-item:opacity-100 aria-expanded:opacity-100 md:opacity-0" if showOnHover else "";
        return <Comp
            data-slot="sidebar-menu-action"
            data-sidebar="menu-action"
            className={cn("text-sidebar-foreground ring-sidebar-ring hover:bg-sidebar-accent hover:text-sidebar-accent-foreground peer-hover/menu-button:text-sidebar-accent-foreground absolute top-1.5 right-1 aspect-square w-5 rounded-md p-0 peer-data-[size=default]/menu-button:top-1.5 peer-data-[size=lg]/menu-button:top-2.5 peer-data-[size=sm]/menu-button:top-1 focus-visible:ring-2 [&>svg]:size-4 flex items-center justify-center outline-hidden transition-transform group-data-[collapsible=icon]:hidden [&>svg]:shrink-0", hoverClass, props.className)}
            {...props}
        />;
    }

    def:pub SidebarMenuBadge(props: Any) -> JsxElement {
        return <div
            data-slot="sidebar-menu-badge"
            data-sidebar="menu-badge"
            className={cn("text-sidebar-foreground peer-hover/menu-button:text-sidebar-accent-foreground peer-data-active/menu-button:text-sidebar-accent-foreground pointer-events-none absolute right-1 flex h-5 min-w-5 rounded-md px-1 text-xs font-medium peer-data-[size=default]/menu-button:top-1.5 peer-data-[size=lg]/menu-button:top-2.5 peer-data-[size=sm]/menu-button:top-1 flex items-center justify-center tabular-nums select-none group-data-[collapsible=icon]:hidden", props.className)}
            {...props}
        />;
    }

    def:pub SidebarMenuSkeleton(props: Any) -> JsxElement {
        showIcon = props.showIcon or false;
        widthState = useState(lambda -> Any { return (Math.floor(Math.random() * 40 + 50)) + "%"; });
        width = widthState[0];
        skeletonStyle = {"--skeleton-width": width};
        return <div
            data-slot="sidebar-menu-skeleton"
            data-sidebar="menu-skeleton"
            className={cn("h-8 gap-2 rounded-md px-2 flex items-center", props.className)}
            {...props}
        >
            {showIcon and (
                <Skeleton className="size-4 rounded-md" data-sidebar="menu-skeleton-icon" />
            )}
            <Skeleton
                className="h-4 max-w-(--skeleton-width) flex-1"
                data-sidebar="menu-skeleton-text"
                style={skeletonStyle}
            />
        </div>;
    }

    def:pub SidebarMenuSub(props: Any) -> JsxElement {
        return <ul
            data-slot="sidebar-menu-sub"
            data-sidebar="menu-sub"
            className={cn("border-sidebar-border mx-3.5 translate-x-px gap-1 border-l px-2.5 py-0.5 group-data-[collapsible=icon]:hidden flex min-w-0 flex-col", props.className)}
            {...props}
        />;
    }

    def:pub SidebarMenuSubItem(props: Any) -> JsxElement {
        return <li
            data-slot="sidebar-menu-sub-item"
            data-sidebar="menu-sub-item"
            className={cn("group/menu-sub-item relative", props.className)}
            {...props}
        />;
    }

    def:pub SidebarMenuSubButton(props: Any) -> JsxElement {
        asChild = props.asChild or false;
        size = props.size or "md";
        isActive = props.isActive or false;
        Comp = Slot if asChild else "a";
        return <Comp
            data-slot="sidebar-menu-sub-button"
            data-sidebar="menu-sub-button"
            data-size={size}
            data-active={isActive}
            className={cn(
                "text-sidebar-foreground ring-sidebar-ring hover:bg-sidebar-accent hover:text-sidebar-accent-foreground active:bg-sidebar-accent active:text-sidebar-accent-foreground [&>svg]:text-sidebar-accent-foreground data-active:bg-sidebar-accent data-active:text-sidebar-accent-foreground h-7 gap-2 rounded-md px-2 focus-visible:ring-2 data-[size=md]:text-sm data-[size=sm]:text-xs [&>svg]:size-4 flex min-w-0 -translate-x-px items-center overflow-hidden outline-hidden group-data-[collapsible=icon]:hidden disabled:pointer-events-none disabled:opacity-50 aria-disabled:pointer-events-none aria-disabled:opacity-50 [&>span:last-child]:truncate [&>svg]:shrink-0",
                props.className
            )}
            {...props}
        />;
    }
}

