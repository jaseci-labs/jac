import from "radix-ui" { Checkbox as CheckboxPrimitive }
import from ...lib.utils { cn }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { Tick02Icon }

def:pub Checkbox(props: any) -> JsxElement {
    return
        <CheckboxPrimitive.Root
            {**props}
            data-slot="checkbox"
            className={cn(
                "cn-checkbox peer relative shrink-0 outline-none after:absolute after:-inset-x-3 after:-inset-y-2 disabled:cursor-not-allowed disabled:opacity-50",
                props["className"]
            )}
        >
            <CheckboxPrimitive.Indicator
                data-slot="checkbox-indicator"
                className="cn-checkbox-indicator grid place-content-center text-current transition-none"
            >
                <HugeiconsIcon icon={Tick02Icon} strokeWidth={2}/>
            </CheckboxPrimitive.Indicator>
        </CheckboxPrimitive.Root>;
}
