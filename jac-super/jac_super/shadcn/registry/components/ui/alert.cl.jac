cl import from "class-variance-authority" { cva }
cl import from ...lib.utils { cn }

glob _alertVariants: Any = cva(
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

cl {
    def:pub Alert(props: Any) -> JsxElement {
        variant = props.variant or "default";
        variantsFn = _alertVariants;
        computedClass = cn(
            variantsFn.call(None, {"variant": variant, "className": props.className})
        );
        return
            <div {...props} data-slot="alert" role="alert" className={computedClass}/>;
    }

    def:pub AlertTitle(props: Any) -> JsxElement {
        return
            <div
                {...props}
                data-slot="alert-title"
                className={cn(
                    "cn-alert-title [&_a]:hover:text-foreground [&_a]:underline [&_a]:underline-offset-3",
                    props.className
                )}
            />;
    }

    def:pub AlertDescription(props: Any) -> JsxElement {
        return
            <div
                {...props}
                data-slot="alert-description"
                className={cn(
                    "cn-alert-description [&_a]:hover:text-foreground [&_a]:underline [&_a]:underline-offset-3",
                    props.className
                )}
            />;
    }

    def:pub AlertAction(props: Any) -> JsxElement {
        return
            <div
                {...props}
                data-slot="alert-action"
                className={cn("cn-alert-action", props.className)}
            />;
    }
}
