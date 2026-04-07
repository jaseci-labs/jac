cl import ".global.css";
cl import from .components.LandingPage { LandingPage }

cl {
    def:pub app() -> JsxElement {
        return <LandingPage />;
    }
}
