import ".styles.global.css";

def:pub app -> JsxElement {
    return
        <div
            className="min-h-screen bg-background text-foreground flex items-center justify-center"
        >
            <h1 className="text-2xl font-bold">Welcome to {{name}}</h1>
        </div>;
}
