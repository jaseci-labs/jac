cl import from "class-variance-authority" { cva }
cl import from ...lib.utils { cn }
cl import from .button { Button }
cl import from .input { Input }
cl import from .textarea { Textarea }

glob _inputGroupAddonVariants: Any = cva(
    "text-muted-foreground h-auto gap-2 py-1.5 text-sm font-medium group-data-[disabled=true]/input-group:opacity-50 [&>kbd]:rounded-[calc(var(--radius)-5px)] [&>svg:not([class*='size-'])]:size-4 text-muted-foreground h-auto gap-2 py-1.5 text-sm font-medium group-data-[disabled=true]/input-group:opacity-50 [&>kbd]:rounded-[calc(var(--radius)-5px)] [&>svg:not([class*='size-'])]:size-4 flex cursor-text items-center justify-center select-none",
    {
        "variants": {
            "align": {
                "inline-start": "pl-2 has-[>button]:ml-[-0.3rem] has-[>kbd]:ml-[-0.15rem] pl-2 has-[>button]:ml-[-0.3rem] has-[>kbd]:ml-[-0.15rem] order-first",
                "inline-end": "pr-2 has-[>button]:mr-[-0.3rem] has-[>kbd]:mr-[-0.15rem] pr-2 has-[>button]:mr-[-0.3rem] has-[>kbd]:mr-[-0.15rem] order-last",
                "block-start": "px-2.5 pt-2 group-has-[>input]/input-group:pt-2 [.border-b]:pb-2 px-2.5 pt-2 group-has-[>input]/input-group:pt-2 [.border-b]:pb-2 order-first w-full justify-start",
                "block-end": "px-2.5 pb-2 group-has-[>input]/input-group:pb-2 [.border-t]:pt-2 px-2.5 pb-2 group-has-[>input]/input-group:pb-2 [.border-t]:pt-2 order-last w-full justify-start"
            }
        },
        "defaultVariants": {
            "align": "inline-start"
        }
    }
);

glob _inputGroupButtonVariants: Any = cva(
    "gap-2 text-sm gap-2 text-sm shadow-none flex items-center",
    {
        "variants": {
            "size": {
                "xs": "h-6 gap-1 rounded-[calc(var(--radius)-3px)] px-1.5 [&>svg:not([class*='size-'])]:size-3.5",
                "sm": "",
                "icon-xs": "size-6 rounded-[calc(var(--radius)-3px)] p-0 has-[>svg]:p-0",
                "icon-sm": "size-8 p-0 has-[>svg]:p-0"
            }
        },
        "defaultVariants": {
            "size": "xs"
        }
    }
);

cl {
    def:pub InputGroup(props: Any) -> JsxElement {
        return <div
            {...props}
            data-slot="input-group"
            role="group"
            className={cn("border-input dark:bg-input/30 has-[[data-slot=input-group-control]:focus-visible]:border-ring has-[[data-slot=input-group-control]:focus-visible]:ring-ring/50 has-[[data-slot][aria-invalid=true]]:ring-destructive/20 has-[[data-slot][aria-invalid=true]]:border-destructive dark:has-[[data-slot][aria-invalid=true]]:ring-destructive/40 has-disabled:bg-input/50 dark:has-disabled:bg-input/80 h-8 rounded-lg border transition-colors in-data-[slot=combobox-content]:focus-within:border-inherit in-data-[slot=combobox-content]:focus-within:ring-0 has-disabled:opacity-50 has-[[data-slot=input-group-control]:focus-visible]:ring-3 has-[[data-slot][aria-invalid=true]]:ring-3 has-[>[data-align=block-end]]:h-auto has-[>[data-align=block-end]]:flex-col has-[>[data-align=block-start]]:h-auto has-[>[data-align=block-start]]:flex-col has-[>[data-align=block-end]]:[&>input]:pt-3 has-[>[data-align=block-start]]:[&>input]:pb-3 has-[>[data-align=inline-end]]:[&>input]:pr-1.5 has-[>[data-align=inline-start]]:[&>input]:pl-1.5 border-input dark:bg-input/30 has-[[data-slot=input-group-control]:focus-visible]:border-ring has-[[data-slot=input-group-control]:focus-visible]:ring-ring/50 has-[[data-slot][aria-invalid=true]]:ring-destructive/20 has-[[data-slot][aria-invalid=true]]:border-destructive dark:has-[[data-slot][aria-invalid=true]]:ring-destructive/40 has-disabled:bg-input/50 dark:has-disabled:bg-input/80 h-8 rounded-lg border transition-colors in-data-[slot=combobox-content]:focus-within:border-inherit in-data-[slot=combobox-content]:focus-within:ring-0 has-disabled:opacity-50 has-[[data-slot=input-group-control]:focus-visible]:ring-3 has-[[data-slot][aria-invalid=true]]:ring-3 has-[>[data-align=block-end]]:h-auto has-[>[data-align=block-end]]:flex-col has-[>[data-align=block-start]]:h-auto has-[>[data-align=block-start]]:flex-col has-[>[data-align=block-end]]:[&>input]:pt-3 has-[>[data-align=block-start]]:[&>input]:pb-3 has-[>[data-align=inline-end]]:[&>input]:pr-1.5 has-[>[data-align=inline-start]]:[&>input]:pl-1.5 group/input-group relative flex w-full min-w-0 items-center outline-none has-[>textarea]:h-auto", props.className)}
        >
            {props.children}
        </div>;
    }

    def:pub InputGroupAddon(props: Any) -> JsxElement {
        align = props.align or "inline-start";
        addonFn = _inputGroupAddonVariants;
        return <div
            {...props}
            role="group"
            data-slot="input-group-addon"
            data-align={align}
            className={cn(addonFn.call(None, {"align": align}), props.className)}
            onClick={lambda(e: Any) -> None {
                if not e.target.closest("button") {
                    inputEl = e.currentTarget.parentElement and e.currentTarget.parentElement.querySelector("input");
                    if inputEl {
                        inputEl.focus();
                    }
                }
            }}
        >
            {props.children}
        </div>;
    }

    def:pub InputGroupButton(props: Any) -> JsxElement {
        type = props.type or "button";
        variant = props.variant or "ghost";
        size = props.size or "xs";
        btnFn = _inputGroupButtonVariants;
        return <Button
            {...props}
            type={type}
            data-size={size}
            variant={variant}
            className={cn(btnFn.call(None, {"size": size}), props.className)}
        >
            {props.children}
        </Button>;
    }

    def:pub InputGroupText(props: Any) -> JsxElement {
        return <span
            {...props}
            className={cn("text-muted-foreground gap-2 text-sm [&_svg:not([class*='size-'])]:size-4 text-muted-foreground gap-2 text-sm [&_svg:not([class*='size-'])]:size-4 flex items-center [&_svg]:pointer-events-none", props.className)}
        >
            {props.children}
        </span>;
    }

    def:pub InputGroupInput(props: Any) -> JsxElement {
        return <Input
            {...props}
            data-slot="input-group-control"
            className={cn("rounded-none border-0 bg-transparent shadow-none ring-0 focus-visible:ring-0 disabled:bg-transparent aria-invalid:ring-0 dark:bg-transparent dark:disabled:bg-transparent rounded-none border-0 bg-transparent shadow-none ring-0 focus-visible:ring-0 disabled:bg-transparent aria-invalid:ring-0 dark:bg-transparent dark:disabled:bg-transparent flex-1", props.className)}
        />;
    }

    def:pub InputGroupTextarea(props: Any) -> JsxElement {
        return <Textarea
            {...props}
            data-slot="input-group-control"
            className={cn("rounded-none border-0 bg-transparent py-2 shadow-none ring-0 focus-visible:ring-0 disabled:bg-transparent aria-invalid:ring-0 dark:bg-transparent dark:disabled:bg-transparent rounded-none border-0 bg-transparent py-2 shadow-none ring-0 focus-visible:ring-0 disabled:bg-transparent aria-invalid:ring-0 dark:bg-transparent dark:disabled:bg-transparent flex-1 resize-none", props.className)}
        />;
    }
}
