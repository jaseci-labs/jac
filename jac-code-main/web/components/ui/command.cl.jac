cl import from "cmdk" { Command as CommandPrimitive }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" {
    SearchIcon,
    Tick02Icon
}
cl import from .dialog {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogHeader,
    DialogTitle
}
cl import from ".input-group" {
    InputGroup,
    InputGroupAddon
}
cl import from ...lib.utils { cn }

cl {
    def:pub Command(props: Any) -> JsxElement {
        return <CommandPrimitive
            data-slot="command"
            {...props}
            className={cn(
                "bg-popover text-popover-foreground rounded-xl! p-1 flex size-full flex-col overflow-hidden",
                props.className
            )}
        />;
    }

    def:pub CommandDialog(props: Any) -> JsxElement {
        title = props.title or "Command Palette";
        description = props.description or "Search for a command to run...";
        showCloseButton = props.showCloseButton or false;
        return <Dialog {...props}>
            <DialogHeader className="sr-only">
                <DialogTitle>{title}</DialogTitle>
                <DialogDescription>{description}</DialogDescription>
            </DialogHeader>
            <DialogContent
                {...props}
                className={cn(
                    "rounded-xl! top-1/3 translate-y-0 overflow-hidden p-0",
                    props.className
                )}
                showCloseButton={showCloseButton}
            >
                {props.children}
            </DialogContent>
        </Dialog>;
    }

    def:pub CommandInput(props: Any) -> JsxElement {
        return <div data-slot="command-input-wrapper" className="p-1 pb-0">
            <InputGroup className="bg-input/30 border-input/30 h-8! rounded-lg! shadow-none! *:data-[slot=input-group-addon]:pl-2!">
                <CommandPrimitive.Input
                    data-slot="command-input"
                    {...props}
                    className={cn(
                        "w-full text-sm outline-hidden disabled:cursor-not-allowed disabled:opacity-50",
                        props.className
                    )}
                />
                <InputGroupAddon>
                    <HugeiconsIcon icon={SearchIcon} className="size-4 shrink-0 opacity-50" size={16} />
                </InputGroupAddon>
            </InputGroup>
        </div>;
    }

    def:pub CommandList(props: Any) -> JsxElement {
        return <CommandPrimitive.List
            data-slot="command-list"
            {...props}
            className={cn(
                "no-scrollbar max-h-72 scroll-py-1 outline-none overflow-x-hidden overflow-y-auto",
                props.className
            )}
        />;
    }

    def:pub CommandEmpty(props: Any) -> JsxElement {
        return <CommandPrimitive.Empty
            data-slot="command-empty"
            {...props}
            className={cn("py-6 text-center text-sm", props.className)}
        />;
    }

    def:pub CommandGroup(props: Any) -> JsxElement {
        return <CommandPrimitive.Group
            data-slot="command-group"
            {...props}
            className={cn("text-foreground **:[[cmdk-group-heading]]:text-muted-foreground overflow-hidden p-1 **:[[cmdk-group-heading]]:px-2 **:[[cmdk-group-heading]]:py-1.5 **:[[cmdk-group-heading]]:text-xs **:[[cmdk-group-heading]]:font-medium", props.className)}
        />;
    }

    def:pub CommandSeparator(props: Any) -> JsxElement {
        return <CommandPrimitive.Separator
            data-slot="command-separator"
            {...props}
            className={cn("bg-border -mx-1 h-px", props.className)}
        />;
    }

    def:pub CommandItem(props: Any) -> JsxElement {
        return <CommandPrimitive.Item
            data-slot="command-item"
            {...props}
            className={cn(
                "data-selected:bg-muted data-selected:text-foreground data-selected:*:[svg]:text-foreground relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none in-data-[slot=dialog-content]:rounded-lg! [&_svg:not([class*='size-'])]:size-4 group/command-item data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50",
                props.className
            )}
        >
            {props.children}
            <HugeiconsIcon
                icon={Tick02Icon}
                className="data-selected:bg-muted data-selected:text-foreground data-selected:*:[svg]:text-foreground relative flex cursor-default items-center gap-2 rounded-sm px-2 py-1.5 text-sm outline-hidden select-none in-data-[slot=dialog-content]:rounded-lg! [&_svg:not([class*='size-'])]:size-4-indicator ml-auto opacity-0 group-has-data-[slot=command-shortcut]/command-item:hidden group-data-[checked=true]/command-item:opacity-100"
                size={16}
            />
        </CommandPrimitive.Item>;
    }

    def:pub CommandShortcut(props: Any) -> JsxElement {
        return <span
            data-slot="command-shortcut"
            {...props}
            className={cn("text-muted-foreground group-data-selected/command-item:text-foreground ml-auto text-xs tracking-widest", props.className)}
        />;
    }
}
