import from "class-variance-authority" { cva }
import from "radix-ui" { Slot }
import from ...lib.utils { cn }

glob _buttonVariants: any = cva(
         "cn-button focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 rounded-lg border border-transparent bg-clip-padding text-sm font-medium focus-visible:ring-3 aria-invalid:ring-3 [&_svg:not([class*='size-'])]:size-4 inline-flex items-center justify-center whitespace-nowrap transition-all disabled:pointer-events-none disabled:opacity-50 [&_svg]:pointer-events-none shrink-0 [&_svg]:shrink-0 outline-none group/button select-none",
         {
             "variants": {
                 "variant": {
                     "default": "cn-button-variant-default bg-primary text-primary-foreground [a]:hover:bg-primary/80",
                     "outline": "cn-button-variant-outline border-border bg-background hover:bg-muted hover:text-foreground dark:bg-input/30 dark:border-input dark:hover:bg-input/50 aria-expanded:bg-muted aria-expanded:text-foreground",
                     "secondary": "cn-button-variant-secondary bg-secondary text-secondary-foreground hover:bg-secondary/80 aria-expanded:bg-secondary aria-expanded:text-secondary-foreground",
                     "ghost": "cn-button-variant-ghost hover:bg-muted hover:text-foreground dark:hover:bg-muted/50 aria-expanded:bg-muted aria-expanded:text-foreground",
                     "destructive": "cn-button-variant-destructive bg-destructive/10 hover:bg-destructive/20 focus-visible:ring-destructive/20 dark:focus-visible:ring-destructive/40 dark:bg-destructive/20 text-destructive focus-visible:border-destructive/40 dark:hover:bg-destructive/30",
                     "link": "cn-button-variant-link text-primary underline-offset-4 hover:underline"
                 },
                 "size": {
                     "default": "cn-button-size-default h-8 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-2 has-data-[icon=inline-start]:pl-2",
                     "xs": "cn-button-size-xs h-6 gap-1 rounded-[min(var(--radius-md),10px)] px-2 text-xs in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3",
                     "sm": "cn-button-size-sm h-7 gap-1 rounded-[min(var(--radius-md),12px)] px-2.5 text-[0.8rem] in-data-[slot=button-group]:rounded-lg has-data-[icon=inline-end]:pr-1.5 has-data-[icon=inline-start]:pl-1.5 [&_svg:not([class*='size-'])]:size-3.5",
                     "lg": "cn-button-size-lg h-9 gap-1.5 px-2.5 has-data-[icon=inline-end]:pr-3 has-data-[icon=inline-start]:pl-3",
                     "icon": "cn-button-size-icon size-8",
                     "icon-xs": "cn-button-size-icon-xs size-6 rounded-[min(var(--radius-md),10px)] in-data-[slot=button-group]:rounded-lg [&_svg:not([class*='size-'])]:size-3",
                     "icon-sm": "cn-button-size-icon-sm size-7 rounded-[min(var(--radius-md),12px)] in-data-[slot=button-group]:rounded-lg",
                     "icon-lg": "cn-button-size-icon-lg size-9"
                 }
             },
             "defaultVariants": {"variant": "default", "size": "default"}
         }
     ),
     _buttonExcludeKeys: list[str] = [
         "className",
         "variant",
         "size",
         "asChild",
         "children"
     ];

def:pub Button(props: any) -> JsxElement {
    variant = props["variant"] or "default";
    size = props["size"] or "default";
    asChild = props["asChild"] or False;

    restProps = {};
    for key in Object.keys(props) {  # jac:ignore[W6001]
        if key not in _buttonExcludeKeys {
            restProps[key] = props[key];
        }
    }

    computedClass = cn(
        _buttonVariants.call(
            None, {"variant": variant, "size": size, "className": props["className"]}
        )
    );

    if asChild {
        return
            <Slot.Root
                data-slot="button"
                data-variant={variant}
                data-size={size}
                className={computedClass}
                {**restProps}
            >
                {props["children"]}
            </Slot.Root>;
    }

    return
        <button
            data-slot="button"
            data-variant={variant}
            data-size={size}
            className={computedClass}
            {**restProps}
        >
            {props["children"]}
        </button>;
}

def:pub buttonVariants -> any {
    return _buttonVariants;
}
