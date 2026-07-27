"""First-run welcome banner for Little X."""

import from "lucide-react" { Sparkles, X }
import from .ui.button { Button }

def:pub WelcomeBanner(onDismiss: Callable[[], None]) -> JsxElement {
    return
        <div
            className="lx-fade-up relative m-4 overflow-hidden rounded-2xl border border-primary/30 bg-gradient-to-br from-primary/15 via-primary/5 to-transparent p-5"
        >
            <div className="flex items-start gap-3">
                <div
                    className="flex size-10 shrink-0 items-center justify-center rounded-full bg-primary/15 text-primary"
                >
                    <Sparkles size={20}/>
                </div>
                <div className="flex-1">
                    <div
                        className="font-display text-lg font-extrabold text-foreground"
                    >
                        Welcome to LITTLE-X
                    </div>
                    <ul
                        className="mt-2 flex flex-col gap-1 text-sm text-muted-foreground"
                    >
                        <li className="flex items-center gap-2">
                            <span className="size-1.5 rounded-full bg-primary"/>
                            Post a thought to get started
                        </li>
                        <li className="flex items-center gap-2">
                            <span className="size-1.5 rounded-full bg-primary"/>
                            Use #hashtags to join trending topics
                        </li>
                        <li className="flex items-center gap-2">
                            <span className="size-1.5 rounded-full bg-primary"/>
                            Explore and follow people in Explore
                        </li>
                    </ul>
                </div>
                <Button
                    variant="ghost"
                    size="icon"
                    className="size-7 text-muted-foreground hover:text-foreground"
                    onClick={lambda { onDismiss(); }}
                >
                    <X size={16}/>
                </Button>
            </div>
        </div>;
}
