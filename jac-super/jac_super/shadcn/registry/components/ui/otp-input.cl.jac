cl import from "input-otp" { OTPInput, OTPInputContext }
cl import from react { useContext }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { MinusSignIcon }
cl import from ...lib.utils { cn }

cl {
    def:pub InputOTP(props: Any) -> JsxElement {
        return
            <OTPInput
                data-slot="input-otp"
                {...props}
                containerClassName={cn(
                    "cn-input-otp flex items-center has-disabled:opacity-50",
                    props.containerClassName
                )}
                spellCheck={false}
                className={cn(
                    "cn-input-otp-input disabled:cursor-not-allowed", props.className
                )}
            />;
    }

    def:pub InputOTPGroup(props: Any) -> JsxElement {
        return
            <div
                data-slot="input-otp-group"
                {...props}
                className={cn("cn-input-otp-group flex items-center", props.className)}
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
        return
            <div
                data-slot="input-otp-slot"
                data-active={isActive}
                {...props}
                className={cn(
                    "cn-input-otp-slot relative flex items-center justify-center data-[active=true]:z-10",
                    props.className
                )}
            >
                {char}{hasFakeCaret
                and (
                    <div
                        className="cn-input-otp-caret pointer-events-none absolute inset-0 flex items-center justify-center"
                    >
                        <div className="cn-input-otp-caret-line"/>
                    </div>
                )}
            </div>;
    }

    def:pub InputOTPSeparator(props: Any) -> JsxElement {
        return
            <div
                data-slot="input-otp-separator"
                {...props}
                className="cn-input-otp-separator flex items-center"
                role="separator"
            >
                <HugeiconsIcon icon={MinusSignIcon} size={16}/>
            </div>;
    }
}
