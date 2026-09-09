import from "@jac/mobui" { Image }

def:pub BrandMark(size: int = 40) -> JsxElement {
    return
        <Image
            accessibilityLabel="JacYac"
            source={{"uri": "/static/assets/jacyak-logo.svg"}}
            style={{"width": size, "height": size}}
        />;
}
