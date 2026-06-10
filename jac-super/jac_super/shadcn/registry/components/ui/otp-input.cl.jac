import from "input-otp" { OTPInput, OTPInputContext }
import from react { useContext }
import from "@hugeicons/react" { HugeiconsIcon }
import from "@hugeicons/core-free-icons" { MinusSignIcon }
import from ...lib.utils { cn }

def:pub InputOTP(props: any) -> JsxElement {
    return
        <OTPInput
            data-slot="input-otp"
            {**props}
            containerClassName={cn(
                "cn-input-otp flex items-center has-disabled:opacity-50",
                props["containerClassName"]
            )}
            spellCheck={false}
            className={cn(
                "cn-input-otp-input disabled:cursor-not-allowed", props["className"]
            )}
        />;
}

def:pub InputOTPGroup(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            data-slot="input-otp-group"
            {**attrs}
            className={cn("cn-input-otp-group flex items-center", props["className"])}
        />;
}

def:pub InputOTPSlot(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    index = props["index"];
    ctx: any = useContext(OTPInputContext);
    slotData: any = None;
    if ctx and ctx.slots {
        slotData = ctx.slots[index];
    }
    char = slotData.char if slotData else None;
    hasFakeCaret = slotData.hasFakeCaret if slotData else False;
    isActive = slotData.isActive if slotData else False;
    return
        <div
            data-slot="input-otp-slot"
            data-active={isActive}
            {**attrs}
            className={cn(
                "cn-input-otp-slot relative flex items-center justify-center data-[active=true]:z-10",
                props["className"]
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

def:pub InputOTPSeparator(props: any) -> JsxElement {
    attrs: dict[str, any] = {** props};
    return
        <div
            data-slot="input-otp-separator"
            {**attrs}
            className="cn-input-otp-separator flex items-center"
            role="separator"
        >
            <HugeiconsIcon icon={MinusSignIcon} size={16}/>
        </div>;
}
