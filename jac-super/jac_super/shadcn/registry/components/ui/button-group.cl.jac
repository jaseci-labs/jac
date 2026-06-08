import from "class-variance-authority" { cva }
import from "radix-ui" { Slot }
import from ...lib.utils { cn }
import from .separator { Separator }

glob _buttonGroupVariants: any = cva(
         "cn-button-group flex w-fit items-stretch *:focus-visible:z-10 *:focus-visible:relative [&>[data-slot=select-trigger]:not([class*='w-'])]:w-fit [&>input]:flex-1",
         {
             "variants": {
                 "orientation": {
                     "horizontal": "cn-button-group-orientation-horizontal [&>*:not(:first-child)]:rounded-l-none [&>*:not(:first-child)]:border-l-0 [&>*:not(:last-child)]:rounded-r-none",
                     "vertical": "cn-button-group-orientation-vertical flex-col [&>*:not(:first-child)]:rounded-t-none [&>*:not(:first-child)]:border-t-0 [&>*:not(:last-child)]:rounded-b-none"
                 }
             },
             "defaultVariants": {"orientation": "horizontal"}
         }
     ),
     _buttonGroupExcludeKeys: list[str] = [
         "className",
         "orientation",
         "asChild",
         "children"
     ];

def:pub ButtonGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    orientation = props["orientation"] or "horizontal";
    computedClass = cn(
        _buttonGroupVariants.call(
            None, {"orientation": orientation, "className": props["className"]}
        )
    );
    return
        <div
            role="group"
            data-slot="button-group"
            data-orientation={orientation}
            className={computedClass}
            {**attrs}
        >
            {props["children"]}
        </div>;
}

def:pub ButtonGroupText(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    asChild = props["asChild"] or False;
    computedClass = cn(
        "cn-button-group-text flex items-center [&_svg]:pointer-events-none",
        props["className"]
    );
    if asChild {
        return
            <Slot.Root
                data-slot="button-group-text"
                className={computedClass}
                {**props}
            >
                {props["children"]}
            </Slot.Root>;
    }
    return
        <div data-slot="button-group-text" className={computedClass} {**attrs}>
            {props["children"]}
        </div>;
}

def:pub ButtonGroupSeparator(props: any) -> JsxElement {
    orientation = props["orientation"] or "vertical";
    return
        <Separator
            data-slot="button-group-separator"
            orientation={orientation}
            className={cn(
                "cn-button-group-separator relative self-stretch data-horizontal:mx-px data-horizontal:w-auto data-vertical:my-px data-vertical:h-auto",
                props["className"]
            )}
            {**props}
        />;
}

def:pub buttonGroupVariants -> any {
    return _buttonGroupVariants;
}
