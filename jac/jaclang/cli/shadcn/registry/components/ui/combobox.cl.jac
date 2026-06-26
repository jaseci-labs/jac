import from "@base-ui/react" { Combobox as ComboboxPrimitive }
import from react { useRef }
import from ...lib.utils { cn }
import from .button { Button }
import from ".input-group" {
    InputGroup,
    InputGroupAddon,
    InputGroupButton,
    InputGroupInput
}
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { ArrowDownIcon, Cancel01Icon, Tick02Icon }

glob _comboboxInputExclude: list[str] = [
         "className",
         "children",
         "disabled",
         "showTrigger",
         "showClear"
     ];

def:pub Combobox(props: any) -> JsxElement {
    return <ComboboxPrimitive.Root {**props}/>;
}

def:pub ComboboxValue(props: any) -> JsxElement {
    return <ComboboxPrimitive.Value data-slot="combobox-value" {**props}/>;
}

def:pub ComboboxTrigger(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.Trigger
            {**props}
            data-slot="combobox-trigger"
            className={cn("[&_svg:not([class*='size-'])]:size-4", props["className"])}
        >
            {props["children"]}
            <HugeiconsIcon
                icon={ArrowDownIcon}
                strokeWidth={2}
                className="text-muted-foreground size-4 pointer-events-none"
            />
        </ComboboxPrimitive.Trigger>;
}

def:pub ComboboxClear(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.Clear
            {**props}
            data-slot="combobox-clear"
            render={<InputGroupButton variant="ghost" size="icon-xs"/>}
            className={cn(props["className"])}
        >
            <HugeiconsIcon
                icon={Cancel01Icon}
                strokeWidth={2}
                className="pointer-events-none"
            />
        </ComboboxPrimitive.Clear>;
}

def:pub ComboboxInput(props: any) -> JsxElement {
    disabled = props["disabled"] or False;
    showTrigger = props["showTrigger"];
    if showTrigger is None {
        showTrigger = True;
    }
    showClear = props["showClear"] or False;

    inputProps = {};
    for key in Object.keys(props) {  # jac:ignore[W6001]
        if key not in _comboboxInputExclude {
            inputProps[key] = props[key];
        }
    }

    return
        <InputGroup className={cn("w-auto", props["className"])}>
            <ComboboxPrimitive.Input
                render={<input
                    data-slot="input-group-control"
                    className="cn-input-group-input rounded-none border-0 bg-transparent shadow-none ring-0 focus-visible:ring-0 disabled:bg-transparent aria-invalid:ring-0 dark:bg-transparent dark:disabled:bg-transparent flex-1 text-base md:text-sm placeholder:text-muted-foreground w-full min-w-0 outline-none px-2.5 py-1"
                    disabled={disabled}
                />}
                {**inputProps}
            />
            <InputGroupAddon align="inline-end">
                {showTrigger
                and (
                    <InputGroupButton
                        size="icon-xs"
                        variant="ghost"
                        asChild={True}
                        data-slot="input-group-button"
                        className="group-has-data-[slot=combobox-clear]/input-group:hidden data-pressed:bg-transparent"
                        disabled={disabled}
                    >
                        <ComboboxTrigger/>
                    </InputGroupButton>
                )}{showClear and <ComboboxClear disabled={disabled}/>}
            </InputGroupAddon>
            {props["children"]}
        </InputGroup>;
}

def:pub ComboboxContent(props: any) -> JsxElement {
    side = props["side"] or "bottom";
    sideOffset = props["sideOffset"] or 6;
    align = props["align"] or "start";
    alignOffset = props["alignOffset"] or 0;
    anchor = props["anchor"];
    return
        <ComboboxPrimitive.Portal>
            <ComboboxPrimitive.Positioner
                side={side}
                sideOffset={sideOffset}
                align={align}
                alignOffset={alignOffset}
                anchor={anchor}
                className="isolate z-50"
            >
                <ComboboxPrimitive.Popup
                    {**props}
                    data-slot="combobox-content"
                    data-chips={Boolean(anchor)}
                    className={cn(
                        "cn-combobox-content bg-popover text-popover-foreground data-open:animate-in data-closed:animate-out data-closed:fade-out-0 data-open:fade-in-0 data-closed:zoom-out-95 data-open:zoom-in-95 data-[side=bottom]:slide-in-from-top-2 data-[side=left]:slide-in-from-right-2 data-[side=right]:slide-in-from-left-2 data-[side=top]:slide-in-from-bottom-2 ring-foreground/10 *:data-[slot=input-group]:bg-input/30 *:data-[slot=input-group]:border-input/30 overflow-hidden rounded-lg shadow-md ring-1 duration-100 *:data-[slot=input-group]:m-1 *:data-[slot=input-group]:mb-0 *:data-[slot=input-group]:h-8 *:data-[slot=input-group]:shadow-none data-[side=inline-start]:slide-in-from-right-2 data-[side=inline-end]:slide-in-from-left-2 group/combobox-content relative max-h-(--available-height) w-(--anchor-width) max-w-(--available-width) min-w-[calc(var(--anchor-width)+--spacing(7))] origin-(--transform-origin) data-[chips=true]:min-w-(--anchor-width)",
                        props["className"]
                    )}
                />
            </ComboboxPrimitive.Positioner>
        </ComboboxPrimitive.Portal>;
}

def:pub ComboboxList(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.List
            {**props}
            data-slot="combobox-list"
            className={cn(
                "cn-combobox-list no-scrollbar max-h-[min(calc(--spacing(72)---spacing(9)),calc(var(--available-height)---spacing(9)))] scroll-py-1 p-1 data-empty:p-0 overflow-y-auto overscroll-contain",
                props["className"]
            )}
        />;
}

def:pub ComboboxItem(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.Item
            {**props}
            data-slot="combobox-item"
            className={cn(
                "cn-combobox-item data-highlighted:bg-accent data-highlighted:text-accent-foreground not-data-[variant=destructive]:data-highlighted:**:text-accent-foreground gap-2 rounded-md py-1 pr-8 pl-1.5 text-sm [&_svg:not([class*='size-'])]:size-4 relative flex w-full cursor-default items-center outline-hidden select-none data-disabled:pointer-events-none data-disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
                props["className"]
            )}
        >
            {props["children"]}
            <ComboboxPrimitive.ItemIndicator
                render={<span
                    className="pointer-events-none absolute right-2 flex size-4 items-center justify-center"
                />}
            >
                <HugeiconsIcon
                    icon={Tick02Icon}
                    strokeWidth={2}
                    className="pointer-events-none"
                />
            </ComboboxPrimitive.ItemIndicator>
        </ComboboxPrimitive.Item>;
}

def:pub ComboboxGroup(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.Group
            {**props}
            data-slot="combobox-group"
            className={cn(props["className"])}
        />;
}

def:pub ComboboxLabel(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.GroupLabel
            {**props}
            data-slot="combobox-label"
            className={cn(
                "text-muted-foreground px-2 py-1.5 text-xs", props["className"]
            )}
        />;
}

def:pub ComboboxCollection(props: any) -> JsxElement {
    return <ComboboxPrimitive.Collection data-slot="combobox-collection" {**props}/>;
}

def:pub ComboboxEmpty(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.Empty
            {**props}
            data-slot="combobox-empty"
            className={cn(
                "cn-combobox-empty text-muted-foreground hidden w-full justify-center py-2 text-center text-sm group-data-empty/combobox-content:flex",
                props["className"]
            )}
        />;
}

def:pub ComboboxSeparator(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.Separator
            {**props}
            data-slot="combobox-separator"
            className={cn("bg-border -mx-1 my-1 h-px", props["className"])}
        />;
}

def:pub ComboboxChips(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.Chips
            {**props}
            data-slot="combobox-chips"
            className={cn(
                "dark:bg-input/30 border-input focus-within:border-ring focus-within:ring-ring/50 has-aria-invalid:ring-destructive/20 dark:has-aria-invalid:ring-destructive/40 has-aria-invalid:border-destructive dark:has-aria-invalid:border-destructive/50 flex min-h-8 flex-wrap items-center gap-1 rounded-lg border bg-transparent bg-clip-padding px-2.5 py-1 text-sm transition-colors focus-within:ring-3 has-aria-invalid:ring-3 has-data-[slot=combobox-chip]:px-1",
                props["className"]
            )}
        >
            {props["children"]}
        </ComboboxPrimitive.Chips>;
}

def:pub ComboboxChip(props: any) -> JsxElement {
    showRemove = props["showRemove"];
    if showRemove is None {
        showRemove = True;
    }
    return
        <ComboboxPrimitive.Chip
            {**props}
            data-slot="combobox-chip"
            className={cn(
                "bg-muted text-foreground flex h-[calc(--spacing(5.25))] w-fit items-center justify-center gap-1 rounded-sm px-1.5 text-xs font-medium whitespace-nowrap has-data-[slot=combobox-chip-remove]:pr-0 has-disabled:pointer-events-none has-disabled:cursor-not-allowed has-disabled:opacity-50",
                props["className"]
            )}
        >
            {props["children"]}{showRemove
            and (
                <ComboboxPrimitive.ChipRemove
                    render={<Button variant="ghost" size="icon-xs"/>}
                    className="-ml-1 opacity-50 hover:opacity-100"
                    data-slot="combobox-chip-remove"
                >
                    <HugeiconsIcon
                        icon={Cancel01Icon}
                        strokeWidth={2}
                        className="pointer-events-none"
                    />
                </ComboboxPrimitive.ChipRemove>
            )}
        </ComboboxPrimitive.Chip>;
}

def:pub ComboboxChipsInput(props: any) -> JsxElement {
    return
        <ComboboxPrimitive.Input
            {**props}
            data-slot="combobox-chip-input"
            className={cn("min-w-16 flex-1 outline-none", props["className"])}
        />;
}

def:pub useComboboxAnchor -> any {
    return useRef(None);
}
