import from "class-variance-authority" { cva }
import from ...lib.utils { cn }

glob _alertVariants: any = cva(
         "cn-alert w-full relative group/alert",
         {
             "variants": {
                 "variant": {
                     "default": "cn-alert-variant-default",
                     "destructive": "cn-alert-variant-destructive"
                 }
             },
             "defaultVariants": {"variant": "default"}
         }
     );

def:pub Alert(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    variant = props["variant"] or "default";
    variantsFn = _alertVariants;
    computedClass = cn(
        variantsFn.call(None, {"variant": variant, "className": props["className"]})
    );
    return <div {**attrs} data-slot="alert" role="alert" className={computedClass}/>;
}

def:pub AlertTitle(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="alert-title"
            className={cn(
                "cn-alert-title [&_a]:hover:text-foreground [&_a]:underline [&_a]:underline-offset-3",
                props["className"]
            )}
        />;
}

def:pub AlertDescription(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="alert-description"
            className={cn(
                "cn-alert-description [&_a]:hover:text-foreground [&_a]:underline [&_a]:underline-offset-3",
                props["className"]
            )}
        />;
}

def:pub AlertAction(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            {**attrs}
            data-slot="alert-action"
            className={cn("cn-alert-action", props["className"])}
        />;
}
