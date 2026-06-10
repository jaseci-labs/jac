import from "radix-ui" { Separator as SeparatorPrimitive }
import from ...lib.utils { cn }

def:pub Separator(props: any) -> JsxElement {
    orientation = props["orientation"] or "horizontal";
    decorative = props["decorative"];
    if decorative is None {
        decorative = True;
    }
    return
        <SeparatorPrimitive.Root
            {**props}
            data-slot="separator"
            decorative={decorative}
            orientation={orientation}
            className={cn(
                "bg-border shrink-0 data-horizontal:h-px data-horizontal:w-full data-vertical:w-px data-vertical:self-stretch",
                props["className"]
            )}
        />;
}
