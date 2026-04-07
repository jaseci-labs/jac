cl import from "radix-ui" { Checkbox as CheckboxPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { Tick02Icon }

cl {
    def:pub Checkbox(props: Any) -> JsxElement {
        return <CheckboxPrimitive.Root
            {...props}
            data-slot="checkbox"
            className={cn("border-input dark:bg-input/30 data-checked:bg-primary data-checked:text-primary-foreground dark:data-checked:bg-primary data-checked:border-primary aria-invalid:aria-checked:border-primary aria-invalid:border-destructive dark:aria-invalid:border-destructive/50 focus-visible:border-ring focus-visible:ring-ring/50 aria-invalid:ring-destructive/20 dark:aria-invalid:ring-destructive/40 flex size-4 items-center justify-center rounded-[4px] border transition-colors group-has-disabled/field:opacity-50 focus-visible:ring-3 aria-invalid:ring-3 peer relative shrink-0 outline-none after:absolute after:-inset-x-3 after:-inset-y-2 disabled:cursor-not-allowed disabled:opacity-50", props.className)}
        >
            <CheckboxPrimitive.Indicator
                data-slot="checkbox-indicator"
                className="[&>svg]:size-3.5 grid place-content-center text-current transition-none"
            >
                <HugeiconsIcon icon={Tick02Icon} strokeWidth={2} />
            </CheckboxPrimitive.Indicator>
        </CheckboxPrimitive.Root>;
    }
}
