"""Test has-var useState scoping across sibling functions."""

def:pub useCart() {
    has cart: list[any] = [];
    return {"cart": cart};
}

def:pub CartComponent() -> JsxElement {
    cart = useCart();
    return <div>{cart["cart"]}</div>;
}
