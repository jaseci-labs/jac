"""Default landing page for {{name}}.

Uses raw Tailwind classes that mirror shadcn's design tokens so the page
looks themed even before you start using actual shadcn components.

Once you've installed components (`jac shadcn add button card`), you can
replace the divs below with `<Card>` and `<Button>` from
`./ui/button` and `./ui/card`. Run `jac shadcn list` to see what's
available in the registry.
"""

cl {
    def:pub HomePage -> JsxElement {
        return
            <main className="flex flex-1 items-center justify-center p-8">
                <div
                    className="w-full max-w-md rounded-xl border border-border bg-card text-card-foreground shadow-sm"
                >
                    <div className="flex flex-col space-y-1.5 p-6 pb-3">
                        <h1
                            className="text-2xl font-semibold leading-none tracking-tight"
                        >
                            Welcome to {{name}}
                        </h1>
                        <p className="text-sm text-muted-foreground">
                            A jac-shadcn project.
                        </p>
                    </div>
                    <div className="space-y-4 p-6 pt-3">
                        <p className="text-sm text-muted-foreground">
                            Edit
                            <code
                                className="mx-1 rounded bg-muted px-1.5 py-0.5 font-mono text-xs"
                            >
                                components/home-page.cl.jac
                            </code>
                            to change this page, or run
                            <code
                                className="mx-1 rounded bg-muted px-1.5 py-0.5 font-mono text-xs"
                            >
                                jac shadcn add &lt;name&gt;
                            </code>
                            to install more components from the registry.
                        </p>
                        <a
                            href="https://docs.jaseci.org/reference/plugins/jac-shadcn/"
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex h-10 items-center justify-center rounded-md bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-colors hover:bg-primary/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
                        >
                            Read the docs
                        </a>
                    </div>
                </div>
            </main>;
    }
}
