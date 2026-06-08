import from "radix-ui" { Switch as SwitchPrimitive }
import from ...lib.utils { cn }

def:pub Switch(props: any) -> JsxElement {
    size = props["size"] or "default";
    return
        <SwitchPrimitive.Root
            {**props}
            data-slot="switch"
            data-size={size}
            className={cn(
                "cn-switch peer group/switch relative inline-flex items-center transition-all outline-none after:absolute after:-inset-x-3 after:-inset-y-2 data-disabled:cursor-not-allowed data-disabled:opacity-50",
                props["className"]
            )}
        >
            <SwitchPrimitive.Thumb
                data-slot="switch-thumb"
                className="cn-switch-thumb pointer-events-none block ring-0 transition-transform"
            />
        </SwitchPrimitive.Root>;
}
