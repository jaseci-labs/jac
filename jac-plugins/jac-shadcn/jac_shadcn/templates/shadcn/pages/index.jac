"""Home page -- renders at `/`."""

cl import from "..components.home-page" { HomePage }

cl {
    def:pub page -> JsxElement {
        return
            <HomePage/>;
    }
}
