import from .app { app }

cl import from ".app" { app }
cl import ".global.css";

cl {
    def:pub App -> JsxElement {
        return
            <div
                className="min-h-screen bg-background text-foreground flex items-center justify-center"
            >
                <h1 className="text-2xl font-bold">
                    Welcome to{{name}}
                </h1>
            </div>;
    }
}
