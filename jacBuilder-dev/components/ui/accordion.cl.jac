cl import from "radix-ui" { Accordion as AccordionPrimitive }
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowDownIcon, ArrowUpIcon }

cl {
    def:pub Accordion(props: Any) -> JsxElement {
        return <AccordionPrimitive.Root
            {...props}
            data-slot="accordion"
            className={cn("cn-accordion flex w-full flex-col", props.className)}
        />;
    }

    def:pub AccordionItem(props: Any) -> JsxElement {
        return <AccordionPrimitive.Item
            {...props}
            data-slot="accordion-item"
            className={cn("not-last:border-b", props.className)}
        />;
    }

    def:pub AccordionTrigger(props: Any) -> JsxElement {
        return <AccordionPrimitive.Header className="flex">
            <AccordionPrimitive.Trigger
                {...props}
                data-slot="accordion-trigger"
                className={cn("focus-visible:ring-ring/50 focus-visible:border-ring focus-visible:after:border-ring **:data-[slot=accordion-trigger-icon]:text-muted-foreground rounded-lg py-2.5 text-left text-sm font-medium hover:underline focus-visible:ring-3 **:data-[slot=accordion-trigger-icon]:ml-auto **:data-[slot=accordion-trigger-icon]:size-4 group/accordion-trigger relative flex flex-1 items-start justify-between border border-transparent transition-all outline-none disabled:pointer-events-none disabled:opacity-50", props.className)}
            >
                {props.children}
                <HugeiconsIcon
                    icon={ArrowDownIcon}
                    strokeWidth={2}
                    data-slot="accordion-trigger-icon"
                    className="focus-visible:ring-ring/50 focus-visible:border-ring focus-visible:after:border-ring **:data-[slot=accordion-trigger-icon]:text-muted-foreground rounded-lg py-2.5 text-left text-sm font-medium hover:underline focus-visible:ring-3 **:data-[slot=accordion-trigger-icon]:ml-auto **:data-[slot=accordion-trigger-icon]:size-4-icon pointer-events-none shrink-0 group-aria-expanded/accordion-trigger:hidden"
                />
                <HugeiconsIcon
                    icon={ArrowUpIcon}
                    strokeWidth={2}
                    data-slot="accordion-trigger-icon"
                    className="focus-visible:ring-ring/50 focus-visible:border-ring focus-visible:after:border-ring **:data-[slot=accordion-trigger-icon]:text-muted-foreground rounded-lg py-2.5 text-left text-sm font-medium hover:underline focus-visible:ring-3 **:data-[slot=accordion-trigger-icon]:ml-auto **:data-[slot=accordion-trigger-icon]:size-4-icon pointer-events-none hidden shrink-0 group-aria-expanded/accordion-trigger:inline"
                />
            </AccordionPrimitive.Trigger>
        </AccordionPrimitive.Header>;
    }

    def:pub AccordionContent(props: Any) -> JsxElement {
        return <AccordionPrimitive.Content
            {...props}
            data-slot="accordion-content"
            className="data-open:animate-accordion-down data-closed:animate-accordion-up text-sm overflow-hidden"
        >
            <div className={cn("pt-0 pb-2.5 h-(--radix-accordion-content-height) [&_a]:underline [&_a]:underline-offset-3 [&_p:not(:last-child)]:mb-4", props.className)}>
                {props.children}
            </div>
        </AccordionPrimitive.Content>;
    }
}
