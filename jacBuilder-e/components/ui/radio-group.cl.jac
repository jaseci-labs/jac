cl import from "radix-ui" { RadioGroup as RadioGroupPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub RadioGroup(props: Any) -> JsxElement {
        return <RadioGroupPrimitive.Root
            {...props}
            data-slot="radio-group"
            className={cn("grid gap-2 w-full", props.className)}
        />;
    }

    def:pub RadioGroupItem(props: Any) -> JsxElement {
        return <RadioGroupPrimitive.Item
            {...props}
            data-slot="radio-group-item"
            className={cn("border-input dark:bg-input/30 data-checked:bg-primary data-checked:text-primary-foreground dark:data-checked:bg-primary data-checked:border-primary aria-invalid:aria-checked:border-primary aria-invalid:border-destructive focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 dark:aria-invalid:border-destructive/50 flex size-4 rounded-full focus-visible:ring-3 aria-invalid:ring-3 group/radio-group-item peer relative aspect-square shrink-0 border outline-none after:absolute after:-inset-x-3 after:-inset-y-2 disabled:cursor-not-allowed disabled:opacity-50", props.className)}
        >
            <RadioGroupPrimitive.Indicator
                data-slot="radio-group-indicator"
                className="flex size-4 items-center justify-center"
            >
                <span className="bg-primary-foreground absolute top-1/2 left-1/2 size-2 -translate-x-1/2 -translate-y-1/2 rounded-full" />
            </RadioGroupPrimitive.Indicator>
        </RadioGroupPrimitive.Item>;
    }
}
