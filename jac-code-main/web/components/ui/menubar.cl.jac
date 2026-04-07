cl import from "radix-ui" { Menubar as MenubarPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Tick02Icon, ArrowRight01Icon }

cl {
    def:pub Menubar(props: Any) -> JsxElement {
        return <MenubarPrimitive.Root
            {...props}
            data-slot="menubar"
            className={cn("bg-background h-8 gap-0.5 rounded-lg border p-[3px] flex items-center", props.className)}
        />;
    }

    def:pub MenubarMenu(props: Any) -> JsxElement {
        return <MenubarPrimitive.Menu data-slot="menubar-menu" {...props} />;
    }

    def:pub MenubarGroup(props: Any) -> JsxElement {
        return <MenubarPrimitive.Group data-slot="menubar-group" {...props} />;
    }

    def:pub MenubarPortal(props: Any) -> JsxElement {
        return <MenubarPrimitive.Portal data-slot="menubar-portal" {...props} />;
    }

    def:pub MenubarRadioGroup(props: Any) -> JsxElement {
        return <MenubarPrimitive.RadioGroup data-slot="menubar-radio-group" {...props} />;
    }

    def:pub MenubarTrigger(props: Any) -> JsxElement {
        return <MenubarPrimitive.Trigger
            {...props}
            data-slot="menubar-trigger"
            className={cn("hover:bg-muted aria-expanded:bg-muted rounded-sm px-1.5 py-[2px] text-sm font-medium flex items-center outline-hidden select-none", props.className)}
        />;
    }

    def:pub MenubarContent(props: Any) -> JsxElement {
        align = props.align or "start";
        alignOffset = props.alignOffset or -4;
        sideOffset = props.sideOffset or 8;
        return <MenubarPrimitive.Portal>
            <MenubarPrimitive.Content
                {...props}
                data-slot="menubar-content"
                align={align}
                alignOffset={alignOffset}
                sideOffset={sideOffset}
                className={cn("bg-popover text-popover-foreground data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 min-w-36 rounded-lg p-1 shadow-md ring-1 duration-100 cn-menu-target z-50 origin-(--radix-menubar-content-transform-origin) overflow-hidden", props.className)}
            />
        </MenubarPrimitive.Portal>;
    }

    def:pub MenubarItem(props: Any) -> JsxElement {
        variant = props.variant or "default";
        return <MenubarPrimitive.Item
            {...props}
            data-slot="menubar-item"
            data-inset={props.inset}
            data-variant={variant}
            className={cn("focus:bg-accent focus:text-accent-foreground data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 dark:data-[variant=destructive]:focus:bg-destructive/20 data-[variant=destructive]:focus:text-destructive data-[variant=destructive]:*:[svg]:text-destructive! not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-disabled:opacity-50 data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 group/menubar-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        />;
    }

    def:pub MenubarCheckboxItem(props: Any) -> JsxElement {
        return <MenubarPrimitive.CheckboxItem
            {...props}
            data-slot="menubar-checkbox-item"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-1.5 pl-7 text-sm data-inset:pl-7 relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
            checked={props.checked}
        >
            <span className="left-1.5 size-4 [&_svg:not([class*='size-'])]:size-4 pointer-events-none absolute flex items-center justify-center">
                <MenubarPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
                </MenubarPrimitive.ItemIndicator>
            </span>
            {props.children}
        </MenubarPrimitive.CheckboxItem>;
    }

    def:pub MenubarRadioItem(props: Any) -> JsxElement {
        return <MenubarPrimitive.RadioItem
            {...props}
            data-slot="menubar-radio-item"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-1.5 pl-7 text-sm data-disabled:opacity-50 data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        >
            <span className="left-1.5 size-4 [&_svg:not([class*='size-'])]:size-4 pointer-events-none absolute flex items-center justify-center">
                <MenubarPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
                </MenubarPrimitive.ItemIndicator>
            </span>
            {props.children}
        </MenubarPrimitive.RadioItem>;
    }

    def:pub MenubarLabel(props: Any) -> JsxElement {
        return <MenubarPrimitive.Label
            {...props}
            data-slot="menubar-label"
            data-inset={props.inset}
            className={cn("px-1.5 py-1 text-sm font-medium data-inset:pl-7", props.className)}
        />;
    }

    def:pub MenubarSeparator(props: Any) -> JsxElement {
        return <MenubarPrimitive.Separator
            {...props}
            data-slot="menubar-separator"
            className={cn("bg-border -mx-1 my-1 h-px", props.className)}
        />;
    }

    def:pub MenubarShortcut(props: Any) -> JsxElement {
        return <span
            {...props}
            data-slot="menubar-shortcut"
            className={cn("text-muted-foreground group-focus/menubar-item:text-accent-foreground text-xs tracking-widest ml-auto", props.className)}
        />;
    }

    def:pub MenubarSub(props: Any) -> JsxElement {
        return <MenubarPrimitive.Sub data-slot="menubar-sub" {...props} />;
    }

    def:pub MenubarSubTrigger(props: Any) -> JsxElement {
        return <MenubarPrimitive.SubTrigger
            {...props}
            data-slot="menubar-sub-trigger"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground data-open:bg-accent data-open:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 flex cursor-default items-center outline-none select-none", props.className)}
        >
            {props.children}
            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="cn-rtl-flip ml-auto size-4" />
        </MenubarPrimitive.SubTrigger>;
    }

    def:pub MenubarSubContent(props: Any) -> JsxElement {
        return <MenubarPrimitive.SubContent
            {...props}
            data-slot="menubar-sub-content"
            className={cn("bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 min-w-32 rounded-lg p-1 shadow-lg ring-1 duration-100 cn-menu-target z-50 origin-(--radix-menubar-content-transform-origin) overflow-hidden", props.className)}
        />;
    }
}
