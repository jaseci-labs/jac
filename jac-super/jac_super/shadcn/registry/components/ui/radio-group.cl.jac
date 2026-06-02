cl import from "radix-ui" { RadioGroup as RadioGroupPrimitive }
cl import from ...lib.utils { cn }

cl {
    def:pub RadioGroup(props: any) -> JsxElement {
        return
            <RadioGroupPrimitive.Root
                {**props}
                data-slot="radio-group"
                className={cn("cn-radio-group w-full", props["className"])}
            />;
    }

    def:pub RadioGroupItem(props: any) -> JsxElement {
        return
            <RadioGroupPrimitive.Item
                {**props}
                data-slot="radio-group-item"
                className={cn(
                    "cn-radio-group-item group/radio-group-item peer relative aspect-square shrink-0 border outline-none after:absolute after:-inset-x-3 after:-inset-y-2 disabled:cursor-not-allowed disabled:opacity-50",
                    props["className"]
                )}
            >
                <RadioGroupPrimitive.Indicator
                    data-slot="radio-group-indicator"
                    className="cn-radio-group-indicator"
                >
                    <span className="cn-radio-group-indicator-icon"/>
                </RadioGroupPrimitive.Indicator>
            </RadioGroupPrimitive.Item>;
    }
}
