import from "class-variance-authority" { cva }
import from "radix-ui" { Toggle as TogglePrimitive }
import from ...lib.utils { cn }

glob _toggleVariants: any = cva(
         "cn-toggle group/toggle hover:bg-muted inline-flex items-center justify-center whitespace-nowrap outline-none focus-visible:ring-[3px] disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none [&_svg]:shrink-0",
         {
             "variants": {
                 "variant": {
                     "default": "cn-toggle-variant-default",
                     "outline": "cn-toggle-variant-outline"
                 },
                 "size": {
                     "default": "cn-toggle-size-default",
                     "sm": "cn-toggle-size-sm",
                     "lg": "cn-toggle-size-lg"
                 }
             },
             "defaultVariants": {"variant": "default", "size": "default"}
         }
     );

def:pub Toggle(props: any) -> JsxElement {
    variant = props["variant"] or "default";
    size = props["size"] or "default";
    variantsFn = _toggleVariants;
    computedClass = cn(
        variantsFn.call(
            None, {"variant": variant, "size": size, "className": props["className"]}
        )
    );
    return
        <TogglePrimitive.Root {**props} data-slot="toggle" className={computedClass}/>;
}

def:pub toggleVariants -> any {
    return _toggleVariants;
}
