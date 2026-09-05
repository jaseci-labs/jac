"""A `pages/` project whose `app` drops the route tree it is handed -- E1108."""

def:pub Home -> JsxElement {
    return <div>home</div>;
}

def:pub app -> JsxElement {
    return <Home/>;
}
