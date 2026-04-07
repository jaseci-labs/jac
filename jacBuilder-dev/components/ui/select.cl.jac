cl import from "radix-ui" { Select as SelectPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { UnfoldMoreIcon, Tick02Icon, ArrowUpIcon, ArrowDownIcon }

cl {
    def:pub Select(props: Any) -> JsxElement {
        return <SelectPrimitive.Root data-slot="select" {...props} />;
    }

    def:pub SelectGroup(props: Any) -> JsxElement {
        return <SelectPrimitive.Group
            {...props}
            data-slot="select-group"
            className={cn("scroll-my-1 p-1 scroll-my-1 p-1", props.className)}
        />;
    }

    def:pub SelectValue(props: Any) -> JsxElement {
        return <SelectPrimitive.Value data-slot="select-value" className={cn("flex flex-1 text-left", props.className)} {...props} />;
    }

    def:pub SelectTrigger(props: Any) -> JsxElement {
        size = props.size or "default";
        return <SelectPrimitive.Trigger
            {...props}
            data-slot="select-trigger"
            data-size={size}
            className={cn("border-input data-placeholder:text-muted-foreground dark:bg-input/30 dark:hover:bg-input/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 gap-1.5 rounded-lg border bg-transparent py-2 pr-2 pl-2.5 text-sm transition-colors select-none focus-visible:ring-3 aria-invalid:ring-3 data-[size=default]:h-8 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] *:data-[slot=select-value]:flex *:data-[slot=select-value]:gap-1.5 [&_svg:not([class*='size-'])]:size-4 border-input data-placeholder:text-muted-foreground dark:bg-input/30 dark:hover:bg-input/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 gap-1.5 rounded-lg border bg-transparent py-2 pr-2 pl-2.5 text-sm transition-colors select-none focus-visible:ring-3 aria-invalid:ring-3 data-[size=default]:h-8 data-[size=sm]:h-7 data-[size=sm]:rounded-[min(var(--radius-md),10px)] *:data-[slot=select-value]:gap-1.5 [&_svg:not([class*='size-'])]:size-4 flex w-fit items-center justify-between whitespace-nowrap outline-none disabled:cursor-not-allowed disabled:opacity-50 *:data-[slot=select-value]:line-clamp-1 *:data-[slot=select-value]:flex *:data-[slot=select-value]:items-center [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        >
            {props.children}
            <SelectPrimitive.Icon asChild={True}>
                <HugeiconsIcon icon={UnfoldMoreIcon} strokeWidth={2} className="text-muted-foreground size-4 pointer-events-none" />
            </SelectPrimitive.Icon>
        </SelectPrimitive.Trigger>;
    }

    def:pub SelectContent(props: Any) -> JsxElement {
        position = props.position or "item-aligned";
        align = props.align or "center";
        popperClass = "";
        if position == "popper" {
            popperClass = "data-[side=bottom]:translate-y-1 data-[side=left]:-translate-x-1 data-[side=right]:translate-x-1 data-[side=top]:-translate-y-1";
        }
        return <SelectPrimitive.Portal>
            <SelectPrimitive.Content
                {...props}
                data-slot="select-content"
                data-align-trigger={position == "item-aligned"}
                className={cn("bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 min-w-36 rounded-lg shadow-md ring-1 duration-100 bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 min-w-36 rounded-lg shadow-md ring-1 duration-100 relative z-50 max-h-(--radix-select-content-available-height) origin-(--radix-select-content-transform-origin) overflow-x-hidden overflow-y-auto data-[align-trigger=true]:animate-none", popperClass, props.className)}
                position={position}
                align={align}
            >
                <SelectScrollUpButton />
                <SelectPrimitive.Viewport
                    data-position={position}
                    className={cn("data-[position=popper]:h-(--radix-select-trigger-height) data-[position=popper]:w-full data-[position=popper]:min-w-(--radix-select-trigger-width)")}
                >
                    {props.children}
                </SelectPrimitive.Viewport>
                <SelectScrollDownButton />
            </SelectPrimitive.Content>
        </SelectPrimitive.Portal>;
    }

    def:pub SelectLabel(props: Any) -> JsxElement {
        return <SelectPrimitive.Label
            {...props}
            data-slot="select-label"
            className={cn("text-muted-foreground px-1.5 py-1 text-xs text-muted-foreground px-1.5 py-1 text-xs", props.className)}
        />;
    }

    def:pub SelectItem(props: Any) -> JsxElement {
        return <SelectPrimitive.Item
            {...props}
            data-slot="select-item"
            className={cn("focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm [&_svg:not([class*='size-'])]:size-4 *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2 focus:bg-accent focus:text-accent-foreground not-data-[variant=destructive]:focus:**:text-accent-foreground gap-1.5 rounded-md py-1 pr-8 pl-1.5 text-sm [&_svg:not([class*='size-'])]:size-4 *:[span]:last:flex *:[span]:last:items-center *:[span]:last:gap-2 relative flex w-full cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        >
            <span className="pointer-events-none absolute right-2 flex size-4 items-center justify-center">
                <SelectPrimitive.ItemIndicator>
                    <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="pointer-events-none" />
                </SelectPrimitive.ItemIndicator>
            </span>
            <SelectPrimitive.ItemText>{props.children}</SelectPrimitive.ItemText>
        </SelectPrimitive.Item>;
    }

    def:pub SelectSeparator(props: Any) -> JsxElement {
        return <SelectPrimitive.Separator
            {...props}
            data-slot="select-separator"
            className={cn("bg-border -mx-1 my-1 h-px bg-border -mx-1 my-1 h-px pointer-events-none", props.className)}
        />;
    }

    def:pub SelectScrollUpButton(props: Any) -> JsxElement {
        return <SelectPrimitive.ScrollUpButton
            {...props}
            data-slot="select-scroll-up-button"
            className={cn("bg-popover z-10 flex cursor-default items-center justify-center py-1 [&_svg:not([class*='size-'])]:size-4", props.className)}
        >
            <HugeiconsIcon icon={ArrowUpIcon} strokeWidth={2} />
        </SelectPrimitive.ScrollUpButton>;
    }

    def:pub SelectScrollDownButton(props: Any) -> JsxElement {
        return <SelectPrimitive.ScrollDownButton
            {...props}
            data-slot="select-scroll-down-button"
            className={cn("bg-popover z-10 flex cursor-default items-center justify-center py-1 [&_svg:not([class*='size-'])]:size-4", props.className)}
        >
            <HugeiconsIcon icon={ArrowDownIcon} strokeWidth={2} />
        </SelectPrimitive.ScrollDownButton>;
    }
}
