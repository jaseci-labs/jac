"""Password input with visibility toggle — replaces Mantine PasswordInput."""
cl import from ...lib.utils { cn }
cl import from "@hugeicons/react" { HugeiconsIcon }
cl import from "@hugeicons/core-free-icons" { ViewIcon, ViewOffSlashIcon }

cl {
    def:pub PasswordInput(props: Any) -> JsxElement {
        has showPassword: bool = False;

        inputType = "text";
        if not showPassword {
            inputType = "password";
        }

        return <div className="relative">
            <input
                type={inputType}
                placeholder={props.placeholder or ""}
                value={props.value or ""}
                onChange={props.onChange}
                disabled={props.disabled or False}
                data-slot="input"
                className={cn("dark:bg-input/30 border-input focus-visible:border-ring focus-visible:ring-ring/50 h-8 rounded-lg border bg-transparent pr-9 pl-2.5 py-1 text-base transition-colors focus-visible:ring-3 md:text-sm placeholder:text-muted-foreground w-full min-w-0 outline-none disabled:pointer-events-none disabled:cursor-not-allowed disabled:opacity-50", props.className)}
            />
            <button
                type="button"
                onClick={lambda { showPassword = not showPassword; }}
                className="absolute right-2 top-1/2 -translate-y-1/2 text-muted-foreground hover:text-foreground transition-colors"
                tabIndex={-1}
            >
                {showPassword and <HugeiconsIcon icon={ViewOffSlashIcon} strokeWidth={2} className="size-3.5" /> or <HugeiconsIcon icon={ViewIcon} strokeWidth={2} className="size-3.5" />}
            </button>
        </div>;
    }
}
