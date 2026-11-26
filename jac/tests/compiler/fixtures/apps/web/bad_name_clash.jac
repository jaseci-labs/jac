import from ..social_app { greet }

def:pub Clash -> JsxElement {
    async can with entry {
        import from ..social_app { relay as greet }
        await greet("x");
    }

    <div/>
}
