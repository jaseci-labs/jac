cl import from "cmdk" { Command as CommandPrimitive }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { SearchIcon, Tick02Icon }
cl import from .dialog {
    Dialog,
    DialogContent,
    DialogDescription,
    DialogHeader,
    DialogTitle
}
cl import from ".input-group" { InputGroup, InputGroupAddon }
cl import from ...lib.utils { cn }

cl {
    def:pub Command(props: any) -> JsxElement {
        return
            <CommandPrimitive
                data-slot="command"
                {**props}
                className={cn(
                    "cn-command flex size-full flex-col overflow-hidden",
                    props["className"]
                )}
            />;
    }

    def:pub CommandDialog(props: any) -> JsxElement {
        title = props["title"] or "Command Palette";
        description = props["description"] or "Search for a command to run...";
        showCloseButton = props["showCloseButton"] or False;
        return
            <Dialog {**props}>
                <DialogHeader className="sr-only">
                    <DialogTitle>{title}</DialogTitle>
                    <DialogDescription>{description}</DialogDescription>
                </DialogHeader>
                <DialogContent
                    {**props}
                    className={cn(
                        "cn-command-dialog top-1/3 translate-y-0 overflow-hidden p-0",
                        props["className"]
                    )}
                    showCloseButton={showCloseButton}
                >
                    {props["children"]}
                </DialogContent>
            </Dialog>;
    }

    def:pub CommandInput(props: any) -> JsxElement {
        return
            <div data-slot="command-input-wrapper" className="cn-command-input-wrapper">
                <InputGroup className="cn-command-input-group">
                    <CommandPrimitive.Input
                        data-slot="command-input"
                        {**props}
                        className={cn(
                            "cn-command-input outline-hidden disabled:cursor-not-allowed disabled:opacity-50",
                            props["className"]
                        )}
                    />
                    <InputGroupAddon>
                        <HugeiconsIcon
                            icon={SearchIcon}
                            className="cn-command-input-icon"
                            size={16}
                        />
                    </InputGroupAddon>
                </InputGroup>
            </div>;
    }

    def:pub CommandList(props: any) -> JsxElement {
        return
            <CommandPrimitive.List
                data-slot="command-list"
                {**props}
                className={cn(
                    "cn-command-list overflow-x-hidden overflow-y-auto",
                    props["className"]
                )}
            />;
    }

    def:pub CommandEmpty(props: any) -> JsxElement {
        return
            <CommandPrimitive.Empty
                data-slot="command-empty"
                {**props}
                className={cn("cn-command-empty", props["className"])}
            />;
    }

    def:pub CommandGroup(props: any) -> JsxElement {
        return
            <CommandPrimitive.Group
                data-slot="command-group"
                {**props}
                className={cn("cn-command-group", props["className"])}
            />;
    }

    def:pub CommandSeparator(props: any) -> JsxElement {
        return
            <CommandPrimitive.Separator
                data-slot="command-separator"
                {**props}
                className={cn("cn-command-separator", props["className"])}
            />;
    }

    def:pub CommandItem(props: any) -> JsxElement {
        return
            <CommandPrimitive.Item
                data-slot="command-item"
                {**props}
                className={cn(
                    "cn-command-item group/command-item data-[disabled=true]:pointer-events-none data-[disabled=true]:opacity-50",
                    props["className"]
                )}
            >
                {props["children"]}
                <HugeiconsIcon
                    icon={Tick02Icon}
                    className="cn-command-item-indicator ml-auto opacity-0 group-has-data-[slot=command-shortcut]/command-item:hidden group-data-[checked=true]/command-item:opacity-100"
                    size={16}
                />
            </CommandPrimitive.Item>;
    }

    def:pub CommandShortcut(props: any) -> JsxElement {
        attrs: dict[str, any] = {** props};
        return
            <span
                data-slot="command-shortcut"
                {**attrs}
                className={cn("cn-command-shortcut", props["className"])}
            />;
    }
}
