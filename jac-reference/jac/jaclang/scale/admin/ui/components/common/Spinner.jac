"""Loading spinner component."""

def:pub Spinner(size: str = "md") -> JsxElement {
    sizeClass: str = "w-4 h-4"
        if size == "sm"
        else ("w-12 h-12" if size == "lg" else "w-8 h-8");

    <div
        className={"border-2 border-accent border-t-transparent rounded-full animate-spin "
            + sizeClass}
    ></div>
}

def:pub LoadingScreen -> JsxElement {
    <div className="min-h-screen bg-bg flex items-center justify-center">
        <div className="text-center">
            <Spinner/>
            <p className="text-muted text-sm mt-3">Loading</p>
        </div>
    </div>
}
