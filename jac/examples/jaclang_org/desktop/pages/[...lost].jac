import from "@jac/runtime" { Link }
import from core.site.ui.button { buttonVariants }
import from core.site.ui.GraphBackdrop { GraphBackdrop }

def:pub page -> JsxPage {
    return
        <section
            className="relative flex min-h-[80vh] items-center justify-center overflow-hidden pt-16"
        >
            <div className="hero-glow absolute inset-0"></div>
            <GraphBackdrop/>
            <div className="relative mx-auto max-w-xl px-6 text-center">
                <p className="font-mono text-sm text-primary">error[E404]</p>
                <h1
                    className="mt-3 text-balance text-5xl font-bold tracking-tight sm:text-6xl"
                >
                    No node here.
                </h1>
                <p className="mt-5 text-balance text-lg text-muted-foreground">
                    This walker traversed the whole graph and found nothing at this path. The edge you followed may have been deleted.
                </p>
                <div className="mt-8 flex items-center justify-center gap-3">
                    <Link
                        to="/"
                        className={buttonVariants().call(None, {"size": "lg"})}
                    >
                        root spawn home
                    </Link>
                    <Link
                        to="/docs/latest"
                        className={buttonVariants().call(
                            None, {"variant": "outline", "size": "lg"}
                        )}
                    >
                        Read the docs
                    </Link>
                </div>
            </div>
        </section>;
}
