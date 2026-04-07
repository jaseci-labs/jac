cl import from "@base-ui/react" { Combobox as ComboboxPrimitive }
cl import from react { useRef }
cl import from ...lib.utils { cn }
cl import from .button { Button }
cl import from ".input-group" { InputGroup, InputGroupAddon, InputGroupButton, InputGroupInput }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowDownIcon, Cancel01Icon, Tick02Icon }

glob _comboboxInputExclude: list = ["className", "children", "disabled", "showTrigger", "showClear"];

cl {
    def:pub Combobox(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Root {...props} />;
    }

    def:pub ComboboxValue(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Value data-slot="combobox-value" {...props} />;
    }

    def:pub ComboboxTrigger(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Trigger
            {...props}
            data-slot="combobox-trigger"
            className={cn("[&_svg:not([class*='size-'])]:size-4", props.className)}
        >
            {props.children}
            <HugeiconsIcon icon={ArrowDownIcon} strokeWidth={2} className="text-muted-foreground size-4 pointer-events-none" />
        </ComboboxPrimitive.Trigger>;
    }

    def:pub ComboboxClear(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Clear
            {...props}
            data-slot="combobox-clear"
            render={<InputGroupButton variant="ghost" size="icon-xs" />}
            className={cn(props.className)}
        >
            <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} className="pointer-events-none" />
        </ComboboxPrimitive.Clear>;
    }

    def:pub ComboboxInput(props: Any) -> JsxElement {
        disabled = props.disabled or False;
        showTrigger = props.showTrigger;
        if showTrigger == None {
            showTrigger = True;
        }
        showClear = props.showClear or False;

        inputProps = {};
        excludeKeys = _comboboxInputExclude;
        Object.keys(props).forEach(lambda(key: Any) -> None {
            if excludeKeys.indexOf(key) == -1 {
                inputProps[key] = props[key];
            }
        });

        return <InputGroup className={cn("w-auto", props.className)}>
            <ComboboxPrimitive.Input
                render={<input
                    data-slot="input-group-control"
                    className="rounded-none border-0 bg-transparent shadow-none ring-0 focus-visible:ring-0 disabled:bg-transparent aria-invalid:ring-0 dark:bg-transparent dark:disabled:bg-transparent rounded-none border-0 bg-transparent shadow-none ring-0 focus-visible:ring-0 disabled:bg-transparent aria-invalid:ring-0 dark:bg-transparent dark:disabled:bg-transparent flex-1 text-base md:text-sm placeholder:text-muted-foreground w-full min-w-0 outline-none px-2.5 py-1"
                    disabled={disabled}
                />}
                {...inputProps}
            />
            <InputGroupAddon align="inline-end">
                {showTrigger and (
                    <InputGroupButton
                        size="icon-xs"
                        variant="ghost"
                        asChild={True}
                        data-slot="input-group-button"
                        className="group-has-data-[slot=combobox-clear]/input-group:hidden data-pressed:bg-transparent"
                        disabled={disabled}
                    >
                        <ComboboxTrigger />
                    </InputGroupButton>
                )}
                {showClear and <ComboboxClear disabled={disabled} />}
            </InputGroupAddon>
            {props.children}
        </InputGroup>;
    }

    def:pub ComboboxContent(props: Any) -> JsxElement {
        side = props.side or "bottom";
        sideOffset = props.sideOffset or 6;
        align = props.align or "start";
        alignOffset = props.alignOffset or 0;
        anchor = props.anchor;
        return <ComboboxPrimitive.Portal>
            <ComboboxPrimitive.Positioner
                side={side}
                sideOffset={sideOffset}
                align={align}
                alignOffset={alignOffset}
                anchor={anchor}
                className="isolate z-50"
            >
                <ComboboxPrimitive.Popup
                    {...props}
                    data-slot="combobox-content"
                    data-chips={Boolean(anchor)}
                    className={cn("bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 *:data-[slot=input-group]:bg-input/30 *:data-[slot=input-group]:border-input/30 max-h-72 min-w-36 overflow-hidden rounded-lg shadow-md ring-1 duration-100 *:data-[slot=input-group]:m-1 *:data-[slot=input-group]:mb-0 *:data-[slot=input-group]:h-8 *:data-[slot=input-group]:shadow-none bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 *:data-[slot=input-group]:bg-input/30 *:data-[slot=input-group]:border-input/30 overflow-hidden rounded-lg shadow-md ring-1 duration-100 *:data-[slot=input-group]:m-1 *:data-[slot=input-group]:mb-0 *:data-[slot=input-group]:h-8 *:data-[slot=input-group]:shadow-none data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2 group/combobox-content relative max-h-(--available-height) w-(--anchor-width) max-w-(--available-width) min-w-[calc(var(--anchor-width)+--spacing(7))] origin-(--transform-origin) data-[chips=true]:min-w-(--anchor-width)", props.className)}
                />
            </ComboboxPrimitive.Positioner>
        </ComboboxPrimitive.Portal>;
    }

    def:pub ComboboxList(props: Any) -> JsxElement {
        return <ComboboxPrimitive.List
            {...props}
            data-slot="combobox-list"
            className={cn("no-scrollbar max-h-[min(calc(--spacing(72)---spacing(9)),calc(var(--available-height)---spacing(9)))] scroll-py-1 overflow-y-auto p-1 data-empty:p-0 no-scrollbar max-h-[min(calc(--spacing(72)---spacing(9)),calc(var(--available-height)---spacing(9)))] scroll-py-1 p-1 data-empty:p-0 overflow-y-auto overscroll-contain", props.className)}
        />;
    }

    def:pub ComboboxItem(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Item
            {...props}
            data-slot="combobox-item"
            className={cn("data-highlighted:bg-accent data-highlighted:text-accent-foreground not-data-[variant=destructive]:data-highlighted:**:text-accent-foreground gap-2 rounded-md py-1 pr-8 pl-1.5 text-sm [&_svg:not([class*='size-'])]:size-4 data-highlighted:bg-accent data-highlighted:text-accent-foreground not-data-[variant=destructive]:data-highlighted:**:text-accent-foreground gap-2 rounded-md py-1 pr-8 pl-1.5 text-sm [&_svg:not([class*='size-'])]:size-4 relative flex w-full cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0", props.className)}
        >
            {props.children}
            <ComboboxPrimitive.ItemIndicator
                render={<span className="pointer-events-none absolute right-2 flex size-4 items-center justify-center" />}
            >
                <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} className="pointer-events-none" />
            </ComboboxPrimitive.ItemIndicator>
        </ComboboxPrimitive.Item>;
    }

    def:pub ComboboxGroup(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Group
            {...props}
            data-slot="combobox-group"
            className={cn(props.className)}
        />;
    }

    def:pub ComboboxLabel(props: Any) -> JsxElement {
        return <ComboboxPrimitive.GroupLabel
            {...props}
            data-slot="combobox-label"
            className={cn("text-muted-foreground px-2 py-1.5 text-xs", props.className)}
        />;
    }

    def:pub ComboboxCollection(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Collection data-slot="combobox-collection" {...props} />;
    }

    def:pub ComboboxEmpty(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Empty
            {...props}
            data-slot="combobox-empty"
            className={cn("text-muted-foreground hidden w-full justify-center py-2 text-center text-sm group-data-empty/combobox-content:flex text-muted-foreground hidden w-full justify-center py-2 text-center text-sm group-data-empty/combobox-content:flex", props.className)}
        />;
    }

    def:pub ComboboxSeparator(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Separator
            {...props}
            data-slot="combobox-separator"
            className={cn("bg-border -mx-1 my-1 h-px", props.className)}
        />;
    }

    def:pub ComboboxChips(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Chips
            {...props}
            data-slot="combobox-chips"
            className={cn("dark:bg-input/30 border-input focus-within:border-ring focus-within:ring-ring/50 has-aria-invalid:ring-destructive/20 dark:has-aria-invalid:ring-destructive/40 has-aria-invalid:border-destructive dark:has-aria-invalid:border-destructive/50 flex min-h-8 flex-wrap items-center gap-1 rounded-lg border bg-transparent bg-clip-padding px-2.5 py-1 text-sm transition-colors focus-within:ring-3 has-aria-invalid:ring-3 has-data-[slot=combobox-chip]:px-1", props.className)}
        >
            {props.children}
        </ComboboxPrimitive.Chips>;
    }

    def:pub ComboboxChip(props: Any) -> JsxElement {
        showRemove = props.showRemove;
        if showRemove == None {
            showRemove = True;
        }
        return <ComboboxPrimitive.Chip
            {...props}
            data-slot="combobox-chip"
            className={cn("bg-muted text-foreground flex h-[calc(--spacing(5.25))] w-fit items-center justify-center gap-1 rounded-sm px-1.5 text-xs font-medium whitespace-nowrap has-data-[slot=combobox-chip-remove]:pr-0 has-disabled:pointer-events-none has-disabled:cursor-not-allowed has-disabled:opacity-50", props.className)}
        >
            {props.children}
            {showRemove and (
                <ComboboxPrimitive.ChipRemove
                    render={<Button variant="ghost" size="icon-xs" />}
                    className="-ml-1 opacity-50 hover:opacity-100"
                    data-slot="combobox-chip-remove"
                >
                    <HugeiconsIcon icon={Cancel01Icon} strokeWidth={2} className="pointer-events-none" />
                </ComboboxPrimitive.ChipRemove>
            )}
        </ComboboxPrimitive.Chip>;
    }

    def:pub ComboboxChipsInput(props: Any) -> JsxElement {
        return <ComboboxPrimitive.Input
            {...props}
            data-slot="combobox-chip-input"
            className={cn("min-w-16 flex-1 outline-none", props.className)}
        />;
    }

    def:pub useComboboxAnchor() -> Any {
        return useRef(None);
    }
}
