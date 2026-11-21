import from "class-variance-authority" { cva }
import from "radix-ui" { Slot }
import from ...lib.utils { cn }

glob _markerVariants: any = cva(
         "cn-marker group/marker relative flex w-full items-center",
         {
             "variants": {
                 "variant": {
                     "default": "cn-marker-variant-default",
                     "separator": "cn-marker-variant-separator",
                     "border": "cn-marker-variant-border"
                 }
             }
         }
     ),
     _markerExcludeKeys: list[str] = ["className", "variant", "asChild", "children"];

def:pub Marker(props: any) -> JsxElement {
    variant = props["variant"] or "default";
    asChild = props["asChild"] or False;
    computedClass = cn(
        _markerVariants.call(
            None, {"variant": variant, "className": props["className"]}
        )
    );

    restProps = {};
    for key in Object.keys(props) {
        if key not in _markerExcludeKeys {
            restProps[key] = props[key];
        }
    }

    if asChild {
        return
            <Slot.Root
                data-slot="marker"
                data-variant={variant}
                className={computedClass}
                {**restProps}
            >
                {props["children"]}
            </Slot.Root>;
    }
    <div
        data-slot="marker"
        data-variant={variant}
        className={computedClass}
        {**restProps}
    >
        {props["children"]}
    </div>
}

def:pub MarkerIcon(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <span
        {**attrs}
        data-slot="marker-icon"
        aria-hidden="true"
        className={cn("cn-marker-icon shrink-0", props["className"])}
    />
}

def:pub MarkerContent(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    <span
        {**attrs}
        data-slot="marker-content"
        className={cn("cn-marker-content min-w-0 wrap-break-word", props["className"])}
    />
}

def:pub markerVariants -> any {
    return _markerVariants;
}
