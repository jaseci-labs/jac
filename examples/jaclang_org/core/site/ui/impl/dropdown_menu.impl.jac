impl DropdownMenu(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.Root data-slot="dropdown-menu" {...kwargs} />;
}

impl DropdownMenuPortal(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.Portal data-slot="dropdown-menu-portal" {...kwargs} />;
}

impl DropdownMenuTrigger(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.Trigger data-slot="dropdown-menu-trigger" {...kwargs} />;
}

impl DropdownMenuContent(**kwargs: any) -> JsxElement {
    align = kwargs.get("align") or "start";
    sideOffset = kwargs.get("sideOffset") or 4;
    return <DropdownMenuPrimitive.Portal>
        <DropdownMenuPrimitive.Content
            {...kwargs}
            data-slot="dropdown-menu-content"
            sideOffset={sideOffset}
            align={align}
            className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-32 rounded-lg p-1 shadow-md ring-1 duration-100 cn-menu-target no-scrollbar data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-32 rounded-lg p-1 shadow-md ring-1 duration-100 z-50 max-h-(--radix-dropdown-menu-content-available-height) w-(--radix-dropdown-menu-trigger-width) origin-(--radix-dropdown-menu-content-transform-origin) overflow-x-hidden overflow-y-auto data-[state=closed]:overflow-hidden", kwargs.get("className"))}
        />
    </DropdownMenuPrimitive.Portal>;
}

impl DropdownMenuGroup(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.Group data-slot="dropdown-menu-group" {...kwargs} />;
}

impl DropdownMenuItem(**kwargs: any) -> JsxElement {
    variant = kwargs.get("variant") or "default";
    return <DropdownMenuPrimitive.Item
        {...kwargs}
        data-slot="dropdown-menu-item"
        data-inset={kwargs.get("inset")}
        data-variant={variant}
        className={cn("focus:bg-accent focus:text-accent-foreground data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 dark:data-[variant=destructive]:focus:bg-destructive/20 data-[variant=destructive]:focus:text-destructive data-[variant=destructive]:*:[svg]:text-destructive not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 focus:bg-accent focus:text-accent-foreground data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 dark:data-[variant=destructive]:focus:bg-destructive/20 data-[variant=destructive]:focus:text-destructive data-[variant=destructive]:*:[svg]:text-destructive not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 group/dropdown-menu-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", kwargs.get("className"))}
    />;
}

impl DropdownMenuCheckboxItem(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.CheckboxItem
        {...kwargs}
        data-slot="dropdown-menu-checkbox-item"
        data-inset={kwargs.get("inset")}
        className={cn("focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", kwargs.get("className"))}
        checked={kwargs.get("checked")}
    >
        <span
            className="absolute right-2 flex items-center justify-center pointer-events-none"
            data-slot="dropdown-menu-checkbox-item-indicator"
        >
            <DropdownMenuPrimitive.ItemIndicator>
                <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
            </DropdownMenuPrimitive.ItemIndicator>
        </span>
        {kwargs.get("children")}
    </DropdownMenuPrimitive.CheckboxItem>;
}

impl DropdownMenuRadioGroup(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.RadioGroup data-slot="dropdown-menu-radio-group" {...kwargs} />;
}

impl DropdownMenuRadioItem(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.RadioItem
        {...kwargs}
        data-slot="dropdown-menu-radio-item"
        data-inset={kwargs.get("inset")}
        className={cn("focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 focus:bg-accent focus:text-accent-foreground focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", kwargs.get("className"))}
    >
        <span
            className="absolute right-2 flex items-center justify-center pointer-events-none"
            data-slot="dropdown-menu-radio-item-indicator"
        >
            <DropdownMenuPrimitive.ItemIndicator>
                <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
            </DropdownMenuPrimitive.ItemIndicator>
        </span>
        {kwargs.get("children")}
    </DropdownMenuPrimitive.RadioItem>;
}

impl DropdownMenuLabel(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.Label
        {...kwargs}
        data-slot="dropdown-menu-label"
        data-inset={kwargs.get("inset")}
        className={cn("text-muted-foreground px-1.5 py-1 text-xs font-medium data-inset:pl-7 text-muted-foreground px-1.5 py-1 text-xs font-medium data-inset:pl-7", kwargs.get("className"))}
    />;
}

impl DropdownMenuSeparator(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.Separator
        {...kwargs}
        data-slot="dropdown-menu-separator"
        className={cn("bg-border -mx-1 my-1 h-px bg-border -mx-1 my-1 h-px", kwargs.get("className"))}
    />;
}

impl DropdownMenuShortcut(**kwargs: any) -> JsxElement {
    attrs: dict[str, any] = {**kwargs};
    return <span
        {...attrs}
        data-slot="dropdown-menu-shortcut"
        className={cn("text-muted-foreground group-focus/dropdown-menu-item:text-accent-foreground ml-auto text-xs tracking-widest text-muted-foreground group-focus/dropdown-menu-item:text-accent-foreground ml-auto text-xs tracking-widest", kwargs.get("className"))}
    />;
}

impl DropdownMenuSub(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.Sub data-slot="dropdown-menu-sub" {...kwargs} />;
}

impl DropdownMenuSubTrigger(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.SubTrigger
        {...kwargs}
        data-slot="dropdown-menu-sub-trigger"
        data-inset={kwargs.get("inset")}
        className={cn("focus:bg-accent focus:text-accent-foreground data-open:bg-accent data-open:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 focus:bg-accent focus:text-accent-foreground data-open:bg-accent data-open:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 flex cursor-default items-center outline-hidden select-none [&_svg]:pointer-events-none [&_svg]:shrink-0", kwargs.get("className"))}
    >
        {kwargs.get("children")}
        <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="ml-auto" />
    </DropdownMenuPrimitive.SubTrigger>;
}

impl DropdownMenuSubContent(**kwargs: any) -> JsxElement {
    return <DropdownMenuPrimitive.SubContent
        {...kwargs}
        data-slot="dropdown-menu-sub-content"
        className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-[96px] rounded-lg p-1 shadow-lg ring-1 duration-100 data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-[96px] rounded-lg p-1 shadow-lg ring-1 duration-100 z-50 origin-(--radix-dropdown-menu-content-transform-origin) overflow-hidden", kwargs.get("className"))}
    />;
}
