cl import from "input-otp" { OTPInput, OTPInputContext }
cl import from react { useContext }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { MinusSignIcon }
cl import from ...lib.utils { cn }

cl {
    def:pub InputOTP(props: Any) -> JsxElement {
        return <OTPInput
            data-slot="input-otp"
            {...props}
            containerClassName={cn(
                "gap-2 flex items-center has-disabled:opacity-50",
                props.containerClassName
            )}
            spellCheck={false}
            className={cn(
                "gap-2-input disabled:cursor-not-allowed",
                props.className
            )}
        />;
    }

    def:pub InputOTPGroup(props: Any) -> JsxElement {
        return <div
            data-slot="input-otp-group"
            {...props}
            className={cn("has-aria-invalid:ring-destructive/20 dark:has-aria-invalid:ring-destructive/40 has-aria-invalid:border-destructive rounded-lg has-aria-invalid:ring-3 flex items-center", props.className)}
        />;
    }

    def:pub InputOTPSlot(props: Any) -> JsxElement {
        index = props.index;
        ctx = useContext(OTPInputContext);
        slotData = None;
        if ctx and ctx.slots {
            slotData = ctx.slots[index];
        }
        char = slotData.char if slotData else None;
        hasFakeCaret = slotData.hasFakeCaret if slotData else false;
        isActive = slotData.isActive if slotData else false;
        return <div
            data-slot="input-otp-slot"
            data-active={isActive}
            {...props}
            className={cn(
                "dark:bg-input/30 border-input data-[active=true]:border-ring data-[active=true]:ring-ring/50 data-[active=true]:aria-invalid:ring-destructive/20 dark:data-[active=true]:aria-invalid:ring-destructive/40 aria-invalid:border-destructive data-[active=true]:aria-invalid:border-destructive size-8 border-y border-r text-sm transition-all outline-none first:rounded-l-lg first:border-l last:rounded-r-lg data-[active=true]:ring-3 relative flex items-center justify-center data-[active=true]:z-10",
                props.className
            )}
        >
            {char}
            {hasFakeCaret and (
                <div className="gap-2-caret pointer-events-none absolute inset-0 flex items-center justify-center">
                    <div className="animate-caret-blink bg-foreground h-4 w-px duration-1000" />
                </div>
            )}
        </div>;
    }

    def:pub InputOTPSeparator(props: Any) -> JsxElement {
        return <div
            data-slot="input-otp-separator"
            {...props}
            className="[&_svg:not([class*='size-'])]:size-4 flex items-center"
            role="separator"
        >
            <HugeiconsIcon icon={MinusSignIcon} size={16} />
        </div>;
    }
}

