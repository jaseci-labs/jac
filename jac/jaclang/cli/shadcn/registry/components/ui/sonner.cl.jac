import from "sonner" { Toaster as SonnerPrimitive }

def:pub Toaster(props: any) -> JsxElement {
    theme = props["theme"] or "system";
    return
        <SonnerPrimitive
            theme={theme}
            className="toaster group"
            toastOptions={{"classNames": {"toast": "cn-toast"}}}
            style={{
                "--normal-bg": "var(--popover)",
                "--normal-text": "var(--popover-foreground)",
                "--normal-border": "var(--border)",
                "--border-radius": "var(--radius)"
            }}
            {**props}
        />;
}
