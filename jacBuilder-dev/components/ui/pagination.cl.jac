cl import from ...lib.utils { cn }
cl import from ".button" { Button, buttonVariants }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ArrowLeft01Icon, ArrowRight01Icon, MoreHorizontalCircle01Icon }

cl {
    def:pub Pagination(props: Any) -> JsxElement {
        return <nav
            {...props}
            role="navigation"
            aria-label="pagination"
            data-slot="pagination"
            className={cn("cn-pagination mx-auto flex w-full justify-center", props.className)}
        />;
    }

    def:pub PaginationContent(props: Any) -> JsxElement {
        return <ul
            {...props}
            data-slot="pagination-content"
            className={cn("gap-0.5 flex items-center", props.className)}
        />;
    }

    def:pub PaginationItem(props: Any) -> JsxElement {
        return <li data-slot="pagination-item" {...props} />;
    }

    def:pub PaginationLink(props: Any) -> JsxElement {
        isActive = props.isActive or False;
        size = props.size or "icon";
        variantsFn = buttonVariants();
        computedClass = cn(
            variantsFn.call(None, {"variant": isActive and "outline" or "ghost", "size": size}),
            "cn-pagination-link",
            props.className
        );
        return <a
            {...props}
            aria-current={isActive and "page" or None}
            data-slot="pagination-link"
            data-active={isActive}
            className={computedClass}
        />;
    }

    def:pub PaginationPrevious(props: Any) -> JsxElement {
        text = props.text or "Previous";
        return <PaginationLink
            {...props}
            aria-label="Go to previous page"
            size="default"
            className={cn("pl-1.5!", props.className)}
        >
            <HugeiconsIcon icon={ArrowLeft01Icon} strokeWidth={2} data-icon="inline-start" className="cn-rtl-flip" />
            <span className="pl-1.5!-text hidden sm:block">{text}</span>
        </PaginationLink>;
    }

    def:pub PaginationNext(props: Any) -> JsxElement {
        text = props.text or "Next";
        return <PaginationLink
            {...props}
            aria-label="Go to next page"
            size="default"
            className={cn("pr-1.5!", props.className)}
        >
            <span className="pr-1.5!-text hidden sm:block">{text}</span>
            <HugeiconsIcon icon={ArrowRight01Icon} strokeWidth={2} data-icon="inline-end" className="cn-rtl-flip" />
        </PaginationLink>;
    }

    def:pub PaginationEllipsis(props: Any) -> JsxElement {
        return <span
            {...props}
            aria-hidden={True}
            data-slot="pagination-ellipsis"
            className={cn("size-8 items-center justify-center [&_svg:not([class*='size-'])]:size-4 flex items-center justify-center", props.className)}
        >
            <HugeiconsIcon icon={MoreHorizontalCircle01Icon} strokeWidth={2} />
            <span className="sr-only">More pages</span>
        </span>;
    }
}
