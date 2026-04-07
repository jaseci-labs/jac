cl import from "class-variance-authority" { cva }
cl import from "radix-ui" { Slot }
cl import from ...lib.utils { cn }
cl import from .separator { Separator }

glob _buttonGroupVariants: Any = cva(
    "has-[>[data-slot=button-group]]:gap-2 has-[select[aria-hidden=true]:last-child]:[&>[data-slot=select-trigger]:last-of-type]:rounded-r-lg flex w-fit items-stretch *:focus-visible:z-10 *:focus-visible:relative [&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit [&>input]:flex-1",
    {
        "variants": {
            "orientation": {
                "horizontal": "[&>[data-slot]:not(:has(~[data-slot]))]:rounded-r-lg! [&>*:not(:first-child)]:rounded-l-none [&>*:not(:first-child)]:border-l-0 [&>*:not(:last-child)]:rounded-r-none",
                "vertical": "[&>[data-slot]:not(:has(~[data-slot]))]:rounded-b-lg! flex-col [&>*:not(:first-child)]:rounded-t-none [&>*:not(:first-child)]:border-t-0 [&>*:not(:last-child)]:rounded-b-none"
            }
        },
        "defaultVariants": {
            "orientation": "horizontal"
        }
    }
);

glob _buttonGroupExcludeKeys: list = ["className", "orientation", "asChild", "children"];

cl {
    def:pub ButtonGroup(props: Any) -> JsxElement {
        orientation = props.orientation or "horizontal";
        computedClass = cn(_buttonGroupVariants.call(None, {"orientation": orientation, "className": props.className}));
        return <div
            role="group"
            data-slot="button-group"
            data-orientation={orientation}
            className={computedClass}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub ButtonGroupText(props: Any) -> JsxElement {
        asChild = props.asChild or False;
        computedClass = cn("bg-muted gap-2 rounded-lg border px-2.5 text-sm font-medium [&_svg:not([class*='size-'])]:size-4 flex items-center [&_svg]:pointer-events-none", props.className);
        if asChild {
            return <Slot.Root
                data-slot="button-group-text"
                className={computedClass}
                {...props}
            >
                {props.children}
            </Slot.Root>;
        }
        return <div
            data-slot="button-group-text"
            className={computedClass}
            {...props}
        >
            {props.children}
        </div>;
    }

    def:pub ButtonGroupSeparator(props: Any) -> JsxElement {
        orientation = props.orientation or "vertical";
        return <Separator
            data-slot="button-group-separator"
            orientation={orientation}
            className={cn("bg-input relative self-stretch data-horizontal:mx-px data-horizontal:w-auto data-vertical:my-px data-vertical:h-auto", props.className)}
            {...props}
        />;
    }

    def:pub buttonGroupVariants() -> Any {
        return _buttonGroupVariants;
    }
}
