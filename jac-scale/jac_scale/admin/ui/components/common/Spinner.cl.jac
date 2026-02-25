"""Loading spinner component."""

cl {
    def:pub Spinner(size: str = "md") -> JsxElement {
        sizeClass = size == "sm"
        and "w-4 h-4"
        or (size == "lg" and "w-12 h-12" or "w-8 h-8");

        return
            <div
                className={"border-2 border-orange-500 border-t-transparent rounded-full animate-spin " + sizeClass}
            ></div>;
    }

    def:pub LoadingScreen -> JsxElement {
        return
            <div
                className="min-h-screen bg-slate-950 flex items-center justify-center"
            >
                <div className="text-center">
                    <Spinner/>
                    <p className="text-slate-400 text-sm mt-3">
                        Loading
                    </p>
                </div>
            </div>;
    }
}
