"""Main entry point for {{name}}."""

cl import ".global.css";

# Client-side root component. Replace this with your own components from
# `components/ui/` -- run `jac shadcn add button card dialog` to install
# more from the registry.
to cl:

def:pub app -> JsxElement {
    return
        <div
            className="min-h-screen bg-background text-foreground flex flex-col items-center justify-center gap-4 p-8"
        >
            <h1 className="text-3xl font-bold">Welcome to {{name}}</h1>
            <p className="text-muted-foreground max-w-md text-center">
                A jac-shadcn project. Edit this file (main.jac) or pull
                components into <code className="font-mono text-sm">components/ui/</code>
                with <code className="font-mono text-sm">jac shadcn add &lt;name&gt;</code>.
            </p>
        </div>;
}
