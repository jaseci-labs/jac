cl import from "radix-ui" { ContextMenu as ContextMenuPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Tick02Icon, ArrowRight01Icon }

cl {
    def:pub ContextMenu(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.Root data-slot="context-menu" {...props} />;
    }

    def:pub ContextMenuTrigger(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.Trigger
            {...props}
            data-slot="context-menu-trigger"
            className={cn("cn-context-menu-trigger select-none", props.className)}
        />;
    }

    def:pub ContextMenuGroup(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.Group data-slot="context-menu-group" {...props} />;
    }

    def:pub ContextMenuPortal(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.Portal data-slot="context-menu-portal" {...props} />;
    }

    def:pub ContextMenuSub(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.Sub data-slot="context-menu-sub" {...props} />;
    }

    def:pub ContextMenuRadioGroup(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.RadioGroup data-slot="context-menu-radio-group" {...props} />;
    }

    def:pub ContextMenuContent(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.Portal>
            <ContextMenuPrimitive.Content
                {...props}
                data-slot="context-menu-content"
                className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 bg-popover text-popover-foreground min-w-36 rounded-lg p-1 shadow-md ring-1 duration-100 cn-menu-target z-50 max-h-(--radix-context-menu-content-available-height) origin-(--radix-context-menu-content-transform-origin) overflow-x-hidden overflow-y-auto", props.className)}
            />
        </ContextMenuPrimitive.Portal>;
    }

    def:pub ContextMenuItem(props: Any) -> JsxElement {
        variant = props.variant or "default";
        return <ContextMenuPrimitive.Item
            {...props}
            data-slot="context-menu-item"
            data-inset={props.inset}
            data-variant={variant}
            className={cn("focus:bg-accent focus:text-accent-foreground data-[variant=destructive]:text-destructive data-[variant=destructive]:focus:bg-destructive/10 dark:data-[variant=destructive]:focus:bg-destructive/20 data-[variant=destructive]:focus:text-destructive data-[variant=destructive]:*:[svg]:text-destructive focus:*:[svg]:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 group/context-menu-item relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        />;
    }

    def:pub ContextMenuSubTrigger(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.SubTrigger
            {...props}
            data-slot="context-menu-sub-trigger"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground data-open:bg-accent data-open:text-accent-foreground gap-1.5 rounded-md px-1.5 py-1 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 flex cursor-default items-center outline-hidden select-none [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        >
            {props.children}
            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} className="cn-rtl-flip ml-auto" />
        </ContextMenuPrimitive.SubTrigger>;
    }

    def:pub ContextMenuSubContent(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.SubContent
            {...props}
            data-slot="context-menu-sub-content"
            className={cn("data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 bg-popover text-popover-foreground min-w-32 rounded-lg border p-1 shadow-lg duration-100 cn-menu-target z-50 origin-(--radix-context-menu-content-transform-origin) overflow-hidden", props.className)}
        />;
    }

    def:pub ContextMenuCheckboxItem(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.CheckboxItem
            {...props}
            data-slot="context-menu-checkbox-item"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
            checked={props.checked}
        >
            <span className="absolute right-2 pointer-events-none">
                <ContextMenuPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
                </ContextMenuPrimitive.ItemIndicator>
            </span>
            {props.children}
        </ContextMenuPrimitive.CheckboxItem>;
    }

    def:pub ContextMenuRadioItem(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.RadioItem
            {...props}
            data-slot="context-menu-radio-item"
            data-inset={props.inset}
            className={cn("focus:bg-accent focus:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm data-inset:pl-7 [&_svg:not([class*='size-'])]:size-4 relative flex cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        >
            <span className="absolute right-2 pointer-events-none">
                <ContextMenuPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
                </ContextMenuPrimitive.ItemIndicator>
            </span>
            {props.children}
        </ContextMenuPrimitive.RadioItem>;
    }

    def:pub ContextMenuLabel(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.Label
            {...props}
            data-slot="context-menu-label"
            data-inset={props.inset}
            className={cn("text-muted-foreground px-1.5 py-1 text-xs font-medium data-inset:pl-7", props.className)}
        />;
    }

    def:pub ContextMenuSeparator(props: Any) -> JsxElement {
        return <ContextMenuPrimitive.Separator
            {...props}
            data-slot="context-menu-separator"
            className={cn("bg-border -mx-1 my-1 h-px", props.className)}
        />;
    }

    def:pub ContextMenuShortcut(props: Any) -> JsxElement {
        return <span
            {...props}
            data-slot="context-menu-shortcut"
            className={cn("text-muted-foreground group-focus/context-menu-item:text-accent-foreground ml-auto text-xs tracking-widest", props.className)}
        />;
    }
}
