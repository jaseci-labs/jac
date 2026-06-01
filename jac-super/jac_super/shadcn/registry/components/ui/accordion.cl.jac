cl import from "radix-ui" { Accordion as AccordionPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowDownIcon, ArrowUpIcon }

cl {
    def:pub Accordion(props: any) -> JsxElement {
        return
            <AccordionPrimitive.Root
                {**props}
                data-slot="accordion"
                className={cn("cn-accordion flex w-full flex-col", props["className"])}
            />;
    }

    def:pub AccordionItem(props: any) -> JsxElement {
        return
            <AccordionPrimitive.Item
                {**props}
                data-slot="accordion-item"
                className={cn("cn-accordion-item", props["className"])}
            />;
    }

    def:pub AccordionTrigger(props: any) -> JsxElement {
        return
            <AccordionPrimitive.Header className="flex">
                <AccordionPrimitive.Trigger
                    {**props}
                    data-slot="accordion-trigger"
                    className={cn(
                        "cn-accordion-trigger group/accordion-trigger relative flex flex-1 items-start justify-between border border-transparent transition-all outline-none disabled:pointer-events-none disabled:opacity-50",
                        props["className"]
                    )}
                >
                    {props["children"]}
                    <HugeiconsIcon
                        icon={ArrowDownIcon}
                        strokeWidth={2}
                        data-slot="accordion-trigger-icon"
                        className="cn-accordion-trigger-icon pointer-events-none shrink-0 group-aria-expanded/accordion-trigger:hidden"
                    />
                    <HugeiconsIcon
                        icon={ArrowUpIcon}
                        strokeWidth={2}
                        data-slot="accordion-trigger-icon"
                        className="cn-accordion-trigger-icon pointer-events-none hidden shrink-0 group-aria-expanded/accordion-trigger:inline"
                    />
                </AccordionPrimitive.Trigger>
            </AccordionPrimitive.Header>;
    }

    def:pub AccordionContent(props: any) -> JsxElement {
        return
            <AccordionPrimitive.Content
                {**props}
                data-slot="accordion-content"
                className="cn-accordion-content overflow-hidden"
            >
                <div
                    className={cn(
                        "cn-accordion-content-inner h-(--radix-accordion-content-height) [&_a]:underline [&_a]:underline-offset-3 [&_p:not(:last-child)]:mb-4",
                        props["className"]
                    )}
                >
                    {props["children"]}
                </div>
            </AccordionPrimitive.Content>;
    }
}
