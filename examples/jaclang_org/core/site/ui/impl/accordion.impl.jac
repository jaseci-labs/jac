impl Accordion(**kwargs: any) -> JsxElement {
    return <AccordionPrimitive.Root
        {...kwargs}
        data-slot="accordion"
        className={cn("cn-accordion flex w-full flex-col", kwargs.get("className"))}
    />;
}

impl AccordionItem(**kwargs: any) -> JsxElement {
    return <AccordionPrimitive.Item
        {...kwargs}
        data-slot="accordion-item"
        className={cn("not-last:border-b", kwargs.get("className"))}
    />;
}

impl AccordionTrigger(**kwargs: any) -> JsxElement {
    return <AccordionPrimitive.Header className="flex">
        <AccordionPrimitive.Trigger
            {...kwargs}
            data-slot="accordion-trigger"
            className={cn("focus-visible:ring-ring/50 focus-visible:border-ring focus-visible:after:border-ring **:data-[slot=accordion-trigger-icon]:text-muted-foreground rounded-lg py-2.5 text-left text-sm font-medium hover:underline focus-visible:ring-3 **:data-[slot=accordion-trigger-icon]:ml-auto **:data-[slot=accordion-trigger-icon]:size-4 group/accordion-trigger relative flex flex-1 items-start justify-between border border-transparent transition-all outline-none disabled:pointer-events-none disabled:opacity-50", kwargs.get("className"))}
        >
            {kwargs.get("children")}
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

impl AccordionContent(**kwargs: any) -> JsxElement {
    return <AccordionPrimitive.Content
        {...kwargs}
        data-slot="accordion-content"
        className="data-open:animate-accordion-down data-closed:animate-accordion-up text-sm overflow-hidden"
    >
        <div
            className={cn("pt-0 pb-2.5 h-(--radix-accordion-content-height) [&_a]:underline [&_a]:underline-offset-3 [&_p:not(:last-child)]:mb-4", kwargs.get("className"))}
        >{kwargs.get("children")}</div>
    </AccordionPrimitive.Content>;
}
