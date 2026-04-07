cl import from "radix-ui" { DropdownMenu as DropdownMenuPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Tick02Icon, ArrowRight01Icon }

cl {
    def:pub DropdownMenu(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.Root data-slot="dropdown-menu" {...props} />;
    }

    def:pub DropdownMenuPortal(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.Portal data-slot="dropdown-menu-portal" {...props} />;
    }

    def:pub DropdownMenuTrigger(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.Trigger data-slot="dropdown-menu-trigger" {...props} />;
    }

    def:pub DropdownMenuContent(props: Any) -> JsxElement {
        align = props.align or "start";
        sideOffset = props.sideOffset or 4;
        return <DropdownMenuPrimitive.Portal>
            <DropdownMenuPrimitive.Content
                {...props}
                data-slot="dropdown-menu-content"
                sideOffset={sideOffset}
                align={align}
                className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-32 rounded-lg p-1 shadow-md ring-1 duration-100 cn-menu-target no-scrollbar data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-32 rounded-lg p-1 shadow-md ring-1 duration-100 z-50 max-h-(--radix-dropdown-menu-content-available-height) w-(--radix-dropdown-menu-trigger-width) origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto data-[state=closed]:overflow-hidden", props.className)}
            />
        </DropdownMenuPrimitive.Portal>;
    }

    def:pub DropdownMenuGroup(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.Group data-slot="dropdown-menu-group" {...props} />;
    }

    def:pub DropdownMenuItem(props: Any) -> JsxElement {
        variant = props.variant or "default";
        return <DropdownMenuPrimitive.Item
            {...props}
            data-slot="dropdown-menu-item"
            data-inset={props.inset}
            data-variant={variant}
            className={cn("focus:bg-accent focus:text-accent-foreground data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 dark:data-[variant=destructive]:focus:bg-destructive/20 data-[variant=destructive]:focus:text-destructive data-[variant=destructive]:*:[svg]:text-destructive not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 focus:bg-accent focus:text-accent-foreground data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 dark:data-[variant=destructive]:focus:bg-destructive/20 data-[variant=destructive]:focus:text-destructive data-[variant=destructive]:*:[svg]:text-destructive not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 group/dropdown-menu-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        />;
    }

    def:pub DropdownMenuCheckboxItem(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.CheckboxItem
            {...props}
            data-slot="dropdown-menu-checkbox-item"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
            checked={props.checked}
        >
            <span className="absolute right-2 flex items-center justify-center pointer-events-none" data-slot="dropdown-menu-checkbox-item-indicator">
                <DropdownMenuPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
                </DropdownMenuPrimitive.ItemIndicator>
            </span>
            {props.children}
        </DropdownMenuPrimitive.CheckboxItem>;
    }

    def:pub DropdownMenuRadioGroup(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.RadioGroup data-slot="dropdown-menu-radio-group" {...props} />;
    }

    def:pub DropdownMenuRadioItem(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.RadioItem
            {...props}
            data-slot="dropdown-menu-radio-item"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        >
            <span className="absolute right-2 flex items-center justify-center pointer-events-none" data-slot="dropdown-menu-radio-item-indicator">
                <DropdownMenuPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
                </DropdownMenuPrimitive.ItemIndicator>
            </span>
            {props.children}
        </DropdownMenuPrimitive.RadioItem>;
    }

    def:pub DropdownMenuLabel(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.Label
            {...props}
            data-slot="dropdown-menu-label"
            data-inset={props.inset}
            className={cn("text-muted-foreground px-1.5 py-1 text-xs font-medium data-inset:pl-7 text-muted-foreground px-1.5 py-1 text-xs font-medium data-inset:pl-7", props.className)}
        />;
    }

    def:pub DropdownMenuSeparator(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.Separator
            {...props}
            data-slot="dropdown-menu-separator"
            className={cn("bg-border -mx-1 my-1 h-px bg-border -mx-1 my-1 h-px", props.className)}
        />;
    }

    def:pub DropdownMenuShortcut(props: Any) -> JsxElement {
        return <span
            {...props}
            data-slot="dropdown-menu-shortcut"
            className={cn("text-muted-foreground group-focus/dropdown-menu-item:text-accent-foreground ml-auto text-xs tracking-widest text-muted-foreground group-focus/dropdown-menu-item:text-accent-foreground ml-auto text-xs tracking-widest", props.className)}
        />;
    }

    def:pub DropdownMenuSub(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.Sub data-slot="dropdown-menu-sub" {...props} />;
    }

    def:pub DropdownMenuSubTrigger(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.SubTrigger
            {...props}
            data-slot="dropdown-menu-sub-trigger"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground data-open:bg-accent data-open:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 focus:bg-accent focus:text-accent-foreground data-open:bg-accent data-open:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 flex cursor-default items-center outline-hidden select-none [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        >
            {props.children}
            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="ml-auto" />
        </DropdownMenuPrimitive.SubTrigger>;
    }

    def:pub DropdownMenuSubContent(props: Any) -> JsxElement {
        return <DropdownMenuPrimitive.SubContent
            {...props}
            data-slot="dropdown-menu-sub-content"
            className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-[96px] rounded-lg p-1 shadow-lg ring-1 duration-100 data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-[96px] rounded-lg p-1 shadow-lg ring-1 duration-100 z-50 origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden", props.className)}
        />;
    }
}
